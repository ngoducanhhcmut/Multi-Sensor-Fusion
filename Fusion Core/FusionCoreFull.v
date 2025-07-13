// Attention Calculator Module
module AttentionCalculator #(
    parameter int SHIFT_AMOUNT = 2,        // sqrt(6) ≈ 2.45 → shift 2 bits ≈ /4
    parameter logic [63:0] LINEAR_NORM = 0 // LinearNorm as a constant, default 0
) (
    input  logic [191:0] Q,    // 192-bit Q vector (6x32-bit fixed-point)
    input  logic [191:0] K,    // 192-bit K vector (6x32-bit fixed-point)
    output logic [63:0] attention_weight // 64-bit attention score
);
    logic [95:0] dot_product_wide; // 96-bit accumulator

    always_comb begin
        dot_product_wide = 96'd0;
        // Compute dot product: Q · K
        for (int i = 0; i < 6; i++) begin
            logic signed [31:0] Q_i = Q[i*32 +: 32];
            logic signed [31:0] K_i = K[i*32 +: 32];
            logic signed [63:0] prod = Q_i * K_i; // 64-bit product
            dot_product_wide = dot_product_wide + {{32{prod[63]}}, prod}; // Sign-extend to 96-bit
        end
        // Compute attention score: (dot_product / sqrt(d)) + LinearNorm
        logic [95:0] shifted = $signed(dot_product_wide) >>> SHIFT_AMOUNT;
        logic [95:0] normalized = shifted + {{32{LINEAR_NORM[63]}}, LINEAR_NORM};
        // Check for overflow
        if (normalized[95:64] != {32{normalized[63]}}) begin
            attention_weight = normalized[63] ? 64'h8000_0000_0000_0000 : 64'h7FFF_FFFF_FFFF_FFFF;
        end else begin
            attention_weight = normalized[63:0];
        end
    end
endmodule


// Concatenator Module
module Concatenator (
    input  logic [511:0] fused_feature1, // Fused feature from sensor 1 (512-bit)
    input  logic [511:0] fused_feature2, // Fused feature from sensor 2 (512-bit)
    input  logic [511:0] fused_feature3, // Fused feature from sensor 3 (512-bit)
    output logic [1535:0] raw_tensor     // 1536-bit concatenated tensor
);
    // Concatenate three 512-bit features into 1536-bit tensor
    // Order: fused_feature3 (MSB), fused_feature2, fused_feature1 (LSB)
    assign raw_tensor = {fused_feature3, fused_feature2, fused_feature1};
endmodule

