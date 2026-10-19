#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
swift tool/generate_update_keys.swift
if [ ! -f .local/update-signing/windows_dsa.pem ]; then
  openssl dsaparam -out .local/update-signing/dsa-parameters.pem 4096
  openssl gendsa -out .local/update-signing/windows_dsa.pem .local/update-signing/dsa-parameters.pem
  rm .local/update-signing/dsa-parameters.pem
fi
openssl dsa -in .local/update-signing/windows_dsa.pem -pubout -out updates/windows_dsa_pub.pem
echo 'Keys ready. Back up .local/update-signing privately; never commit private keys.'
