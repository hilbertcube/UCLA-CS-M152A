`timescale 1ns / 1ps
//=============================================================================
// game_logic.v
//
// Core game state machine for Space Invaders. Advances on game_tick.
//
//  - 15 villains in 5x3 grid. Index i, with col(i) = i%5, row(i) = i/5.
//      Sprite at:  x = villain_base_x + col*32
//                  y = villain_base_y + row*24
//      Sprite size 12x8 in a 32x24 cell.
//
//  - 3 player bullets (active flag + x,y each), travel up   4 px/tick
//  - 12 villain bullets (one-hot active + x,y),  travel down 4 px/tick
//
//  - Player moves +/-4 px/tick while btnL or btnR held; clamped to [0..624]
//  - Villains shift +/-2 px/tick; flip direction at screen edges
//  - Every 90 ticks (~1.5 s @ 60Hz), up to 3 villains fire bullets,
//      villain indices selected by an LFSR
//
// Full game state is wired out in parallel for the renderer.
//=============================================================================
module game_logic(
    input  wire        clk,
    input  wire        rst,
    input  wire        game_tick,
    input  wire        btnL,
    input  wire        btnR,
    input  wire        fire_pulse,

    // --- Player ---
    output reg  [9:0]  player_x,
    output reg         player_alive,
    output reg         player_blink,

    // --- Villains (5x3 grid) ---
    output reg  [14:0] villain_alive,
    output reg  [9:0]  villain_base_x,
    output reg  [9:0]  villain_base_y,

    // --- Player bullets (3 slots) ---
    output reg  [2:0]  pb_active,
    output reg  [9:0]  pb_x_0, pb_x_1, pb_x_2,
    output reg  [9:0]  pb_y_0, pb_y_1, pb_y_2,

    // --- 12 villain bullets (broken out for renderer) ---
    output reg  [11:0] vb_active,
    output reg  [9:0]  vb_x_0,  vb_x_1,  vb_x_2,  vb_x_3,  vb_x_4,  vb_x_5,
    output reg  [9:0]  vb_x_6,  vb_x_7,  vb_x_8,  vb_x_9,  vb_x_10, vb_x_11,
    output reg  [9:0]  vb_y_0,  vb_y_1,  vb_y_2,  vb_y_3,  vb_y_4,  vb_y_5,
    output reg  [9:0]  vb_y_6,  vb_y_7,  vb_y_8,  vb_y_9,  vb_y_10, vb_y_11,

    // --- HUD ---
    output reg  [1:0]  lives,
    output reg  [13:0] score,
    output reg  [1:0]  game_state   // 00=PLAY, 01=GAME_OVER, 10=WIN
);

    // -------------------- Parameters --------------------
    localparam SCREEN_W   = 10'd640;
    localparam SCREEN_H   = 10'd480;

    // Player sprite 32x16 (2x scaled ROM), fixed Y near bottom
    localparam PLAYER_W   = 10'd32;
    localparam PLAYER_H   = 10'd16;
    localparam PLAYER_Y   = 10'd450;
    localparam PLAYER_MAX_X = SCREEN_W - PLAYER_W;   // 624
    localparam PLAYER_SPD = 10'd4;                   // player movement px/tick

    // Villain sprite 24x16 (2x scaled ROM), cell 40x32
    localparam V_W        = 10'd24;
    localparam V_H        = 10'd16;
    localparam V_CELL_W   = 10'd40;
    localparam V_CELL_H   = 10'd32;
    localparam V_GRID_W   = V_CELL_W * 10'd5;   // 160 px wide
    localparam V_BASE_X_INIT = 10'd80;
    localparam V_BASE_Y_INIT = 10'd60;

    // Bullets
    localparam PB_W       = 10'd2;
    localparam PB_H       = 10'd8;
    localparam VB_W       = 10'd2;
    localparam VB_H       = 10'd6;
    localparam BULLET_SPD = 10'd4;
    localparam VILLAIN_SPD= 10'd2;

    // Game states
    localparam ST_PLAY      = 2'b00;
    localparam ST_GAME_OVER = 2'b01;
    localparam ST_WIN       = 2'b10;

    // Villain movement direction
    localparam DIR_RIGHT    = 1'b0;
    localparam DIR_LEFT     = 1'b1;
    reg villain_dir;

    // Damage-flash timer (player blinks while > 0; invulnerable too)
    reg [6:0] blink_cnt;

    // LFSR for pseudo-random shooter selection
    reg [15:0] lfsr;

    // Shooting cooldown counter
    reg [6:0] shoot_cnt;
    localparam SHOOT_PERIOD = 7'd45;   // ~0.75 sec @ 60 Hz (doubled fire rate)

    // -------------------- Combinational helpers --------------------
    // Villain (col,row) -> screen x,y. Compute from index 0..14.
    // col = i%5,  row = i/5 (constant divisor by 5 -> use a small lookup).
    function [9:0] vill_x;
        input [3:0] idx;
        reg   [2:0] col;
        begin
            case (idx)
                4'd0,  4'd5,  4'd10: col = 3'd0;
                4'd1,  4'd6,  4'd11: col = 3'd1;
                4'd2,  4'd7,  4'd12: col = 3'd2;
                4'd3,  4'd8,  4'd13: col = 3'd3;
                default:             col = 3'd4;  // 4, 9, 14
            endcase
            vill_x = villain_base_x + ({7'd0, col} * V_CELL_W);
        end
    endfunction

    function [9:0] vill_y;
        input [3:0] idx;
        reg   [1:0] row;
        begin
            if      (idx <= 4'd4)  row = 2'd0;
            else if (idx <= 4'd9)  row = 2'd1;
            else                   row = 2'd2;
            vill_y = villain_base_y + ({8'd0, row} * V_CELL_H);
        end
    endfunction

    // AABB collision: true if box A overlaps box B
    function aabb_overlap;
        input [9:0] ax, ay, aw, ah;
        input [9:0] bx, by, bw, bh;
        begin
            aabb_overlap = (ax < bx + bw) && (ax + aw > bx) &&
                           (ay < by + bh) && (ay + ah > by);
        end
    endfunction

    // Walls (must match renderer.v constants)
    localparam WALL_W      = 10'd32;
    localparam WALL_H      = 10'd22;
    localparam WALL_Y      = 10'd330;
    localparam WALL_ARCH_X = 10'd11;
    localparam WALL_ARCH_W = 10'd10;
    localparam WALL_ARCH_Y = 10'd12;
    localparam WALL0_X     = 10'd64;
    localparam WALL1_X     = 10'd224;
    localparam WALL2_X     = 10'd384;
    localparam WALL3_X     = 10'd544;

    // True if bullet (bx,by,bw,bh) hits the solid region of the wall at wx.
    // Wall solid = top block + left pillar + right pillar (arch cutout excluded).
    function bullet_hits_wall;
        input [9:0] bx, by, bw, bh, wx;
        begin
            bullet_hits_wall =
                // top block: full width, above arch
                aabb_overlap(bx, by, bw, bh, wx, WALL_Y, WALL_W, WALL_ARCH_Y) ||
                // left pillar
                aabb_overlap(bx, by, bw, bh, wx, WALL_Y + WALL_ARCH_Y,
                             WALL_ARCH_X, WALL_H - WALL_ARCH_Y) ||
                // right pillar
                aabb_overlap(bx, by, bw, bh,
                             wx + WALL_ARCH_X + WALL_ARCH_W,
                             WALL_Y + WALL_ARCH_Y,
                             WALL_W - WALL_ARCH_X - WALL_ARCH_W,
                             WALL_H - WALL_ARCH_Y);
        end
    endfunction

    function any_wall_hit;
        input [9:0] bx, by, bw, bh;
        begin
            any_wall_hit = bullet_hits_wall(bx, by, bw, bh, WALL0_X) ||
                           bullet_hits_wall(bx, by, bw, bh, WALL1_X) ||
                           bullet_hits_wall(bx, by, bw, bh, WALL2_X) ||
                           bullet_hits_wall(bx, by, bw, bh, WALL3_X);
        end
    endfunction

    wire any_villain_alive = |villain_alive;

    // --- Pre-compute bullet/villain x,y for combinational collision checks ---
    // These wires reflect *current registered* values; collisions are
    // evaluated against pre-tick positions, which is fine.
    wire [9:0] vx [0:14];
    wire [9:0] vy [0:14];
    genvar gi;
    generate
        for (gi = 0; gi < 15; gi = gi + 1) begin : g_vpos
            assign vx[gi] = vill_x(gi[3:0]);
            assign vy[gi] = vill_y(gi[3:0]);
        end
    endgenerate

    // Pack villain bullet x/y into indexed wires too for cleaner sequential code
    wire [9:0] vbx [0:11];
    wire [9:0] vby [0:11];
    assign vbx[0]=vb_x_0;   assign vby[0]=vb_y_0;
    assign vbx[1]=vb_x_1;   assign vby[1]=vb_y_1;
    assign vbx[2]=vb_x_2;   assign vby[2]=vb_y_2;
    assign vbx[3]=vb_x_3;   assign vby[3]=vb_y_3;
    assign vbx[4]=vb_x_4;   assign vby[4]=vb_y_4;
    assign vbx[5]=vb_x_5;   assign vby[5]=vb_y_5;
    assign vbx[6]=vb_x_6;   assign vby[6]=vb_y_6;
    assign vbx[7]=vb_x_7;   assign vby[7]=vb_y_7;
    assign vbx[8]=vb_x_8;   assign vby[8]=vb_y_8;
    assign vbx[9]=vb_x_9;   assign vby[9]=vb_y_9;
    assign vbx[10]=vb_x_10; assign vby[10]=vb_y_10;
    assign vbx[11]=vb_x_11; assign vby[11]=vb_y_11;

    // Pack player bullet x/y for indexed access in collision logic
    wire [9:0] pbx [0:2];
    wire [9:0] pby [0:2];
    assign pbx[0] = pb_x_0; assign pby[0] = pb_y_0;
    assign pbx[1] = pb_x_1; assign pby[1] = pb_y_1;
    assign pbx[2] = pb_x_2; assign pby[2] = pb_y_2;

    // Hit-detection wires (combinational) - per-bullet vector showing which
    // villain (if any) each player bullet collides with. Priority = lowest index.
    wire [14:0] pb_vill_hit_vec_0;
    wire [14:0] pb_vill_hit_vec_1;
    wire [14:0] pb_vill_hit_vec_2;
    generate
        for (gi = 0; gi < 15; gi = gi + 1) begin : g_pb_hit
            assign pb_vill_hit_vec_0[gi] = pb_active[0] && villain_alive[gi] &&
                aabb_overlap(pbx[0], pby[0], PB_W, PB_H, vx[gi], vy[gi], V_W, V_H);
            assign pb_vill_hit_vec_1[gi] = pb_active[1] && villain_alive[gi] &&
                aabb_overlap(pbx[1], pby[1], PB_W, PB_H, vx[gi], vy[gi], V_W, V_H);
            assign pb_vill_hit_vec_2[gi] = pb_active[2] && villain_alive[gi] &&
                aabb_overlap(pbx[2], pby[2], PB_W, PB_H, vx[gi], vy[gi], V_W, V_H);
        end
    endgenerate
    wire pb_hit_0 = |pb_vill_hit_vec_0;
    wire pb_hit_1 = |pb_vill_hit_vec_1;
    wire pb_hit_2 = |pb_vill_hit_vec_2;

    // Which villain bullet hit the player?
    wire [11:0] vb_hit_vec;
    generate
        for (gi = 0; gi < 12; gi = gi + 1) begin : g_vb_hit
            assign vb_hit_vec[gi] = vb_active[gi] &&
                aabb_overlap(vbx[gi], vby[gi], VB_W, VB_H,
                             player_x, PLAYER_Y, PLAYER_W, PLAYER_H);
        end
    endgenerate
    wire vb_any_hit = |vb_hit_vec;

    // LFSR-derived shooter indices (clamped to 0..14)
    // Replace mod-15 with conditional subtract.
    wire [3:0] s1_raw = lfsr[3:0];
    wire [3:0] s2_raw = lfsr[7:4];
    wire [3:0] s3_raw = lfsr[11:8];
    wire [3:0] shoot1 = (s1_raw >= 4'd15) ? (s1_raw - 4'd15) : s1_raw;
    wire [3:0] shoot2 = (s2_raw >= 4'd15) ? (s2_raw - 4'd15) : s2_raw;
    wire [3:0] shoot3 = (s3_raw >= 4'd15) ? (s3_raw - 4'd15) : s3_raw;

    // -------------------- Sequential block --------------------
    always @(posedge clk) begin
        if (rst) begin
            // Player
            player_x       <= 10'd304;     // (640-32)/2 = 304
            player_alive   <= 1'b1;
            player_blink   <= 1'b0;
            blink_cnt      <= 7'd0;
            // Villains
            villain_alive  <= 15'h7FFF;
            villain_base_x <= V_BASE_X_INIT;
            villain_base_y <= V_BASE_Y_INIT;
            villain_dir    <= DIR_RIGHT;
            // Bullets
            pb_active      <= 3'd0;
            pb_x_0 <= 10'd0; pb_y_0 <= 10'd0;
            pb_x_1 <= 10'd0; pb_y_1 <= 10'd0;
            pb_x_2 <= 10'd0; pb_y_2 <= 10'd0;
            vb_active      <= 12'd0;
            vb_x_0  <= 10'd0; vb_y_0  <= 10'd0;
            vb_x_1  <= 10'd0; vb_y_1  <= 10'd0;
            vb_x_2  <= 10'd0; vb_y_2  <= 10'd0;
            vb_x_3  <= 10'd0; vb_y_3  <= 10'd0;
            vb_x_4  <= 10'd0; vb_y_4  <= 10'd0;
            vb_x_5  <= 10'd0; vb_y_5  <= 10'd0;
            vb_x_6  <= 10'd0; vb_y_6  <= 10'd0;
            vb_x_7  <= 10'd0; vb_y_7  <= 10'd0;
            vb_x_8  <= 10'd0; vb_y_8  <= 10'd0;
            vb_x_9  <= 10'd0; vb_y_9  <= 10'd0;
            vb_x_10 <= 10'd0; vb_y_10 <= 10'd0;
            vb_x_11 <= 10'd0; vb_y_11 <= 10'd0;
            // HUD / state
            lives          <= 2'd3;
            score          <= 14'd0;
            game_state     <= ST_PLAY;
            // RNG, cooldown
            lfsr           <= 16'hACE1;
            shoot_cnt      <= 7'd0;
        end else begin
            // Always advance the LFSR
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

            // Fire pulse can latch a new player bullet immediately, into the
            // lowest-indexed free slot. Up to 3 bullets can be on-screen.
            if (game_state == ST_PLAY && fire_pulse && player_alive) begin
                if (!pb_active[0]) begin
                    pb_active[0] <= 1'b1;
                    pb_x_0       <= player_x + (PLAYER_W >> 1) - (PB_W >> 1);
                    pb_y_0       <= PLAYER_Y - PB_H;
                end else if (!pb_active[1]) begin
                    pb_active[1] <= 1'b1;
                    pb_x_1       <= player_x + (PLAYER_W >> 1) - (PB_W >> 1);
                    pb_y_1       <= PLAYER_Y - PB_H;
                end else if (!pb_active[2]) begin
                    pb_active[2] <= 1'b1;
                    pb_x_2       <= player_x + (PLAYER_W >> 1) - (PB_W >> 1);
                    pb_y_2       <= PLAYER_Y - PB_H;
                end
            end

            // ============================================================
            // Game-tick-driven updates (only during PLAY)
            // ============================================================
            if (game_tick && game_state == ST_PLAY) begin

                // Player blink timer ticks at game-tick rate (~60Hz)
                if (blink_cnt > 7'd0) begin
                    blink_cnt    <= blink_cnt - 7'd1;
                    player_blink <= blink_cnt[2];   // toggle every 4 ticks (~67ms)
                end else begin
                    player_blink <= 1'b0;
                end

                //------------------------------------------------------
                // 1) Player movement
                //------------------------------------------------------
                if (btnL && !btnR) begin
                    if (player_x >= PLAYER_SPD) player_x <= player_x - PLAYER_SPD;
                    else                        player_x <= 10'd0;
                end else if (btnR && !btnL) begin
                    if (player_x + PLAYER_SPD <= PLAYER_MAX_X) player_x <= player_x + PLAYER_SPD;
                    else                                       player_x <= PLAYER_MAX_X;
                end

                //------------------------------------------------------
                // 2) Player bullet movement - 3 slots, each moves up
                //------------------------------------------------------
                if (pb_active[0]) begin
                    if (pb_y_0 < BULLET_SPD || any_wall_hit(pb_x_0, pb_y_0, PB_W, PB_H))
                        pb_active[0] <= 1'b0;
                    else
                        pb_y_0 <= pb_y_0 - BULLET_SPD;
                end
                if (pb_active[1]) begin
                    if (pb_y_1 < BULLET_SPD || any_wall_hit(pb_x_1, pb_y_1, PB_W, PB_H))
                        pb_active[1] <= 1'b0;
                    else
                        pb_y_1 <= pb_y_1 - BULLET_SPD;
                end
                if (pb_active[2]) begin
                    if (pb_y_2 < BULLET_SPD || any_wall_hit(pb_x_2, pb_y_2, PB_W, PB_H))
                        pb_active[2] <= 1'b0;
                    else
                        pb_y_2 <= pb_y_2 - BULLET_SPD;
                end

                //------------------------------------------------------
                // 3) Villain bullets (12 slots) move down; deactivate at
                //    the bottom of the screen
                //------------------------------------------------------
                // Villain bullets stop at walls but do not erode them (saves LUTs)
                if (vb_active[0])  begin if (vb_y_0  >= SCREEN_H-BULLET_SPD || any_wall_hit(vb_x_0,  vb_y_0,  VB_W,VB_H)) vb_active[0]  <= 1'b0; else vb_y_0  <= vb_y_0  + BULLET_SPD; end
                if (vb_active[1])  begin if (vb_y_1  >= SCREEN_H-BULLET_SPD || any_wall_hit(vb_x_1,  vb_y_1,  VB_W,VB_H)) vb_active[1]  <= 1'b0; else vb_y_1  <= vb_y_1  + BULLET_SPD; end
                if (vb_active[2])  begin if (vb_y_2  >= SCREEN_H-BULLET_SPD || any_wall_hit(vb_x_2,  vb_y_2,  VB_W,VB_H)) vb_active[2]  <= 1'b0; else vb_y_2  <= vb_y_2  + BULLET_SPD; end
                if (vb_active[3])  begin if (vb_y_3  >= SCREEN_H-BULLET_SPD || any_wall_hit(vb_x_3,  vb_y_3,  VB_W,VB_H)) vb_active[3]  <= 1'b0; else vb_y_3  <= vb_y_3  + BULLET_SPD; end
                if (vb_active[4])  begin if (vb_y_4  >= SCREEN_H-BULLET_SPD || any_wall_hit(vb_x_4,  vb_y_4,  VB_W,VB_H)) vb_active[4]  <= 1'b0; else vb_y_4  <= vb_y_4  + BULLET_SPD; end
                if (vb_active[5])  begin if (vb_y_5  >= SCREEN_H-BULLET_SPD || any_wall_hit(vb_x_5,  vb_y_5,  VB_W,VB_H)) vb_active[5]  <= 1'b0; else vb_y_5  <= vb_y_5  + BULLET_SPD; end
                if (vb_active[6])  begin if (vb_y_6  >= SCREEN_H-BULLET_SPD || any_wall_hit(vb_x_6,  vb_y_6,  VB_W,VB_H)) vb_active[6]  <= 1'b0; else vb_y_6  <= vb_y_6  + BULLET_SPD; end
                if (vb_active[7])  begin if (vb_y_7  >= SCREEN_H-BULLET_SPD || any_wall_hit(vb_x_7,  vb_y_7,  VB_W,VB_H)) vb_active[7]  <= 1'b0; else vb_y_7  <= vb_y_7  + BULLET_SPD; end
                if (vb_active[8])  begin if (vb_y_8  >= SCREEN_H-BULLET_SPD || any_wall_hit(vb_x_8,  vb_y_8,  VB_W,VB_H)) vb_active[8]  <= 1'b0; else vb_y_8  <= vb_y_8  + BULLET_SPD; end
                if (vb_active[9])  begin if (vb_y_9  >= SCREEN_H-BULLET_SPD || any_wall_hit(vb_x_9,  vb_y_9,  VB_W,VB_H)) vb_active[9]  <= 1'b0; else vb_y_9  <= vb_y_9  + BULLET_SPD; end
                if (vb_active[10]) begin if (vb_y_10 >= SCREEN_H-BULLET_SPD || any_wall_hit(vb_x_10, vb_y_10, VB_W,VB_H)) vb_active[10] <= 1'b0; else vb_y_10 <= vb_y_10 + BULLET_SPD; end
                if (vb_active[11]) begin if (vb_y_11 >= SCREEN_H-BULLET_SPD || any_wall_hit(vb_x_11, vb_y_11, VB_W,VB_H)) vb_active[11] <= 1'b0; else vb_y_11 <= vb_y_11 + BULLET_SPD; end

                //------------------------------------------------------
                // 4) Villain group movement FSM
                //------------------------------------------------------
                if (villain_dir == DIR_RIGHT) begin
                    if (villain_base_x + V_GRID_W + VILLAIN_SPD >= SCREEN_W)
                        villain_dir    <= DIR_LEFT;
                    else
                        villain_base_x <= villain_base_x + VILLAIN_SPD;
                end else begin // DIR_LEFT
                    if (villain_base_x < VILLAIN_SPD)
                        villain_dir    <= DIR_RIGHT;
                    else
                        villain_base_x <= villain_base_x - VILLAIN_SPD;
                end

                //------------------------------------------------------
                // 5) Player-bullet vs villain collision
                //    Each bullet independently. Up to 3 villains can die in
                //    one tick. Score = 10 * (number of bullets that hit).
                //    Note: if two bullets hit the same villain in the same
                //    tick, the dual <= 0 to villain_alive is idempotent;
                //    score still counts each bullet (minor gift to the player).
                //------------------------------------------------------
                if (pb_hit_0) begin
                    pb_active[0] <= 1'b0;
                    casez (pb_vill_hit_vec_0)
                        15'b???????????????1: villain_alive[0]  <= 1'b0;
                        15'b??????????????10: villain_alive[1]  <= 1'b0;
                        15'b?????????????100: villain_alive[2]  <= 1'b0;
                        15'b????????????1000: villain_alive[3]  <= 1'b0;
                        15'b???????????10000: villain_alive[4]  <= 1'b0;
                        15'b??????????100000: villain_alive[5]  <= 1'b0;
                        15'b?????????1000000: villain_alive[6]  <= 1'b0;
                        15'b????????10000000: villain_alive[7]  <= 1'b0;
                        15'b???????100000000: villain_alive[8]  <= 1'b0;
                        15'b??????1000000000: villain_alive[9]  <= 1'b0;
                        15'b?????10000000000: villain_alive[10] <= 1'b0;
                        15'b????100000000000: villain_alive[11] <= 1'b0;
                        15'b???1000000000000: villain_alive[12] <= 1'b0;
                        15'b??10000000000000: villain_alive[13] <= 1'b0;
                        15'b?100000000000000: villain_alive[14] <= 1'b0;
                        default: ;
                    endcase
                end
                if (pb_hit_1) begin
                    pb_active[1] <= 1'b0;
                    casez (pb_vill_hit_vec_1)
                        15'b???????????????1: villain_alive[0]  <= 1'b0;
                        15'b??????????????10: villain_alive[1]  <= 1'b0;
                        15'b?????????????100: villain_alive[2]  <= 1'b0;
                        15'b????????????1000: villain_alive[3]  <= 1'b0;
                        15'b???????????10000: villain_alive[4]  <= 1'b0;
                        15'b??????????100000: villain_alive[5]  <= 1'b0;
                        15'b?????????1000000: villain_alive[6]  <= 1'b0;
                        15'b????????10000000: villain_alive[7]  <= 1'b0;
                        15'b???????100000000: villain_alive[8]  <= 1'b0;
                        15'b??????1000000000: villain_alive[9]  <= 1'b0;
                        15'b?????10000000000: villain_alive[10] <= 1'b0;
                        15'b????100000000000: villain_alive[11] <= 1'b0;
                        15'b???1000000000000: villain_alive[12] <= 1'b0;
                        15'b??10000000000000: villain_alive[13] <= 1'b0;
                        15'b?100000000000000: villain_alive[14] <= 1'b0;
                        default: ;
                    endcase
                end
                if (pb_hit_2) begin
                    pb_active[2] <= 1'b0;
                    casez (pb_vill_hit_vec_2)
                        15'b???????????????1: villain_alive[0]  <= 1'b0;
                        15'b??????????????10: villain_alive[1]  <= 1'b0;
                        15'b?????????????100: villain_alive[2]  <= 1'b0;
                        15'b????????????1000: villain_alive[3]  <= 1'b0;
                        15'b???????????10000: villain_alive[4]  <= 1'b0;
                        15'b??????????100000: villain_alive[5]  <= 1'b0;
                        15'b?????????1000000: villain_alive[6]  <= 1'b0;
                        15'b????????10000000: villain_alive[7]  <= 1'b0;
                        15'b???????100000000: villain_alive[8]  <= 1'b0;
                        15'b??????1000000000: villain_alive[9]  <= 1'b0;
                        15'b?????10000000000: villain_alive[10] <= 1'b0;
                        15'b????100000000000: villain_alive[11] <= 1'b0;
                        15'b???1000000000000: villain_alive[12] <= 1'b0;
                        15'b??10000000000000: villain_alive[13] <= 1'b0;
                        15'b?100000000000000: villain_alive[14] <= 1'b0;
                        default: ;
                    endcase
                end
                // Aggregate score: +10 per bullet that hit something
                case ({pb_hit_2, pb_hit_1, pb_hit_0})
                    3'b001, 3'b010, 3'b100: score <= score + 14'd10;
                    3'b011, 3'b101, 3'b110: score <= score + 14'd20;
                    3'b111:                 score <= score + 14'd30;
                    default: ;
                endcase

                //------------------------------------------------------
                // 6) Villain-bullet vs player collision (priority encoder)
                //    Player must be alive and not currently flashing.
                //------------------------------------------------------
                if (vb_any_hit && player_alive && blink_cnt == 7'd0) begin
                    blink_cnt <= 7'd60;
                    if (lives > 2'd0) lives <= lives - 2'd1;
                    // Clear the bullet that hit (lowest index priority)
                    casez (vb_hit_vec)
                        12'b???????????1: vb_active[0]  <= 1'b0;
                        12'b??????????10: vb_active[1]  <= 1'b0;
                        12'b?????????100: vb_active[2]  <= 1'b0;
                        12'b????????1000: vb_active[3]  <= 1'b0;
                        12'b???????10000: vb_active[4]  <= 1'b0;
                        12'b??????100000: vb_active[5]  <= 1'b0;
                        12'b?????1000000: vb_active[6]  <= 1'b0;
                        12'b????10000000: vb_active[7]  <= 1'b0;
                        12'b???100000000: vb_active[8]  <= 1'b0;
                        12'b??1000000000: vb_active[9]  <= 1'b0;
                        12'b?10000000000: vb_active[10] <= 1'b0;
                        12'b100000000000: vb_active[11] <= 1'b0;
                        default: ;
                    endcase
                end

                //------------------------------------------------------
                // 7) Villain volley: every SHOOT_PERIOD ticks, spawn up
                //    to 3 villain bullets, each from a (pseudo-random
                //    living) villain into a free slot.
                //
                //    We use 3 dedicated slot ranges to avoid clobbering:
                //      bullet from shoot1 -> slots 0..3
                //      bullet from shoot2 -> slots 4..7
                //      bullet from shoot3 -> slots 8..11
                //------------------------------------------------------
                if (shoot_cnt >= SHOOT_PERIOD) begin
                    shoot_cnt <= 7'd0;

                    // Spawn for shoot1 in slots 0..3 (first free)
                    if (villain_alive[shoot1]) begin
                        if      (!vb_active[0]) begin vb_active[0] <= 1'b1; vb_x_0 <= vx[shoot1] + (V_W>>1) - (VB_W>>1); vb_y_0 <= vy[shoot1] + V_H; end
                        else if (!vb_active[1]) begin vb_active[1] <= 1'b1; vb_x_1 <= vx[shoot1] + (V_W>>1) - (VB_W>>1); vb_y_1 <= vy[shoot1] + V_H; end
                        else if (!vb_active[2]) begin vb_active[2] <= 1'b1; vb_x_2 <= vx[shoot1] + (V_W>>1) - (VB_W>>1); vb_y_2 <= vy[shoot1] + V_H; end
                        else if (!vb_active[3]) begin vb_active[3] <= 1'b1; vb_x_3 <= vx[shoot1] + (V_W>>1) - (VB_W>>1); vb_y_3 <= vy[shoot1] + V_H; end
                    end
                    // Spawn for shoot2 in slots 4..7
                    if (villain_alive[shoot2]) begin
                        if      (!vb_active[4]) begin vb_active[4] <= 1'b1; vb_x_4 <= vx[shoot2] + (V_W>>1) - (VB_W>>1); vb_y_4 <= vy[shoot2] + V_H; end
                        else if (!vb_active[5]) begin vb_active[5] <= 1'b1; vb_x_5 <= vx[shoot2] + (V_W>>1) - (VB_W>>1); vb_y_5 <= vy[shoot2] + V_H; end
                        else if (!vb_active[6]) begin vb_active[6] <= 1'b1; vb_x_6 <= vx[shoot2] + (V_W>>1) - (VB_W>>1); vb_y_6 <= vy[shoot2] + V_H; end
                        else if (!vb_active[7]) begin vb_active[7] <= 1'b1; vb_x_7 <= vx[shoot2] + (V_W>>1) - (VB_W>>1); vb_y_7 <= vy[shoot2] + V_H; end
                    end
                    // Spawn for shoot3 in slots 8..11
                    if (villain_alive[shoot3]) begin
                        if      (!vb_active[8])  begin vb_active[8]  <= 1'b1; vb_x_8  <= vx[shoot3] + (V_W>>1) - (VB_W>>1); vb_y_8  <= vy[shoot3] + V_H; end
                        else if (!vb_active[9])  begin vb_active[9]  <= 1'b1; vb_x_9  <= vx[shoot3] + (V_W>>1) - (VB_W>>1); vb_y_9  <= vy[shoot3] + V_H; end
                        else if (!vb_active[10]) begin vb_active[10] <= 1'b1; vb_x_10 <= vx[shoot3] + (V_W>>1) - (VB_W>>1); vb_y_10 <= vy[shoot3] + V_H; end
                        else if (!vb_active[11]) begin vb_active[11] <= 1'b1; vb_x_11 <= vx[shoot3] + (V_W>>1) - (VB_W>>1); vb_y_11 <= vy[shoot3] + V_H; end
                    end
                end else begin
                    shoot_cnt <= shoot_cnt + 7'd1;
                end

                //------------------------------------------------------
                // 8) State transitions
                //------------------------------------------------------
                if (lives == 2'd0) begin
                    game_state   <= ST_GAME_OVER;
                    player_alive <= 1'b0;
                end
                if (!any_villain_alive) begin
                    game_state <= ST_WIN;
                end
            end // game_tick && PLAY
        end
    end

endmodule