module fault_monitor (
    input logic clk,
    input logic rst_n,
    input logic [255:0] sensor1,
    input logic [255:0] sensor2,
    input logic [255:0] sensor3,
    output logic [3:0] error_code
);
    parameter int DATA_WIDTH = 16;
    parameter int NUM_WORDS = 15;
    parameter int CHECKSUM_WIDTH = 16;
    
    logic [2:0] signal_loss_shreg [1:3];
    logic [2:0] range_error_shreg [1:3];
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int s = 1; s <= 3; s++) begin
                signal_loss_shreg[s] <= 3'b111;
                range_error_shreg[s] <= 3'b111;
            end
        end else begin
            signal_loss_shreg[1] <= {signal_loss_shreg[1][1:0], (sensor1 == 256'h0)};
            range_error_shreg[1] <= {range_error_shreg[1][1:0], check_range(sensor1[239:0])};
            signal_loss_shreg[2] <= {signal_loss_shreg[2][1:0], (sensor2 == 256'h0)};
            range_error_shreg[2] <= {range_error_shreg[2][1:0], check_range(sensor2[239:0])};
            signal_loss_shreg[3] <= {signal_loss_shreg[3][1:0], (sensor3 == 256'h0)};
            range_error_shreg[3] <= {range_error_shreg[3][1:0], check_range(sensor3[239:0])};
        end
    end
    
    function logic [CHECKSUM_WIDTH-1:0] compute_checksum(input [239:0] data);
        logic [CHECKSUM_WIDTH:0] sum = 0;
        for (int i = 0; i < NUM_WORDS; i++) begin
            sum = sum + data[i*DATA_WIDTH +: DATA_WIDTH];
        end
        return sum[CHECKSUM_WIDTH-1:0];
    endfunction
    
    function logic check_range(input [239:0] data);
        for (int i = 0; i < NUM_WORDS; i++) begin
            logic signed [DATA_WIDTH-1:0] word = data[i*DATA_WIDTH +: DATA_WIDTH];
            if (word < -10000 || word > 10000) return 1'b1;
        end
        return 1'b0;
    endfunction
    
    always_comb begin
        error_code = 4'b0;
        error_code[0] = (compute_checksum(sensor1[239:0]) != sensor1[255:240]) ||
                        (compute_checksum(sensor2[239:0]) != sensor2[255:240]) ||
                        (compute_checksum(sensor3[239:0]) != sensor3[255:240]);
        error_code[1] = (range_error_shreg[1] == 3'b111) ||
                        (range_error_shreg[2] == 3'b111) ||
                        (range_error_shreg[3] == 3'b111);
        error_code[2] = (signal_loss_shreg[1] == 3'b111) ||
                        (signal_loss_shreg[2] == 3'b111) ||
                        (signal_loss_shreg[3] == 3'b111);
        error_code[3] = 1'b0;
    end
endmodule

// Feature Fusion Module
module FeatureFusion (
    input  logic [63:0] attention_weight, // 64-bit attention weight
    input  logic [191:0] V,               // 192-bit V vector (6x32-bit fixed-point)
    output logic [511:0] fused_feature    // 512-bit fused feature
);
    logic [31:0] scaled_V [0:5]; // Array to hold scaled V elements

    for (genvar i = 0; i < 6; i++) begin : scale_block
        always_comb begin
            logic signed [31:0] V_i = V[i*32 +: 32];
            logic signed [95:0] full_prod = $signed(attention_weight) * $signed(V_i); // 64-bit * 32-bit = 96-bit
            logic signed [95:0] shifted_prod = full_prod >>> 16; // Shift right 16 bits for Q16.16
            // Check for overflow in 32-bit
            if (shifted_prod[95:32] != {64{shifted_prod[31]}}) begin
                scaled_V[i] = shifted_prod[31] ? 32'h8000_0000 : 32'h7FFF_FFFF;
            end else begin
                scaled_V[i] = shifted_prod[31:0];
            end
        end
    end

    // Expand 192-bit scaled vector to 512-bit with zero padding
    assign fused_feature = {{320{1'b0}}, // 320-bit zero padding
                           scaled_V[5], scaled_V[4], scaled_V[3],
                           scaled_V[2], scaled_V[1], scaled_V[0]}; // 192-bit scaled V
endmodule


module fusion_compressor (
    input logic clk,
    input logic rst_n,
    input logic [1535:0] raw_tensor,
    output logic [2047:0] fused_tensor
);
    parameter int INPUT_SIZE = 96;
    parameter int OUTPUT_SIZE = 128;
    parameter int BIT_WIDTH = 16;
    
    logic signed [BIT_WIDTH-1:0] weights [0:OUTPUT_SIZE-1][0:INPUT_SIZE-1];
    logic signed [BIT_WIDTH-1:0] bias [0:OUTPUT_SIZE-1];
    
    logic signed [BIT_WIDTH-1:0] input_vec_reg [0:INPUT_SIZE-1];
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < INPUT_SIZE; i++) input_vec_reg[i] <= 0;
        end else begin
            for (int i = 0; i < INPUT_SIZE; i++) begin
                input_vec_reg[i] <= raw_tensor[i*BIT_WIDTH +: BIT_WIDTH];
            end
        end
    end
    
    logic signed [37:0] accum [0:OUTPUT_SIZE-1];
    always_comb begin
        for (int i = 0; i < OUTPUT_SIZE; i++) begin
            accum[i] = bias[i];
            for (int j = 0; j < INPUT_SIZE; j++) begin
                accum[i] = accum[i] + ($signed(input_vec_reg[j]) * $signed(weights[i][j]));
            end
        end
    end
    
    logic signed [BIT_WIDTH-1:0] output_vec_reg [0:OUTPUT_SIZE-1];
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < OUTPUT_SIZE; i++) output_vec_reg[i] <= 0;
        end else begin
            for (int i = 0; i < OUTPUT_SIZE; i++) begin
                if (accum[i] <= 0) begin
                    output_vec_reg[i] <= 0;
                end else if (accum[i] > (1 << (BIT_WIDTH-1)) - 1) begin
                    output_vec_reg[i] <= (1 << (BIT_WIDTH-1)) - 1;
                end else begin
                    output_vec_reg[i] <= accum[i][BIT_WIDTH-1:0];
                end
            end
        end
    end
    
    always_comb begin
        for (int i = 0; i < OUTPUT_SIZE; i++) begin
            fused_tensor[i*BIT_WIDTH +: BIT_WIDTH] = output_vec_reg[i];
        end
    end
endmodule

module QKV_Generator (
    input  wire [255:0] normalized_vector,
    input  wire [15:0] W_q [0:11][0:15],  // Trọng số từ bên ngoài
    input  wire [15:0] W_k [0:11][0:15],
    input  wire [15:0] W_v [0:11][0:15],
    output wire [191:0] Q, K, V,
    output wire [2:0]   overflow  // Cờ tràn số
);
    wire signed [15:0] x [0:15];
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin
            assign x[i] = normalized_vector[16*i + 15 : 16*i];
        end
    endgenerate

    reg signed [39:0] accum_q [0:11];
    reg signed [39:0] accum_k [0:11];
    reg signed [39:0] accum_v [0:11];
    reg [2:0] ovf_flags;

    always_comb begin
        ovf_flags = 3'b0;
        for (int j = 0; j < 12; j = j + 1) begin
            accum_q[j] = 0;
            accum_k[j] = 0;
            accum_v[j] = 0;
            for (int k = 0; k < 16; k = k + 1) begin
                accum_q[j] = accum_q[j] + ($signed(W_q[j][k]) * $signed(x[k]));
                accum_k[j] = accum_k[j] + ($signed(W_k[j][k]) * $signed(x[k]));
                accum_v[j] = accum_v[j] + ($signed(W_v[j][k]) * $signed(x[k]));
            end
            // Kiểm tra tràn số cho 16-bit
            if (accum_q[j] > 32767 || accum_q[j] < -32768) ovf_flags[0] = 1'b1;
            if (accum_k[j] > 32767 || accum_k[j] < -32768) ovf_flags[1] = 1'b1;
            if (accum_v[j] > 32767 || accum_v[j] < -32768) ovf_flags[2] = 1'b1;
        end
    end

    generate
        for (i = 0; i < 12; i = i + 1) begin
            assign Q[16*i + 15 : 16*i] = (accum_q[i] > 32767) ? 32767 :
                                         (accum_q[i] < -32768) ? -32768 : accum_q[i][15:0];
            assign K[16*i + 15 : 16*i] = (accum_k[i] > 32767) ? 32767 :
                                         (accum_k[i] < -32768) ? -32768 : accum_k[i][15:0];
            assign V[16*i + 15 : 16*i] = (accum_v[i] > 32767) ? 32767 :
                                         (accum_v[i] < -32768) ? -32768 : accum_v[i][15:0];
        end
    endgenerate
    assign overflow = ovf_flags;
endmodule


module Sensor_Preprocessor #(
    parameter MIN_VAL = -16384,
    parameter MAX_VAL = 16383
) (
    input  wire [255:0] raw_vector,
    output wire [255:0] normalized_vector,
    output wire [15:0]  error_flags  // Thêm cờ báo lỗi
);
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : clip_loop
            wire signed [15:0] element = raw_vector[16*i + 15 : 16*i];
            wire signed [15:0] clipped_element;
            wire               out_of_range;
            
            assign out_of_range = (element < MIN_VAL) || (element > MAX_VAL);
            assign clipped_element = (element < MIN_VAL) ? MIN_VAL :
                                     (element > MAX_VAL) ? MAX_VAL :
                                     element;
            assign normalized_vector[16*i + 15 : 16*i] = clipped_element;
            assign error_flags[i] = out_of_range;  // Báo lỗi cho Fault Monitor
        end
    endgenerate
endmodule

module TMR_Voter (
    input  wire [191:0] copy1, copy2, copy3,
    output wire [191:0] voted,
    output wire [11:0]  error_flags  // Cờ lỗi cho 12 từ
);
    genvar i;
    generate
        for (i = 0; i < 12; i = i + 1) begin : vote_loop
            wire [15:0] c1 = copy1[16*i + 15 : 16*i];
            wire [15:0] c2 = copy2[16*i + 15 : 16*i];
            wire [15:0] c3 = copy3[16*i + 15 : 16*i];
            reg  [15:0] voted_word;
            reg         error;

            always_comb begin
                if (c1 == c2) begin
                    voted_word = c1;
                    error = 1'b0;
                end else if (c1 == c3) begin
                    voted_word = c1;
                    error = 1'b0;
                end else if (c2 == c3) begin
                    voted_word = c2;
                    error = 1'b0;
                end else begin
                    voted_word = c1;  // Chọn mặc định
                    error = 1'b1;     // Báo lỗi
                end
            end
            assign voted[16*i + 15 : 16*i] = voted_word;
            assign error_flags[i] = error;
        end
    endgenerate
endmodule


module FusionCore #(
    parameter MIN_VAL = -16384,
    parameter MAX_VAL = 16383,
    parameter SHIFT_AMOUNT = 2,
    parameter logic [63:0] LINEAR_NORM = 0,
    parameter DATA_WIDTH = 16,
    parameter NUM_WORDS = 15,
    parameter CHECKSUM_WIDTH = 16,
    parameter INPUT_SIZE = 96,
    parameter OUTPUT_SIZE = 128,
    parameter BIT_WIDTH = 16
) (
    input  logic clk,
    input  logic rst_n,
    input  logic [255:0] sensor1_raw,
    input  logic [255:0] sensor2_raw,
    input  logic [255:0] sensor3_raw,
    input  logic [15:0] W_q [0:11][0:15],
    input  logic [15:0] W_k [0:11][0:15],
    input  logic [15:0] W_v [0:11][0:15],
    input  logic signed [BIT_WIDTH-1:0] fc_weights [0:OUTPUT_SIZE-1][0:INPUT_SIZE-1],
    input  logic signed [BIT_WIDTH-1:0] fc_bias [0:OUTPUT_SIZE-1],
    output logic [2047:0] fused_tensor,
    output logic [3:0] error_code
);

    // Stage 1: Preprocessing and Monitoring
    logic [255:0] normalized [0:2];
    logic [15:0] error_flags [0:2];
    
    Sensor_Preprocessor #(.MIN_VAL(MIN_VAL), .MAX_VAL(MAX_VAL)) sp0 (
        .raw_vector(sensor1_raw),
        .normalized_vector(normalized[0]),
        .error_flags(error_flags[0])
    );
    Sensor_Preprocessor #(.MIN_VAL(MIN_VAL), .MAX_VAL(MAX_VAL)) sp1 (
        .raw_vector(sensor2_raw),
        .normalized_vector(normalized[1]),
        .error_flags(error_flags[1])
    );
    Sensor_Preprocessor #(.MIN_VAL(MIN_VAL), .MAX_VAL(MAX_VAL)) sp2 (
        .raw_vector(sensor3_raw),
        .normalized_vector(normalized[2]),
        .error_flags(error_flags[2])
    );

    fault_monitor #(.DATA_WIDTH(DATA_WIDTH), .NUM_WORDS(NUM_WORDS), .CHECKSUM_WIDTH(CHECKSUM_WIDTH)) fm (
        .clk(clk),
        .rst_n(rst_n),
        .sensor1(sensor1_raw),
        .sensor2(sensor2_raw),
        .sensor3(sensor3_raw),
        .error_code(error_code)
    );

    // Register normalized vectors
    logic [255:0] normalized_reg [0:2];
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 3; i++) normalized_reg[i] <= '0;
        end else begin
            for (int i = 0; i < 3; i++) normalized_reg[i] <= normalized[i];
        end
    end

    // Stage 2: QKV Generation and Voting
    logic [191:0] Q [0:2][0:2], K [0:2][0:2], V [0:2][0:2];
    logic [191:0] voted_Q [0:2], voted_K [0:2], voted_V [0:2];

    generate
        for (genvar s = 0; s < 3; s++) begin : sensors
            for (genvar i = 0; i < 3; i++) begin : tmr_instances
                QKV_Generator qkv (
                    .normalized_vector(normalized_reg[s]),
                    .W_q(W_q),
                    .W_k(W_k),
                    .W_v(W_v),
                    .Q(Q[s][i]),
                    .K(K[s][i]),
                    .V(V[s][i]),
                    .overflow() // ignore for now
                );
            end
            TMR_Voter voter_q (.copy1(Q[s][0]), .copy2(Q[s][1]), .copy3(Q[s][2]), .voted(voted_Q[s]), .error_flags());
            TMR_Voter voter_k (.copy1(K[s][0]), .copy2(K[s][1]), .copy3(K[s][2]), .voted(voted_K[s]), .error_flags());
            TMR_Voter voter_v (.copy1(V[s][0]), .copy2(V[s][1]), .copy3(V[s][2]), .voted(voted_V[s]), .error_flags());
        end
    endgenerate

    // Register voted Q, K, V
    logic [191:0] voted_Q_reg [0:2], voted_K_reg [0:2], voted_V_reg [0:2];
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 3; i++) begin
                voted_Q_reg[i] <= '0;
                voted_K_reg[i] <= '0;
                voted_V_reg[i] <= '0;
            end
        end else begin
            for (int i = 0; i < 3; i++) begin
                voted_Q_reg[i] <= voted_Q[i];
                voted_K_reg[i] <= voted_K[i];
                voted_V_reg[i] <= voted_V[i];
            end
        end
    end

    // Stage 3: Attention and Feature Fusion
    logic [63:0] attention_weight [0:2];
    logic [511:0] fused_feature [0:2];

    generate
        for (genvar s = 0; s < 3; s++) begin : attention_fusion
            AttentionCalculator #(.SHIFT_AMOUNT(SHIFT_AMOUNT), .LINEAR_NORM(LINEAR_NORM)) ac (
                .Q(voted_Q_reg[s]),
                .K(voted_K_reg[s]),
                .attention_weight(attention_weight[s])
            );
            FeatureFusion ff (
                .attention_weight(attention_weight[s]),
                .V(voted_V_reg[s]),
                .fused_feature(fused_feature[s])
            );
        end
    endgenerate

    // Register fused features
    logic [511:0] fused_feature_reg [0:2];
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 3; i++) fused_feature_reg[i] <= '0;
        end else begin
            for (int i = 0; i < 3; i++) fused_feature_reg[i] <= fused_feature[i];
        end
    end

    // Stage 4: Concatenation and Compression
    logic [1535:0] raw_tensor;
    Concatenator concat (
        .fused_feature1(fused_feature_reg[0]),
        .fused_feature2(fused_feature_reg[1]),
        .fused_feature3(fused_feature_reg[2]),
        .raw_tensor(raw_tensor)
    );

    fusion_compressor #(.INPUT_SIZE(INPUT_SIZE), .OUTPUT_SIZE(OUTPUT_SIZE), .BIT_WIDTH(BIT_WIDTH)) fc (
        .clk(clk),
        .rst_n(rst_n),
        .raw_tensor(raw_tensor),
        .weights(fc_weights),
        .bias(fc_bias),
        .fused_tensor(fused_tensor)
    );

endmodule
