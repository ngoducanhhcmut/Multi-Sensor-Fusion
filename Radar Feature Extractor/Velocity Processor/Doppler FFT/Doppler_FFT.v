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