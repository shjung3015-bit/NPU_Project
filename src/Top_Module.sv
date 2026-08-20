module Top_Module(
    input logic clk, rst_n,
    input logic rx,

    output logic busy,
    output logic tx,
    output logic [4:0] dbg_state
);


    logic signed [3:0][31:0] result;
    logic ResultValid;

    logic run, Load_wgt;
    logic Ena_act, Wea_act, Ena_wgt, Wea_wgt;
    logic [9:0] AddrWt_act, AddrWt_wgt;
    logic [9:0] BaseAddr_wgt, BaseAddr_act;
    logic [31:0] Din_wgt, Din_act;
    logic PopEna;
    logic [9:0] Num_act;

    UART_Bridge U_Bridge(

        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .result(result),
        .ResultValid(ResultValid),

        .tx(tx),
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
        .PopEna(PopEna),
        .Num_act(Num_act),
        .BridgeBusy(busy),
        .dbg_state(dbg_state)
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
        .PopEna(PopEna),
        .Num_act(Num_act),

        .result(result),
        .ResultValid(ResultValid)
    );


endmodule

