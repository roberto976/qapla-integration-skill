#!/usr/bin/env bash
# sync-docs.sh — freshness checklist for the qapla-integration reference files.
#
# The live docs at api.qapla.dev / webhook.qapla.dev are the authoritative source.
# The references/*.md files are a synced working copy, each stamped with a `synced:` date.
# This script lists every reference, its `source:` URL and `synced:` date, so a maintainer
# can re-fetch the live page on each Qapla' API release and bump the date.
#
# It does NOT auto-fetch — it is a guided checklist runner (no network, no dependencies).
#
# Usage:  ./sync-docs.sh

set -euo pipefail

ref_dir="$(cd "$(dirname "$0")/../references" && pwd)"

printf '%-22s %-32s %s\n' "FILE" "SOURCE" "SYNCED"
printf '%-22s %-32s %s\n' "----" "------" "------"

for f in "$ref_dir"/*.md; do
  name="$(basename "$f")"
  source="$(grep -m1 '^source:' "$f" | sed 's/^source:[[:space:]]*//')"
  synced="$(grep -m1 '^synced:' "$f" | sed 's/^synced:[[:space:]]*//')"
  printf '%-22s %-32s %s\n' "$name" "${source:-<missing>}" "${synced:-<missing>}"
done

cat <<'NOTE'

To refresh after a Qapla' API release:
  1. Open each SOURCE url above and diff it against the reference file.
  2. Update changed endpoints/fields in the reference.
  3. Bump the `synced:` date in that file's header.
  4. Commit. If an endpoint's version changed, also update references/versioning.md.

The live docs always win over these files when they disagree.
NOTE
