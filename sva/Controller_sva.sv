module Controller_sva(
    input logic clk,
    input logic rst_n,
    input logic [2:0] current_state,
    input logic [7:0] num_act,
    input logic [7:0] act_offset
);

property act_offset_overflow;
    @(posedge clk) disable iff(!rst_n)
    act_offset <= num_act;
endproperty
assert property(act_offset_overflow)
else $error("[Controller] act_offset overflow");

property state_available;
    @(posedge clk) disable iff(!rst_n)
    $onehot(current_state);
endproperty
assert property(state_available)
else $error("[Controller] Invalid state");

endmodule
