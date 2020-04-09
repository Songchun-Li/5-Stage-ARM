module datareg2r1w
  ( input [3:0] rd_addr1_i
  , input [3:0] rd_addr2_i
  , input [3:0] wr_addr_i
  , input [31:0] wr_data_i
  , input wr_en_i
  , input clk_i
  , output reg [31:0] rd_data1_o
  , output reg [31:0] rd_data2_o
  );

  // this is the data memory with 2 read and 1 write
  reg [31:0] data_reg[0:15];

  initial $readmemh("D:/Dropbox/2020 Spring/EE 469/lab/starter/cpu/my_testcode/data_reg.hex", data_reg); // read initial data to read data into instruction memory

  // assign rd_data1_o = data_reg[rd_addr1_i];
  // assign rd_data2_o = data_reg[rd_addr2_i];

  always @ (posedge clk_i) begin
    rd_data1_o <= data_reg[rd_addr1_i];
    rd_data2_o <= data_reg[rd_addr2_i];
    if (wr_en_i)
      data_reg[wr_addr_i] <= wr_data_i;
  end


endmodule
