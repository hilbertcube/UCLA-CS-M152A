`timescale 1ns / 1ps
module villain_rom(
    input  wire [3:0] col,   // 0..11, col 0 = leftmost
    input  wire [2:0] row,   // 0..7,  row 0 = top
    output wire       pix
);
    // 12x8 alien sprite (MSB = col 0, LSB = col 11)
    //
    //  . . . # . . . . # . . .   row 0  antennae
    //  . . . . # # # # . . . .   row 1
    //  . . # # # # # # # # . .   row 2  body top
    //  . # # . # # # # . # # .   row 3  eyes
    //  # # # # # # # # # # # #   row 4  full body
    //  # . # . # # # # . # . #   row 5  legs
    //  . . # . . . . . . # . .   row 6  feet
    //  . . . . . . . . . . . .   row 7
    reg [11:0] rows [0:7];
    initial begin
        rows[0] = 12'h108;
        rows[1] = 12'h0F0;
        rows[2] = 12'h3FC;
        rows[3] = 12'h6F6;
        rows[4] = 12'hFFF;
        rows[5] = 12'hAF5;
        rows[6] = 12'h204;
        rows[7] = 12'h000;
    end

    assign pix = rows[row][4'd11 - col];

endmodule
