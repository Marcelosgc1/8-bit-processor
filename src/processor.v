module processor(
	input clk, reset,
	input [31:0] instruction_code,
	input [31:0] data_read,
	output reg [7:0] program_counter,
	output reg [7:0] access_address,
	output [7:0] data_write,
	output reg [3:0] byte_enable,
	output reg write_enable,
	output reg [64:0] debug_reg
);


	localparam 	NOP 	= 5'b00000,
					B 		= 5'b00001,
					BEQ 	= 5'b00010,
					ADD 	= 5'b00011,
					SUB 	= 5'b00100,
					LOAD 	= 5'b00101,
					STR 	= 5'b00110,
					ADDI 	= 5'b00111,
					BX		= 5'b01000,
					BL		= 5'b01001,
					AND	= 5'b01010,
					ORR	= 5'b01011,
					ANDI	= 5'b01100,
					ORRI	= 5'b01101,
					LSL	= 5'b01110,
					LSR	= 5'b01111,
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
	reg [2:0]  ALU_CODE;
	reg BRANCH, UNC_BRANCH, COND_BRANCH, FUNC_RETURN, BR_LINK, CMP_CODE;
	reg F_STR_OP, F_LOAD_OP;
	
	reg [13:0] DEC_PIPE;
	reg [7:0]  OPERATOR_1, OPERATOR_2;
	reg [2:0]  D_ALU_CODE;
	reg D_UNC_BRANCH, D_COND_BRANCH, D_FUNC_RETURN, D_CMP_CODE;
	reg D_STR_OP, D_LOAD_OP;
	
	reg [13:0] EXE_PIPE;
	reg [7:0] EXE_RES;
	wire [7:0] ALU_RES;
	wire ZERO_S;
	reg ZERO_FLAG;
	reg E_UNC_BRANCH, E_COND_BRANCH, E_FUNC_RETURN;
	reg E_STR_OP, E_LOAD_OP;

	reg [13:0] MEM_PIPE;
	reg [7:0] MEM_RES;
	reg [7:0] R_data;
	reg [7:0] W_data;
	reg M_LOAD_OP;
	
	reg MEMORY_HAZARD, F_RTYPE, D_RTYPE, E_RTYPE, M_RTYPE, F_ITYPE, D_ITYPE, E_ITYPE, M_ITYPE, MREG_WRITE, EREG_WRITE, FREG_WRITE, DREG_WRITE, 
	F_ALU_WRITE, D_ALU_WRITE, E_ALU_WRITE, M_ALU_WRITE, MEM_WRITE;
	
	reg [7:0] ALU_OP1, ALU_OP2;
	reg [4:0] OPCODE_F;
	
	
	always @(*) begin	
		//DEBUG
		debug_reg[0+:8] = REGISTRADORES[1];
		debug_reg[8+:8] = REGISTRADORES[2];
		debug_reg[16+:5] = FETCH_PIPE[18:14];
		debug_reg[60] = (F_ITYPE);
		debug_reg[61] = (D_ITYPE);
		debug_reg[62] = (E_ITYPE);
		debug_reg[63] = (M_ITYPE);
	
		
		//flags
		program_counter = REGISTRADORES[1];
		access_address = EXE_RES;
		write_enable = E_STR_OP;
		W_data = REGISTRADORES[EXE_PIPE[13:11]];
			
	
		OPCODE_F = FETCH_PIPE[18:14];

		
		FUNC_RETURN = (OPCODE_F == BX);
		BR_LINK     = (OPCODE_F == BL);
		UNC_BRANCH 	= (OPCODE_F == B | FUNC_RETURN | BR_LINK);
		COND_BRANCH = (OPCODE_F == BEQ);
		CMP_CODE    = (OPCODE_F == CMP);
		
		
		
		case (OPCODE_F)
			BEQ: begin
				ALU_CODE = 3'd001;
			end
			B: begin
				ALU_CODE = 3'd001;
			end
			BL: begin
				ALU_CODE = 3'd001;
			end
			CMP: begin
				ALU_CODE = 3'd010;
			end
			ADD: begin
				ALU_CODE = 3'd001;
			end
			SUB: begin
				ALU_CODE = 3'd010;
			end
			LOAD: begin
				ALU_CODE = 3'd001;
			end
			STR: begin
				ALU_CODE = 3'd001;
			end
			ADDI: begin
				ALU_CODE = 3'd001;
			end
			AND: begin
				ALU_CODE = 3'd011;
			end
			ANDI: begin
				ALU_CODE = 3'd011;
			end
			ORR: begin
				ALU_CODE = 3'd100;
			end
			ORRI: begin
				ALU_CODE = 3'd100;
			end
			LSL: begin
				ALU_CODE = 3'd101;
			end
			LSR: begin
				ALU_CODE = 3'd110;
			end
			default: ALU_CODE = 0;
		endcase

		
		
		
		BRANCH = (E_UNC_BRANCH | (E_COND_BRANCH & ZERO_FLAG));
		
		
		
		F_RTYPE = (OPCODE_F == ADD | OPCODE_F == SUB | OPCODE_F == AND | OPCODE_F == ORR);
		F_ITYPE = (OPCODE_F == ADDI | OPCODE_F == ANDI | OPCODE_F == ORRI | OPCODE_F == LSL | OPCODE_F == LSR);
		
		F_STR_OP  = (OPCODE_F == STR);
		F_LOAD_OP = (OPCODE_F == LOAD);
		
	
		MEMORY_HAZARD = 	(D_LOAD_OP) & 
								(FETCH_PIPE[10:8] == DEC_PIPE[13:11] | (FETCH_PIPE[10:8] == DEC_PIPE[2:0] & F_RTYPE));
		
		
		F_ALU_WRITE = (F_RTYPE | F_ITYPE);
		FREG_WRITE  = (F_LOAD_OP | F_ALU_WRITE);
		
		
		
		if (DEC_PIPE[10:8] == EXE_PIPE[13:11] & |EXE_PIPE[13:11] & EREG_WRITE) ALU_OP1 = EXE_RES;
		else if (DEC_PIPE[10:8] == MEM_PIPE[13:11] & |EXE_PIPE[13:11] & MREG_WRITE) ALU_OP1 = MEM_RES;
		else ALU_OP1 = OPERATOR_1;
		
		if (DEC_PIPE[2:0] == EXE_PIPE[13:11] & |EXE_PIPE[13:11] & EREG_WRITE & D_RTYPE) ALU_OP2 = EXE_RES;
		else if (DEC_PIPE[2:0] == MEM_PIPE[13:11] & |EXE_PIPE[13:11] & MREG_WRITE & D_RTYPE) ALU_OP2 = MEM_RES;
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
			E_RTYPE <= 0;
			E_ITYPE <= 0;
			E_STR_OP <= 0;
			E_LOAD_OP <= 0;
			EREG_WRITE <= 0;
			E_ALU_WRITE <= 0;
			E_UNC_BRANCH <= 0;
			E_COND_BRANCH <= 0; 
			E_FUNC_RETURN <= 0;
			MEM_PIPE <= 0;
			MEM_RES <= 0;
			M_RTYPE <= 0;
			M_ITYPE <= 0;
			M_LOAD_OP <= 0;
			MREG_WRITE <= 0;
			M_ALU_WRITE <= 0;
			
			
			
			//DEBUG
			debug_reg[64] <= 0;
		end
		else begin 
			//DEBUG
			if (OPCODE_F == ADDI) debug_reg[64] <= 1;
			
			
			//FETCH
			if (E_FUNC_RETURN) REGISTRADORES[1] <= REGISTRADORES[EXE_PIPE[2:0]];
			else if (BRANCH) REGISTRADORES[1] <= EXE_RES[7:0];
			else if (MEMORY_HAZARD) REGISTRADORES[1] <= REGISTRADORES[1];
			else REGISTRADORES[1] <= REGISTRADORES[1] + 8'd4;
			
			if (BR_LINK) REGISTRADORES[6] <= REGISTRADORES[1];
			
			if (MEMORY_HAZARD) FETCH_PIPE <= FETCH_PIPE;
			else if (BRANCH) FETCH_PIPE <= 0;
			else FETCH_PIPE <= instruction_code[18:0];
			
			//EXECUTE
			if (BRANCH) begin 
				EXE_PIPE <= 0;
				E_RTYPE <= 0;
				E_ITYPE <= 0;
				E_STR_OP <= 0;
				E_LOAD_OP <= 0;
				EREG_WRITE <= 0;
				E_ALU_WRITE <= 0;
				E_UNC_BRANCH <= 0;
				E_COND_BRANCH <= 0; 
				E_FUNC_RETURN <= 0;
			end else begin 
				EXE_PIPE <= DEC_PIPE;
				E_RTYPE <= D_RTYPE;
				E_ITYPE <= D_ITYPE;
				E_STR_OP <= D_STR_OP;
				E_LOAD_OP <= D_LOAD_OP;
				EREG_WRITE <= DREG_WRITE;
				E_ALU_WRITE <= D_ALU_WRITE;
				E_UNC_BRANCH <= D_UNC_BRANCH;
				E_COND_BRANCH <= D_COND_BRANCH; 
				E_FUNC_RETURN <= D_FUNC_RETURN;
			end
			
			EXE_RES <= ALU_RES;
			
			if (D_RTYPE | D_ITYPE | D_CMP_CODE) ZERO_FLAG <= ZERO_S;
			
			
			//MEMORY
			MEM_PIPE <= EXE_PIPE;
			MEM_RES <= EXE_RES;
			M_RTYPE <= E_RTYPE;
			M_ITYPE <= E_ITYPE;
			M_LOAD_OP <= E_LOAD_OP;
			MREG_WRITE <= EREG_WRITE;
			M_ALU_WRITE <= E_ALU_WRITE;
			
