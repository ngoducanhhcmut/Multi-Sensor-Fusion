module fault_monitor (
    input logic clk,
    input logic rst_n,
    input logic [255:0] sensor1,
    input logic [255:0] sensor2,
    input logic [255:0] sensor3,
    output logic [3:0] error_code
);
    parameter int DATA_WIDTH = 16;
    parameter int NUM_WORDS = 15;
    parameter int CHECKSUM_WIDTH = 16;
    
    logic [2:0] signal_loss_shreg [1:3];
    logic [2:0] range_error_shreg [1:3];
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int s = 1; s <= 3; s++) begin
                signal_loss_shreg[s] <= 3'b111;
                range_error_shreg[s] <= 3'b111;
            end
        end else begin
            signal_loss_shreg[1] <= {signal_loss_shreg[1][1:0], (sensor1 == 256'h0)};
            range_error_shreg[1] <= {range_error_shreg[1][1:0], check_range(sensor1[239:0])};
            signal_loss_shreg[2] <= {signal_loss_shreg[2][1:0], (sensor2 == 256'h0)};
            range_error_shreg[2] <= {range_error_shreg[2][1:0], check_range(sensor2[239:0])};
            signal_loss_shreg[3] <= {signal_loss_shreg[3][1:0], (sensor3 == 256'h0)};
            range_error_shreg[3] <= {range_error_shreg[3][1:0], check_range(sensor3[239:0])};
        end
    end
    
    function logic [CHECKSUM_WIDTH-1:0] compute_checksum(input [239:0] data);
        logic [CHECKSUM_WIDTH:0] sum = 0;
        for (int i = 0; i < NUM_WORDS; i++) begin
            sum = sum + data[i*DATA_WIDTH +: DATA_WIDTH];
        end
        return sum[CHECKSUM_WIDTH-1:0];
    endfunction
    
    function logic check_range(input [239:0] data);
        for (int i = 0; i < NUM_WORDS; i++) begin
            logic signed [DATA_WIDTH-1:0] word = data[i*DATA_WIDTH +: DATA_WIDTH];
            if (word < -10000 || word > 10000) return 1'b1;
        end
        return 1'b0;
    endfunction
    
    always_comb begin
        error_code = 4'b0;
        error_code[0] = (compute_checksum(sensor1[239:0]) != sensor1[255:240]) ||
                        (compute_checksum(sensor2[239:0]) != sensor2[255:240]) ||
                        (compute_checksum(sensor3[239:0]) != sensor3[255:240]);
        error_code[1] = (range_error_shreg[1] == 3'b111) ||
                        (range_error_shreg[2] == 3'b111) ||
                        (range_error_shreg[3] == 3'b111);
        error_code[2] = (signal_loss_shreg[1] == 3'b111) ||
                        (signal_loss_shreg[2] == 3'b111) ||
                        (signal_loss_shreg[3] == 3'b111);
        error_code[3] = 1'b0;
    end
endmodule