`timescale 1ns / 1ps
//=============================================================================
// clk_div.v
//
// Generates:
//   pix_clk   - 25 MHz pixel clock for VGA (from 100 MHz input)
//   game_tick - single-cycle pulse at ~60 Hz, in pix_clk domain.
//
// 25 MHz / 416,666 ~= 60 Hz. We use 416,666 for the game-tick interval.
//=============================================================================
module clk_div(
    input  wire clk_in,     // 100 MHz
    output reg  pix_clk,    // 25 MHz
    output reg  game_tick   // 1 pulse @ ~60 Hz, in pix_clk domain
);

    // -------- 25 MHz generation: divide 100 MHz by 4 ---------------
    reg [1:0] div_cnt;
    initial begin
        div_cnt = 2'd0;
        pix_clk = 1'b0;
    end

    always @(posedge clk_in) begin
        div_cnt <= div_cnt + 2'd1;
        if (div_cnt[0])          // toggle at count 1 and 3 ? every 2 cycles ? 25 MHz
            pix_clk <= ~pix_clk;
    end

    // -------- Game tick: ~60 Hz in pix_clk domain ------------------
    // 25_000_000 / 60 ~= 416,666. Need 19-bit counter.
    reg [18:0] tick_cnt;
    initial begin
        tick_cnt = 19'd0;
        game_tick = 1'b0;
    end

    always @(posedge pix_clk) begin
        if (tick_cnt >= 19'd416_666) begin
            tick_cnt  <= 19'd0;
            game_tick <= 1'b1;
        end else begin
            tick_cnt  <= tick_cnt + 19'd1;
            game_tick <= 1'b0;
        end
    end

endmodule