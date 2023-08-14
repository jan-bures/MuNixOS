#include <ctype.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#pragma region Structure definitions

/**
 * @brief Boot sector of a FAT12/16 volume.
 */
typedef struct
{
	uint8_t jmp[3];           // 0x0000
	uint8_t oem[8];           // 0x0003
	uint16_t bytes;            // 0x000B
	uint8_t sectors;          // 0x000D
	uint16_t reserved;         // 0x000E
	uint8_t fats;             // 0x0010
	uint16_t root_entries;     // 0x0011
	uint16_t sectors_small;    // 0x0013
	uint8_t media;            // 0x0015
	uint16_t sectors_fat;      // 0x0016
	uint16_t sectors_track;    // 0x0018
	uint16_t heads;            // 0x001A
	uint32_t hidden;           // 0x001C
	uint32_t sectors_large;    // 0x0020
	uint8_t drive;            // 0x0024
	uint8_t reserved2;        // 0x0025
	uint8_t signature;        // 0x0026
	uint32_t volume_id;        // 0x0027
	uint8_t volume_label[11]; // 0x002B
	uint8_t fs_type[8];       // 0x0036
} __attribute__((packed)) BootSector;

/**
 * @brief Directory entry of a FAT12/16 volume.
 */
typedef struct
{
	uint8_t filename[8];          // 0x0000
	uint8_t ext[3];               // 0x0008
	uint8_t attributes;           // 0x000B
	uint8_t reserved;             // 0x000C
	uint8_t creation_time_tenths; // 0x000D
	uint16_t creation_time;        // 0x000E
	uint16_t creation_date;        // 0x0010
	uint16_t last_access_date;     // 0x0012
	uint16_t first_cluster_high;   // 0x0014
	uint16_t last_write_time;      // 0x0016
	uint16_t last_write_date;      // 0x0018
	uint16_t first_cluster_low;    // 0x001A
	uint32_t size;                 // 0x001C
} __attribute__((packed)) DirectoryEntry;

#pragma endregion

#pragma region Global variables

BootSector g_bootSector;
uint8_t* g_fat = NULL;
DirectoryEntry* g_root = NULL;
uint32_t g_rootEnd;

#pragma endregion

#pragma region FAT12 read functions

/**
 * @brief Reads the boot sector of a FAT12/16 volume.
 * @param disk
 * @return
 */
bool readBootSector(FILE* disk)
{
	return fread(&g_bootSector, sizeof(BootSector), 1, disk) > 0;
}

/**
 * @brief Reads sectors from a FAT12/16 volume.
 * @param disk
 * @param lba
 * @param count
 * @param buffer
 * @return
 */
bool readSectors(FILE* disk, uint32_t lba, uint8_t count, void* buffer)
{
	bool result = true;
	result &= fseek(disk, lba * g_bootSector.bytes, SEEK_SET) == 0;
	result &= fread(buffer, g_bootSector.bytes, count, disk) == count;
	return result;
}

/**
 * @brief Reads the FAT of a FAT12/16 volume.
 * @param disk
 * @return
 */
bool readFat(FILE* disk)
{
	g_fat = (uint8_t*)malloc(g_bootSector.sectors_fat * g_bootSector.bytes);
	return readSectors(disk, g_bootSector.reserved, g_bootSector.sectors_fat, g_fat);
}

bool readRootDirectory(FILE* disk)
{
	uint32_t lba = g_bootSector.reserved + g_bootSector.sectors_fat * g_bootSector.fats;
	uint32_t size = g_bootSector.root_entries * sizeof(DirectoryEntry);
	uint32_t sectors = size / g_bootSector.bytes;
	// Round up to the next sector.
	if (size % g_bootSector.bytes > 0) {
		sectors++;
	}

	g_rootEnd = lba + sectors;
	g_root = (DirectoryEntry*)malloc(sectors * g_bootSector.bytes);
	return readSectors(disk, lba, sectors, g_root);
}

DirectoryEntry* findFile(const char* name)
{
	for (uint32_t i = 0; i < g_bootSector.root_entries; i++) {
		if (memcmp(g_root[i].filename, name, 8) == 0 && memcmp(g_root[i].ext, name + 8, 3) == 0) {
			return &g_root[i];
		}
	}

	return NULL;
}

bool readFile(DirectoryEntry* entry, FILE* disk, void* buffer)
{
	bool result = true;
	uint16_t cluster = entry->first_cluster_low;

	do {
		uint32_t lba = g_rootEnd + (cluster - 2) * g_bootSector.sectors;
		result &= readSectors(disk, lba, g_bootSector.sectors, buffer);
		buffer += g_bootSector.sectors * g_bootSector.bytes;

		uint32_t fatIndex = cluster + cluster / 2;
		if (cluster % 2 == 0) {
			cluster = (*(uint16_t * )(g_fat + fatIndex)) & 0xFFF;
		}
		else {
			cluster = (*(uint16_t * )(g_fat + fatIndex)) >> 4;
		}
	} while (result && cluster < 0xFF8);

	return result;
}

#pragma endregion

#pragma region Entry point

int main(int argc, char** argv)
{
	// Check arguments.
	if (argc < 3) {
		printf("Usage: %s <disk image> <file name>\n", argv[0]);
		return EXIT_FAILURE;
	}

	// Open disk image.
	FILE* disk = fopen(argv[1], "rb");
	if (!disk) {
		printf("Failed to open disk image '%s'\n", argv[1]);
		return EXIT_FAILURE;
	}

	// Read boot sector.
	if (!readBootSector(disk)) {
		printf("Failed to read boot sector\n");
		return EXIT_FAILURE;
	}

	// Read FAT.
	if (!readFat(disk)) {
		printf("Failed to read FAT\n");
		free(g_fat);
		return EXIT_FAILURE;
	}

	// Read root directory.
	if (!readRootDirectory(disk)) {
		printf("Failed to read root directory\n");
		free(g_fat);
		free(g_root);
		return EXIT_FAILURE;
	}

	// Find file.
	DirectoryEntry* entry = findFile(argv[2]);
	if (!entry) {
		printf("File '%s' not found\n", argv[2]);
		free(g_fat);
		free(g_root);
		return EXIT_FAILURE;
	}

	// Read file.
	uint8_t* buffer = (uint8_t*)malloc(entry->size + g_bootSector.bytes);
	if (!readFile(entry, disk, buffer)) {
		printf("Failed to read file '%s'\n", argv[2]);
		free(g_fat);
		free(g_root);
		free(buffer);
		return EXIT_FAILURE;
	}

	// Print file.
	for (uint32_t i = 0; i < entry->size; i++) {
		if (isprint(buffer[i])) {
			printf("%c", buffer[i]);
		} else {
			printf("<%02x>", buffer[i]);
		}
	}
	printf("\n");

	// Cleanup.
	free(g_fat);
	free(g_root);
	free(buffer);
	fclose(disk);
	return EXIT_SUCCESS;
}

#pragma endregion