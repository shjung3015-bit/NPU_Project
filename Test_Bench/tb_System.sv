`timescale 1ns/1ps

// Full-system testbench: writes into SRAM_wgt/SRAM_act through the top-level
// write ports (ena_*/wea_*/addr_*_wt/din_*), runs the array, and checks that
// Capture_REG correctly holds each column's result as it arrives (columns
// become valid on different cycles because of the systolic skew) and only
// raises result_valid once all four columns have been captured.
module tb_System;

    localparam int CLK_PERIOD = 10;
    localparam int NUM_TRIALS = 5;

    localparam logic [9:0] BASE_WGT = 10'd0;
    localparam logic [9:0] BASE_ACT = 10'd0;

    logic clk, rst_n, run, load_wgt;
    logic ena_act, wea_act, ena_wgt, wea_wgt;
    logic [9:0] addr_act_wt, addr_wgt_wt;
    logic [9:0] base_addr_wgt, base_addr_act;
    logic [31:0] din_wgt, din_act;
    logic signed [3:0][31:0] data_out;

    int errors = 0;
    int cycle_count;

    Top_Module DUT (
        .clk           (clk),
        .rst_n         (rst_n),
        .run           (run),
        .load_wgt      (load_wgt),
        .ena_act       (ena_act),
        .wea_act       (wea_act),
        .ena_wgt       (ena_wgt),
        .wea_wgt       (wea_wgt),
        .addr_act_wt   (addr_act_wt),
        .addr_wgt_wt   (addr_wgt_wt),
        .base_addr_wgt (base_addr_wgt),
        .base_addr_act (base_addr_act),
        .din_wgt       (din_wgt),
        .din_act       (din_act),
        .data_out      (data_out)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) cycle_count <= 0;
        else        cycle_count <= cycle_count + 1;
    end

    logic signed [7:0] W[4][4];
    logic signed [7:0] A[4];

    function automatic logic signed [7:0] rand8();
        return $urandom_range(0, 40) - 20; // -20..20
    endfunction

    // Write one weight row through the real SRAM_wgt write port (ena_wgt/
    // wea_wgt/addr_wgt_wt/din_wgt), exercising the ports added for loading
    // SRAM_wgt rather than poking DUT.SRAM_wgt.mem[] directly.
    task automatic write_wgt_row(int row, logic signed [7:0] w0, w1, w2, w3);
        logic [31:0] expected_word;
        expected_word = {w3, w2, w1, w0};

        @(negedge clk);
        addr_wgt_wt = BASE_WGT + row;
        din_wgt     = expected_word;
        ena_wgt     = 1;
        wea_wgt     = 1;
        @(negedge clk);
        ena_wgt = 0;
        wea_wgt = 0;

        // Read back what actually landed in SRAM_wgt.mem through the write
        // port, to check the port itself independent of downstream math.
        if (DUT.SRAM_wgt.mem[BASE_WGT + row] !== expected_word) begin
            errors++;
            $display("[FAIL] SRAM_wgt write port: row=%0d got=%h exp=%h",
                      row, DUT.SRAM_wgt.mem[BASE_WGT + row], expected_word);
        end else begin
            $display("[ OK ] SRAM_wgt write port: row=%0d wrote=%h", row, expected_word);
        end
    endtask

    task automatic write_act_row(logic signed [7:0] a0, a1, a2, a3);
        logic [31:0] expected_word;
        expected_word = {a3, a2, a1, a0};

        @(negedge clk);
        addr_act_wt = BASE_ACT;
        din_act     = expected_word;
        ena_act     = 1;
        wea_act     = 1;
        @(negedge clk);
        ena_act = 0;
        wea_act = 0;

        if (DUT.SRAM_act.mem[BASE_ACT] !== expected_word) begin
            errors++;
            $display("[FAIL] SRAM_act write port: got=%h exp=%h",
                      DUT.SRAM_act.mem[BASE_ACT], expected_word);
        end else begin
            $display("[ OK ] SRAM_act write port: wrote=%h", expected_word);
        end
    endtask

    task automatic preload_memories();
        for (int i = 0; i < 4; i++) begin
            write_wgt_row(i, W[i][0], W[i][1], W[i][2], W[i][3]);
        end
        write_act_row(A[0], A[1], A[2], A[3]);
    endtask

    task automatic do_load_weights();
        base_addr_wgt = BASE_WGT;
        load_wgt = 1;
        @(negedge clk);
        load_wgt = 0;
        repeat (8) @(negedge clk);
    endtask

    int arrival_cycle[4];
    logic [3:0] seen;

    task automatic do_run_activation();
        for (int i = 0; i < 4; i++) arrival_cycle[i] = -1;
        seen = 4'b0000;

        base_addr_act = BASE_ACT;
        run = 1;
        @(negedge clk);
        run = 0;

        for (int c = 0; c < 15; c++) begin
            @(posedge clk);
            #1; // let non-blocking updates settle before sampling
            for (int k = 0; k < 4; k++) begin
                if (DUT.data_valid[k] && !seen[k]) begin
                    seen[k]          = 1'b1;
                    arrival_cycle[k] = cycle_count;
                end
            end
        end
        @(negedge clk);
    endtask

    // Columns must become valid strictly in order 0,1,2,3, one cycle apart --
    // this staggering (from the activation skew pipeline) is exactly why
    // Capture_REG is needed instead of reading data_out directly.
    task automatic check_staggered_arrival();
        for (int k = 0; k < 4; k++) begin
            if (arrival_cycle[k] < 0) begin
                errors++;
                $display("[FAIL] column %0d data_valid never asserted", k);
            end
        end
        for (int k = 1; k < 4; k++) begin
            if (arrival_cycle[k] >= 0 && arrival_cycle[k-1] >= 0) begin
                if (arrival_cycle[k] - arrival_cycle[k-1] != 1) begin
                    errors++;
                    $display("[FAIL] column %0d arrived %0d cycle(s) after column %0d (expected 1)",
                              k, arrival_cycle[k] - arrival_cycle[k-1], k-1);
                end
            end
        end
    endtask

    task automatic check_capture_result();
        int a_val, w_val, sum;
        logic signed [31:0] expected;
        for (int j = 0; j < 4; j++) begin
            sum = 0;
            for (int i = 0; i < 4; i++) begin
                a_val = int'(A[i]);
                w_val = int'(W[i][j]);
                sum += a_val * w_val;
            end
            expected = sum;
            if (DUT.result[j] !== expected) begin
                errors++;
                $display("[FAIL] captured result col=%0d got=%0d exp=%0d", j, DUT.result[j], expected);
            end else begin
                $display("[ OK ] captured result col=%0d got=%0d exp=%0d", j, DUT.result[j], expected);
            end
        end

        if (DUT.result_valid !== 1'b1) begin
            errors++;
            $display("[FAIL] result_valid not asserted after all 4 columns captured");
        end else begin
            $display("[ OK ] result_valid asserted");
        end
    endtask

    // Kick the next trial's start pulse and confirm captured/result_valid
    // clear synchronously with it, proving Capture_REG resets between runs.
    task automatic check_result_valid_clears_on_next_start();
        base_addr_act = BASE_ACT;
        run = 1;
        @(negedge clk);
        run = 0;
        @(negedge clk); // current_state: IDLE -> ACT
        @(negedge clk); // ACT case fires; start <= 1 registers here
        @(negedge clk); // one cycle for Capture_REG to react to start

        if (DUT.result_valid !== 1'b0) begin
            errors++;
            $display("[FAIL] result_valid did not clear after new start pulse");
        end else begin
            $display("[ OK ] result_valid cleared on new start");
        end

        repeat (15) @(negedge clk); // let this run finish before next trial
    endtask

    initial begin
        $dumpfile("tb_System.vcd");
        $dumpvars(0, tb_System);

        clk       = 0;
        rst_n     = 0;
        run       = 0;
        load_wgt  = 0;
        ena_act = 0; wea_act = 0; ena_wgt = 0; wea_wgt = 0;
        addr_act_wt = 0; addr_wgt_wt = 0;
        din_wgt   = 0;
        din_act   = 0;
        base_addr_wgt = BASE_WGT;
        base_addr_act = BASE_ACT;

        repeat (3) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        for (int trial = 0; trial < NUM_TRIALS; trial++) begin
            for (int i = 0; i < 4; i++) begin
                for (int j = 0; j < 4; j++) W[i][j] = rand8();
                A[i] = rand8();
            end

            preload_memories();
            do_load_weights();
            do_run_activation();
            $display("-- trial %0d --", trial);
            check_staggered_arrival();
            check_capture_result();
            check_result_valid_clears_on_next_start();
        end

        if (errors == 0) $display("TEST PASSED");
        else              $display("TEST FAILED (%0d mismatches)", errors);

        $finish;
    end

endmodule
