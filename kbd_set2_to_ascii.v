`timescale 1ns/1ps
module kbd_set2_to_ascii #(
    parameter ENABLE_BACKSPACE = 0   // 1 => output ASCII 0x08 on Backspace press
)(
    input  wire       clk,
    input  wire       reset_n,

    input  wire [7:0] key_code,       // Set 2 scan code
    input  wire       key_pressed,    // 1=press, 0=release
    input  wire       key_extended,   // ignore extended keys for password typing
    input  wire       key_valid,      // 1-cycle pulse per event

    output reg  [7:0] ascii_byte,     // ASCII output
    output reg        ascii_valid,    // 1-cycle pulse when ascii_byte is valid
    output reg        submit          // 1-cycle pulse on Enter press
);

    // ------------------------------------------------------------
    // Modifier states
    // ------------------------------------------------------------
    reg shift_down;
    reg caps_on;

    // Set 2 scan codes (common)
    localparam [7:0] SC_LSHIFT = 8'h12;
    localparam [7:0] SC_RSHIFT = 8'h59;
    localparam [7:0] SC_CAPS   = 8'h58;

    localparam [7:0] SC_ENTER  = 8'h5A;
    localparam [7:0] SC_SPACE  = 8'h29;
    localparam [7:0] SC_BKSP   = 8'h66;

    // ------------------------------------------------------------
    // Apply letter case:
    // upper = caps XOR shift
    // ------------------------------------------------------------
    function [7:0] apply_case;
        input [7:0] lower;   // 'a'..'z'
        input       shift;
        input       caps;
        reg         upper;
        begin
            upper = (caps ^ shift);
            apply_case = upper ? (lower - 8'd32) : lower;
        end
    endfunction

    // ------------------------------------------------------------
    // Map Set-2 scan code to ASCII (press events only)
    // Returns 8'h00 if not a printable key we care about
    // ------------------------------------------------------------
    function [7:0] map_to_ascii;
        input [7:0] sc;
        input       shift;
        input       caps;
        reg [7:0] out;
        begin
            out = 8'h00;

            // -------- Letters (Set 2) --------
            case (sc)
                8'h1C: out = apply_case("a", shift, caps);
                8'h32: out = apply_case("b", shift, caps);
                8'h21: out = apply_case("c", shift, caps);
                8'h23: out = apply_case("d", shift, caps);
                8'h24: out = apply_case("e", shift, caps);
                8'h2B: out = apply_case("f", shift, caps);
                8'h34: out = apply_case("g", shift, caps);
                8'h33: out = apply_case("h", shift, caps);
                8'h43: out = apply_case("i", shift, caps);
                8'h3B: out = apply_case("j", shift, caps);
                8'h42: out = apply_case("k", shift, caps);
                8'h4B: out = apply_case("l", shift, caps);
                8'h3A: out = apply_case("m", shift, caps);
                8'h31: out = apply_case("n", shift, caps);
                8'h44: out = apply_case("o", shift, caps);
                8'h4D: out = apply_case("p", shift, caps);
                8'h15: out = apply_case("q", shift, caps);
                8'h2D: out = apply_case("r", shift, caps);
                8'h1B: out = apply_case("s", shift, caps);
                8'h2C: out = apply_case("t", shift, caps);
                8'h3C: out = apply_case("u", shift, caps);
                8'h2A: out = apply_case("v", shift, caps);
                8'h1D: out = apply_case("w", shift, caps);
                8'h22: out = apply_case("x", shift, caps);
                8'h35: out = apply_case("y", shift, caps);
                8'h1A: out = apply_case("z", shift, caps);
                default: begin end
            endcase

            // If we already matched a letter, return it
            if (out != 8'h00) begin
                map_to_ascii = out;
            end else begin
                // -------- Number row (Set 2) --------
                case (sc)
                    8'h16: out = shift ? "!" : "1";
                    8'h1E: out = shift ? "@" : "2";
                    8'h26: out = shift ? "#" : "3";
                    8'h25: out = shift ? "$" : "4";
                    8'h2E: out = shift ? "%" : "5";
                    8'h36: out = shift ? "^" : "6";
                    8'h3D: out = shift ? "&" : "7";
                    8'h3E: out = shift ? "*" : "8";
                    8'h46: out = shift ? "(" : "9";
                    8'h45: out = shift ? ")" : "0";
                    default: begin end
                endcase

                // -------- Punctuation / space --------
                if (out == 8'h00) begin
                    case (sc)
                        8'h0E: out = shift ? "~"  : "`";
                        8'h4E: out = shift ? "_"  : "-";
                        8'h55: out = shift ? "+"  : "=";
                        8'h54: out = shift ? "{"  : "[";
                        8'h5B: out = shift ? "}"  : "]";
                        8'h5D: out = shift ? "|"  : "\\";
                        8'h4C: out = shift ? ":"  : ";";
                        8'h52: out = shift ? "\"" : "'";
                        8'h41: out = shift ? "<"  : ",";
                        8'h49: out = shift ? ">"  : ".";
                        8'h4A: out = shift ? "?"  : "/";
                        8'h29: out = " "; // space
                        default: begin end
                    endcase
                end

                map_to_ascii = out;
            end
        end
    endfunction

    // ------------------------------------------------------------
    // Main logic: produce ascii_valid on key press events only
    // ------------------------------------------------------------
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            shift_down  <= 1'b0;
            caps_on     <= 1'b0;
            ascii_byte  <= 8'd0;
            ascii_valid <= 1'b0;
            submit      <= 1'b0;
        end else begin
            ascii_valid <= 1'b0;
            submit      <= 1'b0;

            if (key_valid) begin
                // Ignore extended keys for password typing (arrows etc.)
                if (!key_extended) begin

                    // Shift held while pressed
                    if (key_code == SC_LSHIFT || key_code == SC_RSHIFT) begin
                        shift_down <= key_pressed;
                    end
                    // Caps toggles on press
                    else if (key_code == SC_CAPS && key_pressed) begin
                        caps_on <= ~caps_on;
                    end
                    // Enter generates submit pulse
                    else if (key_code == SC_ENTER && key_pressed) begin
                        submit <= 1'b1;
                    end
                    // Optional backspace
                    else if (key_code == SC_BKSP && key_pressed) begin
                        if (ENABLE_BACKSPACE) begin
                            ascii_byte  <= 8'h08;
                            ascii_valid <= 1'b1;
                        end
                    end
                    // Printable key press -> ASCII
                    else if (key_pressed) begin
                        ascii_byte <= map_to_ascii(key_code, shift_down, caps_on);
                        if (map_to_ascii(key_code, shift_down, caps_on) != 8'h00) begin
                            ascii_valid <= 1'b1;
                        end
                    end

                end
            end
        end
    end

endmodule
