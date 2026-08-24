module LoopMatmul (
    input clk, rst_n,
    input logic LoopStart,
    input logic [7:0] Num_K_Tile,
    input logic WriteCommit,
    input logic [9:0] Num_act,
    input logic [9:0] BaseAddr_wgt_in,
    input logic [9:0] BaseAddr_act_in,

    output logic run, Load_wgt,
    output logic [9:0] BaseAddr_wgt,
    output logic [9:0] BaseAddr_act,
    output logic AddEna,
    output logic TileStart,
    output logic LoopActive

);

    parameter IDLE=4'b0001, LOAD_WGT=4'b0010, LOAD_ACT=4'b0100, DONE=4'b1000;

    logic [3:0] CurrentState, NextState;
    logic [2:0] LoadWgtCounter;
    logic [9:0] WriteCommitCounter;
    logic [7:0] K_TileCounter;
    logic [9:0] BaseAddr_REG_wgt;
    logic [9:0] BaseAddr_REG_act;
    logic [7:0] Num_K_Tile_REG;
    logic LoopStartEdge, LoopStartPrev;


    assign LoopStartEdge = LoopStart && !LoopStartPrev;
    assign LoopActive = (CurrentState == LOAD_WGT) || (CurrentState == LOAD_ACT);

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
                // Controller's LoadPulse_wgt = Load_wgt & ~LoadPrev_wgt needs one
                // cycle to register Load_wgt before Controller itself enters (and
                // later leaves) its own 4-cycle LOAD_WGT countdown, so Controller
                // trails this state by one cycle. Holding Load_wgt for 5 cycles
                // (0..4) instead of 4 lets run's rising edge land with Controller
                // already back in IDLE instead of racing its last LOAD_WGT cycle
                // (which silently swallows RunPulse and stalls the loop forever).
                if(LoadWgtCounter == 4) NextState = LOAD_ACT;
                else NextState = LOAD_WGT;
            end

            LOAD_ACT: begin
                if(WriteCommitCounter == Num_act)begin
                    if(K_TileCounter == Num_K_Tile_REG -1) NextState = DONE;
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
            // Must be qualified by CurrentState==LOAD_ACT: WriteCommitCounter's
            // own reset (above) only takes effect the cycle *after* CurrentState
            // leaves LOAD_ACT, so on that one cycle it still reads == Num_act
            // while CurrentState has already moved on to the next tile's
            // LOAD_WGT. Without this qualifier that stale reading re-fires this
            // block a second time per tile completion, double-advancing
            // K_TileCounter/BaseAddr_REG and injecting a phantom extra tile.
            if(CurrentState == LOAD_ACT && WriteCommitCounter == Num_act) begin
                if(K_TileCounter == Num_K_Tile_REG - 1 ) K_TileCounter <=0;
                else begin
                    K_TileCounter <= K_TileCounter + 1;
                    BaseAddr_REG_wgt <= BaseAddr_REG_wgt + 4;
                    BaseAddr_REG_act <= BaseAddr_REG_act + 4;
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
                        Num_K_Tile_REG <= Num_K_Tile;
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
