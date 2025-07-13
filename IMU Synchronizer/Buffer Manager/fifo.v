module fifo #(
    parameter DEPTH = 16,     // Must be >= 2
    parameter WIDTH = 64      // Must be >= 1
) (
    input  wire             clk,
    input  wire             rst,
    input  wire             write_en,
    input  wire [WIDTH-1:0] data_in,
    output logic            full,
    input  wire             read_en,
    output logic [WIDTH-1:0] data_out,
    output logic            empty
);
    // Validate parameters
    initial begin
        if (DEPTH < 2) $error("DEPTH must be >= 2");
        if (WIDTH < 1) $error("WIDTH must be >= 1");
    end

    // Pointer and memory
    localparam PTR_WIDTH = $clog2(DEPTH);
    logic [PTR_WIDTH-1:0] wr_ptr, rd_ptr;
    logic [PTR_WIDTH:0] count;  // Extra bit for count (0 to DEPTH)
    logic [WIDTH-1:0] mem [0:DEPTH-1];

    // Registered outputs
    always_ff @(posedge clk) begin -begin
        if (rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count <= '0;
            data_out <= '0;
            for (int i = 0; i < DEPTH; i++) mem[i] <= '0;  // Clear memory
        end else begin
            // Write operation
            if (write_en && !full) begin
                mem[wr_ptr] <= data_in;
                wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
            end

            // Read operation
            if (read_en && !empty) begin
                data_out <= mem[rd_ptr];  // Register output
                rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
            end

            // Update counter
            case ({write_en && !full, read_en && !empty})
                2'b01:   count <= count - 1;  // Read only
                2'b10:   count <= count + 1;  // Write only
                2'b11:   count <= count;      // Read + Write
                default: count <= count;
            endcase
        end
    end

    // Status flags (combinational)
    assign full  = (count == DEPTH);
    assign empty = (count == 0);
endmodule