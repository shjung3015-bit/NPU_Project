module MAC_Unit(

    input  clk, rst_n,
    input  LoadEna,          // 1 = weight 로딩 단계, 0 = 연산 단계 (배열 전체에 동일하게 broadcast)
    input  InValid,         // 지금 들어온 값이 유효한지 (skew 채우는 중이면 0)

    input  signed [ACT_W-1:0]  AIn,        // 왼쪽 PE에서 온 activation (compute phase에서만 의미 있음)
    input  signed [ACT_W-1:0]  WIn,        // 위 PE에서 온 weight (load phase에서만 의미 있음)
    input  signed [PSUM_W-1:0] PsumIn,     // 위 PE에서 온 partial sum (compute phase에서만 의미 있음)

    output logic signed [ACT_W-1:0]  AOut,       // 오른쪽 PE로 전달 (1클럭 지연)
    output logic signed [ACT_W-1:0]  WOut,       // 아래 PE로 전달 (load phase 때만 흐름, 1클럭 지연)
    output logic signed [PSUM_W-1:0] PsumOut,    // 아래 PE로 전달되는 누적 partial sum
    output logic OutValid
);

    localparam ACT_W  = 8;
    localparam PSUM_W = 32;

    logic signed [ACT_W-1:0] WReg;

    always_ff@(posedge clk) begin
	    if(!rst_n) begin
		    AOut<=0;
		    WOut<=0;
		    PsumOut<=0;
		    OutValid<=0;
		    WReg <=0;
	    end
	    else begin
		    if(LoadEna) begin
			    WReg <= WIn;
			    WOut <= WIn;
		    end
		    else if (InValid) begin
			    AOut <= AIn;
			    PsumOut<=PsumIn + AIn * WReg;
		    end

		    OutValid<=InValid;
	    end
    end
endmodule
