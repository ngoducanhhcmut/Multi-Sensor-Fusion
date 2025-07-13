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