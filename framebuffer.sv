// =============================================================================
// framebuffer.sv - simple dual-clock, dual-port RAM
// -----------------------------------------------------------------------------
// Quartus infers a block-RAM from this style. Write on wclk, read on rclk.
// =============================================================================
`default_nettype none

module framebuffer #(
    parameter int AW    = 10,
    parameter int DW    = 3,
    parameter int DEPTH = 200
) (
    input  logic            wclk,
    input  logic            we,
    input  logic [AW-1:0]   waddr,
    input  logic [DW-1:0]   wdata,

    input  logic            rclk,
    input  logic [AW-1:0]   raddr,
    output logic [DW-1:0]   rdata
);
    logic [DW-1:0] mem [0:DEPTH-1];

    initial begin
        for (int i = 0; i < DEPTH; i++) mem[i] = '0;
    end

    always_ff @(posedge wclk) begin
        if (we) mem[waddr] <= wdata;
    end

    always_ff @(posedge rclk) begin
        rdata <= mem[raddr];
    end
endmodule

`default_nettype wire
