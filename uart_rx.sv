`include "clock_mul.sv"

module uart_rx (
    input clk,
    input rx,
    output reg rx_ready,
    output reg [7:0] rx_data
);

// Takes two paramters: the source clock frequency and the baudrate
parameter SRC_FREQ = 76800;
parameter BAUDRATE = 9600; // Rate at which data is sent

// STATES: State of the state machine
// localparam is equivlent to typdef enum in SV
localparam DATA_BITS = 8;
localparam 
    INIT = 0, 
    IDLE = 1,
    RX_DATA = 2,
    STOP = 3;

// CLOCK MULTIPLIER: Instantiate the clock multiplier
wire rx_clk;
clock_mul #(.SRC_FREQ(SRC_FREQ), .OUT_FREQ(BAUDRATE)) clk_mul (
    .src_clk(clk),
    .out_clk(rx_clk)
);

// CROSS CLOCK DOMAIN: The rx_ready flag should only be set 1 one for one source 
// clock cycle. Use the cross clock domain technique discussed in class to handle this.
reg rx_ready_reg = 1'b0;
always @(posedge clk) begin
    rx_ready <= rx_ready_reg;
    rx_ready_reg <= 1'b0;
end

// STATE MACHINE: Use the UART clock to drive that state machine that receves a byte from the rx signal
integer state = INIT;
reg [7:0] rx_data_reg;
integer bit_count;
// Need to posedge and negedge rx_clk
always @(posedge rx_clk) begin
    case (state)
        INIT: begin
            rx_ready_reg <= 1'b0;
            rx_data_reg <= 8'b0; // Clear data register
            if (rx == 1'b0) begin // Start bit detected
                state <= RX_DATA;
                bit_count <= 0;
            end else begin
                state <= IDLE; // else go straight to idle and wait for start bit
            end
        end
        IDLE: begin
            rx_ready_reg <= 1'b0;
            if (rx == 1'b0) begin // Start bit detected
                state <= RX_DATA;
                bit_count <= 0; // Reset bitcount
            end else begin
                state <= IDLE; // else, stay idle
            end
        end
        RX_DATA: begin
            rx_data_reg <= {rx, rx_data_reg[7:1]}; // Shift new bit MSB
            //rx_data_reg[DATA_BITS - bit_count - 1] <= rx; // Taking new bit, using index instead of shifting
            rx_data <= rx_data_reg; // Update output data
            bit_count <= bit_count + 1;
            if (bit_count == DATA_BITS - 1) begin // Transmission complete after 8 bits
                state <= STOP;
            end else begin
                state <= RX_DATA;
            end
        end
        STOP: begin
            if (rx == 1'b1) begin // Stop bit detected
                rx_data <= rx_data_reg; // Output the received data
                rx_ready_reg <= 1'b1; // Indicate data is ready
                state <= IDLE; // Return to idle state for next byte
            end else begin
                state <= STOP; // Wait for stop bit to be valid
            end
        end
    endcase
end

endmodule