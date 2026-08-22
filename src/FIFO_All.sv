module FIFO_All(
    input logic clk, rst_n,
    input logic [3:0] [31:0] DIn,
    input logic [3:0] DataValid,

    input logic inject,
    output logic InjectEna,

    output logic [3:0] [31:0] DOut,
    output logic OutputValid
);

    localparam NUM_LANES  = 4;
    localparam FIFO_DEPTH = 8;

    logic [3:0] FfEmpty, FfFull;
    logic AllReady;


    assign AllReady = &(~FfEmpty);

    always_ff@(posedge clk) begin
        if(!rst_n) OutputValid <= 1'b0;
        else       OutputValid <= AllReady;
    end

    genvar i;

    for(i=0; i<NUM_LANES; i++) begin
        FIFO fifo(
            .clk(clk),
            .rst_n(rst_n),
            .wea(DataValid[i]),
            .rea(AllReady),
            .DIn(DIn[i]),

            .FfEmpty(FfEmpty[i]),
            .FfFull(FfFull[i]),
            .DOut(DOut[i])
        );
    end

    logic [$clog2(FIFO_DEPTH):0] counter;

    always_ff@(posedge clk) begin
        if(!rst_n) begin
            counter <= 0;
        end
        else case({inject, AllReady})
            2'b10: begin
                counter <= counter + 1;
            end
            2'b01: begin
                counter <= counter - 1;
            end
            default: begin
                counter <= counter;
            end
        endcase
    end

    assign InjectEna = counter < FIFO_DEPTH;


endmodule
