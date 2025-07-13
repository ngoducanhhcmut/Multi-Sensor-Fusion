// Module CoordinateNormalizer: Chuẩn hóa tọa độ về khoảng [0-1023]
module CoordinateNormalizer (
    input wire clk,
    input wire reset,
    input wire [127:0] point_data,
    input wire input_valid,
    output reg [127:0] normalized_coords,
    output reg valid
);
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            normalized_coords <= 128'b0;
            valid <= 1'b0;
        end else if (input_valid) begin
            for (i = 0; i < 4; i = i + 1) begin
                wire [9:0] x = point_data[i*32 + 9 : i*32];
                wire [9:0] y = point_data[i*32 + 19 : i*32 + 10];
                wire [9:0] z = point_data[i*32 + 29 : i*32 + 20];
                normalized_coords[i*32 + 9 : i*32]   <= (x[9]) ? 10'd0 : (x > 1023) ? 10'd1023 : x;
                normalized_coords[i*32 + 19 : i*32 + 10] <= (y[9]) ? 10'd0 : (y > 1023) ? 10'd1023 : y;
                normalized_coords[i*32 + 29 : i*32 + 20] <= (z[9]) ? 10'd0 : (z > 1023) ? 10'd1023 : z;
                normalized_coords[i*32 + 31 : i*32 + 30] <= point_data[i*32 + 31 : i*32 + 30];
            end
            valid <= 1'b1;
        end else begin
            valid <= 1'b0;
        end
    end
endmodule