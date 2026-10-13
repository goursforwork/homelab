#!/usr/bin/env bash
# Create RAID from FILE-backed loop devices only; never receives physical-disk names.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_root
require_tools
select_lab "$@"
[[ ! -e "$LAB_DIR" ]] || fail "$LAB_DIR exists. Run cleanup if it belongs to this lab; no files overwritten."
[[ ! -e "$MD" ]] && [[ ! -e "/sys/block/${MD##*/}" ]] \
  || fail "$MD already exists. Choose a clean disposable Linux VM."
if [[ -d "$MOUNT_DIR" ]]; then
  mountpoint -q "$MOUNT_DIR" && fail "$MOUNT_DIR is already mounted."
  [[ -z "$(ls -A "$MOUNT_DIR")" ]] || fail "$MOUNT_DIR exists and is not empty."
fi

install -d -m 0700 "$LAB_BASE" "$LAB_DIR"
printf '%s\n' "$MARKER_TEXT" > "$MARKER"
mkdir -p "$MOUNT_DIR"
loops=()
for ((i=1; i<=TOTAL; i++)); do
  image="$LAB_DIR/disk${i}.img"
  truncate -s 256M "$image"
  loops+=("$(losetup --find --show --nooverlap "$image")")
done

printf 'Creating RAID%s on %s from virtual disks: %s\n' "$RAID_LEVEL" "$MD" "${loops[*]:0:ACTIVE}"
mdadm --create "$MD" --metadata=1.2 --name="homelab_$LAB" \
  --level="$RAID_LEVEL" --raid-devices="$ACTIVE" --run "${loops[@]:0:ACTIVE}"
mdadm --wait "$MD"
mkfs.ext4 -F -L "$LABEL" "$MD"
mount -t ext4 "$MD" "$MOUNT_DIR"
printf 'mdadm home lab %s: checksum validation works after a single member failure.\n' "$LAB" \
  > "$MOUNT_DIR/test.txt"
(cd "$MOUNT_DIR" && sha256sum test.txt > checksums.sha256)
verify_mount
verify_file

printf '\nCreated and mounted %s at %s\n' "$MD" "$MOUNT_DIR"
printf 'Members: %s\n' "${loops[*]:0:ACTIVE}"
printf 'Unused replacement disk: %s\n\n' "${loops[$ACTIVE]}"
cat /proc/mdstat
printf '\nNext: sudo bash scripts/fail-and-rebuild.sh %s\n' "$LAB"
