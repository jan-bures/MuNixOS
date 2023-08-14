org 0x7C00      ; Start addresses from 0x7C00, which is where BIOS looks for the OS
bits 16         ; Emit 16-bit instructions

%define ENDL `\r\n` ; Newline characters


;
; FAT12 header
;

; Jump instruction to skip over the header

jmp short start ; Jump to the start of our code
nop ; Pad the first instruction to make it 3 bytes long

; BIOS Parameter Block

bpb_oem:           db 'MSWIN4.1'       ; OEM name - 8 bytes, MSWIN4.1 used for compatibility
bpb_bytes:         dw 512              ; Bytes per sector - 512 is the standard
bpb_sectors:       db 1                ; Sectors per cluster - 1 is the standard
bpb_reserved:      dw 1                ; Number of reserved sectors - 1 is the standard
bpb_fats:          db 2                ; Number of FATs - 2 is the standard
bpb_root_entries:  dw 224              ; Number of root directory entries - 224 is the standard
bpb_sectors_small: dw 2880             ; Number of sectors on the disk - 2880 is the standard, 2880 * 512 = 1.44MB
bpb_media:         db 0xF0             ; Media descriptor - 0xF0 is the standard for floppy disks
bpb_sectors_fat:   dw 9                ; Sectors per FAT - 9 is the standard
bpb_sectors_track: dw 18               ; Sectors per track - 18 is the standard
bpb_heads:         dw 2                ; Number of heads - 2 is the standard
bpb_hidden:        dd 0                ; Number of hidden sectors - 0 is the standard
bpb_sectors_large: dd 0                ; Number of large sectors - 0 is the standard

; Extended BIOS Parameter Block

ebpb_drive:        db 0                ; Drive number - 0 is the standard, 0x80 is the first hard drive; useless
ebpb_reserved:     db 0                ; Reserved - 0 is the standard
ebpb_signature:    db 0x29             ; Extended boot signature - 0x29 is the standard
ebpb_volume_id:    dd 0                ; Volume ID - 0 is the standard, 0x12345678 is a common value
ebpb_volume_label: db 'NO NAME    '    ; Volume label - 11 bytes, 'NO NAME    ' is the standard
ebpb_fs_type:      db 'FAT12   '       ; Filesystem type - 8 bytes, 'FAT12   ' is the standard


; Boot code

start:
    ; Set up data segments
    mov ax, 0               ; Can't write to ds/es directly because it's a 16-bit register
    mov ds, ax
    mov es, ax

    ; Set up stack
    mov ss, ax
    mov sp, 0x7C00          ; Stack grows downwards, so we set it to the start of our OS

    ; Some BIOSes might start the bootloader at 0x7C0:0x0000 instead of 0x0000:0x7C00
    push es
    push word .after
    retf

.after:

    ; BIOS should set dl to the drive number of the boot drive
    mov [ebpb_drive], dl        ; Set the drive number in the extended BIOS parameter block

    ; Show loading message
    mov si, msg_loading
    call puts

    ; Read drive parameters (number of heads, sectors per track, etc.),
    ; instead of hard-coding them
    push es
    mov ah, 0x08                ; BIOS get drive parameters function
    int 0x13                    ; Call BIOS interrupt 0x13 (disk services)
    jc floppy_error             ; If the carry flag is set, the read failed
    pop es

    and cl, 0x3F                ; remove top 2 bits of sector number
    xor ch, ch                  ; ch = 0
    mov [bpb_sectors_track], cx ; Set sectors per track in the BIOS parameter block

    inc dh                      ; dh = 1
    mov [bpb_heads], dh         ; Set number of heads in the BIOS parameter block

    ; Compute the LBA address of the root directory (reserved_sectors + sectors_per_fat * number_of_fats)
    mov ax, [bpb_sectors_fat]   ; ax = sectors_per_fat
    mov bl, [bpb_fats]          ; bl = number_of_fats
    xor bh, bh                  ; bh = 0
    mul bx                      ; ax = sectors_per_fat * number_of_fats
    add ax, [bpb_reserved]      ; ax = sectors_per_fat * number_of_fats + reserved_sectors
    push ax                     ; Save the LBA address of the root directory

    ; Compute the size of the root directory in sectors (root_entries * 32 / bytes_per_sector)
    mov ax, [bpb_sectors]       ; ax = sectors_per_cluster
    shl ax, 5                   ; ax = root_entries * 32
    xor dx, dx                  ; dx = 0
    div word [bpb_sectors]        ; ax = root_entries * 32 / bytes_per_sector

    test dx, dx                 ; If dx != 0, add 1 to the result
    jz .root_dir_after
    inc ax                      ; division remainder is not 0, so add 1 to the result
                                ; this means a sector is only partially filled, so we need to read an extra sector

