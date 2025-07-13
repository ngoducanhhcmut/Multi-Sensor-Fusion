// Module: Convolutional_Layer
// Description: Optimized convolutional layer with pipelining and boundary handling
// Supports: 16x8x3 input, 16x8x16 output, 3x3 kernel, padding=1
module Convolutional_Layer (
    input  wire         clk,          // Clock
    input  wire         rst_n,        // Active-low reset
    input  wire         start,        // Start signal
    input  wire [3071:0] input_image, // 3072-bit RGB image (INT8)
    output logic [32767:0] output_feature_map, // 32768-bit output (INT16)
    output logic        valid_out     // Data valid
);

// Parameters
localparam H = 16;   // Image height
localparam W = 8;    // Image width
localparam C = 3;    // Input channels
localparam F = 16;   // Filters
localparam K = 3;    // Kernel size
localparam P = 1;    // Padding

// Image buffer (registered)
logic signed [7:0] img_buffer[0:H-1][0:W-1][0:C-1];

// Weights and biases (INT8 weights, INT16 biases)
logic signed [7:0] weights [0:F-1][0:C-1][0:K-1][0:K-1];
logic signed [15:0] biases [0:F-1];

// Feature map storage
logic signed [15:0] feature_map[0:H-1][0:W-1][0:F-1];

// Control signals
enum {IDLE, LOAD, PROCESS, DONE} state;
logic [4:0] row, col;  // 5-bit for 0-15 rows
logic [3:0] filter;    // 4-bit for 0-15 filters
logic [1:0] k_row, k_col; // Kernel indices

// Convolution pipeline registers
logic signed [15:0] partial_sum [0:F-1];
logic signed [15:0] final_sum [0:F-1];

// Weight initialization (example values)
initial begin
    foreach(weights[i,j,k,l]) weights[i][j][k][l] = 8'h01;
    foreach(biases[i]) biases[i] = 16'h0000;
end

// FSM Control
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        valid_out <= 0;
        row <= 0;
        col <= 0;
        filter <= 0;
        k_row <= 0;
        k_col <= 0;
        output_feature_map <= 0;
    end else begin
        case (state)
            IDLE: begin
                valid_out <= 0;
                if (start) begin
                    // Load input image
                    for (int i=0; i<H; i++) 
                        for (int j=0; j<W; j++) 
                            for (int k=0; k<C; k++)
                                img_buffer[i][j][k] <= input_image[(i*W*C + j*C + k)*8 +: 8];
                    state <= LOAD;
                end
            end
            
            LOAD: begin
                // Initialize processing
                row <= 0;
                col <= 0;
                filter <= 0;
                k_row <= 0;
                k_col <= 0;
                state <= PROCESS;
            end
            
            PROCESS: begin
                // Kernel window processing
                if (k_col < K-1) k_col <= k_col + 1;
                else begin
                    k_col <= 0;
                    if (k_row < K-1) k_row <= k_row + 1;
                    else begin
                        k_row <= 0;
                        if (filter < F-1) filter <= filter + 1;
                        else begin
                            filter <= 0;
                            if (col < W-1) col <= col + 1;
                            else begin
                                col <= 0;
                                if (row < H-1) row <= row + 1;
                                else state <= DONE;
                            end
                        end
                    end
                end
            end
            
            DONE: begin
                valid_out <= 1;
                state <= IDLE;
            end
        endcase
    end
end

// Convolution engine (pipelined)
always_ff @(posedge clk) begin
    if (state == PROCESS) begin
        // Stage 1: Partial sum calculation
        for (int f=0; f<F; f++) begin
            automatic int in_row = row + k_row - P;
            automatic int in_col = col + k_col - P;
            automatic logic signed [7:0] pixel_val = 
                (in_row >=0 && in_row < H && in_col >=0 && in_col < W) ? 
                img_buffer[in_row][in_col][filter % C] : 8'b0;
                
            automatic logic signed [15:0] product = 
                pixel_val * weights[f][filter % C][k_row][k_col];
            
            if (k_row ==0 && k_col==0) 
                partial_sum[f] <= product;
            else 
                partial_sum[f] <= partial_sum[f] + product;
        end
        
        // Stage 2: Final sum with bias (after kernel window)
        if (k_row == K-1 && k_col == K-1) begin
            for (int f=0; f<F; f++) begin
                automatic logic signed [31:0] biased = 
                    partial_sum[f] + biases[f];
                
                // Saturation logic
                if (biased > 32767) 
                    final_sum[f] <= 16'h7FFF;
                else if (biased < -32768)
                    final_sum[f] <= 16'h8000;
                else
                    final_sum[f] <= biased[15:0];
                
                // Store in feature map
                feature_map[row][col][f] <= final_sum[f];
            end
        end
    end
end

// Output flattening
always_comb begin
    output_feature_map = 0;
    for (int i=0; i<H; i++)
        for (int j=0; j<W; j++)
            for (int f=0; f<F; f++)
                output_feature_map[(i*W*F + j*F + f)*16 +:16] = feature_map[i][j][f];
end

endmodule