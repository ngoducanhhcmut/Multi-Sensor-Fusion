module BRAMInterface (
    input  wire        clk,
    input  wire        rst,
    input  wire        read_en,
    input  wire        write_en,
    input  wire [14:0] addr,
    input  wire [31:0] data_in,
    output logic [31:0] data_out
);

    // BRAM parameters
    localparam DEPTH = 32768;  // 32x32x32 voxels
    
    // Memory array
    logic [31:0] bram [0:DEPTH-1];
    
    // Initialize BRAM
    initial begin
        for (int i = 0; i < DEPTH; i++) begin
            bram[i] = 0;
        end
    end
    
    // BRAM operation
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < DEPTH; i++) begin
                bram[i] <= 0;  // Reset toàn bộ BRAM
            end
            data_out <= 0;
        end else begin
            if (write_en) begin
                bram[addr] <= data_in;
            end
            if (read_en) begin
                data_out <= bram[addr];
            end
        end
    end

endmodule