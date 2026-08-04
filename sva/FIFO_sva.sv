module FIFO_sva(
    input logic clk, rst_n, 
    input logic wea, rea,
    input logic ff_empty, ff_full,
    input logic [$clog2(8):0] wptr, rptr
);

    property fifo_empty_nor_full;
        @(posedge clk) disable iff(!rst_n)
        !(ff_empty && ff_full);
    endproperty
    assert property(fifo_empty_nor_full)
    else $error("FIFO cannot be empty and full at the same time");

    property fifo_no_write_when_full;
        @(posedge clk) disable iff(!rst_n)
        (wea && ff_full) |=> $stable(wptr);
    endproperty
    assert property(fifo_no_write_when_full)
    else $error("FIFO cannot write when full");

    property fifo_no_read_when_empty;
        @(posedge clk) disable iff(!rst_n)
        (rea && ff_empty) |=> $stable(rptr);
    endproperty
    assert property(fifo_no_read_when_empty)
    else $error("FIFO cannot read when empty");


endmodule
