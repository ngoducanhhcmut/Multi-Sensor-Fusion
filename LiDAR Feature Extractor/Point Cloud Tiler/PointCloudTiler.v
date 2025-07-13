// Module PointCloudTiler: Tích hợp các module con
module PointCloudTiler (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [511:0] point_cloud,
    output wire [1023:0] tile_buffer [255:0],
    output wire valid
);
    wire [127:0] point_data;
    wire [127:0] normalized_coords;
    wire [31:0] tile_indices;
    wire pr_valid, cn_valid, tic_valid, tb_valid;
    wire pr_done;

    PointReader pr (
        .clk(clk),
        .reset(reset),
        .start(start),
        .point_cloud(point_cloud),
        .point_data(point_data),
        .valid(pr_valid),
        .done(pr_done)
    );

    CoordinateNormalizer cn (
        .clk(clk),
        .reset(reset),
        .point_data(point_data),
        .input_valid(pr_valid),
        .normalized_coords(normalized_coords),
        .valid(cn_valid)
    );

    TileIndexCalculator tic (
        .clk(clk),
        .reset(reset),
        .normalized_coords(normalized_coords),
        .input_valid(cn_valid),
        .tile_indices(tile_indices),
        .valid(tic_valid)
    );

    TileBuffer tb (
        .clk(clk),
        .reset(reset),
        .tile_indices(tile_indices),
        .point_data(point_data),
        .input_valid(tic_valid),
        .tile_buffer(tile_buffer),
        .valid(tb_valid)
    );

    assign valid = tb_valid;
endmodule