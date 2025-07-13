module inverse_quant_transform #(
    parameter COEFF_WIDTH = 16,
    parameter QP_WIDTH = 6,
    parameter MAX_SIZE = 32,
    parameter BIT_DEPTH = 8
) (
    input  logic clk,
    input  logic reset,
    input  logic start,
    output logic done,
    input  logic [7:0]                    syntax_elements,
    input  logic signed [COEFF_WIDTH-1:0] quantized_coeff_matrix[MAX_SIZE][MAX_SIZE],
    input  logic [QP_WIDTH-1:0]           QP,
    output logic signed [COEFF_WIDTH-1:0] residual_data[MAX_SIZE][MAX_SIZE]
);

    typedef enum {IDLE, QUANT_PROCESS, TRANSFORM, DONE} state_t;
    state_t state;
    logic signed [COEFF_WIDTH-1:0] dequant_buf[MAX_SIZE][MAX_SIZE];
    logic [1:0] transform_size;
    logic transform_start, transform_done;

    transform_size_selector tss (
        .syntax_elements(syntax_elements),
        .cu_size(2'b11), // Giả định, cần lấy từ cú pháp thực tế
        .transform_size(transform_size)
    );

    inverse_transform it (
        .clk(clk), .reset(reset), .start(transform_start), .done(transform_done),
        .transform_size(transform_size),
        .coeff_matrix(dequant_buf),
        .residual_data(residual_data)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            done <= 0;
        end else begin
            case (state)
                IDLE: if (start) state <= QUANT_PROCESS;
                QUANT_PROCESS: begin
                    for (int i = 0; i < MAX_SIZE; i++) begin
                        for (int j = 0; j < MAX_SIZE; j++) begin
                            inverse_quantizer iq (
                                .quantized_coeff(quantized_coeff_matrix[i][j]),
                                .QP(QP),
                                .coeff(dequant_buf[i][j])
                            );
                        end
                    end
                    state <= TRANSFORM;
                    transform_start <= 1;
                end
                TRANSFORM: begin
                    transform_start <= 0;
                    if (transform_done) begin
                        state <= DONE;
                        done <= 1;
                    end
                end
                DONE: if (!start) begin
                    state <= IDLE;
                    done <= 0;
                end
            endcase
        end
    end
endmodule