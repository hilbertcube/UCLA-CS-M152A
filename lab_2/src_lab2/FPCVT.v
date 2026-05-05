`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCLA
// Engineer: Gaurav Kumar and Don Le
// 
// Create Date: 04/21/2026 10:58:07 AM
// Design Name: FPCVT
// Module Name: FPCVT
// Project Name: Lab 2
// Target Devices: NA
// Tool Versions: 
// Description: Convert a 12 bit signed integer to a rounded 8 bit integer
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module FPCVT (
    input  [11:0] D,   // 12-bit input
    output        S,   // sign
    output reg [2:0]  E,   // exponent
    output reg [3:0]  F    // significand
);


// Part 1: Get sign and mag
assign S = D[11];
reg [11:0] mag;

// Perform 2's complement if we have a negative number
always @(*) begin
    if (D == 12'b100000000000) begin
        // special case: -2048
        mag = 12'b011111111111;
    end
    else if (D[11] == 1'b1) begin
        // take 2's complement
        mag = ~D + 12'd1;
    end
    else begin
        // unchanged
        mag = D;
    end
end


// Part 2: count leading 0s
integer i;
reg found;
reg [3:0] zeros;

always @(*) begin
    zeros = 0;
    found = 0;

    for (i = 11; i >= 0; i = i - 1) begin
        if (mag[i] == 1'b1 && found == 0) begin
            zeros = 11 - i;
            found = 1;
        end
    end
end

// Part 3: Exponent + Shift
reg [11:0] norm;
reg [4:0] frac_ext; // 4 bits and rounding bit
reg [4:0] rounded;  // rounded value


always @(*) begin
    // Default values
    E = 3'd0;
    F = 4'd0;

    if (mag != 0) begin
        // Exponent mapping
        if (zeros >= 8)
            E = 3'd0;
        else if (zeros == 0)
            E = 3'd7;
        else
            E = 3'd8 - zeros;
                 
        // shift left so first 1 is at MSB
        norm = mag << zeros;

        // Take 4 bits + rounding bit
        frac_ext = norm[11:7];
        rounded = frac_ext[4:1] + frac_ext[0];
        
        // rounding
        if (frac_ext[0] == 1'b1) begin
            // Handle overflow
            if (rounded == 5'b10000) begin
                F = 4'b1000;
                if (E < 7)
                    E = E + 1;
                else
                    F = 4'b1111;
            end
            else
                F = rounded[3:0];
        end
        else
            // no rounding
            F = frac_ext[4:1];
    end
end

endmodule
