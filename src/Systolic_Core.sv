module Systolic_Core(
    input logic clk, rst_n, run, Load_wgt,
    input logic Ena_act, Wea_act, Ena_wgt, Wea_wgt,
    input logic [9:0] AddrWt_act, AddrWt_wgt,
    input logic [9:0] BaseAddr_wgt, BaseAddr_act,
    input [31:0] Din_wgt, Din_act,
    input logic [9:0] Num_act,

    output logic signed [3:0][31:0] result,
    output logic ResultValid
);

    logic [3:0] [7:0] Dout_wgt;
    logic [3:0] [7:0] Dout_act;

    logic Enb_wgt, Enb_act;
    logic [9:0] AddrRd_wgt, AddrRd_act;
    logic LoadEna, start;
    logic [3:0] DataValid;
    logic signed [3:0][31:0] DataOut;
    logic InjectEna;


    Controller controller (
        .clk(clk),
        .rst_n(rst_n),
        .run(run),
        .Load_wgt(Load_wgt),
        .BaseAddr_wgt(BaseAddr_wgt),
        .BaseAddr_act(BaseAddr_act),
        .Num_act(Num_act),
        .InjectEna(InjectEna),

        .Enb_wgt(Enb_wgt),
        .Enb_act(Enb_act),

        .Addr_wgt(AddrRd_wgt),
        .Addr_act(AddrRd_act),

        .LoadEna(LoadEna),
        .start(start)
    );


    SRAM SRAM_wgt (
        .clk(clk),
        .rst_n(rst_n),
        .ena(Ena_wgt),
        .wea(Wea_wgt),
        .enb(Enb_wgt),
        .AddrRd(AddrRd_wgt),
        .AddrWt(AddrWt_wgt),
        .din(Din_wgt),

        .dout(Dout_wgt)
    );

    SRAM SRAM_act (
        .clk(clk),
        .rst_n(rst_n),
        .ena(Ena_act),
        .wea(Wea_act),
        .enb(Enb_act),
        .AddrRd(AddrRd_act),
        .AddrWt(AddrWt_act),
        .din(Din_act),

        .dout(Dout_act)
    );


    Systolic_Array SA (
        .clk(clk),
        .rst_n(rst_n),
        .LoadEna(LoadEna),
        .start(start),
        .In_act(Dout_act),
        .In_wgt(Dout_wgt),
        .DataOut(DataOut),
        .DataValid(DataValid)
    );

    FIFO_All FIFO (
        .clk(clk),
        .rst_n(rst_n),
        .DIn(DataOut),
        .DataValid(DataValid),
        .inject(Enb_act),

        .InjectEna(InjectEna),
        .DOut(result),
        .OutputValid(ResultValid)
    );


endmodule
