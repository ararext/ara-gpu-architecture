#!/usr/bin/env python3
"""
asm.py — minimal assembler for the project's 12-bit ISA.

Usage:  python3 tools/asm.py input.asm output.hex

Instruction format (12 bits): [opcode(4)][rd(2)][rs1(2)][rs2/imm(4)]

Syntax (one instruction per line, ';' starts a comment):
    MOVI Rd, imm        ; imm is 0..15
    ADD  Rd, Rs1, Rs2   ; also SUB MUL AND OR XOR SHL SHR
    CMP  Rs1, Rs2
    NOP
    HALT
"""
import sys

OPCODES = {
    "NOP": 0x0, "ADD": 0x1, "SUB": 0x2, "MUL": 0x3, "AND": 0x4,
    "OR": 0x5, "XOR": 0x6, "SHL": 0x7, "SHR": 0x8, "CMP": 0x9,
    "MOVI": 0xA, "HALT": 0xF,
}
REG_OPS = {"ADD", "SUB", "MUL", "AND", "OR", "XOR", "SHL", "SHR"}


def reg(token, line_no):
    token = token.strip().upper()
    if len(token) != 2 or token[0] != "R" or token[1] not in "0123":
        raise ValueError(f"line {line_no}: bad register '{token}' (use R0..R3)")
    return int(token[1])


def assemble_line(text, line_no):
    parts = text.replace(",", " ").split()
    mnem = parts[0].upper()
    args = parts[1:]
    if mnem not in OPCODES:
        raise ValueError(f"line {line_no}: unknown instruction '{mnem}'")
    op = OPCODES[mnem]
    rd = rs1 = low = 0

    if mnem in ("NOP", "HALT"):
        if args:
            raise ValueError(f"line {line_no}: {mnem} takes no operands")
    elif mnem == "MOVI":
        if len(args) != 2:
            raise ValueError(f"line {line_no}: MOVI needs 'Rd, imm'")
        rd = reg(args[0], line_no)
        low = int(args[1], 0)
        if not 0 <= low <= 15:
            raise ValueError(f"line {line_no}: MOVI immediate must be 0..15")
    elif mnem == "CMP":
        if len(args) != 2:
            raise ValueError(f"line {line_no}: CMP needs 'Rs1, Rs2'")
        rs1, low = reg(args[0], line_no), reg(args[1], line_no)
    else:  # register-register ops
        if len(args) != 3:
            raise ValueError(f"line {line_no}: {mnem} needs 'Rd, Rs1, Rs2'")
        rd, rs1, low = (reg(a, line_no) for a in args)

    return (op << 8) | (rd << 6) | (rs1 << 4) | low


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    words = []
    with open(sys.argv[1]) as f:
        for n, raw in enumerate(f, start=1):
            text = raw.split(";")[0].strip()
            if text:
                words.append(assemble_line(text, n))
    with open(sys.argv[2], "w") as f:
        for w in words:
            f.write(f"{w:03x}\n")
    print(f"assembled {len(words)} instructions -> {sys.argv[2]}")


if __name__ == "__main__":
    main()