.root_dir_after:
    ; Read the root directory
    mov cl, al                  ; cl = size of root directory in sectors
    pop ax                      ; ax = LBA address of the root directory
    mov dl, [ebpb_drive]        ; dl = drive number
    mov bx, buffer              ; bx = buffer address
    call disk_read              ; Read the root directory

    ; Search for kernel.bin
    xor bx, bx                  ; bx = 0
    mov di, buffer              ; di = buffer address

.search_kernel:
    mov si, file_kernel_bin     ; si = file name
    mov cx, 11                  ; cx = file name length
    push di
    repe cmpsb                  ; Compare the file name in the root directory with the file name we're looking for
    pop di
    je .found_kernel

    add di, 32                  ; di += 32 (size of a directory entry)
    inc bx                      ; bx += 1
    cmp bx, [bpb_root_entries]  ; If bx == root_entries, we've searched the entire root directory
    jl .search_kernel           ; If bx < root_entries, search the next directory entry

    ; Kernel not found
    jmp kernel_not_found_error

    ; Halt the processor
    cli
    hlt

.found_kernel:
    ; di points to the directory entry of kernel.bin
    mov ax, [di+0x1A]           ; ax = starting cluster of kernel.bin
    mov [kernel_cluster], ax    ; Save the starting cluster of kernel.bin

    ; Read the FAT
    mov ax, [bpb_reserved]      ; ax = reserved_sectors
    mov bx, buffer              ; bx = buffer address
    mov cl, [bpb_fats]          ; cl = number_of_fats
    mov dl, [ebpb_drive]        ; dl = drive number
    call disk_read              ; Read the FAT

    ; Read the kernel and process FAT entries
    mov bx, KERNEL_LOAD_SEGMENT ; bx = segment to load the kernel into
    mov es, bx                  ; es = segment to load the kernel into
    mov bx, KERNEL_LOAD_OFFSET  ; bx = offset to load the kernel into

.load_kernel:
    mov ax, [kernel_cluster]    ; ax = current cluster

    ; TODO: Fix hardcoded value
    add ax, 31                  ; first cluster = (kernel_cluster - 2) * sectors_per_cluster + start_sector
                                ; start_sector = reserved_sectors + sectors_per_fat * number_of_fats + root_dir_sectors
                                ;              = 1 + 9 * 2 + 14 = 33
    mov cl, 1
    mov dl, [ebpb_drive]        ; dl = drive number
    call disk_read              ; Read the cluster

    add bx, [bpb_bytes]         ; bx += bytes_per_sector

    ; Compute the next cluster
    mov ax, [kernel_cluster]    ; ax = current cluster
    mov cx, 3
    mul cx                      ; ax = current cluster * 3
    mov cx, 2
    div cx                      ; ax = current cluster * 3 / 2, dx = current cluster * 3 % 2

    mov si, buffer              ; si = buffer address
    add si, ax                  ; si += current cluster * 3 / 2
    mov ax, [ds:si]             ; ax = next cluster

    or dx, dx                   ; If dx != 0, the next cluster is in the high 12 bits of ax
    jz .even

.odd:
    shr ax, 4                   ; ax = next cluster [bits 12-15]
    jmp .next_cluster_after

.even:
    and ax, 0x0FFF              ; ax = next cluster [bits 0-11]

.next_cluster_after:
    cmp ax, 0x0FF8             ; If ax >= 0x0FF8, the cluster is the last cluster in the file
    jae .read_finish

    mov [kernel_cluster], ax    ; Save the next cluster
    jmp .load_kernel

.read_finish:
    ; Jump to the kernel
    mov dl, [ebpb_drive]        ; dl = drive number

    mov ax, KERNEL_LOAD_SEGMENT ; ax = segment to load the kernel into
    mov ds, ax                  ; ds = segment to load the kernel into
    mov es, ax                  ; es = segment to load the kernel into

    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

    cli
    hlt


;
; Error handlers
;

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

kernel_not_found_error:
    mov si, msg_kernel_not_found
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0x00        ; BIOS keyboard function
    int 0x16            ; Call BIOS interrupt 0x16 (keyboard services) - wait for keypress
    jmp 0xFFFF:0x0000   ; Reboot the computer

.halt:
    cli                ; Disable interrupts, so the CPU doesn't get interrupted while halting
    hlt                ; Halt the processor


