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