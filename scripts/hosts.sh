#!/usr/bin/env bash
# Uso: ./scripts/hosts.sh [IP]   (por defecto, la IP de MetalLB)
set -euo pipefail
IP="${1:-192.168.49.240}"
for n in 1 2 3 4; do
  d="app${n}.parcial.local"
  if ! grep -qE "[[:space:]]${d}\$" /etc/hosts; then
    echo "${IP} ${d}" | sudo tee -a /etc/hosts >/dev/null
    echo "agregado: ${d}"
  fi
done