module clock_divider(
    input clk,
    input reset,
    output reg tick_1hz,
    output reg tick_2hz,
    output reg tick_500hz,
    output reg blink_state
  );

  reg [26:0] count_1hz;
  reg [25:0] count_2hz;
  reg [16:0] count_500hz;

  always @(posedge clk)
  begin
    if (reset)
    begin
      count_1hz <= 0;
      count_2hz <= 0;
      count_500hz <= 0;
      tick_1hz <= 0;
      tick_2hz <= 0;
      tick_500hz <= 0;
      blink_state <= 0;
    end
    else
    begin
      tick_1hz <= 0;
      tick_2hz <= 0;
      tick_500hz <= 0;

      // 1 Hz enable pulse from 100 MHz.
      if (count_1hz == 99_999_999)
      begin
        count_1hz <= 0;
        tick_1hz <= 1'b1;
      end
      else
      begin
        count_1hz <= count_1hz + 1;
      end

      // 2 Hz enable pulse and matching blink state.
      // Toggle the blink state every 25,000,000 cycles and emit a pulse.
      if (count_2hz == 24_999_999)
      begin
        count_2hz <= 0;
        tick_2hz <= 1'b1;
        blink_state <= ~blink_state;
      end
      else
      begin
        count_2hz <= count_2hz + 1;
      end

      // 500 Hz display scan enable pulse.
      if (count_500hz == 199_999)
      begin
        count_500hz <= 0;
        tick_500hz <= 1'b1;
      end
      else
      begin
        count_500hz <= count_500hz + 1;
      end

    end
  end

endmodule
