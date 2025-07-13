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
    input  logic [15:0] W_q [0:5][0:15],   // 6x16 weight matrices
    input  logic [15:0] W_k [0:5][0:15],
    input  logic [15:0] W_v [0:5][0:15],
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