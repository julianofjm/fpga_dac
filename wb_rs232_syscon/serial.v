//-----------------------------------------------------------------------------
// module: serial.vhd
// This file contains modules for serial I/O.
//
// OVERVIEW of contents:  The clock generators are
//   configured to provide clocks at 16x the desired transmit
//   BAUD rates for RS232 serial I/O.  This is done so that
//   the rs232rx module can easily share the clock generation
//   circuitry of the rs232tx block.
//   The clock_gen_select module has a BAUD rate selection
//   input field of three bits.  This field allows the appropriate
//   "clock_factor" clock rate to be produced once and used on many
//   transmitters and receivers.
//   Alternatively, there is a "clock_gen" block which uses parameters
//   to specify the desired values for the DDS and prescaler divide factor.
//
// Author: John Clayton
// Date  : Nov.  7, 2000
// Update: Nov.  7, 2000 Created this file, with RS232tx block only
//                       The rs232tx block has no double buffering.
// Update: Nov.  9, 2000 Separated clock generator circuitry into "clock_gen"
// Update: Nov. 29, 2000 Added rs232rx block
// Update: Nov. 30, 2000 Moved contents of "async_tx" and "async_rx" from 
//                       blocks.vhd to this file.
// Update: May   7, 2001 Translated this file from VHDL to verilog, using 
//                       "xhdl"
// Update: May   8, 2001 Since the output of xhdl was rather "spotty", I have
//                       fixed errors and filled in the "holes" in the code.
//                       In addition, I have tried to wean this file from
//                       its previous use and dependency upon "blocks.v"
//                       (also translated from VHDL, but consisting of rather
//                       trivial modules.)
// Update: May   8, 2001 Converted to synchronous resets on all flip-flops.
// Update: May  16, 2001 Re-worked the state machines for rs232rx and rs232tx.
// Update: July 25, 2001 Changed the polarity of q[] in rs232_tx, so that its
//                       output will be the desired (high) level upon initial
//                       FPGA configuration, even before or without a reset!
// Update: Jan. 30, 2002 Corrected the formula in STEP 1: Find the ratio.
//                       (Thanks to Shehryar Shaheen at the University of
//                        Limerick for pointing out the error.)
// Update: June 28, 2002 Fixed "clock_gen" so that it uses the dds_clk.
//
//----------------------------------------
//
// FORMULATING BAUD RATE SETTINGS
//
//
// This ROM contains BAUD rate selection parameters for
// use with the clock_gen_select block.
// The BAUD clocks which are generated are positive pulses,
// (used as clock enables,) and may be used as general clock enables
// if desired.
// Configuring the clock_gen begins with a "Fclk" MHz basic clock.
// To this is applied a prescaler (with value of dds_prescale_value,) 
// followed by a Direct Digital Synthesizer (DDS) frequency
// generator.  The DDS has an accumulator that is "dds_bits" bits wide.
// The user should know that there is some "jitter" introduced by the
// DDS, and that the amount of jitter varies depending upon the desired
// output frequency.  By increasing "dds_bits" the jitter can be made
// very small.  Also, the jitter tends to be smaller for small values of
// "dds_phase_increment"
//
// The following settings apply for these table values:
// rate_select    BAUD rate (16x this is generated)
//----------------------------------------
//     000        9600
//     001        19200
//     010        38400
//     011        57600
//     100        115200
//   (other values are available)
//
//
//
// In order to generate the parameters for a new clock
// frequency, first find the basic Fclk for your board.
// (Fclk=49.152 MHz in this example.)  
// Next, choose the lowest desired BAUD rate.
// (lowest_rate=9600 in this example.)
//
// STEP 1 : Find the ratio
//-------------------------
// First, pick a "clock_factor" for the operation of the rs232 units.
// (16 is traditional, although this hardware supports odd values as
//  well.  For instance, you could pick a clock_factor of 7, if this
//  allows you to generate BAUD rates more exactly from your particular
//  Fclk.  Try to pick the highest clock_factor that you practically can
//  since higher numbers allow the receiver to sample in the middle of
//  the received bit more exactly...  Also, don't go over 16 unless you
//  widen out the counters in the design!)
// So, for this example, let clock_factor=16.
//
// Now, find Fclk/(clock_factor*lowest_rate) = 320 (in this example).
// If this ratio is NOT an integer, then be aware that the
// BAUD rates which you will be able to produce will not be
// exact.  For asynchronous communications, the clock frequency need not
// be exact. (As mentioned in "Brute Force DDS method" below.)
// If you cannot make clocks close enough to the BAUD rates you desire,
// then you can try a different "clock_factor" setting.
// Or, alternately, you could just use the "Brute Force DDS method."
// (See below)
// 
// Or, if all else fails: get a different clock oscillator!
// If the ratio is an integer, or close to it, then proceed to step 2.
//
// Brute Force DDS method (Still step 1):
//-----------------------
// Simply increase the size of the DDS (increase "dds_bits",)
// and set the prescaler to Ndiv=1 (to pass the clock directly
// to the DDS).  Then choose your DDS phase increment values (STEP 3)
// so that you can produce rates which are as close as possible
// to "clock_factor" times the desired BAUD rates.  It might not be exact,
// but it is as close as possible.  If "dds_bits" is sufficiently large,
// then the resulting BAUD rate clocks can be _extremely_ close to the
// correct frequencies.  The Baud rate clocks actually do not need
// to be perfect, they can vary by perhaps 3 or 4 percent from their
// exact frequencies, with an increased risk of bit-errors which result,
// of course.
// 
// The formula is: dds_freq_int = (2^dds_bits)*(desired_frequency)/Fclk.
//
// STEP 2 : Find the prescaler value
//----------------------------------
// If the ratio mentioned in STEP 1 is an integer, then divide that integer
// into its prime factors.  The product of all of the prime factors which
// are not equal to 2 is a good place to start for the prescaler_value.
// If this yields too low of a clock frequency going into the DDS, then
// revert to the "Brute force DDS approach" mentioned above, or else get
// a more suitable clock oscillator!
//
// For this example: 320 = 2*2*2*2*2*2*5.  So the prescaler Ndiv = 5.
//
// If you are lucky and the prime factors are all equal to 2, then you have
// chosen an Fclk which is very agreeable to producing the BAUD clocks.  You
// can probably set Ndiv=1, which disables the prescaler from operating.
//
//
// STEP 3 : Calculate DDS phase increment values
//----------------------------------------------
// Use the following formula:
//    dds_freq_int = (2^dds_bits)*(desired_frequency)/Fclk_dds.
// The resulting values should be used with the DDS, and the values will be
// be "dds_bits-1" wide unsigned quantities.
// Remember that you can change the prescaler Ndiv value to get different
// Fclk_dds values.
//
//=========================================================================





