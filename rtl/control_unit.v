// =====================================================================
// control_unit.v — Decodes the 4-bit opcode into control signals.
// Segment 1: Baseline CPU Design
// Segment 2 addition: uses_rs1 / uses_rs2 tell the hazard logic which
// source registers an instruction actually READS. Without them, MOVI
// (which only uses an immediate) would look like it depends on whatever
// register number happens to sit in its rs1/rs2 bit-fields.
//
// Instruction format (12 bits): [opcode(4)][rd(2)][rs1(2)][rs2/imm(4)]
//   - Register ops use rs2/imm[1:0] as the rs2 register address.
//   - MOVI uses all 4 bits of rs2/imm as a zero-extended immediate.
// =====================================================================
module control_unit (
    input      [3:0] opcode,
    output reg        reg_write,   // 1 = write ALU result back to rd
    output reg [3:0]  alu_op,      // passed straight to the ALU
    output reg        use_imm,     // 1 = ALU operand B is the immediate
    output reg        halt,        // 1 = stop the CPU (freeze PC)
    output reg        uses_rs1,    // 1 = instruction reads register rs1
    output reg        uses_rs2     // 1 = instruction reads register rs2
);

    localparam OP_ADD  = 4'h1;
    localparam OP_SUB  = 4'h2;
    localparam OP_MUL  = 4'h3;
    localparam OP_AND  = 4'h4;
    localparam OP_OR   = 4'h5;
    localparam OP_XOR  = 4'h6;
    localparam OP_SHL  = 4'h7;
    localparam OP_SHR  = 4'h8;
    localparam OP_CMP  = 4'h9;
    localparam OP_MOVI = 4'hA;
    localparam OP_HALT = 4'hF;

    always @(*) begin
        alu_op  = opcode;                    // opcode doubles as ALU select
        use_imm = (opcode == OP_MOVI);
        halt    = (opcode == OP_HALT);

        case (opcode)
            OP_ADD, OP_SUB, OP_MUL, OP_AND, OP_OR, OP_XOR,
            OP_SHL, OP_SHR, OP_MOVI: reg_write = 1'b1;
            default:                 reg_write = 1'b0;   // NOP, CMP, HALT don't write
        endcase

        case (opcode)
            OP_ADD, OP_SUB, OP_MUL, OP_AND, OP_OR, OP_XOR,
            OP_SHL, OP_SHR, OP_CMP: begin
                uses_rs1 = 1'b1;
                uses_rs2 = 1'b1;
            end
            default: begin                   // NOP, MOVI, HALT read no registers
                uses_rs1 = 1'b0;
                uses_rs2 = 1'b0;
            end
        endcase
    end

endmodule
