module cache (
  input clk, 
  input rst,
  input logic proc_read_req,          // Processor read request to cache
  input logic proc_write_req,         // Processor write request to cache
  input [9:0] proc_address,           // Processor address bus for cache access
  input [7:0] proc_write_data,        // Processor data to write into cache
  output reg [31:0] cache_read_data,   // Cache data sent to processor after a read
  output reg cache_read_ready,        // Cache signals data is ready for processor read
  output reg cache_write_ready        // Cache signals ready for processor write
);

parameter cache_size = 256; // Cache size = 8 blocks * 4 words/block * 8 bits/word = 256 bits.
parameter cache_index_size = 3; // log2(8) = 3 bits
parameter word_offset_size = 2; // log2(4) = 2 bits
parameter cache_tag_size = 5; // 10 - (2 + 3) = 5 bits.
// NOTE we don't have any byte offset because each word is 8 bits.

reg [cache_size-1:0] cache [7:0];      // 8 blocks
reg [cache_tag_size-1:0] cache_tags [0:7];  // 8 * 5
reg [2**cache_index_size-1:0] valid_bits;   // row of 8 valid bits

reg [word_offset_size-1:0] word_offset;   
reg [cache_index_size-1:0] cache_index;
reg [cache_tag_size-1:0] cache_tag;

integer i; // Define integer for loop operations

// Define states enums make the output look WAY better. 
typedef enum logic [2:0] {
  IDLE_STATE,
  CHECK_TAG_STATE,
  READ_HIT_STATE,
  READ_MISS_STATE,
  WRITE_HIT_STATE,
  WRITE_MISS_STATE,
  WAIT_FOR_MEM
} STATE;

STATE current_state, next_state;

logic readMemory;  // Control memory reads -> note that this goes to our ram 
logic writeMemory; // Control memory writes > note that this goes to our ram 

// Memory interface
reg [31:0] mem_read_data;  // Data read from memory to cache
logic memoryRR;           // Memory read ready signal
logic memoryWR;           // Memory write ready signal
reg [9:0] sendAddress;    // Address to send to memory
reg [7:0] sedproc_data;   // Data to send to memory

Memory ram (
  .clk(clk),
  .rst(rst),
  .cache_read_req_to_mem(readMemory),   // Cache read request to memory
  .cache_write_req_to_mem(writeMemory), // Cache write request to memory
  .AddressBus(sendAddress),             // Address bus to memory
  .dInputBus(sedproc_data),             // Data to write into memory
  .dOutputBus(mem_read_data),           // Data read from memory
  .memoryRR(memoryRR),
  .memoryWR(memoryWR)
);


always @(posedge clk or posedge rst) begin
  if (rst) begin
    current_state <= IDLE_STATE;
    valid_bits <= 8'b00000000;
    for (i = 0; i < 8; i++) begin
      cache[i] <= 8'b00000000;        
      cache_tags[i] <= 5'b00000;     
    end
  end else begin
    current_state <= next_state;      // Update current state
  end
end

always @(*) begin
  cache_read_data = 8'b0;         // Default cache read data
  cache_read_ready = 0;           // Default: not ready for cache read
  cache_write_ready = 0;          // Default: not ready for cache write
  readMemory = 0;                 // Default memory signals to 0 👇
  writeMemory = 0;
  
  next_state = current_state;     // Default next state is current state

  case (current_state)
    IDLE_STATE: begin
      if (proc_read_req || proc_write_req) begin
        next_state = CHECK_TAG_STATE;
      end
    end

    CHECK_TAG_STATE: begin
      cache_index = proc_address[5:3];     // Cache index (3 bits)
      word_offset = proc_address[2:1];     // Word offset (2 bits)
      cache_tag = proc_address[9:5];       // Cache tag (5 bits)
      
      if (valid_bits[cache_index] && (cache_tags[cache_index] == cache_tag)) begin // check if our tag matches what was requested allong with the valid bits. 
        if (proc_read_req) begin
          next_state = READ_HIT_STATE;
        end else if (proc_write_req) begin
          next_state = WRITE_HIT_STATE;
        end
      end else begin
        if (proc_read_req) begin
          next_state = READ_MISS_STATE;
        end else if (proc_write_req) begin
          next_state = WRITE_MISS_STATE;
        end
      end
    end

    READ_HIT_STATE: begin
      cache_read_data = cache[cache_index]; // This is the notation for going through a word 
      cache_read_ready = 1;
      next_state = IDLE_STATE;
    end

    WRITE_HIT_STATE: begin
      cache[cache_index][(word_offset * 8) +: 8] = proc_write_data;  // Write data to cache
      writeMemory = 1;
      sendAddress = {cache_tag, cache_index, word_offset}; // Memory address to write
      sedproc_data = proc_write_data;
      cache_write_ready = 1;
      next_state = IDLE_STATE;
    end

    READ_MISS_STATE: begin
      readMemory = 1;
      sendAddress = {cache_tag, cache_index, word_offset}; // Address to read from memory
      next_state = WAIT_FOR_MEM;
    end

    WRITE_MISS_STATE: begin
      writeMemory = 1;
      sendAddress = {cache_tag, cache_index, word_offset}; // Address to write to memory
      sedproc_data = proc_write_data;
      next_state = WAIT_FOR_MEM;
    end

    WAIT_FOR_MEM: begin
      if (memoryRR) begin
        cache[cache_index] = mem_read_data;  // Cache line update on read miss
        valid_bits[cache_index] = 1;                                // Mark cache line as valid (change the valid bit)
        cache_read_data = cache[cache_index];                            // Send data to processor
        cache_read_ready = 1;
        memoryRR = 0; 
        next_state = IDLE_STATE;
      end else if (memoryWR) begin
        memoryWR = 0; 
        next_state = IDLE_STATE;
      end
    end
  endcase
end

endmodule
