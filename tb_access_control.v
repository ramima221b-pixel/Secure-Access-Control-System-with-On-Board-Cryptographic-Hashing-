// ============================================================
// Project : Secure Access Control System - BUET EEE
// File    : tb_access_control.v
// Purpose : Simulation testbench. Verifies correct grant/deny,
//           dual-stage plaintext wipe, and latency measurement.
// Authors : [your group members]
// Date    : [submission date]
// ============================================================
`timescale 1ns/1ps

module tb_access_control;

    // --------------------------------------------------------
    // Clock and reset
    // --------------------------------------------------------
    reg clk;
    reg reset_n;
    always #10 clk = ~clk;   // 20 ns period = 50 MHz

    // --------------------------------------------------------
    // DUT ports
    // --------------------------------------------------------
    reg        byte_valid;
    reg [7:0]  byte_in;
    reg        submit;

    wire        busy;
    wire        granted;
    wire        denied;
    wire        plaintext_deleted;
    wire [255:0] digest_out;
    wire [31:0]  latency_out;

    // --------------------------------------------------------
    // DUT instantiation
    // MASTER_HASH not passed - uses module default from Change 5
    // Default is now 907f74f5... = SHA-256("Abc_123")
    // --------------------------------------------------------
    access_control_hash_1block dut (
        .clk               (clk),
        .reset_n           (reset_n),
        .byte_in           (byte_in),
        .byte_valid        (byte_valid),
        .submit            (submit),
        .busy              (busy),
        .granted           (granted),
        .denied            (denied),
        .plaintext_deleted (plaintext_deleted),
        .digest_out        (digest_out),
        .latency_out       (latency_out)
    );

    // --------------------------------------------------------
    // Task: send one ASCII byte as a single-cycle pulse
    // --------------------------------------------------------
    task send_byte;
        input [7:0] b;
        begin
            @(posedge clk);
            byte_in    = b;
            byte_valid = 1'b1;
            @(posedge clk);
            byte_valid = 1'b0;
            byte_in    = 8'h00;
        end
    endtask

    // --------------------------------------------------------
    // Task: pulse submit for one cycle
    // --------------------------------------------------------
    task press_enter;
        begin
            @(posedge clk);
            submit = 1'b1;
            @(posedge clk);
            submit = 1'b0;
        end
    endtask

    // --------------------------------------------------------
    // Task: wait for result with timeout
    // --------------------------------------------------------
    integer timeout_cnt;
    task wait_for_result;
        begin
            timeout_cnt = 0;
            while (!granted && !denied && timeout_cnt < 10000) begin
                @(posedge clk);
                timeout_cnt = timeout_cnt + 1;
            end
            if (timeout_cnt >= 10000)
                $display("TIMEOUT: no result after 10000 cycles");
        end
    endtask

    // --------------------------------------------------------
    // Simulation dump for waveform viewer
    // --------------------------------------------------------
    initial begin
        $dumpfile("tb_access_control.vcd");
        $dumpvars(0, tb_access_control);
    end

    // --------------------------------------------------------
    // Main stimulus
    // --------------------------------------------------------
    initial begin
        // Initialise
        clk        = 0;
        reset_n    = 0;
        byte_valid = 0;
        byte_in    = 8'h00;
        submit     = 0;

        // Hold reset for 5 cycles
        repeat(5) @(posedge clk);
        reset_n = 1;
        repeat(2) @(posedge clk);

        // ====================================================
        // TEST 1: Correct password "Abc_123"
        // Expected: granted=1, denied=0
        // ASCII: A=0x41 b=0x62 c=0x63 _=0x5F 1=0x31 2=0x32 3=0x33
        // ====================================================
        $display("\n--- TEST 1: Correct password Abc_123 ---");
        send_byte(8'h41); // A
        send_byte(8'h62); // b
        send_byte(8'h63); // c
        send_byte(8'h5F); // _
        send_byte(8'h31); // 1
        send_byte(8'h32); // 2
        send_byte(8'h33); // 3
        press_enter;

        wait_for_result;

        $display("TEST 1 RESULT: granted=%b denied=%b", granted, denied);
        $display("TEST 1 LATENCY: %0d cycles = %0d ns at 50MHz",
                 latency_out, latency_out * 20);
        $display("TEST 1 LATENCY: %0d us = %0d ms (limit: 500ms)",
                 (latency_out * 20) / 1000,
                 (latency_out * 20) / 1000000);
        $display("TEST 1 plaintext_deleted=%b (expect 1)", plaintext_deleted);

        if (granted !== 1'b1)
            $display("FAIL: TEST 1 should grant access");
        else
            $display("PASS: TEST 1 correct password granted");

        // Wait between tests
        repeat(10) @(posedge clk);

        // ====================================================
        // TEST 2: Wrong password "wrongpw"
        // Expected: granted=0, denied=1
        // ====================================================
        $display("\n--- TEST 2: Wrong password wrongpw ---");
        send_byte(8'h77); // w
        send_byte(8'h72); // r
        send_byte(8'h6F); // o
        send_byte(8'h6E); // n
        send_byte(8'h67); // g
        send_byte(8'h70); // p
        send_byte(8'h77); // w
        press_enter;

        wait_for_result;

        $display("TEST 2 RESULT: granted=%b denied=%b", granted, denied);
        if (denied !== 1'b1)
            $display("FAIL: TEST 2 should deny access");
        else
            $display("PASS: TEST 2 wrong password denied");

        repeat(10) @(posedge clk);

        // ====================================================
        // TEST 3: Empty submit (press Enter with no password)
        // Expected: denied=1 (empty string hash != master hash)
        // ====================================================
        $display("\n--- TEST 3: Empty password (Enter only) ---");
        // Send one dummy byte then enter - FSM needs at least
        // one byte to leave S_IDLE; a zero-length attempt is
        // not possible in the current FSM design (submit in
        // S_IDLE is ignored). Send one wrong byte instead.
        send_byte(8'h20); // space
        press_enter;

        wait_for_result;

        $display("TEST 3 RESULT: granted=%b denied=%b", granted, denied);
        if (denied !== 1'b1)
            $display("FAIL: TEST 3 single space should deny");
        else
            $display("PASS: TEST 3 single space denied");

        repeat(10) @(posedge clk);

        // ====================================================
        // TEST 4: Second correct password - verifies latency
        //         counter resets properly between attempts
        // ====================================================
        $display("\n--- TEST 4: Second correct attempt (latency reset check) ---");
        send_byte(8'h41); // A
        send_byte(8'h62); // b
        send_byte(8'h63); // c
        send_byte(8'h5F); // _
        send_byte(8'h31); // 1
        send_byte(8'h32); // 2
        send_byte(8'h33); // 3
        press_enter;

        wait_for_result;

        $display("TEST 4 LATENCY: %0d cycles (should be same as TEST 1)",
                 latency_out);
        if (granted !== 1'b1)
            $display("FAIL: TEST 4 should grant");
        else
            $display("PASS: TEST 4 second correct attempt granted");

        repeat(5) @(posedge clk);

        $display("\n=== ALL TESTS COMPLETE ===");
        $finish;
    end

endmodule