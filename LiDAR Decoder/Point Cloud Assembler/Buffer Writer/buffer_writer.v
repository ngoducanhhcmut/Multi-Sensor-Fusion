// Sub-module: Buffer Writer
module buffer_writer (
    input  logic        clk,
    input  logic        reset,
    input  logic [127:0] point,
    input  logic         valid_in,
    output logic [511:0] buffer_next,
    output logic         write_full
);
    logic [511:0] buffer_reg;
    logic [2:0]   num_points;

    // Calculate next state
    always_comb begin
        if (valid_in) begin
            buffer_next = {point, buffer_reg[511:128]}; // Shift left, add point to MSB
            write_full = (num_points == 3'd3);
        end else begin
            buffer_next = buffer_reg;
            write_full = 1'b0;
        end
    end

    // Register update
    always_ff @(posedge clk) begin
        if (reset) begin
            buffer_reg <= 512'b0;
            num_points <= 3'b0;
        end else if (valid_in) begin
            buffer_reg <= buffer_next;
            num_points <= (num_points == 3'd3) ? 3'b0 : num_points + 1;
        end
    end

endmodule