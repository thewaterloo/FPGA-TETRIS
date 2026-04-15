// =============================================================================
// tb_vga_controller.sv - checks a full frame of VGA sync timing
// =============================================================================
`timescale 1ns/1ps

module tb_vga_controller;
    logic pix_clk = 0;
    logic rst_n   = 0;

    logic [9:0] fb_raddr;
    logic [2:0] fb_rdata = 3'd0;

    wire [7:0] VGA_R, VGA_G, VGA_B;
    wire       VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N;

    vga_controller dut (.*);

    always #20 pix_clk = ~pix_clk;   // 25 MHz

    int hs_falls = 0;
    always @(negedge VGA_HS) hs_falls++;

    initial begin
        repeat (4) @(posedge pix_clk);
        rst_n = 1;
        // one full frame = 800*525 = 420_000 pix clocks
        repeat (420_100) @(posedge pix_clk);
        if (hs_falls != 525)
            $fatal(1, "expected 525 HS pulses in one frame, saw %0d", hs_falls);
        $display("[tb_vga] PASS: %0d HS pulses", hs_falls);
        $finish;
    end
endmodule
