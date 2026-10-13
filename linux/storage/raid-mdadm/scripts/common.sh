#!/usr/bin/env bash
# Sourced by other scripts. Do not execute directly.
set -euo pipefail

LAB_BASE=/var/tmp/mdadm-homelab
MARKER_TEXT='owned-by-raid-mdadm-homelab-v1'

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
require_root() { (( EUID == 0 )) || fail 'Run with sudo, e.g. sudo bash scripts/create.sh raid1'; }
require_tools() {
  local tool
  for tool in mdadm losetup truncate mkfs.ext4 mount umount mountpoint findmnt sha256sum grep; do
    command -v "$tool" >/dev/null 2>&1 || fail "Missing $tool (on Ubuntu/Debian: sudo apt install mdadm e2fsprogs util-linux)"
  done
}
select_lab() {
  [[ $# -eq 1 ]] || fail 'Specify exactly one lab: raid1 or raid5'
  LAB="$1"
  case "$LAB" in
    raid1) MD=/dev/md110; RAID_LEVEL=1; ACTIVE=2; TOTAL=3; LABEL=HLAB_RAID1 ;;
    raid5) MD=/dev/md111; RAID_LEVEL=5; ACTIVE=3; TOTAL=4; LABEL=HLAB_RAID5 ;;
    *) fail "Unknown lab '$LAB'. Choose raid1 or raid5." ;;
  esac
  LAB_DIR="$LAB_BASE/$LAB"
  MOUNT_DIR="/mnt/mdadm-homelab-$LAB"
  MARKER="$LAB_DIR/.lab-owner"
}
ensure_owned() {
  [[ -f "$MARKER" ]] && [[ "$(cat "$MARKER")" == "$MARKER_TEXT" ]] \
    || fail "Lab ownership marker not found at $MARKER; refusing to change storage."
}
get_loop() {
  local img="$LAB_DIR/disk${1}.img" names
  [[ -f "$img" ]] || fail "Missing lab image: $img"
  names="$(losetup --list --associated "$img" --output NAME --noheadings --raw)" \
    || fail "Could not list loop devices for $img"
  [[ -n "$names" && "$names" != *$'\n'* ]] \
    || fail "Expected exactly one attached loop device for $img."
  printf '%s\n' "$names"
}
array_is_active() { mdadm --detail "$MD" >/dev/null 2>&1; }
ensure_our_array() {
  local member
  array_is_active || fail "$MD is not active."
  member="$(get_loop 1)"
  # Strong guardrail: do not operate on an unrelated array using our reserved md number.
  mdadm --detail "$MD" | grep -Fq -- "$member" \
    || fail "$MD does not list the lab's first backing disk ($member); refusing to modify it."
}
verify_mount() {
  local source
  mountpoint -q "$MOUNT_DIR" || fail "$MOUNT_DIR is not mounted."
  source="$(findmnt --noheadings --output SOURCE --target "$MOUNT_DIR")"
  [[ "$source" == "$MD" ]] \
    || fail "Unexpected filesystem mounted on $MOUNT_DIR: $source."
}
verify_file() {
  (cd "$MOUNT_DIR" && sha256sum --check --status checksums.sha256) \
    || fail 'Checksum validation failed: expected data is missing or changed.'
}
