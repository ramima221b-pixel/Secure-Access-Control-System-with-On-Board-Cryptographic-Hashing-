`timescale 1ns/1ps
module kbd_scancode_decode (
    input  wire       clk,
    input  wire       reset_n,

    input  wire [7:0] sc_byte,
    input  wire       sc_valid,      // 1-cycle pulse from ps2_rx

    output reg  [7:0] key_code,      // scan code (Set 2)
    output reg        key_pressed,   // 1=press (make), 0=release (break)
    output reg        key_extended,  // 1 if preceded by E0
    output reg        key_valid      // 1-cycle pulse when event is emitted
);

    // Prefix flags
    reg got_e0;
    reg got_f0;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            got_e0      <= 1'b0;
            got_f0      <= 1'b0;

            key_code     <= 8'd0;
            key_pressed  <= 1'b0;
            key_extended <= 1'b0;
            key_valid    <= 1'b0;
        end else begin
            key_valid <= 1'b0;

            if (sc_valid) begin
                // Ignore power-on/self-test and ACK bytes if they appear
                // 0xAA = self-test passed (manual)
                // 0xFA = ACK (if host ever sends commands)
                if (sc_byte == 8'hAA || sc_byte == 8'hFA) begin
                    got_e0 <= 1'b0;
                    got_f0 <= 1'b0;
                end
                // Prefix handling
                else if (sc_byte == 8'hE0) begin
                    got_e0 <= 1'b1;
                end
                else if (sc_byte == 8'hF0) begin
                    got_f0 <= 1'b1;
                end
                // Actual key code byte
                else begin
                    key_code     <= sc_byte;
                    key_extended <= got_e0;
                    key_pressed  <= ~got_f0;   // if F0 was seen, this is a release
                    key_valid    <= 1'b1;

                    // consume prefixes
                    got_e0 <= 1'b0;
                    got_f0 <= 1'b0;
                end
            end
        end
    end

endmodule
