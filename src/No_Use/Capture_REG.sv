module Capture_REG(
    input logic clk, rst_n, start,

    input logic [3:0] data_valid,
    input logic signed [3:0] [31:0] data_in,    

    output logic result_valid,
    output logic signed [3:0] [31:0] result
);

    logic [3:0] captured, next_captured;

    assign next_captured = start ? 4'b0000 : (data_valid | captured);

    always_ff@(posedge clk) begin
        if(!rst_n) begin
            result <= 0;
            result_valid <= 0;
            captured <= 0;
        end
        else begin
            captured <= next_captured;
            result_valid <= &next_captured;

            for(int i=0; i<4; i++) begin
                if(data_valid[i]) result[i] <= data_in[i];
            end
        end
    end