//-----------------------------------------
// This component is a generic clock generator.  Simply connect the appropriate
// inputs, and the desired frequency will be the result.  Output consists of a
// stream of narrow pulses which are one clock wide.  The sizes of DDS and
// prescaler counters are adjustable by parameters.

module clock_gen (
                  clk,
                  reset,
                  frequency,
                  clk_out
                  );

parameter DDS_PRESCALE_NDIV_PP = 5;    // Prescale divide factor
parameter DDS_PRESCALE_BITS_PP = 3;
parameter DDS_BITS_PP  = 6;

input clk;
input reset;
input[DDS_BITS_PP-2:0] frequency;
output clk_out;

// Local signals
wire pulse;
wire dds_clk;

// Simple renaming for readability
wire [DDS_BITS_PP-2:0] dds_phase_increment = frequency; 

reg delayed_pulse;
reg [DDS_PRESCALE_BITS_PP-1:0] dds_prescale_count;
reg [DDS_BITS_PP-1:0] dds_phase;


// This is the DDS prescaler part.  It has a variable divide value.
// The divide factor is "dds_prescale_ndiv".
always @(posedge clk)
begin
  if (reset) dds_prescale_count <= 0;
  else if (dds_prescale_count == (DDS_PRESCALE_NDIV_PP-1))
    dds_prescale_count <= 0;
  else dds_prescale_count <= dds_prescale_count + 1;
