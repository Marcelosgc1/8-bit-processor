module ALU(
	input [7:0] op1, op2,
	input [4:0] operation,
	input is_signed,
	output reg [7:0] result,
	output reg ZERO
);

	localparam 	NOP 	= 5'd00000,
					B 		= 5'd00001,
					BEQ 	= 5'd00010,
					ADD 	= 5'd00011,
					SUB 	= 5'd00100,
					LOAD 	= 5'd00101,
					STR 	= 5'd00110,
					ADDI 	= 5'd00111,
					BX		= 5'd01000,
					BL		= 5'd01001,
					AND	= 5'd01010,
					ORR	= 5'd01011,
					ANDI	= 5'd01100,
					ORRI	= 5'd01101,
					LSL	= 5'd01110,
					LSR	= 5'd01111,
					CMP	= 5'b10000
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
			BEQ: begin
				result = sum[7:0];
			end
			B: begin
				result = sum[7:0];
			end
			BL: begin
				result = sum[7:0];
			end
			CMP: begin
				result = subt[7:0];
			end
			ADD: begin
				result = sum[7:0];
			end
			SUB: begin
				result = subt[7:0];
			end
			LOAD: begin
				result = sum[7:0];
			end
			STR: begin
				result = sum[7:0];
			end
			ADDI: begin
				result = sum[7:0];
			end
			AND: begin
				result = logic_and;
			end
			ANDI: begin
				result = logic_and;
			end
			ORR: begin
				result = logic_or;
			end
			ORRI: begin
				result = logic_or;
			end
			LSL: begin
				result = op1 << op2;
			end
			LSR: begin
				result = op1 << op2;
			end
			ORRI: begin
				result = logic_or;
			end
			default: result = 0;
		endcase
	end

endmodule