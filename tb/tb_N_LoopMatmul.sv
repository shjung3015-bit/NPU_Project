`timescale 1ns/1ps

// N_LoopMatmul (hardware N-tile loop, wrapping the K-tile loop) validation,
// driven purely over the UART command protocol through the Top_Module
// boundary (same interface the physical board exposes).
//
// Builds on tb_LoopMatmul.sv's single-N-tile K-loop test: here the full
// weight matrix spans N_Num_Tile*ARRAY_SIZE columns, stored as N_Num_Tile
// separate K x ARRAY_SIZE column-blocks laid out back-to-back in weight
// SRAM (block n at rows [n*K, n*K+K-1]) -- exactly the stride N_LoopMatmul
// walks between N-tiles (BaseAddr_wgt += K_Num_Tile*ARRAY_SIZE, see
// N_LoopMatmul.sv). The activation block is loaded once and reused for
// every N-tile (weight-stationary across N). A single REG_CTRL LoopStart
// pulse then lets N_LoopMatmul step through every N-tile, each running
// its own full K-tile sweep via K_LoopMatmul, and the M x ARRAY_SIZE
// result block per N-tile lands in Accumulator SRAM at rows
// [n*M, n*M+M-1] (Accumulator's N_TileBase_REG advances by Num_act per
// N-tile). Only after the whole N/K loop settles does the testbench pop
// all N_Num_Tile*M result rows back out in order.
//
// K_LoopMatmul now strides the activation base address per K-tile by
// Num_act (M) rather than a hardcoded ARRAY_SIZE -- matching exactly what
// Controller.sv actually reads (Offset_act walks 0..Num_act-1 per tile,
// see Controller.sv:26,91-93) -- so M is no longer required to equal
// ARRAY_SIZE. M is a per-trial argument here (see run_trial) and the
// trial list below deliberately covers M < ARRAY_SIZE, M == ARRAY_SIZE,
// and M > ARRAY_SIZE to exercise that generalization. K-multiple-of-
// ARRAY_SIZE still applies (that stride is a fixed 4, unrelated to M).

module tb_N_LoopMatmul;

    localparam int CLK_PERIOD   = 10;
    localparam int CLKS_PER_BIT = 234;
    localparam int BIT_PERIOD   = CLK_PERIOD * CLKS_PER_BIT;

    localparam int ARRAY_SIZE = 4;
    localparam int M_MAX      = 8; // upper bound on the per-trial M below
    localparam int K_MAX      = 8;
    localparam int N_TILE_MAX = 4;
    localparam int NUM_TRIALS = 7;

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

    // ---- host-side byte-level UART model (same as tb_LoopMatmul.sv) -----
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

    // ---- background tx listener (same as tb_LoopMatmul.sv) --------------
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

    // ---- test data ----------------------------------------------------
    // Weight[n][k][c]: N-tile n's K x ARRAY_SIZE column-block (true weight
    // column = n*ARRAY_SIZE+c). Activation is shared across every N-tile.
    logic signed [7:0] Weight [N_TILE_MAX-1:0][K_MAX-1:0][ARRAY_SIZE-1:0];
    logic signed [7:0] Activation [M_MAX-1:0][K_MAX-1:0];
    logic signed [31:0] Golden [N_TILE_MAX-1:0][M_MAX-1:0][ARRAY_SIZE-1:0];

    function automatic logic signed [7:0] rand8();
        return $urandom_range(0, 40) - 20; // -20..20
    endfunction

    task automatic gen_test_data(input int K, input int N_TILES, input int M);
        for (int n = 0; n < N_TILES; n++)
            for (int k = 0; k < K; k++)
                for (int c = 0; c < ARRAY_SIZE; c++)
                    Weight[n][k][c] = rand8();
        for (int r = 0; r < M; r++)
            for (int k = 0; k < K; k++)
                Activation[r][k] = rand8();
    endtask

    task automatic compute_golden(input int K, input int N_TILES, input int M);
        logic signed [31:0] sum;
        for (int n = 0; n < N_TILES; n++) begin
            for (int r = 0; r < M; r++) begin
                for (int c = 0; c < ARRAY_SIZE; c++) begin
                    sum = 0;
                    for (int k = 0; k < K; k++) sum += Activation[r][k] * Weight[n][k][c];
                    Golden[n][r][c] = sum;
                end
            end
        end
    endtask

    // ---- SRAM programming ----------------------------------------------
    // Every N-tile's full K x ARRAY_SIZE weight block, back-to-back:
    // N-tile n's block lives at absolute addresses [n*K, n*K+K-1], exactly
    // the stride N_LoopMatmul advances BaseAddr_wgt by between N-tiles.
    task automatic load_weight_full(input int K, input int N_TILES);
        logic signed [7:0] lane [ARRAY_SIZE-1:0];
        int addr;
        send_write1(REG_MODE, 8'b0000_0011); // ena_wgt=1, wea_wgt=1
        for (int n = 0; n < N_TILES; n++) begin
            for (int row = 0; row < K; row++) begin
                for (int col = 0; col < ARRAY_SIZE; col++) lane[col] = Weight[n][row][col];
                addr = n*K + row;
                send_addr(REG_ADDR_WGT_WT, addr[9:0]);
                send_write4(REG_DIN_WGT, lane[3], lane[2], lane[1], lane[0]);
            end
        end
        send_write1(REG_MODE, 8'b0000_0000);
    endtask

    // Every K-tile's M-row activation block, each at its own M-row window
    // -- loaded once and reused for every N-tile (weight-stationary).
    // Block kt lives at addresses [kt*M, kt*M+M-1], matching K_LoopMatmul's
    // BaseAddr_REG_act += Num_act stride between K-tiles (K_LoopMatmul.sv).
    task automatic load_activation_full(input int K_TILES, input int M);
        logic signed [7:0] lane [ARRAY_SIZE-1:0];
        int addr;
        send_write1(REG_MODE, 8'b0000_1100); // ena_act=1, wea_act=1
        for (int kt = 0; kt < K_TILES; kt++) begin
            for (int row = 0; row < M; row++) begin
                for (int col = 0; col < ARRAY_SIZE; col++)
                    lane[col] = Activation[row][kt*ARRAY_SIZE+col];
                addr = kt*M+row;
                send_addr(REG_ADDR_ACT_WT, addr[9:0]);
                send_write4(REG_DIN_ACT, lane[3], lane[2], lane[1], lane[0]);
            end
        end
        send_write1(REG_MODE, 8'b0000_0000);
    endtask

    // ---- one full hardware N/K-loop pass + result checking --------------
    task automatic run_trial(input int K, input int N_TILES, input int M);
        int K_TILES;
        logic [7:0] rxb [0:16];
        logic signed [31:0] got;

        K_TILES = K / ARRAY_SIZE;

        gen_test_data(K, N_TILES, M);
        compute_golden(K, N_TILES, M);

        $display("-- trial K=%0d N_TILES=%0d M=%0d (K_TILES=%0d) --", K, N_TILES, M, K_TILES);

        load_weight_full(K, N_TILES);
        load_activation_full(K_TILES, M);

        send_addr(REG_BASE_WGT, 10'd0);
        send_addr(REG_BASE_ACT, 10'd0);
        send_write2(REG_NUM_ACT, 8'h00, M[7:0]);
        send_write1(REG_NUM_K_TILE, K_TILES[7:0]);
        send_write1(REG_NUM_N_TILE, N_TILES[7:0]);
        repeat (5) @(negedge clk);

        // single LoopStart pulse: N_LoopMatmul now drives K_LoopMatmul
        // (which in turn drives Load_wgt/run/AddEna/TileStart) across
        // every N-tile's full K-tile sweep on its own.
        send_write1(REG_CTRL, 8'b0000_0001);
        repeat (300 + (M+60)*K_TILES*N_TILES) @(negedge clk);

        for (int n = 0; n < N_TILES; n++) begin
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
                    if (got !== Golden[n][row][col]) begin
                        errors++;
                        $display("[FAIL] K=%0d N_TILE=%0d row=%0d col=%0d got=%0d exp=%0d",
                                  K, n, row, col, got, Golden[n][row][col]);
                    end else begin
                        $display("[ OK ] K=%0d N_TILE=%0d row=%0d col=%0d got=%0d exp=%0d",
                                  K, n, row, col, got, Golden[n][row][col]);
                    end
                end
            end
        end
    endtask

    initial begin
        int K_LIST[NUM_TRIALS];
        int N_TILE_LIST[NUM_TRIALS];
        int M_LIST[NUM_TRIALS];

        $dumpfile("tb_N_LoopMatmul.vcd");
        $dumpvars(0, tb_N_LoopMatmul);

        // M == ARRAY_SIZE (4): same coverage as before the M generalization.
        K_LIST[0] = 4;  N_TILE_LIST[0] = 1;  M_LIST[0] = 4; // single N-tile, single K-tile (base case)
        K_LIST[1] = 4;  N_TILE_LIST[1] = 3;  M_LIST[1] = 4; // N-loop alone, K-loop degenerate
        K_LIST[2] = 8;  N_TILE_LIST[2] = 2;  M_LIST[2] = 4; // N-loop and K-loop both active
        K_LIST[3] = 8;  N_TILE_LIST[3] = 4;  M_LIST[3] = 4; // larger N sweep

        // M != ARRAY_SIZE: exercises K_LoopMatmul's Num_act-based activation
        // stride (K_LoopMatmul.sv) instead of the old hardcoded ARRAY_SIZE one.
        K_LIST[4] = 8;  N_TILE_LIST[4] = 2;  M_LIST[4] = 2; // M < ARRAY_SIZE
        K_LIST[5] = 8;  N_TILE_LIST[5] = 2;  M_LIST[5] = 6; // M > ARRAY_SIZE
        K_LIST[6] = 8;  N_TILE_LIST[6] = 3;  M_LIST[6] = 3; // M < ARRAY_SIZE, N-loop too

        clk = 0; rst_n = 0; rx = 1'b1;
        repeat (5) @(negedge clk);
        rst_n = 1;
        repeat (30) @(negedge clk);  // realistic idle-high settle before first byte

        for (int trial = 0; trial < NUM_TRIALS; trial++)
            run_trial(K_LIST[trial], N_TILE_LIST[trial], M_LIST[trial]);

        if (errors == 0) $display("TEST PASSED");
        else              $display("TEST FAILED (%0d mismatches)", errors);

        $finish;
    end

endmodule
