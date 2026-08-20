module Controller_sva(
    input logic clk,
    input logic rst_n,
    input logic [2:0] CurrentState, NextState,
    input logic [7:0] Num_act,
    input logic [7:0] Offset_act
);


    parameter IDLE = 3'b001, LOAD_WGT = 3'b010, STREAM = 3'b100;

    property act_offset_overflow;
        @(posedge clk) disable iff(!rst_n)
        Offset_act <= Num_act;
    endproperty
    assert property(act_offset_overflow)
    else $error("[Controller] act_offset overflow");

    property state_available;
        @(posedge clk) disable iff(!rst_n)
        $onehot(CurrentState);
    endproperty
    assert property(state_available)
    else $error("[Controller] Invalid state");

    property STREAM_LOAD_STATE_VIOLATION;
        @(posedge clk) disable iff(!rst_n)
        if (CurrentState == STREAM) begin
            NextState != LOAD_WGT;
        end
        else if(CurrentState == LOAD_WGT) begin
            NextState != STREAM;
        end
    endproperty
    assert property (STREAM_LOAD_STATE_VIOLATION)
    else $error("[Controller] STREAM_LOAD_STATE_VIOLATION");

endmodule
