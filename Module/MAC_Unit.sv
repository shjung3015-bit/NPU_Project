module MAC_Unit(
    
    input  clk, rst_n,
    input  load_en,          // 1 = weight 로딩 단계, 0 = 연산 단계 (배열 전체에 동일하게 broadcast)
    input  in_valid,         // 지금 들어온 값이 유효한지 (skew 채우는 중이면 0)

    input  signed [7:0]  a_in,        // 왼쪽 PE에서 온 activation (compute phase에서만 의미 있음)
    input  signed [7:0]  w_in,        // 위 PE에서 온 weight (load phase에서만 의미 있음)
    input  signed [31:0] psum_in,     // 위 PE에서 온 partial sum (compute phase에서만 의미 있음)

    output logic signed [7:0]  a_out,       // 오른쪽 PE로 전달 (1클럭 지연)
    output logic signed [7:0]  w_out,       // 아래 PE로 전달 (load phase 때만 흐름, 1클럭 지연)
    output logic signed [31:0] psum_out,    // 아래 PE로 전달되는 누적 partial sum
    output logic out_valid
);


    logic signed [7:0] w_reg;

    always_ff@(posedge clk) begin
	    if(!rst_n) begin
		    a_out<=0;
		    w_out<=0;
		    psum_out<=0;
		    out_valid<=0;
		    w_reg <=0;
	    end 
	    else begin
		    if(load_en) begin
			    w_reg <= w_in;
			    w_out <= w_in;
		    end
		    else if (in_valid) begin
			    a_out <= a_in;
			    psum_out<=psum_in + a_in * w_reg;
		    end

		    out_valid<=in_valid;
	    end
    end
endmodule