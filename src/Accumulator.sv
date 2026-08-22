module Accumulator(
    input logic clk, rst_n,
    input logic signed [3:0][31:0] Core_Result,
    input logic CoreResultValid,
    input logic AddEna, Pop, TileStart,

    output logic WriteEnable,
    output logic signed [3:0][31:0] dout,
    output logic Output_Valid
);

    logic Popping;
    logic [9:0] AddrRd;
    logic [9:0] Addr_Counter, Addr_Counter_Delay;
    logic [9:0] Addr_Pop;
    logic signed [3:0][31:0] InputData_SRAM, OutputData_SRAM;
    logic signed [3:0][31:0] Result;
    logic signed [3:0][31:0] Core_Result_Delay;
    logic AddEna_Delay;

    logic PopEdge, PopPrev;
    logic TileStartEdge, TileStartPrev;

    assign AddrRd = (Popping || PopEdge) ? Addr_Pop : Addr_Counter;

    assign InputData_SRAM = AddEna_Delay ? Result : Core_Result_Delay;
    assign dout = OutputData_SRAM;

    assign PopEdge = Pop && !PopPrev;

    assign TileStartEdge = TileStart && !TileStartPrev;


    always_ff@(posedge clk) begin
        if(!rst_n) begin
            PopPrev <= 0;
            TileStartPrev <= 0;
        end
        else begin
            PopPrev <= Pop;
            TileStartPrev <= TileStart;
        end
    end

    always_ff@(posedge clk) begin
        if(!rst_n)begin
            WriteEnable <= 0;
            Addr_Counter <= 0;
            Addr_Counter_Delay <= 0;
            Core_Result_Delay <= 0;
            AddEna_Delay <= 0;
        end
        else begin
            WriteEnable <= CoreResultValid;
            if(TileStartEdge) Addr_Counter <= 0;
            else if(CoreResultValid) Addr_Counter <= Addr_Counter + 1;
            Addr_Counter_Delay <= Addr_Counter;
            Core_Result_Delay <= Core_Result;
            AddEna_Delay <= AddEna;
        end
    end

    always_ff@(posedge clk) begin
        if(!rst_n) begin
            Addr_Pop <= 0;
            Output_Valid <= 0;
        end
        else if (TileStartEdge) begin 
            Addr_Pop <= 0;
        end
        else if (PopEdge) begin 
            Addr_Pop <= Addr_Pop + 1;
            Output_Valid <= 1'b1;
        end
        else Output_Valid <= 1'b0;
    end

    always_ff@(posedge clk) begin
        if(!rst_n) Popping <= 1'b0;
        else if (TileStartEdge) Popping <= 1'b0;
        else if (PopEdge) Popping <= 1'b1;
    end


    genvar i;
    generate
        for(i=0; i<4; i++)  begin : g_row
            SRAM SRAM_Accumulator(
                .clk(clk),
                .rst_n(rst_n),
                .ena(WriteEnable),
                .wea(WriteEnable),
                .enb(CoreResultValid || PopEdge),
                .AddrRd(AddrRd),
                .AddrWt(Addr_Counter_Delay),
                .din(InputData_SRAM[i]),

                .dout(OutputData_SRAM[i])
                );

            Adder Adder_Accumulator (
                .Data1(OutputData_SRAM[i]),
                .Data2(Core_Result_Delay[i]),

                .dout(Result[i])
            );
        end
    endgenerate


endmodule
