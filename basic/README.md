# EhBASIC Port for the Agfa EBS PNAFITA1++A (I/O controller from the Agfa Compugraphic 9000PS)

Enhanced BASIC for the Motorola MC680xx

```
Copyright(C) 2002-12 by Lee Davison. This program may be freely distributed
for personal use only. All commercial rights are reserved.

For commercial use please contact me at leeedavison@lgooglemail.com for conditions.
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

Example session running a fractal test:

```
68K-MON 0> g 1400

14739 Bytes free

Enhanced 68k BASIC Version 3.54

Ready
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

run
000000011111111111111111122222233347E7AB322222111100000000000000000000000000000
000001111111111111111122222222333557BF75433222211111000000000000000000000000000
000111111111111111112222222233445C      643332222111110000000000000000000000000
011111111111111111222222233444556C      654433332211111100000000000000000000000
11111111111111112222233346 D978 BCF    DF9 6556F4221111110000000000000000000000
111111111111122223333334469                 D   6322111111000000000000000000000
1111111111222333333334457DB                    85332111111100000000000000000000
11111122234B744444455556A                      96532211111110000000000000000000
122222233347BAA7AB776679                         A32211111110000000000000000000
2222233334567        9A                         A532221111111000000000000000000
222333346679                                    9432221111111000000000000000000
234445568  F                                   B5432221111111000000000000000000
                                              864332221111111000000000000000000
234445568  F                                   B5432221111111000000000000000000
222333346679                                    9432221111111000000000000000000
2222233334567        9A                         A532221111111000000000000000000
122222233347BAA7AB776679                         A32211111110000000000000000000
11111122234B744444455556A                      96532211111110000000000000000000
1111111111222333333334457DB                    85332111111100000000000000000000
111111111111122223333334469                 D   6322111111000000000000000000000
11111111111111112222233346 D978 BCF    DF9 6556F4221111110000000000000000000000
011111111111111111222222233444556C      654433332211111100000000000000000000000
000111111111111111112222222233445C      643332222111110000000000000000000000000
000001111111111111111122222222333557BF75433222211111000000000000000000000000000
000000011111111111111111122222233347E7AB322222111100000000000000000000000000000

Ready
```
Completes the fractal in 81 seconds. Pretty fast!
[Benchmarks results for other systems](https://docs.google.com/spreadsheets/d/1Sdh9vmm8RKGiE1-sTh9ThjFogLAoTg3M-5rL7LBWBUI/edit?usp=sharing)

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
