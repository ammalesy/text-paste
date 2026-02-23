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
    const name = b.pathname.replace('records/', '');
    const fileDateStr = name.slice(0, 10);
    return fileDateStr < cutoffStr;
  });

  await Promise.all(toDelete.map((b) => del(b.url)));
}

// Parse raw body as JSON (Vercel does not auto-parse body)
function parseBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (chunk) => { data += chunk; });
    req.on('end', () => {
      try { resolve(JSON.parse(data)); }
      catch { reject(new Error('Invalid JSON')); }
    });
    req.on('error', reject);
  });
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  let body;
  try {
    body = req.body && typeof req.body === 'object' ? req.body : await parseBody(req);
  } catch {
    return res.status(400).json({ error: 'Invalid request body' });
  }

  const { text } = body;
  if (!text || text.trim() === '') {
    return res.status(400).json({ error: 'Text is empty' });
  }

  if (!process.env.BLOB_READ_WRITE_TOKEN) {
    return res.status(500).json({ error: 'BLOB_READ_WRITE_TOKEN is not set. Please connect a Vercel Blob store to this project.' });
  }

  let blob;
  try {
    const filename = `${timestampStr()}-record.txt`;
    blob = await put(`records/${filename}`, text, {
      access: 'public',
      contentType: 'text/plain; charset=utf-8',
    });
    cleanOldRecords().catch((e) => console.error('cleanOldRecords error:', e));
    return res.status(200).json({ success: true, filename, url: blob.url });
  } catch (err) {
    console.error('Blob put error:', err);
    return res.status(500).json({ error: err.message || 'Failed to save record' });
  }
};

