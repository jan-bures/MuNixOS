# Registers

The x86 architecture has various registers that can be used to store data and addresses. The registers can be divided into the following groups:

- General purpose registers
- Segment registers
- Status registers
- Control registers
- Protected mode registers
- Debug registers
- Floating point unit registers
- SIMD registers

This document covers the most important registers for 16-bit and 32-bit mode.

## General purpose registers

The general purpose registers are the most commonly used registers. They can be used to store data and addresses. The following tables shows the most important general purpose registers, which can be further subdivided:

### Data registers

The data registers can be used to store data and addresses. They can also be used to perform arithmetic operations. They can be accessed as 8-bit, 16-bit, 32-bit or 64-bit registers.

- 64 bits: RAX, RBX, RCX, RDX
- 32 bits: EAX, EBX, ECX, EDX
- 16 bits: AX, BX, CX, DX
- 8 bits: AH, AL, BH, BL, CH, CL, DH, DL

The "H" and "L" suffixes are used to access the high and low 8 bits of the respective 16-bit registers.

The "E" prefix is used to access the 32-bit registers.

The "R" prefix is used to access the 64-bit registers.

| Register   | Bits      | Name        | Description                            |
|------------|-----------|-------------|----------------------------------------|
| (E)AX      | 16 (32)   | Accumulator | I/O port access, arithmetic operations |
| (E)BX      | 16 (32)   | Base        | Pointer to data in the DS segment      |
| (E)CX      | 16 (32)   | Counter     | Loop and shift counter                 |
| (E)DX      | 16 (32)   | Data        | I/O port access, arithmetic operations |

### Indexes and pointers

| Register   | Bits      | Name               | Description                              |
|------------|-----------|--------------------|------------------------------------------|
| (E)SI      | 16 (32)   | Source index       | String and array operations              |
| (E)DI      | 16 (32)   | Destination index  | String and array operations              |
| (E)BP      | 16 (32)   | Stack base pointer | Holds the base address of the stack      |
| (E)SP      | 16 (32)   | Stack pointer      | Holds the top address of the stack       |

## Segment registers

The segment registers can only be accessed as 16-bit registers. They are used to specify the currently active segments. They cannot be written directly, instead, the constants must be loaded into a general purpose register and then moved into the segment register.

| Register   | Name    | Description                                          |
|------------|---------|------------------------------------------------------|
| CS         | Code    | Points to the code segment in which the program runs |
| DS         | Data    | Points to the data segment the program accesses      |
| SS         | Stack   | Points to the stack segment the program uses         |
| ES         | Extra   | Points to an extra data segment                      |
| FS         | Extra   | Points to an extra data segment                      |
| GS         | Extra   | Points to an extra data segment                      |

## Status registers

The status registers contain information about the current state of the processor. They can be accessed as 16-bit, 32-bit or 64-bit registers.

| Register   | Bits      | Name        | Description                                   |
|------------|-----------|-------------|-----------------------------------------------|
| (E)FLAGS   | 16 (32)   | Flags       | Contains the status of the processor          |
| (E)IP      | 16 (32)   | Instruction | Contains the address of the next instruction  |

### (E)FLAGS register

The (E)FLAGS register contains the status of the processor. It can be accessed as 16-bit, 32-bit or 64-bit register. The following table shows the most important flags:

| Bit   | Name | Description               |
|-------|------|---------------------------|
| 0     | CF   | Carry flag                |
| 2     | PF   | Parity flag               |
| 4     | AF   | Adjust flag               |
| 6     | ZF   | Zero flag                 |
| 7     | SF   | Sign flag                 |
| 8     | TF   | Trap flag                 |
| 9     | IF   | Interrupt flag            |
| 10    | DF   | Direction flag            |
| 11    | OF   | Overflow flag             |
| 12-13 | IOPL | I/O privilege level       |
| 14    | NT   | Nested task flag          |
| 16    | RF   | Resume flag               |
| 17    | VM   | Virtual 8086 mode flag    |
| 18    | AC   | Alignment check           |
| 19    | VIF  | Virtual interrupt flag    |
| 20    | VIP  | Virtual interrupt pending |
| 21    | ID   | ID flag                   |