module RangeInitializer (
    input wire clk,
    input wire reset,
    input wire init_pulse,
    output reg [15:0] range_initial
);
    always @(posedge clk or posedge reset) begin
        if (reset)
            range_initial <= 16'hFFFF;
        else if (init_pulse)
            range_initial <= 16'hFFFF;
    end
endmodule
