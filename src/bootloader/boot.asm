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
    jmp main


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


main:
    ; Set up data segments
    mov ax, 0               ; Can't write to ds/es directly because it's a 16-bit register
    mov ds, ax
    mov es, ax

    ; Set up stack
    mov ss, ax
    mov sp, 0x7C00          ; Stack grows downwards, so we set it to the start of our OS

    ; Read something from the floppy disk
    ; BIOS should set dl to the drive number of the boot drive
    mov [ebpb_drive], dl    ; Set the drive number in the extended BIOS parameter block

    mov ax, 1               ; LBA address of the first sector to read
    mov cx, 1               ; Number of sectors to read
    mov bx, 0x7E00          ; Pointer to the buffer to read the sectors into, 0x7E00 is the end of our bootloader
    call disk_read          ; Read the sectors

    ; Print a message
    mov si, msg_hello
    call puts

    ; Halt the processor
    cli
    hlt

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0x00        ; BIOS keyboard function
    int 0x16            ; Call BIOS interrupt 0x16 (keyboard services) - wait for keypress
    jmp 0xFFFF:0x0000   ; Reboot the computer

.halt:
    cli                ; Disable interrupts, so the CPU doesn't get interrupted while halting
    hlt                ; Halt the processor


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

msg_hello: db 'Hello, world!', ENDL, 0
msg_read_failed: db 'Read from disk failed!', ENDL, 0


; $ = memory offset of current line in bytes, $$ = memory offset of current segment
; Our sector is 512 bytes, so we need to pad it with 510-($-$$) bytes of 0s
times 510-($-$$) db 0
; The last two bytes are the magic number that BIOS looks for to identify a boot sector
dw 0xAA55