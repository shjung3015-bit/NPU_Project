module Top_Module(
    input logic clk, rst_n,
    input logic rx,

    output logic busy,
    output logic tx,
    output logic [4:0] dbg_state
);

    
    logic signed [3:0][31:0] result;
    logic result_valid;

    logic run, load_wgt; 
    logic ena_act, wea_act, ena_wgt, wea_wgt;
    logic [9:0] addr_act_wt, addr_wgt_wt;
    logic [9:0] base_addr_wgt, base_addr_act;
    logic [31:0] din_wgt, din_act;
    logic pop_ena;
    logic [9:0] num_act;

    UART_Bridge U_Bridge(

        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .result(result),
        .result_valid(result_valid),

        .tx(tx),
        .run(run),
        .load_wgt(load_wgt),
        .ena_act(ena_act),
        .wea_act(wea_act),
        .ena_wgt(ena_wgt),
        .wea_wgt(wea_wgt),
        .addr_act_wt(addr_act_wt),
        .addr_wgt_wt(addr_wgt_wt),
        .base_addr_act(base_addr_act),
        .base_addr_wgt(base_addr_wgt),
        .din_wgt(din_wgt),
        .din_act(din_act),
        .pop_ena(pop_ena),
        .num_act(num_act),
        .bridge_busy(busy),
        .dbg_state(dbg_state)
    );

    Systolic_Core S_Core(
        .clk(clk),
        .rst_n(rst_n),
        .run(run),
        .load_wgt(load_wgt),
        .ena_act(ena_act),
        .wea_act(wea_act),
        .ena_wgt(ena_wgt),
        .wea_wgt(wea_wgt),
        .addr_act_wt(addr_act_wt),
        .addr_wgt_wt(addr_wgt_wt),
        .base_addr_act(base_addr_act),
        .base_addr_wgt(base_addr_wgt),
        .din_wgt(din_wgt),
        .din_act(din_act),
        .pop_ena(pop_ena),
        .num_act(num_act),

        .result(result),
        .result_valid(result_valid)
    );


endmodule

