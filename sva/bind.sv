bind FIFO FIFO_sva fifo_sva_inst(
    .clk(clk),
    .rst_n(rst_n),
    .wea(wea),
    .rea(rea),
    .FfEmpty(FfEmpty),
    .FfFull(FfFull),
    .wptr(WrPtr),
    .rptr(RdPtr)
);

bind Controller Controller_sva controller_sva_inst(
    .clk(clk),
    .rst_n(rst_n),
    .CurrentState(CurrentState),
    .Num_act(Num_act),
    .Offset_act(Offset_act)
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
    .PopFire(PopFire),
    .OutputValid(OutputValid)
);

bind Systolic_Array Systolic_Array_sva systolic_array_sva_inst(
    .clk(clk),
    .rst_n(rst_n),
    .CurrentState(CurrentState),
    .NextState(NextState),
    .InValidArray(InValidArray),
    .DataOut(DataOut),
    .DataValid(DataValid)
);

bind MAC_Unit MAC_Unit_sva mac_unit_sva_inst(
    .clk(clk),
    .rst_n(rst_n),
    .LoadEna(LoadEna),
    .InValid(InValid),
    .AOut(AOut),
    .WOut(WOut),
    .PsumOut(PsumOut),
    .OutValid(OutValid)
);
