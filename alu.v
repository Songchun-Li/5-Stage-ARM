module alu
  ( input [31:0] op1_i
  , input [31:0] op2_i
  , input [3:0] aluop_i
  , input [3:0] cpsr_i
  , input carry_shifted_i
  , output reg [31:0] out_o
  , output reg [3:0] cpsr_update_o
  );

  reg temp, carry;
  reg [31:0] op_neg;

  always @(*) begin
    cpsr_update_o = cpsr_i;
    /*

    cpsr_update_o[3] = n
    cpsr_update_o[2] = z
    cpsr_update_o[1] = c
    cpsr_update_o[0] = v

    */
    case(aluop_i)
      4'b0000: begin
        out_o = op1_i & op2_i;   // AND
        cpsr_update_o[1] = carry_shifted_i;
        end
      4'b0001: begin
        out_o = op1_i ^ op2_i;   // EOR
        cpsr_update_o[1] = carry_shifted_i;
        end
      4'b0010: begin                                         //sub
        op_neg = -op2_i ;    //2's complement
        {temp, out_o[30:0]} = op1_i[30:0] + op_neg[30:0];   // op1-op2
        {carry, out_o[31]} = temp + op1_i[31] + op_neg[31];
        cpsr_update_o[1] = carry;
        cpsr_update_o[0] = carry ^ temp;
        end
      4'b0011: begin                                         //reversed sub
        op_neg = -op1_i ;    //2's complement
        {temp, out_o[30:0]} = op2_i[30:0] + op_neg[30:0];   // op2-op1
        {carry, out_o[31]} = temp + op2_i[31] + op_neg[31];
        cpsr_update_o[1] = carry;
        cpsr_update_o[0] = carry ^ temp;
        end
      4'b0100: begin                                         // sum
        {temp, out_o[30:0]} = op1_i[30:0] + op2_i[30:0];
        {carry, out_o[31]} = temp + op1_i[31] + op2_i[31];
        cpsr_update_o[1] = carry;
        cpsr_update_o[0] = carry ^ temp;
        end
      4'b0101: begin
        {temp, out_o[30:0]} = op1_i[30:0]+op2_i[30:0] + carry_shifted_i;
        {carry, out_o[31]} = temp + op1_i[31]+op2_i[31];   // sum_cin
        cpsr_update_o[1] = carry;
        cpsr_update_o[0] = carry ^ temp;
        end
      4'b0110: begin                                       // sub_cin
        op_neg = -op2_i ;    //2's complement
        {temp, out_o[30:0]} = op1_i[30:0] + op_neg[30:0] + carry_shifted_i - 1;   // op1-op2
        {carry, out_o[31]} = temp + op1_i[31] + op_neg[31];
        cpsr_update_o[1] = carry;
        cpsr_update_o[0] = carry ^ temp;
        end
      4'b0111: begin                                         // reversed sub_cin
        op_neg = -op1_i ;    //2's complement
        {temp, out_o[30:0]} = op2_i[30:0] + op_neg[30:0];   // op2-op1
        {carry, out_o[31]} = temp + op2_i[31] + op_neg[31];
        cpsr_update_o[1] = carry;
        cpsr_update_o[0] = carry ^ temp;
        end
      4'b1000: begin
        out_o = op1_i & op2_i;     // TST and set condition
        cpsr_update_o[1] = carry_shifted_i;
        end
      4'b1001: begin
        out_o = op1_i ^ op2_i;     // TEQ and set condition
        cpsr_update_o[1] = carry_shifted_i;
        end
      4'b1010: begin                      // CMP and set condition, actually operate a sub
        op_neg = -op2_i ;    //2's complement
        {temp, out_o[30:0]} = op1_i[30:0] + op_neg[30:0];   // op1-op2
        {carry, out_o[31]} = temp + op1_i[31] + op_neg[31];
        cpsr_update_o[1] = carry;
        cpsr_update_o[0] = carry ^ temp;
        end
      4'b1011: begin                     // CMN and set condition, actually operate a add
        {temp, out_o[30:0]} = op1_i[30:0] + op2_i[30:0];
        {carry, out_o[31]} = temp + op1_i[31] + op2_i[31];
        cpsr_update_o[1] = carry;
        cpsr_update_o[0] = carry ^ temp;
        end
      4'b1100: begin
        out_o = op1_i | op2_i;     // ORR
        cpsr_update_o[1] = carry_shifted_i;
        end
      4'b1101: begin
      out_o = op2_i;             // for mov instr, just pass op2
      cpsr_update_o[1] = carry_shifted_i;
      end
      4'b1110: begin
        out_o = op1_i & ~op2_i;    // BIC
        cpsr_update_o[1] = carry_shifted_i;
        end
      4'b1111: begin
        out_o = ~op2_i;
        cpsr_update_o[1] = carry_shifted_i;
        end
      default: out_o = 32'h00000000;
    endcase

    if (out_o == 0) cpsr_update_o[2] = 1;            // set zero
    if (out_o[31])  cpsr_update_o[3] = 1;            // set negative

  end
endmodule