;
; Print a string to the screen
; Parameters:
;   ds:si - Pointer to the string to print
;
puts:
    ; Save registers that we're going to modify
    push si
    push ax

.loop:
    lodsb               ; Load the next char from ds:si into al, and increment si
    or al, al           ; Set the zero flag if character in al is null
    jz .done            ; If the zero flag is set, we're done

    mov ah, 0x0E        ; BIOS teletype function
    mov bh, 0x00        ; Page number
    int 0x10            ; Call BIOS interrupt 0x10 (video services)

    jmp .loop           ; Repeat until the string is exhausted

.done:
    ; Restore registers
    pop ax
    pop si
    ret


; Disk routines


;
; Converts an LBA address to a CHS address
; Parameters:
;   ax - LBA address
; Returns:
;   cx [bits 0-5] - Sector number
;   cx [bits 6-15] - Cylinder number
;      |F|E|D|C|B|A|9|8|7|6|5-0|  CX
;	    | | | | | | | | | |  `----- sector number
;	    | | | | | | | | `---------- high order 2 bits of track/cylinder
;	    `-------------------------- low order 8 bits of track/cyl number
;   dh - Head number
;
lba_to_chs:
    push ax
    push dx

    xor dx, dx                      ; dx = 0
    div word [bpb_sectors_track]    ; ax = lba / sectors_per_track, dx = lba % sectors_per_track
    inc dx                          ; dx = (lba % sectors_per_track) + 1 = sector_number
    mov cx, dx                      ; cx = sector_number

    xor dx, dx                      ; dx = 0
    div word [bpb_heads]            ; ax = (lba / sectors_per_track) / heads, dx = (lba / sectors_per_track) % heads
    mov dh, dl                      ; dh = head_number
    mov ch, al                      ; ch = cylinder_number [bits 0-7]
    shl ah, 6                       ; ah = cylinder_number [bits 8-9]
    or  cl, ah                      ; cx = cylinder_number [bits 0-9], sector_number

    pop ax
    mov dl, al
    pop ax
    ret


;
; Reads sectors from a disk
; Parameters:
;   ax - LBA address of the first sector to read
;   cl - Number of sectors to read (max 128)
;   dl - Drive number
;   es:bx - Pointer to the buffer to read the sectors into
;
disk_read:
    ; Save modified registers
    push ax
    push bx
    push cx
    push dx
    push di

    push cx                         ; Save cx (number of sectors to read)
    call lba_to_chs                 ; Convert LBA address to CHS address
    pop ax                          ; al = number of sectors to read

    mov ah, 0x02                    ; BIOS read sector function
    mov di, 3                       ; Retry count

.retry:
    pusha                           ; Save all registers, we don't know what BIOS will modify
    stc                             ; Set the carry flag, BIOS will clear it if the read succeeds
    int 0x13                        ; Call BIOS interrupt 0x13 (disk services)
    jnc .success                    ; If the carry flag is clear, the read succeeded

    ; Read failed, try again
    popa                            ; Restore registers
    call disk_reset                 ; Reset the disk
    dec di                          ; Decrement retry count
    test di, di                     ; If retry count is 0, we've retried 3 times and failed
    jnz .retry                      ; If retry count is not 0, try again

.fail:
    jmp floppy_error                ; Jump to the floppy error handler

.success:
    popa

    ; Restore modified registers
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret


;
; Resets the disk controller
; Parameters:
;   dl - Drive number
;
disk_reset:
    pusha
    mov ah, 0x00                    ; BIOS reset disk function
    stc                             ; Set the carry flag, BIOS will clear it if the reset succeeds
    int 0x13                        ; Call BIOS interrupt 0x13 (disk services)
    jc floppy_error                 ; If the carry flag is set, the reset failed
    popa
    ret


msg_loading:              db 'Loading...', ENDL, 0

msg_read_failed:          db 'Read from disk failed!', ENDL, 0
msg_kernel_not_found:     db 'KERNEL.BIN not found!', ENDL, 0

file_kernel_bin:          db 'KERNEL  BIN'
kernel_cluster:           dw 0

KERNEL_LOAD_SEGMENT       equ 0x2000
KERNEL_LOAD_OFFSET        equ 0x0000

; $ = memory offset of current line in bytes, $$ = memory offset of current segment
; Our sector is 512 bytes, so we need to pad it with 510-($-$$) bytes of 0s
times 510-($-$$) db 0
; The last two bytes are the magic number that BIOS looks for to identify a boot sector
dw 0xAA55

buffer: