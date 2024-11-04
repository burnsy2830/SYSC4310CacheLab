module memory_cache_top_tb;
  // Testbench signals
  reg clk; 
  reg rst;
  reg proc_read;
  reg proc_write;
  reg [9:0] proc_add;
  reg [7:0] proc_write_data;
  wire [31:0] cache_read;
  wire cache_read_r;
  wire cache_write_r;

  cache dut (
    .clk(clk),
    .rst(rst),
    .proc_read_req(proc_read),
    .proc_write_req(proc_write),
    .proc_address(proc_add),
    .proc_write_data(proc_write_data),
    .cache_read_data(cache_read),
    .cache_read_ready(cache_read_r),
    .cache_write_ready(cache_write_r)
  );
  initial begin
    clk = 0; 
    forever #5 clk = ~clk; 
  end
  initial begin

    rst = 1;
    proc_read = 0;
    proc_write = 0;
    proc_add = 10'b0;
    proc_write_data = 8'b0;
    #10;
    rst = 0; 
    // Test Case 1: Write to Cache
    proc_write = 1;            
    proc_add = 10'b0000000001;  
    proc_write_data = 8'b11111111;    
    #20;                   
    proc_write = 0;
    // Test Case 2: Cache Miss and Memory Fetch
    #20;                          
    proc_read = 1;              
    proc_add = 10'b0000000001;   
    #20;                
    proc_read = 0;
    // Test Case 3: Cache Hit and Read
    #20;                     
    proc_read = 1;              
    proc_add = 10'b0000000001;   
    #20;           
    proc_read = 0;

    // Test Case 4: Write Hit
    #20;                     
    proc_write = 1;            
    proc_add = 10'b0000000001;  
    proc_write_data = 8'b10101010;
    #20;   
    proc_write = 0;
    #50;   
    $stop;
  end
endmodule
