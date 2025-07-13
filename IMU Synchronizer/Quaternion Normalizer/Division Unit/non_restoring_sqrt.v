module non_restoring_sqrt (
    input  logic [31:0] in,   // Q2.30
    output logic [31:0] out   // Q2.30
);
    // Non-restoring square root algorithm
    logic [31:0] root;
    logic [63:0] rem, test_sub;
    integer i;
    
    always_comb begin
        root = 0;
        rem = {in, 32'h0}; // Q2.62
        
        for (i = 31; i >= 0; i--) begin
            test_sub = {root, 2'b01} << (2 * i);
            if (rem >= test_sub) begin
                rem = rem - test_sub;
                root = root | (1 << i);
            end
        end
        out = root; // Q2.30
    end
endmodule