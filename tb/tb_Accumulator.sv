`timescale 1ns/1ps

module tb_Accumulator;

    localparam int CLK_PERIOD = 10;

    logic clk, rst_n;
    logic signed [3:0][31:0] Core_Result;
    logic CoreResultValid;
    logic AddEna, Pop;
    logic signed [3:0][31:0] dout;
    logic Output_Valid;

    int errors = 0;

    Accumulator DUT (
        .clk             (clk),
        .rst_n           (rst_n),
        .Core_Result     (Core_Result),
        .CoreResultValid (CoreResultValid),
        .AddEna          (AddEna),
        .Pop             (Pop),
        .dout            (dout),
        .Output_Valid    (Output_Valid)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        #5_000_000;
        $display("WATCHDOG TIMEOUT: Addr_Counter=%0d WriteEnable=%0b",
                  DUT.Addr_Counter, DUT.WriteEnable);
        $finish;
    end

    // ---- helpers ----------------------------------------------------------

    // 4-lane row where lane i = tag*16 + i, so a misaligned/off-by-one push
    // (wrong data landing at an address) is immediately visible in the
    // printed value instead of masquerading as a plausible-looking number.
    function automatic logic signed [3:0][31:0] row(input int tag);
        for (int i = 0; i < 4; i++) row[i] = tag*16 + i;
    endfunction

    // read a row straight out of the SRAM array, bypassing dout/Pop entirely
    // (Pop/Output_Valid have no logic behind them yet, per the module spec)
    function automatic logic signed [3:0][31:0] mem_row(input int addr);
        // hierarchical scope index must be a compile-time constant in
        // Icarus, so this is unrolled by hand instead of using a for-loop
        // variable to index into the generate block.
        mem_row[0] = DUT.g_row[0].SRAM_Accumulator.mem[addr];
        mem_row[1] = DUT.g_row[1].SRAM_Accumulator.mem[addr];
        mem_row[2] = DUT.g_row[2].SRAM_Accumulator.mem[addr];
        mem_row[3] = DUT.g_row[3].SRAM_Accumulator.mem[addr];
    endfunction

    task automatic check_row(input string label, input int addr,
                              input logic signed [3:0][31:0] exp);
        logic signed [3:0][31:0] got;
        got = mem_row(addr);
        if (got !== exp) begin
            errors++;
            $display("[FAIL] %s addr=%0d got=%0d,%0d,%0d,%0d exp=%0d,%0d,%0d,%0d",
                      label, addr, got[0], got[1], got[2], got[3],
                      exp[0], exp[1], exp[2], exp[3]);
        end else begin
            $display("[ OK ] %s addr=%0d = %0d,%0d,%0d,%0d",
                      label, addr, got[0], got[1], got[2], got[3]);
        end
    endtask

    // All stimulus is driven right after @(negedge clk), so it is rock
    // stable a full half-period before the DUT's posedge-triggered flops
    // (Accumulator's counters + the SRAMs') ever look at it. Driving
    // immediately after @(posedge clk) instead would race the testbench
    // process against those same-edge always_ff blocks -- confirmed by
    // instrumenting Addr_Counter/WriteEnable with $strobe, which showed
    // CoreResultValid visibly 1 while Addr_Counter/WriteEnable never
    // moved, i.e. the DUT's flops sampled an intermediate, pre-update
    // value of the testbench's signals for that edge.
    task automatic do_reset();
        @(negedge clk);
        rst_n           = 1'b0;
        CoreResultValid = 1'b0;
        AddEna          = 1'b0;
        Pop             = 1'b0;
        Core_Result     = '0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
    endtask

    // Isolated push: pulse CoreResultValid for exactly one cycle, then hold
    // Core_Result/AddEna steady while it drains. AddrWt/WriteEnable are
    // registered (delayed one cycle) to match the SRAM's read latency, so
    // the write that actually fires one cycle later still needs to see the
    // *same* Core_Result/AddEna that were live during the pulse -- holding
    // them steady here is what makes an isolated push safe.
    task automatic push_isolated(input int tag, input logic add_ena);
        Core_Result     = row(tag);
        AddEna          = add_ena;
        CoreResultValid = 1'b1;
        @(negedge clk);
        CoreResultValid = 1'b0;
        repeat (2) @(negedge clk);
    endtask

    initial begin
        $dumpfile("tb_Accumulator.vcd");
        $dumpvars(0, tb_Accumulator);

        clk = 0;

        // =====================================================================
        // 1) Write vs accumulate mode
        // =====================================================================

        // -- 1a: AddEna=0, single row -> plain overwrite --
        do_reset();
        push_isolated(1, 1'b0);                          // addr 0 <- row(1)
        check_row("write single row", 0, row(1));

        // -- 1b: AddEna=0, several different addresses --
        do_reset();
        for (int a = 0; a < 5; a++) push_isolated(10+a, 1'b0);   // addr 0..4
        for (int a = 0; a < 5; a++) check_row("write multi-addr", a, row(10+a));

        // -- 1c: AddEna=1 on the SAME addresses -> old_value + new_Core_Result --
        do_reset();     // counter back to 0; SRAM contents from 1b persist
        for (int a = 0; a < 5; a++) push_isolated(20+a, 1'b1);   // addr 0..4
        for (int a = 0; a < 5; a++) begin
            logic signed [3:0][31:0] exp;
            exp = row(10+a) + row(20+a);   // old (from 1b) + new
            check_row("accumulate multi-addr", a, exp);
        end

        // -- 1d: AddEna=1, single row, one more accumulate on top --
        do_reset();
        push_isolated(30, 1'b1);           // addr 0 <- (row(10)+row(20)) + row(30)
        begin
            logic signed [3:0][31:0] exp;
            exp = row(10) + row(20) + row(30);
            check_row("accumulate single row", 0, exp);
        end

        // =====================================================================
        // 2) Back-to-back pipeline timing: CoreResultValid every cycle, no
        //    gaps, different Core_Result + different target address each cycle.
        // =====================================================================
        do_reset();
        begin
            localparam int N = 8;
            AddEna = 1'b0;
            for (int a = 0; a < N; a++) begin
                Core_Result     = row(100+a);
                CoreResultValid = 1'b1;
                @(negedge clk);
            end
            CoreResultValid = 1'b0;
            Core_Result     = row(999);   // poison: must not leak into any row
            repeat (2) @(negedge clk);

            for (int a = 0; a < N; a++)
                check_row("back-to-back", a, row(100+a));
        end

        // =====================================================================
        // 3) Reset edge case: CoreResultValid asserted on the very first
        //    cycle after rst_n deasserts.
        // =====================================================================
        @(negedge clk);
        rst_n           = 1'b0;
        CoreResultValid = 1'b0;
        AddEna          = 1'b0;
        Pop             = 1'b0;
        Core_Result     = '0;
        repeat (2) @(negedge clk);

        if (dout !== '0) begin
            errors++;
            $display("[FAIL] dout not zero while held in reset: %0d,%0d,%0d,%0d",
                      dout[0], dout[1], dout[2], dout[3]);
        end else $display("[ OK ] dout reads 0 while held in reset");

        if (DUT.Addr_Counter !== 10'd0) begin
            errors++;
            $display("[FAIL] Addr_Counter=%0d while held in reset, expected 0", DUT.Addr_Counter);
        end else $display("[ OK ] Addr_Counter=0 while held in reset");

        // *** very first cycle after rst_n deasserts: release reset and
        //     assert CoreResultValid in the same stroke ***
        rst_n           = 1'b1;
        Core_Result     = row(200);
        AddEna          = 1'b0;
        CoreResultValid = 1'b1;
        @(negedge clk);
        CoreResultValid = 1'b0;
        repeat (2) @(negedge clk);

        if (DUT.Addr_Counter !== 10'd1) begin
            errors++;
            $display("[FAIL] reset-edge: Addr_Counter=%0d, expected 1 after one push starting from 0",
                      DUT.Addr_Counter);
        end else $display("[ OK ] reset-edge: address counter started at 0 and advanced to 1");

        check_row("reset-edge first push", 0, row(200));

        // second push right after should land at address 1, addr 0 untouched
        push_isolated(201, 1'b0);
        check_row("reset-edge second push", 1, row(201));
        check_row("reset-edge addr0 unchanged", 0, row(200));

        if (errors == 0) $display("TEST PASSED");
        else              $display("TEST FAILED (%0d mismatches)", errors);

        $finish;
    end

endmodule
