# Segment 2 — Pipelining and Hazard Handling (Checkpoint Notes)

## What was built

`rtl/cpu_pipelined.v` — a 4-stage pipelined version of the Segment 1 CPU.

```
  IF  ──►  [IF/ID]  ──►  ID  ──►  [ID/EX]  ──►  EX  ──►  [EX/WB]  ──►  WB
 fetch              decode +                  ALU +                  register
                    reg read +                forwarding             write
                    hazard check              muxes
```

- Each pipeline register carries a `valid` bit, so an empty slot ("bubble") is never mistaken for an instruction.
- `HAZARD_MODE` parameter selects how read-after-write (RAW) hazards are handled:
  - **0 — none**: unsafe on purpose, so the tests can prove they detect a broken pipeline.
  - **1 — stall**: the instruction in ID waits until its producer has written back.
  - **2 — forwarding**: the EX/WB result is routed back into the ALU inputs, plus a WB→ID bypass on the register read.
- HALT stops fetching and lets the pipeline drain; `halted` goes high when HALT reaches WB.
- Built-in counters: `cycle_cnt`, `retired_cnt`, `stall_cnt`.

Supporting changes: `control_unit.v` gained `uses_rs1` / `uses_rs2` (so MOVI is not mistaken for a register reader); `tools/asm.py` assembles `programs/*.asm` into hex.

## Measured results (Icarus Verilog, from `bash run_tests.sh`)

| Program | CPU | Registers R0..R3 | Cycles | Stalls | CPI |
|---|---|---|---|---|---|
| segment1 (6 instr) | single-cycle | 10 5 50 5 | 6 | 0 | 1.00 |
| | pipelined, no protection | 10 5 50 **10** (wrong) | 9 | 0 | 1.50 |
| | pipelined, stall | 10 5 50 5 | 11 | 2 | 1.83 |
| | pipelined, forwarding | 10 5 50 5 | 9 | 0 | 1.50 |
| hazard_chain (7 instr) | single-cycle | 7 21 14 27 | 7 | 0 | 1.00 |
| | pipelined, no protection | 7 5 249 0 (wrong) | 10 | 0 | 1.43 |
| | pipelined, stall | 7 21 14 27 | 18 | 8 | 2.57 |
| | pipelined, forwarding | 7 21 14 27 | 10 | 0 | 1.43 |
| independent (8 instr) | single-cycle | 9 3 1 1 | 8 | 0 | 1.00 |
| | all three pipelined modes | 9 3 1 1 | 11 | 0 | 1.38 |

## How to read these numbers (viva-ready)

1. **Pipeline fill cost.** A 4-stage pipeline needs 3 extra cycles to fill, so N instructions take N + 3 cycles at best. CPI = (N + 3) / N, which approaches 1.0 as programs get longer. On these 6 to 8 instruction programs the fill cost dominates, which is why CPI looks like 1.4 to 1.5.
2. **Why the pipeline is not "faster" here.** In cycle count alone, the single-cycle CPU wins on these tiny programs. The pipeline's advantage is clock frequency: each stage has a much shorter critical path than the whole single-cycle datapath, so the clock can run faster. That is measured with Vivado timing analysis in Segment 7, not in simulation. Do not claim a speedup before that measurement exists.
3. **Why stalling is expensive.** Stall mode loses cycles on every close dependency (`hazard_chain`: 8 stalls, CPI 2.57). Forwarding removes all of them, because every result in this ISA is produced in EX and can be forwarded straight back. CPI drops from 2.57 to 1.43.
4. **Why the unprotected pipeline is the most useful test.** It finishes fast but produces wrong answers (`7 5 249 0` instead of `7 21 14 27`). This shows the hazard tests can fail, so a pass in stall and forwarding mode actually means something.
5. **WAW case.** `hazard_chain` writes R0 twice in a row (`MOVI R0,5` then `MOVI R0,7`). The younger value must win. Forwarding handles this because the EX/WB forward overrides a stale bypass from the older write.

## Honest limitations (say these before an examiner asks)

- Forwarding eliminates all stalls **only because there is no LOAD yet.** A load-use hazard (data not available until a memory stage) needs one stall even with forwarding. That returns when data memory is added.
- No branches or jumps, so there are no control hazards and no flush logic yet. The PC's jump port is still tied off.
- Timing/frequency claims are deferred to Segment 7. Only cycle counts are measured here.

## Checkpoint log (fill in your own words)

- **What I built:**
A 4-stage pipelined version of my Segment 1 CPU (IF, ID, EX, WB) with pipeline
registers between the stages. Each register carries a valid bit so that empty
slots (bubbles) are never mistaken for real instructions. I added a
HAZARD_MODE parameter so the same design can run with no protection, with
stalling, or with forwarding. I also added cycle, retired-instruction and stall
counters, a small Python assembler, and a run_tests.sh script that runs every
testbench. Each test program runs on four CPUs side by side: the Segment 1
single-cycle CPU and the three pipeline modes.

**Results:**
- Forwarding mode never stalled and finished in N+3 cycles for N instructions.
  The extra 3 cycles are the cost of filling a 4-stage pipeline.
- On hazard_chain (dense dependencies), stalling took 18 cycles with 8 stalls
  (CPI 2.57). Forwarding took 10 cycles with 0 stalls (CPI 1.43).
- The unprotected pipeline gave wrong answers on dependent code (7 5 249 0
  instead of 7 21 14 27) but was correct on independent code.
- On these tiny programs the single-cycle CPU used fewer cycles. The pipeline's
  real benefit is a higher clock frequency, which I will measure in Vivado in
  Segment 7. I am not claiming a speedup yet.

**Biggest surprise:**
The unprotected pipeline runs fast and finishes cleanly, but the answers are
wrong. A hazard does not crash anything, it silently corrupts results. That is
why I kept a no-protection mode: it proves the tests can fail, so a pass in the
stall and forwarding modes actually means something.

**What would break if I removed the WB-to-ID bypass in forwarding mode?**
Dependencies two instructions apart. Forwarding into EX only covers a producer
that is one instruction ahead. When the producer is two ahead, it is in WB while
the consumer is in ID, and the register file has not been written yet, so the
consumer reads a stale value. I tested this: hazard_chain gave 7 19 12 2 instead
of 7 21 14 27 and the testbench failed.

**What would break if I removed the valid bits?**
(Reasoning, not yet tested.) Bubbles would look like real instructions, so the
retired-instruction count and CPI would be wrong, and the HALT and drain logic
would depend on every control signal of a bubble being zeroed perfectly. The
valid bit is the explicit marker that makes that safe.

**Limitations:**
Forwarding removes all stalls only because there is no LOAD yet. A load-use
hazard will need a stall even with forwarding. There are no branches yet, so no
control hazards or flush logic.

- **Waveform screenshot saved as:** `docs/seg2_waveform.png`
