module FIFO(
    input logic clk, rst_n,
    input logic wea, rea,
    input logic [31:0] DIn,

    output logic FfEmpty, FfFull,
    output logic [31:0] DOut
);

    localparam FIFO_DEPTH = 8;
    localparam DATA_W     = 32;
    localparam PTR_W      = $clog2(FIFO_DEPTH);

    logic [DATA_W-1:0] MemFifo [FIFO_DEPTH-1:0];
    logic [PTR_W:0] WrPtr, RdPtr;

    assign FfEmpty = (WrPtr == RdPtr);
    assign FfFull = (WrPtr[PTR_W-1:0]==RdPtr[PTR_W-1:0]) && (WrPtr[PTR_W] != RdPtr[PTR_W]);


    always_ff@(posedge clk) begin
        if(!rst_n) begin
            WrPtr <=0;
        end
        else if(wea && !FfFull) begin
            WrPtr <= WrPtr + 1;
        end
        else begin
            WrPtr <= WrPtr;
        end
    end

    always_ff@(posedge clk) begin
        if(!rst_n) begin
            RdPtr <=0;
        end
        else if(rea && !FfEmpty) begin
            RdPtr <= RdPtr + 1;
        end
        else begin
            RdPtr <= RdPtr;
        end
    end

    always_ff@(posedge clk) begin
        if(!rst_n) begin
            DOut <=0;
        end
        else begin
            if(wea && !FfFull) begin
                MemFifo[WrPtr[PTR_W-1:0]] <= DIn;
            end
            if(rea && !FfEmpty) begin
                DOut <= MemFifo[RdPtr[PTR_W-1:0]];
            end
        end
    end


endmodule
