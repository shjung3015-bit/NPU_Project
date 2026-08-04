bind FIFO FIFO_sva fifo_sva_inst(
    .clk(clk),
    .rst_n(rst_n),
    .wea(wea),
    .rea(rea),
    .ff_empty(ff_empty),
    .ff_full(ff_full),
    .wptr(wr_ptr),
    .rptr(rd_ptr)
);

bind Controller Controller_sva controller_sva_inst(
    .clk(clk),
    .rst_n(rst_n),
    .current_state(current_state),
    .num_act(num_act),
    .act_offset(act_offset)
);

bind SRAM SRAM_sva sram_sva_inst(
    .clk(clk),
    .rst_n(rst_n),
    .enb(enb),
    .dout(dout)
);

bind FIFO_All FIFO_All_sva fifo_all_sva_inst(
    .clk(clk),
    .rst_n(rst_n),
    .counter(counter),
    .pop_fire(pop_fire),
    .output_valid(output_valid)
);
