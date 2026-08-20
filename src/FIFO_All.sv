module FIFO_All(
    input logic clk, rst_n,
    input logic [3:0] [31:0] DIn,
    input logic pop,
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
    logic PopFire;
    logic PopPrev, PopEdge;

    // pop comes from the (slow, externally-controlled) host register
    // interface and can stay asserted for a huge number of clocks --
    // edge-detect it so one host-visible pop request drains exactly one
    // entry instead of free-running every cycle AllReady stays true.
    always_ff@(posedge clk) begin
        if(!rst_n) PopPrev <= 1'b0;
        else       PopPrev <= pop;
    end

    assign AllReady = &(~FfEmpty);
    assign PopEdge = pop && !PopPrev;
    assign PopFire = AllReady && PopEdge;

    // OutputValid must line up with the cycle DOut actually holds the
    // popped data, which lags PopFire by 1 cycle (each FIFO's DOut is
    // registered), so it's a delayed copy of PopFire rather than the
    // same combinational signal used to drive rea below.
    always_ff@(posedge clk) begin
        if(!rst_n) OutputValid <= 1'b0;
        else       OutputValid <= PopFire;
    end

    genvar i;

    for(i=0; i<NUM_LANES; i++) begin
        FIFO fifo(
            .clk(clk),
            .rst_n(rst_n),
            .wea(DataValid[i]),
            .rea(PopFire),
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
        else case({inject, PopFire})
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
