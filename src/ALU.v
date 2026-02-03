module ALU(
	input [7:0] op1, op2,
	input [2:0] operation,
	input is_signed,
	output reg [7:0] result,
	output reg ZERO
);

	localparam 	ADD 	= 3'd001,
					SUB 	= 3'd010,
					AND	= 3'd011,
					ORR	= 3'd100,
					LSL	= 3'd101,
					LSR	= 3'd110
					;
					
	
	reg signed [8:0] sum, subt;
	reg signed [8:0] s_op1;
	reg [7:0] logic_and, logic_or;
	
	always @(*) begin
		
		if (is_signed) s_op1 = $signed(op1);
		else s_op1 = op1;
		
		sum = s_op1 + $signed(op2);
		
		subt = s_op1 - $signed(op2);
		
		logic_and = op1 & op2;
		
		logic_or = op1 | op2;
		
		ZERO = !(|result);
		
		case (operation)
			ADD: begin
				result = sum[7:0];
			end
			SUB: begin
				result = subt[7:0];
			end
			AND: begin
				result = logic_and;
			end
			ORR: begin
				result = logic_or;
			end
			LSL: begin
				result = op1 << op2;
			end
			LSR: begin
				result = op1 >> op2;
			end
			default: result = 0;
		endcase
	end

endmodule