const express = require('express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const app = express();
const PORT = 3000;
const RECORDS_DIR = path.join(__dirname, 'records');

/* ── Auth helpers (same algorithm as api/login.js) ── */
const TOKEN_TTL_MS = 8 * 60 * 60 * 1000; // 8 hours

function signToken(ts) {
  const secret = process.env.APP_PASSWORD || '';
  const sig = crypto.createHmac('sha256', secret).update(String(ts)).digest('hex');
  return `${ts}.${sig}`;
}

function verifyToken(token) {
  if (!token) return false;
  const [ts, sig] = token.split('.');
  if (!ts || !sig) return false;
  const expected = crypto
    .createHmac('sha256', process.env.APP_PASSWORD || '')
    .update(ts)
    .digest('hex');
  if (sig !== expected) return false;
  if (Date.now() - Number(ts) > TOKEN_TTL_MS) return false;
  return true;
}

function requireAuth(req, res, next) {
  const token = req.headers['x-auth-token'] || req.query?.token || '';
  if (!verifyToken(token)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}

// Ensure records directory exists
if (!fs.existsSync(RECORDS_DIR)) {
  fs.mkdirSync(RECORDS_DIR);
}

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

/* ── POST /api/login ─────────────────────────── */
app.post('/api/login', (req, res) => {
  const { password } = req.body || {};
  const correctPassword = process.env.APP_PASSWORD;

  if (!correctPassword) {
    return res.status(500).json({ error: 'APP_PASSWORD is not set on the server.' });
  }
  if (!password || password !== correctPassword) {
    return res.status(401).json({ error: 'รหัสผ่านไม่ถูกต้อง' });
  }

  const token = signToken(Date.now());
  return res.status(200).json({ success: true, token });
});

/* ── GET /api/login?token=... — verify token ─── */
app.get('/api/login', (req, res) => {
  const token = req.query?.token || '';
  return res.status(200).json({ valid: verifyToken(token) });
});

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
app.post('/api/save', requireAuth, (req, res) => {
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

// GET /api/records  — list all records grouped by date, with content (auth required)
app.get('/api/records', requireAuth, (req, res) => {
  const PAGE_SIZE = 10;
  const page = Math.max(1, parseInt(req.query?.page || '1', 10));

  const files = fs.readdirSync(RECORDS_DIR).sort().reverse();

  const total = files.length;
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const currentPage = Math.min(page, totalPages);
  const start = (currentPage - 1) * PAGE_SIZE;
  const pageFiles = files.slice(start, start + PAGE_SIZE);

  const grouped = {};
  pageFiles.forEach((file) => {
    const dateKey = file.slice(0, 10); // YYYY-MM-DD
    if (!grouped[dateKey]) grouped[dateKey] = [];
    const filepath = path.join(RECORDS_DIR, file);
    const content = fs.existsSync(filepath) ? fs.readFileSync(filepath, 'utf8') : '';
    grouped[dateKey].push({ filename: file, content });
  });

  res.json({
    grouped,
    pagination: { page: currentPage, totalPages, total, pageSize: PAGE_SIZE },
  });
});

// GET /api/record/:filename  — get content of a specific record (auth required)
app.get('/api/record/:filename', requireAuth, (req, res) => {
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

// DELETE /api/delete?filename=...  — delete a record file (auth required)
app.delete('/api/delete', requireAuth, (req, res) => {
  const { filename } = req.query || {};
  if (!filename || filename.includes('/') || filename.includes('..')) {
    return res.status(400).json({ error: 'Invalid filename' });
  }
  const filepath = path.join(RECORDS_DIR, filename);
  if (!fs.existsSync(filepath)) {
    return res.status(404).json({ error: 'File not found' });
  }
  fs.unlinkSync(filepath);
  res.json({ success: true });
});

app.listen(PORT, () => {
  console.log(`TextPaste running at http://localhost:${PORT}`);
});
