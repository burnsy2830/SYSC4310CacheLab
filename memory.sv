module Memory (
  input logic clk,
  input logic rst,
  input logic cache_read_req_to_mem,
  input logic cache_write_req_to_mem,
  input [9:0] AddressBus,
  input [7:0] dInputBus,
  output reg [31:0] dOutputBus, // Should be reg since it can be assigned in always block
  output logic memoryRR,
  output logic memoryWR
);

  // Define a 2D array of registers to form memory: 1024 locations, each 8 bits wide.
  reg [7:0] mem [0:1023];  

  integer i;  // Define this here because you can't define it in a loop.
  
  always @(posedge clk) begin
    if (rst) begin
      // Reset all memory locations to 0
      for (i = 0; i < 1024; i = i + 1) begin
        mem[i] <= 8'b00000000; 
      end
      memoryRR <= 0;
      memoryWR <= 0;
    end else begin
      // Case where only a read request is made
      if (cache_read_req_to_mem) begin
        dOutputBus <= {mem[AddressBus], mem[AddressBus+1], mem[AddressBus+2], mem[AddressBus+3]};
        memoryRR <= 1;  // Assert memory read ready signal
      end else begin
        memoryRR <= 0;  // De-assert memoryRR once read is processed
      end
      
      // Case where a write request is made
      if (cache_write_req_to_mem) begin
        {mem[AddressBus], mem[AddressBus+1], mem[AddressBus+2], mem[AddressBus+3]} <= dInputBus;
        memoryWR <= 1;  // Assert memory write ready signal
      end else begin
        memoryWR <= 0;  // De-assert memoryWR after write is processed
      end
    end
  end
endmodule
