`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/23/2026 10:56:20 AM
// Design Name: 
// Module Name: FPCVT_tb_gk_dl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module FPCVT_tb_gk_dl;

// Inputs (to DUT)
reg [11:0] D;

// Outputs (from DUT)
wire S;
wire [2:0] E;
wire [3:0] F;

FPCVT uut (
    .D(D),
    .S(S),
    .E(E),
    .F(F)
);

initial begin

// 1. Zero
D = 12'b000000000000;   // 0  ? S=0 E=000 F=0000
#10;

// 2. Small positive
D = 12'b000000001011;   // 11 ? S=0 E=000 F=1011  (just take LSB 4 bits)
#10;

// 3. Example from lab (~422)
D = 12'b000110100110;   // 422 ? S=0 E=101 F=1101  (13 × 2^5 = 416)
#10;

// 4. Negative number
D = 12'b111001011010;   // -422 ? S=1 E=101 F=1101
#10;

// 5. Rounding down case
D = 12'b000000101100;   // ? S=0 E=010 F=1011  (round down)
#10;

// 6. Rounding up case
D = 12'b000000101110;   // ? S=0 E=010 F=1100  (round up)
#10;

// 7. Overflow rounding case
D = 12'b000001111101;   // 125 ? S=0 E=100 F=1000  (overflow ? shift + E++)
#10;

// 8. Max positive
D = 12'b011111111111;   // 2047 ? S=0 E=111 F=1111  (rounds to 1024 = 8×2^7)
#10;

// 9. Most negative
D = 12'b100000000000;   // -2048 ? S=1 E=111 F=1111  (largest magnitude case)
#10;

    // Finish simulation
    $finish;
end

endmodule