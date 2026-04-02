`timescale 1ns/1ps
module sha256_oneblock_driver (
    input  wire         clk,
    input  wire         reset_n,

    input  wire         start,      // 1-cycle pulse or held high
    input  wire [511:0] block,

    output reg          busy,
    output reg          done,       // 1-cycle pulse when digest captured
    output reg  [255:0] digest
);

    // ------------------------------------------------------------
    // Secworks sha256_core interface
    // ------------------------------------------------------------
    reg         init;
    reg         next;
    reg         mode;         // secworks convention: (repo-dependent)
                              // keep constant as you used before.
    wire        ready;
    wire        digest_valid;
    wire [255:0] core_digest;

    // ------------------------------------------------------------
    // Latch start request and latch the input block
    // ------------------------------------------------------------
    reg         start_req;
    reg [511:0] block_latched;

    // ------------------------------------------------------------
    // FSM states
    // ------------------------------------------------------------
    localparam S_IDLE     = 3'd0;
    localparam S_WAIT_RDY = 3'd1;
    localparam S_INIT     = 3'd2;
    localparam S_WAIT_LOW = 3'd3;
    localparam S_WAIT_HIGH= 3'd4;

    reg [2:0] state;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state        <= S_IDLE;
            start_req    <= 1'b0;
            block_latched<= 512'd0;

            busy   <= 1'b0;
            done   <= 1'b0;
            digest <= 256'd0;

            init <= 1'b0;
            next <= 1'b0;
            mode <= 1'b1;  // keep same as your original driver
        end else begin
            // defaults each cycle
            done <= 1'b0;
            init <= 1'b0;
            next <= 1'b0;
            mode <= 1'b1;

            // latch start request and block
            if (start && !start_req) begin
                start_req     <= 1'b1;
                block_latched <= block;
            end

            case (state)
                // --------------------------------------------------------
                // IDLE: wait for a start request
                // --------------------------------------------------------
                S_IDLE: begin
                    busy <= 1'b0;
                    if (start_req) begin
                        state <= S_WAIT_RDY;
                    end
                end

                // --------------------------------------------------------
                // WAIT_RDY: wait until core reports ready
                // --------------------------------------------------------
                S_WAIT_RDY: begin
                    busy <= 1'b1;
                    if (ready) begin
                        state <= S_INIT;
                    end
                end

                // --------------------------------------------------------
                // INIT: assert init for exactly 1 cycle
                // core samples block on init
                // --------------------------------------------------------
                S_INIT: begin
                    init      <= 1'b1;
                    start_req <= 1'b0;   // consume request
                    state     <= S_WAIT_LOW;
                end

                // --------------------------------------------------------
                // WAIT_LOW:
                // Important fix: ensure digest_valid is LOW before we accept
                // the next HIGH as "done". Prevents stale previous digest.
                // --------------------------------------------------------
                S_WAIT_LOW: begin
                    if (!digest_valid) begin
                        state <= S_WAIT_HIGH;
                    end
                end

                // --------------------------------------------------------
                // WAIT_HIGH: wait for fresh digest_valid assertion
                // --------------------------------------------------------
                S_WAIT_HIGH: begin
                    if (digest_valid) begin
                        digest <= core_digest;
                        done   <= 1'b1;
                        busy   <= 1'b0;
                        state  <= S_IDLE;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

    // ------------------------------------------------------------
    // Secworks core instance: feed the latched block, not raw block
    // ------------------------------------------------------------
    sha256_core u_core (
        .clk          (clk),
        .reset_n      (reset_n),
        .init         (init),
        .next         (next),
        .mode         (mode),
        .block        (block_latched),
        .ready        (ready),
        .digest       (core_digest),
        .digest_valid (digest_valid)
    );

endmodule
