module clock_divider(
    input clk,
    input reset,
    output reg clk_1hz,
    output reg clk_2hz,
    output reg clk_500hz
);

    reg [26:0] count_1hz;
    reg [25:0] count_2hz;
    reg [16:0] count_500hz;

    always @(posedge clk) begin
        if (reset) begin
            count_1hz <= 0;
            count_2hz <= 0;
            count_500hz <= 0;
            clk_1hz <= 0;
            clk_2hz <= 0;
            clk_500hz <= 0;
        end else begin

            // 1 Hz clock from 100 MHz
            // Toggle every 50,000,000 cycles
            if (count_1hz == 49_999_999) begin
                count_1hz <= 0;
                clk_1hz <= ~clk_1hz;
            end else begin
                count_1hz <= count_1hz + 1;
            end

            // 2 Hz clock
            // Toggle every 25,000,000 cycles
            if (count_2hz == 24_999_999) begin
                count_2hz <= 0;
                clk_2hz <= ~clk_2hz;
            end else begin
                count_2hz <= count_2hz + 1;
            end

            // 500 Hz clock
            // Toggle every 100,000 cycles
            if (count_500hz == 99_999) begin
                count_500hz <= 0;
                clk_500hz <= ~clk_500hz;
            end else begin
                count_500hz <= count_500hz + 1;
            end

        end
    end

endmodule