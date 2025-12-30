module teste(
	input [7:0] a,
	input [7:0] b,
	output signed [8:0] c,
	output [8:0] d
);


assign c = $signed(a) + $signed(b);
assign d = a+b;


endmodule


