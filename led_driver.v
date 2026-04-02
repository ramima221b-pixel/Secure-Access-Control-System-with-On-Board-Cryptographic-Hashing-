`timescale 1ns/1ps
module led_driver (
    input  wire granted,
    input  wire denied,
    input  wire busy,
    input  wire plaintext_deleted,
    output wire [15:0] led
);
    // LED mapping (change as you like)
    // LED0 = granted
    // LED1 = denied
    // LED2 = busy
    // LED3 = plaintext_deleted
    assign led[0]  = granted;
    assign led[1]  = denied;
    assign led[2]  = busy;
    assign led[3]  = plaintext_deleted;

    // rest off
    assign led[15:4] = 12'd0;
endmodule
