module instr_mem
  ( input [31:0] pc_i
  , input clk_i
  , input instr_mem_read_en_i
  , output reg [31:0] instr_o
  );

  reg [7:0] instr_mem [0:511];
  // initial $readmemh("D:/Dropbox/2020 Spring/EE 469/lab_pipe/starter/cpu/my_testcode/instr_test.hex", instr_mem); // read
  initial $readmemh("D:/Dropbox/2020 Spring/EE 469/lab_pipe/starter/cpu/my_testcode/instr_add.hex", instr_mem); // read

  always @(posedge clk_i) begin
    if (instr_mem_read_en_i) begin
    	instr_o[31:24] <= instr_mem[pc_i+3];
      instr_o[23:16] <= instr_mem[pc_i+2];
      instr_o[15:8] <= instr_mem[pc_i+1];
      instr_o[7:0] <= instr_mem[pc_i];
    end
  end

endmodule
