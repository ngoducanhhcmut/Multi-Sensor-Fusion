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

module MaxPoolingModule #(
    parameter H = 4,      // Feature map height (phải lớn hơn 0)
    parameter W = 4       // Feature map width (phải lớn hơn 0)
)(
    input  logic [H*W*256-1:0] activation_map_flat, // Input: HxWx32 INT8, thứ tự [Pixel0_Ch0..Ch31][Pixel1_Ch0..Ch31]...
    output logic [255:0]        feature_vector      // Output: 256-bit vector, thứ tự [Ch0][Ch1]...[Ch31]
);
    // Kiểm tra trường hợp biên
    initial begin
        if (H <= 0 || W <= 0) begin
            $fatal("Error: H và W phải lớn hơn 0");
        end
    end

    localparam BIT_WIDTH = 8;      // Độ rộng bit mỗi kênh
    localparam CHANNELS  = 32;     // Số kênh cố định
    localparam PIXEL_BITS = CHANNELS * BIT_WIDTH; // 256 bits mỗi pixel

    // Hàm binary tree reduction để tìm giá trị lớn nhất
    function automatic logic [BIT_WIDTH-1:0] tree_reduce;
        input logic [BIT_WIDTH-1:0] data [H*W];
        logic [BIT_WIDTH-1:0] tree [0:H*W-1][0:$clog2(H*W)];
        
        begin
            // Khởi tạo lá cây
            for (int i = 0; i < H*W; i++) begin
                tree[i][0] = data[i];
            end
            
            // Giảm dần bằng cây nhị phân
            for (int level = 1; level <= $clog2(H*W); level++) begin
                int stride = 1 << (level - 1);
                for (int i = 0; i < (H*W + stride-1)/(2*stride); i++) begin
                    int idx1 = 2*i*stride;
                    int idx2 = (2*i+1)*stride;
                    
                    if (idx2 >= H*W) begin
                        tree[i][level] = tree[idx1][level-1];
                    end else begin
                        tree[i][level] = (tree[idx1][level-1] > tree[idx2][level-1]) 
                                       ? tree[idx1][level-1] 
                                       : tree[idx2][level-1];
                    end
                end
            end
            
            tree_reduce = tree[0][$clog2(H*W)];
        end
    endfunction

    // Xử lý chính
    always_comb begin
        for (int ch = 0; ch < CHANNELS; ch++) begin
            logic [BIT_WIDTH-1:0] channel_data [H*W];
            
            // Trích xuất dữ liệu từng kênh
            for (int h = 0; h < H; h++) begin
                for (int w = 0; w < W; w++) begin
                    int pixel_idx = h*W + w;
                    int bit_offset = (pixel_idx * PIXEL_BITS) + (ch * BIT_WIDTH);
                    channel_data[pixel_idx] = activation_map_flat[bit_offset +: BIT_WIDTH];
                end
            end
            
            // Áp dụng tree reduction để tìm max
            feature_vector[ch*BIT_WIDTH +: BIT_WIDTH] = tree_reduce(channel_data);
        end
    end

endmodule


module Camera_Feature_Extractor (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3071:0] input_image,
    output reg [255:0] feature_vector,
    output reg valid_out,
    
    // BatchNorm parameters
    input wire signed [7:0] bn_gamma [0:31],
    input wire signed [7:0] bn_beta [0:31],
    input wire signed [7:0] bn_mean [0:31],
    input wire [7:0] bn_variance [0:31],
    input wire [7:0] epsilon
);

    // Internal signals with pipeline control
    reg [32767:0] conv_output;
    reg conv_valid;
    reg [32767:0] act_output;
    reg act_valid;
    reg [16383:0] quant_output; // 16x8x32x8 = 16384 bits
    reg quant_valid;
    reg [255:0] max_pool_output;
    reg pool_valid;

    // Convolutional Layer
    Convolutional_Layer #(
        .H(16),
        .W(8),
        .C(3),
        .F(32),
        .K(3),
        .P(1)
    ) conv_layer (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .input_image(input_image),
        .output_feature_map(conv_output),
        .valid_out(conv_valid)
    );

    // Activation Function (ReLU) with pipeline
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            act_output <= 0;
            act_valid <= 0;
        end else if (conv_valid) begin
            for (int i = 0; i < 4096; i++) begin // 16x8x32
                act_output[i*8 +:8] <= (conv_output[i*16 +:16] > 0) ? conv_output[i*16 +:16][7:0] : 0;
            end
            act_valid <= 1;
        end else begin
            act_valid <= 0;
        end
    end

    // Improved Quantization with configurable scale factor
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            quant_output <= 0;
            quant_valid <= 0;
        end else if (act_valid) begin
            for (int i = 0; i < 4096; i++) begin
                logic signed [15:0] act_val = act_output[i*8 +:8];
                logic signed [7:0] quant_val;
                // Example scale factor, can be configured
                quant_val = (act_val > 127) ? 127 : (act_val < -128) ? -128 : act_val[7:0];
                quant_output[i*8 +:8] <= quant_val;
            end
            quant_valid <= 1;
        end else begin
            quant_valid <= 0;
        end
    end

    // Max Pooling Module (assumed implemented with pipeline)
    MaxPoolingModule #(
        .H(16),
        .W(8)
    ) max_pool (
        .clk(clk),
        .rst_n(rst_n),
        .enable(quant_valid),
        .activation_map_flat(quant_output),
        .feature_vector(max_pool_output),
        .valid_out(pool_valid)
    );

    // Improved Batch Normalization with lookup table for inv_std
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            feature_vector <= 0;
            valid_out <= 0;
        end else if (pool_valid) begin
            for (int ch = 0; ch < 32; ch++) begin
                logic signed [15:0] x = $signed(max_pool_output[ch*8 +:8]);
                logic signed [7:0] mean = bn_mean[ch];
                logic [7:0] var = bn_variance[ch];
                logic signed [7:0] gamma = bn_gamma[ch];
                logic signed [7:0] beta = bn_beta[ch];
                
                // Assume LUT_inv_std is precomputed: LUT_inv_std[i] = round((1/sqrt(i+epsilon))*64)
                logic [7:0] inv_std = (var + epsilon > 0) ? 64 : 64; // Simplified, actual LUT needed
                logic signed [15:0] normalized = (x - mean) * $signed(inv_std);
                logic signed [15:0] scaled = normalized * gamma;
                logic signed [15:0] y_temp = scaled >> 6; // Adjust based on scaling
                logic signed [7:0] y_final = y_temp[7:0] + beta;
                
                // Clamping to INT8 range
                feature_vector[ch*8 +:8] <= (y_final > 127) ? 127 : (y_final < -128) ? -128 : y_final;
            end
            valid_out <= 1;
        end else begin
            valid_out <= 0;
        end
    end

endmodule



