`timescale 1ns/1ps
module sevenseg_scan8 #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer REFRESH_HZ = 1000          // total display refresh (all digits)
)(
    input  wire       clk,
    input  wire       reset_n,

    input  wire [7:0] ch7,
    input  wire [7:0] ch6,
    input  wire [7:0] ch5,
    input  wire [7:0] ch4,
    input  wire [7:0] ch3,
    input  wire [7:0] ch2,
    input  wire [7:0] ch1,
    input  wire [7:0] ch0,       // rightmost digit

    output reg  [7:0] an,         // active-LOW digit enables
    output reg  [6:0] seg,        // active-LOW segments
    output reg        dp          // active-LOW dp
);

    // ------------------------------------------------------------
    // Refresh tick: we cycle digits 0..7 continuously
    // Tick rate per digit = REFRESH_HZ * 8
    // ------------------------------------------------------------
    localparam integer DIGIT_HZ = REFRESH_HZ * 8;
    localparam integer DIV = (CLK_HZ / DIGIT_HZ);

    reg [$clog2(DIV)-1:0] div_cnt;
    reg [2:0] digit_sel;

    wire tick = (div_cnt == DIV-1);

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            div_cnt   <= 0;
            digit_sel <= 0;
        end else begin
            if (tick) begin
                div_cnt   <= 0;
                digit_sel <= digit_sel + 3'd1;
            end else begin
                div_cnt <= div_cnt + 1;
            end
        end
    end

    // ------------------------------------------------------------
    // Pick current character
    // ------------------------------------------------------------
    reg [7:0] ch_cur;

    always @(*) begin
        case (digit_sel)
            3'd0: ch_cur = ch0;
            3'd1: ch_cur = ch1;
            3'd2: ch_cur = ch2;
            3'd3: ch_cur = ch3;
            3'd4: ch_cur = ch4;
            3'd5: ch_cur = ch5;
            3'd6: ch_cur = ch6;
            3'd7: ch_cur = ch7;
            default: ch_cur = " ";
        endcase
    end

    // ------------------------------------------------------------
    // Font lookup
    // ------------------------------------------------------------
    wire [6:0] seg_w;
    wire       dp_w;

    sevenseg_font u_font (
        .ch (ch_cur),
        .seg(seg_w),
        .dp (dp_w)
    );

    // ------------------------------------------------------------
    // Drive outputs (one digit active at a time)
    // AN is active-LOW
    // ------------------------------------------------------------
    always @(*) begin
        an  = 8'b11111111;
        an[digit_sel] = 1'b0;

        seg = seg_w;
        dp  = dp_w;
    end

endmodule
