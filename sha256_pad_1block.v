`timescale 1ns/1ps
// ------------------------------------------------------------
// SHA-256 single-block padder (FIPS 180-4 style)
// Supports messages up to 55 bytes (so padding fits in 1 block).
//
// Input:  msg[8*i +: 8] = byte i (i=0 is first char)
// Output: block[511:504] is first byte, big-endian packed into 512b block.
// ------------------------------------------------------------
module sha256_pad_1block #(
    parameter integer MAX_BYTES = 55
) (
    input  wire [8*MAX_BYTES-1:0] msg_bytes,
    input  wire [5:0]             msg_len_bytes,   // 0..55
    output reg  [511:0]           block_padded
);
    integer i;
    reg [63:0] bitlen;

    always @* begin
        block_padded = 512'b0;

        // Copy message bytes into the block (byte 0 goes to block[511:504])
        for (i = 0; i < MAX_BYTES; i = i + 1) begin
            if (i < msg_len_bytes) begin
                block_padded[511 - 8*i -: 8] = msg_bytes[8*i +: 8];
            end
        end

        // Append the '1' bit as 0x80 byte right after the message
        // (since msg_len_bytes <= 55, this always lands before last 64 bits)
        block_padded[511 - 8*msg_len_bytes -: 8] = 8'h80;

        // Append original length (in bits) in the last 64 bits (big-endian by bit placement)
        bitlen = msg_len_bytes * 64'd8;
        // FIPS 180-4 §5.1.1: last 64 bits of the block carry
        // the original message length in bits, big-endian.
        // block_padded[63:0] maps to the final 8 bytes of the block.
        block_padded[63:0] = bitlen;
    end
endmodule

