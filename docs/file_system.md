# File system

A file system is a way of storing and organizing files on a storage device,
such as a hard drive, USB drive, or SD card. The file system defines how files
are named, organized, and stored on a storage medium. It also determines the
way files are accessed and updated. Common file systems include the FAT family,
NTFS, HFS+, APFS and the ext family.

## FAT12

FAT12 is a simple file system with many limitations. It supports file names
up to 8 characters long with a 3 character extension. It also supports a
maximum of 4,096 files per directory and a maximum volume size of 16 MB. FAT12
is also inefficient with storage space, since it uses 12 bits to store each
cluster address. This means that on a 16 MB volume, each cluster is 4 KB in
size, but 12 bits are used to store the cluster address, which means 4 bits
are wasted.

### Structure

The FAT12 file system is divided into four main regions:
- **Reserved sectors** - contains the boot sector and other reserved sectors.
- **FAT (File Allocation Table) region** - contains the file allocation table.
- **Root directory region** - a Directory Table that stores information about
  the files and directories in the root directory.
- **Data region** - contains the actual file and directory data.

### Reading data

To read a file from a FAT12 volume, you must first locate the file's directory
entry in the root directory. The directory entry contains the file's name,
extension, size, and starting cluster number. The starting cluster number is
used to locate the first cluster of the file in the FAT. The FAT contains a
list of cluster numbers, where each cluster number points to the next cluster
in the file. The last cluster in the file contains a special value that
indicates the end of the file. The data region contains the actual file data.
To read the file, you must read the data from each cluster in the file.
