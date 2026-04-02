`timescale 1ns/1ps
module ps2_rx (
    input  wire       clk,          // system clock (e.g., 100 MHz)
    input  wire       reset_n,      // active-low reset

    input  wire       ps2_clk,      // PS/2 clock (from PIC24 emulation)
    input  wire       ps2_data,     // PS/2 data  (from PIC24 emulation)

    output reg  [7:0] rx_byte,      // received data byte
    output reg        rx_valid,     // 1-cycle pulse when rx_byte is valid

    output reg        framing_err,  // 1-cycle pulse: bad start/stop
    output reg        parity_err    // 1-cycle pulse: odd parity failed
);

    // ------------------------------------------------------------
    // Synchronize PS/2 signals into clk domain (avoid metastability)
    // ------------------------------------------------------------
    reg [2:0] ps2c_sync;
    reg [2:0] ps2d_sync;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            ps2c_sync <= 3'b111;
            ps2d_sync <= 3'b111;
        end else begin
            ps2c_sync <= {ps2c_sync[1:0], ps2_clk};
            ps2d_sync <= {ps2d_sync[1:0], ps2_data};
        end
    end

    wire ps2c = ps2c_sync[2];
    wire ps2d = ps2d_sync[2];

    // ------------------------------------------------------------
    // Detect falling edge of PS/2 clock (sample on falling edge)
    // ------------------------------------------------------------
    reg ps2c_prev;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) ps2c_prev <= 1'b1;
        else          ps2c_prev <= ps2c;
    end

    wire ps2_fall = (ps2c_prev == 1'b1) && (ps2c == 1'b0);

    // ------------------------------------------------------------
    // Capture 11-bit PS/2 frame:
    // start(0), data[7:0] LSB first, odd parity, stop(1)
    // ------------------------------------------------------------
    reg [3:0]  bit_cnt;   // 0..10
    reg [10:0] shreg;     // shift register

    // Because we shift newest bit into MSB:
    //   after full frame:
    //     frame[0]  = start (first received)
    //     frame[8:1]= data D0..D7
    //     frame[9]  = parity
    //     frame[10] = stop  (last received)
    wire [10:0] frame_next = {ps2d, shreg[10:1]};

    // Odd parity check: XOR of (data + parity) must be 1 (odd)
    function automatic odd_parity_ok;
        input [7:0] data;
        input       parity_bit;
        begin
            odd_parity_ok = (^{parity_bit, data}) == 1'b1;
        end
    endfunction

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            bit_cnt     <= 4'd0;
            shreg       <= 11'h7FF;   // idle high
            rx_byte     <= 8'd0;
            rx_valid    <= 1'b0;
            framing_err <= 1'b0;
            parity_err  <= 1'b0;
        end else begin
            // default pulses low
            rx_valid    <= 1'b0;
            framing_err <= 1'b0;
            parity_err  <= 1'b0;

            if (ps2_fall) begin
                // shift in the new bit
                shreg <= frame_next;

                if (bit_cnt == 4'd10) begin
                    // full frame received -> validate using frame_next
                    if ((frame_next[0]  != 1'b0) || (frame_next[10] != 1'b1)) begin
                        framing_err <= 1'b1;
                    end else if (!odd_parity_ok(frame_next[8:1], frame_next[9])) begin
                        parity_err <= 1'b1;
                    end else begin
                        rx_byte  <= frame_next[8:1];
                        rx_valid <= 1'b1;
                    end

                    bit_cnt <= 4'd0;
                end else begin
                    bit_cnt <= bit_cnt + 4'd1;
                end
            end
        end
    end

endmodule
