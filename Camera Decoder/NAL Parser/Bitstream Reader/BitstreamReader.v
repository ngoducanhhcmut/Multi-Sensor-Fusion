// Bitstream Reader Module (Improved)
module BitstreamReader (
    input  logic         clk,
    input  logic         reset,
    input  logic [7:0]   bitstream_data,    // Input byte stream
    input  logic         bitstream_valid,   // Valid signal for input byte
    output logic [3071:0] chunk_data,       // 3072-bit chunk output
    output logic         chunk_valid,       // Valid signal for chunk output
    output logic         chunk_overflow     // Warning when input overflows
);

    logic [3071:0] buffer;
    logic [9:0] byte_count;  // 0-383 (384 bytes)
    logic [7:0] input_reg;
    logic input_valid_reg;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            buffer <= '0;
            byte_count <= '0;
            chunk_valid <= 1'b0;
            chunk_overflow <= 1'b0;
            input_reg <= '0;
            input_valid_reg <= 1'b0;
        end else begin
            chunk_valid <= 1'b0;
            chunk_overflow <= 1'b0;
            
            input_reg <= bitstream_data;
            input_valid_reg <= bitstream_valid;
            
            if (input_valid_reg) begin
                if (byte_count < 384) begin
                    buffer[byte_count*8 +:8] <= input_reg;
                    byte_count <= byte_count + 1;
                end else begin
                    chunk_overflow <= 1'b1;
                end
                
                if (byte_count == 383) begin
                    chunk_data <= {buffer[3063:0], input_reg};
                    chunk_valid <= 1'b1;
                    byte_count <= 0;
                end
            end
        end
    end
endmodule