module SRAM(

    input logic clk, rst_n, ena, wea, enb,
    input logic [9:0] addr_rd,
    input logic [9:0] addr_wt,

    input logic [31:0] din,
    output logic [31:0] dout

);


    logic [31:0] mem [1023:0];

    always_ff@(posedge clk) begin
        if(!rst_n) begin
        end
        else begin 
            if(ena) begin
                if(wea) begin
                    mem[addr_wt] <= din;
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
                dout <= mem[addr_rd];
            end
        end
    end
endmodule
