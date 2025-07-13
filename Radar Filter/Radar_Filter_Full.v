module BackgroundModel #(
    parameter N = 16  // Kích thước cửa sổ, phải là lũy thừa của 2
) (
    input  wire clk,                     // Xung nhịp
    input  wire reset,                   // Tín hiệu reset
    input  wire valid_in,                // Tín hiệu hợp lệ đầu vào
    input  wire [15:0] intensity,        // Cường độ đầu vào
    output reg  [15:0] threshold         // Ngưỡng nhiễu
);
    initial begin
        if ((N & (N - 1)) != 0) begin
            $error("N must be a power of 2");
        end
    end
    reg [15:0] buffer [0:N-1];
    reg [31:0] sum = 0;
    reg [$clog2(N)-1:0] wptr = 0;
    reg [N-1:0] valid_buffer = 0;
    localparam SHIFT = $clog2(N);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wptr <= 0;
            sum <= 0;
            valid_buffer <= 0;
            threshold <= 16'h00FF;  // Ngưỡng mặc định
        end else if (valid_in) begin
            if (valid_buffer[wptr]) begin
                sum <= sum - buffer[wptr] + intensity;
            end else begin
                sum <= sum + intensity;
            end
            buffer[wptr] <= intensity;
            valid_buffer[wptr] <= 1'b1;
            wptr <= (wptr == N-1) ? 0 : wptr + 1;
            if (&valid_buffer) begin
                threshold <= sum >> SHIFT;
            end else begin
                threshold <= 16'h00FF;  // Giữ ngưỡng mặc định
            end
        end
    end
endmodule

module IntensityExtractor (
    input  wire [127:0] filtered_point,  // Điểm đã lọc
    output wire [15:0]  intensity        // Cường độ tín hiệu
);
    assign intensity = filtered_point[15:0];
endmodule

module StaticFilter (
    input  wire clk,                     // Xung nhịp
    input  wire reset,                   // Tín hiệu reset
    input  wire valid_in,                // Tín hiệu hợp lệ đầu vào
    input  wire [127:0] filtered_point,  // Điểm đã lọc
    input  wire [15:0]  threshold,       // Ngưỡng nhiễu
    output reg  valid_out,               // Tín hiệu hợp lệ đầu ra
    output reg  [127:0] clean_point      // Điểm sạch
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            valid_out <= 0;
            clean_point <= 0;
        end else begin
            valid_out <= valid_in;
            if (valid_in) begin
                if (filtered_point[15:0] >= threshold) begin
                    clean_point <= filtered_point;
                end else begin
                    clean_point <= {16'h0000, filtered_point[111:0]};
                end
            end else begin
                clean_point <= clean_point;  // Giữ giá trị hiện tại
            end
        end
    end
endmodule

module ClutterRemover #(
    parameter N = 16  // Kích thước cửa sổ trung bình
) (
    input  wire clk,                     // Xung nhịp
    input  wire reset,                   // Tín hiệu reset
    input  wire valid_in,                // Tín hiệu hợp lệ đầu vào
    input  wire [127:0] filtered_point,  // Điểm đã lọc
    output wire valid_out,               // Tín hiệu hợp lệ đầu ra
    output wire [127:0] clean_point      // Điểm sạch
);
    wire [15:0] intensity;
    wire [15:0] threshold;
    IntensityExtractor extractor (
        .filtered_point(filtered_point),
        .intensity(intensity)
    );
    BackgroundModel #(N) bg_model (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .intensity(intensity),
        .threshold(threshold)
    );
    StaticFilter static_filter (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .filtered_point(filtered_point),
        .threshold(threshold),
        .valid_out(valid_out),
        .clean_point(clean_point)
    );
endmodule

