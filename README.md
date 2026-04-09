# FPGA Verilog Labs - Basys 3

Verilog labs targeting the Digilent Basys 3 (Artix-7 XC7A35T) FPGA board, built with Xilinx Vivado.

## Labs

### Lab 0
- **Combinational Gates (Muxed)** — basic combinational logic with multiplexed outputs
- **4-Bit Comparator** — magnitude comparator
- **16-to-1 Multiplexer** — with enable

### Lab 1
- **Sequential ALU** — register file, adder, multiplier, UART interface

## Project Structure

```
lab_X/
├── src_labX/          # Source files (RTL, testbenches, constraints)
└── *_proj/            # Vivado project (not tracked except .xpr)
```

## Requirements

- Xilinx Vivado (tested with Vivado 2020.2+)
- Digilent Basys 3 board
