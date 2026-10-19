// =====================================================================
// alu.v — Combinational Arithmetic Logic Unit
// Segment 1: Baseline CPU Design
//
// Supports: ADD, SUB, MUL, AND, OR, XOR, SHL, SHR, CMP, MOVI (passthrough)
// =====================================================================
module alu #(
    parameter WIDTH = 8
) (
    input      [WIDTH-1:0] a,       // operand A (typically rs1)
    input      [WIDTH-1:0] b,       // operand B (rs2 or zero-extended immediate)
    input      [3:0]       op,      // operation select, driven by control_unit
    output reg [WIDTH-1:0] result,
    output                 zero     // 1 if result == 0 (useful for CMP/branches later)
);

    localparam OP_NOP  = 4'h0;
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

    always @(*) begin
        case (op)
            OP_ADD : result = a + b;
            OP_SUB : result = a - b;
            OP_MUL : result = a * b;         // truncates to WIDTH bits — fine at this scope
            OP_AND : result = a & b;
            OP_OR  : result = a | b;
            OP_XOR : result = a ^ b;
            OP_SHL : result = a << b[2:0];
            OP_SHR : result = a >> b[2:0];
            OP_CMP : result = a - b;         // result discarded by control unit; zero flag is the point
            OP_MOVI: result = b;             // pass immediate straight through
            default: result = {WIDTH{1'b0}};
        endcase
    end

    assign zero = (result == {WIDTH{1'b0}});

endmodule
