module Controller(
    input logic clk, rst_n, run, Load_wgt,
    input logic [9:0] BaseAddr_wgt, BaseAddr_act,
    input logic [9:0] Num_act,
    input logic InjectEna,

    output logic Enb_wgt, Enb_act,
    output logic [9:0] Addr_wgt, Addr_act,
    output logic LoadEna, start
);

    localparam ARRAY_SIZE = 4;
    localparam ADDR_W = 10;

    parameter IDLE = 3'b001, LOAD_WGT = 3'b010, STREAM = 3'b100;

    logic [2:0] CurrentState, NextState;
    logic [$clog2(ARRAY_SIZE)-1:0] Offset_wgt;
    logic [ADDR_W-1:0] Offset_act;
    logic RunPrev, LoadPrev_wgt;
    logic RunPulse, LoadPulse_wgt;



    assign Enb_wgt = (CurrentState == LOAD_WGT);
    assign Enb_act = (CurrentState == STREAM) && InjectEna && (Offset_act < Num_act);
    assign Addr_wgt = BaseAddr_wgt + Offset_wgt;
    assign Addr_act = BaseAddr_act + Offset_act;

    assign RunPulse = run & ~RunPrev;
    assign LoadPulse_wgt = Load_wgt & ~LoadPrev_wgt;


    always_ff@(posedge clk) begin
        if(!rst_n) CurrentState <= IDLE;
        else CurrentState <= NextState;
    end

    always_comb begin
        case(CurrentState)
            IDLE: begin
                if(LoadPulse_wgt) NextState = LOAD_WGT;

                else if(RunPulse) NextState = STREAM;

                else NextState = IDLE;
            end
            LOAD_WGT: begin
                if(Offset_wgt == 2'b00) NextState = IDLE;
                else NextState = LOAD_WGT;
            end

            STREAM: begin
                if(Offset_act == Num_act) NextState = IDLE;
                else NextState = STREAM;
            end

            default: NextState = IDLE;

        endcase

    end


    always_ff@(posedge clk) begin
        if(!rst_n) begin
            LoadEna <= 0;
            start <= 0;

            Offset_wgt <= ARRAY_SIZE-1;
            Offset_act <= 0;
            RunPrev <= 1'b0;
            LoadPrev_wgt <= 1'b0;
        end

        else begin
            RunPrev <= run;
            LoadPrev_wgt <=Load_wgt;
            case(CurrentState)
                IDLE: begin
                    LoadEna <= 0;
                    Offset_wgt <= ARRAY_SIZE-1;
                    Offset_act <= 2'b00;
                end

                LOAD_WGT: begin
                    LoadEna <= 1;
                    Offset_wgt <= Offset_wgt - 1;
                end
                STREAM: begin
                    if(InjectEna && Offset_act < Num_act) begin
                        start <= 1;
                        Offset_act <= Offset_act + 1;
                    end
                    else begin
                        start <= 0;
                    end
                end
            endcase
        end
    end



endmodule


