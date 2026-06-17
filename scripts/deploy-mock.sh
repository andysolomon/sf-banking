#!/usr/bin/env bash
# Deploy the mock core-banking SaaS to Vercel.
# Prereq (interactive, one-time): `vercel login`.
# Usage: scripts/deploy-mock.sh [--prod]   (default: preview deploy)
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
MOCK_DIR="$HERE/mock"

cd "$MOCK_DIR"

if ! command -v vercel >/dev/null 2>&1; then
  echo "Vercel CLI not found. Install: npm i -g vercel   (then: vercel login)"
  exit 1
fi

if [ "${1:-}" = "--prod" ]; then
  echo "Deploying mock to Vercel PRODUCTION…"
  vercel --prod --yes
else
  echo "Deploying mock to Vercel preview… (pass --prod for production)"
  vercel --yes
fi

echo
echo "Done. Use the printed URL as the Named Credential base in Salesforce (ADR-004)."
echo "Smoke test:  curl -s <URL>/api/accounts/abc/balance"
