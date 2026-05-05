module seg7_controller(
    input clk,
    input scan_tick,
    input blink_state,
    input sel,
    input adj,

    input [3:0] min_tens,
    input [3:0] min_ones,
    input [3:0] sec_tens,
    input [3:0] sec_ones,

    output reg [6:0] seg,
    output reg [3:0] an
  );

  reg [1:0] digit_select;
  reg [3:0] current_digit;
  reg blink_blank;
  wire [6:0] decoded_seg;

  seg7_decoder decoder(
                 .digit(current_digit),
                 .seg(decoded_seg)
               );

  always @(posedge clk)
  begin
    if (scan_tick)
      digit_select <= digit_select + 1;
  end

  always @(*)
  begin
    case (digit_select)
      2'b00:
      begin
        an = 4'b1110;
        current_digit = sec_ones;
        blink_blank = adj && sel && blink_state;
      end

      2'b01:
      begin
        an = 4'b1101;
        current_digit = sec_tens;
        blink_blank = adj && sel && blink_state;
      end

      2'b10:
      begin
        an = 4'b1011;
        current_digit = min_ones;
        blink_blank = adj && !sel && blink_state;
      end

      2'b11:
      begin
        an = 4'b0111;
        current_digit = min_tens;
        blink_blank = adj && !sel && blink_state;
      end

      default:
      begin
        an = 4'b1111;
        current_digit = 4'd0;
        blink_blank = 1'b0;
      end
    endcase

    seg = blink_blank ? 7'b1111111 : decoded_seg;
  end

endmodule
