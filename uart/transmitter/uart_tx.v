/*
# Filename:         uart_tx.v
# File Description: UART Transmitter — transmits 8-bit data with parity and stop bit at ~115200 baud using 3.125 MHz clock.
# Global variables: None
*/

//
// UART Transmitter (uart_tx)
// Description:
//   Transmits 8-bit serial data with start, parity and stop bits.
//   Baud rate: ~115200 bps (CLKS_PER_BIT = 27 or 28 depending on clock; this implementation uses 27 cycles/bit).
//
// Ports:
//   clk_3125    - 3.125 MHz clock
//   parity_type - 0 -> even parity, 1 -> odd parity
//   tx_start    - pulse to start transmission (assumed one-cycle pulse or held until accepted)
//   data[7:0]   - byte to transmit (MSB transmitted first by this implementation)
//   tx          - serial TX output (idle high)
//   tx_done     - asserted when stop-bit period completes
//

module uart_tx(
    input  wire       clk_3125,    // 3.125 MHz clock
    input  wire       parity_type, // 0: even parity, 1: odd parity
    input  wire       tx_start,    // start transmission (synchronous to clk_3125)
    input  wire [7:0] data,        // 8-bit data to send (MSB first as implemented)
    output wire       tx,          // UART serial output
    output wire       tx_done      // high during stop-bit period end (indicates frame done)
);

////////////////////////////////////////////////////////////////////////////////
// Parameters / localparams
////////////////////////////////////////////////////////////////////////////////

// CLKS_PER_BIT: number of clk_3125 cycles per UART bit period.
// NOTE: The original code used 27 cycles per bit in behaviour comments; keep the
// existing transmission timing by using 27 cycles per bit (0..26 counter).
localparam integer CLKS_PER_BIT = 27; // cycles per bit (0..CLKS_PER_BIT-1)

// Transmitter state encodings (descriptive ALL_CAPS parameter names)
localparam [3:0] IDLE   = 4'd0,
                 START  = 4'd1,
                 DATA0  = 4'd2,
                 DATA1  = 4'd3,
                 DATA2  = 4'd4,
                 DATA3  = 4'd5,
                 DATA4  = 4'd6,
                 DATA5  = 4'd7,
                 DATA6  = 4'd8,
                 DATA7  = 4'd9,
                 PARITY = 4'd10,
                 STOP   = 4'd11;

////////////////////////////////////////////////////////////////////////////////
// Registers / Wires (variable-level comments)
// ----------------------------------------------------------------------------
// shift_reg    : 9-bit shift register that holds data[7:0] + parity in LSB/MSB convention.
//                shift_reg[8] is the bit currently output by the tx assignment.
// state        : current transmit state (one-hot-like encoding via localparam).
// baud_counter : counts cycles within a bit (0..CLKS_PER_BIT-1).
//
// Notes:
// - This implementation preserves the original behaviour exactly. Data is loaded
//   into shift_reg and shifted each bit-time. MSB-first output is achieved by
//   driving tx from shift_reg[8] and shifting left each bit time.
//
reg [8:0] shift_reg    = 9'd0;  // shift_reg: {data[7:0], parity_bit} loaded on IDLE->START
reg [3:0] state        = 4'd0;  // state: transmitter FSM current state
reg [4:0] baud_counter = 5'd0;  // baud_counter: counts clk_3125 cycles within a bit (width supports up to 31)

////////////////////////////////////////////////////////////////////////////////
// Output assignments (combinational)
// ----------------------------------------------------------------------------
// tx: drive serial line based on current state.
//      IDLE  : line high (1)
//      START : start bit (0)
//      STOP  : stop bit (1)
//      others: output bit from shift_reg[8] (data/parity)
assign tx =
    (state == IDLE)  ? 1'b1 :
    (state == START) ? 1'b0 :
    (state == STOP)  ? 1'b1 :
                       shift_reg[8];

