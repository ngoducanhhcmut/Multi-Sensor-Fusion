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