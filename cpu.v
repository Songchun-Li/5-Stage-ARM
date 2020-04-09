

module cpu(
  input wire clk,
  input wire nreset,
  output wire led,
  output wire [7:0] debug_port1,
  output wire [7:0] debug_port2,
  output wire [7:0] debug_port3,
  output wire [7:0] debug_port4,
  output wire [7:0] debug_port5,
  output wire [7:0] debug_port6,
  output wire [7:0] debug_port7
  );

  /*
  instructions supported:
  add, sub, eor, mvn, orr, tst, teq, bic, cmp
  ldr,str (pre-indexing no write back)
  conditional btanch, bl
  /////////////////////////
  pipeline summary
  5 stage:
  IF: instruction fetch
  ID: instruction decode & control logic
  EXEC: alu and shifter
  MEM: data memory read and write
  WB: data register write back
  */

  // Controls the LED on the board. LED on, if a branch implemented
  assign led = pc_not_plus_4;

  // These are how you communicate back to the serial port debugger.
  wire [31:0] debug_out;
  reg [31:0] debug_word;
  assign debug_port1 = pc_r[7:0];
  assign debug_port2 = pc_IDEXEC_r[7:0]; // The real executing instr
  assign debug_port3 = 8'd0;
  assign debug_port4 = debug_word[31:24];
  assign debug_port5 = debug_word[23:16];
  assign debug_port6 = debug_word[15:8];
  assign debug_port7 = debug_word[7:0];

  always @(*) begin
    if (pc_not_plus_4)
     debug_word = 32'hffffffff;
    else
      debug_word = alu_res;
    end

  reg [31:0] pc_r;
  reg [31:0] cpsr_r;
  // pipeline control signal
  reg pc_update_en, instr_mem_read_en, IFID_forward_en, IDEXEC_forward_en, EXECMEM_forward_en, MEMWB_forward_en;

  //datapath signal
  wire carry_shifted;
  wire [31:0] curr_instr;
  wire [3:0] rdest_addr, rn_addr, rm_addr, cond;
  wire [31:0] offset_shift;
  wire [31:0] rd_data1, rd_data2;
  wire [31:0]  wr_mem_data, wr_mem_addr, alu_res;
  wire [31:0] mem_offset;
  wire [31:0] wb_data;
  //
  reg stall_at_IFID, stall_at_EXECMEM;
  //////////////////////////////////////////////////////////////////////////////
  // Instruction fetch/ Instruction decode
  //////////////////////////////////////////////////////////////////////////////
  // goes into instruction memory
  wire [3:0] reg1_addr_IF, reg2_addr_IF;
  // passed to next stage
  reg [3:0] rdest_addr_IFID_r, opcode_IFID_r, cond_IFID_r, reg1_addr_IFID_r, reg2_addr_IFID_r;
  reg data_reg_wr_en_IFID_r, mem_wr_en_IFID_r, cpsr_en_IFID_r, branch_sel_IFID_r, writeback_sel_IFID_r,
      mem_rd_en_IFID_r, shifter_en_IFID_r;
  reg using_data_reg_1_IFID_r, using_data_reg_2_IFID_r;
  reg [1:0] alu_src_sel_IFID_r;
  reg [31:0] pc_plus4_IFID_r, offset_shift_IFID_r, mem_offset_IFID_r, pc_IFID_r;
  reg [31:0] IFID_instr_r;

  // control signals
  wire ctrl_data_reg_wr_en, ctrl_mem_wr_en, ctrl_cpsr_en, ctrl_mem_rd_en;
  wire ctrl_branch_sel, reg2_sel, writeback_sel, shifter_en;
  wire using_data_reg_1, using_data_reg_2;
  wire [1:0] alu_src_sel;
  wire [3:0] opcode;
  wire [31:0] pc_plus4;
  //////////////////////////////////////////////////////////////////////////////
  // Instruction decode/ Execution
  //////////////////////////////////////////////////////////////////////////////
  reg [31:0] rd_data1_IDEXEC_r, rd_data2_IDEXEC_r, alu_op2_IDEXEC, offset_shift_IDEXEC_r, pc_IDEXEC_r;
  reg cpsr_en_IDEXEC_r, branch_sel_IDEXEC_r, shifter_en_IDEXEC_r, data_reg_wr_en_IDEXEC_r, mem_wr_en_IDEXEC_r;
  reg writeback_sel_IDEXEC_r, mem_rd_en_IDEXEC_r;
  reg using_data_reg_1_IDEXEC_r, using_data_reg_2_IDEXEC_r;
  reg [3:0] rdest_addr_IDEXEC_r, opcode_IDEXEC_r, cond_IDEXEC_r, reg1_addr_IDEXEC_r, reg2_addr_IDEXEC_r;
  reg [31:0] IDEXEC_instr_r, mem_offset_IDEXEC_r, pc_plus4_IDEXEC_r;
  wire [31:0] alu_op2_shifted;
  reg [1:0] alu_src_sel_IDEXEC_r;
  //////////////////////////////////////////////////////////////////////////////
  // Execution / Memory Op
  //////////////////////////////////////////////////////////////////////////////
  // goes to data memory
  reg [31:0] rd_data2_EXECMEM;
  reg mem_wr_en_EXECMEM, mem_rd_en_EXECMEM, branch_sel_EXECMEM_r, cond_matched_EXECMEM_r;
  // pass to next stages
  reg [31:0] alu_res_EXECMEM_r;
  reg [3:0] rdest_addr_EXECMEM_r;
  reg writeback_sel_EXECMEM_r, data_reg_wr_en_EXECMEM_r;
  reg using_data_reg_1_EXECMEM_r, using_data_reg_2_EXECMEM_r;
  // result obtained in this stage
  wire [31:0] mem_rd_data;
  reg [31:0] pc_EXECMEM_r, offset_shift_EXECMEM_r;
  //////////////////////////////////////////////////////////////////////////////
  // Memory Op / Writeback
  //////////////////////////////////////////////////////////////////////////////
  reg [31:0] rdest_addr_MEMWB_r;
  reg data_reg_wr_en_MEMWB_r;

  /*
  state1 pc update
  state2 instruction fetched and decoded
  state3 execution           state_mem_wr_en = 1, state_mem_rd_en = 1, state_cpsr_en
  state4 memory operation   state_data_reg_wr_en = 1
  state5 writeback          state_pc_en = 1
  state summary
  000: instr fetch
  001: instr decode
  010: execution
  011: memory
  100: write back
  101:reset
  */

  //pc updater
  // to squash a instrction, the easiest way is to
  reg instr_squash_r;
  always @ (posedge clk) begin
    if (!nreset) begin
       pc_r <= 32'h00000000;
       instr_squash_r <= 0;
       end
    else if (pc_update_en) begin    // pc_update_en = 0 when the pipeline is stalled
        if(pc_not_plus_4) begin // TODO pc_not_plus_4_EXECMEM_r also indicate that the fetched instructions should be squashed
          pc_r <= pc_overwrite;
          instr_squash_r <= 1;
          end
        else begin
          pc_r <= pc_r + 4; // not branch or write to data_reg[15], just keep increasing
          instr_squash_r <= 0;
          end
      end
  end
  //////////////////////////////////////////////////////////////////////////////
  // instruction fetch
  //////////////////////////////////////////////////////////////////////////////
  //data path design
  instr_mem the_instr_mem
    (.pc_i(pc_r)
    ,.clk_i(clk)
    ,.instr_mem_read_en_i(instr_mem_read_en)
    ,.instr_o(curr_instr)
    );
  reg [31:0] pc_IF_r;
  always @(posedge clk) begin
    if (instr_mem_read_en)
      pc_IF_r <= pc_r;
    else pc_IF_r <= pc_IF_r;
    end

  ctrl_logic the_ctrl_logic
    (.instr_i(curr_instr)
    ,.cpsr_i(cpsr_r)
    ,.pc_r_i(pc_IF_r)
    ,.ctrl_data_reg_wr_en_o(ctrl_data_reg_wr_en)
    ,.ctrl_mem_wr_en_o(ctrl_mem_wr_en)
    ,.ctrl_cpsr_en_o(ctrl_cpsr_en)
    ,.ctrl_branch_sel_o(ctrl_branch_sel)
    ,.writeback_sel_o(writeback_sel)
    ,.ctrl_mem_rd_en_o(ctrl_mem_rd_en)
    ,.alu_src_sel_o(alu_src_sel)
    ,.reg2_sel_o(reg2_sel)
    ,.shifter_en_o(shifter_en)
    ,.opcode_o(opcode)
    ,.rn_addr_o(rn_addr)
    ,.rdest_addr_o(rdest_addr)
    ,.rm_addr_o(rm_addr)
    ,.pc_plus4_o(pc_plus4)
    ,.offset_shift_o(offset_shift)
    ,.mem_offset_o(mem_offset)
    ,.cond_o(cond)
    ,.using_data_reg_1_o(using_data_reg_1)
    ,.using_data_reg_2_o(using_data_reg_2)
    );

  reg mem_wr_en, data_reg_wr_en, cpsr_en, branch_sel;
  always @(*) begin
  // make the instruction fetched at jumping to be useless
    mem_wr_en = ctrl_mem_wr_en && !instr_squash_r;
    data_reg_wr_en = ctrl_data_reg_wr_en && !instr_squash_r;
    cpsr_en = ctrl_cpsr_en && !instr_squash_r;
    branch_sel = ctrl_branch_sel && !instr_squash_r;
    end

  assign reg2_addr_IF = reg2_sel ? rdest_addr : rm_addr;
  assign reg1_addr_IF = rn_addr;



  //////////////////////////////////////////////////////////////////////////////
  // Instruction fetch/ Instruction decode
  //////////////////////////////////////////////////////////////////////////////
  always @ (posedge clk) begin
    if (IFID_forward_en) begin
      // datapath passing throuth
      rdest_addr_IFID_r <= rdest_addr;
      opcode_IFID_r <= opcode;
      pc_plus4_IFID_r <= pc_plus4;
      offset_shift_IFID_r <= offset_shift;
      mem_offset_IFID_r <= mem_offset;
      IFID_instr_r <= curr_instr;
      pc_IFID_r <= pc_IF_r;
      cond_IFID_r <= cond;
      reg1_addr_IFID_r <= reg1_addr_IF;
      reg2_addr_IFID_r <= reg2_addr_IF;
      using_data_reg_1_IFID_r <= using_data_reg_1;
      using_data_reg_2_IFID_r <= using_data_reg_2;
      // controlling signal passing through
      mem_rd_en_IFID_r <= ctrl_mem_rd_en;
      mem_wr_en_IFID_r <= mem_wr_en && !pc_not_plus_4;
      data_reg_wr_en_IFID_r <= data_reg_wr_en && !pc_not_plus_4;
      cpsr_en_IFID_r <= cpsr_en && !pc_not_plus_4;
      branch_sel_IFID_r <= branch_sel && !pc_not_plus_4;
      writeback_sel_IFID_r <= writeback_sel;
      alu_src_sel_IFID_r <= alu_src_sel;
      shifter_en_IFID_r <= shifter_en;
      end
      else if (stall_at_IFID) begin
      // this mean the stage is stalled
      mem_wr_en_IFID_r <= 0;
      data_reg_wr_en_IFID_r <= 0;
      cpsr_en_IFID_r <= 0;
      branch_sel_IFID_r <= 0;
      end
    end

  datareg2r1w datareg
    (.rd_addr1_i(reg1_addr_IF)
    ,.rd_addr2_i(reg2_addr_IF)
    ,.wr_data_i(wb_data)
    ,.wr_addr_i(rdest_addr_EXECMEM_r)
    ,.wr_en_i(data_reg_wr_en_EXECMEM_r)
    ,.clk_i(clk)
    ,.rd_data1_o(rd_data1)
    ,.rd_data2_o(rd_data2)
    );

  //////////////////////////////////////////////////////////////////////////////
  // Instruction decode/ Execution
  //////////////////////////////////////////////////////////////////////////////
  // Data forward related
  reg [31:0] data_forwarded_from_alu_r, data_forwarded_from_wb_data_r;
  // forwarded data still update during stalling
  always @(posedge clk) begin
    data_forwarded_from_alu_r <= alu_res;
    data_forwarded_from_wb_data_r <= wb_data;
    end
  reg rd_data1_use_alu_forward, rd_data1_use_wb_data_forward, rd_data2_use_alu_forward, rd_data2_use_wb_data_forward;

  always @(posedge clk) begin
    if (IDEXEC_forward_en) begin
      // datapath
      rd_data1_IDEXEC_r <= rd_data1;
      rd_data2_IDEXEC_r <= rd_data2;
      opcode_IDEXEC_r <= opcode_IFID_r;
      alu_src_sel_IDEXEC_r <= alu_src_sel_IFID_r;

      IDEXEC_instr_r <= IFID_instr_r;
      // control signal
      cpsr_en_IDEXEC_r <= cpsr_en_IFID_r && !pc_not_plus_4;
      branch_sel_IDEXEC_r <= branch_sel_IFID_r && !pc_not_plus_4;
      shifter_en_IDEXEC_r <= shifter_en_IFID_r;
      // datapath passing throuth
      rdest_addr_IDEXEC_r <= rdest_addr_IFID_r;
      offset_shift_IDEXEC_r <= offset_shift_IFID_r;
      pc_IDEXEC_r <= pc_IFID_r;
      cond_IDEXEC_r <= cond_IFID_r;
      mem_offset_IDEXEC_r <= mem_offset_IFID_r;
      pc_plus4_IDEXEC_r <= pc_plus4_IFID_r;
      // for pipeline control
      reg1_addr_IDEXEC_r <= reg1_addr_IFID_r;
      reg2_addr_IDEXEC_r <= reg2_addr_IFID_r;
      using_data_reg_1_IDEXEC_r <= using_data_reg_1_IFID_r;
      using_data_reg_2_IDEXEC_r <= using_data_reg_2_IFID_r;
      // controlling signal passing through
      mem_wr_en_IDEXEC_r <= mem_wr_en_IFID_r && !pc_not_plus_4;
      mem_rd_en_IDEXEC_r <= mem_rd_en_IFID_r;
      writeback_sel_IDEXEC_r <= writeback_sel_IFID_r;
      data_reg_wr_en_IDEXEC_r <= data_reg_wr_en_IFID_r && !pc_not_plus_4;
      end
    end

  // overwrite the alu input accordng to pipeline control
  wire shifter_en_wcond;
  assign shifter_en_wcond = shifter_en_IDEXEC_r && cond_matched;
  reg [31:0] rd_data1_overwritten, rd_data2_overwritten;
  always @(*) begin // overwrite the two register
    rd_data1_overwritten = rd_data1_IDEXEC_r;
    rd_data2_overwritten = rd_data2_IDEXEC_r;
    if (rd_data1_use_alu_forward)
      rd_data1_overwritten = data_forwarded_from_alu_r;
    if (rd_data1_use_wb_data_forward)
      rd_data1_overwritten = data_forwarded_from_wb_data_r;
    if (rd_data2_use_alu_forward)
      rd_data2_overwritten = data_forwarded_from_alu_r;
    if (rd_data2_use_wb_data_forward)
      rd_data2_overwritten = data_forwarded_from_wb_data_r;
    case(alu_src_sel_IDEXEC_r) // 00:mem_offset:, 01:pc + 4 10:read data2
      2'b00: alu_op2_IDEXEC = mem_offset_IDEXEC_r;
      2'b01: alu_op2_IDEXEC = pc_plus4_IDEXEC_r;
      default: alu_op2_IDEXEC = rd_data2_overwritten;
    endcase
    end

  wire [31:0] rm_data_to_shifter;
  // assign rm_data_to_shifter = (rd_data2_use_alu_forward || rd_data2_use_wb_data_forward)? alu_op2_IDEXEC : rd_data2_IDEXEC_r;
  assign rm_data_to_shifter = rd_data2_overwritten;
  shifter the_shifter
    (.alu_op2_i(alu_op2_IDEXEC)
    ,.shifter_en_i(shifter_en_wcond)       // from control logic by analyzing the instr
    ,.instr_info_i(IDEXEC_instr_r[27:25])
    ,.immediate_i(IDEXEC_instr_r[11:0])  // loweset 12 bits  in instr
    ,.rm_data_i(rm_data_to_shifter)            // Rm goes to read port 2 except doing store
    ,.carry_in_i(cpsr_r[29])
    ,.alu_op2_o(alu_op2_shifted)
    ,.carry_to_alu_o(carry_shifted)
    );

  wire [3:0] cpsr_n;
  alu the_alu
    (.op1_i(rd_data1_overwritten)
    ,.op2_i(alu_op2_shifted)
    ,.aluop_i(opcode_IDEXEC_r)
    ,.cpsr_i(cpsr_r[31:28])
    ,.carry_shifted_i(carry_shifted)
    ,.out_o(alu_res)
    ,.cpsr_update_o(cpsr_n)
    );

    // checking the condition and overewrite some signals
    // make the instruction not able to write to memory and not able to writeback to register
    reg cond_matched;
    //condition check up
    always @(*) begin
      cond_matched = 1'b0;
      case(cond_IDEXEC_r)
        4'b0000:	cond_matched = cpsr_r[30];   //	euqal Z=1
        4'b0001:	cond_matched = !cpsr_r[30];  //	not equal Z=0
        4'b0010:	cond_matched = cpsr_r[29];   //		C=1
        4'b0011:	cond_matched = cpsr_r[29];   //		C=0
        4'b0100:	cond_matched = cpsr_r[31];   //	negative N=1
        4'b0101:	cond_matched = cpsr_r[31];   //	nonnegative N=0
        4'b0110:	cond_matched = cpsr_r[28];   // overflow V=1
        4'b0111:	cond_matched = !cpsr_r[28];  //	no overflow	V=0
        4'b1000:	cond_matched = cpsr_r[29] && !cpsr_r[30];       // unsigned number larger	C=1 and Z=0
        4'b1001:	cond_matched = !cpsr_r[29] && cpsr_r[30];       // unsigned number small/euqal	C=0 and Z=1
        4'b1010:	cond_matched = !(cpsr_r[31] ^ cpsr_r[28]);     // signed number larger/equal	N=1_and_V=1 or N=0_and_V=0
        4'b1011:	cond_matched = cpsr_r[31] ^ cpsr_r[28];        // signed number smaller	N=1_and_V=0 or N=0_and_V=1
        4'b1100:	cond_matched = !cpsr_r[30] && !(cpsr_r[31] ^ cpsr_r[28]);  // signed number larger	Z=0_and_N=V
        4'b1101:	cond_matched = cpsr_r[30] || (cpsr_r[31] ^ cpsr_r[28]);    // signed number smaller/equal	Z=1 or N!=V
        4'b1110:	cond_matched = 1'b1;
        4'b1111:	cond_matched = 1'b0;
        default:  cond_matched = 1'b0;
      endcase
      end


  //////////////////////////////////////////////////////////////////////////////
  // Execution / Memory Op
  //////////////////////////////////////////////////////////////////////////////
  // update cpsr
  always @ (posedge clk) begin
    if (!nreset)
      cpsr_r <= 32'h00000000;
    // else if (cpsr_en && set_cpsr)
    else if (cpsr_en_IDEXEC_r  && cond_matched)
      cpsr_r[31:28] <= cpsr_n;
  end

  always @(*) begin
    rd_data2_EXECMEM = rd_data2_overwritten; // TODO
    // control signal
    mem_wr_en_EXECMEM = mem_wr_en_IDEXEC_r && cond_matched  && !pc_not_plus_4;
    mem_rd_en_EXECMEM = mem_rd_en_IDEXEC_r && cond_matched  && !pc_not_plus_4;
  end

  data_mem the_data_mem
    (.clk_i(clk)
    ,.addr_i(alu_res)
    ,.wr_data_i(rd_data2_EXECMEM)
    ,.wr_en_i(mem_wr_en_EXECMEM)
    ,.rd_en_i(mem_rd_en_EXECMEM)
    ,.rd_data_o(mem_rd_data)
    );

  always @(posedge clk) begin
    if (EXECMEM_forward_en) begin
      // pipeline moveforward
      // datapath
      alu_res_EXECMEM_r <= alu_res;
      // datapath passing throuth
      rdest_addr_EXECMEM_r <= rdest_addr_IDEXEC_r;
      // controlling signal passing through
      data_reg_wr_en_EXECMEM_r <= data_reg_wr_en_IDEXEC_r && cond_matched  && !pc_not_plus_4;
      writeback_sel_EXECMEM_r <= writeback_sel_IDEXEC_r;
      using_data_reg_1_EXECMEM_r <= using_data_reg_1_IDEXEC_r;
      using_data_reg_2_EXECMEM_r <= using_data_reg_2_IDEXEC_r;
      pc_EXECMEM_r <= pc_IDEXEC_r;
      branch_sel_EXECMEM_r <= branch_sel_IDEXEC_r && !pc_not_plus_4;
      cond_matched_EXECMEM_r <= cond_matched && !pc_not_plus_4;
      offset_shift_EXECMEM_r <= offset_shift_IDEXEC_r;
      end
    else if (stall_at_EXECMEM) begin
    // this mean the stage is stalled
      data_reg_wr_en_EXECMEM_r <= 0;
      branch_sel_EXECMEM_r <= 0;
      end
    end

  assign wb_data = writeback_sel_EXECMEM_r ? mem_rd_data : alu_res_EXECMEM_r; // 1: mem to reg, 0:alu output

  reg [31:0] pc_overwrite;
  reg pc_not_plus_4;
  always @(*) begin
    // default value
    pc_overwrite = pc_EXECMEM_r;
    pc_not_plus_4 = 0;
    if(branch_sel_EXECMEM_r && cond_matched_EXECMEM_r) begin //jump if valid branch operation
      pc_overwrite = pc_EXECMEM_r + 8 + offset_shift_EXECMEM_r; //ctrl_branch_sel=1
      pc_not_plus_4 = 1;
      end
    else begin
      if (data_reg_wr_en_EXECMEM_r && rdest_addr_EXECMEM_r == 4'hf) begin
        pc_overwrite = wb_data;
        pc_not_plus_4 = 1;
        end
    end
  end


  //////////////////////////////////////////////////////////////////////////////
  // Memory Op / Writeback
  //////////////////////////////////////////////////////////////////////////////
  // wb_data goes back to the data register in the next cycle
  // these are just used for pipeline controlling
  always @(posedge clk) begin
    data_reg_wr_en_MEMWB_r <= data_reg_wr_en_EXECMEM_r;
    rdest_addr_MEMWB_r <= rdest_addr_EXECMEM_r;
  end

  //////////////////////////////////////////////////////////////////////////////
  // pipeline control logic
  //////////////////////////////////////////////////////////////////////////////
  // structural hazard
  // happen when the writeback register are read, need to stall the pipeline for one cycle
  // to prevent possible unknown error

  // data hazard
  // using data forwarding to overewrite(no stall required)/update(stall required) the data at ID/EXEC
  // target variable: rd_data1_IDEXEC_r, rd_data2_IDEXEC_r
  // data forwarding source: alu result or data mem read data

  // control hazard
  // PC register is independented from then main data register
  // When a branch is token(pc is overwritten), the instruction will be squashed by making the instr ineffective
  // (make it not to take branch, not to write cpsr reg, data reg and data mem)

  // If a stgae is stalled, all the stage before this stage will be stalled

  // consecutive
  // the later instr is about to execute when the formal instr is about to do data mem oper
  // if formal instr is data processing op, we can forward the result back to exec without stall
  // if formal instr is data mem op, stall one cycle and forward the read data back to exec

  // 1 instrt away
  // the later instr is about to execute when the formal instr is about to write
  // forward the write back data to exec stage without stalling

  // 2 instr away
  // The later instr read when the formal instr is about to write
  // stall the pipeline for one cycle to prevent possible unknown error

  // About NOP
  // When the pipeline is stalled, the stalled boundry will generate same signal as the last signals,
  // except making it unable to branch, write register, memory nor cpsr register
  wire consecutive_flag, one_instr_away_flag, two_instr_away_flag;
  assign consecutive_flag = ( ((reg1_addr_IDEXEC_r == rdest_addr_EXECMEM_r) && using_data_reg_1_IDEXEC_r) || ((reg2_addr_IDEXEC_r == rdest_addr_EXECMEM_r) && using_data_reg_2_IDEXEC_r) ) && data_reg_wr_en_EXECMEM_r;
  assign one_instr_away_flag = ( ((reg1_addr_IDEXEC_r == rdest_addr_MEMWB_r) && using_data_reg_1_IDEXEC_r) || ((reg2_addr_IDEXEC_r == rdest_addr_MEMWB_r) && using_data_reg_2_IDEXEC_r ) ) &&  data_reg_wr_en_MEMWB_r;
  assign two_instr_away_flag = (((reg1_addr_IF == rdest_addr_EXECMEM_r) && using_data_reg_1) || ((reg2_addr_IF == rdest_addr_EXECMEM_r) && using_data_reg_2)) &&  data_reg_wr_en_EXECMEM_r;

  always @(*) begin
    //default value
    pc_update_en = 1'b1;
    instr_mem_read_en = 1'b1;
    IFID_forward_en = 1'b1;
    IDEXEC_forward_en = 1'b1;
    EXECMEM_forward_en = 1'b1;
    rd_data1_use_wb_data_forward = 0;
    rd_data2_use_wb_data_forward = 0;
    rd_data1_use_alu_forward = 0;
    rd_data2_use_alu_forward = 0;
    stall_at_IFID = 0;
    stall_at_EXECMEM = 0;

    // consecutive
    // if ((((reg1_addr_IDEXEC_r == rdest_addr_EXECMEM_r) && using_data_reg_1_IDEXEC_r) || ((reg2_addr_IDEXEC_r == rdest_addr_EXECMEM_r) && using_data_reg_2_IDEXEC_r )) &&  data_reg_wr_en_EXECMEM_r) begin
    if (consecutive_flag)  begin
      // check data is forwarded from alu result or data memory
      if (writeback_sel_EXECMEM_r) begin
        // from data memory
        // stall for one cycle
        pc_update_en = 1'b0;
        instr_mem_read_en = 1'b0;
        IFID_forward_en = 1'b0;
        IDEXEC_forward_en = 1'b0;
        EXECMEM_forward_en = 1'b0;
        stall_at_EXECMEM = 1;
        // forward data is not ready, do not use them yet
        rd_data1_use_wb_data_forward = 0;
        rd_data2_use_wb_data_forward = 0;
        // after stalling for one cycle, the formal instr moves forward
        // then the situation became one_instr away
        end
      else begin
        // from alu result, no need to stall
        rd_data1_use_alu_forward = (reg1_addr_IDEXEC_r == rdest_addr_EXECMEM_r) && using_data_reg_1_IDEXEC_r && data_reg_wr_en_EXECMEM_r;
        rd_data2_use_alu_forward = (reg2_addr_IDEXEC_r == rdest_addr_EXECMEM_r) && using_data_reg_2_IDEXEC_r && data_reg_wr_en_EXECMEM_r;
        end
      end

    if (one_instr_away_flag) begin
          // one instr away
          // if ((((reg1_addr_IDEXEC_r == rdest_addr_MEMWB_r) && using_data_reg_1_IDEXEC_r) || ((reg2_addr_IDEXEC_r == rdest_addr_MEMWB_r) && using_data_reg_2_IDEXEC_r )) &&  data_reg_wr_en_MEMWB_r) begin
          // no stall required for either forwarded from data mem or from alu result
          rd_data1_use_wb_data_forward = (reg1_addr_IDEXEC_r == rdest_addr_MEMWB_r) && using_data_reg_1_IDEXEC_r && data_reg_wr_en_MEMWB_r;
          rd_data2_use_wb_data_forward = (reg2_addr_IDEXEC_r == rdest_addr_MEMWB_r) && using_data_reg_2_IDEXEC_r && data_reg_wr_en_MEMWB_r;
          end
    if (two_instr_away_flag && !stall_at_EXECMEM) begin
          // two instr away (stall the pipeline before data reg (instruction decode stage))
          // if ((((reg1_addr_IF == rdest_addr_EXECMEM_r) && using_data_reg_1) || ((reg2_addr_IF == rdest_addr_EXECMEM_r) && using_data_reg_2)) &&  data_reg_wr_en_EXECMEM_r) begin
          // write back and read the same address
          // stall for one cycle
          pc_update_en = 1'b0;
          instr_mem_read_en = 1'b0;
          IFID_forward_en = 1'b0;
          stall_at_IFID = 1;
        end
    end
endmodule
