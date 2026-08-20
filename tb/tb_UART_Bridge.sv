`timescale 1ns/1ps

module tb_UART_Bridge;

    localparam int CLK_PERIOD   = 10;
    localparam int CLKS_PER_BIT = 234;
    localparam int BIT_PERIOD   = CLK_PERIOD * CLKS_PER_BIT;

    logic clk, rst_n;
    logic rx, tx;
    logic signed [3:0][31:0] result;
    logic ResultValid;

    logic run, Load_wgt;
    logic Ena_act, Wea_act, Ena_wgt, Wea_wgt;
    logic [9:0] AddrWt_act, AddrWt_wgt;
    logic [9:0] BaseAddr_wgt, BaseAddr_act;
    logic [31:0] Din_wgt, Din_act;
    logic PopEna;
    logic [9:0] Num_act;
    logic BridgeBusy;

    int errors = 0;

    UART_Bridge DUT (
        .clk(clk), .rst_n(rst_n),
        .rx(rx), .tx(tx),
        .result(result), .ResultValid(ResultValid),

        .run(run), .Load_wgt(Load_wgt),
        .Ena_act(Ena_act), .Wea_act(Wea_act), .Ena_wgt(Ena_wgt), .Wea_wgt(Wea_wgt),
        .AddrWt_act(AddrWt_act), .AddrWt_wgt(AddrWt_wgt),
        .BaseAddr_wgt(BaseAddr_wgt), .BaseAddr_act(BaseAddr_act),
        .Din_wgt(Din_wgt), .Din_act(Din_act),
        .PopEna(PopEna), .Num_act(Num_act),
        .BridgeBusy(BridgeBusy)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        #5_000_000;
        $display("WATCHDOG TIMEOUT: state=%0d rx=%b tx=%b busy=%b cmd=%0h addr=%0h tx_ide=%0d",
                  DUT.CurrentState, rx, tx, DUT.busy, DUT.cmd, DUT.addr, DUT.TxIde);
        $finish;
    end

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

    // ---- background tx listener --------------------------------------
    // Runs continuously from t=0 so it can never "arrive late" relative to
    // the DUT starting a response (UART_RX latches a byte before its stop
    // bit even finishes, so the DUT can begin replying before a sequential
    // send_byte() call on the host side has even returned).
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

    task automatic check_read(input string label);
        logic [7:0] rxb [0:16];
        logic [7:0] exp [0:16];
        int local_errors;

        exp[0] = {7'b0, ResultValid};
        for (int i = 0; i < 4; i++) begin
            exp[1+i*4+0] = result[i][31:24];
            exp[1+i*4+1] = result[i][23:16];
            exp[1+i*4+2] = result[i][15:8];
            exp[1+i*4+3] = result[i][7:0];
        end

        for (int i = 0; i < 17; i++) recv_byte(rxb[i]);

        local_errors = 0;
        for (int i = 0; i < 17; i++) begin
            if (rxb[i] !== exp[i]) begin
                errors++;
                local_errors++;
                $display("[FAIL] %s byte[%0d] got=%02h exp=%02h", label, i, rxb[i], exp[i]);
            end
        end
        $display("[ %s ] %s readback (17 bytes)", (local_errors == 0) ? "OK  " : "FAIL", label);
    endtask

    initial begin
        $dumpfile("tb_UART_Bridge.vcd");
        $dumpvars(0, tb_UART_Bridge);

        clk = 0;
        rst_n = 0;
        rx = 1'b1;
        result = '0;
        ResultValid = 0;

        repeat (5) @(negedge clk);
        rst_n = 1;
        repeat (30) @(negedge clk);  // realistic idle-high settle before first byte

        // --- 1-byte write: addr 0x00 -> {run, Load_wgt, PopEna} ---
        send_write1(8'h00, 8'b0000_0101); // run=1, load_wgt=0, pop_ena=1
        repeat (5) @(negedge clk);
        if ({run, Load_wgt, PopEna} !== 3'b101) begin
            errors++;
            $display("[FAIL] addr 0x00 got run=%0b load_wgt=%0b pop_ena=%0b", run, Load_wgt, PopEna);
        end else $display("[ OK ] addr 0x00 control byte");

        // --- 1-byte write: addr 0x01 -> {Ena_act, Wea_act, Ena_wgt, Wea_wgt} ---
        send_write1(8'h01, 8'b0000_1010); // ena_act=1, wea_act=0, ena_wgt=1, wea_wgt=0
        repeat (5) @(negedge clk);
        if ({Ena_act, Wea_act, Ena_wgt, Wea_wgt} !== 4'b1010) begin
            errors++;
            $display("[FAIL] addr 0x01 got %b%b%b%b", Ena_act, Wea_act, Ena_wgt, Wea_wgt);
        end else $display("[ OK ] addr 0x01 control byte");

        // --- back-to-back 2-byte writes: regression test for byte_ide reset ---
        send_write2(8'h06, 8'h01, 8'h2C);   // num_act = 0x012C = 300
        repeat (5) @(negedge clk);
        send_write2(8'h02, 8'h01, 8'hAB);   // addr_act_wt = 0x01AB = 429
        repeat (5) @(negedge clk);
        if (Num_act !== 10'd300) begin
            errors++;
            $display("[FAIL] num_act got=%0d exp=300", Num_act);
        end else $display("[ OK ] num_act = %0d", Num_act);
        if (AddrWt_act !== 10'h1AB) begin
            errors++;
            $display("[FAIL] addr_act_wt got=%03h exp=1ab (checks byte_ide reset between writes)", AddrWt_act);
        end else $display("[ OK ] addr_act_wt = %03h (byte_ide reset between writes confirmed)", AddrWt_act);

        // --- 4-byte write ---
        send_write4(8'h07, 8'hDE, 8'hAD, 8'hBE, 8'hEF);
        repeat (5) @(negedge clk);
        if (Din_act !== 32'hDEADBEEF) begin
            errors++;
            $display("[FAIL] din_act got=%08h exp=deadbeef", Din_act);
        end else $display("[ OK ] din_act = %08h", Din_act);

        // --- READ addr 0x09, twice in a row: regression test for tx_ide reset ---
        ResultValid = 1;
        result[0] = 32'sh11111111;
        result[1] = 32'sh22222222;
        result[2] = 32'sh33333333;
        result[3] = 32'sh44444444;

        send_read(8'h09);
        check_read("read #1");
        repeat (5) @(negedge clk);

        ResultValid = 0;
        result[0] = 32'sh55555555;
        result[1] = 32'sh66666666;
        result[2] = 32'sh77777777;
        result[3] = 32'sh88888888;

        send_read(8'h09);
        check_read("read #2 (checks tx_ide reset between reads)");

        if (errors == 0) $display("TEST PASSED");
        else              $display("TEST FAILED (%0d mismatches)", errors);

        $finish;
    end

endmodule
