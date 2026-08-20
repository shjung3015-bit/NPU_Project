`timescale 1ns/1ps

module tb_FIFO;

    localparam int CLK_PERIOD = 10;

    logic clk, rst_n;
    logic wea, rea;
    logic [31:0] DIn;
    logic FfEmpty, FfFull;
    logic [31:0] DOut;

    FIFO DUT (
        .clk      (clk),
        .rst_n    (rst_n),
        .wea      (wea),
        .rea      (rea),
        .DIn      (DIn),
        .FfEmpty  (FfEmpty),
        .FfFull   (FfFull),
        .DOut     (DOut)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        clk   = 0;
        rst_n = 0;
        wea   = 0;
        rea   = 0;
        DIn   = 0;

        repeat (2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // Fill the 8-deep FIFO, then keep writing while full to exercise
        // p_no_write_when_full (WrPtr must stay stable while FfFull).
        for (int i = 0; i < 10; i++) begin
            wea  = 1;
            DIn = i;
            @(posedge clk);
        end
        wea = 0;

        // Drain it, then keep reading while empty to exercise
        // p_no_read_when_empty (RdPtr must stay stable while FfEmpty).
        for (int i = 0; i < 10; i++) begin
            rea = 1;
            @(posedge clk);
        end
        rea = 0;

        repeat (2) @(posedge clk);
        $display("tb_FIFO: done, no assertion failures above means PASS");
        $finish;
    end

endmodule