module phase_extractor #(
    parameter PHASE_OFFSET = 0
) (
    input  wire         clk,
    input  wire         reset,
    input  wire         data_valid,
    input  wire [127:0] clean_point,
    output reg  [15:0]  phase_diff,
    output reg          diff_valid
);

    reg [15:0] prev_phase;  // Phase trước đó
    reg        prev_valid;  // Trạng thái valid trước đó

    // Hàm tính chênh lệch pha, xử lý wrap-around
    function automatic signed [16:0] calc_diff(input [15:0] a, b);
        logic signed [16:0] diff = a - b;
        if (diff > 32767)      return diff - 65536;
        else if (diff < -32768) return diff + 65536;
        else                   return diff;
    endfunction

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            prev_phase <= 16'b0;
            phase_diff <= 16'b0;
            diff_valid <= 1'b0;
            prev_valid <= 1'b0;
        end else begin
            diff_valid <= 1'b0;
            
            if (data_valid) begin
                wire [15:0] current_phase = clean_point[PHASE_OFFSET +: 16];
                
                if (prev_valid) begin
                    phase_diff <= calc_diff(current_phase, prev_phase)[15:0];
                    diff_valid <= 1'b1;
                end
                
                prev_phase <= current_phase;
                prev_valid <= 1'b1;
            end else begin
                prev_valid <= 1'b0;
            end
        end
    end
endmodule

module velocity_lut #(
    parameter LUT_DEPTH = 256
) (
    input  wire         clk,
    input  wire         reset,
    input  wire         phase_valid,
    input  wire [15:0]  phase_diff,
    output reg  [15:0]  velocity,
    output reg          vel_valid
);

    reg signed [15:0] lut [0:LUT_DEPTH-1];  // LUT chứa giá trị vận tốc
    wire signed [7:0] index = phase_diff[7:0];  // Index có dấu từ 8 bit thấp nhất
    reg valid_pipe;  // Pipeline tín hiệu valid

    // Khởi tạo LUT mẫu
    initial begin
        for (int i = 0; i < LUT_DEPTH; i++) begin
            lut[i] = (i < 128) ? i : i - 256; // Giá trị từ -128 đến 127
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            velocity  <= 16'b0;
            vel_valid <= 1'b0;
            valid_pipe <= 1'b0;
        end else begin
            valid_pipe <= phase_valid;
            vel_valid  <= valid_pipe;
            
            if (phase_valid) begin
                velocity <= lut[index];
            end
        end
    end
endmodule

module doppler_processor #(
    parameter PHASE_OFFSET = 0,    // Vị trí phase trong clean_point
    parameter LUT_DEPTH = 256      // Kích thước LUT
)(
    input  wire         clk,          // Clock
    input  wire         reset,        // Reset
    input  wire         data_valid,   // Tín hiệu valid đầu vào
    input  wire [127:0] clean_point,  // Điểm sạch 128-bit
    output wire [15:0]  velocity,     // Vận tốc (signed)
    output wire         vel_valid     // Tín hiệu valid đầu ra
);

    wire [15:0] phase_diff;  // Độ lệch pha
    wire        diff_valid;  // Tín hiệu valid của phase_diff

    // Module Phase Extractor
    phase_extractor #(.PHASE_OFFSET(PHASE_OFFSET)) u_phase_extractor (
        .clk         (clk),
        .reset       (reset),
        .data_valid  (data_valid),
        .clean_point (clean_point),
        .phase_diff  (phase_diff),
        .diff_valid  (diff_valid)
    );

    // Module Velocity LUT
    velocity_lut #(.LUT_DEPTH(LUT_DEPTH)) u_velocity_lut (
        .clk         (clk),
        .reset       (reset),
        .phase_valid (diff_valid),
        .phase_diff  (phase_diff),
        .velocity    (velocity),
        .vel_valid   (vel_valid)
    );

endmodule


module Coordinate_Splitter (
    input  logic [127:0] window_in [0:4],
    output logic [31:0]  X [0:4],
    output logic [31:0]  Y [0:4],
    output logic [31:0]  Z [0:4]
);

    // Bit [127:96] (W) không được sử dụng
    for (genvar i = 0; i < 5; i++) begin
        assign X[i] = window_in[i][31:0];    // X: bits [31:0]
        assign Y[i] = window_in[i][63:32];   // Y: bits [63:32]
        assign Z[i] = window_in[i][95:64];   // Z: bits [95:64]
    end
