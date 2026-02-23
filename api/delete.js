const { list, del } = require('@vercel/blob');

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'DELETE') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  if (!process.env.BLOB_READ_WRITE_TOKEN) {
    return res.status(500).json({ error: 'BLOB_READ_WRITE_TOKEN is not set.' });
  }

  // filename comes from query string: /api/delete?filename=2026-02-23T14-05-30-record.txt
  const { filename } = req.query || {};
  if (!filename || filename.includes('..') || filename.includes('/')) {
    return res.status(400).json({ error: 'Invalid filename' });
  }

  try {
    // Find the blob by pathname
    const { blobs } = await list({ prefix: `records/${filename}` });
    const blob = blobs.find((b) => b.pathname === `records/${filename}`);

    if (!blob) {
      return res.status(404).json({ error: 'Record not found' });
    }

    await del(blob.url);
    return res.status(200).json({ success: true });
  } catch (err) {
    console.error('Blob delete error:', err);
    return res.status(500).json({ error: err.message || 'Failed to delete record' });
  }
};
