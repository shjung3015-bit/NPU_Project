module K_LoopMatmul (
    input clk, rst_n,
    input logic LoopStart,
    input logic [7:0] K_Num_Tile,
    input logic WriteCommit,
    input logic [9:0] Num_act,
    input logic [9:0] BaseAddr_wgt_in,
    input logic [9:0] BaseAddr_act_in,

    output logic run, Load_wgt,
    output logic [9:0] BaseAddr_wgt,
    output logic [9:0] BaseAddr_act,
    output logic AddEna,
    output logic TileStart,
    output logic K_LoopActive

);

    parameter IDLE=4'b0001, LOAD_WGT=4'b0010, LOAD_ACT=4'b0100, DONE=4'b1000;

    logic [3:0] CurrentState, NextState;
    logic [2:0] LoadWgtCounter;
    logic [9:0] WriteCommitCounter;
    logic [7:0] K_TileCounter;
    logic [9:0] BaseAddr_REG_wgt;
    logic [9:0] BaseAddr_REG_act;
    logic [7:0] K_Num_Tile_REG;
    logic LoopStartEdge, LoopStartPrev;


    assign LoopStartEdge = LoopStart && !LoopStartPrev;
    assign K_LoopActive = (CurrentState == LOAD_WGT) || (CurrentState == LOAD_ACT);

    always_ff@(posedge clk) begin
        if(!rst_n) begin
            LoopStartPrev <= 0;
        end
        else begin
            LoopStartPrev <= LoopStart;
        end
    end


    always_ff@(posedge clk)begin
        if(!rst_n) CurrentState <= IDLE;
        else CurrentState <= NextState;
    end

    always_comb begin
        case(CurrentState)
            IDLE: begin
                if(LoopStartEdge) NextState = LOAD_WGT;
                else NextState = IDLE;
            end

            LOAD_WGT: begin
                if(LoadWgtCounter == 4) NextState = LOAD_ACT;
                else NextState = LOAD_WGT;
            end

            LOAD_ACT: begin
                if(WriteCommitCounter == Num_act)begin
                    if(K_TileCounter == K_Num_Tile_REG -1) NextState = DONE;
                    else NextState = LOAD_WGT;
                end
                else NextState = LOAD_ACT;
            end

            DONE: NextState = IDLE;

            default: NextState = IDLE;
        endcase
    end

    always_ff@(posedge clk) begin
        if(!rst_n) begin
            LoadWgtCounter <= 0;
        end
        else begin

            if(CurrentState == LOAD_WGT) LoadWgtCounter <= LoadWgtCounter + 1;
            else LoadWgtCounter <= 0;
        end
    end

    always_ff@(posedge clk) begin
        if(!rst_n) begin 
            WriteCommitCounter <= 0;
        end
        else if(CurrentState != LOAD_ACT) WriteCommitCounter <= 0;
        else if(WriteCommit) WriteCommitCounter <= WriteCommitCounter + 1;
    end

    always_ff@(posedge clk) begin
        if(!rst_n) begin
            K_TileCounter <= 0;
            BaseAddr_REG_wgt <= 0;
            BaseAddr_REG_act <= 0;
        end
        else if(LoopStartEdge) begin 
            K_TileCounter <= 0;
            BaseAddr_REG_wgt <= BaseAddr_wgt_in;
            BaseAddr_REG_act <= BaseAddr_act_in;
        end
        else begin
            if(CurrentState == LOAD_ACT && WriteCommitCounter == Num_act) begin
                if(K_TileCounter == K_Num_Tile_REG - 1 ) K_TileCounter <=0;
                else begin
                    K_TileCounter <= K_TileCounter + 1;
                    BaseAddr_REG_wgt <= BaseAddr_REG_wgt + 4;
                    BaseAddr_REG_act <= BaseAddr_REG_act + Num_act;
                end
            end
        end
    end


    always_ff@(posedge clk)begin

        if(!rst_n) begin
            run <=0;
            Load_wgt<=0;
            TileStart <=0;
            BaseAddr_wgt <= 0;
            BaseAddr_act <= 0;
        end

        else begin 
            run <= 0;
            Load_wgt<=0;
            TileStart <= 0;
            case(CurrentState)
                IDLE: begin 
                    if(LoopStartEdge) begin
                        K_Num_Tile_REG <= K_Num_Tile;
                    end
                end 

                LOAD_WGT: begin 
                    Load_wgt <= 1;
                    BaseAddr_wgt <= BaseAddr_REG_wgt;
                end

                LOAD_ACT: begin
                    TileStart <= 1;
                    run <= 1;
                    BaseAddr_act <= BaseAddr_REG_act;
                    AddEna <= (K_TileCounter == 0) ? 0 : 1;
                end
            endcase

        end

    end

endmodule
