module MAC_Unit_sva(
    input  clk, rst_n,
    input  LoadEna,
    input  InValid,

    input logic signed [7:0]  AOut,
    input logic signed [7:0]  WOut,
    input logic signed [31:0] PsumOut,
    input logic OutValid
);

    property MAC_Unit_Valid_Propagation;
        @(posedge clk) disable iff(!rst_n)
        InValid |=> OutValid == $past(InValid);
    endproperty
    assert property (MAC_Unit_Valid_Propagation)
    else $error("[MAC_Unit] MAC_Unit_Invalid_Propagation");

    property MAC_Unit_Output_Stability;
        @(posedge clk) disable iff(!rst_n)
        InValid && !LoadEna |=> $stable(AOut) && $stable(WOut) && $stable(PsumOut);
    endproperty
    assert property (MAC_Unit_Output_Stability)
    else $error("[MAC_Unit] MAC_Unit_Output_Unstable");

endmodule
