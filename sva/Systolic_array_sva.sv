module Systolic_Array_sva(
    input logic clk, rst_n,

    input logic [1:0] CurrentState, NextState,
    input logic InValidArray [4:0] [4:0],
    input logic signed [3:0][31:0] DataOut,
    input logic [3:0] DataValid
);

    property Data_Valid_Propagation;
        @(posedge clk) disable iff(!rst_n)
        DataValid[k] |-> !$isunknown(DataOut[k]);
    endproperty
    assert property (Data_Valid_Propagation)
    else $error("[Systolic_Array] Invalid_Data_Propagation");

    property Valid_Pipeline_Propagation;
        @(posedge clk) disable iff(!rst_n)
        InValidArray[i][j] |-> InValidArray[i][j+1];
    endproperty
    assert property (Valid_Pipeline_Propagation)
    else $error("[Systolic_Array] Invalid_Pipeline_Propagation");

endmodule
