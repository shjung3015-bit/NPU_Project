module N_LoopMatmul(
    input clk, rst_n,
    input logic N_LoopStart,
    input logic [7:0] K_Num_Tile,
    input logic [7:0] N_Num_Tile,
    input logic WriteCommit,
    input logic [9:0] Num_act,
    input logic [9:0] BaseAddr_wgt_in,
    input logic [9:0] BaseAddr_act_in,

    output logic run, Load_wgt,
    output logic [9:0] BaseAddr_wgt,
    output logic [9:0] BaseAddr_act,
    output logic [9:0] N_TileBase_REG,
    output logic AddEna,
    output logic TileStart,
    output logic LoopActive

);

    parameter IDLE=4'b0001, PROCESS=4'b0010, DONE = 4'b1000;

    logic [3:0] CurrentState, NextState;
    logic [7:0] N_Tile_Counter;
    logic [7:0] Num_N_Tile_REG;
    logic N_LoopStartEdge, N_LoopStartPrev;
    logic K_LoopActive, K_LoopActivePrev, K_LoopActiveFallEdge, K_LoopStart;
    logic [9:0] N_BaseAddr_REG_wgt;


    assign LoopActive = (CurrentState == PROCESS) || (CurrentState == DONE);
    assign N_LoopStartEdge = N_LoopStart && !N_LoopStartPrev;
    assign K_LoopActiveFallEdge = !K_LoopActive && K_LoopActivePrev;

    K_LoopMatmul LM_K(
        .clk(clk),
        .rst_n(rst_n),
        .LoopStart(K_LoopStart),
        .K_Num_Tile(K_Num_Tile),
        .WriteCommit(WriteCommit),
        .Num_act(Num_act),
        .BaseAddr_wgt_in(N_BaseAddr_REG_wgt),
        .BaseAddr_act_in(BaseAddr_act_in),

        .run(run), 
        .Load_wgt(Load_wgt),
        .BaseAddr_wgt(BaseAddr_wgt),
        .BaseAddr_act(BaseAddr_act),
        .AddEna(AddEna),
        .TileStart(TileStart),
        .K_LoopActive(K_LoopActive)
    );


    always_ff@(posedge clk) begin
        if(!rst_n) begin
            N_LoopStartPrev <= 0;
        end
        else begin
            N_LoopStartPrev <= N_LoopStart;
        end
    end

    always_ff@(posedge clk) begin
        if(!rst_n) begin
            K_LoopActivePrev <= 0;
        end
        else begin
            K_LoopActivePrev <= K_LoopActive;
        end
    end

    always_ff@(posedge clk) begin
        if(!rst_n) 
            CurrentState <= IDLE;
        else    
            CurrentState <= NextState;
    end

    always_ff@(posedge clk) begin
        if(!rst_n) N_Tile_Counter <= 0;
        else if(N_LoopStartEdge) N_Tile_Counter <= 0;
        else begin
            if(K_LoopActiveFallEdge) N_Tile_Counter <= N_Tile_Counter + 1;
        end
    end

    always_comb begin
        case(CurrentState)
            IDLE: begin
                if(N_LoopStartEdge) NextState = PROCESS;
                else NextState = IDLE;
            end

            PROCESS: begin
                if(K_LoopActiveFallEdge) begin
                    if(N_Tile_Counter == Num_N_Tile_REG - 1) NextState = DONE;
                    else NextState = PROCESS;
                end
                else NextState = PROCESS;
            end

            DONE: begin
                NextState = IDLE;
            end
        endcase
    end


    always_ff@(posedge clk) begin

        if(!rst_n) begin
            N_BaseAddr_REG_wgt <= 0;
            N_TileBase_REG <= 0;
            K_LoopStart <= 0;
        end

        else begin
            K_LoopStart <= 0;
            case(CurrentState)
                IDLE: begin
                    
                    if(N_LoopStartEdge) begin
                        Num_N_Tile_REG <= N_Num_Tile;
                        N_BaseAddr_REG_wgt <= BaseAddr_wgt_in;
                        N_TileBase_REG <= 0;
                        K_LoopStart <= 1; 
                    end
                end

                PROCESS: begin 
                    if(K_LoopActiveFallEdge) begin
                        if(N_Tile_Counter != Num_N_Tile_REG - 1) begin 
                            K_LoopStart <= 1;
                            N_BaseAddr_REG_wgt <= N_BaseAddr_REG_wgt + (K_Num_Tile << 2);
                            N_TileBase_REG <= N_TileBase_REG + Num_act;
                        end
                    end
                end
            endcase
        end

    end

endmodule