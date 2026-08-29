# UART – Universal Asynchronous Receiver Transmitter

## Overview
This project implements a **UART (Universal Asynchronous Receiver Transmitter)** in **Verilog HDL**.  
It includes both **UART Transmitter (TX)** and **UART Receiver (RX)** modules for serial communication.

The system operates with a **3.125 MHz clock** and supports a baud rate of approximately **115200 bps**.

---

## Features
- 8-bit UART communication
- Start bit detection
- Stop bit verification
- Even / Odd parity support
- FSM based design
- UART transmitter and receiver modules

---

## UART Frame Format

Start Bit | Data Bits | Parity Bit | Stop Bit  
0 | 8 bits | Even / Odd | 1

---

## Modules

### uart_rx.v
Receives serial UART data and converts it to parallel 8-bit data.

Outputs:
- `rx_msg` – received data
- `rx_parity` – parity bit
- `rx_complete` – reception complete signal

### uart_tx.v
Transmits 8-bit parallel data as serial UART frames.

Outputs:
- `tx` – serial transmit line
- `tx_done` – transmission complete signal

---

## Baud Rate Configuration

Clock Frequency: **3.125 MHz**

Receiver  
CLKS_PER_BIT = 28

Transmitter  
CLKS_PER_BIT = 27

Baud Rate ≈ **115200 bps**

---

## File Structure
```
uart
- uart_rx.v
- uart_tx.v
- README.md
```
---

## Tools Used
- Verilog HDL
- ModelSim
- Intel Quartus Prime

---

## Applications
- Embedded system communication
- FPGA serial interfaces
- Debug communication between devices
