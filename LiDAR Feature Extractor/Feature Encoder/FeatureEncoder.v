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