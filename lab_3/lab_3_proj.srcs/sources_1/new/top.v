`timescale 1ns / 1ps

module top(
    input clk,              // 100 MHz clock
    input pause_btn,
    input reset_btn,
    input sel,
    input adj,
    output [6:0] seg,
    output [3:0] an,
    output dp
  );

  wire clk_1hz;
  wire clk_500hz;
  wire clk_2hz;

  wire pause_clean;
  wire reset_clean;
  wire sel_clean;
  wire adj_clean;

  wire pause_pulse;
  wire reset_pulse;

  wire [3:0] min_tens;
  wire [3:0] min_ones;
  wire [3:0] sec_tens;
  wire [3:0] sec_ones;

  assign dp = 1'b1; // decimal point off, active-low

  clock_divider clkdiv(
                  .clk(clk),
                  .reset(1'b0),
                  .clk_1hz(clk_1hz),
                  .clk_2hz(clk_2hz),
                  .clk_500hz(clk_500hz)
                );

  debouncer db_pause(
              .clk(clk),
              .btn_in(pause_btn),
              .btn_clean(pause_clean),
              .btn_pulse(pause_pulse)
            );

  debouncer db_reset(
              .clk(clk),
              .btn_in(reset_btn),
              .btn_clean(reset_clean),
              .btn_pulse(reset_pulse)
            );

  debouncer db_sel(
              .clk(clk),
              .btn_in(sel),
              .btn_clean(sel_clean),
              .btn_pulse()
            );

  debouncer db_adj(
              .clk(clk),
              .btn_in(adj),
              .btn_clean(adj_clean),
              .btn_pulse()
            );

  stopwatch_counter counter(
                      .clk(clk),
                      .tick_1hz(clk_1hz),
                      .tick_2hz(clk_2hz),
                      .pause(pause_pulse),
                      .reset(reset_pulse),
                      .sel(sel_clean),
                      .adj(adj_clean),
                      .min_tens(min_tens),
                      .min_ones(min_ones),
                      .sec_tens(sec_tens),
                      .sec_ones(sec_ones)
                    );

  seg7_controller display(
                    .clk_500hz(clk_500hz),
                    .blink_clk(clk_2hz),
                    .sel(sel_clean),
                    .adj(adj_clean),
                    .min_tens(min_tens),
                    .min_ones(min_ones),
                    .sec_tens(sec_tens),
                    .sec_ones(sec_ones),
                    .seg(seg),
                    .an(an)
                  );

endmodule
