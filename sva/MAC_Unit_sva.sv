module MAC_Unit_sva(
    input  clk, rst_n,
    input  load_en,       
    input  in_valid,       
 
    input logic signed [7:0]  a_out,     
    input logic signed [7:0]  w_out,      
    input logic signed [31:0] psum_out,    
    input logic out_valid
);

    property MAC_Unit_Valid_Propagation;
        @(posedge clk) disable iff(!rst_n)
        in_valid |=> out_valid == $past(in_valid);
    endproperty
    assert property (MAC_Unit_Valid_Propagation)
    else $error("[MAC_Unit] MAC_Unit_Invalid_Propagation");

    property MAC_Unit_Output_Stability;
        @(posedge clk) disable iff(!rst_n)
        in_valid && !load_en |=> $stable(a_out) && $stable(w_out) && $stable(psum_out);
    endproperty
    assert property (MAC_Unit_Output_Stability)
    else $error("[MAC_Unit] MAC_Unit_Output_Unstable");

endmodule