//			write_enable <= E_STR_OP;
//			W_data <= REGISTRADORES[EXE_PIPE[13:11]];
			
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
				if (M_LOAD_OP) begin
					REGISTRADORES[MEM_PIPE[13:11]] <= R_data;		
				end 
				else if (M_ALU_WRITE) begin
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
			D_RTYPE <= 0;
			D_ITYPE <= 0;
			D_STR_OP <= 0;
			D_LOAD_OP <= 0;
			DREG_WRITE <= 0;
			D_ALU_WRITE <= 0;
			D_UNC_BRANCH <= 0;
			D_COND_BRANCH <= 0; 
			D_FUNC_RETURN <= 0;
			D_CMP_CODE <= 0;
			D_ALU_CODE <= 0;
		end
		else if (BRANCH) begin
			DEC_PIPE <= 0;
			OPERATOR_1 <= 0;
			OPERATOR_2 <= 0;
			D_RTYPE <= 0;
			D_ITYPE <= 0;
			D_STR_OP <= 0;
			D_LOAD_OP <= 0;
			DREG_WRITE <= 0;
			D_ALU_WRITE <= 0;
			D_UNC_BRANCH <= 0;
			D_COND_BRANCH <= 0; 
			D_FUNC_RETURN <= 0;
			D_CMP_CODE <= 0;
			D_ALU_CODE <= 0;
		end else begin
			//DECODE
			if (MEMORY_HAZARD) begin
				DEC_PIPE <= 0;
				D_RTYPE <= 0;
				D_ITYPE <= 0;
				D_STR_OP <= 0;
				D_LOAD_OP <= 0;
				DREG_WRITE <= 0;
				D_ALU_WRITE <= 0;
				D_UNC_BRANCH <= 0;
				D_COND_BRANCH <= 0; 
				D_FUNC_RETURN <= 0;
				D_CMP_CODE <= 0;
				D_ALU_CODE <= 0;
			end else begin
				DEC_PIPE <= FETCH_PIPE[13:0];
				D_RTYPE <= F_RTYPE;
				D_ITYPE <= F_ITYPE;
				D_STR_OP <= F_STR_OP;
				D_LOAD_OP <= F_LOAD_OP;
				DREG_WRITE <= FREG_WRITE;
				D_ALU_WRITE <= F_ALU_WRITE;
				D_UNC_BRANCH <= UNC_BRANCH;
				D_COND_BRANCH <= COND_BRANCH; 
				D_FUNC_RETURN <= FUNC_RETURN;
				D_CMP_CODE <= CMP_CODE;
				D_ALU_CODE <= ALU_CODE;
			end
			
			OPERATOR_1 <= 	(BRANCH) ? REGISTRADORES[1] :
								REGISTRADORES[FETCH_PIPE[10:8]];
			OPERATOR_2 <= 	(F_RTYPE) ? REGISTRADORES[FETCH_PIPE[2:0]] :
								(CMP_CODE) ? REGISTRADORES[FETCH_PIPE[13:11]] :
								FETCH_PIPE[7:0];
		end
	end
	
	
	ALU(
		.op1(ALU_OP1),
		.op2(ALU_OP2),
		.operation(D_ALU_CODE),
		.is_signed(D_RTYPE | D_ITYPE),
		.result(ALU_RES),
		.ZERO(ZERO_S)	
	);
	
endmodule
