module shifter
	( input [31:0] alu_op2_i
  , input [2:0] instr_info_i // instr[27:25]
	, input shifter_en_i
	, input [11:0] immediate_i
	, input [31:0] rm_data_i
	, input carry_in_i
	, output wire [31:0] alu_op2_o
	, output reg carry_to_alu_o
	);

	reg [31:0] temp;
	reg [31:0] out, unused;
	reg [7:0] shiftby; // no. bits to be shifted

	assign alu_op2_o = shifter_en_i ? out : alu_op2_i ;

	always @(*) begin
		if ( instr_info_i == 3'b001 ) begin // rotate shift right on 8bit immediate
			temp = { 24'd0, immediate_i[7:0] };
			shiftby = {3'd0, immediate_i[11:8], 1'b0};  // #rot left shift 1 bit, actually equals 2*#rot
			{ unused, out } = { temp, temp } >> shiftby;

			if (shiftby == 0)
        carry_to_alu_o = carry_in_i;
			else
        carry_to_alu_o = out[31];
		end

		else begin // support rm shifted by immediate， does not support rm shifted by rs
    // immediate_i[6:5] is shift_type
    // 00 logical shift left (arith shift left is the same as lsl)
    // 01 logical shift right
    // 10 arith shift right
    // 11 rotate shift right / rrx when immediate is 0
    // logicl shift left by immediate

      if (immediate_i[6:5] == 2'b00)  begin //&& (immediate_i[4] == 0)
        temp = rm_data_i;
        { carry_to_alu_o, out } = {carry_in_i ,temp} << immediate_i[11:7];
        end
      // logicl shift right by immediate
      if (immediate_i[6:5] == 2'b01) begin //&& (immediate_i[4] == 0)
        temp = rm_data_i;
        { out, carry_to_alu_o } = { temp, carry_in_i} >> immediate_i[11:7];
        end
      // arith shift right by immediate
      if (immediate_i[6:5] == 2'b10) begin //&& (immediate_i[4] == 0)
  		  temp = rm_data_i;
  			if (temp[31]) // if negative
          { unused, out, carry_to_alu_o } = { 32'hFFFFFFFF, temp, carry_in_i } >> immediate_i[11:7];
  			else
          { out, carry_to_alu_o } = { temp, carry_in_i } >> immediate_i[11:7];
  			end
      // rotate shift right by immediate
      if ( (immediate_i[6:5] == 2'b11) && (immediate_i[11:7] != 5'd0) ) begin //&& (immediate_i[4] == 0)
				temp = rm_data_i;
				{ unused, out, carry_to_alu_o } = {temp,temp,carry_in_i} >> immediate_i[11:7];
  			end
      // rotate shift right by immediate w/ expanison the same as ROR#0
      if ( (immediate_i[6:5] == 2'b11) && (immediate_i[4] == 0) && (immediate_i[11:7] == 5'd0) ) begin
        temp = rm_data_i;
        {out, carry_to_alu_o} = {carry_in_i, temp};
        end
		end
	end
endmodule
