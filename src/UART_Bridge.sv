module UART_Bridge(
    input logic clk, rst_n,
    input logic rx,
    input logic signed [3:0][31:0] result,
    input logic ResultValid,

    output logic tx,
    output logic run, Load_wgt,
    output logic Ena_act, Wea_act, Ena_wgt, Wea_wgt,
    output logic [9:0] AddrWt_act, AddrWt_wgt,
    output logic [9:0] BaseAddr_wgt, BaseAddr_act,
    output logic [31:0] Din_wgt, Din_act,
    output logic PopEna,
    output logic [9:0] Num_act,
    output logic BridgeBusy,
    output logic [4:0] dbg_state

);

    // Active-low so the LED for the *current* state lights up (Tang Nano 9K
    // LEDs are wired to the 1.8V bank and light when driven low).
    assign dbg_state = ~CurrentState;

    parameter WAIT_CMD= 5'b00001, WAIT_ADDR = 5'b00010, WAIT_DATA = 5'b00100, COMMIT = 5'b01000, SEND = 5'b10000;
    parameter WRITE = 1'b0, READ = 1'b1;

    localparam NUM_LANES      = 4;
    localparam RESULT_BYTES   = 1 + NUM_LANES*4;
    localparam MAX_WRITE_BYTES = 4;

    localparam REG_CTRL        = 8'h00; // {run, Load_wgt, PopEna}
    localparam REG_MODE        = 8'h01; // {Ena_act, Wea_act, Ena_wgt, Wea_wgt}
    localparam REG_ADDR_ACT_WT = 8'h02;
    localparam REG_ADDR_WGT_WT = 8'h03;
    localparam REG_BASE_ACT    = 8'h04;
    localparam REG_BASE_WGT    = 8'h05;
    localparam REG_NUM_ACT     = 8'h06;
    localparam REG_DIN_ACT     = 8'h07;
    localparam REG_DIN_WGT     = 8'h08;
    localparam REG_RESULT      = 8'h09;

    logic [7:0] TxData;
    logic TxTrigger;
    logic [4:0] CurrentState, NextState;
    logic [7:0] cmd, addr;
    logic [4:0] ByteRemain;
    logic [1:0] ByteIde;
    logic [7:0] TempBuf [MAX_WRITE_BYTES-1:0];
    logic [7:0] TxPayload [0:RESULT_BYTES-1];
    logic [4:0] TxIde;
    logic SentStarted, TxBusySeen, RxValid, busy;
    logic [7:0] RxByte;


    assign TxData = TxPayload[TxIde];
    assign TxTrigger = (CurrentState == SEND) && !SentStarted;
    assign BridgeBusy = (CurrentState != WAIT_CMD);

    UART_RX  U_rx(
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),

        .RxByte(RxByte),
        .RxValid(RxValid)
    );

    UART_TX U_tx(
        .clk(clk),
        .rst_n(rst_n),
        .TxData(TxData),
        .trigger(TxTrigger),

        .busy(busy),
        .tx(tx)
    );


always_ff@(posedge clk) begin
    if(!rst_n) CurrentState <= WAIT_CMD;
    else CurrentState <= NextState;
end

