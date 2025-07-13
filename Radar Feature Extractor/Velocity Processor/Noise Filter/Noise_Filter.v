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