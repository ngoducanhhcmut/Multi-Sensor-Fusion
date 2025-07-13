// Sub-module: Output Packer
module output_packer (
    input  logic        clk,
    input  logic        reset,
    input  logic [511:0] buffer_next,
    input  logic         write_full,
    output logic [511:0] packed_data,
    output logic         packed_valid
);
    always_ff @(posedge clk) begin
        if (reset) begin
            packed_data <= 512'b0;
            packed_valid <= 1'b0;
        end else begin
            packed_valid <= write_full;
            if (write_full) begin
                packed_data <= buffer_next; // Capture buffer with four points
            end
        end
    end

endmodule