`timescale 1ns/1ps

module tb_FIFO;

    localparam int CLK_PERIOD = 10;

    logic clk, rst_n;
    logic wea, rea;
    logic [31:0] d_in;
    logic ff_empty, ff_full;
    logic [31:0] d_out;

    FIFO DUT (
        .clk      (clk),
        .rst_n    (rst_n),
        .wea      (wea),
        .rea      (rea),
        .d_in     (d_in),
        .ff_empty (ff_empty),
        .ff_full  (ff_full),
        .d_out    (d_out)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        clk   = 0;
        rst_n = 0;
        wea   = 0;
        rea   = 0;
        d_in  = 0;

        repeat (2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // Fill the 8-deep FIFO, then keep writing while full to exercise
        // p_no_write_when_full (wr_ptr must stay stable while ff_full).
        for (int i = 0; i < 10; i++) begin
            wea  = 1;
            d_in = i;
            @(posedge clk);
        end
        wea = 0;

        // Drain it, then keep reading while empty to exercise
        // p_no_read_when_empty (rd_ptr must stay stable while ff_empty).
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