end
assign dds_clk = (dds_prescale_count == (DDS_PRESCALE_NDIV_PP-1));
// "dds_prescale_count" above could be compared to zero instead, to save
// on logic?...

// This is the DDS phase accumulator part
always @(posedge clk)
begin
  if (reset) dds_phase <= 0;
  else if (dds_clk) dds_phase <= dds_phase + dds_phase_increment;
end

assign pulse = dds_phase[DDS_BITS_PP-1]; // Simple renaming for readability
// This is "rising edge detector" part
always @(posedge clk)
begin
  delayed_pulse <= pulse;
end
assign clk_out = (pulse && ~delayed_pulse);  // Choose the rising edge

endmodule


//-----------------------------------------
// This component is a clock generator with parameters selected by an
// index into a lookup table.  There are eight possible settings.
// Recalculate the settings for your own needs as described in 
// "FORMULATING BAUD RATE SETTINGS" above.  You will need to change
// the bit width of the DDS registers, according to the `defines.

`define DDS_BITS 6
`define DDS_PRESCALE_BITS 3

module clock_gen_select (
                         clk,
                         reset,
                         rate_select,
                         clk_out
                         );

input clk;
input reset;
input [2:0] rate_select;

output clk_out;

// Local signals
wire pulse;
wire dds_clk;

reg delayed_pulse;
reg [`DDS_PRESCALE_BITS-1:0] dds_prescale_count;
reg [`DDS_PRESCALE_BITS-1:0] dds_prescale_ndiv;
reg [`DDS_BITS-1:0] dds_phase;
reg [`DDS_BITS-2:0] dds_phase_increment;

// This part sets up the "dds_phase_increment" and "dds_prescale_ndiv" values
always @(rate_select)
begin
  case (rate_select)
    3'b000  : begin
                dds_phase_increment <=  1;  // 9600
                dds_prescale_ndiv   <=  5;
              end
              
    3'b001  : begin
                dds_phase_increment <=  2;  // 19200
                dds_prescale_ndiv   <=  5;
              end
              
    3'b010  : begin
                dds_phase_increment <=  4;  // 38400
                dds_prescale_ndiv   <=  5;
              end
              
    3'b011  : begin
                dds_phase_increment <=  6;  // 57600
                dds_prescale_ndiv   <=  5;
              end
              
    3'b100  : begin
                dds_phase_increment <= 12;  // 115200
                dds_prescale_ndiv   <=  5;
              end
              
    3'b101  : begin
                dds_phase_increment <= 12;  // 115200
                dds_prescale_ndiv   <=  5;
              end
              
    3'b110  : begin
                dds_phase_increment <= 12;  // 115200
                dds_prescale_ndiv   <=  5;
              end
              
    3'b111  : begin
                dds_phase_increment <= 12;  // 115200
                dds_prescale_ndiv   <=  5;
              end
              
    default : begin
                dds_phase_increment <= 12;  // 115200
                dds_prescale_ndiv   <=  5;
              end
  endcase 
end 


// This is the DDS prescaler part.  It has a variable divide value.
// The divide factor is "dds_prescale_ndiv" + 1.
always @(posedge clk)
begin
  if (reset) dds_prescale_count <= 0;
  else if (dds_prescale_count == (dds_prescale_ndiv-1))
    dds_prescale_count <= 0;
  else dds_prescale_count <= dds_prescale_count + 1;
end
assign dds_clk = (dds_prescale_count == (dds_prescale_ndiv-1));
// "dds_prescale_count" above could be compared to zero?...

// This is the DDS phase accumulator part
always @(posedge clk)
begin
  if (reset) dds_phase <= 0;
  else if (dds_clk) dds_phase <= dds_phase + dds_phase_increment;
end

