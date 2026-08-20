module SRAM_sva(
    input logic clk, rst_n, enb,
    input logic [31:0] dout
);

    property SRAM_dout_timing;
        @(posedge clk) disable iff(!rst_n)
        enb |=> !$isunknown(dout);
    endproperty
    assert property(SRAM_dout_timing)
    else $error("[SRAM] dout timing violation at time %0t", $time);


    property SRAM_same_addr_collision;
        @(posedge clk) disable iff(!rst_n)
        !(ena && wea && enb && (AddrWt == AddrRd));
    endproperty
    assert property(SRAM_same_addr_collision)
    else $error("[SRAM] Write/Read same address collision");


endmodule
