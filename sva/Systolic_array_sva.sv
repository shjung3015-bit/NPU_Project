module Systolic_Array_sva(
    input logic clk, rst_n,

    input logic [1:0] current_state, next_state,
    input logic in_valid_array [4:0] [4:0],
    input logic signed [3:0][31:0] data_out,
    input logic [3:0] data_valid
);

    property Data_Valid_Propagation;
        @(posedge clk) disable iff(!rst_n)
        data_valid[k] |-> !$isunknown(data_out[k]);
    endproperty
    assert property (Data_Valid_Propagation)
    else $error("[Systolic_Array] Invalid_Data_Propagation");

    property Valid_Pipeline_Propagation;
        @(posedge clk) disable iff(!rst_n)
        in_valid_array[i][j] |-> in_valid_array[i][j+1];
    endproperty
    assert property (Valid_Pipeline_Propagation)
    else $error("[Systolic_Array] Invalid_Pipeline_Propagation");

endmodule
