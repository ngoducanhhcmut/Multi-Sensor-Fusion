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