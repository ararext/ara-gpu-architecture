// =====================================================================
// register_file.v — 4-register (default) file, synchronous write,
// combinational (asynchronous) dual read.
// Segment 1: Baseline CPU Design
// =====================================================================
module register_file #(
    parameter WIDTH = 8,
    parameter ADDR  = 2            // ADDR=2 -> 4 registers (R0..R3)
) (
    input                  clk,
    input                  rst,
    input                  we,      // write enable
    input      [ADDR-1:0]  waddr,
    input      [WIDTH-1:0] wdata,
    input      [ADDR-1:0]  raddr1,
    input      [ADDR-1:0]  raddr2,
    output     [WIDTH-1:0] rdata1,
    output     [WIDTH-1:0] rdata2
);

    localparam DEPTH = 1 << ADDR;

    reg [WIDTH-1:0] regs [0:DEPTH-1];
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < DEPTH; i = i + 1)
                regs[i] <= {WIDTH{1'b0}};
        end else if (we) begin
            regs[waddr] <= wdata;
        end
    end

    // Combinational read (single-cycle CPU style — fine for Segment 1;
    // Segment 2 pipelining will need to handle read/write same-cycle hazards).
    assign rdata1 = regs[raddr1];
    assign rdata2 = regs[raddr2];

endmodule
