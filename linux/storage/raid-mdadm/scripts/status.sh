#!/usr/bin/env bash
# Show read-only RAID details; checksum test may read from filesystem.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_root
require_tools
select_lab "$@"
ensure_owned
ensure_our_array
printf '=== Kernel arrays ===\n'
cat /proc/mdstat
printf '\n=== Detailed status: %s ===\n' "$MD"
mdadm --detail "$MD"
printf '\n=== Filesystem ===\n'
if mountpoint -q "$MOUNT_DIR"; then
  verify_mount
  df -h "$MOUNT_DIR"
  verify_file
  printf 'Checksum: PASS\n'
else
  printf '%s is not mounted\n' "$MOUNT_DIR"
fi
printf '\n=== Loop devices ===\n'
for ((i=1; i<=TOTAL; i++)); do
  printf 'disk%s.img -> %s\n' "$i" "$(get_loop "$i")"
done
