`timescale 1ns / 1ps
//=============================================================================
// top.v
//
// Top-level module for Space Invaders on Basys3 FPGA.
//
// Inputs:
//   clk        - 100 MHz board clock
//   btnL,btnR  - move player left / right
//   btnU       - fire player bullet
//   btnD       - hold 3 sec to reset game
//   reset_btn  - hard reset (center button)
//
// Outputs:
//   Hsync,Vsync       - VGA sync signals
//   vgaRed,vgaGreen,vgaBlue - 4-bit color channels
//   seg, dp, an       - 7-segment display (score)
//=============================================================================
module top(
    input  wire        clk,        // 100 MHz
    // Buttons
    input  wire        btnL,       // move left
    input  wire        btnR,       // move right
    input  wire        btnU,       // fire
    input  wire        btnD,       // reset (hold 3 sec)
    input  wire        reset_btn,  // hard reset (center)
    // VGA
    output wire        Hsync,
    output wire        Vsync,
    output wire [3:0]  vgaRed,
    output wire [3:0]  vgaGreen,
    output wire [3:0]  vgaBlue,
    // 7-segment display
    output wire [6:0]  seg,
    output wire        dp,
    output wire [3:0]  an
);

    //--------------------------------------------------------------------------
    // Clock generation: 25 MHz pixel clock and game tick (~60 Hz)
    //--------------------------------------------------------------------------
    wire pix_clk;       // 25 MHz for VGA
    wire game_tick;     // single-cycle pulse at ~60 Hz (in pix_clk domain)

    clk_div u_clk_div (
        .clk_in   (clk),
        .pix_clk  (pix_clk),
        .game_tick(game_tick)
    );

    //--------------------------------------------------------------------------
    // Reset: synchronize hard reset to pix_clk domain
    //--------------------------------------------------------------------------
    reg [1:0] rst_sync;
    always @(posedge pix_clk) rst_sync <= {rst_sync[0], reset_btn};
    wire rst = rst_sync[1];

    //--------------------------------------------------------------------------
    // Button debouncers (all in pix_clk domain)
    //--------------------------------------------------------------------------
    wire btnL_db, btnR_db, btnU_db, btnD_db;
    wire btnU_pulse;    // single-cycle pulse on fire press

    debouncer #(.CNT_WIDTH(16)) u_db_L (.clk(pix_clk), .rst(rst), .btn_in(btnL), .btn_out(btnL_db), .btn_pulse());
    debouncer #(.CNT_WIDTH(16)) u_db_R (.clk(pix_clk), .rst(rst), .btn_in(btnR), .btn_out(btnR_db), .btn_pulse());
    debouncer #(.CNT_WIDTH(16)) u_db_U (.clk(pix_clk), .rst(rst), .btn_in(btnU), .btn_out(btnU_db), .btn_pulse(btnU_pulse));
    debouncer #(.CNT_WIDTH(16)) u_db_D (.clk(pix_clk), .rst(rst), .btn_in(btnD), .btn_out(btnD_db), .btn_pulse());

    //--------------------------------------------------------------------------
    // Hold-to-reset: BTNB held for ~3 seconds => soft reset
    // At 25 MHz, 3 sec = 75,000,000 cycles -> need 27-bit counter
    //--------------------------------------------------------------------------
    reg [26:0] hold_cnt;
    reg        soft_rst;
    always @(posedge pix_clk) begin
        if (rst) begin
            hold_cnt <= 27'd0;
            soft_rst <= 1'b0;
        end else if (btnD_db) begin
            if (hold_cnt >= 27'd75_000_000) begin
                soft_rst <= 1'b1;
                hold_cnt <= hold_cnt;   // saturate
            end else begin
                hold_cnt <= hold_cnt + 27'd1;
                soft_rst <= 1'b0;
            end
        end else begin
            hold_cnt <= 27'd0;
            soft_rst <= 1'b0;
        end
    end

    wire game_rst = rst | soft_rst;

    //--------------------------------------------------------------------------
    // VGA sync generator
    //--------------------------------------------------------------------------
    wire        video_on;
    wire [9:0]  pix_x;
    wire [9:0]  pix_y;

    vga_sync u_vga (
        .pix_clk (pix_clk),
        .rst     (rst),
        .hsync   (Hsync),
        .vsync   (Vsync),
        .video_on(video_on),
        .pix_x   (pix_x),
        .pix_y   (pix_y)
    );

    //--------------------------------------------------------------------------
    // Game logic - tracks all state, advances on game_tick
    //--------------------------------------------------------------------------
    wire [9:0]   player_x;
    wire         player_alive;
    wire         player_blink;        // high during damage flash
    wire [14:0]  villain_alive;       // bit i = villain i is alive
    wire [9:0]   villain_base_x;
    wire [9:0]   villain_base_y;
    wire [2:0]   pb_active;
    wire [9:0]   pb_x_0, pb_x_1, pb_x_2;
    wire [9:0]   pb_y_0, pb_y_1, pb_y_2;
    wire [11:0]  vb_active;           // up to 12 villain bullets
    wire [9:0]   vb_x_0, vb_x_1, vb_x_2,  vb_x_3,  vb_x_4,  vb_x_5;
    wire [9:0]   vb_x_6, vb_x_7, vb_x_8,  vb_x_9,  vb_x_10, vb_x_11;
    wire [9:0]   vb_y_0, vb_y_1, vb_y_2,  vb_y_3,  vb_y_4,  vb_y_5;
    wire [9:0]   vb_y_6, vb_y_7, vb_y_8,  vb_y_9,  vb_y_10, vb_y_11;
    wire [1:0]   lives;
    wire [13:0]  score;
    wire [1:0]   game_state;          // 00=PLAY 01=GAME_OVER 10=WIN

    game_logic u_game (
        .clk          (pix_clk),
        .rst          (game_rst),
        .game_tick    (game_tick),
        .btnL         (btnL_db),
        .btnR         (btnR_db),
        .fire_pulse   (btnU_pulse),
        .player_x     (player_x),
        .player_alive (player_alive),
        .player_blink (player_blink),
        .villain_alive(villain_alive),
        .villain_base_x(villain_base_x),
        .villain_base_y(villain_base_y),
        .pb_active    (pb_active),
        .pb_x_0(pb_x_0), .pb_y_0(pb_y_0),
        .pb_x_1(pb_x_1), .pb_y_1(pb_y_1),
        .pb_x_2(pb_x_2), .pb_y_2(pb_y_2),
        .vb_active    (vb_active),
        .vb_x_0(vb_x_0), .vb_y_0(vb_y_0),
        .vb_x_1(vb_x_1), .vb_y_1(vb_y_1),
        .vb_x_2(vb_x_2), .vb_y_2(vb_y_2),
        .vb_x_3(vb_x_3), .vb_y_3(vb_y_3),
        .vb_x_4(vb_x_4), .vb_y_4(vb_y_4),
        .vb_x_5(vb_x_5), .vb_y_5(vb_y_5),
        .vb_x_6(vb_x_6), .vb_y_6(vb_y_6),
        .vb_x_7(vb_x_7), .vb_y_7(vb_y_7),
        .vb_x_8(vb_x_8), .vb_y_8(vb_y_8),
        .vb_x_9(vb_x_9), .vb_y_9(vb_y_9),
        .vb_x_10(vb_x_10), .vb_y_10(vb_y_10),
        .vb_x_11(vb_x_11), .vb_y_11(vb_y_11),
        .lives        (lives),
        .score        (score),
        .game_state   (game_state)
    );

    //--------------------------------------------------------------------------
    // Renderer - combinational pixel-color generator
    //--------------------------------------------------------------------------
    renderer u_render (
        .pix_x        (pix_x),
        .pix_y        (pix_y),
        .video_on     (video_on),
        .player_x     (player_x),
        .player_alive (player_alive),
        .player_blink (player_blink),
        .villain_alive(villain_alive),
        .villain_base_x(villain_base_x),
        .villain_base_y(villain_base_y),
        .pb_active    (pb_active),
        .pb_x_0(pb_x_0), .pb_y_0(pb_y_0),
        .pb_x_1(pb_x_1), .pb_y_1(pb_y_1),
        .pb_x_2(pb_x_2), .pb_y_2(pb_y_2),
        .vb_active    (vb_active),
        .vb_x_0(vb_x_0), .vb_y_0(vb_y_0),
        .vb_x_1(vb_x_1), .vb_y_1(vb_y_1),
        .vb_x_2(vb_x_2), .vb_y_2(vb_y_2),
        .vb_x_3(vb_x_3), .vb_y_3(vb_y_3),
        .vb_x_4(vb_x_4), .vb_y_4(vb_y_4),
        .vb_x_5(vb_x_5), .vb_y_5(vb_y_5),
        .vb_x_6(vb_x_6), .vb_y_6(vb_y_6),
        .vb_x_7(vb_x_7), .vb_y_7(vb_y_7),
        .vb_x_8(vb_x_8), .vb_y_8(vb_y_8),
        .vb_x_9(vb_x_9), .vb_y_9(vb_y_9),
        .vb_x_10(vb_x_10), .vb_y_10(vb_y_10),
        .vb_x_11(vb_x_11), .vb_y_11(vb_y_11),
        .lives        (lives),
        .game_state   (game_state),
        .vgaRed       (vgaRed),
        .vgaGreen     (vgaGreen),
        .vgaBlue      (vgaBlue)
    );

    //--------------------------------------------------------------------------
    // 7-segment display - shows score in decimal
    //--------------------------------------------------------------------------
    seg7_display u_seg7 (
        .clk  (pix_clk),
        .rst  (rst),
        .score(score),
        .seg  (seg),
        .dp   (dp),
        .an   (an)
    );

endmodule