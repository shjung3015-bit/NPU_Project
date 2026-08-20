module UART_TX#(
    parameter CLKS_PER_BIT = 234
)(
    input logic clk, rst_n,
    input logic [7:0] TxData,
    input logic trigger,

    output logic busy,
    output logic tx

);
    parameter IDLE = 4'b0001, START = 4'b0010, DATA = 4'b0100, STOP = 4'b1000;

    logic [3:0] CurrentState, NextState;
    logic [7:0] StrCounter, StCounter, DaCounter;
    logic [3:0] BitCounter;
    logic [7:0] ShiftReg;

    always_ff@(posedge clk) begin
        if(!rst_n) CurrentState <= IDLE;
        else CurrentState <= NextState;
    end

    always_comb begin

        case(CurrentState)
            IDLE: begin
                if(trigger) NextState = START;
                else NextState = IDLE;
            end

            START: begin
                if(StrCounter == CLKS_PER_BIT - 1) NextState = DATA;
                else NextState = START;
            end

            DATA: begin
                if(BitCounter == 8) NextState = STOP;
                else NextState = DATA;
            end

            STOP: begin
                if(StCounter == CLKS_PER_BIT - 1) NextState = IDLE;
                else NextState = STOP;
            end

            default: NextState = IDLE;
        endcase
    end

    always_ff@(posedge clk)begin
        if(!rst_n)begin
            busy <= 0;
            tx <= 0;
            StrCounter <= 0;
            StCounter <= 0;
            BitCounter <= 0;
            DaCounter <= 0;
        end

        else begin
            busy <= 0;

            case(CurrentState)
                IDLE: begin
                    tx <= 1;
                    StrCounter <= 0;
                    StCounter <= 0;
                    BitCounter <=0;
                    DaCounter <=0;
                    if(trigger == 1) ShiftReg <= TxData;
                end

                START: begin
                    tx <= 0;
                    busy <= 1;
                    StrCounter <= StrCounter + 1;
                end

                DATA: begin
                    busy <= 1;
                    if(BitCounter != 8) begin
                        tx <= ShiftReg[0];
                        if(DaCounter == CLKS_PER_BIT - 1) begin
                            DaCounter <= 0;
                            BitCounter <= BitCounter + 1;
                            ShiftReg <= {1'b0, ShiftReg[7 : 1]};
                        end
                        else DaCounter <= DaCounter + 1;
                    end
                end

                STOP: begin
                    busy <= 1;
                    tx <= 1;
                    StCounter <= StCounter + 1;
                end
            endcase
        end
    end

endmodule
