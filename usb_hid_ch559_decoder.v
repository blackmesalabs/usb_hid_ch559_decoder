/* ****************************************************************************
-- (C) Copyright 2022 Black Mesa Labs
-- Source file: usb_hid_ch559_decoder.v                
-- Date:        November 13, 2022
-- Author:      khubbard
-- Description: Decode the 400,000 baud USB HID stream of mouse and/or keyboard
-- Language:    Verilog-2001 
-- License:     This project is licensed with the CERN Open Hardware Licence
--              v1.2.  You may redistribute and modify this project under the
--              terms of the CERN OHL v.1.2. (http://ohwr.org/cernohl).
--              This project is distributed WITHOUT ANY EXPRESS OR IMPLIED
--              WARRANTY, INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY
--              AND FITNESS FOR A PARTICULAR PURPOSE. Please see the CERN OHL
--              v.1.2 for applicable Conditions.
--
-- Mouse:
-- [ Signature  ] [ Vendor Unique ]  v
-- fe 06 00 04 02 00 01 6d 04 69 c0 01 00 00 00 00 00 0a # Left Button
-- fe 04 00 04 02 00 01 5e 04 83 00 01 00 00 00 0a       # Simple Scroll Mouse
--                                   0  1  2  3  4  5
--    buttons    = keys[0];
--    horizontal = keys[1];
--    vertical   = keys[2];
--    wheel      = keys[4] (side buttons) or keys[3] (Simple);
--    if ( horizontal >= 0x80 ): horizontal = horizontal -256;
--    if ( vertical   >= 0x80 ): vertical   = vertical   -256;
--    if ( wheel      >= 0x80 ): wheel      = wheel      -256; +/- 1
--
-- Keyboard:
-- [ Signature  ][ Vendor Unique  ]
-- fe 08 00 04 06 00 05 f2 04 e9 14 02 00 06 00 00 00 00 00 0a
--                                   0  1  2  3  4  5  6  7
-- https://wiki.osdev.org/USB_Human_Interface_Devices
-- 0     Byte    Modifier keys status
-- 1     Byte    Reserved field
-- 2     Byte    Keypress #1
-- 3     Byte    Keypress #2
-- 4     Byte    Keypress #3
-- 5     Byte    Keypress #4
-- 6     Byte    Keypress #5
-- 7     Byte    Keypress #6
--
-- Modifiers
-- 0       1       Left Ctrl
-- 1       1       Left Shift
-- 2       1       Left Alt
-- 3       1       Left GUI (Windows/Super key)
-- 4       1       Right Ctrl
-- 5       1       Right Shift
-- 6       1       Right Alt
-- 7       1       Right GUI (Windows/Super key)
--
-- Revision History:
-- Ver#  When      Who      What
-- ----  --------  -------- ---------------------------------------------------
-- 0.1   11.13.22  khubbard Creation
-- ***************************************************************************/
`default_nettype none // Strictly enforce all nets to be declared
                                                                                
module usb_hid_ch559_decoder
(
  input  wire         reset,
  input  wire         clk,
  input  wire         rx_rdy,
  input  wire [7:0]   rx_byte,
  output wire [15:0]  hid_keyboard_data,
  output wire         hid_keyboard_rdy,
  output wire [31:0]  hid_mouse_data,
  output wire         hid_mouse_rdy 
); // module usb_hid_ch559_decoder


  reg  [15:0]    uart_timeout_cnt;
  reg            uart_timeout_jk;
  reg  [4:0]     keyboard_fsm_cnt;
  reg            keyboard_fsm_start;
  reg            keyboard_fsm_done;
  reg  [15:0]    keyboard_pend;
  reg  [15:0]    keyboard_actv;
  reg            keyboard_rdy;
  reg  [4:0]     mouse_fsm_cnt;
  reg            mouse_fsm_start;
  reg            mouse_fsm_done;
  reg  [31:0]    mouse_pend;
  reg  [31:0]    mouse_actv;
  reg            mouse_rdy;
  reg            mouse_type;

  assign hid_keyboard_data = keyboard_actv[15:0];
  assign hid_keyboard_rdy  = keyboard_rdy;

  assign hid_mouse_data    = mouse_actv[31:0]
  assign hid_mouse_rdy     = mouse_rdy;


// Note : This doesn't monitor Mouse-X and Mouse-Y deltas. Too many bits
//assign sump_dbg[16:0] = { keyboard_rdy, keyboard_actv[15:0] };
//assign sump_dbg[19:17] = 3'd0;
//assign sump_dbg[31:20] = { mouse_rdy, mouse_actv[18:16], mouse_actv[31:24] };

//assign sump_dbg[19:16] = { 1'b0, mouse_type, mouse_fsm_done, mouse_fsm_start };
//assign sump_dbg[15:0 ] = { 10'd0, mouse_fsm_cnt[4:0] };


//-----------------------------------------------------------------------------
// CH559 seems consistent on sending a new report byte every 30uS or so.
// Start a watchdog timer after each byte received and delcare "idle" period
// is 100uS has gone by. Use idle flag to declare the start of a new report
// if the flag is set and an 0xFE comes in
// 100uS / 80 MHz = 8,000
//-----------------------------------------------------------------------------
always @ ( posedge clk or posedge reset ) begin : proc_wd 
 if ( reset == 1 ) begin
   uart_timeout_cnt <= 16'd0;
   uart_timeout_jk  <= 0;
 end else begin 
   if ( rx_rdy == 1 ) begin 
     uart_timeout_cnt <= 16'd0;
     uart_timeout_jk  <= 0;
   end else begin 
     if ( uart_timeout_cnt == 16'd8000 ) begin 
       uart_timeout_jk  <= 1;
     end else begin
       uart_timeout_cnt <= uart_timeout_cnt + 1;
       uart_timeout_jk  <= 0;
     end
   end
 end 
end // proc_wd


//-----------------------------------------------------------------------------
// [ Signature  ][ Vendor Unique  ]
// fe 08 00 04 06 00 05 f2 04 e9 14 02 00 06 00 00 00 00 00 0a
//-----------------------------------------------------------------------------
always @ ( posedge clk or posedge reset ) begin : proc_keyboard_fsm
 if ( reset == 1 ) begin
   keyboard_fsm_cnt   <= 5'd0;
   keyboard_fsm_done  <= 0;
   keyboard_fsm_start <= 0;
 end else begin 
   keyboard_fsm_start <= 0;
   keyboard_fsm_done  <= 0;
   if ( rx_rdy == 1 ) begin 
     if ( uart_timeout_jk == 1 ) begin
       if ( rx_byte == 8'hFE && keyboard_fsm_cnt == 5'd0 ) begin 
         keyboard_fsm_cnt   <= keyboard_fsm_cnt + 1;
         keyboard_fsm_start <= 1;
       end else begin
         keyboard_fsm_cnt  <= 5'd0;// Flush any garbage
       end
     end else begin
       if ( keyboard_fsm_cnt >= 5'd1 ) begin 
         keyboard_fsm_cnt <= keyboard_fsm_cnt + 1;
       end
       if ( rx_byte != 8'h08 && keyboard_fsm_cnt == 5'd1 ) begin 
         keyboard_fsm_cnt  <= 5'd0;// Flush any garbage
       end
       if ( rx_byte != 8'h00 && keyboard_fsm_cnt == 5'd2 ) begin 
         keyboard_fsm_cnt  <= 5'd0;// Flush any garbage
       end
       if ( rx_byte != 8'h04 && keyboard_fsm_cnt == 5'd3 ) begin 
         keyboard_fsm_cnt  <= 5'd0;// Flush any garbage
       end
       if ( rx_byte != 8'h06 && keyboard_fsm_cnt == 5'd4 ) begin 
         keyboard_fsm_cnt  <= 5'd0;// Flush any garbage
       end
       if ( rx_byte == 8'h0A && keyboard_fsm_cnt == 5'd19) begin 
         keyboard_fsm_cnt  <= 5'd0;
         keyboard_fsm_done <= 1;
       end else if ( keyboard_fsm_cnt == 5'd19) begin 
         keyboard_fsm_cnt  <= 5'd0;
       end
     end
   end
 end
end


//-----------------------------------------------------------------------------
// Latch the data as it flies by. Store in pending. xfer when 0x0A comes in.
// WARNING : This doesn't handle multiple keys at once other than modifiers.
//-----------------------------------------------------------------------------
always @ ( posedge clk or posedge reset ) begin : proc_keyboard_data
 if ( reset == 1 ) begin
   keyboard_pend <= 16'd0;
   keyboard_actv <= 16'd0;
   keyboard_rdy  <= 0;
 end else begin 
   keyboard_rdy  <= 0;
   if ( rx_rdy == 1 ) begin 
     if ( keyboard_fsm_cnt == 5'd11 ) begin 
       keyboard_pend[15:8] <= rx_byte[7:0];// Modifiers
     end
     if ( keyboard_fsm_cnt == 5'd13 ) begin 
       keyboard_pend[7:0]  <= rx_byte[7:0];// Keys
     end
   end
   if ( keyboard_fsm_done == 1 ) begin
     keyboard_actv <= keyboard_pend[15:0];
     keyboard_rdy  <= 1;
   end
 end
end


//-----------------------------------------------------------------------------
// [ Signature  ] [ Vendor Unique ] v
// fe 06 00 04 02 00 01 6d 04 69 c0 01 00 00 00 00 00 0a # Left Button
// fe 04 00 04 02 00 01 5e 04 83 00 01 00 00 00 0a       # Simple Scroll Mouse
//-----------------------------------------------------------------------------
always @ ( posedge clk or posedge reset ) begin : proc_mouse_fsm
 if ( reset == 1 ) begin
   mouse_fsm_cnt   <= 5'd0;
   mouse_fsm_done  <= 0;
   mouse_fsm_start <= 0;
   mouse_type      <= 0;
 end else begin 
   mouse_fsm_done  <= 0;
   mouse_fsm_start <= 0;
   if ( rx_rdy == 1 ) begin 
     if ( uart_timeout_jk == 1 ) begin
       if ( rx_byte == 8'hFE && mouse_fsm_cnt == 5'd0 ) begin 
         mouse_fsm_cnt   <= mouse_fsm_cnt + 1;
         mouse_fsm_start <= 1;
       end else begin
         mouse_fsm_cnt  <= 5'd0;
       end
     end else begin
       if ( mouse_fsm_cnt >= 5'd1 ) begin 
         mouse_fsm_cnt <= mouse_fsm_cnt + 1;
       end
       if ( rx_byte == 8'h06 && mouse_fsm_cnt == 5'd1 ) begin 
         mouse_type <= 1;// Fancy Mouse        
       end
       if ( rx_byte == 8'h04 && mouse_fsm_cnt == 5'd1 ) begin 
         mouse_type <= 0;// Simple Mouse        
       end
       if ( ~( rx_byte == 8'h06 || rx_byte == 8'h04 ) && 
            mouse_fsm_cnt == 5'd1 ) begin 
         mouse_fsm_cnt  <= 5'd0;// Flush any garbage
       end
       if ( rx_byte != 8'h00 && mouse_fsm_cnt == 5'd2 ) begin 
         mouse_fsm_cnt  <= 5'd0;// Flush any garbage
       end
       if ( rx_byte != 8'h04 && mouse_fsm_cnt == 5'd3 ) begin 
         mouse_fsm_cnt  <= 5'd0;// Flush any garbage
       end
       if ( rx_byte != 8'h02 && mouse_fsm_cnt == 5'd4 ) begin 
         mouse_fsm_cnt  <= 5'd0;// Flush any garbage
       end
       if ( rx_byte == 8'h0A && 
           ( ( mouse_type == 0 && mouse_fsm_cnt == 5'd15) ||
             ( mouse_type == 1 && mouse_fsm_cnt == 5'd17)   )
          ) begin
         mouse_fsm_cnt  <= 5'd0;
         mouse_fsm_done <= 1;
         mouse_type     <= 0;
       end else if ( mouse_fsm_cnt == 5'd17) begin 
         mouse_fsm_cnt  <= 5'd0;
       end
     end
   end
 end
end


//-----------------------------------------------------------------------------
// Latch the data as it flies by. Store in pending. xfer when 0x0A comes in.
//-----------------------------------------------------------------------------
always @ ( posedge clk or posedge reset ) begin : proc_mouse_data
 if ( reset == 1 ) begin
   mouse_pend <= 32'd0;
   mouse_actv <= 32'd0;
   mouse_rdy  <= 0;
 end else begin 
   mouse_rdy  <= 0;
   if ( rx_rdy == 1 ) begin 
     if ( mouse_fsm_cnt == 5'd11 ) begin 
       mouse_pend[31:24] <= rx_byte[7:0];// Mouse Buttons
     end
     if ( mouse_fsm_cnt == 5'd12 ) begin 
       mouse_pend[15:8]  <= rx_byte[7:0];// Mouse Horizontal Delta
     end
     if ( mouse_fsm_cnt == 5'd13 ) begin 
       mouse_pend[7:0]   <= rx_byte[7:0];// Mouse Vertical Delta
     end
     if ( ( mouse_type == 0 && mouse_fsm_cnt == 5'd14 ) ||
          ( mouse_type == 1 && mouse_fsm_cnt == 5'd15 )   ) begin
       mouse_pend[23:16] <= rx_byte[7:0];// Mouse Wheel, 01 or FF
     end
   end
   if ( mouse_fsm_done == 1 ) begin
     mouse_actv <= mouse_pend[31:0];
     mouse_rdy  <= 1;
   end
 end
end


endmodule // usb_hid_ch559_decoder
`default_nettype wire // enable Verilog default for any 3rd party IP needing it
