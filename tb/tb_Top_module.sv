`timescale 1ns/1ps

module tb_Top_Module;

    localparam int CLK_PERIOD = 10;
    localparam int NUM_TRIALS = 5;

    localparam logic [9:0] BASE_WGT = 10'd0;
    localparam logic [9:0] BASE_ACT = 10'd0;

    logic clk, rst_n, run, load_wgt;
    logic ena_act, wea_act, ena_wgt, wea_wgt;
    logic [9:0] addr_act_wt, addr_wgt_wt;
    logic [9:0] base_addr_wgt, base_addr_act;
    logic [31:0] din_wgt, din_act;
    logic pop_ena;
    logic [9:0] num_act;
    logic signed [3:0][31:0] result;

    int errors = 0;

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
        .pop_ena       (pop_ena),
        .num_act       (num_act),
        .result        (result)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    logic signed [7:0]  W[4][4];
    logic signed [7:0]  A[4];

    function automatic logic signed [7:0] rand8();
        return $urandom_range(0, 40) - 20; // -20..20
    endfunction

    // Controller's write-enables (ena_wgt/wea_wgt/ena_act/wea_act) are exposed
    // but poking mem[] directly keeps this testbench focused on the compute
    // datapath rather than the SRAM write port (tb_System.sv covers that).
    // Byte lane k of a 32-bit word ends up as wgt_in[k]/act_in[k] (row k for
    // weights, PE row k's activation for act), so mem word = {lane3,lane2,lane1,lane0}.
    task automatic preload_memories();
        for (int i = 0; i < 4; i++) begin
            DUT.SRAM_wgt.mem[BASE_WGT + i] = {W[i][3], W[i][2], W[i][1], W[i][0]};
        end
        DUT.SRAM_act.mem[BASE_ACT] = {A[3], A[2], A[1], A[0]};
    endtask

    // Weight loading reads offsets 3,2,1,0 -> rows 0,1,2,3 of the array
    // (row i ends up holding mem[base_addr_wgt + i]). Takes 4 cycles in
    // LOAD_wgt; wait with margin before starting the next phase.
    task automatic do_load_weights();
        base_addr_wgt = BASE_WGT;
        load_wgt = 1;
        @(negedge clk);
        load_wgt = 0;
        repeat (8) @(negedge clk);
    endtask

    // Single activation vector: num_act=1 means Controller streams exactly
    // one column through the array. Wait well past the array's pipeline
    // latency (skew + 4x4 propagation) before popping the result FIFOs.
    task automatic do_run_activation();
        base_addr_act = BASE_ACT;
        num_act = 10'd1;
        run = 1;
        @(negedge clk);
        run = 0;
        repeat (15) @(negedge clk);
    endtask

    // Pop the per-column result FIFOs and wait for output_valid (result_valid
    // is an internal Top_Module net, accessed hierarchically since it isn't
    // brought out as a top-level port).
    task automatic do_pop_result();
        int timeout;
        pop_ena = 1;
        @(negedge clk);
        pop_ena = 0;

        timeout = 0;
        while (!DUT.result_valid && timeout < 20) begin
            @(negedge clk);
            timeout++;
        end

        if (!DUT.result_valid) begin
            errors++;
            $display("[FAIL] result_valid never asserted after pop_ena");
        end
    endtask

    task automatic check_result();
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
            if (result[j] !== expected) begin
                errors++;
                $display("[FAIL] col=%0d got=%0d exp=%0d", j, result[j], expected);
            end else begin
                $display("[ OK ] col=%0d got=%0d exp=%0d", j, result[j], expected);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_Top_module.vcd");
        $dumpvars(0, tb_Top_Module);

        clk       = 0;
        rst_n     = 0;
        run       = 0;
        load_wgt  = 0;
        ena_act = 0; wea_act = 0; ena_wgt = 0; wea_wgt = 0;
        addr_act_wt = 0; addr_wgt_wt = 0;
        din_wgt   = 0;
        din_act   = 0;
        pop_ena   = 0;
        num_act   = 0;
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
            do_pop_result();
            $display("-- trial %0d --", trial);
            check_result();
        end

        if (errors == 0) $display("TEST PASSED");
        else              $display("TEST FAILED (%0d mismatches)", errors);

        $finish;
    end

endmodule
