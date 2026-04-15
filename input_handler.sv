// =============================================================================
// input_handler.sv - debounce + edge detect for DE1-SoC KEYs
// -----------------------------------------------------------------------------
// KEYs are active low. Produces a 1-cycle pulse on each press.
//   key_n[0] -> left
//   key_n[1] -> rotate
//   key_n[2] -> right
//   sw_drop  -> soft drop (SW0 held)  — edge-detected on rising edge
// =============================================================================
`default_nettype none

module input_handler (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [2:0] key_n,
    input  logic       sw_drop,
    output logic       left_e,
    output logic       right_e,
    output logic       rot_e,
    output logic       drop_e
);

    // ~10 ms debounce at 50 MHz ≈ 500_000 cycles
    localparam int DB_MAX = 500_000;

    logic [2:0] sync0, sync1;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync0 <= 3'b111;
            sync1 <= 3'b111;
        end else begin
            sync0 <= key_n;
            sync1 <= sync0;
        end
    end

    // Per-button debounce counters
    logic [2:0] stable;
    logic [2:0] stable_prev;
    logic [19:0] cnt [0:2];

    genvar g;
    generate
        for (g = 0; g < 3; g++) begin : g_db
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    cnt[g]    <= '0;
                    stable[g] <= 1'b1;
                end else begin
                    if (sync1[g] == stable[g]) begin
                        cnt[g] <= '0;
                    end else if (cnt[g] == DB_MAX-1) begin
                        stable[g] <= sync1[g];
                        cnt[g]    <= '0;
                    end else begin
                        cnt[g] <= cnt[g] + 1;
                    end
                end
            end
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) stable_prev <= 3'b111;
        else        stable_prev <= stable;
    end

    // Falling edge = key press
    assign left_e  = (stable_prev[0] & ~stable[0]);
    assign rot_e   = (stable_prev[1] & ~stable[1]);
    assign right_e = (stable_prev[2] & ~stable[2]);

    // Drop: rising edge of SW0 (sync'd)
    logic sw0_s0, sw0_s1, sw0_prev;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sw0_s0 <= 1'b0; sw0_s1 <= 1'b0; sw0_prev <= 1'b0;
        end else begin
            sw0_s0   <= sw_drop;
            sw0_s1   <= sw0_s0;
            sw0_prev <= sw0_s1;
        end
    end
    assign drop_e = sw0_s1 & ~sw0_prev;

endmodule

`default_nettype wire
