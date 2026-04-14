#!/usr/bin/env bash
# scripts/setup-cosign.sh — Generate Cosign key pair and store in Sealed Secrets
set -euo pipefail

echo "Setting up Cosign image signing"

if ! command -v cosign &>/dev/null; then
  echo "Installing cosign..."
  COSIGN_VERSION="v2.2.3"
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')
  curl -sLO "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-${OS}-${ARCH}"
  chmod +x cosign-${OS}-${ARCH}
  mv cosign-${OS}-${ARCH} /usr/local/bin/cosign
fi

echo "Generating Cosign key pair..."
COSIGN_PASSWORD="" cosign generate-key-pair

echo "cosign.key and cosign.pub generated"
echo ""
echo "Next steps:"
echo "  1. Add cosign.key to GitHub Secrets as COSIGN_PRIVATE_KEY"
echo "  2. Add cosign.pub to security/cosign/cosign.pub in this repo"
echo "  3. Update kyverno/cluster-policies.yaml with the public key"
echo "  4. Store cosign.key in a secrets manager — do NOT commit it"
echo ""
echo "Public key (safe to commit):"
cat cosign.pub

if command -v kubeseal &>/dev/null; then
  echo ""
  echo "Sealing cosign.key with Sealed Secrets..."
  kubectl create secret generic cosign-private-key \
    --from-file=cosign.key=./cosign.key \
    --dry-run=client -o yaml | \
    kubeseal --format yaml > security/sealed-secrets/cosign-private-key.yaml
  echo "Sealed secret written to security/sealed-secrets/cosign-private-key.yaml"
  echo "This is safe to commit to git"
fi

rm cosign.key 
