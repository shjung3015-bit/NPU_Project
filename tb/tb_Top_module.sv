`timescale 1ns/1ps

// End-to-end check through the real Top_Module boundary (clk/rst_n/rx ->
// busy/tx only, same interface the physical board exposes). Top_Module no
// longer exposes the datapath control signals directly (they live inside
// UART_Bridge/Systolic_Core now), so every trial is driven purely over the
// UART command protocol: program weights + an activation into SRAM,
// pulse load_wgt then run, pop the result, and read it back over UART.

module tb_Top_Module;

    localparam int CLK_PERIOD   = 10;
    localparam int CLKS_PER_BIT = 234;
    localparam int BIT_PERIOD   = CLK_PERIOD * CLKS_PER_BIT;
    localparam int NUM_TRIALS   = 5;

    localparam logic [9:0] BASE_WGT = 10'd0;
    localparam logic [9:0] BASE_ACT = 10'd0;

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

    logic signed [7:0] W[4][4];
    logic signed [7:0] A[4];

    function automatic logic signed [7:0] rand8();
        return $urandom_range(0, 40) - 20; // -20..20
    endfunction

    // ---- host-side byte-level UART model -------------------------------
    task automatic send_byte(input logic [7:0] b);
        rx = 1'b0;                 // start bit
        #(BIT_PERIOD);
        for (int i = 0; i < 8; i++) begin
            rx = b[i];
            #(BIT_PERIOD);
        end
        rx = 1'b1;                 // stop bit
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

    // 10-bit address register split into the 2 bytes {temp_buf0,temp_buf1};
    // the top 6 bits of the high byte are dropped when assigned into the
    // 10-bit register on the DUT side, so zero-extending here is enough.
    task automatic send_addr(input logic [7:0] reg_id, input logic [9:0] val);
        send_write2(reg_id, {6'b0, val[9:8]}, val[7:0]);
    endtask

    // ---- background tx listener ----------------------------------------
    logic [7:0] RxQueue [$];

    initial begin : tx_listener
        logic [7:0] b;
        forever begin
            @(negedge tx);
            #(BIT_PERIOD + BIT_PERIOD/2);
            for (int i = 0; i < 8; i++) begin
                b[i] = tx;
                #(BIT_PERIOD);
            end
            RxQueue.push_back(b);
        end
    end

    task automatic recv_byte(output logic [7:0] b);
        wait (RxQueue.size() > 0);
        b = RxQueue.pop_front();
    endtask

    // Weight loading reads offsets 3,2,1,0 -> rows 0,1,2,3 of the array
    // (row i ends up holding mem[base_addr_wgt + i]). Byte lane k of the
    // 32-bit write word ends up as wgt_in[k]/act_in[k] (row k for weights,
    // PE row k's activation for act), so mem word = {lane3,lane2,lane1,lane0}.
    task automatic load_weights_and_activation();
        // --- enable weight-SRAM writes: addr 0x01 = {ena_act,wea_act,ena_wgt,wea_wgt} ---
        send_write1(8'h01, 8'b0000_0011);
        for (int i = 0; i < 4; i++) begin
            send_addr(8'h03, BASE_WGT + i[9:0]);
            send_write4(8'h08, W[i][3], W[i][2], W[i][1], W[i][0]);
        end

        // --- switch to activation-SRAM write, load A at BASE_ACT ---
        send_write1(8'h01, 8'b0000_1100);
        send_addr(8'h02, BASE_ACT);
        send_write4(8'h07, A[3], A[2], A[1], A[0]);

        // --- disable all write enables ---
        send_write1(8'h01, 8'b0000_0000);

        // --- base addresses used during LOAD_wgt/run, num_act = 1 ---
        send_addr(8'h05, BASE_WGT);
        send_addr(8'h04, BASE_ACT);
        send_write2(8'h06, 8'h00, 8'h01);
    endtask

    task automatic do_load_weights();
        // addr 0x00 = {run, load_wgt, pop_ena}
        send_write1(8'h00, 8'b0000_0010);
        repeat (20) @(negedge clk);
    endtask

    task automatic do_run_activation();
        send_write1(8'h00, 8'b0000_0100);
        repeat (20) @(negedge clk);
    endtask

    task automatic do_pop_and_check();
        logic [7:0] rxb [0:16];
        int a_val, w_val, sum;
        logic signed [31:0] got, expected;

        send_write1(8'h00, 8'b0000_0001);
        repeat (20) @(negedge clk);

        send_read(8'h09);
        for (int i = 0; i < 17; i++) recv_byte(rxb[i]);

        for (int j = 0; j < 4; j++) begin
            sum = 0;
            for (int i = 0; i < 4; i++) begin
                a_val = int'(A[i]);
                w_val = int'(W[i][j]);
                sum += a_val * w_val;
            end
            expected = sum;
            got = {rxb[1+j*4+0], rxb[1+j*4+1], rxb[1+j*4+2], rxb[1+j*4+3]};

            if (got !== expected) begin
                errors++;
                $display("[FAIL] col=%0d got=%0d exp=%0d", j, got, expected);
            end else begin
                $display("[ OK ] col=%0d got=%0d exp=%0d", j, got, expected);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_Top_module.vcd");
        $dumpvars(0, tb_Top_Module);

        clk   = 0;
        rst_n = 0;
        rx    = 1'b1;

        repeat (5) @(negedge clk);
        rst_n = 1;
        repeat (30) @(negedge clk);  // realistic idle-high settle before first byte

        for (int trial = 0; trial < NUM_TRIALS; trial++) begin
            for (int i = 0; i < 4; i++) begin
                for (int j = 0; j < 4; j++) W[i][j] = rand8();
                A[i] = rand8();
            end

            load_weights_and_activation();
            do_load_weights();
            do_run_activation();
            $display("-- trial %0d --", trial);
            do_pop_and_check();
        end

        if (errors == 0) $display("TEST PASSED");
        else              $display("TEST FAILED (%0d mismatches)", errors);

        $finish;
    end

endmodule
