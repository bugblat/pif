#----------------------------------------------------------------------
# Name:        piffind.py
# Purpose:     sarch for the XO2 via the smbus Python library
#
# Author:      Tim
#
# Created:     11/07/2012
# Copyright:   (c) Tim 2013
# Licence:     Creative Commons Attribution-ShareAlike 3.0 Unported License.
#----------------------------------------------------------------------
#!/usr/bin/env python

import sys, ctypes, pifglobs
from ctypes   import *
from pifglobs import *

# import rpdb2
# rpdb2.start_embedded_debugger('pw')

##---------------------------------------------------------
def showDeviceID(handle):

  dw = c_ulong(0xdeadbeef)
  res = pifglobs.pif.pifGetDeviceIdCode(handle, byref(dw))
  if (res == 0):
    print("\nread ID code failed\n")
    return "failed"

  deviceID = dw.value
  print('XO2 Device ID: %08x' % deviceID) ,

  s = UNRECOGNIZED
  ok = (deviceID & 0xffff8fff) == (0x012ba043 & 0xffff8fff)
  model = (deviceID >> 12) & 7;

  if model == 0 :
    s = "XO2-256HC"
  elif model == 1 :
    s = "XO2-640HC"
  elif model == 2 :
    s = "XO2-1200HC"
  elif model == 3 :
    s = "XO2-2000HC"
  elif model == 4 :
    s = "XO2-4000HC"
  elif model == 5 :
    s = "XO2-7000HC"
  else:
    s = UNRECOGNIZED
    ok = false;

  if ok == True:
    print(" - device is an " + s)
  else:
    print(" - unrecognised ID!")

  return s;

##---------------------------------------------------------
def main():
  print("================= pif find ========================")
  handle = None
  try:

    pifglobs.pif = ctypes.CDLL("libpif.so")

    strBuf = create_string_buffer(1000)
    rv = pifglobs.pif.pifVersion(strBuf, sizeof(strBuf))
    print('Using pif library version: %s\n' % repr(strBuf.value))

    handle = c_int(pifglobs.pif.pifInit())
    dev = showDeviceID(handle)

  except:
    e = sys.exc_info()[0]
    print("\nException caught %s\n" % e)

  if handle:
    pifglobs.pif.pifClose(handle)
  print("\n==================== bye ==========================")

##---------------------------------------------------------
if __name__ == '__main__':
  main()

# EOF -----------------------------------------------------------------

