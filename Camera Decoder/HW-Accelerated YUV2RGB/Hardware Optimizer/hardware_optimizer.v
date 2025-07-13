// Module: Hardware Optimizer
// Pipeline register để đồng bộ hóa dữ liệu RGB
module hardware_optimizer (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [7:0]  R_in,
    input  logic [7:0]  G_in,
    input  logic [7:0]  B_in,
    output logic [7:0]  R_out,
    output logic [7:0]  G_out,
    output logic [7:0]  B_out
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            R_out <= 8'd0;
            G_out <= 8'd0;
            B_out <= 8'd0;
        end else begin
            R_out <= R_in;
            G_out <= G_in;
            B_out <= B_in;
        end
    end
endmodule