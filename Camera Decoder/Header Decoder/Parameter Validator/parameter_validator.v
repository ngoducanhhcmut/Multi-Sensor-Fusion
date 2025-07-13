module parameter_validator (
    input  logic        clk,
    input  logic        reset,
    input  logic [7:0]  profile,
    input  logic [15:0] width,
    input  logic [15:0] height,
    input  logic [7:0]  fps,
    input  logic [1:0]  chroma_format,
    input  logic [3:0]  bit_depth,
    input  logic [5:0]  qp,
    input  logic        tiles_enabled,
    input  logic [3:0]  tile_cols,
    input  logic [3:0]  tile_rows,
    output logic        valid,
    output logic        done
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            valid <= 0;
            done <= 0;
        end else begin
            valid <= 0;
            done <= 0;
            // Kiểm tra profile (hỗ trợ Main và Main10)
            if (profile != 1 && profile != 2) begin
                valid <= 0;
            end
            // Kiểm tra width và height chia hết cho 16
            else if (width % 16 != 0 || height % 16 != 0) begin
                valid <= 0;
            end
            // Kiểm tra QP
            else if (qp > 51) begin
                valid <= 0;
            end
            // Kiểm tra chroma_format (chỉ hỗ trợ 4:2:0)
            else if (chroma_format != 1) begin
                valid <= 0;
            end
            // Kiểm tra bit_depth (8 hoặc 10)
            else if (bit_depth != 8 && bit_depth != 10) begin
                valid <= 0;
            end
            // Kiểm tra FPS
            else if (fps == 0) begin
                valid <= 0;
            end
            // Kiểm tra tiles
            else if (tiles_enabled && (tile_cols == 0 || tile_rows == 0)) begin
                valid <= 0;
            end
            else begin
                valid <= 1;
            end
            done <= 1;
        end
    end
endmodule