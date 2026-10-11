#!/bin/bash
set -euo pipefail
[[ "$GITHUB_REPOSITORY" == 'shaoyou11/Kazumi' ]] || { echo '仅在个人定制仓库运行'; exit 1; }
upstream_tag=$(gh api repos/Predidit/Kazumi/releases/latest --jq .tag_name)
[[ "$upstream_tag" =~ ^v?[0-9][A-Za-z0-9._-]*$ ]] || { echo '发行标签无效'; exit 1; }
git fetch https://github.com/Predidit/Kazumi.git "refs/tags/$upstream_tag:refs/tags/official-$upstream_tag"
git config user.name shaoyou11
git config user.email shaoyou11@users.noreply.github.com
if ! git merge-base --is-ancestor "refs/tags/official-$upstream_tag" HEAD; then
  git merge --no-ff "refs/tags/official-$upstream_tag" -m "实现：合并官方 $upstream_tag 并保留 KazumiT 定制"
fi
for file in lib/pages/player/double_tap_seek.dart lib/services/update/kazumit_update.dart test/kazumit_gestures_test.dart; do
  test -s "$file" || { echo "定制文件缺失：$file"; exit 1; }
done
source_sha=$(git rev-parse HEAD)
release_tag="kazumit-${upstream_tag}-${source_sha:0:8}"
if gh release view "$release_tag" >/dev/null 2>&1; then
  echo 'build=false' >> "$GITHUB_OUTPUT"
  exit 0
fi
mkdir -p build
printf '%s' "$upstream_tag" > build/upstream-tag.txt
printf 'build=true\ntag=%s\n' "$release_tag" >> "$GITHUB_OUTPUT"
