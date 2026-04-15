// =============================================================================
// tb_tetris_top.sv - ModelSim smoke test
// -----------------------------------------------------------------------------
// Clocks the top-level, releases reset, fakes a few button presses, and runs
// long enough to exercise gravity and a lock/redraw cycle. No self-check — use
// this as a waveform driver, then eyeball VGA_HS/VGA_VS and score.
// =============================================================================
`timescale 1ns/1ps

module tb_tetris_top;
    logic        CLOCK_50 = 0;
    logic [3:0]  KEY  = 4'b1111;
    logic [9:0]  SW   = '0;
    wire  [9:0]  LEDR;
    wire  [6:0]  HEX0, HEX1, HEX2, HEX3;
    wire  [7:0]  VGA_R, VGA_G, VGA_B;
    wire         VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;

    tetris_top dut (.*);

    always #10 CLOCK_50 = ~CLOCK_50;   // 50 MHz

    task press(input int which);
        begin
            @(posedge CLOCK_50); KEY[which] = 1'b0;
            repeat (600_000) @(posedge CLOCK_50);  // hold past debounce
            KEY[which] = 1'b1;
            repeat (600_000) @(posedge CLOCK_50);
        end
    endtask

    initial begin
        $dumpfile("tetris.vcd");
        $dumpvars(0, tb_tetris_top);

        KEY[0] = 1'b0;           // assert reset
        repeat (10) @(posedge CLOCK_50);
        KEY[0] = 1'b1;

        repeat (300_000) @(posedge CLOCK_50);
        press(1);  // left
        press(2);  // rotate
        press(3);  // right

        // Let gravity drop the piece a few times
        repeat (120_000_000) @(posedge CLOCK_50);

        $display("[tb] done, score=%0d", dut.u_fsm.score);
        $finish;
    end
endmodule
