module SRAM(

    input logic clk, rst_n, ena, wea, enb,
    input logic [9:0] AddrRd,
    input logic [9:0] AddrWt,

    input logic [31:0] din,
    output logic [31:0] dout

);

    localparam ADDR_W = 10;
    localparam DATA_W = 32;
    localparam DEPTH  = 1 << ADDR_W;

    logic [DATA_W-1:0] mem [DEPTH-1:0];

    always_ff@(posedge clk) begin
        if(!rst_n) begin
        end
        else begin
            if(ena) begin
                if(wea) begin
                    mem[AddrWt] <= din;
                end
            end
        end
    end

    always_ff@(posedge clk) begin
        if(!rst_n) begin
            dout <= 32'd0;
        end
        else begin
            if(enb) begin
                dout <= mem[AddrRd];
            end
        end
    end
endmodule
