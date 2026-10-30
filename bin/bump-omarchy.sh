#!/usr/bin/env bash
# Pin the adapter to another Omarchy release: release.sh, PKGBUILD and README.
# Usage: bin/bump-omarchy.sh [VERSION]   (default: latest stable vX.Y.Z tag)
set -eEuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
source "$SCRIPT_DIR/release.sh"
old_version=$OMARCHY_VERSION old_commit=$OMARCHY_COMMIT

tags=$(git ls-remote --tags "$OMARCHY_REPO")
version=${1:-}
version=${version#v}
if [[ -z $version ]]; then
  version=$(sed -n 's|.*refs/tags/v\([0-9]\+\.[0-9]\+\.[0-9]\+\)$|\1|p' <<< "$tags" | sort -V | tail -1)
  [[ -n $version ]] || { echo "No stable tag found in $OMARCHY_REPO" >&2; exit 1; }
fi
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || { echo "Invalid version: $version" >&2; exit 1; }
# Annotated tags list the commit on the peeled ^{} line.
commit=$(awk -v t="refs/tags/v$version^{}" '$2 == t {print $1}' <<< "$tags")
[[ -n $commit ]] || commit=$(awk -v t="refs/tags/v$version" '$2 == t {print $1}' <<< "$tags")
[[ -n $commit ]] || { echo "Tag v$version not found in $OMARCHY_REPO" >&2; exit 1; }

if [[ $version == "$old_version" && $commit == "$old_commit" ]]; then
  echo "Already at Omarchy v$version ($commit)."
  exit 0
fi
if [[ $version == "$old_version" ]]; then
  echo "Tag v$version moved from $old_commit to $commit. Stopping." >&2
  exit 1
fi
newest=$(printf '%s\n' "$old_version" "$version" | sort -V | tail -1)
[[ $newest == "$version" ]] || echo "Warning: v$version is older than v$old_version." >&2

# Same checksum makepkg computes for a git source pinned to a commit.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git init -q --bare "$work/omarchy.git"
git -C "$work/omarchy.git" fetch -q --depth 1 "$OMARCHY_REPO" "refs/tags/v$version"
sum=$(git -c core.abbrev=no -C "$work/omarchy.git" archive --format tar "$commit" | sha256sum)
sum=${sum%% *}

pkgbuild=$PROJECT_DIR/pkgbuilds/omarchy-cachyos/PKGBUILD
sed -i "s/^OMARCHY_VERSION=.*/OMARCHY_VERSION=$version/; s/^OMARCHY_COMMIT=.*/OMARCHY_COMMIT=$commit/" \
  "$SCRIPT_DIR/release.sh"
# pkgver may not contain '-': 4.5.0-rc2 becomes 4.5.0rc2, which sorts before 4.5.0.
sed -i "s/^pkgver=.*/pkgver=${version//-/}/; s/^pkgrel=.*/pkgrel=1/; s/^_commit=.*/_commit=$commit/; \
  s/^sha256sums=('[0-9a-f]\{64\}'/sha256sums=('$sum'/" "$pkgbuild"
old=${old_version//./\\.}
sed -i "s/$old_commit/$commit/g; s/\*\*$old (Quattro)\*\*/**$version (Quattro)**/; s/\`v$old\`/\`v$version\`/g; \
  s/fuentes reales de $old/fuentes reales de $version/; s/source-$old/source-$version/g" "$PROJECT_DIR/README.md"

grep -q "^sha256sums=('$sum'" "$pkgbuild" || { echo "Could not update sha256sums in $pkgbuild" >&2; exit 1; }
for patch in "$PROJECT_DIR"/pkgbuilds/omarchy-cachyos/*.patch; do
  [[ ! -f $patch ]] || echo "Check that ${patch##*/} is still needed and still applies." >&2
done
echo "Omarchy v$old_version -> v$version ($commit)"
