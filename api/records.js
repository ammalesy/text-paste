const { list } = require('@vercel/blob');

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { blobs } = await list({ prefix: 'records/' });

  // Sort newest first
  blobs.sort((a, b) => b.pathname.localeCompare(a.pathname));

  const grouped = {};
  blobs.forEach((b) => {
    const name = b.pathname.replace('records/', '');
    const dateKey = name.slice(0, 10); // YYYY-MM-DD
    if (!grouped[dateKey]) grouped[dateKey] = [];
    grouped[dateKey].push({ filename: name, url: b.url });
  });

  res.status(200).json(grouped);
};
