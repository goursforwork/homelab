#!/usr/bin/env bash
# Intentionally fails the second member of our file-backed lab array, then rebuilds.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_root
require_tools
select_lab "$@"
ensure_owned
ensure_our_array
verify_mount
[[ ! -f "$LAB_DIR/.rebuild-done" ]] || fail 'Rebuild already performed. Run cleanup and create a fresh lab.'
failed_member="$(get_loop 2)"
replacement="$(get_loop "$TOTAL")"
mdadm --detail "$MD" | grep -Fq -- "$failed_member" \
  || fail "$failed_member is not a current array member; refusing to fail it."
if mdadm --detail "$MD" | grep -Fq -- "$replacement"; then
  fail "$replacement is already part of $MD."
fi
verify_file
printf 'About to mark %s FAULTY and remove it from %s.\n' "$failed_member" "$MD"
printf 'It is a disposable file-backed virtual disk, not a physical drive.\n'
read -r -p "Type FAIL-$LAB to continue: " confirmation
[[ "$confirmation" == "FAIL-$LAB" ]] || fail 'Confirmation did not match; no RAID member failed.'

mdadm --manage "$MD" --fail "$failed_member"
printf '\nDegraded array after failure:\n'
mdadm --detail "$MD"
verify_file
printf 'File checksum still matches while degraded.\n'
printf 'Capture a screenshot of this degraded array now for GitHub evidence.\n'
read -r -p 'Press Enter to remove the failed member and rebuild: ' _
mdadm --manage "$MD" --remove "$failed_member"
mdadm --manage "$MD" --add "$replacement"
printf '\nRebuilding with replacement %s ...\n' "$replacement"
mdadm --wait "$MD"
ensure_our_array
verify_mount
verify_file
printf '%s\n' 'done' > "$LAB_DIR/.rebuild-done"
printf '\nRebuild complete; checksum still matches.\n'
mdadm --detail "$MD"
printf '\nNext: sudo bash scripts/status.sh %s\n' "$LAB"
