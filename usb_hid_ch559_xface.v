/* ****************************************************************************
-- (C) Copyright 2022 Black Mesa Labs
-- Source file: usb_hid_ch559_xface.v                
-- Date:        November 13, 2022
-- Author:      khubbard
-- Description: Decode the 400,000 baud USB HID stream of mouse and/or keyboard
-- Language:    Verilog-2001 
--
-- WARNING : The CH559 module is unable to overdrive the Spartan3 soft pulldown.
--
-- WARNING : There seems to be some voltage drop issues. For example, mouse 
--           plugged in to CH559 will work just fine one one USB hub, but on
--           another it will spit some initial HID info and then stop.
--
-- Note: baud_rate[15:0] is actual number of clocks in a symbol:
--       Example 10 Mbps with 100 MHz clock, baud_rate = 0x000a;// Div-10
--
-- Revision History:
-- Ver#  When      Who      What
-- ----  --------  -------- ---------------------------------------------------
-- 0.1   11.13.22  khubbard Creation
-- ***************************************************************************/
//`default_nettype none // Strictly enforce all nets to be declared
                                                                                
module usb_hid_ch559_xface
(
  input  wire         reset,
  input  wire         clk,
  input  wire         rxd,
  output wire [15:0]  hid_keyboard_data,
  output wire         hid_keyboard_rdy,
  output wire [31:0]  hid_mouse_data,
  output wire         hid_mouse_rdy
); // module usb_hid_ch559_xface


  wire           rx_rdy;
  wire [7:0]     rx_byte;


//-----------------------------------------------------------------------------
// UART 
//-----------------------------------------------------------------------------
mesa_rx_uart u_mesa_rx_uart
(
  .reset             ( reset              ),
  .clk               ( clk                ),
  .rxd               ( rxd                ),
  .rx_rdy            ( rx_rdy             ),
  .rx_byte           ( rx_byte[7:0]       ),
  .baud_rate         ( 16'd200            )   // 80 MHz / 400kbaud = 200
);// module mesa_rx_uart


//-----------------------------------------------------------------------------
// Protocol decoder
//-----------------------------------------------------------------------------
usb_hid_ch559_decoder u_usb_hid_ch559_decoder
(
  .reset             ( reset                   ),
  .clk               ( clk                     ),
  .rx_rdy            ( rx_rdy                  ),
  .rx_byte           ( rx_byte[7:0]            ),
  .hid_keyboard_data ( hid_keyboard_data[15:0] ),
  .hid_keyboard_rdy  ( hid_keyboard_rdy        ),
  .hid_mouse_data    ( hid_mouse_data[31:0]    ),
  .hid_mouse_rdy     ( hid_mouse_rdy           )
);// module usb_hid_ch559_decoder


endmodule // usb_hid_ch559_xface
`default_nettype wire // enable Verilog default for any 3rd party IP needing it