endmodule


module Data_Reassembler (
    input  logic [31:0]  median_X,
    input  logic [31:0]  median_Y,
    input  logic [31:0]  median_Z,
    input  logic [127:0] current_point,  // Điểm gốc để lấy W
    output logic [127:0] filtered_point
);

    // W field (bits [127:96]) giữ nguyên từ điểm hiện tại
    assign filtered_point = {current_point[127:96], median_Z, median_Y, median_X};
endmodule

module Median_Calculator (
    input  logic signed [31:0] data_in [0:4],
    output logic signed [31:0] median
);

    // Định nghĩa các giai đoạn cho mạng sắp xếp
    logic signed [31:0] stage1[0:4];
    logic signed [31:0] stage2[0:4];
    logic signed [31:0] stage3[0:4];
    logic signed [31:0] stage4[0:4];
    logic signed [31:0] stage5[0:4];
    logic signed [31:0] stage6[0:4];
    logic signed [31:0] stage7[0:4];
    logic signed [31:0] stage8[0:4];
    logic signed [31:0] stage9[0:4];

    // Giai đoạn 1: So sánh và hoán đổi 0 và 1
    assign stage1[0] = (data_in[0] < data_in[1]) ? data_in[0] : data_in[1];
    assign stage1[1] = (data_in[0] < data_in[1]) ? data_in[1] : data_in[0];
    assign stage1[2] = data_in[2];
    assign stage1[3] = data_in[3];
    assign stage1[4] = data_in[4];

    // Giai đoạn 2: So sánh và hoán đổi 3 và 4
    assign stage2[0] = stage1[0];
    assign stage2[1] = stage1[1];
    assign stage2[2] = stage1[2];
    assign stage2[3] = (stage1[3] < stage1[4]) ? stage1[3] : stage1[4];
    assign stage2[4] = (stage1[3] < stage1[4]) ? stage1[4] : stage1[3];

    // Giai đoạn 3: So sánh và hoán đổi 2 và 4
    assign stage3[0] = stage2[0];
    assign stage3[1] = stage2[1];
    assign stage3[2] = (stage2[2] < stage2[4]) ? stage2[2] : stage2[4];
    assign stage3[4] = (stage2[2] < stage2[4]) ? stage2[4] : stage2[2];
    assign stage3[3] = stage2[3];

    // Giai đoạn 4: So sánh và hoán đổi 2 và 3
    assign stage4[0] = stage3[0];
    assign stage4[1] = stage3[1];
    assign stage4[2] = (stage3[2] < stage3[3]) ? stage3[2] : stage3[3];
    assign stage4[3] = (stage3[2] < stage3[3]) ? stage3[3] : stage3[2];
    assign stage4[4] = stage3[4];

    // Giai đoạn 5: So sánh và hoán đổi 1 và 4
    assign stage5[0] = stage4[0];
    assign stage5[1] = (stage4[1] < stage4[4]) ? stage4[1] : stage4[4];
    assign stage5[4] = (stage4[1] < stage4[4]) ? stage4[4] : stage4[1];
    assign stage5[2] = stage4[2];
    assign stage5[3] = stage4[3];

    // Giai đoạn 6: So sánh và hoán đổi 0 và 3
    assign stage6[0] = (stage5[0] < stage5[3]) ? stage5[0] : stage5[3];
    assign stage6[3] = (stage5[0] < stage5[3]) ? stage5[3] : stage5[0];
    assign stage6[1] = stage5[1];
    assign stage6[2] = stage5[2];
    assign stage6[4] = stage5[4];

    // Giai đoạn 7: So sánh và hoán đổi 0 và 2
    assign stage7[0] = (stage6[0] < stage6[2]) ? stage6[0] : stage6[2];
    assign stage7[2] = (stage6[0] < stage6[2]) ? stage6[2] : stage6[0];
    assign stage7[1] = stage6[1];
    assign stage7[3] = stage6[3];
    assign stage7[4] = stage6[4];

    // Giai đoạn 8: So sánh và hoán đổi 1 và 3
    assign stage8[0] = stage7[0];
    assign stage8[1] = (stage7[1] < stage7[3]) ? stage7[1] : stage7[3];
    assign stage8[3] = (stage7[1] < stage7[3]) ? stage7[3] : stage7[1];
    assign stage8[2] = stage7[2];
    assign stage8[4] = stage7[4];

    // Giai đoạn 9: So sánh và hoán đổi 1 và 2
    assign stage9[0] = stage8[0];
    assign stage9[1] = (stage8[1] < stage8[2]) ? stage8[1] : stage8[2];
    assign stage9[2] = (stage8[1] < stage8[2]) ? stage8[2] : stage8[1];
    assign stage9[3] = stage8[3];
    assign stage9[4] = stage8[4];

    // Giá trị trung vị là phần tử thứ ba trong mảng đã sắp xếp
    assign median = stage9[2];
