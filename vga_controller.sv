// =============================================================================
// vga_controller.sv - 640x480 @ 60 Hz, 25 MHz pixel clock
// -----------------------------------------------------------------------------
// Timing (VESA DMT 4:3):
//   H: visible 640, FP 16, sync 96, BP 48, total 800
//   V: visible 480, FP 10, sync  2, BP 33, total 525
// Draws a 10x20 Tetris playfield centred on screen, each cell 20 px square,
// so playfield is 200x400. Border and background are filled with dark grey.
// =============================================================================
`default_nettype none

module vga_controller (
    input  logic        pix_clk,
    input  logic        rst_n,

    // framebuffer read port (10x20 grid, 3-bit colour index)
    output logic [9:0]  fb_raddr,
    input  logic [2:0]  fb_rdata,

    output logic [7:0]  VGA_R, VGA_G, VGA_B,
    output logic        VGA_HS, VGA_VS,
    output logic        VGA_BLANK_N, VGA_SYNC_N
);
    // timing constants
    localparam int H_VIS = 640, H_FP = 16, H_SY = 96, H_BP = 48;
    localparam int V_VIS = 480, V_FP = 10, V_SY =  2, V_BP = 33;
    localparam int H_TOT = H_VIS + H_FP + H_SY + H_BP; // 800
    localparam int V_TOT = V_VIS + V_FP + V_SY + V_BP; // 525

    // playfield geometry
    localparam int CELL = 20;
    localparam int PF_W = 10 * CELL;          // 200
    localparam int PF_H = 20 * CELL;          // 400
    localparam int PF_X0 = (H_VIS - PF_W)/2;  // 220
    localparam int PF_Y0 = (V_VIS - PF_H)/2;  // 40

    logic [9:0] hcnt;
    logic [9:0] vcnt;

    always_ff @(posedge pix_clk or negedge rst_n) begin
        if (!rst_n) begin
            hcnt <= '0;
            vcnt <= '0;
        end else begin
            if (hcnt == H_TOT-1) begin
                hcnt <= '0;
                vcnt <= (vcnt == V_TOT-1) ? '0 : vcnt + 1;
            end else begin
                hcnt <= hcnt + 1;
            end
        end
    end

    // sync (active low)
    assign VGA_HS = ~((hcnt >= H_VIS + H_FP) && (hcnt < H_VIS + H_FP + H_SY));
    assign VGA_VS = ~((vcnt >= V_VIS + V_FP) && (vcnt < V_VIS + V_FP + V_SY));

    logic visible;
    assign visible     = (hcnt < H_VIS) && (vcnt < V_VIS);
    assign VGA_BLANK_N = visible;
    assign VGA_SYNC_N  = 1'b0;

    // are we inside the playfield?
    logic in_pf;
    logic [9:0] px, py;      // local playfield pixel coords
    assign in_pf = (hcnt >= PF_X0) && (hcnt < PF_X0 + PF_W) &&
                   (vcnt >= PF_Y0) && (vcnt < PF_Y0 + PF_H);
    assign px = in_pf ? (hcnt - PF_X0[9:0]) : 10'd0;
    assign py = in_pf ? (vcnt - PF_Y0[9:0]) : 10'd0;

    logic [3:0] cell_col;
    logic [4:0] cell_row;
    assign cell_col = px[7:4] > 4'd9 ? 4'd9 : px / CELL;
    assign cell_row = py / CELL;

    // row-major address: row*10 + col
    assign fb_raddr = in_pf ? (cell_row * 10 + cell_col) : 10'd0;

    // grid lines inside playfield for a retro look
    logic on_grid;
    assign on_grid = in_pf && ((px % CELL == 0) || (py % CELL == 0));

    // colour LUT
    logic [23:0] rgb;
    always_comb begin
        unique case (fb_rdata)
            3'd0: rgb = 24'h101018; // empty
            3'd1: rgb = 24'h00FFFF; // I cyan
            3'd2: rgb = 24'hFFFF00; // O yellow
            3'd3: rgb = 24'hA000FF; // T purple
            3'd4: rgb = 24'h00FF00; // S green
            3'd5: rgb = 24'hFF0000; // Z red
            3'd6: rgb = 24'h0000FF; // J blue
            3'd7: rgb = 24'hFF7F00; // L orange
        endcase
    end

    logic [23:0] pix;
    always_comb begin
        if (!visible)          pix = 24'h000000;
        else if (!in_pf)       pix = 24'h202028;  // background
        else if (on_grid)      pix = 24'h303040;  // grid
        else                   pix = rgb;
    end

    assign VGA_R = pix[23:16];
    assign VGA_G = pix[15: 8];
    assign VGA_B = pix[ 7: 0];

endmodule

`default_nettype wire
