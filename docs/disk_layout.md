# Disk addressing

This document describes the physical layout of disks and how to access data on them.

## CHS (Cylinder-Head-Sector)

CHS is used by old BIOSes to access floppy disks, hard disks and optical disks, but it is not used
by modern BIOSes or operating systems. This addressing method no longer matches the physical layout
of the disks, but it is still used by many disk utilities.

- **Tracks** - concentric rings on the disk surface
- **Sectors** - pie-shaped wedges on the disk surface
- **Cylinders** - a set of tracks with the same diameter on all surfaces
- **Platters** - a hard disk consists of one or more platters (disks)
- **Heads** - each platter has one or two surfaces, each surface is called a head

Sectors can be accessed by specifying the cylinder, head and sector number. This is
called CHS (Cylinder-Head-Sector) addressing, and it can only be used to access the
first 8 GB of the disk:

- **C (cylinder)** - 10 bits (0-1023)
- **H (Head)** - 8 bits (0-254), formerly 4 bits (0-15)
- **S (Sector)** - 6 bits (1-63)

```
1024 * 256 * 63 * 512 = 8,455,716,864 bytes ~= 8 GB
```

Cylinders are numbered starting from 0, heads are numbered starting from 0 and sectors
are numbered starting from 1.

The following image shows the physical layout:

![Disk layout](/images/cylinder_head_sector.png)

## LBA (Logical Block Addressing)

LBA is the most common addressing method used by modern BIOSes and operating systems. It is used to
access the entire disk, not just the first 8 GB.

LBA is a simple linear addressing scheme. The disk is addressed as a single, large device, which is
divided into sectors of 512 bytes starting from 0.

## LBA to CHS conversion

The following formulas can be used to convert between LBA and CHS:

```
sector = (LBA % sectors_per_track) + 1
head = (LBA / sectors_per_track) % number_of_heads
cylinder = (LBA / sectors_per_track) / number_of_heads
```