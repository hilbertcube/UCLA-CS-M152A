`timescale 1ns / 1ps
module player_rom(
    input  wire [3:0] col,   // 0..15, col 0 = leftmost
    input  wire [2:0] row,   // 0..7,  row 0 = top (cannon tip)
    output wire       pix
);
    // Displayed at 2x scale (32x16 on screen). Each ROM pixel = 2x2 block.
    //
    // Screen view (32 wide, # = lit pixel):
    //  r0-1  ..............####..............  cannon tip
    //  r2-3  ............########............  cannon
    //  r4-5  ..........############..........  nose
    //  r6-7  ......####################......  upper body
    //  r8-9  ######....############....######  wings + cockpit notch
    // r10-11 ################################  full body
    // r12-13 ####....################....####  engine bays
    // r14-15 ##........####....####........##  exhaust clusters
    reg [15:0] rows [0:7];
    initial begin
        rows[0] = 16'h0180;   // cannon tip     (2 px wide)
        rows[1] = 16'h03C0;   // cannon         (4 px)
        rows[2] = 16'h07E0;   // nose           (6 px)
        rows[3] = 16'h1FF8;   // upper body     (10 px)
        rows[4] = 16'hE7E7;   // wings (###..######..###)
        rows[5] = 16'hFFFF;   // full body
        rows[6] = 16'hCFF3;   // engine bays (##..########..##)
        rows[7] = 16'h8661;   // exhaust clusters (#....##..##....#)
    end

    assign pix = rows[row][4'd15 - col];

endmodule
