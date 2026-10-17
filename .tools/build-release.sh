#!/usr/bin/env bash
# Builds a release zip with every addon as its own top-level folder:
#   EllesmereUI/  EllesmereUIActionBars/  EllesmereUIUnitFrames/  ...
# 3.3.5a can't load nested addons, so users just extract into Interface/AddOns.
#
# Usage: .tools/build-release.sh [version] [ref]
#   version defaults to the ## Version of EllesmereUI.toc
#   ref     defaults to HEAD (only tracked files are packaged)
# Prints the path of the created zip on the last line.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

VERSION="${1:-$(sed -n 's/^## Version: //p' EllesmereUI.toc | tr -d '\r')}"
REF="${2:-HEAD}"
OUT_DIR="$REPO_ROOT/dist"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# Dev-only files that live in the repo but must not ship.
EXCLUDES=(
    .github .gitignore .gitattributes .pkgmeta .tools tools docs
    install.sh install.bat AGENTS.md CLAUDE.md README.md todo.md
    PERF_NOTES.md CONTRIBUTING_TRANSLATIONS.md Locales/_keys.txt
)

mkdir -p "$STAGE/EllesmereUI"
git archive "$REF" | tar -x -C "$STAGE/EllesmereUI"

# If the working tree has uncommitted TOC edits (e.g. update-version.sh ran in
# CI), prefer them so the shipped version matches the release name.
if [[ "$REF" == "HEAD" ]]; then
    while IFS= read -r toc; do
        [[ -f "$STAGE/EllesmereUI/$toc" ]] && cp "$toc" "$STAGE/EllesmereUI/$toc"
    done < <(git ls-files '*.toc')
fi

for path in "${EXCLUDES[@]}"; do
    rm -rf "${STAGE:?}/EllesmereUI/$path"
done

# Hoist every sub-addon (folder containing <name>/<name>.toc) to the top level.
addons=(EllesmereUI)
for dir in "$STAGE"/EllesmereUI/*/; do
    name="$(basename "$dir")"
    if [[ -f "$dir/$name.toc" ]]; then
        mv "$dir" "$STAGE/$name"
        addons+=("$name")
    fi
done

mkdir -p "$OUT_DIR"
ZIP="$OUT_DIR/EllesmereUI-${VERSION}.zip"
rm -f "$ZIP"
if command -v zip >/dev/null; then
    (cd "$STAGE" && zip -qr -9 "$ZIP" "${addons[@]}")
else
    (cd "$STAGE" && python3 -c '
import os, sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for top in sys.argv[2:]:
        for root, _, files in os.walk(top):
            for f in sorted(files):
                z.write(os.path.join(root, f))
' "$ZIP" "${addons[@]}")
fi

echo "Packaged ${#addons[@]} addons: ${addons[*]}" >&2
echo "$ZIP"
