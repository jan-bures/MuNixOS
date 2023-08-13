set disassembly-flavor intel
set architecture i8086
tui new-layout horizontal {-horizontal asm 1 regs 1} 2 status 0 cmd 1
layout horizontal
target remote | qemu-system-i386 -gdb stdio -fda build/main_floppy.img