always_ff@(posedge clk) begin
    if(!rst_n) begin
        cmd <= 0;
        addr <= 0;
        ByteRemain <= 0;
        TempBuf[0] <= 0;
        TempBuf[1] <= 0;
        TempBuf[2] <= 0;
        TempBuf[3] <= 0;
        TxIde <= 0;
        SentStarted <= 0;
        TxBusySeen <= 0;

        {run, Load_wgt, PopEna} <= 0;
        {Ena_act, Wea_act, Ena_wgt, Wea_wgt} <= 0;
        AddrWt_act <= 0;
        AddrWt_wgt <= 0;
        BaseAddr_act <= 0;
        BaseAddr_wgt <= 0;
        Num_act <= 0;
        Din_act <= 0;
        Din_wgt <= 0;

    end
    else begin
        case (CurrentState)
            WAIT_CMD: begin
                if(RxValid) begin
                    cmd <= RxByte;
                end
            end

            WAIT_ADDR: begin
                if(RxValid) begin
                    addr <= RxByte;
                    ByteIde <= 0;
                    case(RxByte)
                        REG_CTRL:        ByteRemain <= 1;
                        REG_MODE:        ByteRemain <= 1;
                        REG_ADDR_ACT_WT: ByteRemain <= 2;
                        REG_ADDR_WGT_WT: ByteRemain <= 2;
                        REG_BASE_ACT:    ByteRemain <= 2;
                        REG_BASE_WGT:    ByteRemain <= 2;
                        REG_NUM_ACT:     ByteRemain <= 2;
                        REG_DIN_ACT:     ByteRemain <= MAX_WRITE_BYTES;
                        REG_DIN_WGT:     ByteRemain <= MAX_WRITE_BYTES;
                        REG_RESULT:      ByteRemain <= RESULT_BYTES;
                    endcase
                end
            end

            WAIT_DATA: begin
                if(RxValid) begin
                    TempBuf[ByteIde] <= RxByte;
                    ByteIde <= ByteIde + 1;
                    ByteRemain <= ByteRemain - 1;
                end

            end

            COMMIT: begin
                if(cmd == WRITE) begin
                    case (addr)
                        REG_CTRL:        {run, Load_wgt, PopEna} <= TempBuf[0][2:0];
                        REG_MODE:        {Ena_act, Wea_act, Ena_wgt, Wea_wgt} <= TempBuf[0][3:0];
                        REG_ADDR_ACT_WT: AddrWt_act <= {TempBuf[0], TempBuf[1]};
                        REG_ADDR_WGT_WT: AddrWt_wgt <= {TempBuf[0], TempBuf[1]};
                        REG_BASE_ACT:    BaseAddr_act <= {TempBuf[0], TempBuf[1]};
                        REG_BASE_WGT:    BaseAddr_wgt <= {TempBuf[0], TempBuf[1]};
                        REG_NUM_ACT:     Num_act <= {TempBuf[0], TempBuf[1]};
                        REG_DIN_ACT:     Din_act <= {TempBuf[0], TempBuf[1], TempBuf[2], TempBuf[3]};
                        REG_DIN_WGT:     Din_wgt <= {TempBuf[0], TempBuf[1], TempBuf[2], TempBuf[3]};
                        default : ;
                    endcase
                end
                else if (cmd == READ) TxIde <= 0;
            end

            SEND: begin
                if(TxTrigger) begin
                    SentStarted <= 1;
                    TxBusySeen <= 0;
                end
                else if (SentStarted) begin
                    if (busy) TxBusySeen <= 1;
                    else if (TxBusySeen) begin
                        SentStarted <= 0;
                        TxIde <= TxIde + 1;
                    end
                end
            end

        endcase
    end
end

    always_comb begin
        TxPayload [0] = {7'b0, ResultValid};
        for(int i=0; i<NUM_LANES; i++)begin
            TxPayload[1+i*4 + 0] = result[i][31:24];
            TxPayload[1+i*4 + 1] = result[i][23:16];
            TxPayload[1+i*4 + 2] = result[i][15:8];
            TxPayload[1+i*4 + 3] = result[i][7:0];
        end
    end


    always_comb begin

        case(CurrentState)
            WAIT_CMD: begin
                if(RxValid) NextState = WAIT_ADDR;
                else NextState = WAIT_CMD;
            end

            WAIT_ADDR: begin
                if(RxValid) begin
                    if(cmd == WRITE) NextState = WAIT_DATA;
                    else if(cmd == READ) NextState = COMMIT;
                    else NextState = WAIT_ADDR;
                end
                else NextState = WAIT_ADDR;
            end

            WAIT_DATA: begin
                if((RxValid)&&(ByteRemain == 1)) NextState = COMMIT;
                else NextState = WAIT_DATA;

            end

            COMMIT: begin
                if(cmd == WRITE )NextState = WAIT_CMD;
                else if(cmd == READ) NextState = SEND;
                else NextState = WAIT_CMD;
            end

            SEND: begin
                if(TxIde < RESULT_BYTES-1) NextState = SEND;
                else if(SentStarted && TxBusySeen && !busy) NextState = WAIT_CMD;
                else NextState = SEND;
            end

            default: NextState = WAIT_CMD;

        endcase

    end

endmodule
