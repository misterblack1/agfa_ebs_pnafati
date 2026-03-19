# EhBASIC Port for the Agfa EBS PNAFITA1++A (I/O controller from the Agfa Compugraphic 9000PS)

Enhanced BASIC for the Motorola MC680xx by Jeff Tranter (tranter@pobox.com)

```
Copyright(C) 2002-12 by Lee Davison. This program may be freely distributed
for personal use only. All commercial rights are reserved.
```

The code needed to modified to run within the constraints of this system. Start ROM-BASIC with a `g 1400` you will see this:

```
68K-MON 0> g 1400

14739 Bytes free

Enhanced 68k BASIC Version 3.54

Ready
```

Push the front panel STOP button to exit back to the monitor. *YOU WILL LOSE YOUR PROGRAM* when you do this, as there is currently no way to re-enter basic with a WARM start. 

`LOAD` and `SAVE` are not implemented, so to `LOAD` a program, simply copy and paste the text into your serial terminal. To `SAVE`, just list the program and copy it paste it from your terminal. When you paste into the terminal, you will need to add some delays (intercharacter and inter line delays) as characters seem to be missed.

## 1. System Memory Overview

| Address Range | Component | Description |
| :--- | :--- | :--- |
| `$000000 - $0003FF` | **Interrupt Vectors** | Hardware/Monitor Vectors |
| `$000400 - $0004FF` | **Monitor Jump Table** | 68K-MON API Entry Points |
| `$000500 - $0013FF` | **Reserved** | Monitor Workspace |
| **`$001400 - $003DFF`** | **EhBASIC (ROM)** | **Kernel & Tokenizer (Resident)** |
| `$003E00 - $00FFFF` | **Expansion Space** | Unused / Future Expansion |
| **`$010000 - $013BFF`** | **EhBASIC RAM** | **Workspace, Stacks, and Programs** |
| `$014000` | **System Stack** | Main Processor Stack (Grow down) |

---

## 2. EhBASIC RAM Workspace Detail ($10000+)

| Offset (Hex) | Absolute | Symbol / Region | Function |
| :--- | :--- | :--- | :--- |
| `+$0000` | `$10000` | `ram_strt` | **Bottom of Workspace** |
| `+$0000-FF` | `$10000` | **Internal Stack** | BASIC subroutine stack (256 bytes) |
| **`+$0100`** | **`$10100`** | **`sp` (Initial)** | **Execution Start Stack Pointer** |

### 2a. Vector Table (Jump Table)
*Each entry is a 6-byte sequence: `$4EF9 [Long Address]`*

| Address | Vector Name | Description |
| :--- | :--- | :--- |
| `$10100` | `LAB_WARM` | Warm start / Re-entry |
| `$10106` | `Usrjmp` | User Function Hook (USR) |
| `$1010C` | `V_INPT` | Console Input Routine |
| `$10112` | `V_OUTP` | Console Output Routine |
| `$10118` | `V_LOAD` | Program Load Hook |
| `$1011E` | `V_SAVE` | Program Save Hook |
| `$10124` | `V_CTLC` | CTRL-C Break Check |

---

## 3. Dynamic "Elastic" Memory Model
EhBASIC uses a dynamic allocation scheme where program data grows **UP** from the bottom and string data grows **DOWN** from the top.

```text
  $10140 +-----------------------+ [prg_strt]
         |    BASIC PROGRAM      | Grows UP as you type
         +-----------------------+ [Sfncl]
         |    FUNCTIONS / VARS   | Grows UP as you define them
         +-----------------------+ [Svarl] / [Sstrl]
         |    ARRAYS             | Grows UP as you DIM them
         +-----------------------+ [Earryl]
         |                       |
         |    FREE SPACE         | (Gap shrinks as data grows)
         |                       |
         +-----------------------+ [Sstorl]
         |    STRING DATA        | Grows DOWN from Top
  $13BFF +-----------------------+ [Ememl]
```
---

## 4. Internal System Variables ($101XX Area)
*These are stored in the workspace after the Vector Table*

| Symbol | Size | Description |
| :--- | :--- | :--- |
| `FAC1_m/e` | 6b | Primary Floating Point Accumulator |
| `FAC2_m/e` | 8b | Secondary Floating Point Accumulator |
| `PRNlword` | 4b | Pseudo-Random Number Seed |
| `TWidth` | 1b | Terminal Width (set to $50 / 80 chars) |
| `TPos` | 1b | Current Cursor Column |
| `Clinel` | 4b | Currently executing Line Number |
| `ccflag` | 1b | CTRL-C Enable/Disable Flag |
