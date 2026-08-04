module FIFO_All_sva(
    input logic clk, rst_n,
    input logic [$clog2(8):0] counter,
    input logic pop_fire,
    input logic output_valid
);

    property FIFO_counter_violation;
        @(posedge clk) disable iff(!rst_n)
        (counter <= 8);
    endproperty
    assert property(FIFO_counter_violation)
    else $error("[FIFO] counter violation at time %0t", $time);

    property FIFO_output_valid_timing_violation;
        @(posedge clk) disable iff(!rst_n)
        pop_fire |=> output_valid;
    endproperty
    assert property(FIFO_output_valid_timing_violation)
    else $error("[FIFO] output_valid timing violation at time %0t", $time);

endmodule
