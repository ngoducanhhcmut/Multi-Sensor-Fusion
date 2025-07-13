module block_combiner #(
    parameter BLOCK_SIZE = 8,      // Kích thước khối (4,8,16,32)
    parameter PIXEL_WIDTH = 8,     // Bit màu (8-bit)
    parameter RESIDUAL_WIDTH = 12  // Bit phần dư (mở rộng để tránh tràn)
)(
    input  logic clk,              // Clock đồng bộ
    input  logic reset,            // Reset bất đồng bộ
    input  logic enable,           // Tín hiệu kích hoạt
    input  logic [PIXEL_WIDTH-1:0] P [BLOCK_SIZE][BLOCK_SIZE],      // Khối dự đoán
    input  logic signed [RESIDUAL_WIDTH-1:0] R [BLOCK_SIZE][BLOCK_SIZE], // Phần dư (có dấu)
    output logic [PIXEL_WIDTH-1:0] Recon [BLOCK_SIZE][BLOCK_SIZE],  // Khối tái tạo
    output logic done              // Báo hoàn thành
);
    logic [PIXEL_WIDTH-1:0] P_reg [BLOCK_SIZE][BLOCK_SIZE];
    logic signed [RESIDUAL_WIDTH-1:0] R_reg [BLOCK_SIZE][BLOCK_SIZE];
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            done <= 0;
            for (int i = 0; i < BLOCK_SIZE; i++) begin
                for (int j = 0; j < BLOCK_SIZE; j++) begin
                    Recon[i][j] <= 0;
                end
            end
        end else if (enable) begin
            P_reg <= P;
            R_reg <= R;
            done <= 1;
            for (int i = 0; i < BLOCK_SIZE; i++) begin
                for (int j = 0; j < BLOCK_SIZE; j++) begin
                    logic [RESIDUAL_WIDTH:0] sum_ext;
                    sum_ext = $signed({1'b0, P_reg[i][j]}) + $signed(R_reg[i][j]); // Mở rộng P_reg
                    if (sum_ext < 0)
                        Recon[i][j] <= 0;
                    else if (sum_ext > ( (1 << PIXEL_WIDTH) - 1))
                        Recon[i][j] <= ( (1 << PIXEL_WIDTH) - 1);
                    else
                        Recon[i][j] <= sum_ext[PIXEL_WIDTH-1:0];
                end
            end
        end else begin
            done <= 0;
        end
    end
endmodule