module FIFO_All(
    input logic clk, rst_n,
    input logic [3:0] [31:0] d_in,
    input logic pop,
    input logic [3:0] data_valid,

    input logic inject,
    output logic inject_ena,

    output logic [3:0] [31:0] d_out,
    output logic output_valid
);

    logic [3:0] ff_empty, ff_full;
    logic all_ready;
    logic pop_fire;
    logic pop_prev, pop_edge;

    // pop comes from the (slow, externally-controlled) host register
    // interface and can stay asserted for a huge number of clocks --
    // edge-detect it so one host-visible pop request drains exactly one
    // entry instead of free-running every cycle all_ready stays true.
    always_ff@(posedge clk) begin
        if(!rst_n) pop_prev <= 1'b0;
        else       pop_prev <= pop;
    end

    assign all_ready = &(~ff_empty);
    assign pop_edge = pop && !pop_prev;
    assign pop_fire = all_ready && pop_edge;

    // output_valid must line up with the cycle d_out actually holds the
    // popped data, which lags pop_fire by 1 cycle (each FIFO's d_out is
    // registered), so it's a delayed copy of pop_fire rather than the
    // same combinational signal used to drive rea below.
    always_ff@(posedge clk) begin
        if(!rst_n) output_valid <= 1'b0;
        else       output_valid <= pop_fire;
    end

    genvar i;

    for(i=0; i<4; i++) begin
        FIFO fifo(
            .clk(clk),
            .rst_n(rst_n),
            .wea(data_valid[i]),
            .rea(pop_fire),
            .d_in(d_in[i]),

            .ff_empty(ff_empty[i]),
            .ff_full(ff_full[i]),
            .d_out(d_out[i])
        );
    end

    logic [$clog2(8):0] counter;

    always_ff@(posedge clk) begin
        if(!rst_n) begin
            counter <= 0;
        end
        else case({inject, pop_fire})
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

    assign inject_ena = counter < 8;


endmodule