assign pulse = dds_phase[`DDS_BITS-1];  // Simple renaming for readability
// This is "rising edge detector" part
always @(posedge clk)
begin
  delayed_pulse <= pulse;
end
assign clk_out = (pulse && ~delayed_pulse);  // Choose the rising edge


endmodule

//`undef DDS_BITS
//`undef DDS_PRESCALE_BITS


//-----------------------------------------
// This block takes care of receiving an RS232 input word,
// from the "rxd" line in a serial fashion.
// The user is responsible for providing appropriate CLK
// and clock enable (CE) to achieve the desired Baudot interval
// (NOTE: the state machine operates at "CLOCK_FACTOR_PP" times the
//   desired BAUD rate.  Set it to anything between 2 and 16,
//   inclusive.  Values higher than 16 will not "buy" much for you,
//   and the state machine might not work well for values less than
//   four either, because of the difficulty in sampling rxd at the
//   "middle" of the bit time.  However, it may be useful to adjust
//   the clock_factor around in order to generate good BAUD clocks
//   from odd Fclk frequencies on your board.)
// Each time the "word_ready" line drives high the unit has put
// a newly received data word into its output buffer, and is possibly
// already in the process of receiving the next one.
// Note that support is not provided for 1.5 stop bits, only integral
// numbers of stop bits are allowed.  However, a selection >2 for
// number of stop bits will still work (it will simply receive
// and count additional stop bits before reporting "word_ready"

module rs232rx (
                clk,
                rx_clk,
                reset,
                rxd,
                read,
                data,
                data_ready,
                error_over_run,
                error_under_run,
                error_all_low
                );

// Parameter declarations
parameter START_BITS_PP  = 1;
parameter DATA_BITS_PP  = 8;
parameter STOP_BITS_PP  = 1;
parameter CLOCK_FACTOR_PP  = 16;

// State encodings, provided as parameters
// for flexibility to the one instantiating the module

parameter m1_idle = 0;
parameter m1_start = 1;
parameter m1_shift = 3;
parameter m1_over_run = 2;
parameter m1_under_run = 4;
parameter m1_all_low = 5;
parameter m1_extra_1 = 6;
parameter m1_extra_2 = 7;
parameter m2_data_ready_flag = 1;
parameter m2_data_ready_ack = 0;


// I/O declarations
input clk; 
input rx_clk; 
input reset;
input rxd;
input read;

output [DATA_BITS_PP-1:0] data;
output data_ready;
output error_over_run;
output error_under_run;
output error_all_low;

reg [DATA_BITS_PP-1:0] data;
reg data_ready;
reg error_over_run;
reg error_under_run;
reg error_all_low;

// Local signal declarations
`define TOTAL_BITS START_BITS_PP + DATA_BITS_PP + STOP_BITS_PP

wire word_xfer_l;
wire mid_bit_l;
wire start_bit_l;
wire stop_bit_l;
wire all_low_l;

reg [3:0] intrabit_count_l;
reg [`TOTAL_BITS-1:0] q;
reg shifter_preset;
reg [2:0] m1_state;
reg [2:0] m1_next_state;
reg m2_state;
reg m2_next_state;


  // State register
  always @(posedge clk)
  begin : m1_state_register
    if (reset) m1_state <= m1_idle;
    else m1_state <= m1_next_state;
  end 

  always @(m1_state 
           or reset
           or rxd
           or mid_bit_l
           or all_low_l
           or start_bit_l
           or stop_bit_l
           )
  begin : m1_state_logic
  
    // Output signals are low unless set high in a state condition.
    shifter_preset <= 0;
    error_over_run <= 0;
    error_under_run <= 0;
    error_all_low <= 0;
  
    case (m1_state)

      m1_idle :
        begin
          shifter_preset <= 1'b1;
          if (~rxd) m1_next_state <= m1_start;
          else m1_next_state <= m1_idle;
        end

      m1_start :
        begin
          if (~rxd && mid_bit_l) m1_next_state <= m1_shift;
          else if (rxd && mid_bit_l) m1_next_state <= m1_under_run;
          else m1_next_state <= m1_start;
        end

      m1_shift :
        begin
          if (all_low_l) m1_next_state <= m1_all_low;
          else if (~start_bit_l && ~stop_bit_l) m1_next_state <= m1_over_run;
          else if (~start_bit_l && stop_bit_l) m1_next_state <= m1_idle;
          else m1_next_state <= m1_shift;
        end

      m1_over_run :
        begin
          error_over_run <= 1;
          shifter_preset <= 1'b1;
          if (reset) m1_next_state <= m1_idle;
          else m1_next_state <= m1_over_run;
        end
      
      m1_under_run :
        begin
          error_under_run <= 1;
          shifter_preset <= 1'b1;
          if (reset) m1_next_state <= m1_idle;
          else m1_next_state <= m1_under_run;
        end
        
      m1_all_low :
        begin
          error_all_low <= 1;
          shifter_preset <= 1'b1;
          if (reset) m1_next_state <= m1_idle;
          else m1_next_state <= m1_all_low;
        end
        
      default : m1_next_state <= m1_idle;
    endcase 
  end 
  assign word_xfer_l = ((m1_state == m1_shift) && ~start_bit_l && stop_bit_l);

  // State register
  always @(posedge clk)
  begin : m2_state_register
    if (reset) m2_state <= m2_data_ready_ack;
    else m2_state <= m2_next_state;
  end 

  // State transition logic
  always @(m2_state or word_xfer_l or read)
  begin : m2_state_logic
    case (m2_state)
      m2_data_ready_ack:
            begin
              data_ready <= 1'b0;
              if (word_xfer_l) m2_next_state <= m2_data_ready_flag;
              else m2_next_state <= m2_data_ready_ack;
            end
      m2_data_ready_flag:
            begin
              data_ready <= 1'b1;
              if (read) m2_next_state <= m2_data_ready_ack;
              else m2_next_state <= m2_data_ready_flag;
            end
      default : m2_next_state <= m2_data_ready_ack;
    endcase 
  end 

  // This counts within a bit-time.
  always @(posedge clk)
  begin
    if (shifter_preset) intrabit_count_l <= 0;
    else if (rx_clk)
    begin
      if (intrabit_count_l == (CLOCK_FACTOR_PP-1)) intrabit_count_l <= 0;
      else intrabit_count_l <= intrabit_count_l + 1;
    end
  end
  // This signal gets one "rx_clk" at the middle of the bit time.
  assign mid_bit_l = ((intrabit_count_l==(CLOCK_FACTOR_PP / 2)) && rx_clk);

  // This is the shift register
  always @(posedge clk)
  begin : rxd_shifter
    if (shifter_preset) q <= -1; // Set to all ones.
    else if (mid_bit_l) q <= {rxd,q[`TOTAL_BITS-1:1]};
  end
  // Note: The definitions of "start_bit_l" and "stop_bit_l" could
  //       well be updated to include _all_ of the start and stop bits.
  assign start_bit_l = q[0];
  assign stop_bit_l = q[`TOTAL_BITS-1];
  assign all_low_l = ~(| q); // Bit-wise or of the entire shift register


  // This is the output buffer
  always @(posedge clk)
  begin : rxd_output
    if (reset) data <= 0;
    else if (word_xfer_l) 
      data <= q[START_BITS_PP+DATA_BITS_PP-1:START_BITS_PP];
  end

endmodule

//`undef TOTAL_BITS


//-----------------------------------------
// This block takes care of framing up an RS232 output word,
// and sending it out the "txd" line in a serial fashion.
// The user is responsible for providing appropriate clk
// and clock enable (tx_clk) to achieve the desired Baudot interval
// (a new bit is transmitted each (tx_clk/clock_factor) pulses)
// (NOTE: the state machine operates at "clock_factor" times the
//   desired BAUD rate.  Set it to anything between 2 and 16,
//   inclusive.  It may be useful to adjust the clock_factor in order to
//   generate good BAUD clocks from odd Fclk frequencies on your board.)
// A load operation is requested by bringing the "load" line high.  However,
// the load will only be accepted when load_request is also high (which  
// just happens to coincide with tx_clk_1x inside of the state machine...)
// Therefore, the "load_request" line may be used as a bus acknowledgement.
// (load_request = "ack_o" in Wishbone terminology -- but it only lasts for
//  one single clk cycle, so be careful how you use it!)
//
// If the "load_request" line is tied to "load," the unit will send
// data characters continuously, with no gaps in between transmissions.
//
// Note that support is not provided for 1.5 stop bits, only integral
// numbers of stop bits are allowed.  A selection of more than 2 for
// number of stop bits will still work fine, it will simply introduce
// a delay between characters being transmitted, although the length
// of the transmitter shift register will also grow to include one
// stage for each stop bit requested...

module rs232tx (
                clk,
                tx_clk,
                reset,
                load,
                data,
                load_request,
                txd
                );

  parameter START_BITS_PP  = 1;
  parameter DATA_BITS_PP  = 8;
  parameter STOP_BITS_PP  = 1;
  parameter CLOCK_FACTOR_PP  = 16;
  parameter TX_BIT_COUNT_BITS_PP = 4;  // = ceil(log(total_bits)/log(2)));

// State encodings, provided as parameters
// for flexibility to the one instantiating the module
  parameter m1_idle = 0;
  parameter m1_waiting = 1;
  parameter m1_sending = 3;
  parameter m1_sending_last_bit = 2;


// I/O declarations
  input clk;
  input tx_clk;
  input reset;
  input load;
  input[DATA_BITS_PP-1:0] data;
  output load_request;
  output txd;

  reg load_request;

// local signals
  `define TOTAL_BITS START_BITS_PP + DATA_BITS_PP + STOP_BITS_PP
  
  reg [`TOTAL_BITS-1:0] q;                 // Actual tx shifter
  reg [TX_BIT_COUNT_BITS_PP-1:0] tx_bit_count_l;
  reg [3:0] prescaler_count_l;
  reg [1:0] m1_state;
  reg [1:0] m1_next_state;

  wire [`TOTAL_BITS-1:0] tx_word = {{STOP_BITS_PP{1'b1}},
                                   data,
                                   {START_BITS_PP{1'b0}}};
  wire begin_last_bit;
  wire start_sending;
  wire tx_clk_1x;

  // This is a prescaler to produce the actual transmit clock.
  always @(posedge clk)
  begin
    if (reset) prescaler_count_l <= 0;
    else if (tx_clk)
    begin
      if (prescaler_count_l == (CLOCK_FACTOR_PP-1)) prescaler_count_l <= 0;
      else prescaler_count_l <= prescaler_count_l + 1;
    end
  end
  assign tx_clk_1x = ((prescaler_count_l == (CLOCK_FACTOR_PP-1) ) && tx_clk);

  // This is the transmitted bit counter
  always @(posedge clk)
  begin
    if (start_sending) tx_bit_count_l <= 0;
    else if (tx_clk_1x)
    begin
      if (tx_bit_count_l == (`TOTAL_BITS-2)) tx_bit_count_l <= 0;
      else tx_bit_count_l <= tx_bit_count_l + 1;
    end
  end
  assign begin_last_bit = ((tx_bit_count_l == (`TOTAL_BITS-2) ) && tx_clk_1x);

  assign start_sending = (tx_clk_1x && load);


  // This state machine handles sending out the transmit data
  
  // State register.
  always @(posedge clk)
  begin : state_register
    if (reset) m1_state <= m1_idle;
    else m1_state <= m1_next_state;
  end

  // State transition logic
  always @(m1_state or tx_clk_1x or load or begin_last_bit)
  begin : state_logic
    // Signal is low unless changed in a state condition.
    load_request <= 0;
    case (m1_state)
      m1_idle :
            begin
              load_request <= tx_clk_1x;
              if (tx_clk_1x && load) m1_next_state <= m1_sending;
              else m1_next_state <= m1_idle;
            end
      m1_sending :
            begin
              if (begin_last_bit) m1_next_state <= m1_sending_last_bit;
              else m1_next_state <= m1_sending;
            end
      m1_sending_last_bit :
            begin
              load_request <= tx_clk_1x;
              if (load & tx_clk_1x) m1_next_state <= m1_sending;
              else if (tx_clk_1x) m1_next_state <= m1_idle;
              else m1_next_state <= m1_sending_last_bit;
            end
      default :
            begin
              m1_next_state <= m1_idle;
            end
    endcase
  end


  // This is the transmit shifter
  always @(posedge clk)
  begin : txd_shifter
    if (reset) q <= 0;  // set output to all ones
    else if (start_sending) q <= ~tx_word;
    else if (tx_clk_1x) q <= {1'b0,q[`TOTAL_BITS-1:1]};
  end
  
  assign txd = ~q[0];

endmodule

