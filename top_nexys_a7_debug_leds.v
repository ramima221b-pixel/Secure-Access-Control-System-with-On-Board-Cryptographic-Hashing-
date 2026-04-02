`timescale 1ns/1ps
module top_nexys_a7 #(
    // ------------------------------------------------------------
    // Board clock is 100 MHz on Nexys A7
    // ------------------------------------------------------------
    parameter integer CLK_HZ = 100_000_000,

    // ------------------------------------------------------------
    // Password max bytes must match your access_control_hash module
    // 55 bytes is the max for single-block SHA-256 padding (<=55)
    // ------------------------------------------------------------
    parameter integer MAX_BYTES = 55,

    // ------------------------------------------------------------
    // Master hash (SHA-256 of your chosen master password)
    // Example shown: SHA-256("abc")
    // ------------------------------------------------------------
    parameter [255:0] MASTER_HASH =
        256'h17197de46cdea02874f98bfb7dd520440028f177c1650892dd03a09f1eb7b67a,

    // ------------------------------------------------------------
    // Debug LED pulse-stretch time (milliseconds)
    // ------------------------------------------------------------
    parameter integer DBG_HOLD_MS = 120
)(
    input  wire        clk100mhz,
    input  wire        btnC,

    // PS/2 signals coming from the PIC24 (USB Host -> PS/2 emulation)
    input  wire        ps2_clk,
    input  wire        ps2_data,

    // 7-seg outputs (common anode => active LOW)
    output wire [6:0]  seg,
    output wire        dp,
    output wire [7:0]  an,

    // LEDs
    output wire [15:0] led
);

    // ------------------------------------------------------------
    // Reset (active-low internal)
    // ------------------------------------------------------------
    wire reset_n = ~btnC;

    // ============================================================
    // 1) PS/2 receiver: (ps2_clk, ps2_data) -> byte stream
    // ============================================================
    wire [7:0] ps2_byte;
    wire       ps2_valid;
    wire       ps2_parity_err;
    wire       ps2_frame_err;

    ps2_rx u_ps2_rx (
        .clk         (clk100mhz),
        .reset_n     (reset_n),
        .ps2_clk     (ps2_clk),
        .ps2_data    (ps2_data),
        .rx_byte     (ps2_byte),
        .rx_valid    (ps2_valid),
        .parity_err  (ps2_parity_err),
        .framing_err (ps2_frame_err)
    );

    // ============================================================
    // 2) Scan-code decoder: handles E0 / F0 -> key events
    // ============================================================
    wire [7:0] key_code;
    wire       key_pressed;
    wire       key_extended;
    wire       key_valid;

    kbd_scancode_decode u_kbd_decode (
        .clk          (clk100mhz),
        .reset_n      (reset_n),
        .sc_byte      (ps2_byte),
        .sc_valid     (ps2_valid),
        .key_code     (key_code),
        .key_pressed  (key_pressed),
        .key_extended (key_extended),
        .key_valid    (key_valid)
    );

    // ============================================================
    // 3) Set-2 -> ASCII translator: produces ascii + Enter pulse
    // ============================================================
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

    // ============================================================
    // 4) Access control + SHA256 (your working core)
    // ============================================================
    wire         busy;
    wire         granted;
    wire         denied;
    wire         plaintext_deleted;
    wire [255:0] digest_out;

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
        .digest_out        (digest_out)
    );

    // ============================================================
    // 5) Decide which message to show on 7-seg
    // ============================================================
    wire [7:0] ch7, ch6, ch5, ch4, ch3, ch2, ch1, ch0;

    display_controller u_disp_ctrl (
        .clk     (clk100mhz),
        .reset_n (reset_n),
        .busy    (busy),
        .granted (granted),
        .denied  (denied),
        .ch7     (ch7),
        .ch6     (ch6),
        .ch5     (ch5),
        .ch4     (ch4),
        .ch3     (ch3),
        .ch2     (ch2),
        .ch1     (ch1),
        .ch0     (ch0)
    );

    // ============================================================
    // 6) 7-seg scan driver
    // ============================================================
    sevenseg_scan8 #(
        .CLK_HZ     (CLK_HZ),
        .REFRESH_HZ (1000)
    ) u_7seg (
        .clk     (clk100mhz),
        .reset_n (reset_n),
        .ch7     (ch7),
        .ch6     (ch6),
        .ch5     (ch5),
        .ch4     (ch4),
        .ch3     (ch3),
        .ch2     (ch2),
        .ch1     (ch1),
        .ch0     (ch0),
        .an      (an),
        .seg     (seg),
        .dp      (dp)
    );

    // ============================================================
    // 7) LED status driver (base)
    // ============================================================
    wire [15:0] led_status;
    led_driver u_led (
        .granted           (granted),
        .denied            (denied),
        .busy              (busy),
        .plaintext_deleted (plaintext_deleted),
        .led               (led_status)
    );

    // ============================================================
    // 8) DEBUG LEDs: visible pulse-stretch + toggles
    //    (Do NOT drive LEDs directly from ps2_clk/ps2_data; too fast)
    // ============================================================

    // How long to hold a debug LED ON so you can see it.
    localparam integer DBG_HOLD_CNT = (CLK_HZ/1000) * DBG_HOLD_MS;

    // Pulse-stretch counters (non-zero => LED ON)
    reg [31:0] cnt_ps2_valid;
    reg [31:0] cnt_key_valid;
    reg [31:0] cnt_ascii_valid;
    reg [31:0] cnt_submit;
    reg [31:0] cnt_err;

    // Toggles (flip state per event) so you can see repeated activity
    reg t_ps2;
    reg t_key;
    reg t_ascii;
    reg t_submit;

    wire any_err = ps2_parity_err | ps2_frame_err;

    always @(posedge clk100mhz) begin
        if (!reset_n) begin
            cnt_ps2_valid   <= 32'd0;
            cnt_key_valid   <= 32'd0;
            cnt_ascii_valid <= 32'd0;
            cnt_submit      <= 32'd0;
            cnt_err         <= 32'd0;
            t_ps2           <= 1'b0;
            t_key           <= 1'b0;
            t_ascii         <= 1'b0;
            t_submit        <= 1'b0;
        end else begin
            // -------------------------
            // Event pulse-stretch loads
            // -------------------------
            if (ps2_valid) begin
                cnt_ps2_valid <= DBG_HOLD_CNT[31:0];
                t_ps2 <= ~t_ps2;
            end else if (cnt_ps2_valid != 0) begin
                cnt_ps2_valid <= cnt_ps2_valid - 1;
            end

            if (key_valid) begin
                cnt_key_valid <= DBG_HOLD_CNT[31:0];
                t_key <= ~t_key;
            end else if (cnt_key_valid != 0) begin
                cnt_key_valid <= cnt_key_valid - 1;
            end

            if (ascii_valid) begin
                cnt_ascii_valid <= DBG_HOLD_CNT[31:0];
                t_ascii <= ~t_ascii;
            end else if (cnt_ascii_valid != 0) begin
                cnt_ascii_valid <= cnt_ascii_valid - 1;
            end

            if (submit) begin
                cnt_submit <= DBG_HOLD_CNT[31:0];
                t_submit <= ~t_submit;
            end else if (cnt_submit != 0) begin
                cnt_submit <= cnt_submit - 1;
            end

            if (any_err) begin
                cnt_err <= DBG_HOLD_CNT[31:0];
            end else if (cnt_err != 0) begin
                cnt_err <= cnt_err - 1;
            end
        end
    end

    // ============================================================
    // LED MAP
    // - Keep your original status LEDs on [3:0] exactly as before.
    // - Put robust, human-visible keyboard debug on the upper LEDs.
    // ============================================================

    assign led[3:0] = led_status[3:0];

    // Optional: show the running state bits too (helps quickly)
    assign led[4]   = busy;
    assign led[5]   = plaintext_deleted;

    // Debug activity (pulse-stretched)
    assign led[10]  = (cnt_submit      != 0); // Enter detected (visible)
    assign led[11]  = (cnt_ascii_valid != 0); // ASCII produced
    assign led[12]  = (cnt_key_valid   != 0); // key event decoded
    assign led[13]  = (cnt_ps2_valid   != 0); // PS/2 byte received
    assign led[14]  = (cnt_err         != 0); // parity/framing error seen

    // Event toggles (flip every event)
    assign led[15]  = t_ps2;                  // toggles each PS/2 byte

    // The remaining LEDs are left as-is / off
    assign led[9:6] = 4'b0000;

endmodule
