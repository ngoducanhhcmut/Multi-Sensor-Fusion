// NAL Unit Extractor Module (Improved)
module NALUnitExtractor (
    input  logic         clk,
    input  logic         reset,
    input  logic         nal_start,        // Start of NAL unit
    input  logic         nal_end,          // End of NAL unit
    input  logic [3071:0] nal_payload,     // NAL payload data
    input  logic [9:0]   nal_payload_size, // Valid payload size
    output logic [7:0]   nal_type,         // NAL unit type
    output logic [3071:0] nal_unit,        // Extracted NAL unit
    output logic [9:0]   nal_unit_size,    // Size of NAL unit
    output logic         nal_valid         // Valid signal for NAL unit
);

    logic [3071:0] unit_buffer;
    logic [9:0] unit_size;
    logic has_started;
    logic [7:0] first_byte;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            nal_type <= '0;
            nal_unit <= '0;
            nal_unit_size <= '0;
            nal_valid <= 1'b0;
            unit_buffer <= '0;
            unit_size <= '0;
            has_started <= 1'b0;
            first_byte <= '0;
        end else begin
            nal_valid <= 1'b0;
            
            if (nal_start) begin
                unit_buffer <= '0;
                unit_size <= '0;
                has_started <= 1'b1;
                first_byte <= nal_payload[7:0];
            end
            
            if (nal_end && has_started) begin
                nal_type <= first_byte;
                nal_unit <= unit_buffer;
                nal_unit_size <= unit_size;
                nal_valid <= nvim1'b1;
                has_started <= 1'b0;
            end else if (has_started) begin
                for (int i = 0; i < nal_payload_size; i++) begin
                    if (unit_size < 384) begin
                        unit_buffer[unit_size*8 +:8] <= nal_payload[i*8 +:8];
                        unit_size <= unit_size + 1;
                    end
                end
            end
        end
    end
endmodule
