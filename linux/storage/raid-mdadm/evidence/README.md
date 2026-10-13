# Lab evidence / GitHub portfolio checklist

Replace these unchecked items with screenshots, terminal-output snippets, and a short write-up from **your own** VM. Do not publish test outputs as if they were performed until you have actually run the labs.

## RAID 1

- [ ] Screenshot: `lsblk` showing the lab virtual block devices.
- [ ] Screenshot/output: healthy array from `sudo mdadm --detail /dev/md110` and `[UU]` from `/proc/mdstat`.
- [ ] Screenshot/output: degraded state with one faulty member.
- [ ] Screenshot/output: rebuilt array with two active members.
- [ ] Terminal output: `Checksum: PASS` from `scripts/status.sh raid1`.

## RAID 5

- [ ] Screenshot/output: healthy array with three active members and `[UUU]`.
- [ ] Output: `df -h` demonstrating capacity close to two member disks.
- [ ] Screenshot/output: degraded state after one disk failure.
- [ ] Screenshot/output: completed rebuild and `Checksum: PASS`.

## Example summary (edit after completing the labs)

> **Environment:** Ubuntu Server [version], running on [hypervisor].
>
> **Objective:** Configure RAID 1 and RAID 5 using `mdadm`, test single-disk failure and recovery, and verify filesystem data using checksums.
>
> **Results:** [Write the actual number of active members, RAID state, usable capacity and checksum results here.]
>
> **Lessons learned:** [Explain mirroring vs. parity, the risk during a degraded rebuild, and why RAID is not backup.]

To save text evidence after each lab (run from repo root):

```bash
sudo bash scripts/status.sh raid1 | tee evidence/raid1-status.txt
sudo bash scripts/status.sh raid5 | tee evidence/raid5-status.txt
```

**Tip:** Save screenshots as `evidence/raid1-healthy.png`, `evidence/raid1-recovered.png`, `evidence/raid5-healthy.png`, and `evidence/raid5-recovered.png` (only if you have captured them). Check terminal logs for usernames, hostnames or other private details before uploading.
