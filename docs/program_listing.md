# Segment 1 Test Program — Hand Assembly

Instruction format (12 bits): `[opcode(4)][rd(2)][rs1(2)][rs2/imm(4)]`

| # | Assembly            | opcode | rd | rs1 | rs2/imm | Binary         | Hex   |
|---|----------------------|--------|----|----|---------|----------------|-------|
| 0 | `MOVI R0, 10`        | A      | 00 | 00 | 1010    | 1010 00 00 1010 | a0a  |
| 1 | `MOVI R1, 5`         | A      | 01 | 00 | 0101    | 1010 01 00 0101 | a45  |
| 2 | `ADD  R2, R0, R1`    | 1      | 10 | 00 | 0001    | 0001 10 00 0001 | 181  |
| 3 | `SUB  R3, R0, R1`    | 2      | 11 | 00 | 0001    | 0010 11 00 0001 | 2c1  |
| 4 | `MUL  R2, R0, R1`    | 3      | 10 | 00 | 0001    | 0011 10 00 0001 | 381  |
| 5 | `HALT`               | F      | 00 | 00 | 0000    | 1111 00 00 0000 | f00  |

## Expected final architectural state

| Register | Expected value | Why |
|---|---|---|
| R0 | 10 | `MOVI R0, 10` |
| R1 | 5  | `MOVI R1, 5` |
| R2 | 50 | `ADD` sets it to 15, then `MUL` overwrites it with 10×5=50 — deliberately included to catch write-back ordering bugs |
| R3 | 5  | `SUB R3, R0, R1` = 10 − 5 |

This is the "golden" expected state `cpu_tb.v` checks against.
