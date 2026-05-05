module debouncer(
    input clk,
    input btn_in,
    output reg btn_clean,
    output reg btn_pulse
);

    reg [19:0] count;
    reg btn_sync_0;
    reg btn_sync_1;
    reg btn_state;
    reg btn_state_prev;

    always @(posedge clk) begin
        btn_sync_0 <= btn_in;
        btn_sync_1 <= btn_sync_0;
    end

    always @(posedge clk) begin
        if (btn_sync_1 != btn_state) begin
            count <= count + 1;

            if (count == 20'd999_999) begin
                btn_state <= btn_sync_1;
                count <= 0;
            end
        end else begin
            count <= 0;
        end
    end

    always @(posedge clk) begin
        btn_clean <= btn_state;

        btn_state_prev <= btn_state;
        btn_pulse <= btn_state & ~btn_state_prev;
    end

endmodule