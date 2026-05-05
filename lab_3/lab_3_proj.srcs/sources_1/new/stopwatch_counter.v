module stopwatch_counter(
    input clk,
    input tick_1hz,
    input tick_2hz,
    input pause,
    input reset,
    input sel,
    input adj,

    output reg [3:0] min_tens,
    output reg [3:0] min_ones,
    output reg [3:0] sec_tens,
    output reg [3:0] sec_ones
  );

  reg tick_1hz_prev;
  reg tick_2hz_prev;
  wire tick_1hz_pulse;
  wire tick_2hz_pulse;

  reg running = 1'b1;

  assign tick_1hz_pulse = tick_1hz & ~tick_1hz_prev;
  assign tick_2hz_pulse = tick_2hz & ~tick_2hz_prev;

  always @(posedge clk)
  begin
    tick_1hz_prev <= tick_1hz;
    tick_2hz_prev <= tick_2hz;
  end

  always @(posedge clk)
  begin
    if (reset)
    begin
      min_tens <= 0;
      min_ones <= 0;
      sec_tens <= 0;
      sec_ones <= 0;
      running <= 1'b1;
    end
    else
    begin

      if (pause)
      begin
        running <= ~running;
      end

      if (adj && tick_2hz_pulse)
      begin
        if (!sel)
        begin
          if (min_ones == 9)
          begin
            min_ones <= 0;

            if (min_tens == 5)
              min_tens <= 0;
            else
              min_tens <= min_tens + 1;
          end
          else
          begin
            min_ones <= min_ones + 1;
          end
        end
        else
        begin
          if (sec_ones == 9)
          begin
            sec_ones <= 0;

            if (sec_tens == 5)
              sec_tens <= 0;
            else
              sec_tens <= sec_tens + 1;
          end
          else
          begin
            sec_ones <= sec_ones + 1;
          end
        end
      end
      else if (running && !adj && tick_1hz_pulse)
      begin
        if (sec_ones == 9)
        begin
          sec_ones <= 0;

          if (sec_tens == 5)
          begin
            sec_tens <= 0;

            if (min_ones == 9)
            begin
              min_ones <= 0;

              if (min_tens == 5)
                min_tens <= 0;
              else
                min_tens <= min_tens + 1;
            end
            else
            begin
              min_ones <= min_ones + 1;
            end

          end
          else
          begin
            sec_tens <= sec_tens + 1;
          end

        end
        else
        begin
          sec_ones <= sec_ones + 1;
        end
      end
    end
  end

endmodule
