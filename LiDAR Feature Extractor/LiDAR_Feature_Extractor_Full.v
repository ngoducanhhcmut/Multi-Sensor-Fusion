module ClusteringModule (
    input  wire        clk,              // Clock
    input  wire        rst,              // Reset
    input  wire        start,            // Start processing
    output reg         done,             // Processing done
    
    // Voxel Grid BRAM Interface
    output reg  [14:0] voxel_addr,       // Voxel address
    input  wire        voxel_data,       // Voxel data (1=occupied)
    output reg         voxel_en,         // Voxel BRAM enable
    
    // Label Grid BRAM Interface
    output reg  [14:0] label_rd_addr,    // Label read address
    input  wire [9:0]  label_rd_data,    // Label read data
    output reg  [14:0] label_wr_addr,    // Label write address
    output reg  [9:0]  label_wr_data,    // Label write data
    output reg         label_we          // Label write enable
);

// Parameters
localparam GRID_SIZE  = 32;
localparam ADDR_BITS  = 15;  // 32*32*32 = 32768
localparam LABEL_BITS = 10;  // 1024 labels max
localparam MAX_LABELS = 1024;

// States
typedef enum logic [2:0] {
    IDLE,
    READ_VOXEL,
    WAIT_DATA,
    PROCESS,
    WRITE_LABEL,
    PASS2_READ,
    PASS2_WAIT,
    PASS2_PROCESS,
    DONE
} state_t;

state_t state;

// Coordinates
reg [4:0] x, y, z;

// Label management
reg [LABEL_BITS-1:0] label_counter;
reg [LABEL_BITS-1:0] parent [0:MAX_LABELS-1];
reg [LABEL_BITS-1:0] row_buffer [0:GRID_SIZE-1];
reg [LABEL_BITS-1:0] last_label;

// Neighbor tracking
reg [LABEL_BITS-1:0] min_neighbor;
reg [LABEL_BITS-1:0] front_root, left_root, top_root;
reg                  has_left, has_top, has_front;

// Address calculation
function [ADDR_BITS-1:0] xyz_to_addr(
    input [4:0] x_in, 
    input [4:0] y_in, 
    input [4:0] z_in
);
    xyz_to_addr = x_in + (y_in << 5) + (z_in << 10);
endfunction

// Optimized iterative root finder (4 cycles max)
function [LABEL_BITS-1:0] find_root(
    input [LABEL_BITS-1:0] label_in
);
    reg [LABEL_BITS-1:0] current;
    begin
        current = label_in;
        if (parent[current] != current) current = parent[current]; // 1st
        if (parent[current] != current) current = parent[current]; // 2nd
        if (parent[current] != current) current = parent[current]; // 3rd
        if (parent[current] != current) current = parent[current]; // 4th
        find_root = current;
    end
endfunction

