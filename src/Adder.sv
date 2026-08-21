module Adder(
    input [31:0] Data1, Data2,
    output [31:0] dout

);

    assign dout = Data1 + Data2;

endmodule