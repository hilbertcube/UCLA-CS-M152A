`timescale 1ns / 1ps
module villain_rom(
    input  wire [1:0] alien_type, // 0=squid  1=crab  2=octopus
    input  wire [3:0] col,        // 0..11, col 0 = leftmost
    input  wire [2:0] row,        // 0..7,  row 0 = top
    output wire       pix
);

    // ---- Type 0 : Squid (top row) ----
    //  . . . . # # # # . . . .
    //  . . # # # # # # # # . .
    //  . # # . # # # # . # # .   eyes
    //  . # # # # # # # # # # .
    //  . . # # . # # . # # . .
    //  . . # . . . . . . # . .   legs
    //  . # . . . . . . . . # .
    //  . . . . . . . . . . . .
    reg [11:0] squid [0:7];
    initial begin
        squid[0] = 12'h0F0;
        squid[1] = 12'h3FC;
        squid[2] = 12'h6F6;
        squid[3] = 12'h7FE;
        squid[4] = 12'h36C;
        squid[5] = 12'h204;
        squid[6] = 12'h402;
        squid[7] = 12'h000;
    end

    // ---- Type 1 : Crab (middle row) ----
    //  . . . # . . . . # . . .   antennae
    //  . . . . # # # # . . . .
    //  . . # # # # # # # # . .
    //  . # # . # # # # . # # .   eyes
    //  # # # # # # # # # # # #   full body
    //  # . # . # # # # . # . #   legs
    //  . . # . . . . . . # . .   feet
    //  . . . . . . . . . . . .
    reg [11:0] crab [0:7];
    initial begin
        crab[0] = 12'h108;
        crab[1] = 12'h0F0;
        crab[2] = 12'h3FC;
        crab[3] = 12'h6F6;
        crab[4] = 12'hFFF;
        crab[5] = 12'hAF5;
        crab[6] = 12'h204;
        crab[7] = 12'h000;
    end

    // ---- Type 2 : Octopus (bottom row) ----
    //  . . # # # # # # # # . .   big round body
    //  . # # # # # # # # # # .
    //  # # . . # # # # . . # #   wide eyes
    //  # # # # # # # # # # # #   full body
    //  # . # . # # # # . # . #   alternating legs
    //  # . . # . # # . # . . #   tentacles
    //  . . # . . . . . . # . .
    //  . . . . . . . . . . . .
    reg [11:0] octopus [0:7];
    initial begin
        octopus[0] = 12'h3FC;
        octopus[1] = 12'h7FE;
        octopus[2] = 12'hCF3;
        octopus[3] = 12'hFFF;
        octopus[4] = 12'hAF5;
        octopus[5] = 12'h969;
        octopus[6] = 12'h204;
        octopus[7] = 12'h000;
    end

    wire [11:0] row_bits = (alien_type == 2'd0) ? squid[row] :
                           (alien_type == 2'd1) ? crab[row]  : octopus[row];
    assign pix = row_bits[4'd11 - col];

endmodule
