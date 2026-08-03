module SKEW_Unit (

    input logic clk,
    input logic rst_n,
    input logic [3:0] [7:0] act_in,
    input logic valid_in,

    output logic [3:0][7:0] act_skew_in,
    output logic [3:0]      valid_out

);



    logic [7:0] act_bubble [2:0][2:0];
    logic valid_bubble [2:0][2:0];

    always_ff@(posedge clk) begin

	    if(!rst_n) begin
		    act_skew_in[0] <= 0;
		    act_skew_in[1] <= 0;
		    act_skew_in[2] <= 0;
		    act_skew_in[3] <= 0;

		    valid_out[0] <= 0;
		    valid_out[1] <= 0;
		    valid_out[2] <= 0;
		    valid_out[3] <= 0;

            act_bubble[0][0] <= 0;
            act_bubble[1][0] <= 0;
            act_bubble[1][1] <= 0;
            act_bubble[2][0] <= 0;
            act_bubble[2][1] <= 0;
            act_bubble[2][2] <= 0;

            valid_bubble[0][0] <= 0;
            valid_bubble[1][0] <= 0;
            valid_bubble[1][1] <= 0;
            valid_bubble[2][0] <= 0;
            valid_bubble[2][1] <= 0;
            valid_bubble[2][2] <= 0;

	    end
	    else begin
		    act_skew_in[0] <= act_in[0];
		
		    act_skew_in[1] <= act_bubble[0][0];
		    act_bubble[0][0] <= act_in[1];
		
		    act_skew_in[2] <=act_bubble[1][0];
		    act_bubble[1][0] <= act_bubble[1][1];
		    act_bubble[1][1] <= act_in[2];

		    act_skew_in[3] <= act_bubble[2][0];
		    act_bubble[2][0] <= act_bubble[2][1];
		    act_bubble[2][1] <= act_bubble[2][2];
		    act_bubble[2][2] <= act_in[3];

		    valid_out[0] <= valid_in;

		    valid_bubble[0][0] <= valid_in;
		    valid_out[1] <= valid_bubble[0][0];

		    valid_bubble[1][1] <=valid_in;
		    valid_bubble[1][0] <= valid_bubble[1][1];
		    valid_out[2] <= valid_bubble[1][0];

		    valid_bubble[2][2] <= valid_in;
		    valid_bubble[2][1] <= valid_bubble[2][2];
		    valid_bubble[2][0] <= valid_bubble[2][1];
		    valid_out[3] <= valid_bubble[2][0];
	    end
    end
endmodule
