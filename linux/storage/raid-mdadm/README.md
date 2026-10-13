# Linux Software RAID Home Lab — RAID 1 and RAID 5 with `mdadm`

Hands-on Linux storage project for a GitHub home lab. Create software RAID arrays from **file-backed virtual disks**, format and mount them, simulate disk failure, rebuild using a replacement disk, and validate the stored data with SHA-256 checksums.

> **Safety:** Run this project inside a **disposable Linux VM**, not on a production machine. The included scripts create **new image files only** and never accept a physical disk path. `mdadm --create`, `mkfs`, disk removal, and cleanup commands can destroy data when used on the wrong devices. This is a learning lab, **not** a backup or a production-ready RAID design.

## Project goals

- Configure RAID 1 (mirroring) with two active virtual disks.
- Configure RAID 5 (distributed parity) with three active virtual disks.
- Recognize healthy, degraded, rebuilding, and recovered array states.
- Simulate a single member failure and replace it with an unused virtual disk.
- Check files before failure, during the degraded state, and after rebuilding.
- Learn the difference between temporary loopback disks and persistent VM-attached disks.

## Topology

| RAID | Active disks | Extra replacement | Approximate usable space* | Disk failures tolerated |
| --- | ---: | ---: | ---: | ---: |
| RAID 1 | 2 × 256 MiB | 1 × 256 MiB | ~256 MiB | 1 member |
| RAID 5 | 3 × 256 MiB | 1 × 256 MiB | ~512 MiB | 1 member |

*Before RAID metadata and filesystem overhead; actual `df -h` usable space is lower. Replacement disks are **not** members until the recovery exercise.

```text
RAID 1:                            RAID 5:
 virtual disk 1 ─┐                  virtual disk 1 ─┐
                 ├─ /dev/md110                     ├─ /dev/md111
 virtual disk 2 ─┘                  virtual disk 2 ─┤
                                                  │
 replacement disk ─ (unused)       virtual disk 3 ─┘
                                   replacement disk ─ (unused)

 Mounted: /mnt/mdadm-homelab-raid1     /mnt/mdadm-homelab-raid5
```

## Prerequisites

- Ubuntu Server or Debian Linux VM with root/sudo access.
- About 2 GiB of free disk space recommended, plus space for the VM (images are sparse but may consume space as RAID writes and synchronization occur).
- Linux loop and software RAID support (`/dev/loop-control`, `md_mod`); **some containers, WSL environments, and restricted VMs will not support these operations**.
- Internet access to install packages, if not already installed.

Install dependencies on Debian or Ubuntu:

```bash
sudo apt update
sudo apt install -y mdadm e2fsprogs util-linux
```

## Quick start

Run commands from this repository's **root** directory:

```bash
# RAID 1: create, inspect, deliberately fail a disk and recover
sudo bash scripts/create.sh raid1
sudo bash scripts/status.sh raid1
sudo bash scripts/fail-and-rebuild.sh raid1
sudo bash scripts/status.sh raid1

# RAID 5: create, inspect, deliberately fail a disk and recover
sudo bash scripts/create.sh raid5
sudo bash scripts/status.sh raid5
sudo bash scripts/fail-and-rebuild.sh raid5
sudo bash scripts/status.sh raid5

# Cleanup: requires an explicit DELETE-raid1 / DELETE-raid5 confirmation
sudo bash scripts/cleanup.sh raid1
sudo bash scripts/cleanup.sh raid5
```

The failure scripts prompt before faulting a member; they do **not** run unattended. You can complete either lab independently. Inspect what each script does before executing it as root.

**Where the virtual disks are stored:** `/var/tmp/mdadm-homelab/raid1/` and `/var/tmp/mdadm-homelab/raid5/`. The scripts reserve `/dev/md110` and `/dev/md111`. They refuse to overwrite an existing lab folder or an existing md device. The mount points are `/mnt/mdadm-homelab-raid1` and `/mnt/mdadm-homelab-raid5`.

## Lab instructions

| Document | What you will learn |
| --- | --- |
| [Lab 1: RAID 1](labs/raid1.md) | Mirroring, disk failure, rebuild and data verification |
| [Lab 2: RAID 5](labs/raid5.md) | Parity, usable capacity, degraded operation and rebuild |
| [Using actual virtual disks attached to a VM](docs/vm-attached-disks.md) | Manual `mdadm` commands, persistent assembly and fstab |
| [Troubleshooting](docs/troubleshooting.md) | Debugging loop devices, permissions and mdadm states |
| [Evidence template](evidence/README.md) | What terminal outputs and screenshots to save in GitHub |
| [GitHub upload guide](GITHUB-UPLOAD.md) | Add the labs to an existing home-lab repository or make a new repo |

## Important validation commands

```bash
cat /proc/mdstat                       # RAID status and rebuild progress
sudo mdadm --detail /dev/md110         # RAID 1 details
sudo mdadm --detail /dev/md111         # RAID 5 details
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
sudo df -h /mnt/mdadm-homelab-raid1
sudo df -h /mnt/mdadm-homelab-raid5
```

In `/proc/mdstat`, `[UU]` is healthy for a two-disk mirror and `[UUU]` is healthy for a three-disk RAID 5. An underscore indicates a missing or unavailable active member (such as `[U_]` or `[U_U]`). Use `mdadm --detail` to see the actual member states and rebuild progress.

## Persistence and backups

The **quick-start scripts intentionally do not modify** `/etc/mdadm/mdadm.conf`, `/etc/fstab`, or the initramfs. File-backed loop devices can disappear at reboot and are **not automatically reattached** just because an array is listed in `mdadm.conf`.

For a reboot-persistent exercise, attach separate virtual hard disks to a disposable VM and follow [the VM-attached disk guide](docs/vm-attached-disks.md). Configure array assembly, an ext4 filesystem UUID in `/etc/fstab`, and `update-initramfs` on Ubuntu/Debian as appropriate.

**RAID is not backup:** it does not protect against accidental deletion, filesystem corruption, ransomware, or loss of the host machine.

## Repo structure

```text
raid-mdadm-homelab/
├── .gitignore
├── GITHUB-UPLOAD.md
├── README.md
├── labs/
│   ├── raid1.md
│   └── raid5.md
├── docs/
│   ├── vm-attached-disks.md
│   └── troubleshooting.md
├── evidence/
│   └── README.md
└── scripts/
    ├── common.sh
    ├── create.sh
    ├── fail-and-rebuild.sh
    ├── status.sh
    └── cleanup.sh
```

## Skills demonstrated

Linux administration · software RAID · `mdadm` · block devices · ext4 · mounting filesystems · failure simulation · storage resilience · data integrity · Bash automation · technical documentation

## Further reading

- [`mdadm(8)` Linux manual](https://man7.org/linux/man-pages/man8/mdadm.8.html)
- [`losetup(8)` Linux manual](https://man7.org/linux/man-pages/man8/losetup.8.html)
- [Debian software RAID guidance](https://wiki.debian.org/SoftwareRAID)
