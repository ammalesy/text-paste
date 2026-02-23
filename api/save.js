const { put, list, del } = require('@vercel/blob');

// Helper: timestamp string e.g. 2026-02-23T14-05-30
function timestampStr() {
  return new Date().toISOString().replace(/:/g, '-').slice(0, 19);
}

// Helper: YYYY-MM-DD from a Date
function dateStr(date) {
  return date.toISOString().slice(0, 10);
}

// Delete blobs older than 2 days
async function cleanOldRecords() {
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 2);
  const cutoffStr = dateStr(cutoff);

  const { blobs } = await list({ prefix: 'records/' });
  const toDelete = blobs.filter((b) => {
    const name = b.pathname.replace('records/', ''); // e.g. 2026-02-23T14-05-30-record.txt
    const fileDateStr = name.slice(0, 10);
    return fileDateStr < cutoffStr;
  });

  await Promise.all(toDelete.map((b) => del(b.url)));
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { text } = req.body;
  if (!text || text.trim() === '') {
    return res.status(400).json({ error: 'Text is empty' });
  }

  const filename = `${timestampStr()}-record.txt`;
  const blob = await put(`records/${filename}`, text, {
    access: 'public',
    contentType: 'text/plain; charset=utf-8',
  });

  await cleanOldRecords();

  res.status(200).json({ success: true, filename, url: blob.url });
};
