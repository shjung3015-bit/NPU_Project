`timescale 1ns/1ps

// LoopMatmul (hardware K-tile loop) validation, driven purely over the UART
// command protocol through the Top_Module boundary (same interface the
// physical board exposes).
//
// Unlike tb_Tiling.sv -- which re-programs the weight/activation SRAM and
// re-pulses load_wgt/run once per K-tile from the testbench side -- this
// exercises the new LoopMatmul hardware: the whole weight matrix (all K
// rows) and every K-tile's activation block are programmed into SRAM up
// front, REG_NUM_K_TILE + REG_BASE_WGT/ACT are set once, and a single
// REG_CTRL LoopStart pulse lets LoopMatmul step through every K-tile
// on its own (Load_wgt -> run -> next tile's Load_wgt -> ... -> done),
// accumulating partial sums in Accumulator via its own AddEna/TileStart.
// Only after the whole loop settles does the testbench pop the M result
// rows back out.
//
// LoopMatmul advances BaseAddr_wgt/BaseAddr_act by a fixed stride of
// ARRAY_SIZE (4) per K-tile regardless of M, so each K-tile's activation
// block must live in its own 4-row window (block for k_tile occupies
// addresses [k_tile*4, k_tile*4+M-1]) without colliding with its
// neighbors -- that only holds if M <= ARRAY_SIZE, so this test fixes
// M = ARRAY_SIZE = 4 and sweeps K = 4, 8, 12 (each already a whole
// multiple of ARRAY_SIZE, so K_TILES = K/4 with no remainder tile).

module tb_LoopMatmul;

    localparam int CLK_PERIOD   = 10;
    localparam int CLKS_PER_BIT = 234;
    localparam int BIT_PERIOD   = CLK_PERIOD * CLKS_PER_BIT;

    localparam int ARRAY_SIZE = 4;
    localparam int M          = ARRAY_SIZE; // fixed: see stride note above
    localparam int K_MAX      = 12;
    localparam int NUM_TRIALS = 3;

    // register map (mirrors src/UART_Bridge.sv's REG_* localparams)
    localparam logic [7:0] REG_CTRL        = 8'h00; // {run, Load_wgt, PopEna, LoopStart}
    localparam logic [7:0] REG_MODE        = 8'h01; // {Ena_act, Wea_act, Ena_wgt, Wea_wgt}
    localparam logic [7:0] REG_ADDR_ACT_WT = 8'h02;
    localparam logic [7:0] REG_ADDR_WGT_WT = 8'h03;
    localparam logic [7:0] REG_BASE_ACT    = 8'h04;
    localparam logic [7:0] REG_BASE_WGT    = 8'h05;
    localparam logic [7:0] REG_NUM_ACT     = 8'h06;
    localparam logic [7:0] REG_DIN_ACT     = 8'h07;
    localparam logic [7:0] REG_DIN_WGT     = 8'h08;
    localparam logic [7:0] REG_RESULT      = 8'h09;
    localparam logic [7:0] REG_NUM_K_TILE  = 8'h12;
    localparam logic [7:0] REG_NUM_N_TILE  = 8'h13;

    logic clk, rst_n, rx, tx, busy;
    int errors = 0;

    Top_Module DUT (
        .clk(clk), .rst_n(rst_n),
        .rx(rx), .tx(tx),
        .busy(busy)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        #300_000_000;
        $display("WATCHDOG TIMEOUT @ t=%0t", $time);
        $finish;
    end

    // ---- host-side byte-level UART model (same as tb_Tiling.sv) --------
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

    task automatic send_addr(input logic [7:0] reg_id, input logic [9:0] val);
        send_write2(reg_id, {6'b0, val[9:8]}, val[7:0]);
    endtask

    // ---- background tx listener (same as tb_Tiling.sv) -----------------
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

    // ---- test data --------------------------------------------------------
    logic signed [7:0] Weight [K_MAX-1:0][ARRAY_SIZE-1:0];
    logic signed [7:0] Activation [M-1:0][K_MAX-1:0];
    logic signed [31:0] Golden [M-1:0][ARRAY_SIZE-1:0];

    function automatic logic signed [7:0] rand8();
        return $urandom_range(0, 40) - 20; // -20..20
    endfunction

    task automatic gen_test_data(input int K);
        for (int k = 0; k < K; k++)
            for (int c = 0; c < ARRAY_SIZE; c++)
                Weight[k][c] = rand8();
        for (int r = 0; r < M; r++)
            for (int k = 0; k < K; k++)
                Activation[r][k] = rand8();
    endtask

    task automatic compute_golden(input int K);
        logic signed [31:0] sum;
        for (int r = 0; r < M; r++) begin
            for (int c = 0; c < ARRAY_SIZE; c++) begin
                sum = 0;
                for (int k = 0; k < K; k++) sum += Activation[r][k] * Weight[k][c];
                Golden[r][c] = sum;
            end
        end
    endtask

    // ---- SRAM programming --------------------------------------------------
    // Whole weight matrix at once: K-tile t's 4x4 sub-block lives at
    // absolute addresses [t*4, t*4+3], exactly the stride LoopMatmul walks.
    task automatic load_weight_full(input int K);
        logic signed [7:0] lane [ARRAY_SIZE-1:0];
        send_write1(REG_MODE, 8'b0000_0011); // ena_wgt=1, wea_wgt=1
        for (int row = 0; row < K; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) lane[col] = Weight[row][col];
            send_addr(REG_ADDR_WGT_WT, row[9:0]);
            send_write4(REG_DIN_WGT, lane[3], lane[2], lane[1], lane[0]);
        end
        send_write1(REG_MODE, 8'b0000_0000);
    endtask

    // Every K-tile's M-row activation block, each at its own 4-row window.
    task automatic load_activation_full(input int K_TILES);
        logic signed [7:0] lane [ARRAY_SIZE-1:0];
        int addr;
        send_write1(REG_MODE, 8'b0000_1100); // ena_act=1, wea_act=1
        for (int kt = 0; kt < K_TILES; kt++) begin
            for (int row = 0; row < M; row++) begin
                for (int col = 0; col < ARRAY_SIZE; col++)
                    lane[col] = Activation[row][kt*ARRAY_SIZE+col];
                addr = kt*ARRAY_SIZE+row;
                send_addr(REG_ADDR_ACT_WT, addr[9:0]);
                send_write4(REG_DIN_ACT, lane[3], lane[2], lane[1], lane[0]);
            end
        end
        send_write1(REG_MODE, 8'b0000_0000);
    endtask

    // ---- one full hardware K-loop pass + result checking -------------------
    task automatic run_trial(input int K);
        int K_TILES;
        logic [7:0] rxb [0:16];
        logic signed [31:0] got;

        K_TILES = K / ARRAY_SIZE;

        gen_test_data(K);
        compute_golden(K);

        $display("-- trial K=%0d (K_TILES=%0d, M=%0d) --", K, K_TILES, M);

        load_weight_full(K);
        load_activation_full(K_TILES);

        send_addr(REG_BASE_WGT, 10'd0);
        send_addr(REG_BASE_ACT, 10'd0);
        send_write2(REG_NUM_ACT, 8'h00, M[7:0]);
        send_write1(REG_NUM_K_TILE, K_TILES[7:0]);
        // Top_Module now always routes LoopStart through N_LoopMatmul, which
        // wraps this K-loop in an outer N-tile loop; N_Num_Tile=1 makes it
        // finish after the single N-tile this K-only test exercises (0 would
        // underflow Num_N_Tile_REG-1 to 255 and phantom-loop the K-sweep).
        send_write1(REG_NUM_N_TILE, 8'h01);
        repeat (5) @(negedge clk);

        // single LoopStart pulse: LoopMatmul now drives Load_wgt/run/AddEna/
        // TileStart on its own across all K_TILES tiles.
        send_write1(REG_CTRL, 8'b0000_0001);
        repeat (150 + 80*K_TILES) @(negedge clk);

        for (int row = 0; row < M; row++) begin
            // pop_ena is edge-triggered: 0 -> 1 -> 0 for each pop.
            send_write1(REG_CTRL, 8'b0000_0010);
            repeat (10) @(negedge clk);
            send_write1(REG_CTRL, 8'b0000_0000);
            repeat (10) @(negedge clk);

            send_read(REG_RESULT);
            for (int i = 0; i < 17; i++) recv_byte(rxb[i]);

            for (int col = 0; col < ARRAY_SIZE; col++) begin
                got = {rxb[1+col*4+0], rxb[1+col*4+1], rxb[1+col*4+2], rxb[1+col*4+3]};
                if (got !== Golden[row][col]) begin
                    errors++;
                    $display("[FAIL] K=%0d row=%0d col=%0d got=%0d exp=%0d",
                              K, row, col, got, Golden[row][col]);
                end else begin
                    $display("[ OK ] K=%0d row=%0d col=%0d got=%0d exp=%0d",
                              K, row, col, got, Golden[row][col]);
                end
            end
        end
    endtask

    initial begin
        int K_LIST[NUM_TRIALS];

        $dumpfile("tb_LoopMatmul.vcd");
        $dumpvars(0, tb_LoopMatmul);

        K_LIST[0] = 4;
        K_LIST[1] = 8;
        K_LIST[2] = 12;

        clk = 0; rst_n = 0; rx = 1'b1;
        repeat (5) @(negedge clk);
        rst_n = 1;
        repeat (30) @(negedge clk);  // realistic idle-high settle before first byte

        for (int trial = 0; trial < NUM_TRIALS; trial++) run_trial(K_LIST[trial]);

        if (errors == 0) $display("TEST PASSED");
        else              $display("TEST FAILED (%0d mismatches)", errors);

        $finish;
    end

endmodule
