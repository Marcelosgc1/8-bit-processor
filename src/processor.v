module processor(
	input clk, reset,
	input [31:0] instruction_code,
	input [31:0] data_read,
	output reg [7:0] program_counter,
	output reg [7:0] access_address,
	output [7:0] data_write,
	output reg [3:0] byte_enable,
	output reg write_enable,
	output reg [63:0] debug_reg
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


	//X0 - 	XZR; 			VALOR CONSTANTE 8'h00;
	//X1 -	PC; 			PROGRAM COUNTER, CONTADOR DE INSTRUCOES;
	//X2-5 -	USO GERAL; 	PROGRAMADOR PODE USAR A VONTADE;
	//X6 -	LR; 			LINK REGISTER; SALVA ENDEREÇO DE ONDE A FUNCAO FOI CHAMADA;
	//X7 -	SP;			STACK POINTER; SALVA O ENDEREÇO DE TOP NA STACK DA MEMORIA DE DADOS;
	
	/* OBSERVAÇOES
	
			OBS 1: Para instruçoes de branch, o PC vai estar +8 em relaçao ao endereço da instrucao de branch;
		Exemplo: Se a instruçao de branch esta no endereço 0x20, e voce quer pular para 0x30, voce
		deve considerar o endereço 0x28, entao no assembly deve estar escrito `B 0x08`, ao inves de
		`B 0x10`, ja que 0x28 + 0x08 = 0x30;
	
	
	*/
	
	reg [7:0] REGISTRADORES [7:0];
	initial REGISTRADORES[7] = 8'hff;
	
	reg [18:0] FETCH_PIPE;
	reg BRANCH;
	
	reg [18:0] DEC_PIPE;
	reg [7:0]  OPERATOR_1, OPERATOR_2;

	reg [18:0] EXE_PIPE;
	reg [7:0] EXE_RES;
	wire [7:0] ALU_RES;
	wire ZERO_S;
	reg ZERO_FLAG;
	
	reg [18:0] MEM_PIPE;
	reg [7:0] MEM_RES;
	reg [7:0] R_data;
	reg [7:0] W_data;
	
	reg MEMORY_HAZARD, F_RTYPE, D_RTYPE, E_RTYPE, M_RTYPE, F_ITYPE, D_ITYPE, E_ITYPE, M_ITYPE, MREG_WRITE, EREG_WRITE, ALU_WRITE;
	reg [7:0] ALU_OP1, ALU_OP2;
	reg [3:0] OPCODE_F, OPCODE_D, OPCODE_E, OPCODE_M;
	
	
	always @(*) begin
		//FOR DEBUG
		for (i = 0; i < 8; i = i + 1) begin
			debug_reg[i+:8] = REGISTRADORES[i];
		end
	
		program_counter = REGISTRADORES[1];
	
		OPCODE_F = FETCH_PIPE[18:14];
		OPCODE_D = DEC_PIPE[18:14];
		OPCODE_E = EXE_PIPE[18:14];
		OPCODE_M = MEM_PIPE[18:14];
		
		access_address = EXE_RES;
		
		BRANCH = (OPCODE_E == B | (OPCODE_E == BEQ & ZERO_FLAG) | OPCODE_E == BX | OPCODE_E == BL);
		
		F_RTYPE = OPCODE_F == ADD | OPCODE_F == SUB | OPCODE_F == AND | OPCODE_F == ORR;
		D_RTYPE = OPCODE_D == ADD | OPCODE_D == SUB | OPCODE_D == AND | OPCODE_D == ORR;
		E_RTYPE = OPCODE_E == ADD | OPCODE_E == SUB | OPCODE_E == AND | OPCODE_E == ORR;
		M_RTYPE = OPCODE_M == ADD | OPCODE_M == SUB | OPCODE_M == AND | OPCODE_M == ORR;
		
		F_ITYPE = OPCODE_F == ADDI | OPCODE_F == ANDI | OPCODE_F == ORRI | OPCODE_F == LSL | OPCODE_F == LSR;
		D_ITYPE = OPCODE_D == ADDI | OPCODE_D == ANDI | OPCODE_D == ORRI | OPCODE_D == LSL | OPCODE_D == LSR;
		E_ITYPE = OPCODE_E == ADDI | OPCODE_E == ANDI | OPCODE_E == ORRI | OPCODE_E == LSL | OPCODE_E == LSR;
		M_ITYPE = OPCODE_M == ADDI | OPCODE_M == ANDI | OPCODE_M == ORRI | OPCODE_M == LSL | OPCODE_M == LSR;
		
		MEMORY_HAZARD = 	(OPCODE_D == LOAD) & 
								(FETCH_PIPE[10:8] == DEC_PIPE[13:11] | (FETCH_PIPE[10:8] == DEC_PIPE[2:0] & F_RTYPE));
		
		MREG_WRITE = OPCODE_M == LOAD | ALU_WRITE;
		EREG_WRITE = OPCODE_E == LOAD | E_RTYPE | E_ITYPE;
		ALU_WRITE  = M_RTYPE | M_ITYPE;
		
		
		if (DEC_PIPE[10:8] == EXE_PIPE[13:11] & |EXE_PIPE[13:11] & EREG_WRITE) ALU_OP1 = EXE_RES;
		else if (DEC_PIPE[10:8] == MEM_PIPE[13:11] & |EXE_PIPE[13:11] & EREG_WRITE) ALU_OP1 = MEM_RES;
		else ALU_OP1 = OPERATOR_1;
		
		if (DEC_PIPE[2:0] == EXE_PIPE[13:11] & |EXE_PIPE[13:11] & EREG_WRITE & D_RTYPE) ALU_OP2 = EXE_RES;
		else if (DEC_PIPE[2:0] == MEM_PIPE[13:11] & |EXE_PIPE[13:11] & EREG_WRITE & D_RTYPE) ALU_OP2 = MEM_RES;
		else ALU_OP2 = OPERATOR_2;
	end
	
	integer i;
	
	always @(posedge clk or negedge reset) begin
		if (!reset) begin
			for (i = 0; i < 7; i = i + 1) begin
				 REGISTRADORES[i] <= 0;
			end
			REGISTRADORES[7] <= 8'hff;
			FETCH_PIPE <= 0;
			EXE_PIPE <= 0;
			EXE_RES <= 0;
			ZERO_FLAG <= 0;
			MEM_PIPE <= 0;
			MEM_RES <= 0;
			R_data <= 0;
			W_data <= 0;
			byte_enable <= 0;
		end
		else begin 
			
			//FETCH
			if (OPCODE_E == BX) REGISTRADORES[1] <= REGISTRADORES[EXE_PIPE[2:0]];
			else if (BRANCH) REGISTRADORES[1] <= EXE_RES[7:0];
			else if (MEMORY_HAZARD) REGISTRADORES[1] <= REGISTRADORES[1];
			else REGISTRADORES[1] <= REGISTRADORES[1] + 8'd4;
			
			if (OPCODE_F == BL) REGISTRADORES[6] <= REGISTRADORES[1];
			
			if (MEMORY_HAZARD) FETCH_PIPE <= FETCH_PIPE;
			else if (BRANCH) FETCH_PIPE <= 0;
			else FETCH_PIPE <= instruction_code[18:0];
			
			//EXECUTE
			if (BRANCH) EXE_PIPE <= 0;
			else EXE_PIPE <= DEC_PIPE;
			
			EXE_RES <= ALU_RES;
			
			if (D_RTYPE | D_ITYPE | CMP) ZERO_FLAG <= ZERO_S;
			
			
			//MEMORY
			MEM_PIPE <= EXE_PIPE;
			MEM_RES <= EXE_RES;
			
			write_enable <= (OPCODE_E == STR);
			W_data <= REGISTRADORES[EXE_PIPE[13:11]];
			
			case (EXE_PIPE[1:0])
				0:	begin 
					R_data <= data_read[7:0];
					byte_enable <= 4'b0001;
				end
				1:	begin
					R_data <= data_read[15:8];
					byte_enable <= 4'b0010;
				end
				2:	begin 
					R_data <= data_read[23:16];
					byte_enable <= 4'b0100;
				end
				3:	begin
					R_data <= data_read[31:24];
					byte_enable <= 4'b1000;
				end
				default: begin
					R_data <= R_data;
					byte_enable <= 0;
				end
			endcase
			
			//WRITE-BACK
			if (|MEM_PIPE[13:11]) begin
				if (OPCODE_M == LOAD) begin
					REGISTRADORES[MEM_PIPE[13:11]] <= R_data;		
				end 
				else if (ALU_WRITE) begin
					REGISTRADORES[MEM_PIPE[13:11]] <= MEM_RES;
				end
			end
		end
	end
	
	always @(negedge clk or negedge reset) begin
		if (!reset) begin
			DEC_PIPE <= 0;
			OPERATOR_1 <= 0;
			OPERATOR_2 <= 0;
		end
		else if (BRANCH) begin
			DEC_PIPE <= 0;
			OPERATOR_1 <= 0;
			OPERATOR_2 <= 0;
		end else begin
			//DECODE
			if (MEMORY_HAZARD) DEC_PIPE <= 0;
			else DEC_PIPE <= FETCH_PIPE;
			
			OPERATOR_1 <= 	(BRANCH) ? REGISTRADORES[1] :
								REGISTRADORES[FETCH_PIPE[10:8]];
			OPERATOR_2 <= 	(F_RTYPE) ? REGISTRADORES[FETCH_PIPE[2:0]] :
								(OPCODE_F == CMP) ? REGISTRADORES[FETCH_PIPE[13:11]] :
								FETCH_PIPE[7:0];
		end
	end
	
	
	ALU(
		.op1(ALU_OP1),
		.op2(ALU_OP2),
		.operation(OPCODE_D),
		.is_signed(D_RTYPE | D_ITYPE),
		.result(ALU_RES),
		.ZERO(ZERO_S)	
	);
	
endmodule
