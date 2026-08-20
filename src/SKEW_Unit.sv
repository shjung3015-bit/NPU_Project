module SKEW_Unit (

    input logic clk,
    input logic rst_n,
    input logic [ARRAY_SIZE-1:0] [7:0] In_act,
    input logic ValidIn,

    output logic [ARRAY_SIZE-1:0][7:0] SkewOut_act,
    output logic [ARRAY_SIZE-1:0]      ValidOut

);

    localparam ARRAY_SIZE = 4;


    logic [7:0] Bubble_act [2:0][2:0];
    logic ValidBubble [2:0][2:0];

    always_ff@(posedge clk) begin

	    if(!rst_n) begin
		    SkewOut_act[0] <= 0;
		    SkewOut_act[1] <= 0;
		    SkewOut_act[2] <= 0;
		    SkewOut_act[3] <= 0;

		    ValidOut[0] <= 0;
		    ValidOut[1] <= 0;
		    ValidOut[2] <= 0;
		    ValidOut[3] <= 0;

            Bubble_act[0][0] <= 0;
            Bubble_act[1][0] <= 0;
            Bubble_act[1][1] <= 0;
            Bubble_act[2][0] <= 0;
            Bubble_act[2][1] <= 0;
            Bubble_act[2][2] <= 0;

            ValidBubble[0][0] <= 0;
            ValidBubble[1][0] <= 0;
            ValidBubble[1][1] <= 0;
            ValidBubble[2][0] <= 0;
            ValidBubble[2][1] <= 0;
            ValidBubble[2][2] <= 0;

	    end
	    else begin
		    SkewOut_act[0] <= ValidIn ? In_act[0] : SkewOut_act[0];

		    SkewOut_act[1] <= ValidBubble[0][0] ? Bubble_act[0][0] : SkewOut_act[1];
		    Bubble_act[0][0] <= ValidIn ? In_act[1] : Bubble_act[0][0];

		    SkewOut_act[2] <= ValidBubble[1][0] ? Bubble_act[1][0] : SkewOut_act[2];
		    Bubble_act[1][0] <= ValidBubble[1][1] ? Bubble_act[1][1] : Bubble_act[1][0];
		    Bubble_act[1][1] <= ValidIn ? In_act[2] : Bubble_act[1][1];

		    SkewOut_act[3] <= ValidBubble[2][0] ? Bubble_act[2][0] : SkewOut_act[3];
		    Bubble_act[2][0] <= ValidBubble[2][1] ? Bubble_act[2][1] : Bubble_act[2][0];
		    Bubble_act[2][1] <= ValidBubble[2][2] ? Bubble_act[2][2] : Bubble_act[2][1];
		    Bubble_act[2][2] <= ValidIn ? In_act[3] : Bubble_act[2][2];

		    ValidOut[0] <= ValidIn;

		    ValidBubble[0][0] <= ValidIn;
		    ValidOut[1] <= ValidBubble[0][0];

		    ValidBubble[1][1] <=ValidIn;
		    ValidBubble[1][0] <= ValidBubble[1][1];
		    ValidOut[2] <= ValidBubble[1][0];

		    ValidBubble[2][2] <= ValidIn;
		    ValidBubble[2][1] <= ValidBubble[2][2];
		    ValidBubble[2][0] <= ValidBubble[2][1];
		    ValidOut[3] <= ValidBubble[2][0];
	    end
    end
endmodule
