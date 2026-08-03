module FIFO(
    input logic clk, rst_n, 
    input logic wea, rea,
    input logic [31:0] d_in,

    output logic ff_empty, ff_full,
    output logic [31:0] d_out
);

    logic [31:0] mem_fifo [7:0];
    logic [$clog2(8):0] wr_ptr, rd_ptr;

    assign ff_empty = (wr_ptr == rd_ptr);
    assign ff_full = (wr_ptr[2:0]==rd_ptr[2:0]) && (wr_ptr[3] != rd_ptr[3]);


    always_ff@(posedge clk) begin
        if(!rst_n) begin
            wr_ptr <=0;
        end
        else if(wea && !ff_full) begin 
            wr_ptr <= wr_ptr + 1;
        end
        else begin
            wr_ptr <= wr_ptr;
        end 
    end

    always_ff@(posedge clk) begin
        if(!rst_n) begin
            rd_ptr <=0;
        end
        else if(rea && !ff_empty) begin 
            rd_ptr <= rd_ptr + 1;
        end
        else begin
            rd_ptr <= rd_ptr;
        end 
    end

    always_ff@(posedge clk) begin
        if(!rst_n) begin
            d_out <=0;
        end
        else begin
            if(wea && !ff_full) begin
                mem_fifo[wr_ptr[2:0]] <= d_in;
            end
            if(rea && !ff_empty) begin
                d_out <= mem_fifo[rd_ptr[2:0]];
            end
        end
    end


endmodule