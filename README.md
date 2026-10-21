# Simplified GPU Architecture — RTL Project

Final-year project: designing a simplified GPU from scratch in Verilog HDL,
built up incrementally from a baseline scalar CPU toward a SIMD/SIMT-style
processing element array, targeting FPGA implementation.

**Scope note:** this project implements SIMD-style execution with per-lane
thread masking, not full per-thread divergent control flow (full SIMT).
That distinction is intentional and documented — see `docs/`.

## Status

- [x] **Segment 1 — Baseline CPU** (single-cycle): ALU, register file, PC,
      instruction memory, control unit — verified in simulation.
- [x] **Segment 2 — Pipelining + hazard handling**: 4-stage pipeline (IF/ID/EX/WB)
      with selectable no-protection / stall / forwarding modes, performance counters,
      and a mini assembler — see `docs/segment2_notes.md`.
- [ ] Segment 3 — SIMD PE array
- [ ] Segment 4 — GPU execution model (FSM, FIFO, thread masking)
- [ ] Segment 5 — Graphics & rasterization
- [ ] Segment 6 — Verification / regression suite
- [ ] Segment 7 — FPGA deployment

## Project structure

```
gpu-project/
├── rtl/      Verilog source: alu, register_file, program_counter, instruction_memory,
│             control_unit, cpu_top (Segment 1 single-cycle), cpu_pipelined (Segment 2)
├── tb/       Testbenches: unit tests, single-cycle integration test, pipeline_tb
├── programs/ Test programs in readable assembly (.asm)
├── tools/    asm.py — assembler (.asm -> .hex)
├── sim/      Assembled .hex programs and generated waveforms (gitignored)
├── docs/     Program listings, checkpoint notes, design decisions
└── run_tests.sh   One-command regression: assemble + run every testbench
```

## Instruction format (12 bits)

```
[ opcode(4) ][ rd(2) ][ rs1(2) ][ rs2 / immediate(4) ]
```

Opcodes: `1`=ADD `2`=SUB `3`=MUL `4`=AND `5`=OR `6`=XOR `7`=SHL `8`=SHR
`9`=CMP `A`=MOVI `F`=HALT. Full bit-by-bit breakdown of the sample program
is in `docs/program_listing.md`.

## Quick start (runs everything)

```bash
bash run_tests.sh
```

## Building and running the testbenches individually

Requires [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog`/`vvp`) and Python 3 —
install via `sudo apt install iverilog` / `brew install icarus-verilog`.

```bash
# ALU unit test
iverilog -g2012 -o sim/alu_tb.vvp rtl/alu.v tb/alu_tb.v
vvp sim/alu_tb.vvp

# Register file unit test
iverilog -g2012 -o sim/register_file_tb.vvp rtl/register_file.v tb/register_file_tb.v
vvp sim/register_file_tb.vvp

# Full CPU integration test
iverilog -g2012 -o sim/cpu_tb.vvp \
    rtl/alu.v rtl/register_file.v rtl/program_counter.v \
    rtl/instruction_memory.v rtl/control_unit.v rtl/cpu_top.v \
    tb/cpu_tb.v
vvp sim/cpu_tb.vvp
```

All three currently pass (`run_tests.sh` also runs the Segment 2 pipeline tests). View waveforms with `gtkwave sim/cpu_tb.vcd` after
running (the `.vcd` files are generated locally and gitignored).

## Toolchain

Verilog HDL · Icarus Verilog / ModelSim (simulation) · Xilinx Vivado / Quartus
(synthesis, later segments) · GTKWave (waveform viewing)