endmodule


module Window_Buffer (
    input  logic        clk,
    input  logic        rst,
    input  logic        valid_in,       // Tín hiệu valid đầu vào
    input  logic [127:0] raw_point,
    output logic [127:0] window_out [0:4],
    output logic        buffer_full     // Báo hiệu buffer đã đầy
);

    logic [127:0] buffer [0:4];
    logic [2:0] count;             // Đếm số điểm đã nhận

    always_ff @(posedge clk) begin
        if (rst) begin
            count <= 0;
            buffer_full <= 0;
            for (int i = 0; i < 5; i++) buffer[i] <= '1; // Giá trị không hợp lệ
        end
        else if (valid_in) begin
            // Dịch chuyển buffer
            for (int i = 0; i < 4; i++) buffer[i] <= buffer[i+1];
            buffer[4] <= raw_point;
            
            // Cập nhật bộ đếm và trạng thái buffer
            count <= (count == 5) ? count : count + 1;
            buffer_full <= (count >= 4);
        end
    end

    assign window_out = buffer;
endmodule


module Noise_Reducer (
    input  logic        clk,
    input  logic        rst,
    input  logic        valid_in,       // Tín hiệu valid đầu vào
    input  logic [127:0] raw_point,
    output logic [127:0] filtered_point,
    output logic        valid_out       // Tín hiệu valid đầu ra
);

    // Tín hiệu nội bộ
    logic [127:0] window [0:4];
    logic [31:0] X[0:4], Y[0:4], Z[0:4];
    logic [31:0] med_X, med_Y, med_Z;
    logic buffer_full;

    Window_Buffer wb (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_in),
        .raw_point(raw_point),
        .window_out(window),
        .buffer_full(buffer_full)
    );

    Coordinate_Splitter cs (
        .window_in(window),
        .X(X),
        .Y(Y),
        .Z(Z)
    );

    Median_Calculator calc_X (.data_in(X), .median(med_X));
    Median_Calculator calc_Y (.data_in(Y), .median(med_Y));
    Median_Calculator calc_Z (.data_in(Z), .median(med_Z));

    Data_Reassembler dr (
        .median_X(med_X),
        .median_Y(med_Y),
        .median_Z(med_Z),
        .current_point(raw_point),
        .filtered_point(filtered_point)
    );

    // Delay valid signal theo pipeline
    logic [2:0] valid_delay;
    always_ff @(posedge clk) begin
        if (rst) valid_delay <= 0;
        else valid_delay <= {valid_delay[1:0], valid_in & buffer_full};
    end
    assign valid_out = valid_delay[2];
endmodule

module Point_Packer (
    input  wire         clk,          // Clock đồng bộ
    input  wire         rst_n,        // Reset tích cực mức thấp
    input  wire [127:0] clean_point,  // Đầu vào: Điểm sạch 128-bit từ Clutter Remover
    input  wire [15:0]  velocity,     // Đầu vào: Vận tốc 16-bit từ Doppler Processor
    output reg  [127:0] point_cloud_data // Đầu ra: Đám mây điểm radar 128-bit
);

