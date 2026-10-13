# Lab 1 — Create, degrade, and rebuild RAID 1

## Objective

Build an ext4 filesystem on a two-member software RAID 1 mirror. Deliberately fail one **file-backed virtual disk**, verify that a test file is still readable, replace the disk, and confirm the completed rebuild.

### RAID 1: what happens?

```text
           /dev/md110  (one logical block device)
                  |
              RAID 1 mirror
               /       \
        disk1.img     disk2.img     disk3.img
          active        active     unused replacement

          Both active members contain mirrored data.
```

- **Minimum active members:** 2 for this lab.
- **Capacity:** ~1 × 256 MiB (less overhead).
- **Failure tolerance:** either *one* active member may fail; array is degraded until rebuilt.

## Procedure

### 1. Inspect the Linux VM

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
cat /proc/mdstat
mdadm --version
```

Ensure `/dev/md110` is not in use. The automation only creates loop devices backed by files and refuses to overwrite an existing md array.

### 2. Create the mirror

From the repository root:

```bash
sudo bash scripts/create.sh raid1
```

The script performs these operations:

1. Creates **three distinct 256 MiB image files** in `/var/tmp/mdadm-homelab/raid1/`.
2. Attaches each image to its own `/dev/loopN` device (the numeric names vary by machine).
3. Runs `mdadm --create /dev/md110 --level=1 --raid-devices=2` with the first **two** loop devices.
4. Waits for initialization, creates ext4, and mounts `/dev/md110` at `/mnt/mdadm-homelab-raid1`.
5. Writes `test.txt` and its `checksums.sha256`; leaves the third virtual disk unused as a replacement.

For learning purposes, the central RAID command is equivalent to the following, **where the variables must refer to your freshly created loop devices** (do not run again against the active array):

```bash
sudo mdadm --create /dev/md110 --level=1 --raid-devices=2 "$DISK1" "$DISK2"
```

### 3. Verify RAID health and file integrity

```bash
sudo bash scripts/status.sh raid1
cat /proc/mdstat
sudo mdadm --detail /dev/md110
sudo ls -l /mnt/mdadm-homelab-raid1
sudo cat /mnt/mdadm-homelab-raid1/test.txt
```

Expected characteristics:

- `Raid Level : raid1`
- `Raid Devices : 2`, `Active Devices : 2` after initialization
- `[UU]` in `/proc/mdstat` for the two active members
- `Checksum: PASS` from the status script

Some status displays may show `resync` briefly while the mirror initializes.

### 4. Simulate a disk failure

```bash
sudo bash scripts/fail-and-rebuild.sh raid1
```

After you confirm `FAIL-raid1`, the script performs the equivalent of:

```bash
sudo mdadm --manage /dev/md110 --fail "$DISK2"
sudo mdadm --manage /dev/md110 --remove "$DISK2"
sudo mdadm --manage /dev/md110 --add "$REPLACEMENT_DISK"
```

`$DISK2` and `$REPLACEMENT_DISK` are **loop devices derived from this lab's image files**, not fixed `/dev/loop0` assumptions. The automation displays degraded status **and verifies the stored checksum before removing the failed member**. It pauses for you to capture the degraded state, then adds the replacement, waits for recovery, and verifies the checksum again.

Manual simulation on real disks must only be done in a disposable VM; **never test disk failure on important drives.**

### 5. Record results

```bash
sudo bash scripts/status.sh raid1
sudo mdadm --detail /dev/md110
cat /proc/mdstat
```

You should again see `Active Devices : 2`, both members operational and `[UU]` once rebuilding completes. The test file should have the same SHA-256 checksum as before the failure.

### 6. Clean up

```bash
sudo bash scripts/cleanup.sh raid1
```

Type `DELETE-raid1` when prompted. It unmounts the filesystem, stops the array, detaches only lab-owned loop devices, and removes only the recognized image files. It doesn't change mdadm boot configuration or `/etc/fstab`.

## Exercises / questions for your GitHub notes

1. Why is RAID 1 usable capacity approximately that of one member disk?
2. What changed in `mdadm --detail` between the healthy and degraded states?
3. Why does the test file remain available when one active member fails?
4. How is redundancy restored after adding the replacement disk?
5. Why isn't RAID 1 equivalent to a backup?

**Success criteria:** You can show a healthy array, a degraded array, a restored array, and a verified SHA-256 checksum.
