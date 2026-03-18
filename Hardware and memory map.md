# Hardware Reference Manual
* Platform: Motorola 68000 Printer Controller
* Architecture: 24-bit Address Bus, 16-bit Data Bus, Polled I/O

## 1. Memory Map Overview
The system uses a simple 3-to-8 address decoder connected to Address lines **A16, A17, and A18**. Each block is allocated 64KB ($10000 bytes) of address space. 

Because address lines A19 through A23 are not connected to the decoder, **the entire 512KB map ($000000 – $07FFFF) repeats itself infinitely** across the entire 16MB standard 68000 address space (e.g., $080000 mirrors $000000, $100000 mirrors $000000).

| Logical Block | Address Range | Physical Device | Description |
| :--- | :--- | :--- | :--- |
| **Block 0** | `$000000 - $00FFFF` | **ROM (EPROM)** | 64KB Physical. Contains Boot Vectors & Firmware. |
| **Block 1** | `$010000 - $01FFFF` | **SRAM** | 16KB Physical. (Repeats 4 times inside this 64K block). |
| **Block 2** | `$020000 - $02FFFF` | **FIFO (MK4501)** | High-Speed Buffer array (Read/Write). |
| **Block 3** | `$030000 - $03FFFF` | **FIFO (Mirror)** | Alias of Block 2. |
| **Block 4** | `$040000 - $04FFFF` | **DUART 1 (MC68681)** | System Console, Front Panel I/O, LED Control. |
| **Block 5** | `$050000 - $05FFFF` | *Unpopulated* | Intended for DUART 2. Accessing freezes CPU. |
| **Block 6** | `$060000 - $06FFFF` | *Unpopulated* | Dead zone. Accessing freezes CPU. |
| **Block 7** | `$070000 - $07FFFF` | *Unpopulated* | Dead zone. Accessing freezes CPU. |

### Note on System Freezes (The DTACK Signal)
The Motorola 68000 requires a peripheral to assert the `DTACK` (Data Transfer Acknowledge) pin to confirm a read/write has finished. If no hardware services the `DTACK` signal, the CPU will wait forever, appearing "frozen".

---

## 2. DUART (MC68681) Port Definitions
* Base Address:  `$040000` (Mapped to the ODD byte lane, `D0-D7`)
* The DUART serves as the central serial console and the primary General Purpose I/O controller for the front panel.

MC68681 DUART1_BASE EQU $040000
* MR1A        EQU DUART1_BASE+$01
* MR2A        EQU DUART1_BASE+$01
* SRA         EQU DUART1_BASE+$03
* CSRA        EQU DUART1_BASE+$03
* CRA         EQU DUART1_BASE+$05
* RxA         EQU DUART1_BASE+$07
* TxA         EQU DUART1_BASE+$07
* ACR         EQU DUART1_BASE+$09
* IMR         EQU DUART1_BASE+$0B

### 2.1 Front Panel Status LEDs
The LEDs are connected to the DUART's **Output Port (OP)**. Interestingly, the engineers used mixed logic (sinking vs. sourcing current), meaning the bits behave oppositely for the two LEDs.

* **DUART OPR Bit SET Command (`$04001D`)**: Forces a pin **LOW** (0V).
* **DUART OPR Bit RESET Command (`$04001F`)**: Forces a pin **HIGH** (5V).

| Component | DUART Pin | Value | Active State | Turn ON Command | Turn OFF Command |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Amber LED** | OP5 | `$20` | Active-LOW | Write `$20` to `$04001D` | Write `$20` to `$04001F` |
| **Red LED** | OP7 | `$80` | Active-HIGH | Write `$80` to `$04001F` | Write `$80` to `$04001D` |

*Note: OP6 (`$40`) is also actively driven by the original firmware and likely goes to another device on the board.*

### 2.2 Front Panel Inputs (Buttons & Switches)
The momentary button and numeric sector switch are connected to the DUART's **Input Port (IP)**. They can be read at address **`$04001B`**.

All inputs are **Active-LOW** (they read as `1` when resting, and drop to `0` when pressed/selected) and have hardware pull-up resistors.

#### Momentary Stop Button
* **Pin:** `IP1`
* **Bitmask:** `$02`
* **State:** `1` = Not Pushed, `0` = Pushed

#### Numeric Toggle Switch (Values 0 - 9)
* **Pins:** `IP2`, `IP3`, `IP4`
* **Bitmask:** `$1C`
* **Hardware Note:** The switch is a 3-bit octal encoder (max 8 positions). When the physical dial reaches positions 8 and 9, the hardware simply overflows and repeats the binary sequence for 0 and 1.

| Dial Position | IP4 (Bit 4) | IP3 (Bit 3) | IP2 (Bit 2) | Hex Value at `$4001B` |
| :---: | :---: | :---: | :---: | :--- |
| **0** | 1 | 1 | 1 | `$FE` (`1111 1110`) |
| **1** | 1 | 1 | 0 | `$FA` (`1111 1010`) |
| **2** | 1 | 0 | 1 | `$F6` (`1111 0110`) |
| **3** | 1 | 0 | 0 | `$F2` (`1111 0010`) |
| **4** | 0 | 1 | 1 | `$EE` (`1110 1110`) |
| **5** | 0 | 1 | 0 | `$EA` (`1110 1010`) |
| **6** | 0 | 0 | 1 | `$E6` (`1110 0110`) |
| **7** | 0 | 0 | 0 | `$E2` (`1110 0010`) |
| **8** | 1 | 1 | 1 | `$FE` *(Wraps to 0)* |
| **9** | 1 | 1 | 0 | `$FA` *(Wraps to 1)* |

*(Software decoding requires shifting the read byte right by 2, inverting the bits, and masking with `$07`).*

---

## 3. MK4501N FIFO Implementation
**Base Address:** `$020000`
The MK4501N is a 512 x 9-bit high-speed FIFO buffer. 
* **Data Access:** Reading or writing anywhere in the 64KB block `$020000 - $02FFFF` interacts with the FIFO's data port. 
* **Control Lines:** Based on previous firmware analysis, the FIFO's control lines (Empty Flag, Full Flag, Reset) are not mapped to an absolute address, but are instead wired to the DUART's remaining I/O pins (e.g., `IP5`, `OP2`). 
* **Data Width:** The `$61 00` values seen during sequential dumps indicate the FIFO is likely wired to the upper byte lane (Even addresses), passing 8 bits of payload data to the bus, while the 9th parity/flag bit may be tied off or routed elsewhere.
