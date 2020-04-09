module data_mem
  ( input clk_i
  , input [31:0] addr_i

  , input [31:0] wr_data_i
  , input wr_en_i

  , input rd_en_i
  , output reg [31:0] rd_data_o
  );

  reg [7:0]   sub_data_mem_0[0:63];
  reg [7:0]   sub_data_mem_1[0:63];
  reg [7:0]   sub_data_mem_2[0:63];
  reg [7:0]   sub_data_mem_3[0:63];
  initial $readmemh("D:/Dropbox/2020 Spring/EE 469/lab_pipe/starter/cpu/my_testcode/data_0.hex", sub_data_mem_0);
  initial $readmemh("D:/Dropbox/2020 Spring/EE 469/lab_pipe/starter/cpu/my_testcode/data_1.hex", sub_data_mem_1);
  initial $readmemh("D:/Dropbox/2020 Spring/EE 469/lab_pipe/starter/cpu/my_testcode/data_2.hex", sub_data_mem_2);
  initial $readmemh("D:/Dropbox/2020 Spring/EE 469/lab_pipe/starter/cpu/my_testcode/data_3.hex", sub_data_mem_3);

  wire [5:0] addr;
  assign addr = addr_i[7:2];

  //write op
  always @(posedge clk_i) begin
    if (wr_en_i) begin
      //data_memory[addr_i] <= wr_data_i;
      sub_data_mem_0[addr] <= wr_data_i[7:0];
      sub_data_mem_1[addr] <= wr_data_i[15:8];
      sub_data_mem_2[addr] <= wr_data_i[23:16];
      sub_data_mem_3[addr] <= wr_data_i[31:24];
    end
    if (rd_en_i) begin
      rd_data_o[31:24] <= sub_data_mem_3[addr];
      rd_data_o[23:16] <= sub_data_mem_2[addr];
      rd_data_o[15:8] <= sub_data_mem_1[addr];
      rd_data_o[7:0] <= sub_data_mem_0[addr];
    end

  end

  endmodule

    // reg [7:0] data_memory[0:255];
    // initial $readmemh("D:/Dropbox/2020 Spring/EE 469/lab/starter/cpu/my_testcode/backup/data_256.hex", data_memory); // read initial data to read data into instruction memory
    // always @(posedge clk_i) begin
    //   if (wr_en_i) begin
    //     //data_memory[addr_i] <= wr_data_i;
    //     data_memory[addr_i] <= wr_data_i[7:0];
    //     data_memory[addr_i+1] <= wr_data_i[15:8];
    //     data_memory[addr_i+2] <= wr_data_i[23:16];
    //     data_memory[addr_i+3] <= wr_data_i[31:24];
    //     end
    //   if (rd_en_i) begin
    //     rd_data_o[31:24] <= data_memory[addr_i+3];
    //     rd_data_o[23:16] <= data_memory[addr_i+2];
    //     rd_data_o[15:8] <= data_memory[addr_i+1];
    //     rd_data_o[7:0] <= data_memory[addr_i];
    //     end
    //   end
