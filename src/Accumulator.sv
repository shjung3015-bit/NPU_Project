module Accumulator(
    input logic clk, rst_n,
    input logic signed [3:0][31:0] Core_Result,
    input logic CoreResultValid,
    input logic AddEna, Pop, 

    output logic signed [3:0][31:0] dout,
    output logic Output_Valid
);

    logic [9:0] Addr_Counter, Addr_Counter_Delay;
    logic signed [3:0][31:0] InputData_SRAM, OutputData_SRAM;
    logic signed [3:0][31:0] Result;
    logic WriteEnable;

    assign InputData_SRAM = AddEna ? Result : Core_Result;
    assign dout = OutputData_SRAM;


    always_ff@(posedge clk) begin
        if(!rst_n)begin
            WriteEnable <= 0;
            Addr_Counter <= 0;
            Addr_Counter_Delay <= 0;
        end

        else begin
            WriteEnable <= CoreResultValid;
            if(CoreResultValid) Addr_Counter <= Addr_Counter + 1;
            Addr_Counter_Delay <= Addr_Counter;
        end
    end

    genvar i;
    generate
        for(i=0; i<4; i++)  begin : g_row
            SRAM SRAM_Accumulator(
                .clk(clk),
                .rst_n(rst_n),
                .ena(WriteEnable),
                .wea(WriteEnable),
                .enb(CoreResultValid),
                .AddrRd(Addr_Counter),
                .AddrWt(Addr_Counter_Delay),
                .din(InputData_SRAM[i]),

                .dout(OutputData_SRAM[i])
                );

            Adder Adder_Accumulator (
                .Data1(OutputData_SRAM[i]),
                .Data2(Core_Result[i]),

                .dout(Result[i])
            );
        end
    endgenerate

    



endmodule
