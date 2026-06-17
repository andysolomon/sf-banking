// POST /api/transfers — execute a transfer in the (mock) core-banking system.
// Idempotency: core_transfer_id is derived from the Idempotency-Key, so retrying the
//   same key returns the SAME id (stateless idempotency simulation — no storage needed).
// Failure switch (header `x-mock-fail` or env MOCK_FAIL_MODE):
//   500     → server error (drills retry → dead-letter)
//   timeout → 30s delay (drills callout timeout)
//   422     → insufficient funds (also triggered by amount_minor > 100000000)
const crypto = require('crypto');

module.exports = async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method not allowed' });

  const fail = req.headers['x-mock-fail'] || process.env.MOCK_FAIL_MODE;
  if (fail === '500') return res.status(500).json({ error: 'core banking unavailable' });
  if (fail === 'timeout') {
    // Bounded, configurable delay (see vercel.json maxDuration). Set the SF callout
    // timeout below this to drill the timeout → retry → dead-letter path.
    const ms = Number(process.env.MOCK_DELAY_MS) || 8000;
    await new Promise((r) => setTimeout(r, ms));
  }

  const body = typeof req.body === 'string' ? safeParse(req.body) : req.body || {};
  const { from_account_number, to_account_number, amount_minor } = body;

  if (!Number.isInteger(amount_minor) || amount_minor <= 0) {
    return res.status(400).json({ error: 'amount_minor must be a positive integer' });
  }
  if (fail === '422' || amount_minor > 100000000) {
    return res.status(422).json({ error: 'insufficient funds' });
  }

  const key = req.headers['idempotency-key'] || '';
  const seed = key || crypto.randomUUID();
  const core_transfer_id = 'ct_' + crypto.createHash('sha256').update(seed).digest('hex').slice(0, 16);

  return res.status(200).json({
    core_transfer_id,
    status: 'posted',
    from_account_number: from_account_number ?? null,
    to_account_number: to_account_number ?? null,
    amount_minor,
    idempotency_key: key || null,
    posted_at: new Date().toISOString(),
  });
};

function safeParse(s) { try { return JSON.parse(s); } catch { return {}; } }
