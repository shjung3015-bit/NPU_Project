module Systolic_Array(

    input logic clk, rst_n, LoadEna, start,

    input logic signed [3:0] [7:0] In_act ,
    input logic signed [3:0] [7:0] In_wgt,

    output logic signed [3:0][31:0] DataOut,
    output logic [3:0] DataValid
);

    localparam ARRAY_SIZE = 4;

    logic [3:0][7:0] SkewIn_act;

    logic signed [7:0] AArray [ARRAY_SIZE:0] [ARRAY_SIZE:0];
    logic signed [7:0] WArray [ARRAY_SIZE:0] [ARRAY_SIZE:0];
    logic signed [31:0] PsumArray [ARRAY_SIZE:0] [ARRAY_SIZE:0];
    logic InValidArray [ARRAY_SIZE:0] [ARRAY_SIZE:0];
    logic [3:0] InValid;

	assign DataValid = {InValidArray[3][4], InValidArray[3][3], InValidArray[3][2], InValidArray[3][1]};

    SKEW_Unit SKEW (
	    .clk(clk),
	    .rst_n(rst_n),
	    .In_act(In_act),
	    .ValidIn(start),

	    .SkewOut_act(SkewIn_act),
	    .ValidOut(InValid)
    );

    genvar k;
    generate
	    for (k = 0; k < ARRAY_SIZE; k++) begin : BOUND
      		assign AArray[k][0]    = SkewIn_act[k];
      		assign WArray[0][k]    = In_wgt[k];
      		assign PsumArray[0][k] = 32'sd0;
            assign InValidArray[k][0] = InValid[k];
      		assign DataOut[k]      = PsumArray[ARRAY_SIZE][k];
    	end
    endgenerate

    genvar i, j;
    generate
	    for (i = 0; i < ARRAY_SIZE; i++) begin : ROW
      		    for (j = 0; j < ARRAY_SIZE; j++) begin : COL
        		    MAC_Unit PE (
          			    .clk      (clk),
          			    .rst_n    (rst_n),
          			    .LoadEna  (LoadEna),
          			    .InValid (InValidArray[i][j]),
          			    .AIn     (AArray[i][j]),
          			    .WIn     (WArray[i][j]),
          			    .PsumIn  (PsumArray[i][j]),
          			    .AOut    (AArray[i][j+1]),
          			    .WOut    (WArray[i+1][j]),
          			    .PsumOut (PsumArray[i+1][j]),
                        .OutValid(InValidArray[i][j+1])
       	 		    );
      		    end
    	    end
    endgenerate
endmodule
