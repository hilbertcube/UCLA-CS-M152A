`timescale 1ns / 1ps
//=============================================================================
// vga_sync.v
//
// 640x480 @ 60 Hz VGA timing generator. Pixel clock = 25.175 MHz nominal
// (we use 25 MHz - close enough for most monitors).
//
// Horizontal:    640 visible + 16 FP + 96 sync + 48 BP = 800 total
// Vertical:      480 visible + 10 FP +  2 sync + 33 BP = 525 total
// Sync polarity: negative for both H and V
//=============================================================================
module vga_sync(
    input  wire        pix_clk,
    input  wire        rst,
    output reg         hsync,
    output reg         vsync,
    output wire        video_on,
    output wire [9:0]  pix_x,
    output wire [9:0]  pix_y
);

    // Horizontal timing
    localparam H_DISPLAY    = 640;
    localparam H_FRONT      = 16;
    localparam H_SYNC       = 96;
    localparam H_BACK       = 48;
    localparam H_TOTAL      = 800;

    // Vertical timing
    localparam V_DISPLAY    = 480;
    localparam V_FRONT      = 10;
    localparam V_SYNC       = 2;
    localparam V_BACK       = 33;
    localparam V_TOTAL      = 525;

    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    always @(posedge pix_clk) begin
        if (rst) begin
            h_cnt <= 10'd0;
            v_cnt <= 10'd0;
        end else begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= 10'd0;
                if (v_cnt == V_TOTAL - 1)
                    v_cnt <= 10'd0;
                else
                    v_cnt <= v_cnt + 10'd1;
            end else begin
                h_cnt <= h_cnt + 10'd1;
            end
        end
    end

    // Sync signals - active low for 640x480@60
    always @(posedge pix_clk) begin
        if (rst) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
        end else begin
            hsync <= ~((h_cnt >= H_DISPLAY + H_FRONT) &&
                      (h_cnt <  H_DISPLAY + H_FRONT + H_SYNC));
            vsync <= ~((v_cnt >= V_DISPLAY + V_FRONT) &&
                      (v_cnt <  V_DISPLAY + V_FRONT + V_SYNC));
        end
    end

    assign video_on = (h_cnt < H_DISPLAY) && (v_cnt < V_DISPLAY);
    assign pix_x    = h_cnt;
    assign pix_y    = v_cnt;

endmodule