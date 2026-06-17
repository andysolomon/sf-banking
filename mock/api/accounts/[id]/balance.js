// GET /api/accounts/:id/balance — returns a deterministic balance for an account id.
// Stateless: balance is derived from a hash of the id, so it's stable across calls.
// Failure switch: send header `x-mock-fail: 500` (or `timeout`) to drill the SF retry /
// circuit-breaker / dead-letter paths. Also honored via env MOCK_FAIL_MODE.
const crypto = require('crypto');

module.exports = async (req, res) => {
  if (req.method !== 'GET') return res.status(405).json({ error: 'method not allowed' });

  const fail = req.headers['x-mock-fail'] || process.env.MOCK_FAIL_MODE;
  if (fail === '500') return res.status(500).json({ error: 'core banking unavailable' });
  if (fail === 'timeout') {
    // Bounded, configurable delay. Set the SF Named-Credential callout timeout BELOW this
    // (e.g. 5s) so the drill exercises SF's timeout→retry path while the function stays
    // within its maxDuration (see vercel.json).
    const ms = Number(process.env.MOCK_DELAY_MS) || 8000;
    await new Promise((r) => setTimeout(r, ms));
  }

  const id = req.query.id;
  const h = parseInt(crypto.createHash('sha256').update(String(id)).digest('hex').slice(0, 8), 16);
  const balance_minor = 100000 + (h % 900000); // 1,000.00 .. 9,999.99 (cents)

  return res.status(200).json({
    core_account_id: id,
    balance_minor,
    currency: 'USD',
    as_of: new Date().toISOString(),
  });
};
