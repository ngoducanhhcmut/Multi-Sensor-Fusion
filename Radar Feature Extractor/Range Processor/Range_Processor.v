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