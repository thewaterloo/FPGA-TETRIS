// =============================================================================
// tetris_top.sv  -  FPGA Tetris top-level for Terasic DE1-SoC (Cyclone V)
// -----------------------------------------------------------------------------
// 50 MHz system clock in, 25.175 MHz pixel clock derived with a /2 divider
// (close enough for a tolerant VGA monitor; use an ALTPLL for perfect timing).
//
// Ports map 1:1 onto the DE1-SoC pinout in quartus/tetris.qsf.
// =============================================================================
`default_nettype none

module tetris_top (
    input  logic        CLOCK_50,
    input  logic [3:0]  KEY,        // active-low push buttons
    input  logic [9:0]  SW,
    output logic [9:0]  LEDR,
    output logic [6:0]  HEX0, HEX1, HEX2, HEX3,

    // VGA
    output logic [7:0]  VGA_R, VGA_G, VGA_B,
    output logic        VGA_HS, VGA_VS,
    output logic        VGA_BLANK_N, VGA_SYNC_N,
    output logic        VGA_CLK
);

    // ---------------------------------------------------------------- clocks
    logic pix_clk;
    logic rst_n;
    assign rst_n = KEY[0];

    // Simple /2 divider: 50 MHz -> 25 MHz (spec is 25.175, monitors tolerate).
    logic clk_div;
    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) clk_div <= 1'b0;
        else        clk_div <= ~clk_div;
    end
    assign pix_clk = clk_div;
    assign VGA_CLK = pix_clk;

    // ---------------------------------------------------------------- input
    logic left_e, right_e, rot_e, drop_e;
    input_handler u_input (
        .clk      (CLOCK_50),
        .rst_n    (rst_n),
        .key_n    (KEY[3:1]),
        .sw_drop  (SW[0]),
        .left_e   (left_e),
        .right_e  (right_e),
        .rot_e    (rot_e),
        .drop_e   (drop_e)
    );

    // ---------------------------------------------------------------- RNG
    logic [2:0] rng_piece;
    lfsr_rng u_rng (
        .clk     (CLOCK_50),
        .rst_n   (rst_n),
        .piece   (rng_piece)
    );

    // ---------------------------------------------------------------- game
    logic        we_fb;
    logic [9:0]  fb_waddr;
    logic [2:0]  fb_wdata;
    logic [15:0] score;
    logic        game_over;

    game_fsm u_fsm (
        .clk        (CLOCK_50),
        .rst_n      (rst_n),
        .left_e     (left_e),
        .right_e    (right_e),
        .rot_e      (rot_e),
        .drop_e     (drop_e),
        .rng_piece  (rng_piece),
        .fb_we      (we_fb),
        .fb_waddr   (fb_waddr),
        .fb_wdata   (fb_wdata),
        .score      (score),
        .game_over  (game_over)
    );

    // ---------------------------------------------------------------- FB
    // 10 cols x 20 rows = 200 cells, 3-bit colour index per cell.
    logic [9:0] fb_raddr;
    logic [2:0] fb_rdata;
    framebuffer #(.AW(10), .DW(3), .DEPTH(200)) u_fb (
        .wclk   (CLOCK_50),
        .we     (we_fb),
        .waddr  (fb_waddr),
        .wdata  (fb_wdata),
        .rclk   (pix_clk),
        .raddr  (fb_raddr),
        .rdata  (fb_rdata)
    );

    // ---------------------------------------------------------------- VGA
    vga_controller u_vga (
        .pix_clk     (pix_clk),
        .rst_n       (rst_n),
        .fb_raddr    (fb_raddr),
        .fb_rdata    (fb_rdata),
        .VGA_R       (VGA_R),
        .VGA_G       (VGA_G),
        .VGA_B       (VGA_B),
        .VGA_HS      (VGA_HS),
        .VGA_VS      (VGA_VS),
        .VGA_BLANK_N (VGA_BLANK_N),
        .VGA_SYNC_N  (VGA_SYNC_N)
    );

    // ---------------------------------------------------------------- HUD
    seg7 u_h0 (.bin(score[ 3: 0]), .seg(HEX0));
    seg7 u_h1 (.bin(score[ 7: 4]), .seg(HEX1));
    seg7 u_h2 (.bin(score[11: 8]), .seg(HEX2));
    seg7 u_h3 (.bin(score[15:12]), .seg(HEX3));

    assign LEDR = {9'b0, game_over};

endmodule

// -----------------------------------------------------------------------------
// seg7 : 4-bit hex to common-anode 7-seg
// -----------------------------------------------------------------------------
module seg7 (input logic [3:0] bin, output logic [6:0] seg);
    always_comb begin
        unique case (bin)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
        endcase
    end
endmodule

`default_nettype wire
