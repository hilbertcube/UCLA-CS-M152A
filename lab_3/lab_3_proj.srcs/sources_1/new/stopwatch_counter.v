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

  reg running = 1'b1;

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

      if (adj && tick_2hz)
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
      else if (running && !adj && tick_1hz)
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
