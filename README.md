# Basys 3 RISC-V Multi-User Password Lock

This project implements a small RISC-V SoC multi-user password lock system on the Basys 3 FPGA board. The system uses a PicoRV32 RISC-V CPU as the main controller. The CPU reads switches and buttons through memory-mapped I/O, manages password data in Data Memory, controls LEDs and the 7-segment display, and sends event logs through UART TX.

## Features

* PicoRV32 RISC-V CPU core
* Memory-mapped I/O
* Multi-user password verification
* Independent `fail_count` and `lock_state` for each user
* LED output for PASS / FAIL / LOCK
* 7-segment display output for PASS / FAIL / LOCK
* UART TX event output:

  * `USERx PASS`
  * `USERx FAIL`
  * `USERx LOCK`

## Project Structure

```text
riscv_password_lock_basys3/
├── README.md
├── rtl/
│   ├── basys3_riscv_lock_top.v
│   ├── picorv32.v
│   ├── uart_tx.v
│   ├── uart_event_sender.v
│   ├── sevenseg_status.v
│   └── sevenseg_hex.v
├── firmware/
│   ├── firmware.hex
│   ├── firmware.S
│   ├── linker.ld
│   ├── Makefile
│   └── bin2hex.py
├── constraints/
│   └── basys3_riscv_lock.xdc
└── docs/
    └── final_project_report.pdf
```

## I/O Mapping

| Basys 3 I/O       | Function                          |
| ----------------- | --------------------------------- |
| `SW[9:8]`         | User ID                           |
| `SW[7:0]`         | 8-bit password input              |
| `BTNC`            | Submit                            |
| `BTNU`            | Reset                             |
| `LED0`            | PASS                              |
| `LED1`            | FAIL                              |
| `LED2`            | LOCK                              |
| 7-segment display | Shows `PASS`, `FAIL`, or `LOCK`   |
| UART TX           | Sends event string to PC terminal |

## User ID Mapping

| `SW[9:8]` | User   |
| --------- | ------ |
| `00`      | User 0 |
| `01`      | User 1 |
| `10`      | User 2 |
| `11`      | User 3 |

## Default Passwords

| User   | Password |
| ------ | -------- |
| User 0 | `0x12`   |
| User 1 | `0x34`   |
| User 2 | `0x56`   |
| User 3 | `0x78`   |

## System Behavior

The user selects a User ID using `SW[9:8]`, enters an 8-bit password using `SW[7:0]`, and presses `BTNC` to submit.

If the password is correct:

* `LED0` turns on
* The 7-segment display shows `PASS`
* UART TX outputs `USERx PASS`

If the password is wrong:

* `LED1` turns on
* The 7-segment display shows `FAIL`
* UART TX outputs `USERx FAIL`
* The corresponding user's `fail_count` is increased

If the same user enters the wrong password three times:

* The user is locked
* `LED2` turns on
* The 7-segment display shows `LOCK`
* UART TX outputs `USERx LOCK`

After a user is locked, that user cannot log in even with the correct password. Other users are not affected because each user has an independent `fail_count` and `lock_state`.

## Firmware

The RISC-V program used in this project is loaded as `firmware.hex`.

* `firmware.hex`: hexadecimal machine code loaded into Instruction Memory
* `firmware.S`: reference RISC-V assembly source included with the project files
* `linker.ld`: linker script
* `Makefile`: optional firmware build script
* `bin2hex.py`: optional binary-to-hex conversion script

Vivado loads `firmware.hex` through `$readmemh` in `basys3_riscv_lock_top.v`. The PicoRV32 CPU then executes the instructions from Instruction Memory.

Example:

```verilog
$readmemh("C:/Users/Jessie/Desktop/riscv_password_lock_basys3/firmware/firmware.hex", instr_mem);
```

Before generating the bitstream, make sure the `$readmemh` path in `basys3_riscv_lock_top.v` points to the correct `firmware.hex` location on your computer.

If you want to use a relative path instead, place `firmware.hex` in the Vivado project root directory and use:

```verilog
$readmemh("firmware.hex", instr_mem);
```

If the firmware is rebuilt, make sure the newly generated `firmware.hex` is copied to the path used by `$readmemh`.

## Vivado Setup

Create a new Vivado project for Basys 3 or the corresponding Artix-7 FPGA part:

```text
xc7a35tcpg236-1
```

Add the following Verilog files to Design Sources:

```text
rtl/basys3_riscv_lock_top.v
rtl/picorv32.v
rtl/uart_tx.v
rtl/uart_event_sender.v
rtl/sevenseg_status.v
rtl/sevenseg_hex.v
```

Note: `sevenseg_status.v` is the final 7-segment status display module. `sevenseg_hex.v` is kept as an optional/reference hexadecimal 7-segment decoder.

Add the following constraint file to Constraints:

```text
constraints/basys3_riscv_lock.xdc
```

Set the top module to:

```text
basys3_riscv_lock_top
```

Then run synthesis, implementation, generate the bitstream, and program the Basys 3 board.

## UART Setting

Use Tera Term, PuTTY, or another serial terminal with the following settings:

| Setting      | Value    |
| ------------ | -------- |
| Baud rate    | `115200` |
| Data bits    | `8`      |
| Parity       | `None`   |
| Stop bits    | `1`      |
| Flow control | `None`   |

To view UART output with Tera Term:

1. Connect the Basys 3 board to the PC using the USB cable.
2. Open Tera Term and select **Serial**.
3. Choose the COM port corresponding to the Basys 3 board.
4. Apply the UART settings above.
5. Program the FPGA and press `BTNC` after setting the switches. The terminal should display messages such as `USER0 PASS`, `USER0 FAIL`, or `USER0 LOCK`.

Example UART output:

```text
USER0 PASS
USER0 FAIL
USER0 LOCK
USER1 PASS
```

## Test Result Summary

The system was tested on the Basys 3 FPGA board.

| Test Case                                      | Expected Result                                                  |
| ---------------------------------------------- | ---------------------------------------------------------------- |
| User 0 correct password `0x12`                 | 7-segment shows `PASS`, LED0 turns on, UART outputs `USER0 PASS` |
| User 0 wrong password                          | 7-segment shows `FAIL`, LED1 turns on, UART outputs `USER0 FAIL` |
| User 0 wrong password three times              | 7-segment shows `LOCK`, LED2 turns on, UART outputs `USER0 LOCK` |
| User 0 locked, then correct password entered   | User 0 remains locked                                            |
| User 0 locked, User 1 correct password entered | User 1 still passes normally                                     |

Due to the limitation of the 7-segment display, some letters may be displayed using approximate segment patterns. However, the PASS / FAIL / LOCK states remain distinguishable.

## Notes

* `picorv32.v` is used as the RISC-V CPU core.
* The password lock logic is executed by the RISC-V CPU through `firmware.hex`.
* Verilog modules are responsible for SoC integration, memory-mapped I/O, LED output, 7-segment display formatting, and UART TX output formatting.
* `sevenseg_status.v` converts internal status codes into 7-segment display text.
* `uart_event_sender.v` converts event codes into full UART event strings.

## Future Improvements

* Add UART RX for password modification or administrator mode
* Add interrupt support instead of polling
* Add a complete debounce circuit for button input
* Add simulation testbenches and waveform verification
* Improve text display using LCD, OLED, or VGA output
