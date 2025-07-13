// Module TileIndexCalculator: Tính chỉ số tile (X, Y)
module TileIndexCalculator (
    input wire clk,
    input wire reset,
    input wire [127:0] normalized_coords,
    input wire input_valid,
    output reg [31:0] tile_indices,
    output reg valid
);
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tile_indices <= 32'b0;
            valid <= 1'b0;
        end else if (input_valid) begin
            for (i = 0; i < 4; i = i + 1) begin
                tile_indices[i*8 + 3 : i*8]     <= normalized_coords[i*32 + 9 : i*32 + 6];  // X
                tile_indices[i*8 + 7 : i*8 + 4] <= normalized_coords[i*32 + 19 : i*32 + 16]; // Y
            end
            valid <= 1'b1;
        end else begin
            valid <= 1'b0;
        end
    end
endmodule