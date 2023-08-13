# Memory access
This is a brief summary of the memory management in the x86 architecture.

## Memory segmentation
The memory is divided into segments of 64KB each. Each byte can be accessed by a 32-bit address, which is composed of a 16-bit segment selector and a 16-bit offset:

```
real_address = segment * 16 + offset
```

This can also be written as:

```
real_address = segment << 4 + offset
```

Segments overlap every 16 bytes, so the same byte can be accessed by different addresses. For example:
    
| Segment:Offset | Real address |
|----------------|--------------|
| 0x0000:0x7C00  | 0x07C00      |
| 0x0001:0x7BF0  | 0x07C00      |
| 0x0010:0x7B00  | 0x07C00      |
| 0x00C0:0x7000  | 0x07C00      |
| 0x7C00:0x0000  | 0x07C00      |

### Segment registers
The segment registers are used to specify the currently active segments. The following table shows the most important segment registers:

| Register   | Description    | Notes                                 |
|------------|----------------|---------------------------------------|
| CS*        | Code segment   | Modified by JMP and CALL instructions |
| DS         | Data segment   |                                       |
| SS         | Stack segment  |                                       |
| ES, FS, GS | Extra segments |                                       |

\* IP register contains the current instruction offset from the CS segment.

Constants can't be written directly into segment registers. Instead, the constants must be loaded into a general purpose register and then moved into the segment register.


## Referencing a memory location in assembly
A memory location can be referenced by a memory operand with the following syntax:

```
segment:[base + index * scale + displacement]
```

All the parts of the memory operand are optional. The following table shows the meaning of each part:

| Part          | Description                                                                                 |
|---------------|---------------------------------------------------------------------------------------------|
| segment       | Segment register - CS, DS, ES, FS, GS, SS (default SS if base register is BP, DS otherwise) |
| base          | Base register - BP/BX in 16-bit mode, any general purpose register in 32-bit mode           |
| index         | Index register - SI/DI in 16-bit mode, any general purpose register in 32-bit mode          |
| scale         | Scale factor - 1, 2, 4 or 8 (only in 32-bit mode)                                           |
| displacement  | Constant displacement - a signed constant value                                             |

Examples:

```nasm
var: dw 100
    mov ax, var   ; copy offset of var into ax
    mov ax, [var] ; copy value of var into ax
```

```nasm
array: dw 100, 200, 300
    mov bx, array     ; copy offset of array into bx
    mov si, 2 * 2     ; array[2], 2 is the index and word is 2 bytes wide

    mov ax, [bx + si] ; copy value of array[2] into ax
```