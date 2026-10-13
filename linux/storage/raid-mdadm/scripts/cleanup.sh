#!/usr/bin/env bash
# Remove ONLY the images and mount point created by this repository.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_root
require_tools
select_lab "$@"
ensure_owned
if array_is_active; then
  ensure_our_array
fi
if mountpoint -q "$MOUNT_DIR"; then
  verify_mount
fi
printf 'This removes disposable %s lab data under %s and stops %s.\n' "$LAB" "$LAB_DIR" "$MD"
read -r -p "Type DELETE-$LAB to continue: " confirmation
[[ "$confirmation" == "DELETE-$LAB" ]] || fail 'Confirmation did not match; nothing deleted.'

if mountpoint -q "$MOUNT_DIR"; then
  umount "$MOUNT_DIR"
fi
if array_is_active; then
  mdadm --stop "$MD"
fi
for ((i=1; i<=TOTAL; i++)); do
  image="$LAB_DIR/disk${i}.img"
  [[ -f "$image" ]] || fail "Missing $image; stopping to avoid removing an unknown path."
  loopdev="$(get_loop "$i")"
  losetup --detach "$loopdev"
  [[ -z "$(losetup --list --associated "$image" --output NAME --noheadings --raw)" ]] \
    || fail "Loop device for $image is still attached. Refusing to delete images."
done
# Only delete known lab-created filenames; preserve unexpected files for inspection.
for ((i=1; i<=TOTAL; i++)); do
  rm -- "$LAB_DIR/disk${i}.img"
done
rm -f -- "$LAB_DIR/.rebuild-done" "$MARKER"
if ! rmdir "$LAB_DIR"; then
  printf 'Leftover files in %s were NOT deleted.\n' "$LAB_DIR" >&2
fi
rmdir "$MOUNT_DIR" 2>/dev/null || true
printf '\nRemoved disposable %s lab.\n' "$LAB"
