module Systolic_Array(
    
    input logic clk, rst_n, load_en, start,

    input logic signed [3:0] [7:0] act_in ,
    input logic signed [3:0] [7:0] wgt_in,

    output logic signed [3:0][31:0] data_out,
    output logic [3:0] data_valid
);

    logic [3:0][7:0] act_skew_in;

    logic signed [7:0] a_array [4:0] [4:0];
    logic signed [7:0] w_array [4:0] [4:0];
    logic signed [31:0] psum_array [4:0] [4:0];
    logic in_valid_array [4:0] [4:0];
    logic [3:0] in_valid;

	assign data_valid = {in_valid_array[3][4], in_valid_array[3][3], in_valid_array[3][2], in_valid_array[3][1]};

    SKEW_Unit SKEW (
	    .clk(clk),
	    .rst_n(rst_n),
	    .act_in(act_in),
	    .valid_in(start),

	    .act_skew_in(act_skew_in),
	    .valid_out(in_valid)
    );

    genvar k;
    generate
	    for (k = 0; k < 4; k++) begin : BOUND
      		assign a_array[k][0]    = act_skew_in[k];
      		assign w_array[0][k]    = wgt_in[k];
      		assign psum_array[0][k] = 32'sd0;
            assign in_valid_array[k][0] = in_valid[k];
      		assign data_out[k]      = psum_array[4][k];
    	end
    endgenerate

    genvar i, j;
    generate
	    for (i = 0; i < 4; i++) begin : ROW
      		    for (j = 0; j < 4; j++) begin : COL
        		    MAC_Unit PE (
          			    .clk      (clk),
          			    .rst_n    (rst_n),
          			    .load_en  (load_en),
          			    .in_valid (in_valid_array[i][j]),
          			    .a_in     (a_array[i][j]),
          			    .w_in     (w_array[i][j]),
          			    .psum_in  (psum_array[i][j]),
          			    .a_out    (a_array[i][j+1]),
          			    .w_out    (w_array[i+1][j]),
          			    .psum_out (psum_array[i+1][j]),
                        .out_valid(in_valid_array[i][j+1])
       	 		    );
      		    end
    	    end
    endgenerate
endmodule
