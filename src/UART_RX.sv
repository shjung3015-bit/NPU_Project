module UART_RX #(
    parameter CLKS_PER_BIT = 234
)(
    input logic clk, rst_n, rx,

    output logic [7:0] RxByte,
    output logic RxValid
);


    parameter IDLE = 4'b0001, START = 4'b0010, DATA = 4'b0100, STOP = 4'b1000;

    logic [3:0] NextState, CurrentState;
    logic [3:0] BitCounter;
    logic [7:0] StCounter, StrCounter, DaCounter;
    logic [7:0] ShiftReg;
    logic RxMeta, RxSync;
    logic [4:0] IdleHighCnt;
    localparam IDLE_CONFIRM = 16;

    always_ff@(posedge clk) begin
        if(!rst_n) CurrentState <= IDLE;
        else CurrentState <= NextState;
    end

    always_ff@(posedge clk) begin
        if(!rst_n) begin
            RxMeta <=1'b1;
            RxSync <=1'b1;
        end else begin
            RxMeta <= rx;
            RxSync <= RxMeta;
        end
    end

    always_ff@(posedge clk) begin
        if(!rst_n) IdleHighCnt <= 0;
        else if(RxSync) IdleHighCnt <= (IdleHighCnt == IDLE_CONFIRM) ? IdleHighCnt : IdleHighCnt + 1;
        else IdleHighCnt <= 0;
    end

    wire LineIdleConfirmed = (IdleHighCnt == IDLE_CONFIRM);



    always_comb begin

        case(CurrentState)

            IDLE: begin
                if(!RxSync && LineIdleConfirmed) NextState = START;
                else NextState = IDLE;
            end

            START: begin
                if(!RxSync) begin
                    if(StrCounter == CLKS_PER_BIT/2 - 1) NextState = DATA;
                    else NextState = START;
                end else begin
                    NextState = IDLE;
                end
            end

            DATA: begin
                if((BitCounter == 8)) NextState = STOP;
                else NextState = DATA;
            end

            STOP: begin
                if(RxSync) begin
                    if(StCounter == CLKS_PER_BIT-1) NextState = IDLE;
                    else NextState = STOP;
                end else begin
                    NextState = IDLE;
                end
            end

            default: NextState = IDLE;
        endcase

    end

    always_ff@(posedge clk) begin

        if(!rst_n) begin
            StCounter <=0;
            StrCounter <=0;
            BitCounter <=0;
            DaCounter <=0;
            ShiftReg <=0;
            RxByte <=0;
            RxValid<=0;
        end

        else begin
            RxValid <=0;

            case(CurrentState)

                IDLE: begin
                    StrCounter <=0;
                    DaCounter <=0;
                    StCounter <=0;
                    BitCounter <=0;
                end

                START: begin
                    StrCounter <= StrCounter + 1;
                end

                DATA: begin
                    if(BitCounter == 8) begin
                        RxByte <= ShiftReg;
                        RxValid <= 1;
                    end
                    else begin
                        if(DaCounter == CLKS_PER_BIT - 1) begin
                            DaCounter <= 0;
                            ShiftReg <= {RxSync, ShiftReg[7:1]};
                            BitCounter <= BitCounter + 1;
                        end
                        else DaCounter <=DaCounter +1;
                        end
                end

                STOP: begin
                    StCounter <= StCounter + 1;
                end
            endcase
        end
    end
endmodule
