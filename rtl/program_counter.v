// =====================================================================
// program_counter.v — increments each cycle unless held (e.g. on HALT).
// Jump port included now so Segment 2+ (branches/pipeline) doesn't need
// a rewrite, but is unused (tied off) in the Segment 1 top level.
// =====================================================================
module program_counter #(
    parameter WIDTH = 4
) (
    input                  clk,
    input                  rst,
    input                  hold,       // freeze PC (e.g. CPU halted)
    input                  jump,
    input      [WIDTH-1:0] jump_addr,
    output reg [WIDTH-1:0] pc
);

    always @(posedge clk or posedge rst) begin
        if (rst)
            pc <= {WIDTH{1'b0}};
        else if (jump)
            pc <= jump_addr;
        else if (!hold)
            pc <= pc + 1'b1;
    end

endmodule
