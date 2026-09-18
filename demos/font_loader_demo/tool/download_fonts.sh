#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
mkdir -p sample-fonts
revision=f8d157532fbfaeda587e826d4cd5b21a49186f7c
for path in \
  Sans/OTF/Japanese/NotoSansCJKjp-Regular.otf \
  Sans/OTF/Japanese/NotoSansCJKjp-Bold.otf \
  Sans/Variable/TTF/NotoSansCJKjp-VF.ttf \
  Sans/LICENSE; do
  target="sample-fonts/${path##*/}"
  blob=$(gh api "repos/notofonts/noto-cjk/contents/$path?ref=$revision" --jq .sha)
  gh api "repos/notofonts/noto-cjk/git/blobs/$blob" --jq .content \
    | base64 --decode > "$target.part"
  mv -- "$target.part" "$target"
done
printf 'Noto CJK revision: %s\n' "$revision" > sample-fonts/SOURCE.txt
sha256sum sample-fonts/*.otf sample-fonts/*.ttf > sample-fonts/SHA256SUMS
cat sample-fonts/SHA256SUMS
