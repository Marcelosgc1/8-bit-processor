module main(
	input clk, reset, 
	output [2:0] sw,
	output reg [13:0] debug_register
);

	wire [3:0] be;
	wire [7:0] 	pc, ra;
	wire [31:0] ic, dr;
	wire [64:0] drrrrr;
	
	
	always @(*) begin
		case(sw[2:1])
			0: debug_register[8] = drrrrr[60];
			1: debug_register[8] = drrrrr[61];
			2: debug_register[8] = drrrrr[62];
			3: debug_register[8] = drrrrr[63];
			default: debug_register[8] = drrrrr[60];
		endcase
		debug_register[0+:8] = sw[0] ? drrrrr[0+:8] : drrrrr[8+:8];
		debug_register[13:9] = {!drrrrr[20],!drrrrr[19],!drrrrr[18],!drrrrr[17],!drrrrr[16]};
	end
	
	reg [24:0] c;
	assign new_clk = c[24];
	always @(posedge clk)begin
		c <= c+1;
	end
	
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
		.clk (new_clk),
		.reset (reset),
		.instruction_code (ic),
		.data_read (dr),
		.program_counter (pc),
		.access_address (ra),
		.data_write (dw),
		.byte_enable (be),
		.write_enable (we),
		.debug_reg(drrrrr)
	);



endmodule