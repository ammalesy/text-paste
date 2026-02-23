const { list } = require('@vercel/blob');

const PAGE_SIZE = 10;

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  if (!process.env.BLOB_READ_WRITE_TOKEN) {
    return res.status(500).json({ error: 'BLOB_READ_WRITE_TOKEN is not set.' });
  }

  try {
    const page = Math.max(1, parseInt(req.query?.page || '1', 10));
    const { blobs } = await list({ prefix: 'records/' });

    // Sort newest first
    blobs.sort((a, b) => b.pathname.localeCompare(a.pathname));

    const total = blobs.length;
    const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));
    const currentPage = Math.min(page, totalPages);
    const start = (currentPage - 1) * PAGE_SIZE;
    const pageBlobs = blobs.slice(start, start + PAGE_SIZE);

    // Fetch content of current page blobs in parallel
    const items = await Promise.all(
      pageBlobs.map(async (b) => {
        const name = b.pathname.replace('records/', '');
        try {
          const r = await fetch(b.url);
          const content = r.ok ? await r.text() : '';
          return { filename: name, content };
        } catch {
          return { filename: name, content: '' };
        }
      })
    );

    // Group by date
    const grouped = {};
    items.forEach(({ filename, content }) => {
      const dateKey = filename.slice(0, 10); // YYYY-MM-DD
      if (!grouped[dateKey]) grouped[dateKey] = [];
      grouped[dateKey].push({ filename, content });
    });

    return res.status(200).json({
      grouped,
      pagination: { page: currentPage, totalPages, total, pageSize: PAGE_SIZE },
    });
  } catch (err) {
    console.error('Blob list error:', err);
    return res.status(500).json({ error: err.message || 'Failed to list records' });
  }
};
