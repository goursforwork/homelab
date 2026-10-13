# Optional advanced lab — use disks attached to a virtual machine

Unlike the quick start, this manual lab creates RAID using **new virtual hard disks attached to a disposable Linux VM** (VirtualBox, VMware, Proxmox, Hyper-V, etc.). These virtual disks persist across VM reboots; this makes the exercise suitable for practicing array reassembly and automatic mounting.

> **Destructive commands ahead.** Only use **blank, disposable, dedicated virtual hard disks**. `mdadm --create` and `mkfs.ext4` overwrite filesystem/RAID metadata. Do NOT copy the example device identifiers blindly; never point these commands at the OS, boot, or important data disk. Take a VM snapshot first. Do not mix these instructions with the loopback quick start on the same md number.

## 1. Create virtual disks in the hypervisor

Add separate virtual hard disks to the VM, then boot Linux:

- RAID 1: **2** disks of 1 GiB each; optionally add a **third** replacement disk.
- RAID 5: **3** disks of 1 GiB each; optionally add a **fourth** replacement disk.

Use a different disposable VM for each manual exercise, or assign unique `/dev/mdN` names and do not reuse disks.

List actual devices and verify **which disk hosts the OS**:

```bash
lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,FSTYPE,TYPE,MOUNTPOINTS
sudo blkid
ls -l /dev/disk/by-id/
```

`/dev/sdb`, `/dev/sdc`, etc. are **not guaranteed**. Prefer verified `/dev/disk/by-id/...` paths for stable device identities. Confirm each new virtual disk is unmounted, not partitioned with important data, and not a member of an existing array.

## 2. Manually build RAID 1

Assign variables to **real, verified new VM data disks**. Placeholders below are deliberately not executable disk paths:

```bash
DISK1=/dev/disk/by-id/REPLACE_WITH_FIRST_NEW_VM_DISK
DISK2=/dev/disk/by-id/REPLACE_WITH_SECOND_NEW_VM_DISK

# Stop here and confirm both paths are the intended disposable VM disks.
lsblk -f "$DISK1" "$DISK2"

sudo mdadm --create /dev/md120 --metadata=1.2 --level=1 --raid-devices=2 "$DISK1" "$DISK2"
cat /proc/mdstat
sudo mdadm --wait /dev/md120
sudo mkfs.ext4 /dev/md120
sudo mkdir -p /mnt/manual-raid1
sudo mount /dev/md120 /mnt/manual-raid1
```

Check with `sudo mdadm --detail /dev/md120` and create test data on `/mnt/manual-raid1`.

## 3. Or manually build RAID 5

Use **three different**, verified blank VM disks:

```bash
DISK1=/dev/disk/by-id/REPLACE_WITH_FIRST_NEW_VM_DISK
DISK2=/dev/disk/by-id/REPLACE_WITH_SECOND_NEW_VM_DISK
DISK3=/dev/disk/by-id/REPLACE_WITH_THIRD_NEW_VM_DISK

lsblk -f "$DISK1" "$DISK2" "$DISK3"

sudo mdadm --create /dev/md121 --metadata=1.2 --level=5 --raid-devices=3 "$DISK1" "$DISK2" "$DISK3"
cat /proc/mdstat
sudo mdadm --wait /dev/md121
sudo mkfs.ext4 /dev/md121
sudo mkdir -p /mnt/manual-raid5
sudo mount /dev/md121 /mnt/manual-raid5
```

Check with `sudo mdadm --detail /dev/md121` and create test data on `/mnt/manual-raid5`.

## 4. Save array configuration for reboot assembly (Ubuntu/Debian)

Choose the array you actually created (e.g. `/dev/md120` or `/dev/md121`). **Do not append duplicates** if you repeat the exercise.

```bash
# Review existing configuration first.
sudo cat /etc/mdadm/mdadm.conf

# Preview ONLY this array's definition.
sudo mdadm --detail --scan /dev/md120

# RAID 1 example only: after confirming the definition isn't already saved.
sudo mdadm --detail --scan /dev/md120 | sudo tee -a /etc/mdadm/mdadm.conf
sudo update-initramfs -u
```

For RAID 5, use `/dev/md121` in both commands. The mdadm array definition (RAID UUID) helps automatic assembly on reboot. Do not add quick-start file-backed loop arrays here—those images are not reattached at boot.

## 5. Configure the filesystem to mount at boot

**Example for manual RAID 1:**

```bash
sudo blkid /dev/md120
sudo blkid -s UUID -o value /dev/md120
```

Copy the **filesystem UUID** (not the mdadm array UUID) into an `/etc/fstab` entry using `sudoedit /etc/fstab`:

```fstab
UUID=REPLACE_WITH_EXT4_FILESYSTEM_UUID /mnt/manual-raid1 ext4 defaults,nofail 0 2
```

For RAID 5, use the UUID of `/dev/md121` and the `/mnt/manual-raid5` mount point. Save and test before reboot:

```bash
sudo umount /mnt/manual-raid1       # Use your actual mount point
sudo mount -a
findmnt /mnt/manual-raid1
sudo mdadm --detail /dev/md120
```

Use the appropriate RAID 5 names if that is your array. Reboot the **disposable VM** and verify the array reassembled and the filesystem remounted. If the device appears as a different `/dev/mdN`, use its array UUID and check `mdadm --detail --scan` and your `mdadm.conf` rather than assuming a stable md number.

## 6. Practice a replacement (optional)

Once a **separate, blank replacement VM disk** is attached and its stable identifier is verified:

```bash
# Variables must be set to the actual member and replacement paths.
sudo mdadm --manage /dev/md120 --fail "$FAILED_MEMBER"
sudo mdadm --manage /dev/md120 --remove "$FAILED_MEMBER"
sudo mdadm --manage /dev/md120 --add "$NEW_REPLACEMENT"
sudo mdadm --wait /dev/md120
sudo mdadm --detail /dev/md120
```

Use `/dev/md121` for RAID 5. The commands above are intentionally incomplete without your own verified paths. Do not add a replacement that contains existing important data.

## Caution about loopback arrays and reboot

`mdadm.conf` alone does not create the `/dev/loopN` associations backing the quick-start images. Rebooting the file-backed lab can leave the array unassembled; this repo deliberately avoids installing startup services to recreate those associations. Run the quick-start labs, gather evidence, and clean up **before rebooting**. Use these VM-attached disks for the persistence exercise instead.
