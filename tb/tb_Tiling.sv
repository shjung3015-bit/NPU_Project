`timescale 1ns/1ps

// Stage 2 - GEMM tiling validation against the real RTL (Controller /
// UART_Bridge / SRAM addressing), driven purely over the UART command
// protocol through the Top_Module boundary (same interface the physical
// board exposes).
//
// The physical array only computes a <=4x4 (K x N) sub-tile per pass, so a
// K=8 x N=12 weight matrix is split into ceil(K/4)=2 x ceil(N/4)=3 = 6
// sub-tiles. For each sub-tile this loads the weight sub-block and the
// activation's matching K-slice into SRAM, pulses load_wgt then run
// (a single run pulse streams all M activation rows automatically), and
// pops+reads back each of the M result rows. This is the first testbench
// to (a) reconfigure the weight SRAM with a new tile back-to-back more
// than once, and (b) pop more than one result per run -- both previously
// unexercised paths (every prior testbench used num_act=1 and a single
// weight load).
//
// Traversal order matches host/tiling_algorithm_test.py: outer loop over
// N-tiles, inner loop over K-tiles. All 6 raw per-tile M x <=4 results are
// collected first, then assembled in a separate pass (sum across K-tiles
// within an N-tile, concatenate across N-tiles) and compared against an
// SV-side int32-accumulated golden matmul.

module tb_Tiling;

    localparam int CLK_PERIOD   = 10;
    localparam int CLKS_PER_BIT = 234;
    localparam int BIT_PERIOD   = CLK_PERIOD * CLKS_PER_BIT;

    localparam int ARRAY_SIZE = 4;
    localparam int K = 8;
    localparam int N = 12;
    localparam int K_TILES = (K + ARRAY_SIZE - 1) / ARRAY_SIZE;
    localparam int N_TILES = (N + ARRAY_SIZE - 1) / ARRAY_SIZE;
    localparam int MAX_M = 10;

    // register map (mirrors src/UART_Bridge.sv's REG_* localparams)
    localparam logic [7:0] REG_CTRL        = 8'h00; // {run, load_wgt, pop_ena}
    localparam logic [7:0] REG_MODE        = 8'h01; // {ena_act, wea_act, ena_wgt, wea_wgt}
    localparam logic [7:0] REG_ADDR_ACT_WT = 8'h02;
    localparam logic [7:0] REG_ADDR_WGT_WT = 8'h03;
    localparam logic [7:0] REG_BASE_ACT    = 8'h04;
    localparam logic [7:0] REG_BASE_WGT    = 8'h05;
    localparam logic [7:0] REG_NUM_ACT     = 8'h06;
    localparam logic [7:0] REG_DIN_ACT     = 8'h07;
    localparam logic [7:0] REG_DIN_WGT     = 8'h08;
    localparam logic [7:0] REG_RESULT      = 8'h09;

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

    // ---- host-side byte-level UART model (same as tb_UART_Bridge.sv) ----
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

    // 10-bit address register split into 2 bytes; zero-extending the high
    // byte is enough since the DUT only keeps the low 10 bits.
    task automatic send_addr(input logic [7:0] reg_id, input logic [9:0] val);
        send_write2(reg_id, {6'b0, val[9:8]}, val[7:0]);
    endtask

    // ---- background tx listener (same as tb_UART_Bridge.sv) ------------
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

    // ---- test data -------------------------------------------------------
    logic signed [7:0] Weight [K-1:0][N-1:0];
    logic signed [7:0] Activation [MAX_M-1:0][K-1:0];
    logic signed [31:0] Golden [MAX_M-1:0][N-1:0];
    logic signed [31:0] RawResult [K_TILES-1:0][N_TILES-1:0][MAX_M-1:0][ARRAY_SIZE-1:0];

    int M;

    function automatic logic signed [7:0] rand8();
        logic [7:0] u;
        u = $urandom_range(0, 255);
        return u;
    endfunction

    task automatic gen_test_data();
        M = $urandom_range(1, 10);
        for (int r = 0; r < K; r++)
            for (int c = 0; c < N; c++)
                Weight[r][c] = rand8();
        for (int r = 0; r < M; r++)
            for (int c = 0; c < K; c++)
                Activation[r][c] = rand8();
    endtask

    task automatic compute_golden();
        logic signed [31:0] sum;
        for (int r = 0; r < M; r++) begin
            for (int c = 0; c < N; c++) begin
                sum = 0;
                for (int k = 0; k < K; k++) sum += Activation[r][k] * Weight[k][c];
                Golden[r][c] = sum;
            end
        end
    endtask

    // ---- one (k_tile, n_tile) hardware pass ------------------------------
    task automatic load_weight_tile(input int k_tile, input int n_tile);
        int ksub, nsub;
        logic signed [7:0] lane [ARRAY_SIZE-1:0];
        ksub = (k_tile == K_TILES-1) ? (K - k_tile*ARRAY_SIZE) : ARRAY_SIZE;
        nsub = (n_tile == N_TILES-1) ? (N - n_tile*ARRAY_SIZE) : ARRAY_SIZE;

        send_write1(REG_MODE, 8'b0000_0011); // ena_wgt=1, wea_wgt=1
        for (int row = 0; row < ksub; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++)
                lane[col] = (col < nsub) ? Weight[k_tile*ARRAY_SIZE+row][n_tile*ARRAY_SIZE+col] : 8'sd0;
            send_addr(REG_ADDR_WGT_WT, row[9:0]);
            send_write4(REG_DIN_WGT, lane[3], lane[2], lane[1], lane[0]);
        end
        send_write1(REG_MODE, 8'b0000_0000);
    endtask

    task automatic load_activation_tile(input int k_tile);
        int ksub;
        logic signed [7:0] lane [ARRAY_SIZE-1:0];
        ksub = (k_tile == K_TILES-1) ? (K - k_tile*ARRAY_SIZE) : ARRAY_SIZE;

        send_write1(REG_MODE, 8'b0000_1100); // ena_act=1, wea_act=1
        for (int row = 0; row < M; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++)
                lane[col] = (col < ksub) ? Activation[row][k_tile*ARRAY_SIZE+col] : 8'sd0;
            send_addr(REG_ADDR_ACT_WT, row[9:0]);
            send_write4(REG_DIN_ACT, lane[3], lane[2], lane[1], lane[0]);
        end
        send_write1(REG_MODE, 8'b0000_0000);
    endtask

    task automatic run_tile_and_collect(input int k_tile, input int n_tile);
        logic [7:0] rxb [0:16];

        send_addr(REG_BASE_WGT, 10'd0);
        send_addr(REG_BASE_ACT, 10'd0);
        send_write2(REG_NUM_ACT, 8'h00, M[7:0]);

        // pulse load_wgt (next full REG_CTRL write below clears it again)
        send_write1(REG_CTRL, 8'b0000_0010);
        repeat (20) @(negedge clk);

        // pulse run -- a single pulse streams all M activation rows
        send_write1(REG_CTRL, 8'b0000_0100);
        repeat (30) @(negedge clk);

        for (int row = 0; row < M; row++) begin
            // pop_ena is edge-triggered: must go 0 -> 1 -> 0 for EACH pop,
            // unlike every previous testbench which only ever popped once.
            send_write1(REG_CTRL, 8'b0000_0001);
            repeat (10) @(negedge clk);
            send_write1(REG_CTRL, 8'b0000_0000);
            repeat (10) @(negedge clk);

            send_read(REG_RESULT);
            for (int i = 0; i < 17; i++) recv_byte(rxb[i]);

            for (int col = 0; col < ARRAY_SIZE; col++) begin
                RawResult[k_tile][n_tile][row][col] =
                    {rxb[1+col*4+0], rxb[1+col*4+1], rxb[1+col*4+2], rxb[1+col*4+3]};
            end
        end
    endtask

    // ---- assembly (sum across K-tiles, concat across N-tiles) + compare -
    task automatic assemble_and_check();
        logic signed [31:0] assembled [MAX_M-1:0][N-1:0];
        logic signed [31:0] acc;
        int nsub;

        for (int n_tile = 0; n_tile < N_TILES; n_tile++) begin
            nsub = (n_tile == N_TILES-1) ? (N - n_tile*ARRAY_SIZE) : ARRAY_SIZE;
            for (int row = 0; row < M; row++) begin
                for (int col = 0; col < nsub; col++) begin
                    acc = 0;
                    for (int k_tile = 0; k_tile < K_TILES; k_tile++)
                        acc += RawResult[k_tile][n_tile][row][col];
                    assembled[row][n_tile*ARRAY_SIZE+col] = acc;
                end
            end
        end

        for (int row = 0; row < M; row++) begin
            for (int col = 0; col < N; col++) begin
                if (assembled[row][col] !== Golden[row][col]) begin
                    errors++;
                    $display("[FAIL] (row=%0d, col=%0d) got=%0d exp=%0d",
                              row, col, assembled[row][col], Golden[row][col]);
                end
            end
        end
    endtask

    initial begin
        $dumpfile("tb_Tiling.vcd");
        $dumpvars(0, tb_Tiling);

        clk = 0; rst_n = 0; rx = 1'b1;
        repeat (5) @(negedge clk);
        rst_n = 1;
        repeat (30) @(negedge clk);  // realistic idle-high settle before first byte

        gen_test_data();
        compute_golden();

        $display("Stage 2: M=%0d K=%0d N=%0d K_TILES=%0d N_TILES=%0d",
                  M, K, N, K_TILES, N_TILES);

        for (int n_tile = 0; n_tile < N_TILES; n_tile++) begin
            for (int k_tile = 0; k_tile < K_TILES; k_tile++) begin
                $display("-- loading/running (k_tile=%0d, n_tile=%0d) --", k_tile, n_tile);
                load_weight_tile(k_tile, n_tile);
                load_activation_tile(k_tile);
                run_tile_and_collect(k_tile, n_tile);
            end
        end

        assemble_and_check();

        if (errors == 0) $display("TEST PASSED");
        else              $display("TEST FAILED (%0d mismatches)", errors);

        $finish;
    end

endmodule
