module BitstreamBuffer (
    input  logic        clk,
    input  logic        reset,
    input  logic        wr_en,        // Tín hiệu ghi dữ liệu
    input  logic [511:0] bitstream_in,
    output logic [511:0] bitstream_out,
    output logic        full          // Báo hiệu bộ đệm đầy
);
    logic [511:0] buffer_reg;
    logic buffer_valid;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            buffer_reg <= 512'b0;
            buffer_valid <= 1'b0;
        end else if (wr_en && !full) begin
            buffer_reg <= bitstream_in;
            buffer_valid <= 1'b1;
        end
    end

    assign bitstream_out = buffer_valid ? buffer_reg : 512'b0;
    assign full = buffer_valid; // Bộ đệm đầy khi dữ liệu hợp lệ
endmodule