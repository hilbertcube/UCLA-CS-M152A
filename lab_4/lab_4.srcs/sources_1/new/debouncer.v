`timescale 1ns / 1ps
//=============================================================================
// debouncer.v
//
// Standard button debouncer with single-cycle pulse output on press edge.
//
//   btn_in    - raw async button input
//   btn_out   - debounced, level (high while pressed)
//   btn_pulse - one-cycle pulse on rising edge of btn_out
//
// CNT_WIDTH = 16 with 25 MHz clk -> ~2.6 ms debounce window
//=============================================================================
module debouncer #(
    parameter CNT_WIDTH = 16
)(
    input  wire clk,
    input  wire rst,
    input  wire btn_in,
    output reg  btn_out,
    output reg  btn_pulse
);

    // -- Synchronize async input to clk domain --
    reg [1:0] sync;
    always @(posedge clk) begin
        if (rst) sync <= 2'b00;
        else     sync <= {sync[0], btn_in};
    end
    wire btn_sync = sync[1];

    // -- Debounce counter --
    reg [CNT_WIDTH-1:0] cnt;
    reg btn_prev;

    always @(posedge clk) begin
        if (rst) begin
            cnt      <= {CNT_WIDTH{1'b0}};
            btn_out  <= 1'b0;
            btn_prev <= 1'b0;
            btn_pulse<= 1'b0;
        end else begin
            // If input changed from latched value, count up; else hold
            if (btn_sync != btn_out) begin
                cnt <= cnt + 1'b1;
                if (&cnt) begin
                    // counter saturated -> accept new value
                    btn_out <= btn_sync;
                end
            end else begin
                cnt <= {CNT_WIDTH{1'b0}};
            end

            // Pulse generation: 1 cycle on rising edge of btn_out
            btn_prev  <= btn_out;
            btn_pulse <= btn_out & ~btn_prev;
        end
    end

endmodule