module CacheController (
    input  wire        clk,
    input  wire        rst,
    input  wire [14:0] voxel_addr,     // Địa chỉ voxel
    input  wire [31:0] voxel_data_in,  // Dữ liệu voxel để ghi
    input  wire        write_en,       // Cờ ghi
    input  wire        read_en,        // Cờ đọc (thêm để xử lý đồng thời)
    output logic [31:0] voxel_data_out,// Dữ liệu voxel đọc được
    output logic       hit,            // Cờ cache hit
    output logic       bram_read_en,
    output logic       bram_write_en,
    output logic [14:0] bram_addr,
    input  wire [31:0] bram_data_in,   // Dữ liệu từ BRAM
    output logic [31:0] bram_data_out  // Dữ liệu gửi đến BRAM
);

    // Cache parameters
    localparam CACHE_SIZE = 1024;       // 4KB cache (1024 entries * 4 bytes)
    localparam INDEX_BITS = 10;         // 2^10 = 1024 entries
    localparam TAG_BITS   = 5;          // 15-bit address - 10-bit index
    
    // Cache memory structure
    typedef struct packed {
        logic [TAG_BITS-1:0] tag;
        logic [31:0] data;
        logic valid;
    } cache_entry_t;
    
    cache_entry_t [CACHE_SIZE-1:0] cache;

    // Address decomposition
    logic [INDEX_BITS-1:0] index;
    logic [TAG_BITS-1:0]   tag;
    
    assign index = voxel_addr[INDEX_BITS-1:0];
    assign tag   = voxel_addr[14:INDEX_BITS];

    // Internal signals
    logic cache_hit_internal;
    logic [31:0] cached_data;
    
    // Cache lookup (combinational)
    always_comb begin
        cache_hit_internal = 0;
        cached_data = 0;
        
        if (cache[index].valid && (cache[index].tag == tag)) begin
            cache_hit_internal = 1;
            cached_data = cache[index].data;
        end
    end

    // Cache update logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < CACHE_SIZE; i++) begin
                cache[i].valid <= 0;
                cache[i].tag   <= 0;
                cache[i].data  <= 0;
            end
            
            hit             <= 0;
            voxel_data_out  <= 0;
            bram_read_en    <= 0;
            bram_write_en   <= 0;
            bram_addr       <= 0;
            bram_data_out   <= 0;
        end else begin
            // Default values
            bram_read_en  <= 0;
            bram_write_en <= 0;
            hit           <= cache_hit_internal;
            
            if (cache_hit_internal) begin
                // Cache hit
                voxel_data_out <= cached_data;
                
                if (write_en && read_en) begin
                    // Xử lý đồng thời read/write: ưu tiên ghi
                    cache[index].data <= voxel_data_in;
                    bram_write_en    <= 1;
                    bram_addr        <= voxel_addr;
                    bram_data_out    <= voxel_data_in;
                    voxel_data_out   <= voxel_data_in; // Đọc dữ liệu vừa ghi
                end else if (write_en) begin
                    // Write-through policy
                    cache[index].data <= voxel_data_in;
                    bram_write_en    <= 1;
                    bram_addr        <= voxel_addr;
                    bram_data_out    <= voxel_data_in;
                end
            end else begin
                // Cache miss
                if (write_en && read_en) begin
                    // Đồng thời read/write trên cache miss: ưu tiên ghi
                    cache[index].valid <= 1;
                    cache[index].tag   <= tag;
                    cache[index].data  <= voxel_data_in;
                    bram_write_en     <= 1;
                    bram_addr         <= voxel_addr;
                    bram_data_out     <= voxel_data_in;
                    voxel_data_out    <= voxel_data_in;
                end else if (write_en) begin
                    // Write allocation
                    cache[index].valid <= 1;
                    cache[index].tag   <= tag;
                    cache[index].data <= voxel_data_in;
                    bram_write_en     <= 1;
                    bram_addr         <= voxel_addr;
                    bram_data_out     <= voxel_data_in;
                    voxel_data_out    <= voxel_data_in;
                end else if (read_en) begin
                    // Read miss - fetch từ BRAM
                    bram_read_en <= 1;
                    bram_addr    <= voxel_addr;
                end
            end
            
            // Đồng bộ dữ liệu từ BRAM khi đọc miss
            if (bram_read_en) begin
                cache[index].valid <= 1;
                cache[index].tag   <= tag;
                cache[index].data  <= bram_data_in;
                voxel_data_out     <= bram_data_in;
            end
        end
    end

endmodule