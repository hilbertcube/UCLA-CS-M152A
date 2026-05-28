`timescale 1ns / 1ps
//=============================================================================
// seg7_display.v
//
// 4-digit multiplexed 7-segment display driver.
//
//   - Takes a 14-bit binary score (0..9999, but we cap at 9999)
//   - Splits into 4 BCD digits using a small division chain
//   - Time-multiplexes the digits on Basys3's 7-segment display
//
// On Basys3:
//   - seg[6:0] are active-LOW (0 lights a segment)
//   - an[3:0]  are active-LOW (0 enables the digit)
//   - dp is active-LOW (1 turns dp off)
//
// Segments are encoded as: {g,f,e,d,c,b,a}
//=============================================================================
module seg7_display(
    input  wire        clk,         // 25 MHz pix_clk
    input  wire        rst,
    input  wire [13:0] score,       // 0..16383, displayed mod 10000
    output reg  [6:0]  seg,
    output wire        dp,
    output reg  [3:0]  an
);

    assign dp = 1'b1;   // decimal point always off

    //--------------------------------------------------------------------------
    // BCD conversion: derive d3 d2 d1 d0 from score using divisions
    // To keep this fully synthesizable and avoid a long divider, we use a
    // sequential approach: split using mod-10 and div-10 with synthesized
    // dividers (small constants, fits in LUTs).
    //--------------------------------------------------------------------------
    // Truncate score to display range 0..9999
    wire [13:0] sc_clamped = (score > 14'd9999) ? 14'd9999 : score;

    wire [3:0] d0 =  sc_clamped        % 14'd10;
    wire [3:0] d1 = (sc_clamped / 14'd10)   % 14'd10;
    wire [3:0] d2 = (sc_clamped / 14'd100)  % 14'd10;
    wire [3:0] d3 = (sc_clamped / 14'd1000) % 14'd10;

    //--------------------------------------------------------------------------
    // Digit multiplexer: ~5 kHz refresh on each digit
    // At 25 MHz, 18-bit counter top bits give ~95 Hz per digit cycle - fine.
    //--------------------------------------------------------------------------
    reg [17:0] mux_cnt;
    always @(posedge clk) begin
        if (rst) mux_cnt <= 18'd0;
        else     mux_cnt <= mux_cnt + 18'd1;
    end

    wire [1:0] digit_sel = mux_cnt[17:16];
    reg [3:0]  cur_digit;

    always @* begin
        case (digit_sel)
            2'd0: begin an = 4'b1110; cur_digit = d0; end
            2'd1: begin an = 4'b1101; cur_digit = d1; end
            2'd2: begin an = 4'b1011; cur_digit = d2; end
            2'd3: begin an = 4'b0111; cur_digit = d3; end
        endcase
    end

    //--------------------------------------------------------------------------
    // BCD -> 7-segment (active-low, {g,f,e,d,c,b,a})
    //--------------------------------------------------------------------------
    always @* begin
        case (cur_digit)
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            default: seg = 7'b1111111;   // blank
        endcase
    end

endmodule