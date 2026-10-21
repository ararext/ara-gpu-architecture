#!/usr/bin/env bash
# run_tests.sh — assemble programs and run the whole regression suite.
# Run from the project root:   bash run_tests.sh
set -u
cd "$(dirname "$0")"

SRC="rtl/alu.v rtl/register_file.v rtl/program_counter.v rtl/instruction_memory.v \
rtl/control_unit.v rtl/cpu_top.v rtl/cpu_pipelined.v"
FAILED=0

run() {   # run <title> <iverilog args...>
    local title="$1"; shift
    iverilog -g2012 -o sim/_run.vvp "$@" || { echo "COMPILE ERROR: $title"; FAILED=1; return; }
    local out; out=$(vvp sim/_run.vvp 2>&1 | grep -v "Not enough words")
    echo "$out" | grep -E "===|PASS|FAIL|CPU|single|pipelined|Program"  # show the interesting lines
    echo "$out" | grep -qE "FAIL|FAILURE|TIMEOUT" && FAILED=1
    echo
}

echo "##### Assembling programs #####"
python3 tools/asm.py programs/segment1.asm      sim/program.hex
python3 tools/asm.py programs/hazard_chain.asm  sim/hazard_chain.hex
python3 tools/asm.py programs/independent.asm   sim/independent.hex
echo

echo "##### Segment 1 unit + integration tests #####"
run "ALU"           rtl/alu.v tb/alu_tb.v
run "Register file" rtl/register_file.v tb/register_file_tb.v
run "Single-cycle CPU" $SRC tb/cpu_tb.v

echo "##### Segment 2 pipeline tests (4 CPUs side by side per program) #####"
run "segment1 program" $SRC tb/pipeline_tb.v \
    -Ppipeline_tb.NAME=\"segment1\" -Ppipeline_tb.PROG=\"sim/program.hex\" \
    -Ppipeline_tb.E0=10 -Ppipeline_tb.E1=5 -Ppipeline_tb.E2=50 -Ppipeline_tb.E3=5 \
    -Ppipeline_tb.HAS_HAZARDS=1
run "hazard_chain" $SRC tb/pipeline_tb.v \
    -Ppipeline_tb.NAME=\"hazard_chain\" -Ppipeline_tb.PROG=\"sim/hazard_chain.hex\" \
    -Ppipeline_tb.E0=7 -Ppipeline_tb.E1=21 -Ppipeline_tb.E2=14 -Ppipeline_tb.E3=27 \
    -Ppipeline_tb.HAS_HAZARDS=1
run "independent" $SRC tb/pipeline_tb.v \
    -Ppipeline_tb.NAME=\"independent\" -Ppipeline_tb.PROG=\"sim/independent.hex\" \
    -Ppipeline_tb.E0=9 -Ppipeline_tb.E1=3 -Ppipeline_tb.E2=1 -Ppipeline_tb.E3=1 \
    -Ppipeline_tb.HAS_HAZARDS=0

rm -f sim/_run.vvp
if [ "$FAILED" -eq 0 ]; then echo "########## ALL SUITES PASSED ##########"; else echo "########## SOMETHING FAILED ##########"; exit 1; fi
