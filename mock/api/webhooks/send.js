// POST /api/webhooks/send — the INBOUND side: core banking pushes an event to Salesforce.
// This lets us drill the inbound webhook flows (FR-3 posted-transaction, FR-4 fraud-alert)
// by telling the mock to POST a payload to the SF Apex @RestResource endpoint.
//
// Body: { target_url, type, payload, auth }
//   target_url — the SF inbound endpoint (e.g. https://<instance>/services/apexrest/txn)
//   type       — "posted_transaction" | "fraud_alert"
//   payload    — the event body (incl. external_txn_id / alert_id for idempotency)
//   auth       — optional Authorization header value (e.g. "Bearer <jwt>")
module.exports = async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method not allowed' });

  const body = typeof req.body === 'string' ? safeParse(req.body) : req.body || {};
  const { target_url, type, payload, auth } = body;
  if (!target_url || !type) {
    return res.status(400).json({ error: 'target_url and type are required' });
  }

  try {
    const r = await fetch(target_url, {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...(auth ? { authorization: auth } : {}) },
      body: JSON.stringify({ type, ...(payload || {}) }),
    });
    const text = await r.text();
    return res.status(200).json({ sent: true, target_status: r.status, target_body: text.slice(0, 500) });
  } catch (e) {
    return res.status(502).json({ sent: false, error: String(e) });
  }
};

function safeParse(s) { try { return JSON.parse(s); } catch { return {}; } }
