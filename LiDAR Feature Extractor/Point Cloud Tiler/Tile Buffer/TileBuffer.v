// Module TileBuffer: Lưu trữ điểm vào bộ đệm tile (16x16 = 256 tiles)
module TileBuffer (
    input wire clk,
    input wire reset,
    input wire [31:0] tile_indices,
    input wire [127:0] point_data,
    input wire input_valid,
    output reg [1023:0] tile_buffer [255:0], // 256 tiles, mỗi tile lưu 32 điểm
    output reg valid
);
    reg [4:0] write_ptr [255:0];
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 256; i = i + 1) begin
                write_ptr[i] <= 5'b0;
                tile_buffer[i] <= 1024'b0;
            end
            valid <= 1'b0;
        end else if (input_valid) begin
            for (i = 0; i < 4; i = i + 1) begin
                wire [7:0] tile_idx = {tile_indices[i*8 + 7 : i*8 + 4], tile_indices[i*8 + 3 : i*8]};
                if (write_ptr[tile_idx] < 31) begin
                    tile_buffer[tile_idx][write_ptr[tile_idx]*32 + 31 : write_ptr[tile_idx]*32] <= point_data[i*32 + 31 : i*32];
                    write_ptr[tile_idx] <= write_ptr[tile_idx] + 1;
                end
            end
            valid <= 1'b1;
        end else begin
            valid <= 1'b0;
        end
    end
endmodule