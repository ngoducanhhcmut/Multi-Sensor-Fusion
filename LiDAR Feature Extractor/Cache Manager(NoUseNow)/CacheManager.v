module CacheManager (
    input  wire        clk,             // Clock
    input  wire        rst,             // Reset
    input  wire [14:0] voxel_addr,      // Địa chỉ voxel (15-bit)
    input  wire [31:0] voxel_data_in,   // Dữ liệu voxel để ghi
    input  wire        write_en,        // Cờ yêu cầu ghi
    input  wire        read_en,         // Cờ yêu cầu đọc (thêm để xử lý đồng thời)
    output wire [31:0] voxel_data_out,  // Dữ liệu voxel tối ưu
    output wire        ready            // Cờ báo dữ liệu sẵn sàng
);

    // Tín hiệu nội bộ
    wire        cache_hit;
    wire        bram_read_en;
    wire        bram_write_en;
    wire [14:0] bram_addr;
    wire [31:0] bram_data_in;
    wire [31:0] bram_data_out;
    
    // Control FSM states
    typedef enum logic [1:0] {
        IDLE,
        READ_BRAM,
        DATA_READY
    } state_t;
    
    state_t state, next_state;

    // Module Cache Controller
    CacheController cache_ctrl (
        .clk(clk),
        .rst(rst),
        .voxel_addr(voxel_addr),
        .voxel_data_in(voxel_data_in),
        .write_en(write_en),
        .read_en(read_en),
        .voxel_data_out(voxel_data_out),
        .hit(cache_hit),
        .bram_read_en(bram_read_en),
        .bram_write_en(bram_write_en),
        .bram_addr(bram_addr),
        .bram_data_in(bram_data_in),
        .bram_data_out(bram_data_out)
    );

    // Module BRAM Interface
    BRAMInterface bram_if (
        .clk(clk),
        .rst(rst),
        .read_en(bram_read_en),
        .write_en(bram_write_en),
        .addr(bram_addr),
        .data_in(bram_data_out),
        .data_out(bram_data_in)
    );

    // State machine for ready signal
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        case (state)
            IDLE: begin
                if (cache_hit && read_en && !write_en) begin
                    next_state = DATA_READY;  // Cache hit, đọc ngay lập tức
                end else if (write_en || (read_en && !cache_hit)) begin
                    next_state = READ_BRAM;   // Ghi hoặc đọc miss
                end else begin
                    next_state = IDLE;
                end
            end
            
            READ_BRAM: begin
                next_state = DATA_READY;
            end
            
            DATA_READY: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    assign ready = (state == DATA_READY);

endmodule