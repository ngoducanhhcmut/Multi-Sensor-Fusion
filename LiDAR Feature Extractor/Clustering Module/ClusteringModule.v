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