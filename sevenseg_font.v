`timescale 1ns/1ps
module sevenseg_font (
    input  wire [7:0] ch,      // ASCII-like (we'll use real ASCII codes)
    output reg  [6:0] seg,      // {a,b,c,d,e,f,g} active-LOW
    output reg        dp        // active-LOW
);
    always @(*) begin
        dp  = 1'b1;             // default DP off (active-LOW)
        seg = 7'b1111111;       // default all off

        // NOTE: common-anode => segment ON = 0
        // seg order is {a,b,c,d,e,f,g}

        case (ch)
            " " : seg = 7'b1111111;

            // Digits
            "0" : seg = 7'b0000001;
            "1" : seg = 7'b1001111;
            "2" : seg = 7'b0010010;
            "3" : seg = 7'b0000110;
            "4" : seg = 7'b1001100;
            "5" : seg = 7'b0100100;
            "6" : seg = 7'b0100000;
            "7" : seg = 7'b0001111;
            "8" : seg = 7'b0000000;
            "9" : seg = 7'b0000100;

            // Letters (7-seg approximations)
            "A" : seg = 7'b0001000; // A
            "C" : seg = 7'b0110001; // C
            "D" : seg = 7'b1000010; // d (lowercase style)
            "E" : seg = 7'b0110000; // E
            "F" : seg = 7'b0111000; // F
            "G" : seg = 7'b0100001; // G-ish
            "H" : seg = 7'b1001000; // H
            "I" : seg = 7'b1001111; // like 1
            "L" : seg = 7'b1110001; // L
            "N" : seg = 7'b0001001; // n-ish
            "O" : seg = 7'b0000001; // O = 0
            "P" : seg = 7'b0011000; // P
            "R" : seg = 7'b0011001; // r-ish
            "S" : seg = 7'b0100100; // S = 5
            "T" : seg = 7'b1110000; // t-ish
            "U" : seg = 7'b1000001; // U
            "Y" : seg = 7'b1000100; // y-ish

            // You can add more if you want.
            default: seg = 7'b1111111;
        endcase
    end
endmodule