// FSM main process
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        done <= 0;
        x <= 0;
        y <= 0;
        z <= 0;
        label_counter <= 1;
        voxel_en <= 0;
        label_we <= 0;
        last_label <= 0;
        for (int i = 0; i < MAX_LABELS; i++) parent[i] <= i;
        for (int i = 0; i < GRID_SIZE; i++) row_buffer[i] <= 0;
    end
    else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= READ_VOXEL;
                    x <= 0; y <= 0; z <= 0;
                    label_counter <= 1;
                end
                done <= 0;
            end
            
            READ_VOXEL: begin
                voxel_addr <= xyz_to_addr(x, y, z);
                voxel_en <= 1;
                has_front = (z > 0);
                if (has_front) label_rd_addr <= xyz_to_addr(x, y, z-1);
                state <= WAIT_DATA;
            end
            
            WAIT_DATA: begin
                voxel_en <= 0;
                front_root <= has_front ? find_root(label_rd_data) : 0;
                state <= PROCESS;
            end
            
            PROCESS: begin
                if (voxel_data) begin
                    min_neighbor = {LABEL_BITS{1'b1}};
                    has_left = (x > 0);
                    has_top = (y > 0);
                    
                    if (has_left && last_label != 0) begin
                        left_root = find_root(last_label);
                        if (left_root < min_neighbor) min_neighbor = left_root;
                    end
                    
                    if (has_top && row_buffer[x] != 0) begin
                        top_root = find_root(row_buffer[x]);
                        if (top_root < min_neighbor) min_neighbor = top_root;
                    end
                    
                    if (has_front && front_root != 0 && front_root < min_neighbor)
                        min_neighbor = front_root;
                    
                    if (min_neighbor == {LABEL_BITS{1'b1}}) begin
                        last_label <= label_counter;
                        parent[label_counter] <= label_counter;
                        label_counter <= label_counter + 1;
                    end
                    else begin
                        last_label <= min_neighbor;
                        if (has_left && last_label != 0 && left_root != min_neighbor)
                            parent[left_root] <= min_neighbor;
                        if (has_top && row_buffer[x] != 0 && top_root != min_neighbor)
                            parent[top_root] <= min_neighbor;
                        if (has_front && front_root != 0 && front_root != min_neighbor)
                            parent[front_root] <= min_neighbor;
                    end
                end
                else last_label <= 0;
                state <= WRITE_LABEL;
            end
            
            WRITE_LABEL: begin
                label_wr_addr <= xyz_to_addr(x, y, z);
                label_wr_data <= last_label;
                label_we <= 1;
                row_buffer[x] <= last_label; // Update row buffer every voxel
                
                if (x < GRID_SIZE-1) begin
                    x <= x + 1;
                    state <= READ_VOXEL;
                end
                else if (y < GRID_SIZE-1) begin
                    x <= 0; y <= y + 1;
                    state <= READ_VOXEL;
                end
                else if (z < GRID_SIZE-1) begin
                    x <= 0; y <= 0; z <= z + 1;
                    state <= READ_VOXEL;
                end
                else begin
                    x <= 0; y <= 0; z <= 0;
                    state <= PASS2_READ;
                end
            end
            
            PASS2_READ: begin
                label_rd_addr <= xyz_to_addr(x, y, z);
                label_we <= 0;
                state <= PASS2_WAIT;
            end
            
            PASS2_WAIT: begin
                state <= PASS2_PROCESS;
            end
            
            PASS2_PROCESS: begin
                if (label_rd_data != 0) begin
                    label_wr_data <= find_root(label_rd_data);
                    label_wr_addr <= xyz_to_addr(x, y, z);
                    label_we <= 1;
                end
                else label_we <= 0;
                
                if (x < GRID_SIZE-1) x <= x + 1;
                else if (y < GRID_SIZE-1) begin x <= 0; y <= y + 1; end
                else if (z < GRID_SIZE-1) begin x <= 0; y <= 0; z <= z + 1; end
                else state <= DONE;
                
                if (state != DONE) state <= PASS2_READ;
            end
            
            DONE: begin
                label_we <= 0;
                done <= 1;
                state <= IDLE;
            end
        endcase
    end
end

endmodule

// CentroidCalculator: Tính tâm với số có dấu và kiểm tra lỗi
module CentroidCalculator (
    input  logic signed [31:0] min_x, min_y, min_z,  // Tọa độ tối thiểu (Q16.16 fixed-point)
    input  logic signed [31:0] max_x, max_y, max_z,  // Tọa độ tối đa (Q16.16 fixed-point)
    output logic signed [31:0] centroid_x, centroid_y, centroid_z,  // Tọa độ tâm (Q16.16 fixed-point)
    output logic error  // Cờ báo lỗi
);
    assign error = (min_x > max_x) || (min_y > max_y) || (min_z > max_z);
    assign centroid_x = error ? 32'sh0 : ((min_x + max_x) >>> 1);  // Dịch số học giữ dấu
    assign centroid_y = error ? 32'sh0 : ((min_y + max_y) >>> 1);
    assign centroid_z = error ? 32'sh0 : ((min_z + max_z) >>> 1);
endmodule

// DimensionCalculator: Tính kích thước với giá trị tuyệt đối
module DimensionCalculator (
    input  logic signed [31:0] min_x, min_y, min_z,  // Tọa độ tối thiểu (Q16.16 fixed-point)
    input  logic signed [31:0] max_x, max_y, max_z,  // Tọa độ tối đa (Q16.16 fixed-point)
    output logic signed [31:0] dx, dy, dz  // Kích thước (Q16.16 fixed-point)
);
    assign dx = (max_x >= min_x) ? (max_x - min_x) : (min_x - max_x);
    assign dy = (max_y >= min_y) ? (max_y - min_y) : (min_y - max_y);
    assign dz = (max_z >= min_z) ? (max_z - min_z) : (min_z - max_z);
endmodule

// FeatureCalculator: Tích hợp Centroid và Dimension
module FeatureCalculator (
    input  logic signed [31:0] min_x, min_y, min_z,  // Tọa độ tối thiểu (Q16.16 fixed-point)
    input  logic signed [31:0] max_x, max_y, max_z,  // Tọa độ tối đa (Q16.16 fixed-point)
    output logic signed [31:0] centroid_x, centroid_y, centroid_z,  // Tọa độ tâm (Q16.16 fixed-point)
    output logic signed [31:0] dx, dy, dz,  // Kích thước (Q16.16 fixed-point)
    output logic error  // Cờ báo lỗi
);
    CentroidCalculator centroid_calc (
        .min_x(min_x), .min_y(min_y), .min_z(min_z),
        .max_x(max_x), .max_y(max_y), .max_z(max_z),
        .centroid_x(centroid_x), .centroid_y(centroid_y), .centroid_z(centroid_z),
        .error(error)
    );
    
    DimensionCalculator dimension_calc (
        .min_x(min_x), .min_y(min_y), .min_z(min_z),
        .max_x(max_x), .max_y(max_y), .max_z(max_z),
        .dx(dx), .dy(dy), .dz(dz)
    );
endmodule

module FeatureEncoder (
    input  wire         clk,              // System clock (125 MHz)
    input  wire         reset_n,          // Active-low reset
    input  wire         features_valid,   // Input data valid signal
    input  wire [31:0]  centroid_x,       // Centroid X (Q8.24 fixed-point)
    input  wire [31:0]  centroid_y,       // Centroid Y (Q8.24 fixed-point)
    input  wire [31:0]  centroid_z,       // Centroid Z (Q8.24 fixed-point)
    input  wire [31:0]  dim_x,            // Dimension X (Q8.24)
    input  wire [31:0]  dim_y,            // Dimension Y (Q8.24)
    input  wire [31:0]  dim_z,            // Dimension Z (Q8.24)
    input  wire [31:0]  aspect_ratio,     // Aspect ratio (UQ16.16)
    input  wire [31:0]  point_density,    // Point density (UQ16.16)
    output logic [255:0] feature_vector,  // Output feature vector
    output logic        vector_valid      // Output valid signal
);

    // Pipeline Stage 1: Data validation and formatting
    logic [31:0] feat_stage1 [0:7];
    logic        valid_stage1;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            valid_stage1 <= 1'b0;
            for (int i = 0; i < 8; i++) feat_stage1[i] <= '0;
        end else begin
            valid_stage1 <= features_valid;
            feat_stage1[0] <= centroid_x;
            feat_stage1[1] <= centroid_y;
            feat_stage1[2] <= centroid_z;
            feat_stage1[3] <= (dim_x[31]) ? 32'h0 : dim_x;    // Clip negative to 0
            feat_stage1[4] <= (dim_y[31]) ? 32'h0 : dim_y;
            feat_stage1[5] <= (dim_z[31]) ? 32'h0 : dim_z;
            feat_stage1[6] <= aspect_ratio;
            feat_stage1[7] <= (point_density[31]) ? 32'h0 : point_density;
        end
    end

    // Pipeline Stage 2: Data packing
    logic [255:0] packed_data;
    logic        valid_stage2;
    assign packed_data = {
        feat_stage1[0], feat_stage1[1],
        feat_stage1[2], feat_stage1[3],
        feat_stage1[4], feat_stage1[5],
        feat_stage1[6], feat_stage1[7]
    };
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) valid_stage2 <= 1'b0;
        else valid_stage2 <= valid_stage1;
    end

    // Pipeline Stage 3: Output register
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            feature_vector <= 256'b0;
            vector_valid <= 1'b0;
        end else begin
            vector_valid <= valid_stage2;
            if (valid_stage2) begin
                feature_vector <= packed_data;
            end
        end
    end

    // Formal assertions for edge case verification
    `ifdef FORMAL
        assert property (@(posedge clk) !reset_n |=> !vector_valid);
        assert property (@(posedge clk) features_valid |=> ##2 vector_valid);
        assert property (@(posedge clk) (dim_x[31] && valid_stage1) |-> (feat_stage1[3] == 0));
    `endif

endmodule


// Module CoordinateNormalizer: Chuẩn hóa tọa độ về khoảng [0-1023]
module CoordinateNormalizer (
    input wire clk,
    input wire reset,
    input wire [127:0] point_data,
    input wire input_valid,
    output reg [127:0] normalized_coords,
    output reg valid
);
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            normalized_coords <= 128'b0;
            valid <= 1'b0;
        end else if (input_valid) begin
            for (i = 0; i < 4; i = i + 1) begin
                wire [9:0] x = point_data[i*32 + 9 : i*32];
                wire [9:0] y = point_data[i*32 + 19 : i*32 + 10];
                wire [9:0] z = point_data[i*32 + 29 : i*32 + 20];
                normalized_coords[i*32 + 9 : i*32]   <= (x[9]) ? 10'd0 : (x > 1023) ? 10'd1023 : x;
                normalized_coords[i*32 + 19 : i*32 + 10] <= (y[9]) ? 10'd0 : (y > 1023) ? 10'd1023 : y;
                normalized_coords[i*32 + 29 : i*32 + 20] <= (z[9]) ? 10'd0 : (z > 1023) ? 10'd1023 : z;
                normalized_coords[i*32 + 31 : i*32 + 30] <= point_data[i*32 + 31 : i*32 + 30];
            end
            valid <= 1'b1;
        end else begin
            valid <= 1'b0;
        end
    end
endmodule

// Module PointReader: Đọc và giải nén dữ liệu từ đám mây điểm 512-bit thành các khối 128-bit
module PointReader (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [511:0] point_cloud,
    output reg [127:0] point_data,
    output reg valid,
    output reg done
);
    reg [1:0] counter;
    reg processing;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 2'b0;
            valid <= 1'b0;
            done <= 1'b0;
            processing <= 1'b0;
            point_data <= 128'b0;
        end else begin
            if (start && !processing) begin
                processing <= 1'b1;
                counter <= 2'b0;
                done <= 1'b0;
            end
            if (processing) begin
                case (counter)
                    2'd0: point_data <= point_cloud[127:0];
                    2'd1: point_data <= point_cloud[255:128];
                    2'd2: point_data <= point_cloud[383:256];
                    2'd3: point_data <= point_cloud[511:384];
                endcase
                valid <= 1'b1;
                counter <= counter + 1;
                if (counter == 2'd3) begin
                    done <= 1'b1;
                    processing <= 1'b0;
                end
            end else begin
                valid <= 1'b0;
            end
        end
    end
endmodule

// Module TileBuffer: Lưu trữ điểm vào bộ đệm tile (16x16 = 256 tiles)
module TileBuffer (
    input wire clk,
    input wire reset,
    input wire [31:0] tile_indices,
    input wire [127:0] point_data,
    input wire input_valid,
    output reg [1023:0] tile_buffer [255:0], // 256 tiles, mỗi tile lưu 32 điểm
    output reg valid
);
    reg [4:0] write_ptr [255:0];
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 256; i = i + 1) begin
                write_ptr[i] <= 5'b0;
                tile_buffer[i] <= 1024'b0;
            end
            valid <= 1'b0;
        end else if (input_valid) begin
            for (i = 0; i < 4; i = i + 1) begin
                wire [7:0] tile_idx = {tile_indices[i*8 + 7 : i*8 + 4], tile_indices[i*8 + 3 : i*8]};
                if (write_ptr[tile_idx] < 31) begin
                    tile_buffer[tile_idx][write_ptr[tile_idx]*32 + 31 : write_ptr[tile_idx]*32] <= point_data[i*32 + 31 : i*32];
                    write_ptr[tile_idx] <= write_ptr[tile_idx] + 1;
                end
            end
            valid <= 1'b1;
        end else begin
            valid <= 1'b0;
        end
    end
endmodule

// Module TileIndexCalculator: Tính chỉ số tile (X, Y)
module TileIndexCalculator (
    input wire clk,
    input wire reset,
    input wire [127:0] normalized_coords,
    input wire input_valid,
    output reg [31:0] tile_indices,
    output reg valid
);
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tile_indices <= 32'b0;
            valid <= 1'b0;
        end else if (input_valid) begin
            for (i = 0; i < 4; i = i + 1) begin
                tile_indices[i*8 + 3 : i*8]     <= normalized_coords[i*32 + 9 : i*32 + 6];  // X
                tile_indices[i*8 + 7 : i*8 + 4] <= normalized_coords[i*32 + 19 : i*32 + 16]; // Y
            end
            valid <= 1'b1;
        end else begin
            valid <= 1'b0;
        end
    end
endmodule

// Module PointCloudTiler: Tích hợp các module con
module PointCloudTiler (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [511:0] point_cloud,
    output wire [1023:0] tile_buffer [255:0],
    output wire valid
);
    wire [127:0] point_data;
    wire [127:0] normalized_coords;
    wire [31:0] tile_indices;
    wire pr_valid, cn_valid, tic_valid, tb_valid;
    wire pr_done;

    PointReader pr (
        .clk(clk),
        .reset(reset),
        .start(start),
        .point_cloud(point_cloud),
        .point_data(point_data),
        .valid(pr_valid),
        .done(pr_done)
    );

    CoordinateNormalizer cn (
        .clk(clk),
        .reset(reset),
        .point_data(point_data),
        .input_valid(pr_valid),
        .normalized_coords(normalized_coords),
        .valid(cn_valid)
    );

    TileIndexCalculator tic (
        .clk(clk),
        .reset(reset),
        .normalized_coords(normalized_coords),
        .input_valid(cn_valid),
        .tile_indices(tile_indices),
        .valid(tic_valid)
    );

    TileBuffer tb (
        .clk(clk),
        .reset(reset),
        .tile_indices(tile_indices),
        .point_data(point_data),
        .input_valid(tic_valid),
        .tile_buffer(tile_buffer),
        .valid(tb_valid)
    );

    assign valid = tb_valid;
endmodule

// Segment Refiner Module - Optimized Version
// Features: Pipelined architecture, optimized memory, parallel cluster updates
module segment_refiner (
    input  wire         clk,          // Clock
    input  wire         rst,          // Reset
    // Input Stream Interface
    input  wire         in_valid,     // Input valid
    input  wire [14:0]  cluster_label,// Current voxel's cluster ID (0 to 32767)
    input  wire [9:0]   voxel_x,      // Voxel X coordinate
    input  wire [9:0]   voxel_y,      // Voxel Y coordinate
    input  wire [9:0]   voxel_z,      // Voxel Z coordinate
    // Output Stream Interface
    output logic        out_valid,    // Output valid
    output logic [75:0] cluster_data, // Packed cluster data (76 bits)
    output logic [12:0] cluster_count // Valid clusters count (up to 4096)
);

// Cluster properties structure
typedef struct packed {
    logic [15:0] size;       // Cluster size
    logic [9:0]  min_x;      // Min X coordinate
    logic [9:0]  max_x;      // Max X coordinate
    logic [9:0]  min_y;      // Min Y coordinate
    logic [9:0]  max_y;      // Max Y coordinate
    logic [9:0]  min_z;      // Min Z coordinate
    logic [9:0]  max_z;      // Max Z coordinate
} cluster_prop_t;

// Memory subsystem (Dual-port RAM)
cluster_prop_t cluster_mem [0:4095];  // Support up to 4096 clusters
logic [11:0]   read_addr, write_addr; // 12-bit address for 4096 entries
logic          write_en;
cluster_prop_t write_data, read_data;

// Processing pipeline registers
logic [14:0] label_ff;
logic [9:0]  x_ff, y_ff, z_ff;
logic        valid_ff, lookup_valid;

// Cluster lookup table
logic [11:0] label_to_index [0:32767]; // Cluster ID to memory index (12-bit index)
logic [11:0] free_index = 0;           // Next free memory index (0 to 4095)

// Output processing
logic [11:0] output_index = 0;
logic        filtering_active = 0;

// ================================================================
// Processing Pipeline (3-stage)
// ================================================================

// Stage 1: Input registration
always_ff @(posedge clk) begin
    label_ff <= cluster_label;
    x_ff <= voxel_x;
    y_ff <= voxel_y;
    z_ff <= voxel_z;
    valid_ff <= in_valid;
end

// Stage 2: Cluster lookup and index management
always_ff @(posedge clk) begin
    lookup_valid <= valid_ff;
    
    // New cluster detection
    if (valid_ff && label_to_index[label_ff] == 0) begin
        if (free_index < 4096) begin
            label_to_index[label_ff] <= free_index + 1;
            free_index <= free_index + 1;
        end
    end
end

// Stage 3: Memory update
always_ff @(posedge clk) begin
    write_en <= 0;
    
    if (lookup_valid) begin
        logic [11:0] index = label_to_index[label_ff] - 1;
        
        if (index < 4096) begin
            write_addr <= index;
            write_en <= 1;
            
            // Initialize new cluster
            if (label_to_index[label_ff] == free_index) begin
                write_data.size <= 1;
                write_data.min_x <= x_ff;
                write_data.max_x <= x_ff;
                write_data.min_y <= y_ff;
                write_data.max_y <= y_ff;
                write_data.min_z <= z_ff;
                write_data.max_z <= z_ff;
            end
            // Update existing cluster
            else begin
                write_data.size <= read_data.size + 1;
                
                // Min/Max calculations
                write_data.min_x <= (x_ff < read_data.min_x) ? x_ff : read_data.min_x;
                write_data.max_x <= (x_ff > read_data.max_x) ? x_ff : read_data.max_x;
                write_data.min_y <= (y_ff < read_data.min_y) ? y_ff : read_data.min_y;
                write_data.max_y <= (y_ff > read_data.max_y) ? y_ff : read_data.max_y;
                write_data.min_z <= (z_ff < read_data.min_z) ? z_ff : read_data.min_z;
                write_data.max_z <= (z_ff > read_data.max_z) ? z_ff : read_data.max_z;
            end
        end
    end
end

// Memory block (True dual-port)
always_ff @(posedge clk) begin
    // Write port
    if (write_en) begin
        cluster_mem[write_addr] <= write_data;
    end
    
    // Read port (for stage 3)
    read_data <= cluster_mem[write_addr];
end

// ================================================================
// Output Filtering Stage
// ================================================================

// Size filtering and output
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        output_index <= 0;
        cluster_count <= 0;
        filtering_active <= 0;
        out_valid <= 0;
    end
    else begin
        out_valid <= 0;
        
        // Start filtering when input completes
        if (!in_valid && free_index > 0 && !filtering_active) begin
            filtering_active <= 1;
        end  
        
        // Filter clusters
        if (filtering_active && output_index < free_index) begin
            cluster_prop_t current = cluster_mem[output_index];
            
            if (current.size >= 8) begin
                // Pack cluster data: [size(16), min_x(10), max_x(10), ...]
                cluster_data <= {
                    current.size,
                    current.min_x, current.max_x,
                    current.min_y, current.max_y,
                    current.min_z, current.max_z
                };
                
                out_valid <= 1;
                cluster_count <= cluster_count + 1;
            end
            
            output_index <= output_index + 1;
        end
        // End of processing
        else if (output_index == free_index) begin
            filtering_active <= 0;
            output_index <= 0;
        end
    end
end

endmodule

module VoxelGridCreator (
    input  clk,                   // Clock
    input  rst_n,                 // Reset active-low
    input  [127:0] point_data,    // 4 points (32-bit each)
    input  valid_in,              // Input valid
    output ready_out,             // Ready for new data
    output [14:0] bram_addr,      // BRAM address (32^3=32768)
    output [79:0] bram_data_out,  // {count, sumX, sumY, sumZ}
    output bram_we,               // BRAM write enable
    input  [79:0] bram_data_in    // BRAM read data
);

// Parameters
localparam VOXEL_SHIFT = 5;       // Chia tọa độ cho 32 (2^5)
localparam MAX_POINTS = 4;        // 4 points/cycle
localparam COUNT_BITS = 8;        // 8-bit count (max 255)
localparam COORD_BITS = 24;       // 24-bit sum coordinates

// Point extraction
logic [9:0] x[4], y[4], z[4];
assign {x[3], y[3], z[3]} = point_data[127:96];
assign {x[2], y[2], z[2]} = point_data[95:64];
assign {x[1], y[1], z[1]} = point_data[63:32];
assign {x[0], y[0], z[0]} = point_data[31:0];

// Voxel index calculation
logic [4:0] vx[4], vy[4], vz[4];
logic [14:0] voxel_index[4];
always_comb begin
    for (int i = 0; i < 4; i++) begin
        vx[i] = x[i] >> VOXEL_SHIFT;
        vy[i] = y[i] >> VOXEL_SHIFT;
        vz[i] = z[i] >> VOXEL_SHIFT;
        voxel_index[i] = {vx[i], vy[i], vz[i]};
    end
end

// Cache for 4 voxels (to handle same-voxel updates)
logic [14:0] cache_addr[4];
logic [79:0] cache_data[4];
logic cache_valid[4] = '{default:0};

// Update logic with cache
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (int i = 0; i < 4; i++) cache_valid[i] <= 0;
    end else if (valid_in && ready_out) begin
        for (int i = 0; i < 4; i++) begin
            // Check if voxel already in cache
            automatic logic found = 0;
            automatic int found_idx = 0;
            for (int j = 0; j < i; j++) begin
                if (voxel_index[i] == voxel_index[j]) begin
                    found = 1;
                    found_idx = j;
                    break;
                end
            end

            if (found) begin // Update existing cache
                automatic logic [COUNT_BITS-1:0] new_cnt = cache_data[found_idx][79:72] + 1;
                cache_data[found_idx][79:72] <= (new_cnt < 255) ? new_cnt : 255;
                cache_data[found_idx][71:48] <= cache_data[found_idx][71:48] + x[i];
                cache_data[found_idx][47:24] <= cache_data[found_idx][47:24] + y[i];
                cache_data[found_idx][23:0]  <= cache_data[found_idx][23:0]  + z[i];
            end else begin // New cache entry
                cache_addr[i] <= voxel_index[i];
                cache_data[i] <= {8'h01, x[i], y[i], z[i]};
                cache_valid[i] <= 1;
            end
        end
    end
end

// BRAM write scheduler (round-robin)
logic [1:0] write_ptr = 0;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_ptr <= 0;
        bram_we <= 0;
    end else begin
        bram_we <= 0;
        for (int i = 0; i < 4; i++) begin
            automatic int idx = (write_ptr + i) % 4;
            if (cache_valid[idx]) begin
                bram_addr <= cache_addr[idx];
                bram_data_out <= cache_data[idx];
                bram_we <= 1;
                write_ptr <= idx + 1;
                cache_valid[idx] <= 0; // Invalidate cache
                break;
            end
        end
    end
end

// Ready signal: module is ready unless all cache slots are full
assign ready_out = !(&cache_valid);

// Boundary checks with assertions
always_comb begin
    for (int i = 0; i < 4; i++) begin
        assert property (@(posedge clk) valid_in |-> (x[i] <= 1023)) else $error("X out of range");
        assert property (@(posedge clk) valid_in |-> (y[i] <= 1023)) else $error("Y out of range");
        assert property (@(posedge clk) valid_in |-> (z[i] <= 1023)) else $error("Z out of range");
    end
end

endmodule

module LiDAR_Feature_Extractor (
    input  wire        clk,              // Clock
    input  wire        rst_n,            // Active-low reset
    input  wire        start,            // Start signal
    input  wire [511:0] point_cloud,     // Input point cloud (512-bit)
    output wire [255:0] feature_vector,  // Output feature vector (256-bit)
    output wire        done              // Done signal
);

// Memory declarations
logic [1023:0] tile_buffer [0:255];    // Tile buffer: 256 tiles, each 1024-bit
logic [79:0]   voxel_grid [0:32767];   // Voxel grid: 32x32x32, each 80-bit
logic [9:0]    label_grid [0:32767];   // Label grid: 32x32x32, each 10-bit

// State machine states
typedef enum logic [3:0] {
    IDLE,
    POINT_CLOUD_TILING,
    VOXEL_GRID_CREATION,
    CLUSTERING,
    SEGMENT_REFINING,
    FEATURE_CALCULATION,
    FEATURE_ENCODING,
    DONE_STATE
} state_t;

state_t state, next_state;

// Control signals for sub-modules
logic pct_start, pct_valid;
logic vgc_valid_in, vgc_ready_out, vgc_done;
logic [127:0] vgc_point_data;
logic [14:0] vgc_bram_addr;
logic [79:0] vgc_bram_data_out;
logic vgc_bram_we;
logic cm_start, cm_done, cm_voxel_en, cm_label_we;
logic [14:0] cm_voxel_addr, cm_label_rd_addr, cm_label_wr_addr;
logic [9:0] cm_label_wr_data;
logic sr_in_valid, sr_out_valid, sr_done;
logic [14:0] sr_cluster_label;
logic [9:0] sr_voxel_x, sr_voxel_y, sr_voxel_z;
logic [75:0] sr_cluster_data;
logic [12:0] sr_cluster_count;
logic fe_features_valid, fe_vector_valid;
logic [255:0] fe_feature_vector;

// Additional registers for control
logic [7:0] tile_idx;        // Tile index (0 to 255)
logic [2:0] batch_idx;       // Batch index (0 to 7 for 32 points/tile)
logic [14:0] voxel_addr;     // Voxel address (0 to 32767)
logic [15:0] max_size;       // Maximum cluster size
logic [75:0] max_cluster_data; // Data of largest cluster
logic vgc_busy, sr_busy;     // Busy flags for VoxelGridCreator and SegmentRefiner
logic [31:0] fc_centroid_x, fc_centroid_y, fc_centroid_z;
logic [31:0] fc_dx, fc_dy, fc_dz;
logic [31:0] fc_aspect_ratio, fc_point_density;

// Sub-module instantiations
PointCloudTiler pct (
    .clk(clk),
    .reset(~rst_n),
    .start(pct_start),
    .point_cloud(point_cloud),
    .tile_buffer(tile_buffer),
    .valid(pct_valid)
);

VoxelGridCreator vgc (
    .clk(clk),
    .rst_n(rst_n),
    .point_data(vgc_point_data),
    .valid_in(vgc_valid_in),
    .ready_out(vgc_ready_out),
    .bram_addr(vgc_bram_addr),
    .bram_data_out(vgc_bram_data_out),
    .bram_we(vgc_bram_we),
    .bram_data_in(voxel_grid[vgc_bram_addr])
);

ClusteringModule cm (
    .clk(clk),
    .rst(~rst_n),
    .start(cm_start),
    .done(cm_done),
    .voxel_addr(cm_voxel_addr),
    .voxel_data((voxel_grid[cm_voxel_addr][79:72] > 0) ? 1'b1 : 1'b0),
    .voxel_en(cm_voxel_en),
    .label_rd_addr(cm_label_rd_addr),
    .label_rd_data(label_grid[cm_label_rd_addr]),
    .label_wr_addr(cm_label_wr_addr),
    .label_wr_data(cm_label_wr_data),
    .label_we(cm_label_we)
);

segment_refiner sr (
    .clk(clk),
    .rst(~rst_n),
    .in_valid(sr_in_valid),
    .cluster_label(sr_cluster_label),
    .voxel_x(sr_voxel_x),
    .voxel_y(sr_voxel_y),
    .voxel_z(sr_voxel_z),
    .out_valid(sr_out_valid),
    .cluster_data(sr_cluster_data),
    .cluster_count(sr_cluster_count)
);

FeatureCalculator fc (
    .min_x(max_cluster_data[59:50]),
    .min_y(max_cluster_data[49:40]),
    .min_z(max_cluster_data[39:30]),
    .max_x(max_cluster_data[29:20]),
    .max_y(max_cluster_data[19:10]),
    .max_z(max_cluster_data[9:0]),
    .centroid_x(fc_centroid_x),
    .centroid_y(fc_centroid_y),
    .centroid_z(fc_centroid_z),
    .dx(fc_dx),
    .dy(fc_dy),
    .dz(fc_dz),
    .error(fc_error)
);

FeatureEncoder fe (
    .clk(clk),
    .reset_n(rst_n),
    .features_valid(fe_features_valid),
    .centroid_x(fc_centroid_x),
    .centroid_y(fc_centroid_y),
    .centroid_z(fc_centroid_z),
    .dim_x(fc_dx),
    .dim_y(fc_dy),
    .dim_z(fc_dz),
    .aspect_ratio(fc_aspect_ratio),
    .point_density(fc_point_density),
    .feature_vector(fe_feature_vector),
    .vector_valid(fe_vector_valid)
);

// State machine
always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        state <= IDLE;
        tile_idx <= 0;
        batch_idx <= 0;
        voxel_addr <= 0;
        max_size <= 0;
        max_cluster_data <= 0;
        vgc_busy <= 0;
        sr_busy <= 0;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always_comb begin
    next_state = state;
    pct_start = 0;
    cm_start = 0;
    done = 0;
    case (state)
        IDLE: begin
            if (start) begin
                next_state = POINT_CLOUD_TILING;
                pct_start = 1;
            end
        end
        POINT_CLOUD_TILING: begin
            if (pct_valid) begin
                next_state = VOXEL_GRID_CREATION;
            end
        end
        VOXEL_GRID_CREATION: begin
            if (vgc_done) begin
                next_state = CLUSTERING;
                cm_start = 1;
            end
        end
        CLUSTERING: begin
            if (cm_done) begin
                next_state = SEGMENT_REFINING;
            end
        end
        SEGMENT_REFINING: begin
            if (sr_done) begin
                next_state = FEATURE_CALCULATION;
            end
        end
        FEATURE_CALCULATION: begin
            next_state = FEATURE_ENCODING;
        end
        FEATURE_ENCODING: begin
            if (fe_vector_valid) begin
                next_state = DONE_STATE;
            end
        end
        DONE_STATE: begin
            done = 1;
            if (~start) begin
                next_state = IDLE;
            end
        end
    endcase
end

// VoxelGridCreator data sending
always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n || state != VOXEL_GRID_CREATION) begin
        vgc_valid_in <= 0;
        vgc_point_data <= 0;
        tile_idx <= 0;
        batch_idx <= 0;
        vgc_done <= 0;
        vgc_busy <= 0;
    end else if (!vgc_busy) begin
        if (tile_idx < 256) begin
            vgc_point_data <= tile_buffer[tile_idx][batch_idx*128 +: 128];
            vgc_valid_in <= 1;
            vgc_busy <= 1;
        end else begin
            vgc_done <= 1;
        end
    end else if (vgc_ready_out) begin
        vgc_valid_in <= 0;
        batch_idx <= batch_idx + 1;
        if (batch_idx == 7) begin
            batch_idx <= 0;
            tile_idx <= tile_idx + 1;
        end
        vgc_busy <= 0;
    end
end

// SegmentRefiner data sending
always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n || state != SEGMENT_REFINING) begin
        sr_in_valid <= 0;
        sr_cluster_label <= 0;
        sr_voxel_x <= 0;
        sr_voxel_y <= 0;
        sr_voxel_z <= 0;
        voxel_addr <= 0;
        max_size <= 0;
        max_cluster_data <= 0;
        sr_done <= 0;
        sr_busy <= 0;
    end else if (!sr_busy) begin
        if (voxel_addr < 32768) begin
            sr_voxel_x <= voxel_addr[4:0];
            sr_voxel_y <= voxel_addr[9:5];
            sr_voxel_z <= voxel_addr[14:10];
            sr_cluster_label <= label_grid[voxel_addr];
            sr_in_valid <= 1;
            sr_busy <= 1;
            voxel_addr <= voxel_addr + 1;
        end else begin
            sr_done <= 1;
        end
    end else if (sr_out_valid) begin
        if (sr_cluster_data[75:60] > max_size) begin
            max_size <= sr_cluster_data[75:60];
            max_cluster_data <= sr_cluster_data;
        end
        sr_in_valid <= 0;
        sr_busy <= 0;
    end
end

// Feature calculation
always_comb begin
    if (state == FEATURE_CALCULATION) begin
        fc_centroid_x = (max_cluster_data[59:50] + max_cluster_data[29:20]) / 2;
        fc_centroid_y = (max_cluster_data[49:40] + max_cluster_data[19:10]) / 2;
        fc_centroid_z = (max_cluster_data[39:30] + max_cluster_data[9:0]) / 2;
        fc_dx = max_cluster_data[29:20] - max_cluster_data[59:50];
        fc_dy = max_cluster_data[19:10] - max_cluster_data[49:40];
        fc_dz = max_cluster_data[9:0] - max_cluster_data[39:30];
        fc_aspect_ratio = (fc_dy != 0) ? fc_dx / fc_dy : 0; // Simplified division
        fc_point_density = (fc_dx * fc_dy * fc_dz != 0) ? max_cluster_data[75:60] / (fc_dx * fc_dy * fc_dz) : 0; // Simplified
    end else begin
        fc_centroid_x = 0;
        fc_centroid_y = 0;
        fc_centroid_z = 0;
        fc_dx = 0;
        fc_dy = 0;
        fc_dz = 0;
        fc_aspect_ratio = 0;
        fc_point_density = 0;
    end
end

// Feature encoding control
always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        fe_features_valid <= 0;
    end else if (state == FEATURE_ENCODING) begin
        fe_features_valid <= 1;
    end else begin
        fe_features_valid <= 0;
    end
end

// Output assignment
assign feature_vector = fe_feature_vector;
assign done = (state == DONE_STATE);

// Memory update logic
always @(posedge clk) begin
    if (cm_label_we) begin
        label_grid[cm_label_wr_addr] <= cm_label_wr_data;
    end
    if (vgc_bram_we) begin
        voxel_grid[vgc_bram_addr] <= vgc_bram_data_out;
    end
end

endmodule


