module Top_Module(
    input logic clk, rst_n,
    input logic rx,

    output logic busy,
    output logic tx,
    output logic [4:0] dbg_state
);


    logic signed [3:0][31:0] result, dout;
    logic ResultValid, dout_Valid;

    logic run, Load_wgt;
    logic Ena_act, Wea_act, Ena_wgt, Wea_wgt;
    logic [9:0] AddrWt_act, AddrWt_wgt;
    logic [9:0] BaseAddr_wgt, BaseAddr_act;
    logic [31:0] Din_wgt, Din_act;
    logic PopEna;
    logic [9:0] Num_act;
    logic WriteCommit;

    logic AddEna, TileStart; // AddEna, TileStart

    logic run_Loop, Load_wgt_Loop;
    logic [9:0] BaseAddr_wgt_Loop, BaseAddr_act_Loop;
    logic AddEna_Loop, TileStart_Loop;

    logic run_Bridge, Load_wgt_Bridge;
    logic [9:0] BaseAddr_wgt_Bridge, BaseAddr_act_Bridge;
    logic AddEna_Bridge, TileStart_Bridge;
    logic [7:0] Num_K_Tile;
    logic LoopStart, LoopActive;

    assign run = (LoopActive || LoopStart) ? run_Loop : run_Bridge;
    assign Load_wgt = (LoopActive || LoopStart) ? Load_wgt_Loop : Load_wgt_Bridge;
    assign BaseAddr_act = (LoopActive || LoopStart) ? BaseAddr_act_Loop : BaseAddr_act_Bridge;
    assign BaseAddr_wgt = (LoopActive || LoopStart) ? BaseAddr_wgt_Loop : BaseAddr_wgt_Bridge;
    assign TileStart = (LoopActive || LoopStart) ? TileStart_Loop : TileStart_Bridge;
    assign AddEna = (LoopActive || LoopStart) ? AddEna_Loop : AddEna_Bridge;



    UART_Bridge U_Bridge(

        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .result(dout),
        .ResultValid(dout_Valid),

        .tx(tx),
        .run(run_Bridge),
        .Load_wgt(Load_wgt_Bridge),
        .Ena_act(Ena_act),
        .Wea_act(Wea_act),
        .Ena_wgt(Ena_wgt),
        .Wea_wgt(Wea_wgt),
        .AddrWt_act(AddrWt_act),
        .AddrWt_wgt(AddrWt_wgt),
        .BaseAddr_act(BaseAddr_act_Bridge),
        .BaseAddr_wgt(BaseAddr_wgt_Bridge),
        .Din_wgt(Din_wgt),
        .Din_act(Din_act),
        .PopEna(PopEna),
        .Num_act(Num_act),
        .BridgeBusy(busy),
        .dbg_state(dbg_state),

        .TileStart(TileStart_Bridge),
        .AddEna(AddEna_Bridge),
        .Num_K_Tile(Num_K_Tile),
        .LoopStart(LoopStart)
    );

    Systolic_Core S_Core(
        .clk(clk),
        .rst_n(rst_n),
        .run(run),
        .Load_wgt(Load_wgt),
        .Ena_act(Ena_act),
        .Wea_act(Wea_act),
        .Ena_wgt(Ena_wgt),
        .Wea_wgt(Wea_wgt),
        .AddrWt_act(AddrWt_act),
        .AddrWt_wgt(AddrWt_wgt),
        .BaseAddr_act(BaseAddr_act),
        .BaseAddr_wgt(BaseAddr_wgt),
        .Din_wgt(Din_wgt),
        .Din_act(Din_act),
        .Num_act(Num_act),

        .result(result),
        .ResultValid(ResultValid)
    );

    Accumulator Acc(
        .clk(clk),
        .rst_n(rst_n),
        .Core_Result(result),
        .CoreResultValid(ResultValid),
        .AddEna(AddEna), //AddEna
        .TileStart(TileStart), //TileStart
        .Pop(PopEna),

        .WriteEnable(WriteCommit),
        .dout(dout),
        .Output_Valid(dout_Valid)
    );

    LoopMatmul LMM(
        .clk(clk),
        .rst_n(rst_n),
        .LoopStart(LoopStart),
        .Num_K_Tile(Num_K_Tile),
        .WriteCommit(WriteCommit),
        .Num_act(Num_act),
        .BaseAddr_wgt_in(BaseAddr_wgt_Bridge),
        .BaseAddr_act_in(BaseAddr_act_Bridge),

        .run(run_Loop), 
        .Load_wgt(Load_wgt_Loop),
        .BaseAddr_wgt(BaseAddr_wgt_Loop),
        .BaseAddr_act(BaseAddr_act_Loop),
        .AddEna(AddEna_Loop),
        .TileStart(TileStart_Loop),
        .LoopActive(LoopActive)
    );


endmodule

