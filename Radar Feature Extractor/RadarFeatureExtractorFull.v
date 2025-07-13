module AngleProcessor #(
    parameter NUM_ANTENNAS = 4,        // Số lượng anten
    parameter PHASE_WIDTH = 16,        // Độ rộng dữ liệu pha
    parameter ANGLE_WIDTH = 64,        // Độ rộng dữ liệu góc đầu ra
    parameter FIXED_POINT_FRAC = 48    // Độ chính xác fixed-point
) (
    input wire clk,                    // Clock
    input wire reset,                  // Reset
    input wire [PHASE_WIDTH-1:0] phase_data [0:NUM_ANTENNAS-1], // Dữ liệu pha từ các anten
    output reg [ANGLE_WIDTH-1:0] angle_out     // Góc ước lượng đầu ra
);

    // Thông số hệ thống cố định (fixed-point Q16.32)
    localparam LAMBDA = 48'h0000_0C28_F5C2;    // λ = 0.03m
    localparam D = 48'h0000_061C_0000;         // d = 0.015m
    localparam TWO_PI = 48'h0006_487E_D511;    // 2π
    
    // Biến trung gian
    reg signed [PHASE_WIDTH-1:0] phase_diff [0:NUM_ANTENNAS-2];
    reg signed [47:0] sum_phase_diff; // Fixed-point accumulator (Q16.32)
    reg signed [47:0] avg_phase_diff;
    reg signed [47:0] sin_theta;
    reg signed [47:0] denominator;
    reg valid_calculation;
    
    // Tính chênh lệch pha giữa các anten liền kề
    always @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < NUM_ANTENNAS-1; i++) begin
                phase_diff[i] <= 0;
            end
        end else begin
            for (int i = 0; i < NUM_ANTENNAS-1; i++) begin
                phase_diff[i] <= $signed(phase_data[i+1]) - $signed(phase_data[i]);
            end
        end
    end
    
    // Tổng hợp và tính trung bình chênh lệch pha
    always @(posedge clk) begin
        if (reset) begin
            sum_phase_diff <= 0;
            avg_phase_diff <= 0;
            valid_calculation <= 0;
        end else begin
            sum_phase_diff <= $signed(phase_diff[0]) + $signed(phase_diff[1]) + $signed(phase_diff[2]);
            avg_phase_diff <= sum_phase_diff / (NUM_ANTENNAS-1);
            valid_calculation <= 1;
        end
    end
    
    // Tính sin(theta) và xử lý trường hợp biên
    always @(posedge clk) begin
        if (reset) begin
            sin_theta <= 0;
            denominator <= 0;
            angle_out <= 0;
        end else if (valid_calculation) begin
            denominator <= TWO_PI * D;
            if (denominator != 0) begin
                sin_theta <= (LAMBDA * avg_phase_diff) / denominator;
            end else begin
                sin_theta <= 0; // Xử lý mẫu số = 0
            end
            
            // Giới hạn sin_theta trong [-1, 1] để tránh tràn số
            if (sin_theta > 48'h0001_0000_0000) begin
                angle_out <= {{(ANGLE_WIDTH-48){1'b0}}, 48'h0001_0000_0000};
            end else if (sin_theta < -48'h0001_0000_0000) begin
                angle_out <= {{(ANGLE_WIDTH-48){1'b1}}, -48'h0001_0000_0000};
            end else begin
                angle_out <= {{(ANGLE_WIDTH-48){sin_theta[47]}}, sin_theta[47:0]};
            end
        end
    end

endmodule


module FeatureCombiner #(
    parameter RANGE_WIDTH = 128,       // Độ rộng vector khoảng cách
    parameter VELOCITY_WIDTH = 64,     // Độ rộng vector vận tốc
    parameter ANGLE_WIDTH = 64,        // Độ rộng vector góc
    parameter FEATURE_WIDTH = 256      // Độ rộng vector đặc trưng
) (
    input wire clk,                    // Clock
    input wire reset,                  // Reset
    input wire valid_in,               // Tín hiệu hợp lệ đầu vào
    input wire [RANGE_WIDTH-1:0] range_vector,      // Vector khoảng cách
    input wire [VELOCITY_WIDTH-1:0] velocity_vector,// Vector vận tốc
    input wire [ANGLE_WIDTH-1:0] angle_vector,      // Vector góc
    output reg [FEATURE_WIDTH-1:0] feature_vector,  // Vector đặc trưng đầu ra
    output reg valid_out               // Tín hiệu hợp lệ đầu ra
);

    // Kiểm tra kích thước tại thời điểm biên dịch
    generate
        if (RANGE_WIDTH + VELOCITY_WIDTH + ANGLE_WIDTH != FEATURE_WIDTH) begin
            initial $fatal("Error: Tổng kích thước đầu vào (%0d + %0d + %0d = %0d) không khớp với FEATURE_WIDTH (%0d)",
                RANGE_WIDTH, VELOCITY_WIDTH, ANGLE_WIDTH, 
                RANGE_WIDTH + VELOCITY_WIDTH + ANGLE_WIDTH, FEATURE_WIDTH);
        end
    endgenerate

    // Kết hợp dữ liệu với tín hiệu điều khiển
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            feature_vector <= 0;
            valid_out <= 0;
        end else if (valid_in) begin
            feature_vector <= {range_vector, velocity_vector, angle_vector};
            valid_out <= 1;
        end else begin
            valid_out <= 0;
        end
    end

endmodule


// Module: Range_Processor
module Range_Processor (
    input wire clk,
    input wire reset,
    input wire [15:0] data_in [0:127],
    output reg [7:0] range_vector [0:15],
    output reg valid_out,
    output reg busy
);
    wire [15:0] fft_real [0:127];
    wire [15:0] fft_imag [0:127];
    wire fft_done;
    
    reg [15:0] magnitude [0:127];
    reg [6:0] calc_index;
    reg [7:0] peaks [0:15];
    reg [4:0] peak_count;
    reg [15:0] noise_threshold;
    
    typedef enum {IDLE, FFT_CALC, MAG_CALC, PEAK_DETECT, DONE} state_t;
    state_t state;

    fft_128_point fft_inst (
        .clk(clk),
        .reset(reset),
        .data_in(data_in),
        .real_out(fft_real),
        .imag_out(fft_imag),
        .done(fft_done)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            valid_out <= 0;
            busy <= 0;
            calc_index <= 0;
            peak_count <= 0;
            noise_threshold <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (~busy) begin
                        busy <= 1;
                        state <= FFT_CALC;
                    end
                end
                FFT_CALC: begin
                    if (fft_done) begin
                        calc_index <= 0;
                        state <= MAG_CALC;
                    end
                end
                MAG_CALC: begin
                    automatic real abs_real = $unsigned(fft_real[calc_index]);
                    automatic real abs_imag = $unsigned(fft_imag[calc_index]);
                    automatic real max_val = (abs_real > abs_imag) ? abs_real : abs_imag;
                    automatic real min_val = (abs_real > abs_imag) ? abs_imag : abs_real;
                    magnitude[calc_index] <= (max_val * 0.96) + (min_val * 0.4);
                    
                    if (calc_index == 127) begin
                        automatic real sum = 0;
                        for (int i = 0; i < 10; i++) sum += magnitude[i];
                        noise_threshold <= (sum / 10) * 1.5;
                        state <= PEAK_DETECT;
                    end else begin
                        calc_index <= calc_index + 1;
                    end
                end
                PEAK_DETECT: begin
                    peak_count <= 0;
                    for (int i = 1; i < 127; i++) begin
                        if (magnitude[i] > magnitude[i-1] && magnitude[i] > magnitude[i+1] && magnitude[i] > noise_threshold) begin
                            if (peak_count < 16) begin
                                peaks[peak_count] <= i;
                                peak_count <= peak_count + 1;
                            end
                        end
                    end
                    for (int i = peak_count; i < 16; i++) peaks[i] <= 0;
                    state <= DONE;
                end
                DONE: begin
                    range_vector <= peaks;
                    valid_out <= 1;
                    busy <= 0;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule


// Module: Doppler_FFT
module Doppler_FFT (
    input wire clk,
    input wire reset,
    input wire [15:0] range_bins [0:15],
    output reg [15:0] doppler_out_real [0:15],
    output reg [15:0] doppler_out_imag [0:15],
    output reg valid_out,
    output reg busy
);
    reg [15:0] chirp_buffer [0:15][0:15];
    reg [3:0] chirp_index;
    
    wire [15:0] fft_real [0:15];
    wire [15:0] fft_imag [0:15];
    wire fft_done;
    
    fft_16_point fft_inst (
        .clk(clk),
        .reset(reset),
        .data_in(chirp_buffer[chirp_index]),
        .real_out(fft_real),
        .imag_out(fft_imag),
        .done(fft_done)
    );

    typedef enum {IDLE, STORE_CHIRP, FFT_PROCESS, OUTPUT} state_t;
    state_t state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            valid_out <= 0;
            busy <= 0;
            chirp_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (~busy) begin
                        busy <= 1;
                        chirp_index <= 0;
                        state <= STORE_CHIRP;
                    end
                end
                STORE_CHIRP: begin
                    chirp_buffer[chirp_index] <= range_bins;
                    if (chirp_index == 15) begin
                        chirp_index <= 0;
                        state <= FFT_PROCESS;
                    end else begin
                        chirp_index <= chirp_index + 1;
                        busy <= 0;
                    end
                end
                FFT_PROCESS: begin
                    if (fft_done) begin
                        doppler_out_real <= fft_real;
                        doppler_out_imag <= fft_imag;
                        state <= OUTPUT;
                    end
                end
                OUTPUT: begin
                    valid_out <= 1;
                    busy <= 0;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule


// Module: Noise_Filter
module Noise_Filter (
    input wire clk,
    input wire reset,
    input wire [15:0] real_in [0:15],
    input wire [15:0] imag_in [0:15],
    output reg [7:0] velocity_vector [0:7],
    output reg valid_out,
    output reg busy
);
    parameter GUARD_CELLS = 2;
    parameter TRAIN_CELLS = 4;
    parameter THRESHOLD_FACTOR = 1.5;
    
    reg [15:0] magnitude [0:15];
    reg [15:0] cfar_threshold [0:15];
    reg [4:0] index;
    reg [7:0] peaks [0:7];
    reg [3:0] peak_count;
    
    typedef enum {IDLE, CALC_MAG, CFAR_PROCESS, PEAK_DETECT, OUTPUT} state_t;
    state_t state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            valid_out <= 0;
            busy <= 0;
            index <= 0;
            peak_count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (~busy) begin
                        busy <= 1;
                        index <= 0;
                        state <= CALC_MAG;
                    end
                end
                CALC_MAG: begin
                    automatic real abs_real = $unsigned(real_in[index]);
                    automatic real abs_imag = $unsigned(imag_in[index]);
                    automatic real max_val = (abs_real > abs_imag) ? abs_real : abs_imag;
                    automatic real min_val = (abs_real > abs_imag) ? abs_imag : abs_real;
                    magnitude[index] <= (max_val * 0.96) + (min_val * 0.4);
                    
                    if (index == 15) begin
                        index <= GUARD_CELLS + TRAIN_CELLS;
                        state <= CFAR_PROCESS;
                    end else begin
                        index <= index + 1;
                    end
                end
                CFAR_PROCESS: begin
                    automatic int left_start = index - TRAIN_CELLS - GUARD_CELLS;
                    automatic int right_end = index + TRAIN_CELLS + GUARD_CELLS;
                    automatic real noise_sum = 0;
                    automatic int count = 0;
                    
                    for (int i = left_start; i < index - GUARD_CELLS; i++) begin
                        if (i >= 0) begin
                            noise_sum += magnitude[i];
                            count++;
                        end
                    end
                    for (int i = index + GUARD_CELLS + 1; i <= right_end; i++) begin
                        if (i < 16) begin
                            noise_sum += magnitude[i];
                            count++;
                        end
                    end
                    automatic real noise_avg = (count > 0) ? (noise_sum / count) : 0;
                    cfar_threshold[index] <= noise_avg * THRESHOLD_FACTOR;
                    
                    if (index == 15 - GUARD_CELLS - TRAIN_CELLS) begin
                        index <= 0;
                        state <= PEAK_DETECT;
                    end else begin
                        index <= index + 1;
                    end
                end
                PEAK_DETECT: begin
                    peak_count <= 0;
                    for (int i = 1; i < 15; i++) begin
                        if (magnitude[i] > cfar_threshold[i] && magnitude[i] > magnitude[i-1] && magnitude[i] > magnitude[i+1]) begin
                            if (peak_count < 8) begin
                                peaks[peak_count] <= i;
                                peak_count <= peak_count + 1;
                            end
                        end
                    end
                    for (int i = peak_count; i < 8; i++) peaks[i] <= 0;
                    state <= OUTPUT;
                end
                OUTPUT: begin
                    velocity_vector <= peaks;
                    valid_out <= 1;
                    busy <= 0;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule


