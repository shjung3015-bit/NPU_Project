`timescale 1ns/1ps

// End-to-end check through the real Top_Module boundary (clk/rst_n/rx -> busy/tx
// only, same interface the physical board exposes): program weights and an
// activation into SRAM over UART, trigger load_wgt then run, pop the result,
// and read it back over UART. Uses an identity weight matrix so the expected
// result is trivially the activation vector itself.

module tb_System;

    localparam int CLK_PERIOD   = 10;
    localparam int CLKS_PER_BIT = 234;
    localparam int BIT_PERIOD   = CLK_PERIOD * CLKS_PER_BIT;

    logic clk, rst_n, rx, tx, busy;
    int errors = 0;

    Top_Module DUT (
        .clk(clk), .rst_n(rst_n),
        .rx(rx), .tx(tx),
        .busy(busy)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        #10_000_000;
        $display("WATCHDOG TIMEOUT @ t=%0t", $time);
        $finish;
    end

    // ---- host-side byte-level UART model -------------------------------
    task automatic send_byte(input logic [7:0] b);
        rx = 1'b0;
        #(BIT_PERIOD);
        for (int i = 0; i < 8; i++) begin
            rx = b[i];
            #(BIT_PERIOD);
        end
        rx = 1'b1;
        #(BIT_PERIOD);
    endtask

    task automatic send_write1(input logic [7:0] addr, input logic [7:0] d0);
        send_byte(8'h00); send_byte(addr); send_byte(d0);
    endtask

    task automatic send_write2(input logic [7:0] addr, input logic [7:0] d0, d1);
        send_byte(8'h00); send_byte(addr); send_byte(d0); send_byte(d1);
    endtask

    task automatic send_write4(input logic [7:0] addr, input logic [7:0] d0, d1, d2, d3);
        send_byte(8'h00); send_byte(addr);
        send_byte(d0); send_byte(d1); send_byte(d2); send_byte(d3);
    endtask

    task automatic send_read(input logic [7:0] addr);
        send_byte(8'h01); send_byte(addr);
    endtask

    // ---- background tx listener (see tb_UART_Bridge.sv for why this has
    // to be a free-running background process rather than a reactive wait) --
    logic [7:0] rx_queue [$];

    initial begin : tx_listener
        logic [7:0] b;
        forever begin
            @(negedge tx);
            #(BIT_PERIOD + BIT_PERIOD/2);
            for (int i = 0; i < 8; i++) begin
                b[i] = tx;
                #(BIT_PERIOD);
            end
            rx_queue.push_back(b);
        end
    end

    task automatic recv_byte(output logic [7:0] b);
        wait (rx_queue.size() > 0);
        b = rx_queue.pop_front();
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        rx = 1'b1;

        repeat (5) @(negedge clk);
        rst_n = 1;
        repeat (30) @(negedge clk);

        // --- enable weight-SRAM writes: addr 0x01 = {ena_act,wea_act,ena_wgt,wea_wgt} ---
        send_write1(8'h01, 8'b0000_0011);

        // --- identity weight matrix, row i -> mem[i] = {W[i][3..0]} ---
        send_write2(8'h03, 8'h00, 8'h00); send_write4(8'h08, 8'h00, 8'h00, 8'h00, 8'h01); // row0=[1,0,0,0]
        send_write2(8'h03, 8'h00, 8'h01); send_write4(8'h08, 8'h00, 8'h00, 8'h01, 8'h00); // row1=[0,1,0,0]
        send_write2(8'h03, 8'h00, 8'h02); send_write4(8'h08, 8'h00, 8'h01, 8'h00, 8'h00); // row2=[0,0,1,0]
        send_write2(8'h03, 8'h00, 8'h03); send_write4(8'h08, 8'h01, 8'h00, 8'h00, 8'h00); // row3=[0,0,0,1]

        // --- switch to activation-SRAM write, load A = [1,2,3,4] at addr 0 ---
        send_write1(8'h01, 8'b0000_1100);
        send_write2(8'h02, 8'h00, 8'h00);
        send_write4(8'h07, 8'h04, 8'h03, 8'h02, 8'h01);

        // --- disable all write enables, set num_act=1 ---
        send_write1(8'h01, 8'b0000_0000);
        send_write2(8'h06, 8'h00, 8'h01);

        // --- pulse load_wgt: addr 0x00 = {run,load_wgt,pop_ena} ---
        send_write1(8'h00, 8'b0000_0010);
        repeat (20) @(negedge clk);

        // --- pulse run ---
        send_write1(8'h00, 8'b0000_0100);
        repeat (20) @(negedge clk);

        // --- assert pop_ena and pop the result ---
        send_write1(8'h00, 8'b0000_0001);
        repeat (20) @(negedge clk);

        // --- read back the result ---
        begin
            logic [7:0] rxb [0:16];
            logic [7:0] exp [0:3][0:3];
            int expected [0:3];

            expected[0] = 1; expected[1] = 2; expected[2] = 3; expected[3] = 4;

            send_read(8'h09);
            for (int i = 0; i < 17; i++) recv_byte(rxb[i]);

            $display("result_valid byte = %02h (transient 1-cycle pulse in the RTL --", rxb[0]);
            $display("  not expected to be caught by a read this long after the pop; not treated as a failure)");

            for (int j = 0; j < 4; j++) begin
                logic signed [31:0] got;
                got = {rxb[1+j*4+0], rxb[1+j*4+1], rxb[1+j*4+2], rxb[1+j*4+3]};
                if (got !== expected[j]) begin
                    errors++;
                    $display("[FAIL] result[%0d] got=%0d exp=%0d", j, got, expected[j]);
                end else begin
                    $display("[ OK ] result[%0d] = %0d", j, got);
                end
            end
        end

        if (errors == 0) $display("TEST PASSED");
        else              $display("TEST FAILED (%0d mismatches)", errors);

        $finish;
    end

endmodule
