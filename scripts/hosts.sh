#!/usr/bin/env bash
set -euo pipefail
IP="${1:-192.168.49.240}"
for d in app1 app2 app3 app4 argocd; do
  h="${d}.parcial.local"
  if ! grep -qE "[[:space:]]${h}\$" /etc/hosts; then
    echo "${IP} ${h}" | sudo tee -a /etc/hosts >/dev/null
    echo "agregado: ${h}"
  fi
done