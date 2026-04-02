`timescale 1ns/1ps
module display_controller (
    input  wire clk,
    input  wire reset_n,

    input  wire busy,
    input  wire granted,
    input  wire denied,

    output reg [7:0] ch7,
    output reg [7:0] ch6,
    output reg [7:0] ch5,
    output reg [7:0] ch4,
    output reg [7:0] ch3,
    output reg [7:0] ch2,
    output reg [7:0] ch1,
    output reg [7:0] ch0
);
    // Simple priority:
    // busy > granted > denied > idle
    always @(*) begin
        // default: IDLE message
        ch7="E"; ch6="N"; ch5="T"; ch4="E"; ch3="R"; ch2=" "; ch1=" "; ch0=" ";

        if (busy) begin
            ch7="B"; ch6="U"; ch5="S"; ch4="Y"; ch3=" "; ch2=" "; ch1=" "; ch0=" ";
        end else if (granted) begin
            // "ACC GRNT" (fits 8 digits)
            ch7="A"; ch6="C"; ch5="C"; ch4=" "; ch3="G"; ch2="R"; ch1="N"; ch0="T";
        end else if (denied) begin
            // "DENIED  "
            ch7="D"; ch6="E"; ch5="N"; ch4="I"; ch3="E"; ch2="D"; ch1=" "; ch0=" ";
        end
    end

endmodule
