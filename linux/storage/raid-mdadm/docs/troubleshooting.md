# Troubleshooting and safe operating notes

## `mdadm: command not found`

On Ubuntu/Debian run `sudo apt update && sudo apt install -y mdadm e2fsprogs util-linux`.

## `losetup: cannot find an unused loop device` or `operation not permitted`

Run from a real Linux VM with root privileges. Containers and some WSL setups don't expose loop block devices or RAID kernel capabilities. Inspect with `ls -l /dev/loop-control` and `sudo losetup --list`. Don't manually invent `/dev/loop0`: script-assigned device numbers vary by machine.

## Script refuses to create the lab

The scripts reserve `/dev/md110`, `/dev/md111`, and `/var/tmp/mdadm-homelab/`. Refusal means one of those names is already in use or previous lab files remain. Inspect with `cat /proc/mdstat`, `lsblk`, `sudo losetup --list`, and `sudo ls -la /var/tmp/mdadm-homelab/`. Do **not** bypass the safety checks or use `mdadm --force` on real drives.

If a script fails partway through, inspect the state before cleanup. The cleanup script may refuse to act if the first lab disk is no longer an array member or the array differs from the expected one. That refusal is intentional. Investigate rather than using `rm -rf` on files that may still back live loop devices.

## What do `[UU]`, `[U_]`, and `[UUU]` mean?

For RAID 1 with two members, `[UU]` means both expected slots are active; `[U_]` means one is unavailable. For RAID 5 with three members, `[UUU]` means all are present; `[U_U]` shows one unavailable. Also look at `mdadm --detail /dev/md110` or `/dev/md111` for precise member state, such as `faulty`, `spare rebuilding`, or `active sync`.

## The rebuild finishes before I can see it

The lab uses small 256 MiB image disks, so recovery may complete very quickly. View the degraded state printed by `fail-and-rebuild.sh`, or use larger disposable virtual disks in a separate manual lab if you want to study sustained rebuild activity. Avoid interrupting recovery just to capture a screenshot.

## `mount: wrong fs type` or unexpected mount source

Use `lsblk -f`, `sudo blkid`, and `findmnt`. Only format the array device **once**, on initial creation. Do not run `mkfs.ext4` to solve a post-failure mount issue: formatting would erase its data. The scripts reject an unexpected filesystem mounted at the lab mount path.

## Array unexpectedly absent after reboot

File-backed loop images are **not persistent loop devices**. The scripts don't create a boot-time reattachment service. For reboot persistence, use the [VM-attached disk lab](vm-attached-disks.md). `mdadm.conf` does not automatically reconnect loop devices to image files.

## Safety reminder

RAID provides **availability and redundancy**, not a backup. Check member identity before `--fail`, `--remove`, `--add`, and especially before `--create` or `mkfs`. Maintain an independent backup of real data.
