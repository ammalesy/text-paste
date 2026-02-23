const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 3000;
const RECORDS_DIR = path.join(__dirname, 'records');

// Ensure records directory exists
if (!fs.existsSync(RECORDS_DIR)) {
  fs.mkdirSync(RECORDS_DIR);
}

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Helper: get YYYY-MM-DD string for a given Date
function dateStr(date) {
  return date.toISOString().slice(0, 10);
}

// Helper: timestamp string for filename  e.g. 2026-02-23T14-05-30
function timestampStr() {
  return new Date().toISOString().replace(/:/g, '-').slice(0, 19);
}

// Helper: delete record files older than 2 days
function cleanOldRecords() {
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 2);
  const cutoffStr = dateStr(cutoff); // YYYY-MM-DD

  const files = fs.readdirSync(RECORDS_DIR);
  files.forEach((file) => {
    // filename format: 2026-02-23T14-05-30-record.txt
    const fileDateStr = file.slice(0, 10); // first 10 chars = YYYY-MM-DD
    if (fileDateStr < cutoffStr) {
      fs.unlinkSync(path.join(RECORDS_DIR, file));
      console.log(`Deleted old record: ${file}`);
    }
  });
}

// POST /api/save  — save text to a timestamped file
app.post('/api/save', (req, res) => {
  const { text } = req.body;
  if (!text || text.trim() === '') {
    return res.status(400).json({ error: 'Text is empty' });
  }

  const filename = `${timestampStr()}-record.txt`;
  const filepath = path.join(RECORDS_DIR, filename);

  fs.writeFileSync(filepath, text, 'utf8');
  cleanOldRecords();

  res.json({ success: true, filename });
});

// GET /api/records  — list all records grouped by date
app.get('/api/records', (req, res) => {
  const files = fs.readdirSync(RECORDS_DIR).sort().reverse();
  const grouped = {};

  files.forEach((file) => {
    const dateKey = file.slice(0, 10); // YYYY-MM-DD
    if (!grouped[dateKey]) grouped[dateKey] = [];
    grouped[dateKey].push(file);
  });

  res.json(grouped);
});

// GET /api/record/:filename  — get content of a specific record
app.get('/api/record/:filename', (req, res) => {
  const { filename } = req.params;
  // Basic security: no path traversal
  if (filename.includes('/') || filename.includes('..')) {
    return res.status(400).json({ error: 'Invalid filename' });
  }
  const filepath = path.join(RECORDS_DIR, filename);
  if (!fs.existsSync(filepath)) {
    return res.status(404).json({ error: 'File not found' });
  }
  const content = fs.readFileSync(filepath, 'utf8');
  res.json({ filename, content });
});

app.listen(PORT, () => {
  console.log(`TextPaste running at http://localhost:${PORT}`);
});