// Pipeline đăng ký đầu ra
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        point_cloud_data <= 128'b0; // Khởi tạo đầu ra về 0 khi reset
    end
    else begin
        point_cloud_data <= {clean_point[127:16], velocity}; // Ghép 112 bit cao của clean_point với 16 bit velocity
    end
end

endmodule


module Radar_Point_Cloud_Generator (
    input  wire         clk,          // Clock đồng bộ
    input  wire         rst_n,        // Reset tích cực mức thấp
    input  wire [127:0] clean_point,  // Đầu vào: Điểm sạch 128-bit từ Clutter Remover
    input  wire [15:0]  velocity,     // Đầu vào: Vận tốc 16-bit từ Doppler Processor
    output wire [127:0] point_cloud_data // Đầu ra: Đám mây điểm radar 128-bit
);

// Pipeline đăng ký đầu ra
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        point_cloud_data <= 128'b0; // Khởi tạo đầu ra về 0 khi reset
    end
    else begin
        point_cloud_data <= {clean_point[127:16], velocity}; // Ghép 112 bit cao của clean_point với 16 bit velocity
    end
end

endmodule


module Radar_Filter (
    input  wire         clk,            // System clock
    input  wire         reset,          // Active-high asynchronous reset
    input  wire         valid_in,       // Input data valid
    input  wire [127:0] raw_point,      // Raw radar data point
    output wire         valid_out,      // Output data valid
    output wire [127:0] point_cloud_data // Filtered radar point cloud
);

    // Internal pipeline control signals
    wire [127:0] filtered_point;
    wire [127:0] clean_point;
    wire [15:0]  velocity;
    
    wire valid_noise_out;
    wire valid_clutter_out;
    wire valid_doppler_out;
    wire pipeline_stall;

    // Reset synchronization (2-stage synchronizer)
    reg reset_sync1, sync_reset;
    always @(posedge clk) begin
        reset_sync1 <= reset;
        sync_reset  <= reset_sync1;
    end

    // Stall detection: Prevent overflow when downstream is not ready
    assign pipeline_stall = valid_out & ~valid_in;

    //---------------------------------------------------------------------
    // Processing Pipeline
    //---------------------------------------------------------------------
    Noise_Reducer noise_reducer (
        .clk            (clk),
        .rst            (sync_reset || pipeline_stall),
        .valid_in       (valid_in && !pipeline_stall),
        .raw_point      (raw_point),
        .filtered_point (filtered_point),
        .valid_out      (valid_noise_out)
    );

    ClutterRemover #(.N(16)) clutter_remover (
        .clk            (clk),
        .reset          (sync_reset || pipeline_stall),
        .valid_in       (valid_noise_out),
        .filtered_point (filtered_point),
        .valid_out      (valid_clutter_out),
        .clean_point    (clean_point)
    );

    doppler_processor #(
        .PHASE_OFFSET(0),
        .LUT_DEPTH(256)
    ) doppler_proc (
        .clk          (clk),
        .reset        (sync_reset || pipeline_stall),
        .data_valid   (valid_clutter_out),
        .clean_point  (clean_point),
        .velocity     (velocity),
        .vel_valid    (valid_doppler_out)
    );

    Radar_Point_Cloud_Generator pc_generator (
        .clk              (clk),
        .rst_n            (~(sync_reset || pipeline_stall)),
        .clean_point      (clean_point),
        .velocity         (velocity),
        .point_cloud_data (point_cloud_data)
    );

    //---------------------------------------------------------------------
    // Output Validation & Pipeline Control
    //---------------------------------------------------------------------
    reg valid_out_reg;
    always @(posedge clk or posedge sync_reset) begin
        if (sync_reset) valid_out_reg <= 1'b0;
        else if (pipeline_stall) valid_out_reg <= valid_out_reg; // Maintain state
        else valid_out_reg <= valid_doppler_out;
    end

    assign valid_out = valid_out_reg;

endmodule


