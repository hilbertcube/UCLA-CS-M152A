`timescale 1ns / 1ps
//=============================================================================
// text_rom.v
//
// Tiny 8x8 bitmap font that supplies the glyphs needed for "GAME OVER"
// and "YOU WIN". Returns a single bit indicating whether the given
// (col,row) within the glyph cell is foreground.
//
// Inputs:
//   ch  - 4-bit character index (see below)
//   col - 0..7 inside the glyph (left-to-right)
//   row - 0..7 inside the glyph (top-to-bottom)
// Output:
//   pix - 1 = foreground pixel, 0 = background
//
// Character indices:
//   0=' '  1='G'  2='A'  3='M'  4='E'
//   5='O'  6='V'  7='R'  8='Y'  9='U'
//  10='W' 11='I' 12='N'
//=============================================================================
module text_rom(
    input  wire [3:0] ch,
    input  wire [2:0] col,
    input  wire [2:0] row,
    output wire       pix
);

    // Row data for each character (8 rows, MSB = left column)
    reg [7:0] glyph_rows [0:12][0:7];

    initial begin
        // ' ' - all blank
        glyph_rows[0][0] = 8'b00000000;
        glyph_rows[0][1] = 8'b00000000;
        glyph_rows[0][2] = 8'b00000000;
        glyph_rows[0][3] = 8'b00000000;
        glyph_rows[0][4] = 8'b00000000;
        glyph_rows[0][5] = 8'b00000000;
        glyph_rows[0][6] = 8'b00000000;
        glyph_rows[0][7] = 8'b00000000;

        // 'G'
        glyph_rows[1][0] = 8'b01111110;
        glyph_rows[1][1] = 8'b11000000;
        glyph_rows[1][2] = 8'b11000000;
        glyph_rows[1][3] = 8'b11001110;
        glyph_rows[1][4] = 8'b11000110;
        glyph_rows[1][5] = 8'b11000110;
        glyph_rows[1][6] = 8'b01111110;
        glyph_rows[1][7] = 8'b00000000;

        // 'A'
        glyph_rows[2][0] = 8'b00111100;
        glyph_rows[2][1] = 8'b01100110;
        glyph_rows[2][2] = 8'b11000011;
        glyph_rows[2][3] = 8'b11000011;
        glyph_rows[2][4] = 8'b11111111;
        glyph_rows[2][5] = 8'b11000011;
        glyph_rows[2][6] = 8'b11000011;
        glyph_rows[2][7] = 8'b00000000;

        // 'M'
        glyph_rows[3][0] = 8'b11000011;
        glyph_rows[3][1] = 8'b11100111;
        glyph_rows[3][2] = 8'b11111111;
        glyph_rows[3][3] = 8'b11011011;
        glyph_rows[3][4] = 8'b11000011;
        glyph_rows[3][5] = 8'b11000011;
        glyph_rows[3][6] = 8'b11000011;
        glyph_rows[3][7] = 8'b00000000;

        // 'E'
        glyph_rows[4][0] = 8'b11111110;
        glyph_rows[4][1] = 8'b11000000;
        glyph_rows[4][2] = 8'b11000000;
        glyph_rows[4][3] = 8'b11111100;
        glyph_rows[4][4] = 8'b11000000;
        glyph_rows[4][5] = 8'b11000000;
        glyph_rows[4][6] = 8'b11111110;
        glyph_rows[4][7] = 8'b00000000;

        // 'O'
        glyph_rows[5][0] = 8'b01111110;
        glyph_rows[5][1] = 8'b11000011;
        glyph_rows[5][2] = 8'b11000011;
        glyph_rows[5][3] = 8'b11000011;
        glyph_rows[5][4] = 8'b11000011;
        glyph_rows[5][5] = 8'b11000011;
        glyph_rows[5][6] = 8'b01111110;
        glyph_rows[5][7] = 8'b00000000;

        // 'V'
        glyph_rows[6][0] = 8'b11000011;
        glyph_rows[6][1] = 8'b11000011;
        glyph_rows[6][2] = 8'b11000011;
        glyph_rows[6][3] = 8'b11000011;
        glyph_rows[6][4] = 8'b01100110;
        glyph_rows[6][5] = 8'b00111100;
        glyph_rows[6][6] = 8'b00011000;
        glyph_rows[6][7] = 8'b00000000;

        // 'R'
        glyph_rows[7][0] = 8'b11111100;
        glyph_rows[7][1] = 8'b11000110;
        glyph_rows[7][2] = 8'b11000110;
        glyph_rows[7][3] = 8'b11111100;
        glyph_rows[7][4] = 8'b11011000;
        glyph_rows[7][5] = 8'b11001100;
        glyph_rows[7][6] = 8'b11000110;
        glyph_rows[7][7] = 8'b00000000;

        // 'Y'
        glyph_rows[8][0] = 8'b11000011;
        glyph_rows[8][1] = 8'b11000011;
        glyph_rows[8][2] = 8'b01100110;
        glyph_rows[8][3] = 8'b00111100;
        glyph_rows[8][4] = 8'b00011000;
        glyph_rows[8][5] = 8'b00011000;
        glyph_rows[8][6] = 8'b00011000;
        glyph_rows[8][7] = 8'b00000000;

        // 'U'
        glyph_rows[9][0] = 8'b11000011;
        glyph_rows[9][1] = 8'b11000011;
        glyph_rows[9][2] = 8'b11000011;
        glyph_rows[9][3] = 8'b11000011;
        glyph_rows[9][4] = 8'b11000011;
        glyph_rows[9][5] = 8'b11000011;
        glyph_rows[9][6] = 8'b01111110;
        glyph_rows[9][7] = 8'b00000000;

        // 'W'
        glyph_rows[10][0] = 8'b11000011;
        glyph_rows[10][1] = 8'b11000011;
        glyph_rows[10][2] = 8'b11000011;
        glyph_rows[10][3] = 8'b11011011;
        glyph_rows[10][4] = 8'b11011011;
        glyph_rows[10][5] = 8'b11111111;
        glyph_rows[10][6] = 8'b01100110;
        glyph_rows[10][7] = 8'b00000000;

        // 'I'
        glyph_rows[11][0] = 8'b01111110;
        glyph_rows[11][1] = 8'b00011000;
        glyph_rows[11][2] = 8'b00011000;
        glyph_rows[11][3] = 8'b00011000;
        glyph_rows[11][4] = 8'b00011000;
        glyph_rows[11][5] = 8'b00011000;
        glyph_rows[11][6] = 8'b01111110;
        glyph_rows[11][7] = 8'b00000000;

        // 'N'
        glyph_rows[12][0] = 8'b11000011;
        glyph_rows[12][1] = 8'b11100011;
        glyph_rows[12][2] = 8'b11110011;
        glyph_rows[12][3] = 8'b11011011;
        glyph_rows[12][4] = 8'b11001111;
        glyph_rows[12][5] = 8'b11000111;
        glyph_rows[12][6] = 8'b11000011;
        glyph_rows[12][7] = 8'b00000000;
    end

    // Look up the requested pixel. col 0 = MSB (leftmost).
    wire [7:0] row_bits = glyph_rows[ch][row];
    assign pix = row_bits[3'd7 - col];

endmodule