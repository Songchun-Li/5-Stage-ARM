module ctrl_logic
  ( input [31:0] instr_i
  , input [31:0] cpsr_i
  , input [31:0] pc_r_i
  , output wire ctrl_data_reg_wr_en_o
  , output wire ctrl_mem_wr_en_o
  , output wire ctrl_cpsr_en_o
  , output wire ctrl_branch_sel_o
  , output wire writeback_sel_o
  , output wire reg2_sel_o
  , output wire ctrl_mem_rd_en_o
  , output wire shifter_en_o
  , output wire [3:0] cond_o
  , output wire [31:0] pc_plus4_o
  , output reg [1:0] alu_src_sel_o
  , output reg [3:0] opcode_o
  , output reg [3:0] rn_addr_o
  , output reg [3:0] rdest_addr_o
  , output reg [3:0] rm_addr_o
  , output reg [31:0] offset_shift_o
  , output reg [31:0] mem_offset_o
  , output wire using_data_reg_1_o
  , output reg using_data_reg_2_o
  );


  assign cond_o = instr_i[31:28];

  reg [23:0] branch_offset;
  reg [31:0] offset_ext;

  wire mem_instr_flag;
  assign mem_instr_flag = (instr_i[27:26] == 2'b01);
  wire data_proc_flag;
  assign data_proc_flag = (instr_i[27:26] == 2'b00);
  wire branch_flag;
  assign branch_flag = (instr_i[27:25] == 3'b101);

  assign pc_plus4_o = pc_r_i + 4;

  always @ (*) begin
    if (branch_flag && instr_i[24]) begin //implemnt mov pc + 4 to lr
      rn_addr_o = 4'd0;  // base_reg
      rdest_addr_o = 4'b1110;
      end
    else begin
      rn_addr_o = instr_i[19:16];  // base_reg
      rdest_addr_o = instr_i[15:12];
      end
    end

  always @ (*) begin
    if (branch_flag && instr_i[24])
      opcode_o = 4'b1101;   // move pc + 4, to lr
    else if (mem_instr_flag && instr_i[23]) // offset up, use add to get address
      opcode_o = 4'b0100;
    else if (mem_instr_flag && !instr_i[23]) // offset down, use sub to get address
      opcode_o = 4'b0010;
    else
      opcode_o = instr_i[24:21];
  end

  always @ (*) begin
    rm_addr_o = instr_i[3:0];   //optional reg
    // branch related
    branch_offset = instr_i[23:0];
    offset_ext = {{8{branch_offset[23]}}, branch_offset};
    offset_shift_o = offset_ext << 2;  // shft left by 2 bits
    // load_store related
    mem_offset_o = {{20{instr_i[11]}}, instr_i[11:0]};
  end

  reg alu_to_reg_en;
  always @ (*) begin
    alu_to_reg_en = 1'b0;
    case(opcode_o)
      4'b0000: alu_to_reg_en = 1'b1;
      4'b0001: alu_to_reg_en = 1'b1;
      4'b0011: alu_to_reg_en = 1'b1;
      4'b0100: alu_to_reg_en = 1'b1;
      4'b0010: alu_to_reg_en = 1'b1;
      4'b0101: alu_to_reg_en = 1'b1;
      4'b0111: alu_to_reg_en = 1'b1;
      4'b0110: alu_to_reg_en = 1'b1;
      4'b1000: alu_to_reg_en = 1'b0;
      4'b1001: alu_to_reg_en = 1'b0;
      4'b1010: alu_to_reg_en = 1'b0;
      4'b1011: alu_to_reg_en = 1'b0;
      4'b1100: alu_to_reg_en = 1'b1;
      4'b1101: alu_to_reg_en = 1'b1;
      4'b1110: alu_to_reg_en = 1'b1;
      4'b1111: alu_to_reg_en = 1'b1;
      default: alu_to_reg_en = 1'b0;
    endcase
    end

  always @ (*) begin
    if (mem_instr_flag && !instr_i[25]) begin// 00:mem_offset:, 01:pc + 4 10:read data2
      alu_src_sel_o = 2'b00;
      using_data_reg_2_o = !instr_i[20]; //store will use reg2, load will not use, instr[20] is load
      // using_data_reg_2_o = 0;
      end
    else if (branch_flag && instr_i[24]) begin
      alu_src_sel_o = 2'b01;
      using_data_reg_2_o = 0;
      end
    else begin
      alu_src_sel_o = 2'b10;
      using_data_reg_2_o = 1;
      end
  end

  assign ctrl_branch_sel_o = branch_flag;
  assign writeback_sel_o = mem_instr_flag && instr_i[20]; // 1: mem to reg, 0:alu output
  assign reg2_sel_o = mem_instr_flag && !instr_i[20];   // the read addr for 2nd data reg read port is destination for store only

  assign ctrl_mem_wr_en_o = reg2_sel_o;
  assign ctrl_cpsr_en_o = data_proc_flag && instr_i[20];  // [27:26] == 00 and set bit = 1
  assign ctrl_mem_rd_en_o = writeback_sel_o;

                                          //alu res                       // load        //bl
  assign ctrl_data_reg_wr_en_o = (data_proc_flag && alu_to_reg_en) || (writeback_sel_o) || (branch_flag && instr_i[24]);


  assign shifter_en_o = data_proc_flag || (mem_instr_flag && instr_i[25] && !instr_i[4]); //instr_i[4] == 1 is undefined
  // mov and inv instr does not use op1
  assign using_data_reg_1_o = (!((opcode_o == 4'b1111) || (opcode_o == 4'b1101)) && data_proc_flag) || mem_instr_flag;
  endmodule
