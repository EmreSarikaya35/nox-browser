#!/bin/sh
# AppIcon.appiconset içeriğini yeniden üretir.
set -e
cd "$(dirname "$0")/.."
SET=NOX/Assets.xcassets/AppIcon.appiconset
mkdir -p "$SET"
swift Scripts/make-icon.swift Scripts/logo.jpg "$SET/icon_1024.png"
IMAGES=""
for size in 16 32 128 256 512; do
  for scale in 1 2; do
    px=$((size * scale))
    [ "$px" = 1024 ] || sips -z "$px" "$px" "$SET/icon_1024.png" --out "$SET/icon_$px.png" >/dev/null
    IMAGES="$IMAGES{\"idiom\":\"mac\",\"size\":\"${size}x${size}\",\"scale\":\"${scale}x\",\"filename\":\"icon_$px.png\"},"
  done
done
printf '{"images":[%s],"info":{"version":1,"author":"xcode"}}\n' "${IMAGES%,}" > "$SET/Contents.json"
printf '{"info":{"version":1,"author":"xcode"}}\n' > NOX/Assets.xcassets/Contents.json
