module frame_assembler #(
    parameter FRAME_WIDTH = 640,
    parameter FRAME_HEIGHT = 480,
    parameter BLOCK_SIZE = 8,
    parameter PIXEL_WIDTH = 8,
    parameter ADDR_WIDTH = 19  // log2(640*480) ≈ 19 bit
)(
    input  logic clk,              // Clock đồng bộ
    input  logic reset,            // Reset bất đồng bộ
    input  logic start,            // Tín hiệu bắt đầu ghi
    input  logic [PIXEL_WIDTH-1:0] Recon [BLOCK_SIZE][BLOCK_SIZE], // Khối đầu vào
    input  logic [9:0] block_x,    // Tọa độ X của khối (0-79)
    input  logic [9:0] block_y,    // Tọa độ Y của khối (0-59)
    output logic [ADDR_WIDTH-1:0] mem_addr,  // Địa chỉ ghi memory
    output logic [PIXEL_WIDTH-1:0] mem_data, // Dữ liệu ghi memory
    output logic mem_we,           // Tín hiệu ghi memory
    output logic done              // Báo hoàn thành
);
    logic [3:0] i, j;
    logic active;
    logic [ADDR_WIDTH-1:0] base_addr;
    assign base_addr = (block_y * BLOCK_SIZE * FRAME_WIDTH) + (block_x * BLOCK_SIZE);
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            active <= 0;
            mem_we <= 0;
            done <= 0;
            i <= 0;
            j <= 0;
        end else begin
            if (start && !active) begin
                active <= 1;
                i <= 0;
                j <= 0;
            end
            if (active) begin
                mem_addr <= base_addr + (i * FRAME_WIDTH) + j;
                mem_data <= Recon[i][j];
                mem_we <= 1;
                if ((block_y * BLOCK_SIZE + i >= FRAME_HEIGHT) || 
                    (block_x * BLOCK_SIZE + j >= FRAME_WIDTH)) begin
                    mem_we <= 0; // Tắt ghi nếu vượt biên
                end
                if (j == BLOCK_SIZE - 1) begin
                    j <= 0;
                    if (i == BLOCK_SIZE - 1) begin
                        active <= 0;
                        done <= 1;
                    end else begin
                        i <= i + 1;
                    end
                end else begin
                    j <= j + 1;
                end
            end else begin
                mem_we <= 0;
                done <= 0;
            end
        end
    end
endmodule