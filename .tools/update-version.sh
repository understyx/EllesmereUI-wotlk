#!/usr/bin/env bash
set -euo pipefail

BASE_VERSION="8.6.4-wotlk"
REPO_ROOT="$(git rev-parse --show-toplevel)"
COMMIT_DATE="$(TZ=UTC git -C "$REPO_ROOT" log -1 --date=format:%Y%m%d --format=%cd)"
VERSION="${BASE_VERSION}.${COMMIT_DATE}"
CHECK_ONLY=false

if [[ "${1:-}" == "--check" ]]; then
    CHECK_ONLY=true
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--check]" >&2
    exit 2
fi

cd "$REPO_ROOT"

outdated=()
while IFS= read -r toc_file; do
    # Bundled libraries own their version metadata.
    if [[ "$toc_file" == Libs/* ]]; then
        continue
    fi

    expected="## Version: $VERSION"
    current="$(grep -m 1 '^## Version:' "$toc_file" || true)"
    if [[ "$current" == "$expected" ]]; then
        continue
    fi

    outdated+=("$toc_file")
    if [[ "$CHECK_ONLY" == false ]]; then
        temp_file="${toc_file}.version-tmp"
        awk -v version="$VERSION" '
            BEGIN { found = 0 }
            /^## Version:/ {
                print "## Version: " version
                found = 1
                next
            }
            { print }
            END { if (!found) exit 1 }
        ' "$toc_file" > "$temp_file"
        mv "$temp_file" "$toc_file"
    fi
done < <(git ls-files '*.toc')

if [[ "$CHECK_ONLY" == true && ${#outdated[@]} -gt 0 ]]; then
    echo "Expected version $VERSION in:" >&2
    printf '  %s\n' "${outdated[@]}" >&2
    exit 1
fi

if [[ "$CHECK_ONLY" == true ]]; then
    echo "All addon TOCs use $VERSION"
else
    echo "Set addon version to $VERSION in ${#outdated[@]} TOC file(s)"
fi
