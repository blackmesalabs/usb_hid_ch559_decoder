# usb_hid_ch559_decoder
Verilog and Python for decoding USB Keyboard and USB Mouse streams from ch559 module
MatzElectronics has this neat $10 module that has 2 USB ports and outputs a UART data
stream at 400,000 baud (3.3V).
https://www.tindie.com/products/matzelectronics/ch559-usb-host-to-uart-bridge-module/

This repository has a Python script (usb.py) which decodes Keyboard and Mouse streams
via a FTDI TTL-232R-3V3 cable.

Using information captured from this, a verilog decoder was created which then 
outputs 16bit data for keyboard events and 32bit data for mouse events.

Note that Gamecontroller decoding wasn't successful. The gamecontrollers that were
tested output a continous stream of data which most likely overruns the 400,000 baud
UART on the ch559 module.

Python:
  usb.py  : Decodes serial stream to text
  usb.ini : Config file for baud and com port
Example captures:
  log_logitech_wired_mouse.txt
  log_wired_keyboard.txt
  log_wired_mouse_ms2.txt
Verilog: 
  usb_hid_ch559_decoder.v : Decoder for keyboard and mouse streams
  usb_hid_ch559_xface.v   : Hierarchy file
  mesa_rx_uart.v          : Receive only UART module
