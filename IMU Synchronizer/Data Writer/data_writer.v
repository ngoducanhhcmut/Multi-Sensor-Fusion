module data_writer (
    input  wire [63:0] quaternion_in,
    input  wire        write_en,
    output wire [63:0] fifo_data_in,
    output logic       fifo_write_en,
    input  wire        fifo_full
);
    assign fifo_data_in = quaternion_in;
    
    always_comb begin
        fifo_write_en = write_en && !fifo_full;  // Write only if not full
    end
endmodule