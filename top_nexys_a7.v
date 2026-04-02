// ============================================================
// Project : Secure Access Control System - BUET EEE
// File    : top_nexys_a7.v
// Purpose : Clean final top module for synthesis and demo.
//           No debug LED scaffolding.
// Authors : [your group members]
// Date    : [submission date]
// ============================================================
`timescale 1ns/1ps

module top_nexys_a7 #(
    parameter integer CLK_HZ    = 50_000_000,
    parameter integer MAX_BYTES = 55,
    parameter [255:0] MASTER_HASH =
        256'h907f74f5ae1571f114bef84799b0f1940f72c2986d40f562f8422369b29cb4c2
)(
    input  wire        clk100mhz,
    input  wire        btnC,
    input  wire        ps2_clk,
    input  wire        ps2_data,
    output wire [6:0]  seg,
    output wire        dp,
    output wire [7:0]  an,
    output wire [15:0] led
);

    wire reset_n = ~btnC;

    // PS/2 receiver
    wire [7:0] ps2_byte;
    wire       ps2_valid;
    wire       ps2_parity_err;
    wire       ps2_frame_err;

    ps2_rx u_ps2_rx (
        .clk        (clk100mhz),
        .reset_n    (reset_n),
        .ps2_clk    (ps2_clk),
        .ps2_data   (ps2_data),
        .rx_byte    (ps2_byte),
        .rx_valid   (ps2_valid),
        .parity_err (ps2_parity_err),
        .framing_err(ps2_frame_err)
    );

    // Scan-code decoder
    wire [7:0] key_code;
    wire       key_pressed;
    wire       key_extended;
    wire       key_valid;

    kbd_scancode_decode u_kbd_decode (
        .clk         (clk100mhz),
        .reset_n     (reset_n),
        .sc_byte     (ps2_byte),
        .sc_valid    (ps2_valid),
        .key_code    (key_code),
        .key_pressed (key_pressed),
        .key_extended(key_extended),
        .key_valid   (key_valid)
    );

    // Set-2 to ASCII
    wire [7:0] ascii_byte;
    wire       ascii_valid;
    wire       submit;

    kbd_set2_to_ascii #(
        .ENABLE_BACKSPACE(0)
    ) u_set2_to_ascii (
        .clk         (clk100mhz),
        .reset_n     (reset_n),
        .key_code    (key_code),
        .key_pressed (key_pressed),
        .key_extended(key_extended),
        .key_valid   (key_valid),
        .ascii_byte  (ascii_byte),
        .ascii_valid (ascii_valid),
        .submit      (submit)
    );

    // Access control + SHA-256
    wire        busy;
    wire        granted;
    wire        denied;
    wire        plaintext_deleted;
    wire [255:0] digest_out;
    wire [31:0]  latency_cycles;

    access_control_hash_1block #(
        .MAX_BYTES   (MAX_BYTES),
        .MASTER_HASH (MASTER_HASH)
    ) u_access (
        .clk               (clk100mhz),
        .reset_n           (reset_n),
        .byte_in           (ascii_byte),
        .byte_valid        (ascii_valid),
        .submit            (submit),
        .busy              (busy),
        .granted           (granted),
        .denied            (denied),
        .plaintext_deleted (plaintext_deleted),
        .digest_out        (digest_out),
        .latency_out       (latency_cycles)
    );

    // Status LEDs
    // led[0]=granted  led[1]=denied
    // led[2]=busy     led[3]=plaintext_deleted
    // led[4]=busy     led[5]=plaintext_deleted (kept per project decision)
    // led[15:6] = off
    assign led[0]   = granted;
    assign led[1]   = denied;
    assign led[2]   = busy;
    assign led[3]   = plaintext_deleted;
    assign led[4]   = busy;
    assign led[5]   = plaintext_deleted;
    assign led[15:6] = 10'b0;

    // Display controller
    wire [7:0] ch7, ch6, ch5, ch4, ch3, ch2, ch1, ch0;

    display_controller u_display (
        .clk     (clk100mhz),
        .reset_n (reset_n),
        .busy    (busy),
        .granted (granted),
        .denied  (denied),
        .ch7(ch7),.ch6(ch6),.ch5(ch5),.ch4(ch4),
        .ch3(ch3),.ch2(ch2),.ch1(ch1),.ch0(ch0)
    );

    // 7-segment scan driver
    sevenseg_scan8 #(
        .CLK_HZ    (CLK_HZ),
        .REFRESH_HZ(1000)
    ) u_seg (
        .clk     (clk100mhz),
        .reset_n (reset_n),
        .ch7(ch7),.ch6(ch6),.ch5(ch5),.ch4(ch4),
        .ch3(ch3),.ch2(ch2),.ch1(ch1),.ch0(ch0),
        .an(an), .seg(seg), .dp(dp)
    );

endmodule