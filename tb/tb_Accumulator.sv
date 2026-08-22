`timescale 1ns/1ps

module tb_Accumulator;

    localparam int CLK_PERIOD = 10;

    logic clk, rst_n;
    logic signed [3:0][31:0] Core_Result;
    logic CoreResultValid;
    logic AddEna, Pop, TileStart;
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
        .TileStart       (TileStart),
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

    // read a row straight out of the SRAM array, bypassing dout/Pop entirely,
    // so write-side checks stay independent of the Pop/Output_Valid path
    // (which is exercised separately via dout/Output_Valid in the Pop tests).
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

    task automatic check_pop(input string label, input int idx,
                              input logic signed [3:0][31:0] exp);
        logic signed [3:0][31:0] got;
        logic valid;
        pop_one(got, valid);
        if (!valid) begin
            errors++;
            $display("[FAIL] %s idx=%0d Output_Valid=0, expected 1", label, idx);
        end
        if (got !== exp) begin
            errors++;
            $display("[FAIL] %s idx=%0d got=%0d,%0d,%0d,%0d exp=%0d,%0d,%0d,%0d",
                      label, idx, got[0], got[1], got[2], got[3],
                      exp[0], exp[1], exp[2], exp[3]);
        end else begin
            $display("[ OK ] %s idx=%0d = %0d,%0d,%0d,%0d (Output_Valid=%0b)",
                      label, idx, got[0], got[1], got[2], got[3], valid);
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
        TileStart       = 1'b0;
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

    // Isolated pop: pulse Pop for exactly one cycle (mirrors push_isolated's
    // one-cycle CoreResultValid pulse), since PopEdge/Addr_Pop only advance
    // on Pop's rising edge -- holding Pop high does NOT keep popping.
    //
    // Timing: Pop is raised right after @(negedge clk), so it is stable for
    // the very next posedge, at which PopEdge=1 fires and, in the same
    // stroke: Addr_Pop advances, Output_Valid<=1, and the SRAM's registered
    // read port latches mem[Addr_Pop] (one-cycle SRAM read latency, same as
    // the write side). So by the following @(negedge clk) -- the first one
    // below -- dout/Output_Valid already reflect that pop; that is exactly
    // where they are sampled. Pop is then dropped and one more @(negedge
    // clk) is let through so Output_Valid settles back to 0 and PopPrev
    // clears, leaving the DUT ready for the next isolated pop.
    task automatic pop_one(output logic signed [3:0][31:0] got,
                            output logic valid);
        Pop = 1'b1;
        @(negedge clk);
        got   = dout;
        valid = Output_Valid;
        Pop = 1'b0;
        @(negedge clk);
    endtask

    // Isolated TileStart pulse: same one-cycle-pulse-then-settle shape as
    // push_isolated/pop_one. TileStartEdge zeroes Addr_Counter, Addr_Pop and
    // Popping in the same stroke, re-arming both the push and pop address
    // sequences for the next tile.
    task automatic do_tile_start();
        TileStart = 1'b1;
        @(negedge clk);
        TileStart = 1'b0;
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

        // =====================================================================
        // 4) Pop: read accumulated rows back out via dout/Output_Valid.
        // =====================================================================

        // -- 4a: push a small tile, then pop it back out in order --
        do_reset();
        begin
            localparam int N = 4;
            for (int a = 0; a < N; a++) push_isolated(40+a, 1'b0);   // addr 0..3
            for (int a = 0; a < N; a++)
                check_pop("pop in order", a, row(40+a));
        end

        // -- 4b: Output_Valid must drop back to 0 once the pop pulse passes,
        //    i.e. it's a one-cycle strobe, not a level that stays up --
        if (Output_Valid !== 1'b0) begin
            errors++;
            $display("[FAIL] Output_Valid=%0b after last pop settled, expected 0", Output_Valid);
        end else $display("[ OK ] Output_Valid=0 after pop settles");

        // -- 4c: Pop is edge-triggered -- holding Pop high must NOT advance
        //    Addr_Pop or re-pulse Output_Valid on its own --
        do_reset();
        push_isolated(45, 1'b0);              // addr 0 <- row(45)
        begin
            logic signed [3:0][31:0] got;
            logic valid;
            pop_one(got, valid);              // consumes the single PopEdge -> addr 0
            if (got !== row(45) || !valid) begin
                errors++;
                $display("[FAIL] level-Pop setup: got=%0d,%0d,%0d,%0d valid=%0b",
                          got[0], got[1], got[2], got[3], valid);
            end

            // raise Pop again and hold it high across several cycles: only
            // the 0->1 transition itself should advance Addr_Pop (once) --
            // holding the level afterward must not advance it again.
            Pop = 1'b1;
            @(negedge clk);                   // the rising edge -> Addr_Pop: 1 -> 2
            if (DUT.Addr_Pop !== 10'd2) begin
                errors++;
                $display("[FAIL] Addr_Pop=%0d right after Pop's rising edge, expected 2", DUT.Addr_Pop);
            end
            repeat (3) @(negedge clk);        // still held high, no further edges
            if (DUT.Addr_Pop !== 10'd2) begin
                errors++;
                $display("[FAIL] Addr_Pop=%0d advanced while Pop held high without a new edge, expected 2",
                          DUT.Addr_Pop);
            end else $display("[ OK ] Addr_Pop stayed at 2 while Pop held high (edge-triggered)");
            if (Output_Valid !== 1'b0) begin
                errors++;
                $display("[FAIL] Output_Valid=%0b while Pop held high with no new edge, expected 0", Output_Valid);
            end else $display("[ OK ] Output_Valid=0 while Pop held high with no new edge");
            Pop = 1'b0;
            @(negedge clk);
        end

        // =====================================================================
        // 5) TileStart: re-arms both Addr_Counter (push side) and Addr_Pop
        //    (pop side) back to 0 for the next tile.
        // =====================================================================
        do_reset();
        begin
            localparam int N = 3;
            for (int a = 0; a < N; a++) push_isolated(50+a, 1'b0);   // addr 0..2

            // pop one row before the tile boundary, so Addr_Pop != 0 going in
            check_pop("tile A pop", 0, row(50));

            do_tile_start();

            if (DUT.Addr_Counter !== 10'd0) begin
                errors++;
                $display("[FAIL] Addr_Counter=%0d after TileStart, expected 0", DUT.Addr_Counter);
            end else $display("[ OK ] Addr_Counter=0 after TileStart");

            if (DUT.Addr_Pop !== 10'd0) begin
                errors++;
                $display("[FAIL] Addr_Pop=%0d after TileStart, expected 0", DUT.Addr_Pop);
            end else $display("[ OK ] Addr_Pop=0 after TileStart");

            if (DUT.Popping !== 1'b0) begin
                errors++;
                $display("[FAIL] Popping=%0b after TileStart, expected 0", DUT.Popping);
            end else $display("[ OK ] Popping=0 after TileStart");

            // next tile's pushes must land back at addr 0, overwriting tile A
            for (int a = 0; a < 2; a++) push_isolated(60+a, 1'b0);   // addr 0..1
            check_row("tile B overwrite addr0", 0, row(60));
            check_row("tile B overwrite addr1", 1, row(61));

            // and popping tile B must start over at addr 0, not resume tile A
            check_pop("tile B pop", 0, row(60));
            check_pop("tile B pop", 1, row(61));
        end

        if (errors == 0) $display("TEST PASSED");
        else              $display("TEST FAILED (%0d mismatches)", errors);

        $finish;
    end

endmodule
