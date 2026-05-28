`timescale 1ns / 1ps
//=============================================================================
// renderer.v
//
// Combinational pixel-color generator. Reads the current pixel position
// from vga_sync plus the entire game state and produces the 12-bit RGB
// output for that pixel.
//
// Sprite priority (highest first):
//   1. Game-state text overlay (GAME OVER / YOU WIN)
//   2. Lives HUD icons (top-left)
//   3. Player ship (with blink during damage flash)
//   4. Player bullet
//   5. Villain bullets
//   6. Villains (5x3 grid)
//   7. Black background
//=============================================================================
module renderer(
    input  wire [9:0]  pix_x,
    input  wire [9:0]  pix_y,
    input  wire        video_on,

    // --- Player ---
    input  wire [9:0]  player_x,
    input  wire        player_alive,
    input  wire        player_blink,

    // --- Villains ---
    input  wire [14:0] villain_alive,
    input  wire [9:0]  villain_base_x,
    input  wire [9:0]  villain_base_y,

    // --- Player bullet ---
    input  wire        pb_active,
    input  wire [9:0]  pb_x,
    input  wire [9:0]  pb_y,

    // --- 12 villain bullets ---
    input  wire [11:0] vb_active,
    input  wire [9:0]  vb_x_0,  vb_x_1,  vb_x_2,  vb_x_3,  vb_x_4,  vb_x_5,
    input  wire [9:0]  vb_x_6,  vb_x_7,  vb_x_8,  vb_x_9,  vb_x_10, vb_x_11,
    input  wire [9:0]  vb_y_0,  vb_y_1,  vb_y_2,  vb_y_3,  vb_y_4,  vb_y_5,
    input  wire [9:0]  vb_y_6,  vb_y_7,  vb_y_8,  vb_y_9,  vb_y_10, vb_y_11,

    // --- HUD / state ---
    input  wire [1:0]  lives,
    input  wire [1:0]  game_state,    // 00=PLAY 01=GAME_OVER 10=WIN

    // --- VGA outputs ---
    output reg  [3:0]  vgaRed,
    output reg  [3:0]  vgaGreen,
    output reg  [3:0]  vgaBlue
);

    // -------------------- Parameters --------------------
    localparam PLAYER_W   = 10'd16;
    localparam PLAYER_H   = 10'd8;
    localparam PLAYER_Y   = 10'd450;

    localparam V_W        = 10'd12;
    localparam V_H        = 10'd8;
    localparam V_CELL_W   = 10'd32;
    localparam V_CELL_H   = 10'd24;

    localparam PB_W       = 10'd2;
    localparam PB_H       = 10'd8;
    localparam VB_W       = 10'd2;
    localparam VB_H       = 10'd6;

    // Lives HUD: 3 ship icons in top-left
    localparam LIFE_W     = 10'd12;
    localparam LIFE_H     = 10'd6;
    localparam LIFE_Y     = 10'd10;
    localparam LIFE_X0    = 10'd10;
    localparam LIFE_PITCH = 10'd16;

    // Text overlay parameters (8x8 glyphs scaled 4x -> 32x32 each)
    // "GAME OVER" = 9 chars => 9*32 = 288 px wide
    // "YOU WIN"   = 7 chars => 7*32 = 224 px wide
    localparam TXT_SCALE  = 10'd4;     // 4x per side
    localparam TXT_W      = 10'd8;
    localparam TXT_H      = 10'd8;
    localparam TXT_CELL_W = TXT_W * TXT_SCALE;   // 32
    localparam TXT_CELL_H = TXT_H * TXT_SCALE;   // 32
    localparam GO_LEN     = 4'd9;                // "GAME OVER"
    localparam YW_LEN     = 4'd7;                // "YOU WIN"
    localparam GO_TXT_X   = (10'd640 - GO_LEN*TXT_CELL_W) / 2;   // (640-288)/2 = 176
    localparam YW_TXT_X   = (10'd640 - YW_LEN*TXT_CELL_W) / 2;   // (640-224)/2 = 208
    localparam TXT_Y      = 10'd200;

    // -------------------- Villain (x,y) lookups --------------------
    function [9:0] vx;
        input [3:0] idx;
        reg   [2:0] col;
        begin
            case (idx)
                4'd0,  4'd5,  4'd10: col = 3'd0;
                4'd1,  4'd6,  4'd11: col = 3'd1;
                4'd2,  4'd7,  4'd12: col = 3'd2;
                4'd3,  4'd8,  4'd13: col = 3'd3;
                default:             col = 3'd4;
            endcase
            vx = villain_base_x + ({7'd0, col} * V_CELL_W);
        end
    endfunction

    function [9:0] vy;
        input [3:0] idx;
        reg   [1:0] row;
        begin
            if      (idx <= 4'd4)  row = 2'd0;
            else if (idx <= 4'd9)  row = 2'd1;
            else                   row = 2'd2;
            vy = villain_base_y + ({8'd0, row} * V_CELL_H);
        end
    endfunction

    // -------------------- Per-pixel hit tests --------------------
    // Inside player ship sprite? Hide it during blink (every other "blink frame")
    wire in_player =
        player_alive && !player_blink &&
        (pix_x >= player_x) && (pix_x < player_x + PLAYER_W) &&
        (pix_y >= PLAYER_Y) && (pix_y < PLAYER_Y + PLAYER_H);

    // Inside player bullet?
    wire in_pb =
        pb_active &&
        (pix_x >= pb_x) && (pix_x < pb_x + PB_W) &&
        (pix_y >= pb_y) && (pix_y < pb_y + PB_H);

    // Inside any villain bullet?
    wire in_vb =
        (vb_active[0]  && pix_x>=vb_x_0  && pix_x<vb_x_0 +VB_W && pix_y>=vb_y_0  && pix_y<vb_y_0 +VB_H) ||
        (vb_active[1]  && pix_x>=vb_x_1  && pix_x<vb_x_1 +VB_W && pix_y>=vb_y_1  && pix_y<vb_y_1 +VB_H) ||
        (vb_active[2]  && pix_x>=vb_x_2  && pix_x<vb_x_2 +VB_W && pix_y>=vb_y_2  && pix_y<vb_y_2 +VB_H) ||
        (vb_active[3]  && pix_x>=vb_x_3  && pix_x<vb_x_3 +VB_W && pix_y>=vb_y_3  && pix_y<vb_y_3 +VB_H) ||
        (vb_active[4]  && pix_x>=vb_x_4  && pix_x<vb_x_4 +VB_W && pix_y>=vb_y_4  && pix_y<vb_y_4 +VB_H) ||
        (vb_active[5]  && pix_x>=vb_x_5  && pix_x<vb_x_5 +VB_W && pix_y>=vb_y_5  && pix_y<vb_y_5 +VB_H) ||
        (vb_active[6]  && pix_x>=vb_x_6  && pix_x<vb_x_6 +VB_W && pix_y>=vb_y_6  && pix_y<vb_y_6 +VB_H) ||
        (vb_active[7]  && pix_x>=vb_x_7  && pix_x<vb_x_7 +VB_W && pix_y>=vb_y_7  && pix_y<vb_y_7 +VB_H) ||
        (vb_active[8]  && pix_x>=vb_x_8  && pix_x<vb_x_8 +VB_W && pix_y>=vb_y_8  && pix_y<vb_y_8 +VB_H) ||
        (vb_active[9]  && pix_x>=vb_x_9  && pix_x<vb_x_9 +VB_W && pix_y>=vb_y_9  && pix_y<vb_y_9 +VB_H) ||
        (vb_active[10] && pix_x>=vb_x_10 && pix_x<vb_x_10+VB_W && pix_y>=vb_y_10 && pix_y<vb_y_10+VB_H) ||
        (vb_active[11] && pix_x>=vb_x_11 && pix_x<vb_x_11+VB_W && pix_y>=vb_y_11 && pix_y<vb_y_11+VB_H);

    // Inside any villain sprite (skipping dead ones)?
    wire [14:0] in_v_vec;
    genvar gi;
    generate
        for (gi = 0; gi < 15; gi = gi + 1) begin : g_in_v
            assign in_v_vec[gi] = villain_alive[gi] &&
                (pix_x >= vx(gi[3:0])) && (pix_x < vx(gi[3:0]) + V_W) &&
                (pix_y >= vy(gi[3:0])) && (pix_y < vy(gi[3:0]) + V_H);
        end
    endgenerate
    wire in_villain = |in_v_vec;

    // Inside lives HUD icon? lives in {0,1,2,3}; show one icon per remaining
    wire in_life0 = (lives >= 2'd1) &&
                    (pix_x >= LIFE_X0) && (pix_x < LIFE_X0 + LIFE_W) &&
                    (pix_y >= LIFE_Y) && (pix_y < LIFE_Y + LIFE_H);
    wire in_life1 = (lives >= 2'd2) &&
                    (pix_x >= LIFE_X0 + LIFE_PITCH) && (pix_x < LIFE_X0 + LIFE_PITCH + LIFE_W) &&
                    (pix_y >= LIFE_Y) && (pix_y < LIFE_Y + LIFE_H);
    wire in_life2 = (lives >= 2'd3) &&
                    (pix_x >= LIFE_X0 + 2*LIFE_PITCH) && (pix_x < LIFE_X0 + 2*LIFE_PITCH + LIFE_W) &&
                    (pix_y >= LIFE_Y) && (pix_y < LIFE_Y + LIFE_H);
    wire in_lives = in_life0 | in_life1 | in_life2;

    // -------------------- Text overlay --------------------
    // For GAME OVER / YOU WIN, look up the current character and call into
    // text_rom for the glyph bit.
    // Character indices in text_rom:
    //   0=' ' 1='G' 2='A' 3='M' 4='E' 5='O' 6='V' 7='R' 8='Y' 9='U' 10='W' 11='I' 12='N'
    // "GAME OVER" = G(1) A(2) M(3) E(4) ' '(0) O(5) V(6) E(4) R(7)
    // "YOU WIN"   = Y(8) O(5) U(9) ' '(0) W(10) I(11) N(12)

    // Common arithmetic: which character cell + sub-pixel within
    wire show_go = (game_state == 2'b01);
    wire show_yw = (game_state == 2'b10);
    wire show_text = show_go | show_yw;

    // Compute character index, scaled pixel position
    wire [9:0] txt_x_base = show_go ? GO_TXT_X : YW_TXT_X;
    wire [3:0] txt_len    = show_go ? GO_LEN  : YW_LEN;

    wire txt_y_in = (pix_y >= TXT_Y) && (pix_y < TXT_Y + TXT_CELL_H);
    wire txt_x_in = (pix_x >= txt_x_base) && (pix_x < txt_x_base + {6'd0, txt_len} * TXT_CELL_W);

    // (col_idx is the character index in the string)
    wire [9:0] tx_off   = pix_x - txt_x_base;
    wire [9:0] ty_off   = pix_y - TXT_Y;
    // Divide by 32 = >> 5 (since TXT_CELL_W=32)
    wire [4:0] col_idx5 = tx_off[9:5];
    // Sub-pixel position 0..31, then scaled down to 0..7 by >> 2
    wire [4:0] sub_x    = tx_off[4:0];
    wire [4:0] sub_y    = ty_off[4:0];
    wire [2:0] glyph_col = sub_x[4:2];
    wire [2:0] glyph_row = sub_y[4:2];

    // Pick the glyph char index for this column position
    reg [3:0] glyph_ch;
    always @* begin
        if (show_go) begin
            case (col_idx5)
                5'd0: glyph_ch = 4'd1;   // G
                5'd1: glyph_ch = 4'd2;   // A
                5'd2: glyph_ch = 4'd3;   // M
                5'd3: glyph_ch = 4'd4;   // E
                5'd4: glyph_ch = 4'd0;   // space
                5'd5: glyph_ch = 4'd5;   // O
                5'd6: glyph_ch = 4'd6;   // V
                5'd7: glyph_ch = 4'd4;   // E
                5'd8: glyph_ch = 4'd7;   // R
                default: glyph_ch = 4'd0;
            endcase
        end else if (show_yw) begin
            case (col_idx5)
                5'd0: glyph_ch = 4'd8;   // Y
                5'd1: glyph_ch = 4'd5;   // O
                5'd2: glyph_ch = 4'd9;   // U
                5'd3: glyph_ch = 4'd0;   // space
                5'd4: glyph_ch = 4'd10;  // W
                5'd5: glyph_ch = 4'd11;  // I
                5'd6: glyph_ch = 4'd12;  // N
                default: glyph_ch = 4'd0;
            endcase
        end else begin
            glyph_ch = 4'd0;
        end
    end

    wire glyph_pix;
    text_rom u_txt (
        .ch  (glyph_ch),
        .col (glyph_col),
        .row (glyph_row),
        .pix (glyph_pix)
    );

    wire in_text = show_text && txt_x_in && txt_y_in && glyph_pix;

    // -------------------- Final color selection --------------------
    always @* begin
        if (!video_on) begin
            vgaRed   = 4'h0;
            vgaGreen = 4'h0;
            vgaBlue  = 4'h0;
        end else if (in_text) begin
            // Yellow on WIN, red-ish white on GAME OVER
            if (show_yw) begin
                vgaRed   = 4'hF;
                vgaGreen = 4'hF;
                vgaBlue  = 4'h0;
            end else begin
                vgaRed   = 4'hF;
                vgaGreen = 4'h4;
                vgaBlue  = 4'h4;
            end
        end else if (in_lives) begin
            // Green ship icons
            vgaRed   = 4'h0;
            vgaGreen = 4'hF;
            vgaBlue  = 4'h0;
        end else if (in_player) begin
            // Green
            vgaRed   = 4'h0;
            vgaGreen = 4'hF;
            vgaBlue  = 4'h0;
        end else if (in_pb) begin
            // White
            vgaRed   = 4'hF;
            vgaGreen = 4'hF;
            vgaBlue  = 4'hF;
        end else if (in_vb) begin
            // Yellow
            vgaRed   = 4'hF;
            vgaGreen = 4'hF;
            vgaBlue  = 4'h0;
        end else if (in_villain) begin
            // Red
            vgaRed   = 4'hF;
            vgaGreen = 4'h0;
            vgaBlue  = 4'h0;
        end else begin
            // Black background
            vgaRed   = 4'h0;
            vgaGreen = 4'h0;
            vgaBlue  = 4'h0;
        end
    end

endmodule