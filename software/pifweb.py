##---------------------------------------------------------
# Name:        pifweb.py
# Purpose:     control a pif board via a web server
#
# Author:      Tim
#
# Created:     08/07/2013
# Copyright:   (c) Tim 2013
# Licence:     Creative Commons Attribution-ShareAlike 3.0 Unported License.
##---------------------------------------------------------
# uses web.py - see  www.webpy.org
#
# windows command line start: python pifweb.py
#
#!/usr/bin/env python

import sys, web, ctypes, pifglobs
from web      import form
from ctypes   import *
from pifglobs import *

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
def sendAddressByte(handle, a):
  try:
    cmdLength = 1
    buff = create_string_buffer(chr(ADDRESS_MASK | a), cmdLength)
    numWritten = c_ulong(0)
    res = pifglobs.pif.pifAppWrite(handle, buff, cmdLength, byref(numWritten))
  except:
    print('FAILED: address byte send')

##---------------------------------------------------------
def sendDataByte(handle, v):
  try:
    cmdLength = 1
    buff = create_string_buffer(chr(DATA_MASK | v), cmdLength)
    numWritten = c_ulong(0)
    res = pifglobs.pif.pifAppWrite(handle, buff, cmdLength, byref(numWritten))
  except:
    print('FAILED: data byte send')

##---------------------------------------------------------
# write val into the Misc register inside the FPGA
def setMiscRegister(val):
  try:
    sendAddressByte(pifglobs.handle, W_MISC_REG)
    sendDataByte(pifglobs.handle, val)
  except:
    pass

##---------------------------------------------------------
urls    = ('/', 'index')
render  = web.template.render('templates/', base='layout')
tag     = 'Red and Green LEDs '
myform  = web.form.Form(
  form.Dropdown(tag, [STR_LEDS_ALT, STR_LEDS_SYNC, STR_LEDS_OFF]))

class index:
  def GET(self):
    form = myform()
    return render.index(pifglobs.state, form)

  def POST(self):
    form = myform()
    if form.validates():
      pifglobs.state = form[tag].value
      if pifglobs.state==STR_LEDS_ALT:
        setMiscRegister(LED_ALTERNATING)
      elif pifglobs.state==STR_LEDS_SYNC:
        setMiscRegister(LED_SYNC)
      elif pifglobs.state==STR_LEDS_OFF:
        setMiscRegister(LED_OFF)
    return render.index(pifglobs.state, form)

##---------------------------------------------------------
def main():
  handle = None
  try:
    pifglobs.pif = ctypes.CDLL("libpif.so")

    strBuf = create_string_buffer(1000)
    rv = pifglobs.pif.pifVersion(strBuf, sizeof(strBuf))
    print('Using pif library version: %s\n' % repr(strBuf.value))

    handle = c_int(pifglobs.pif.pifInit())
    dev = showDeviceID(handle)

    if dev != UNRECOGNIZED:
      print('pif detected')
      pifglobs.handle = handle
      pifglobs.state = STR_LEDS_ALT
      setMiscRegister(LED_ALTERNATING)
      app = web.application(urls, globals())
      app.run()

  except:
    e = sys.exc_info()[0]
    print("\nException caught %s\n" % e)

  if handle:
    pifglobs.pif.pifClose(handle)

##---------------------------------------------------------
if __name__ == '__main__':
  main()

# EOF -----------------------------------------------------------------
