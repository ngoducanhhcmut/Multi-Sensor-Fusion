module reconstruction_unit #(
    parameter FRAME_WIDTH = 640,
    parameter FRAME_HEIGHT = 480,
    parameter BLOCK_SIZE = 8,
    parameter PIXEL_WIDTH = 8,
    parameter ADDR_WIDTH = 19,
    parameter RESIDUAL_WIDTH = 12
)(
    input  logic clk,
    input  logic reset,
    input  logic block_valid,
    input  logic [PIXEL_WIDTH-1:0] P [BLOCK_SIZE][BLOCK_SIZE],
    input  logic signed [RESIDUAL_WIDTH-1:0] R [BLOCK_SIZE][BLOCK_SIZE],
    input  logic [9:0] block_x,
    input  logic [9:0] block_y,
    output logic [ADDR_WIDTH-1:0] mem_addr,
    output logic [PIXEL_WIDTH-1:0] mem_data,
    output logic mem_we,
    output logic done
);
    logic combiner_done;
    logic [PIXEL_WIDTH-1:0] Recon [BLOCK_SIZE][BLOCK_SIZE];
    
    block_combiner #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .RESIDUAL_WIDTH(RESIDUAL_WIDTH)
    ) combiner (
        .clk(clk),
        .reset Reset),
        .enable(block_valid),
        .P(P),
        .R(R),
        .Recon(Recon),
        .done(combiner_done)
    );
    
    frame_assembler #(
        .FRAME_WIDTH(FRAME_WIDTH),
        .FRAME_HEIGHT(FRAME_HEIGHT),
        .BLOCK_SIZE(BLOCK_SIZE),
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) assembler (
        .clk(clk),
        .reset(reset),
        .start(combiner_done),
        .Recon(Recon),
        .block_x(block_x),
        .block_y(block_y),
        .mem_addr(mem_addr),
        .mem_data(mem_data),
        .mem_we(mem_we),
        .done(done)
    );
endmodule