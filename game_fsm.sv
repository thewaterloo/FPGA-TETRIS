// =============================================================================
// game_fsm.sv - Tetris game state machine
// -----------------------------------------------------------------------------
// Maintains an internal 10x20 playfield (3-bit colour per cell). Handles:
//   * piece spawning from RNG
//   * left / right / rotate / soft-drop inputs (edge-triggered)
//   * gravity on a ~0.6 s tick
//   * collision detection against walls, floor, and locked cells
//   * line detection + clear + gravity on the stack above
//   * score (100 / 300 / 500 / 800 per 1/2/3/4 line clear)
//   * full-frame redraw into the dual-port framebuffer
// =============================================================================
`default_nettype none

module game_fsm (
    input  logic        clk,        // 50 MHz
    input  logic        rst_n,

    input  logic        left_e,
    input  logic        right_e,
    input  logic        rot_e,
    input  logic        drop_e,

    input  logic [2:0]  rng_piece,  // 1..7 from LFSR

    output logic        fb_we,
    output logic [9:0]  fb_waddr,
    output logic [2:0]  fb_wdata,

    output logic [15:0] score,
    output logic        game_over
);

    // ----------------------------------------------------------- grid store
    // 200 cells x 3 bits = 600 bits. Keep as packed 2-D for clarity.
    logic [2:0] grid [0:19][0:9];

    // piece state
    logic [2:0] cur_kind;     // 1..7
    logic [1:0] cur_rot;
    logic signed [4:0] cur_x; // anchor col
    logic signed [5:0] cur_y; // anchor row

    // ------------------------------------------------- piece shape function
    // Returns (dx,dy) for the i-th block of (kind,rot). 4 blocks per piece.
    // Shapes are the classic SRS-ish layouts; rotation is anchor-relative.
    function automatic void get_block (
        input  logic [2:0] kind,
        input  logic [1:0] rot,
        input  logic [1:0] idx,
        output logic signed [2:0] dx,
        output logic signed [2:0] dy
    );
        logic [4:0] sel;
        sel = {kind, rot};
        // Use a big case on {kind,rot,idx} - synthesises to a small LUT.
        case (kind)
            3'd1: begin // I
                case (rot[0])
                    1'b0: begin dx = idx - 2'd1; dy = 3'd0; end           // horiz
                    1'b1: begin dx = 3'd0;       dy = idx - 2'd1; end     // vert
                endcase
            end
            3'd2: begin // O (no rotation)
                case (idx)
                    2'd0: begin dx= 3'd0; dy= 3'd0; end
                    2'd1: begin dx= 3'd1; dy= 3'd0; end
                    2'd2: begin dx= 3'd0; dy= 3'd1; end
                    2'd3: begin dx= 3'd1; dy= 3'd1; end
                endcase
            end
            3'd3: begin // T
                case (rot)
                2'd0: case (idx) 2'd0:begin dx=-3'd1;dy=3'd0;end 2'd1:begin dx=3'd0;dy=3'd0;end 2'd2:begin dx=3'd1;dy=3'd0;end 2'd3:begin dx=3'd0;dy=3'd1;end endcase
                2'd1: case (idx) 2'd0:begin dx=3'd0;dy=-3'd1;end 2'd1:begin dx=3'd0;dy=3'd0;end 2'd2:begin dx=3'd0;dy=3'd1;end 2'd3:begin dx=-3'd1;dy=3'd0;end endcase
                2'd2: case (idx) 2'd0:begin dx=-3'd1;dy=3'd0;end 2'd1:begin dx=3'd0;dy=3'd0;end 2'd2:begin dx=3'd1;dy=3'd0;end 2'd3:begin dx=3'd0;dy=-3'd1;end endcase
                2'd3: case (idx) 2'd0:begin dx=3'd0;dy=-3'd1;end 2'd1:begin dx=3'd0;dy=3'd0;end 2'd2:begin dx=3'd0;dy=3'd1;end 2'd3:begin dx=3'd1;dy=3'd0;end endcase
                endcase
            end
            3'd4: begin // S
                case (rot[0])
                1'b0: case (idx) 2'd0:begin dx=3'd0;dy=3'd0;end 2'd1:begin dx=3'd1;dy=3'd0;end 2'd2:begin dx=-3'd1;dy=3'd1;end 2'd3:begin dx=3'd0;dy=3'd1;end endcase
                1'b1: case (idx) 2'd0:begin dx=3'd0;dy=-3'd1;end 2'd1:begin dx=3'd0;dy=3'd0;end 2'd2:begin dx=3'd1;dy=3'd0;end 2'd3:begin dx=3'd1;dy=3'd1;end endcase
                endcase
            end
            3'd5: begin // Z
                case (rot[0])
                1'b0: case (idx) 2'd0:begin dx=-3'd1;dy=3'd0;end 2'd1:begin dx=3'd0;dy=3'd0;end 2'd2:begin dx=3'd0;dy=3'd1;end 2'd3:begin dx=3'd1;dy=3'd1;end endcase
                1'b1: case (idx) 2'd0:begin dx=3'd1;dy=-3'd1;end 2'd1:begin dx=3'd0;dy=3'd0;end 2'd2:begin dx=3'd1;dy=3'd0;end 2'd3:begin dx=3'd0;dy=3'd1;end endcase
                endcase
            end
            3'd6: begin // J
                case (rot)
                2'd0: case (idx) 2'd0:begin dx=-3'd1;dy=3'd0;end 2'd1:begin dx=3'd0;dy=3'd0;end 2'd2:begin dx=3'd1;dy=3'd0;end 2'd3:begin dx=3'd1;dy=3'd1;end endcase
                2'd1: case (idx) 2'd0:begin dx=3'd0;dy=-3'd1;end 2'd1:begin dx=3'd0;dy=3'd0;end 2'd2:begin dx=3'd0;dy=3'd1;end 2'd3:begin dx=-3'd1;dy=3'd1;end endcase
                2'd2: case (idx) 2'd0:begin dx=-3'd1;dy=-3'd1;end 2'd1:begin dx=-3'd1;dy=3'd0;end 2'd2:begin dx=3'd0;dy=3'd0;end 2'd3:begin dx=3'd1;dy=3'd0;end endcase
                2'd3: case (idx) 2'd0:begin dx=3'd1;dy=-3'd1;end 2'd1:begin dx=3'd0;dy=-3'd1;end 2'd2:begin dx=3'd0;dy=3'd0;end 2'd3:begin dx=3'd0;dy=3'd1;end endcase
                endcase
            end
            3'd7: begin // L
                case (rot)
                2'd0: case (idx) 2'd0:begin dx=-3'd1;dy=3'd0;end 2'd1:begin dx=3'd0;dy=3'd0;end 2'd2:begin dx=3'd1;dy=3'd0;end 2'd3:begin dx=-3'd1;dy=3'd1;end endcase
                2'd1: case (idx) 2'd0:begin dx=-3'd1;dy=-3'd1;end 2'd1:begin dx=3'd0;dy=-3'd1;end 2'd2:begin dx=3'd0;dy=3'd0;end 2'd3:begin dx=3'd0;dy=3'd1;end endcase
                2'd2: case (idx) 2'd0:begin dx=3'd1;dy=-3'd1;end 2'd1:begin dx=-3'd1;dy=3'd0;end 2'd2:begin dx=3'd0;dy=3'd0;end 2'd3:begin dx=3'd1;dy=3'd0;end endcase
                2'd3: case (idx) 2'd0:begin dx=3'd0;dy=-3'd1;end 2'd1:begin dx=3'd0;dy=3'd0;end 2'd2:begin dx=3'd0;dy=3'd1;end 2'd3:begin dx=3'd1;dy=3'd1;end endcase
                endcase
            end
            default: begin dx = 3'd0; dy = 3'd0; end
        endcase
    endfunction

    // collision check for candidate (kind,rot,x,y)
    function automatic logic collides (
        input logic [2:0]        kind,
        input logic [1:0]        rot,
        input logic signed [4:0] x,
        input logic signed [5:0] y
    );
        logic signed [2:0] dx, dy;
        logic signed [5:0] nx, ny;
        logic              hit;
        hit = 1'b0;
        for (int i = 0; i < 4; i++) begin
            get_block(kind, rot, i[1:0], dx, dy);
            nx = x + dx;
            ny = y + dy;
            if (nx < 0 || nx > 9 || ny > 19)        hit = 1'b1;
            else if (ny >= 0 && grid[ny][nx] != 3'd0) hit = 1'b1;
        end
        return hit;
    endfunction

    // ------------------------------------------------------------ FSM state
    typedef enum logic [3:0] {
        S_RESET, S_SPAWN, S_PLAY, S_LOCK, S_LOCK_WR,
        S_CLEAR_SCAN, S_CLEAR_SHIFT, S_REDRAW, S_OVER
    } state_t;
    state_t state, nstate;

    // gravity tick: at 50 MHz, ~0.6 s = 30_000_000 cycles
    localparam int GRAV_MAX = 30_000_000;
    logic [24:0] grav_cnt;
    logic        grav_tick;

    // iterator regs
    logic [4:0]  it_row;
    logic [3:0]  it_col;
    logic [1:0]  lock_i;
    logic [7:0]  lines_this_turn;

    // framebuffer write
    logic        fb_we_r;
    logic [9:0]  fb_waddr_r;
    logic [2:0]  fb_wdata_r;
    assign fb_we    = fb_we_r;
    assign fb_waddr = fb_waddr_r;
    assign fb_wdata = fb_wdata_r;

    // -------------------------------------------------------------- gravity
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grav_cnt  <= '0;
            grav_tick <= 1'b0;
        end else begin
            grav_tick <= 1'b0;
            if (grav_cnt == GRAV_MAX-1) begin
                grav_cnt  <= '0;
                grav_tick <= 1'b1;
            end else begin
                grav_cnt <= grav_cnt + 1;
            end
        end
    end

    // -------------------------------------------------------------- main FSM
    integer r, c;
    logic signed [2:0] bdx, bdy;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_RESET;
            score      <= 16'd0;
            game_over  <= 1'b0;
            fb_we_r    <= 1'b0;
            fb_waddr_r <= '0;
            fb_wdata_r <= '0;
            it_row     <= '0;
            it_col     <= '0;
            lock_i     <= '0;
            lines_this_turn <= '0;
            cur_kind   <= 3'd1;
            cur_rot    <= 2'd0;
            cur_x      <= 5'd4;
            cur_y      <= 6'd0;
            for (r = 0; r < 20; r++)
                for (c = 0; c < 10; c++)
                    grid[r][c] <= 3'd0;
        end else begin
            fb_we_r <= 1'b0;

            unique case (state)
            // ------------------------------------------------------------
            S_RESET: begin
                state  <= S_REDRAW;
                it_row <= '0;
                it_col <= '0;
            end

            // ------------------------------------------------------------
            S_SPAWN: begin
                cur_kind <= (rng_piece == 3'd0) ? 3'd1 : rng_piece;
                cur_rot  <= 2'd0;
                cur_x    <= 5'd4;
                cur_y    <= 6'd1;
                if (collides((rng_piece==3'd0)?3'd1:rng_piece, 2'd0, 5'd4, 6'd1)) begin
                    game_over <= 1'b1;
                    state     <= S_OVER;
                end else begin
                    state <= S_PLAY;
                end
            end

            // ------------------------------------------------------------
            S_PLAY: begin
                // horizontal moves
                if (left_e  && !collides(cur_kind, cur_rot, cur_x - 1, cur_y)) cur_x <= cur_x - 1;
                if (right_e && !collides(cur_kind, cur_rot, cur_x + 1, cur_y)) cur_x <= cur_x + 1;
                if (rot_e   && !collides(cur_kind, cur_rot + 2'd1, cur_x, cur_y)) cur_rot <= cur_rot + 2'd1;

                if (drop_e || grav_tick) begin
                    if (!collides(cur_kind, cur_rot, cur_x, cur_y + 1)) begin
                        cur_y <= cur_y + 1;
                    end else begin
                        state  <= S_LOCK;
                        lock_i <= 2'd0;
                    end
                end
            end

            // ------------------------------------------------------------
            S_LOCK: begin
                // write the 4 blocks of the current piece into grid
                get_block(cur_kind, cur_rot, lock_i, bdx, bdy);
                if (cur_y + bdy >= 0 && cur_y + bdy <= 19 &&
                    cur_x + bdx >= 0 && cur_x + bdx <= 9) begin
                    grid[cur_y + bdy][cur_x + bdx] <= cur_kind;
                end
                if (lock_i == 2'd3) begin
                    state           <= S_CLEAR_SCAN;
                    it_row          <= 5'd0;
                    lines_this_turn <= 8'd0;
                end else begin
                    lock_i <= lock_i + 2'd1;
                end
            end

            // ------------------------------------------------------------
            S_CLEAR_SCAN: begin
                // check row it_row for a full line
                if (it_row < 5'd20) begin
                    logic full;
                    full = 1'b1;
                    for (c = 0; c < 10; c++)
                        if (grid[it_row][c] == 3'd0) full = 1'b0;
                    if (full) begin
                        // shift every row above down by one
                        for (r = 19; r > 0; r--)
                            if (r <= it_row)
                                for (c = 0; c < 10; c++)
                                    grid[r][c] <= grid[r-1][c];
                        for (c = 0; c < 10; c++) grid[0][c] <= 3'd0;
                        lines_this_turn <= lines_this_turn + 1;
                        // re-scan the same row since it now holds the row above
                    end else begin
                        it_row <= it_row + 1;
                    end
                end else begin
                    // done scanning -> score and redraw
                    case (lines_this_turn)
                        8'd1: score <= score + 16'd100;
                        8'd2: score <= score + 16'd300;
                        8'd3: score <= score + 16'd500;
                        8'd4: score <= score + 16'd800;
                        default: ;
                    endcase
                    it_row <= 5'd0;
                    it_col <= 4'd0;
                    state  <= S_REDRAW;
                end
            end

            // ------------------------------------------------------------
            S_REDRAW: begin
                // stream the whole 10x20 grid out to the framebuffer
                fb_we_r    <= 1'b1;
                fb_waddr_r <= it_row * 10 + it_col;
                fb_wdata_r <= grid[it_row][it_col];
                if (it_col == 4'd9) begin
                    it_col <= 4'd0;
                    if (it_row == 5'd19) begin
                        state <= (game_over) ? S_OVER : S_SPAWN;
                    end else begin
                        it_row <= it_row + 1;
                    end
                end else begin
                    it_col <= it_col + 1;
                end
            end

            // ------------------------------------------------------------
            S_OVER: begin
                // stay here; press reset to restart
            end

            default: state <= S_RESET;
            endcase
        end
    end

endmodule

`default_nettype wire
