#!python3
###############################################################################
# Source file : usb.py               
# Language    : Python 3.3 7
# Author      : Kevin M. Hubbard 
# Description : Listen to USB HID stream from "CH559" USB HID to UART.
# License     : GPLv3
#      This program is free software: you can redistribute it and/or modify
#      it under the terms of the GNU General Public License as published by
#      the Free Software Foundation, either version 3 of the License, or
#      (at your option) any later version.
#
#      This program is distributed in the hope that it will be useful,
#      but WITHOUT ANY WARRANTY; without even the implied warranty of
#      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#      GNU General Public License for more details.
#
#      You should have received a copy of the GNU General Public License
#      along with this program.  If not, see <http://www.gnu.org/licenses/>.
#                                                               
# https://www.usb.org/sites/default/files/documents/hut1_12v2.pdf
#
# PySerial for Python3 from:
#   https://pypi.python.org/pypi/pyserial/
#
# https://www.tindie.com/products/matzelectronics/ch559-usb-host-to-uart-bridge-module/
#
# Note : This works well with USB keyboards and mice. It doesn't not work
#        with game controllers as they seem to send data all the time and 
#        overflows the limited 400,000 baud UART pipe.
# -----------------------------------------------------------------------------
# History :
#   2022.11.04 : khubbard : Created 
###############################################################################
import sys;
import select;
import socket;
import time;
import os;

def main():
  args = sys.argv + [None]*3;# Example "usb.ini"
  vers          = "2022.11.04";
  auth          = "khubbard";

  # If no ini file is specified in ARGS[1], look for usb.ini in CWD.
  file_name = os.path.join( os.getcwd(), "usb.ini");
  if ( args[1] != None and os.path.exists( args[1] ) ):
    file_name = args[1];

  # If it exists, load it, otherwise create a default one and then load it.
  if ( ( os.path.exists( file_name ) ) == False ):
    ini_list =  ["usb_port        = COM3    # ie COM4",
                 "baudrate        = 921600  # ie 921600", ];
    ini_file = open ( file_name, 'w' );
    for each in ini_list:
      ini_file.write( each + "\r\n" );
    ini_file.close();
    
  if ( ( os.path.exists( file_name ) ) == True ):
    ini_file = open ( file_name, 'r' );
    ini_list = ini_file.readlines();
    ini_hash = {};
    for each in ini_list:
      words = " ".join(each.split()).split(' ') + [None] * 4;
      if ( words[1] == "=" ):
        ini_hash[ words[0] ] = words[2];

  com_port     = ini_hash["usb_port"];
  baudrate     = int(ini_hash["baudrate"],10);
    
  os.system('cls');# Win specific clear screen
  print("------------------------------------------------------------------" );
  print("usb.py "+vers+" by "+auth+".");

  # Establish Hardware Connection
  hw = UART( port_name=com_port, baudrate=baudrate );

  log = [];
  dashes = "--------------------------";
  file_name = "log.txt";
  # Create a file for appending to later
  file_out  = open( file_name, 'w' );
  file_out.write("\n" );
  file_out.close();

  ##############################
  # Main Loop 
  ##############################
  run = True;
  buffer = [];
  rx = b"";# Binary string
  i = 0;
  hid_keyboard = False;
  hid_unknown  = False;
  hid_mouse    = False;

# hid_keyboard = True;
  hid_mouse    = True;
