// =============================================================================
// lfsr_rng.sv - 16-bit maximal-length LFSR, outputs piece index 1..7
// -----------------------------------------------------------------------------
`default_nettype none

module lfsr_rng (
    input  logic       clk,
    input  logic       rst_n,
    output logic [2:0] piece
);
    logic [15:0] r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) r <= 16'hACE1;
        else        r <= {r[14:0], r[15] ^ r[13] ^ r[12] ^ r[10]};
    end

    // Map lower bits to 1..7 (avoid 0 = empty)
    logic [2:0] raw;
    assign raw   = r[2:0];
    assign piece = (raw == 3'd0) ? 3'd7 : raw;
endmodule

`default_nettype wire
