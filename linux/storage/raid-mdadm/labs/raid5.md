# Lab 2 — Create, degrade, and rebuild RAID 5

## Objective

Build a three-member RAID 5 array from virtual disks, observe distributed parity and usable capacity, simulate a single disk failure, rebuild the array with a replacement, and validate data integrity.

### RAID 5: what happens?

RAID 5 stripes data and distributed parity across disks. The parity information allows reconstruction when **one** active member is unavailable.

```text
                 /dev/md111
                     |
              RAID 5 (3 disks)
                 /   |   \
            disk1  disk2  disk3       disk4
            active active active     unused replacement

Simplified stripes:
  stripe A:   data    data    parity
  stripe B:   data    parity  data
  stripe C:   parity  data    data
```

- **Minimum disks:** 3 for standard RAID 5.
- **Capacity:** `(3 - 1) × 256 MiB` ≈ 512 MiB (before metadata/filesystem overhead).
- **Failure tolerance:** one active member; a second failure before recovery can make the array unavailable and cause data loss.

## Procedure

### 1. Inspect the Linux VM

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
cat /proc/mdstat
mdadm --version
```

Make sure `/dev/md111` is not being used by another array.

### 2. Create RAID 5

```bash
sudo bash scripts/create.sh raid5
```

Behind the scenes, the script:

1. Creates **four separate 256 MiB image files**, with three active and one unused replacement.
2. Attaches them to loop devices using `losetup --find --show --nooverlap`.
3. Creates `/dev/md111` at RAID level 5 with **three active members**.
4. Waits for array initialization before creating and mounting ext4.
5. Writes a test file and SHA-256 checksum.

The key command, shown for study only, is:

```bash
sudo mdadm --create /dev/md111 --level=5 --raid-devices=3 "$DISK1" "$DISK2" "$DISK3"
```

The variables stand for the actual loop devices displayed by the script. **Do not re-run this command after the array has been created.**

### 3. Confirm the array is healthy

```bash
sudo bash scripts/status.sh raid5
cat /proc/mdstat
sudo mdadm --detail /dev/md111
sudo df -h /mnt/mdadm-homelab-raid5
```

Look for:

- `Raid Level : raid5`
- `Raid Devices : 3` and `Active Devices : 3`
- `[UUU]` in `/proc/mdstat` after initialization
- A filesystem capacity close to (but less than) **512 MiB**
- `Checksum: PASS`

### 4. Simulate one member failure and rebuild

```bash
sudo bash scripts/fail-and-rebuild.sh raid5
```

After confirming `FAIL-raid5`, the script:

1. Marks the second **lab-owned loop member** as faulty using `mdadm --manage --fail`.
2. Displays the degraded array and verifies the file checksum while running with one member absent.
3. Pauses so you can capture the degraded state, then removes the failed member from the RAID assembly.
4. Adds the unused fourth loop device as the replacement.
5. Waits for reconstruction and verifies the file again.

Equivalent commands, shown for reference only:

```bash
sudo mdadm --manage /dev/md111 --fail "$DISK2"
sudo mdadm --manage /dev/md111 --remove "$DISK2"
sudo mdadm --manage /dev/md111 --add "$REPLACEMENT_DISK"
```

Observe rebuild activity with:

```bash
cat /proc/mdstat
sudo mdadm --detail /dev/md111
```

Because the images are small, you may not see the rebuilding progress bar before completion. That is normal.

### 5. Validate successful recovery

```bash
sudo bash scripts/status.sh raid5
cat /proc/mdstat
```

Successful final state: three operational RAID 5 members, `[UUU]`, and `Checksum: PASS`. The removed second image remains attached to a loop device until cleanup but is **not** an active array member after the replacement.

### 6. Clean up

```bash
sudo bash scripts/cleanup.sh raid5
```

Type `DELETE-raid5` when prompted. The script stops the lab array, detaches its own loop devices, and deletes the disposable image files.

## Exercises / questions for your GitHub notes

1. Why does RAID 5 require at least three disks?
2. Why is the approximate usable capacity `(N - 1) × smallest member size`?
3. How is RAID 5 able to read data when one disk fails?
4. What risk remains while the array is degraded and rebuilding?
5. How does RAID 5 differ from RAID 1 in capacity and recovery overhead?

**Success criteria:** You can demonstrate parity-based RAID 5, usable capacity, a degraded state, a completed rebuild, and an unchanged SHA-256 checksum.
