module Top_Module(
    input logic clk, rst_n, run, load_wgt,
    input logic ena_act, wea_act, ena_wgt, wea_wgt,
    input logic [9:0] addr_act_wt, addr_wgt_wt,
    input logic [9:0] base_addr_wgt, base_addr_act,
    input [31:0] din_wgt, din_act,
    input logic pop_ena,
    input logic [9:0] num_act,

    output logic signed [3:0][31:0] result
);

    logic [3:0] [7:0] dout_wgt;
    logic [3:0] [7:0] dout_act;

    logic enb_wgt, enb_act;
    logic [9:0] addr_wgt_rd, addr_act_rd;
    logic load_en, start;
    logic [3:0] data_valid;
    logic result_valid;
    logic signed [3:0][31:0] data_out;
    logic inject_ena;


    Controller controller (
        .clk(clk),
        .rst_n(rst_n),
        .run(run),
        .load_wgt(load_wgt),
        .base_addr_wgt(base_addr_wgt),
        .base_addr_act(base_addr_act),
        .num_act(num_act),
        .inject_ena(inject_ena),

        .enb_wgt(enb_wgt),
        .enb_act(enb_act),
    
        .addr_wgt(addr_wgt_rd),
        .addr_act(addr_act_rd),

        .load_en(load_en),
        .start(start)
    );


    SRAM SRAM_wgt (
        .clk(clk),
        .ena(ena_wgt),
        .wea(wea_wgt),
        .enb(enb_wgt),
        .addr_rd(addr_wgt_rd),
        .addr_wt(addr_wgt_wt),
        .din(din_wgt),

        .dout(dout_wgt)
    );

    SRAM SRAM_act (
        .clk(clk),
        .ena(ena_act),
        .wea(wea_act),
        .enb(enb_act),
        .addr_rd(addr_act_rd),
        .addr_wt(addr_act_wt),
        .din(din_act),

        .dout(dout_act)
    );


    Systolic_Array SA (
        .clk(clk),
        .rst_n(rst_n),
        .load_en(load_en),
        .start(start),
        .act_in(dout_act),
        .wgt_in(dout_wgt),
        .data_out(data_out),
        .data_valid(data_valid)
    );

    FIFO_All FIFO (
        .clk(clk),
        .rst_n(rst_n),
        .d_in(data_out),
        .pop(pop_ena),
        .data_valid(data_valid),
        .inject(start),

        .inject_ena(inject_ena),
        .d_out(result),
        .output_valid(result_valid)
    );


endmodule