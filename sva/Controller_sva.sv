module Controller_sva(
    input logic clk,
    input logic rst_n,
    input logic [2:0] current_state, next_state,
    input logic [7:0] num_act,
    input logic [7:0] act_offset
);


    parameter IDLE = 3'b001, LOAD_wgt = 3'b010, STREAM = 3'b100;

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

    property STREAM_LOAD_STATE_VIOLATION;
        @(posedge clk) disable iff(!rst_n)
        if (current_state == STREAM) begin
            next_state != LOAD_wgt;
        end
        else if(current_state == LOAD_wgt) begin
            next_state != STREAM;
        end
    endproperty
    assert property (STREAM_LOAD_STATE_VIOLATION)
    else $error("[Controller] STREAM_LOAD_STATE_VIOLATION");

endmodule