# hid_unknown  = True;
  x = 0;
  y = 0;
  while ( run == True ):
    rx = rx + hw.rd();
    hex_str = "";
    txt_str = "";

    if ( hid_unknown == True ):
      hex_list = [ "%02x" % each for each in rx ];# list comprehension
      hex_str = "";
      for each in hex_list:
        hex_str += each + " ";
      file_out  = open( file_name, 'a' );
      file_out.write( hex_str + "\n" );
      file_out.close();
      print( hex_str );
      rx = b"";
    else:
      # Note that 0x0a is both end of a UART line AND a valid binary char ( K_g )
      # If the length isn't correct, just append until the length is correct
      # Keyboards begin with "FE 08 00 04 06" and packets are 19 bytes plus the <LF>
      # Mice      begin with "FE 06 00 04 02" and packets are 17 bytes plus the <LF>

      if ( hid_keyboard == True ):
        if ( len(rx) >= 20 ):
          if ( rx[0:5] == b'\xfe\x08\x00\x04\x06' ):
            hid_keyboard_filter( rx );
            rx = b"";

      if ( hid_mouse    == True ):
        if ( len(rx) >= 16 ):
          if ( rx[0:5] == b'\xfe\x06\x00\x04\x02' or
               rx[0:5] == b'\xfe\x04\x00\x04\x02'    ):
            (b,w,h,v) = hid_mouse_filter( rx );
            rx = b"";
            x += h;
            y += v;
            print( b,w,x // 10, y//10 )
      # Don't allow undecoded garbage to accumulate. Do accumulate strings that were
      # parsed too soon due to 0x0A ( <LF> ) randomly showing up in the data stream.
      if ( len(rx) >= 20 ):
        rx = b"";
   
  # while ( run == True ):
# def main():

#######################################################################
#                                   v
# fe 06 00 04 02 00 01 6d 04 69 c0 01 00 00 00 00 00 0a  # Left Button
# fe 04 00 04 02 00 01 5e 04 cb 00 01 00 00 00 0a
# fe 04 00 04 02 00 01 ef 17 19 e0 01 00 00 00 0a
# fe 04 00 04 02 00 01 5e 04 83 00 01 00 00 00 0a
# Note : 18 vs 16 length is simple scroll wheel mice versus
# Logitech laser mice with side buttons.


def hid_mouse_filter( packet ):
  if ( len( packet ) == 18 or len( packet ) == 16 ):
    if ( packet[0:5] == b'\xfe\x06\x00\x04\x02' or
         packet[0:5] == b'\xfe\x04\x00\x04\x02'
       ):
      # keys = packet[11:17];
      keys = packet[11:16];
      buttons    = keys[0];
      horizontal = keys[1];
      vertical   = keys[2];
      if ( packet[0:5] == b'\xfe\x06\x00\x04\x02' ):
        wheel      = keys[4];
      else:
        wheel      = keys[3];
      if ( horizontal >= 0x80 ):
        horizontal = horizontal -256;
      if ( vertical   >= 0x80 ):
        vertical   = vertical   -256;
      if ( wheel      >= 0x80 ):
        wheel      = wheel      -256;
#     print("%02x : %02x %02x : %02x %02x : %02x" % \
#            ( keys[0], keys[1], keys[2], keys[3],keys[4],keys[5] ) );
      return ( buttons, wheel, horizontal, vertical );
  return ( 0,0,0,0 );

#######################################################################
# fe 08 00 04 06 00 05 f2 04 e9 14 02 00 06 00 00 00 00 00 0a
# -------------- -----------------  0  1  2  3  4  5  6  7
#    Common       Vendor Unique
# https://wiki.osdev.org/USB_Human_Interface_Devices
# 0     Byte    Modifier keys status.
# 1     Byte    Reserved field.
# 2     Byte    Keypress #1.
# 3     Byte    Keypress #2.
# 4     Byte    Keypress #3.
# 5     Byte    Keypress #4.
# 6     Byte    Keypress #5.
# 7     Byte    Keypress #6.
# Modifiers
# 0       1       Left Ctrl.
# 1       1       Left Shift.
# 2       1       Left Alt.
# 3       1       Left GUI (Windows/Super key.)
# 4       1       Right Ctrl.
# 5       1       Right Shift.
# 6       1       Right Alt.
# 7       1       Right GUI (Windows/Super key.)
def hid_keyboard_filter( packet ):
  key_lut = {
    0x27 : "K_0",
    0x29 : "K_ESCAPE",
    0x35 : "K_BACKQUOTE",
    0x2d : "K_MINUS",
    0x2e : "K_PLUS",
    0x2a : "K_BACKSPACE",
    0x49 : "K_INSERT",
    0x4a : "K_HOME",
    0x4b : "K_PAGEUP",
    0x46 : "K_PRINT",
    0x47 : "K_SCROLLOCK",
    0x48 : "K_PAUSE",
    0x2b : "K_TAB",
    0x2f : "K_LEFTBRACKET",
    0x30 : "K_RIGHTBRACKET",
    0x31 : "K_BACKSLASH",
    0x4c : "K_DELETE",
    0x4d : "K_END",
    0x4e : "K_PAGEDOWN",
    0x39 : "K_CAPSLOCK",
    0x33 : "K_SEMICOLON",
    0x34 : "K_QUOTE",
    0x28 : "K_ENTER",
    0x36 : "K_COMMA",
    0x37 : "K_PERIOD",
    0x38 : "K_SLASH",
    0x50 : "K_LEFT",
    0x51 : "K_DOWN",
    0x4f : "K_RIGHT",
    0x52 : "K_UP",
   };

  if ( len( packet ) == 20 ):
    if ( packet[0:5] == b'\xfe\x08\x00\x04\x06' ):
      keys = packet[11:19];
#     print( keys );
      for key_each in keys[2:]:
        key_val = "";
        if ( key_lut.get( key_each ) != None ):
          key_val = key_lut[ key_each ];
        elif ( key_each >= 0x04 and key_each <= 0x1d ):
          key_val = "K_" + chr( 97 - 0x04 + key_each );# a-z
        elif ( key_each >= 0x1e and key_each <= 0x26 ):
          key_val = "K_" + chr( 49 - 0x1e + key_each );# 1-9
        elif ( key_each >= 0x3a and key_each <= 0x45 ):
          key_val = "K_F%d" % ( key_each - 0x3A + 1 );# F1-F12
        else:
          key_val = "%02x" % key_each;
        if ( key_each != 0x00 ):
          print( key_val );
  return

def list2file( file_name, my_list ):
  file_out  = open( file_name, 'w' );
  for each in my_list:
    file_out.write( each + "\n" );
  file_out.close();
  return;


###############################################################################
# Protocol interface over a UART PySerial connection.
class UART:
  def __init__ ( self, port_name, baudrate ):
    try:
      import serial;
    except:
      raise RuntimeError("ERROR: PySerial from sourceforge.net is required");
      raise RuntimeError(         
         "ERROR: Unable to import serial\n"+
         "PySerial from sourceforge.net is required for USB connection.");
    try:
      self.ser = serial.Serial( port=port_name, baudrate=baudrate,
                               bytesize=8, parity='N', stopbits=1,
                               timeout=1, xonxoff=0, rtscts=0,     );
      self.port = port_name;
      self.baud = baudrate;
      self.ser.flushOutput();
      self.ser.flushInput();
    except:
      raise RuntimeError("ERROR: Unable to open USB COM Port "+port_name)

  def wr(self, addr, data):
    self.ser.write( " ".encode("utf-8") );
    return;

  def rd( self ):
    rts = self.ser.readline();
#   rts = rts.decode("utf-8");
    return rts;

  def close(self):
    self.ser.flushOutput();
    self.ser.flushInput();
    self.ser.close()

  def __del__(self):
    try:
      self.ser.close()
    except:
      raise RuntimeError("Backdoor ERROR: Unable to close COM Port!!")


###############################################################################
try:
  if __name__=='__main__': main()
except KeyboardInterrupt:
  print('Break!')
# EOF
