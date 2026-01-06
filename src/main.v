module main(
	input clk, reset,
	output [63:0] debug_register
);

	wire [3:0] be;
	wire [7:0] 	pc, ra;
	wire [31:0] ic, dr;

	memory INSTRUCTION_MEMORY(
		.address ( pc[7:2] ),
		.byteena ( 4'b0 ),
		.clock ( clk ),
		.data ( 32'b0 ),
		.wren ( 1'b0 ),
		.q ( ic )
	);
	
	memory DATA_MEMORY(
		.address ( ra[7:2] ),
		.byteena ( be ),
		.clock ( clk ),
		.data ( dw ),
		.wren ( we ),
		.q ( dr )
	);
	
	
	
	processor my_processor (
		.clk (clk),
		.reset (reset),
		.instruction_code (ic),
		.data_read (dr),
		.program_counter (pc),
		.access_address (ra),
		.data_write (dw),
		.byte_enable (be),
		.write_enable (we),
		.debug_reg(debug_register)
	);



endmodule