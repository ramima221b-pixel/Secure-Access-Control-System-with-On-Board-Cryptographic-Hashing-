`timescale 1ns/1ps
module access_control_hash_1block #(
    parameter integer MAX_BYTES  = 55,
    parameter [255:0] MASTER_HASH = 256'h907f74f5ae1571f114bef84799b0f1940f72c2986d40f562f8422369b29cb4c2
)(
    input  wire        clk,
    input  wire        reset_n,

    input  wire [7:0]  byte_in,
    input  wire        byte_valid,   // pulse
    input  wire        submit,       // pulse

    output reg         busy,
    output reg         granted,
    output reg         denied,
    output reg         plaintext_deleted,
    output reg [255:0] digest_out,
    output reg [31:0] latency_out    // cycle count from LATCH to done
);

    // ------------------------------------------------------------
    // Plaintext buffer (ASCII bytes, variable length, up to MAX_BYTES)
    // Convention:
    //   - First typed char -> pw_bytes[7:0]
    //   - Next             -> pw_bytes[15:8], etc.
    // ------------------------------------------------------------
    reg [8*MAX_BYTES-1:0] pw_bytes;
    reg [5:0]             pw_len;

    // ------------------------------------------------------------
    // Attempt counter (for debug prints)
    // Increments when a new attempt begins (first byte received in IDLE).
    // ------------------------------------------------------------
    reg [7:0] attempt_id;
    // Latency measurement
    reg [31:0] lat_cnt;
    reg        lat_running;

    // ------------------------------------------------------------
    // Padding module: (pw_bytes, pw_len) -> 512-bit padded block
    // ------------------------------------------------------------
    wire [511:0] block_padded;
    sha256_pad_1block #(.MAX_BYTES(MAX_BYTES)) u_pad (
        .msg_bytes     (pw_bytes),
        .msg_len_bytes (pw_len),
        .block_padded  (block_padded)
    );

    // ------------------------------------------------------------
    // Stable block register fed to the SHA driver
    // ------------------------------------------------------------
    reg [511:0] block_reg;

    // ------------------------------------------------------------
    // One-block SHA-256 driver (wraps secworks core)
    // ------------------------------------------------------------
    reg          start_drv;
    wire         drv_busy;
    wire         drv_done;
    wire [255:0] drv_digest;

    sha256_oneblock_driver u_drv (
        .clk     (clk),
        .reset_n (reset_n),
        .start   (start_drv),
        .block   (block_reg),
        .busy    (drv_busy),
        .done    (drv_done),
        .digest  (drv_digest)
    );

    // ------------------------------------------------------------
    // FSM states
    // ------------------------------------------------------------
    localparam S_IDLE    = 3'd0;
    localparam S_COLLECT = 3'd1;
    localparam S_LATCH   = 3'd2;
    localparam S_START1  = 3'd3;
    localparam S_START2  = 3'd4;
    localparam S_WAIT    = 3'd5;
    localparam S_DONE    = 3'd6;

    reg [2:0] state;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state             <= S_IDLE;

            pw_bytes          <= { (8*MAX_BYTES){1'b0} };
            pw_len            <= 6'd0;

            block_reg         <= 512'd0;
            start_drv         <= 1'b0;

            attempt_id        <= 8'd0;
            lat_cnt        <= 32'd0;
            lat_running    <= 1'b0;
            latency_out    <= 32'd0;

            // outputs
            busy              <= 1'b0;
            granted           <= 1'b0;
            denied            <= 1'b0;
            plaintext_deleted <= 1'b0;
            digest_out        <= 256'd0;

        end else begin
            // ------------------------------------------------------------
            // Defaults each cycle
            // ------------------------------------------------------------
            start_drv <= 1'b0;

            // ------------------------------------------------------------
            // Option A: busy is high whenever we are not idle.
            // This is the correct "handshake" definition for TB/UI.
            // ------------------------------------------------------------
            busy <= (state != S_IDLE);
            // Increment latency counter every cycle while running
            if (lat_running) lat_cnt <= lat_cnt + 32'd1;

            case (state)

                // --------------------------------------------------------
                // IDLE: wait for first byte of a new password attempt
                // --------------------------------------------------------
                S_IDLE: begin
                    if (byte_valid) begin
                        // New attempt begins
                        attempt_id        <= attempt_id + 8'd1;
                
                        // Clear result flags
                        granted           <= 1'b0;
                        denied            <= 1'b0;
                        plaintext_deleted <= 1'b0;
                        digest_out        <= 256'd0;
                
                        // **FIXED: Properly clear all bytes and set first byte**
                        pw_bytes          <= {(8*MAX_BYTES){1'b0}};  // Clear everything first
                        pw_bytes[7:0]     <= byte_in;                     // Then set first byte
                        pw_len            <= 6'd1;
                
                        state <= S_COLLECT;
                    end
                end

                // --------------------------------------------------------
                // COLLECT: accept bytes until submit pulse arrives
                // --------------------------------------------------------
                S_COLLECT: begin
                    if (byte_valid) begin
                        if (pw_len < MAX_BYTES) begin
                            pw_bytes[8*pw_len +: 8] <= byte_in;
                            pw_len                  <= pw_len + 1'b1;
                        end
                    end

                    if (submit) begin
                        state <= S_LATCH;
                    end
                end

                // --------------------------------------------------------
                // LATCH: freeze the padded block into block_reg
                // --------------------------------------------------------
                S_LATCH: begin
                    block_reg  <= block_padded;
                    lat_cnt    <= 32'd0;     // reset for this attempt
                    lat_running <= 1'b1;     // start counting
                    state      <= S_START1;
                end
                // --------------------------------------------------------
                // START1: pulse start to SHA driver
                // --------------------------------------------------------
                S_START1: begin
`ifndef SYNTHESIS
                    $display("%0t [DUT] BEGIN hash attempt=%0d len=%0d bytes: '%c' '%c' '%c'",
                             $time, attempt_id, pw_len,
                             pw_bytes[7:0], pw_bytes[15:8], pw_bytes[23:16]);
`endif
                    start_drv <= 1'b1;
                    state     <= S_START2;
                end

                // --------------------------------------------------------
                // START2: wipe plaintext immediately after launching hash
                // --------------------------------------------------------
                S_START2: begin
                    pw_len   <= 6'd0;
                    pw_bytes <= { (8*MAX_BYTES){1'b0} };

                    plaintext_deleted <= 1'b1;
                    state             <= S_WAIT;
                end

                // --------------------------------------------------------
                // WAIT: wait for driver done, then latch digest and compare
                // --------------------------------------------------------
                S_WAIT: begin
                    if (drv_done) begin
                    lat_running <= 1'b0;
                    latency_out <= lat_cnt;
`ifndef SYNTHESIS
                        $display("%0t [DUT] DONE  hash attempt=%0d digest=%h",
                                 $time, attempt_id, drv_digest);
`endif
                        // SECURITY WIPE STAGE 2: zero the 512-bit FIPS-padded block register.
                        // Stage 1 (pw_bytes raw ASCII) was zeroed in S_START2.
                        // After this, no password-derived data remains anywhere in the design.
                        block_reg <= 512'd0;

                        digest_out <= drv_digest;

                        if (drv_digest == MASTER_HASH) begin
                            granted <= 1'b1;
                            denied  <= 1'b0;
                        end else begin
                            granted <= 1'b0;
                            denied  <= 1'b1;
                        end

                        state <= S_DONE;
                    end
                end

                // --------------------------------------------------------
                // DONE: one-cycle terminal state, then return to idle
                // --------------------------------------------------------
                S_DONE: begin
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end

            endcase
        end
    end

endmodule
