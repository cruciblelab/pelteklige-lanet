#!/usr/bin/env bash
# Fonem modelini (ZIPA small CR-CTC, int8 ONNX, ~70 MB) indirir ve doğrular.
# Model git'e konmaz; CI her derlemede bu betikle indirip APK'ya ekler.
#
# Kaynak : https://huggingface.co/anyspeech/zipa-small-crctc-500k
# Makale : Zhu ve ark., "ZIPA: A family of efficient models for multilingual
#          phone recognition", ACL 2025 — https://github.com/lingjzhu/zipa
# Lisans : model ağırlıkları CC BY 4.0
set -euo pipefail

REVISION="a97a19eab1e5b2263ade7922ba97bf737dd418db"
SHA256="d0e28b68164e8b1fbd6105100c01798828aa0855000ce9bbbd1a2cec233adf13"
URL="https://huggingface.co/anyspeech/zipa-small-crctc-500k/resolve/${REVISION}/model.int8.onnx"

cd "$(dirname "$0")/.."
OUT="assets/models/zipa-small-crctc-500k.int8.onnx"
mkdir -p assets/models

if [ -f "$OUT" ] && echo "$SHA256  $OUT" | sha256sum -c --status; then
  echo "Model zaten var ve doğrulandı: $OUT"
  exit 0
fi

echo "Model indiriliyor…"
curl -fL --retry 4 --retry-delay 2 -o "$OUT.part" "$URL"
echo "$SHA256  $OUT.part" | sha256sum -c -
mv "$OUT.part" "$OUT"
echo "Hazır: $OUT ($(du -h "$OUT" | cut -f1))"