// tx_done: high when stop-bit period is ongoing near its end (indicates transmission complete)
// We assert tx_done when in STOP state and baud_counter has reached end of bit period.
assign tx_done = (state == STOP && baud_counter >= (CLKS_PER_BIT - 1));

////////////////////////////////////////////////////////////////////////////////
// Initialization (for simulation visibility; reset handled externally if required)
initial begin
    shift_reg    = 9'd0;
    state        = IDLE;
    baud_counter = 5'd0;
end

////////////////////////////////////////////////////////////////////////////////
// Sequential FSM: state transitions, baud counting and shifting
////////////////////////////////////////////////////////////////////////////////
always @(posedge clk_3125) begin
    /*
    Purpose:
    ---
    Implement UART transmission FSM:
      - In IDLE: wait for tx_start, preload shift_reg with data+parity, and go to START.
      - In START: hold start bit for one bit period then advance to DATA0.
      - DATAx states: for each data bit, hold the bit for one bit period then shift and progress.
      - PARITY: hold parity for one bit period.
      - STOP: hold stop bit for one bit period then return to IDLE.
    Notes:
      - Parity is precomputed and loaded into shift_reg[0] (LSB) so that shift_reg[8]
        always points to the bit to be output (after appropriate shifting).
      - Data is shifted left each bit-time so MSB of initial shift_reg becomes
        the first bit driven out via shift_reg[8].
    */
    case (state)

        // IDLE: prepare frame when tx_start asserted
        IDLE: begin
            baud_counter <= 5'd0;
            if (tx_start) begin
                // Pack data and parity into shift_reg such that shift_reg[8] is first
                // transmitted data bit (MSB-first behaviour).
                // Compute parity: ^data gives even parity (0 = even). For parity_type:
                //   parity_type == 0 -> even parity (store XOR of data)
                //   parity_type == 1 -> odd parity  (store NOT XOR of data)
                shift_reg <= (parity_type == 1'b0) ? {data, ^data} : {data, ~^data};
                state <= START;
            end
        end

        // START bit: hold low for one bit interval
        START: begin
            baud_counter <= baud_counter + 1'b1;
            if (baud_counter >= (CLKS_PER_BIT - 1)) begin
                baud_counter <= 5'd0;
                state        <= DATA0;
            end
        end

        // DATA bits: each DATAx state holds one bit-time and shifts the register
        DATA0, DATA1, DATA2, DATA3, DATA4, DATA5, DATA6, DATA7: begin
            baud_counter <= baud_counter + 1'b1;
            if (baud_counter >= (CLKS_PER_BIT - 1)) begin
                baud_counter <= 5'd0;
                // Shift next bit into MSB position (left shift). This moves the next
                // bit to shift_reg[8] for subsequent transmit.
                shift_reg <= {shift_reg[7:0], 1'b0};

                // Advance through DATA states to PARITY
                case (state)
                    DATA0: state <= DATA1;
                    DATA1: state <= DATA2;
                    DATA2: state <= DATA3;
                    DATA3: state <= DATA4;
                    DATA4: state <= DATA5;
                    DATA5: state <= DATA6;
                    DATA6: state <= DATA7;
                    DATA7: state <= PARITY;
                endcase
            end
        end

        // PARITY bit: hold parity bit (already in shift_reg[8]) for one bit interval
        PARITY: begin
            baud_counter <= baud_counter + 1'b1;
            if (baud_counter >= (CLKS_PER_BIT - 1)) begin
                baud_counter <= 5'd0;
                state        <= STOP;
            end
        end

        // STOP bit: hold line high for one bit interval then return to IDLE
        STOP: begin
            baud_counter <= baud_counter + 1'b1;
            if (baud_counter >= (CLKS_PER_BIT - 1)) begin
                baud_counter <= 5'd0;
                state        <= IDLE;
            end
        end

        default: begin
            // Safety: return to IDLE on undefined state
            state <= IDLE;
        end
    endcase
end

endmodule
