# 68K-MON: Custom MONITOR ROM for the Agfa Compugraphic 9000PS I/O board with BASIC in ROM

**68K-MON** is a fully functional, SWTBUG-like ROM monitor built from scratch for the Motorola 68000-based I/O board inside the Agfa Compugraphic 9000PS RIP (Raster Image Processor.) The I/O board is maked `AGFA EBS PNAFATI1++A`.

![Boot message](https://github.com/misterblack1/agfa_ebs_pnafati/blob/main/images/Boot.png?raw=true)

## Reverse-Engineering
This project started with this board containing a 68000 CPU, 64K of ROM, 16KB of SRAM, an MC68681 Dual UART (DUART), an MK4501N High-Speed FIFO, and a front panel with a numeric dial and LEDs. By dumping and forensically analyzing the original ROM, we deduced the address decoder logic and peripheral wiring.

Video exploration and teardown of Compugraphic 9000PS on [Adrian's Digital Basement](https://www.youtube.com/watch?v=2rAgdZ9zBuA)

Original dumps of the ROMs from this machine are available at [https://archive.org/details/agfa-computgraphi-9000-ps](https://archive.org/details/agfa-computgraphi-9000-ps)

### Hardware Notes
* **RAM select logic:** The board uses a simple 3-to-8 address decoder connected to address lines `A16`, `A17`, and `A18`. Because `A19-A23` are ignored, the entire 512KB physical memory map echoes infinitely throughout the 68000's 16MB address space.
* **Polled I/O:** The original vector table was entirely blank (`$FFFFFFFF`) or pointed to infinite loops. The board relies 100% on polling and does not use hardware interrupts.
* **The 68681 DUART Does Everything:** Because it's the only major logic chip on the board, the DUART isn't just used for serial communication. Its General Purpose I/O pins control the front panel LEDs, read the front panel numeric dial, read the Stop button, and manage the MK4501 FIFO flags.
* **Odd-Byte Lane:** The DUART is wired exclusively to the lower half of the 16-bit data bus (`D0-D7`), meaning its registers only exist at odd memory addresses.

![Hardware board](https://github.com/misterblack1/agfa_ebs_pnafati/blob/main/images/Agfa%20Board.jpg?raw=true)

![Agfa Computergraphic 9000PS](https://github.com/misterblack1/agfa_ebs_pnafati/blob/main/images/Compugraphic9000ps.jpg?raw=true)
---

## Hardware Memory Map and Notes

| Logical Block | Address Range | Physical Device | Description |
| :--- | :--- | :--- | :--- |
| **Block 0** | `$000000 - $00FFFF` | **ROM (EPROM)** | 64KB Physical. Boot Vectors & 68K-MON Firmware. |
| **Block 1** | `$010000 - $01FFFF` | **SRAM** | 16KB Actual but 64KB mapped to SRAM sockets. Stack at `$014000`. User code starts at `$010100`. |
| **Block 2** | `$020000 - $02FFFF` | **FIFO (MK4501)** | High-Speed Buffer array. |
| **Block 3** | `$030000 - $03FFFF` | **FIFO (Mirror)** | Alias of Block 2. |
| **Block 4** | `$040000 - $04FFFF` | **DUART (MC68681)** | System Console, Front Panel I/O, LED Control. |
| **Block 5-7** | `$050000 - $07FFFF` | *Unpopulated* | Dead zones. Accessing these freezes the CPU (No DTACK). |

`/RESET` and `/HALT` on the CPU are tied together. They are supplied to the CPU from connector P1, normally fed from another board. In order to use this board, you will need to create your own reset circuit. (I am using the /PWR_GOOD signal on the AT PSU connector via a resistor.)

---

## Front Panel Wiring (via DUART)

### Status LEDs (DUART Output Port)
The LEDs are driven by the DUART Output Port. Interestingly, the hardware uses mixed logic:
* **Amber LED (OP5, Mask `$20`)**: Active-LOW. Turn on by writing `$20` to the OPR SET register (`$04001D`).
* **Red LED (OP7, Mask `$80`)**: Active-HIGH. Turn on by writing `$80` to the OPR RESET register (`$04001F`).

### Inputs: Dial & Stop Button (DUART Input Port)
Read from the DUART unlatched input register at `$04001B`. Inputs are pulled high and go active-low when pressed/selected.
* **Stop Button (IP1, Mask `$02`)**: Goes to `0` when pushed. 
* **Numeric Dial (IP2, IP3, IP4)**: 3-bit octal encoder (0-7). The software shifts the DUART byte right by 2, inverts the bits, and masks with `$07` to read the dial's physical state dynamically.

---

## Features & Commands
**68K-MON** is a command-line interface running at **9600 Baud (8N1)** on Port A of the DUART. The RxD and TxD pins can be found on the unusitlized P10 connector on the board. It features case-insensitive commands, backspace support, and a dynamic prompt that updates based on the physical front-panel dial.

| Command | Usage | Description |
| :--- | :--- | :--- |
| **M** | `M <Addr>` | **Modify Memory**: Interactive hex editor. Type a byte to overwrite, or press `Enter` to safely exit. |
| **D** | `D [Addr] [Len]` | **Hex Dump**: Prints a 16-byte aligned hex/ASCII dump. Defaults to length `$10`. Pressing `D` again continues from the last address. |
| **L** | `L` | **Load S-Records**: Listens for Motorola S-Records. Supports 24-bit `S2` records and `S8` termination. *(Note: Add a 1ms character transmit delay to your terminal emulator to prevent buffer overruns when pasting code).* |
| **P** | `P <Start> <End>` | **Punch**: Dumps a memory range to the terminal formatted as standard Motorola `S2` (24-bit) records. |
| **F** | `F <Byte> <Start> <End>` | **Fill Memory**: Fills a memory range. Smart-detects if arg 3 is a Length instead of an End Address. |
| **E** | `E <Reg> <Val>` | **Edit Register**: Modifies the saved register state (e.g., `E D0 FFFF`, `E PC 010100`). |
| **R** | `R` | **Show Registers**: Displays a formatted table of all saved D, A, PC, SR, and SSP registers. |
| **G** | `G [Addr]` | **Go/Execute**: Jumps to `Addr`. If no address is provided, jumps to the saved `PC` register. |
| **? / H**| `?` or `H` | **Help**: Prints the command list. |

*Pressing the physical **Stop** button on the front panel while at the prompt will trigger a hard software reboot.*

---

## User API (Writing your own programs)
You can write your own 68k assembly programs, assemble them to Motorola S-Records, load them into RAM (at `$010100`) using the `L` command, and execute them using `G`.

68K-MON provides a permanent API jump table at `$0400` so your programs can interact with the terminal without knowing the hardware addresses.

| Vector | Address | Description |
| :--- | :--- | :--- |
| `START` | `JMP $0400` | Hard reset. Clears registers and restarts the monitor. |
| `PUTCHAR` | `JSR $0406` | Prints the ASCII character stored in `D0.B` to the terminal. |
| `GETCHAR` | `JSR $040C` | Halts and reads a character from the terminal into `D0.B`. |
| `PRINT` | `JSR $0412` | Prints a null-terminated string pointed to by `A0`. |
| `GETLINE` | `JSR $0418` | Halts and reads a full line (with echo/backspace) into buffer at `A0`. |
| `EXIT` | `JMP $041E` | Safely terminates your program and returns to the `>` prompt. |

*Do not use `RTS` to exit your main program block, as misaligned stack frames will cause a bus error. Always `JMP $041E` to cleanly exit.*

---

## Building and running the Code
The `swtbug-v6.m68` source file is written for **Easy68K**. Assembled, it will run on the real hardware.

**To build for Physical EPROMs:**
In Easy68K, you need to assembly the code. Then use SIM68k to load the assembled code and use the memory viewer to save the first 64k of address space to a BIN file. This is your ROM code to run on real hardware. You must byte split the file as real hardware requires two 8 bit EPROMs.

When the system powers up, the RED led will on the control panel will always illumate. When the ROM initializes the DUART, it will turn on the AMBER LED. This is a good indicator the code is running. The system prompt will be `68K-MON 0>` where the 0 will be replaced with whatever the front numeric switch is set to. (0-7 is possible.)

When the system executes a command, the RED LED will turn off while the command executes, and will illuminate again when the command is finished. 

The `STOP` button on the front panel will only work when at the prompt, due to the nature of how the system does not support IRQs. 

---

## Included Example: Mandelbrot Generator
Included in this repo is `fractal calculation-v6.x68`. This is an example user program meant to be loaded into RAM at `$010100` using but using the `L` command and pasting the S-records from `fractal calculation-v6.S68` into your terminal window. Use `G 10100` to start the program.

Because the 68000 lacks an FPU, this program uses **Fixed-Point Arithmetic** to natively calculate and render an ASCII Mandelbrot fractal directly to the serial terminal, proving the stability of the API vectors and the hardware's math execution.

![Fractal](https://github.com/misterblack1/agfa_ebs_pnafati/blob/main/images/fractal.png?raw=true)

The Fractal generator is based on this BASIC program: (author unknown)

```
10 FOR Y=-12 to 12
20 FOR X=-39 TO 39
30 CA=X*.0458
40 CB=Y*.08333
50 A=CA
60 B=CB
70 FOR I = 0 TO 15
80 T=A*A-B*B+CA
90 B=2*A*B+CB
100 A=T
110 IF(A*A+B*B)>4 GOTO 200
120 NEXT I
130 PRINT " ";
140 GOTO 210
200 IF I>9 THEN I=I+7
205 PRINT CHR$(48+I);
210 NEXT X
220 PRINT
230 NEXT Y
```
