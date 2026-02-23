const crypto = require('crypto');

// Token valid for 8 hours
const TOKEN_TTL_MS = 8 * 60 * 60 * 1000;

// Simple HMAC-signed token: base64(timestamp).signature
function signToken(ts) {
  const secret = process.env.APP_PASSWORD || '';
  const sig = crypto.createHmac('sha256', secret).update(String(ts)).digest('hex');
  return `${ts}.${sig}`;
}

function verifyToken(token) {
  if (!token) return false;
  const [ts, sig] = token.split('.');
  if (!ts || !sig) return false;
  const expected = crypto.createHmac('sha256', process.env.APP_PASSWORD || '').update(ts).digest('hex');
  if (sig !== expected) return false;
  if (Date.now() - Number(ts) > TOKEN_TTL_MS) return false;
  return true;
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  // GET /api/login?token=... — verify existing token
  if (req.method === 'GET') {
    const token = req.query?.token || '';
    return res.status(200).json({ valid: verifyToken(token) });
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // Parse body
  let body;
  try {
    let raw = '';
    await new Promise((resolve, reject) => {
      req.on('data', (c) => { raw += c; });
      req.on('end', resolve);
      req.on('error', reject);
    });
    body = req.body && typeof req.body === 'object' ? req.body : JSON.parse(raw);
  } catch {
    return res.status(400).json({ error: 'Invalid request body' });
  }

  const { password } = body;
  const correctPassword = process.env.APP_PASSWORD;

  if (!correctPassword) {
    return res.status(500).json({ error: 'APP_PASSWORD is not set on the server.' });
  }

  if (!password || password !== correctPassword) {
    return res.status(401).json({ error: 'รหัสผ่านไม่ถูกต้อง' });
  }

  const token = signToken(Date.now());
  return res.status(200).json({ success: true, token });
};

module.exports.verifyToken = verifyToken;
