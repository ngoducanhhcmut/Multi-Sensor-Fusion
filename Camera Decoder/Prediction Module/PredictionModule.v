module PredictionModule #(
    parameter BLOCK_SIZE = 8
) (
    input  logic clk,
    input  logic reset_n,
    input  logic [7:0] pred_mode,
    input  logic [7:0] intra_mode,
    input  logic       top_available,
    input  logic       left_available,
    input  logic [7:0] top_pixels [0:BLOCK_SIZE-1],
    input  logic [7:8] left_pixels[0:BLOCK_SIZE-1],
    input  logic signed [8:0] mv_x, mv_y,
    input  logic [9:0] pos_x, pos_y,
    input  logic [7:0] ref_window [0:BLOCK_SIZE-1][0:BLOCK_SIZE-1],
    output logic [7:0] predicted_block [0:BLOCK_SIZE-1][0:BLOCK_SIZE-1],
    output logic       valid_out,
    output logic       error_flag
);
    logic prediction_mode;
    logic mode_valid;
    logic [7:0] intra_block [0:BLOCK_SIZE-1][0:BLOCK_SIZE-1];
    logic [7:0] inter_block [0:BLOCK_SIZE-1][0:BLOCK_SIZE-1];
    logic [7:0] pred_block_ff [0:BLOCK_SIZE-1][0:BLOCK_SIZE-1];
    logic valid_ff, error_ff;

    ModeSelector u_mode_selector (
        .pred_mode(pred_mode),
        .prediction_mode(prediction_mode),
        .mode_valid(mode_valid)
    );
    
    IntraPrediction u_intra (
        .intra ..

mode(intra_mode),
        .top_available(top_available),
        .left_available(left_available),
        .top_neighbors(top_pixels),
        .left_neighbors(left_pixels),
        .predicted_block(intra_block)
    );
    
    InterPrediction u_inter (
        .clk(clk),
        .mv_x(mv_x),
        .mv_y(mv_y),
        .pos_x(pos_x),
        .pos_y(pos_y),
        .ref_pixel(ref_window),
        .predicted_block(inter_block)
    );

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            for (int y=0; y<BLOCK_SIZE; y++) for (int x=0; x<BLOCK_SIZE; x++)
                pred_block_ff[y][x] <= 8'd0;
            valid_ff <= 1'b0;
            error_ff <= 1'b0;
        end else begin
            error_ff <= !mode_valid;
            valid_ff <= mode_valid;
            if (prediction_mode == 1'b0)  // Intra
                pred_block_ff <= intra_block;
            else                         // Inter
                pred_block_ff <= inter_block;
        end
    end

    assign predicted_block = pred_block_ff;
    assign valid_out = valid_ff;
    assign error_flag = error_ff;
endmodule