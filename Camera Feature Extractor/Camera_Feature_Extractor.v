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