// pif.cpp -----------------------------------------------------------
//
// Copyright (c) 2001 to 2013  te
//
// Licence: Creative Commons Attribution-ShareAlike 3.0 Unported License.
//          http://creativecommons.org/licenses/by-sa/3.0/
//---------------------------------------------------------------------

/*
XO2 Programming Interface

-----------------------------------------------------------------------------
UFM (Sector 1) Commands
-----------------------------------------------------------------------------

 Read Status Reg        0x3C  Read the 4-byte Configuration Status Register

 Check Busy Flag        0xF0  Read the Configuration Busy Flag status

 Bypass                 0xFF  Null operation.

 Enable Config I'face   0x74  Enable Transparent UFM access - All user I/Os
 (Transparent Mode)           (except the hardened user SPI port) are governed
                              by the user logic, the device remains in User
                              mode. (The subsequent commands in this table
                              require the interface to be enabled.)

 Enable Config I'face   0xC6  Enable Offline UFM access - All user I/Os
 (Offline Mode)               (except persisted sysCONFIG ports) are tri-stated
                              User logic ceases to function, UFM remains
                              accessible, and the device enters 'Offline'
                              access mode. (The subsequent commands in this
                              table require the interface to be enabled.)

 Disable Config I'face  0x26  Disable the configuration (UFM) access.

 Set Address            0xB4  Set the UFM sector 14-bit Address Register

 Init UFM Address       0x47  Reset to the Address Register to point to the
                              first UFM page (sector 1, page 0).

 Read UFM               0xCA  Read the UFM data. Operand specifies number
                              pages to read and number of dummy bytes to
                              prepend. Address Register is post-incremented.

 Erase UFM              0xCB  Erase the UFM sector only.

 Program UFM            0xC9  Write one page of data to the UFM. Address
                              Register is post-incremented.

-----------------------------------------------------------------------------
Config Flash (Sector 0) Commands
-----------------------------------------------------------------------------

 Read Device ID code    0xE0  Read the 4-byte Device ID (0x01 2b 20 43)

 Read USERCODE          0xC0  Read 32-bit USERCODE

 Read Status Reg        0x3C  Read the 4-byte Configuration Status Register

 Check Busy Flag        0xF0  Read the Configuration Busy Flag status

 Refresh                0x79  Launch boot sequence (same as toggling PROGRAMN)

 Flash Check            0x7D  This reads the on-chip config Flash bitstream
                              and checks the CRC of the Flash bits, without
                              actually writing the bits to the configuration
                              SRAM. (This is done in the background during
                              normal device operation). Query the Flash Check
                              Status bits of the Status register for result.

 Bypass                 0xFF  Null operation.

 Enable Config I'face   0x74  Enable Transparent Configuration Flash access -
 (Transparent Mode)           All user I/Os (except the hardened user SPI port)
                              are governed by the user logic, the device
                              remains in User mode. (The subsequent commands
                              in this table require the interface to be
                              enabled.)

 Enable Config I'face   0xC6  Enable Offline Configuration Flash access -
 (Offline Mode)               All user I/Os (except persisted sysCONFIG ports)
                              are tri-stated. User logic ceases to function,
                              UFM remains accessible, and the device enters
                              ‘Offline’ access mode. (The subsequent commands
                              in this table require the interface to be
                              enabled.)

 Disable Config I'face  0x26  Exit access mode.

 Set Address            0xB4  Set the 14-bit Address Register

 Verify Device ID       0xE2  Verify device ID with 32-bit input, set Fail
                              flag if mismatched.

 Init CFG Address       0x46  Reset to the Address Register to point to the
                              first Config flash page (sector 0, page 0).

 Read Config Flash      0x73  Read the Config Flash data. Operand specifies
                              number pages to read and number of dummy bytes
                              to prepend. Address Register is post-incremented.

 Erase Flash            0x0E  Erase the Config Flash, Done bit, Security bits
                              and USERCODE

 Program Config Flash   0x70  Write 1 page of data to the Config Flash.
                              Address Register is post-incremented.

 Program DONE           0x5E  Program the Done bit

 Program SECURITY       0xCE  Program the Security bit (Secures CFG Flash
                              sector)

 Program SECURITY PLUS  0xCF  Program the Security Plus bit
                              (Secures UFM Sector)
                              (only valid when Security bit is also set)

 Program USERCODE       0xC2  Program 32-bit USERCODE

-----------------------------------------------------------------------------
Non-Volatile Register (NVR) Commands
-----------------------------------------------------------------------------

 Read Trace ID code     0x19  Read 64-bit TraceID.
-----------------------------------------------------------------------------
*/

#include <assert.h>
#include <stdio.h>
#include <time.h>

#include "lowlevel.h"
#include "bcm2835.h"
#include "pif.h"

#define ISC_ERASE               0x0e
#define ISC_DISABLE             0x26
#define ISC_INIT_CFG_ADDR       0x46
#define ISC_INIT_UFM_ADDR       0x47
#define ISC_PROG_DONE           0x5e
#define ISC_PROG_CFG_INCR       0x70
#define ISC_READ_CFG_INCR       0x73
#define ISC_ENABLE_X            0x74
#define ISC_REFRESH             0x79
#define ISC_ENABLE_PROG         0xc6
#define ISC_PROG_UFM_INCR       0xc9
#define ISC_READ_UFM_INCR       0xca
#define ISC_ERASE_UFM           0xcb
#define LSC_WRITE_ADDRESS       0xb4

#define BYPASS                  0xff
#define CHECK_BUSY_FLAG         0xf0

#define READ_DEVICE_ID_CODE     0xe0
#define READ_STATUS_REG         0x3c
#define READ_TRACE_ID_CODE      0x19

#define READ_USERCODE           0xc0
#define ISC_PROGRAM_USERCODE    0xc2

static const int MICROSEC = 1000;              // nanosecs
static const int MILLISEC = 1000 * MICROSEC;   // nanosecs

//---------------------------------------------------------------------
uint32_t Tpif::_dwordBE(uint8_t *p) {
  uint32_t v = 0;
  for (int i=0; i<4; i++)
    v = (v<<8) | (uint32_t)(*p++);
  return v;
  }

//---------------------------------------------------------------------
bool Tpif::_cfgWrite(TllWrBuf& oBuf) {
  if (oBuf.length() > 0)
    return pLo->spiWrite(RW_CONFIG, oBuf.data(), oBuf.length());
  else
    return true;
  }

//---------------------------------------------------------------------
bool Tpif::_cfgWriteRead(TllWrBuf& oBuf, uint8_t *pRdData, size_t ArdLen) {
  assert(pRdData);
  memset(pRdData, 0, ArdLen);
  return pLo->spiWriteRead(RW_CONFIG, oBuf.data(), oBuf.length(),
                                                            pRdData, ArdLen);
  }

//---------------------------------------------------------------------
bool Tpif::getDeviceIdCode(uint32_t& v) {
  v = 0;
  TllWrBuf oBuf;
  oBuf.byte(READ_DEVICE_ID_CODE).byte(0).byte(0).byte(0);

  uint8_t p[4];
  bool ok = _cfgWriteRead(oBuf, p, 4);
  v = _dwordBE(p);
  return ok;
  }

//---------------------------------------------------------------------
bool Tpif::getStatusReg(uint32_t& v) {
  v = 0;
  TllWrBuf oBuf;
  oBuf.byte(READ_STATUS_REG).byte(0).byte(0).byte(0);

  uint8_t p[4];
  bool ok = _cfgWriteRead(oBuf, p, 4);
  v = _dwordBE(p);
  return ok;
  }

//---------------------------------------------------------------------
bool Tpif::getTraceId(uint8_t* p) {
  TllWrBuf oBuf;
  oBuf.byte(READ_TRACE_ID_CODE).byte(0).byte(0).byte(0);
  return _cfgWriteRead(oBuf, p, 8);
  }

//---------------------------------------------------------------------
bool Tpif::_doSimple(int Acmd, int Ap0) {
  TllWrBuf oBuf;
  oBuf.byte(Acmd).byte(Ap0).byte(0).byte(0);
  waitUntilNotBusy(-1);
  return _cfgWrite(oBuf);
  }

//---------------------------------------------------------------------
bool Tpif::initCfgAddr() {
  return _doSimple(ISC_INIT_CFG_ADDR);
  }

//---------------------------------------------------------------------
bool Tpif::_initUfmAddr() {
  return _doSimple(ISC_INIT_UFM_ADDR);
  }

bool Tpif::_setUfmPageAddr(int pageNumber) {
  TllWrBuf oBuf;
  int hi = (pageNumber >> 8) & 0xff;
  int lo = (pageNumber >> 0) & 0xff;
  oBuf.byte(LSC_WRITE_ADDRESS).byte(0).byte(0).byte(0).byte(0x40).byte(0)
                                                          .byte(hi).byte(lo);
  return _cfgWrite(oBuf);
  }

bool Tpif::progDone() {
  bool ok = _doSimple(ISC_PROG_DONE);
  // sleep for 200us
  nanosleep((struct timespec[]){{0, (200 * MICROSEC)}}, NULL);
  return ok;
  }

bool Tpif::refresh() {
  TllWrBuf oBuf;
  oBuf.byte(ISC_REFRESH).byte(0).byte(0);
  bool ok = _cfgWrite(oBuf);
  // sleep for 5ms
  nanosleep((struct timespec[]){{0, (5 * MILLISEC)}}, NULL);
  return ok;
  }

bool Tpif::erase(int Amask) {
  bool ok = _doSimple(ISC_ERASE, Amask);
  waitUntilNotBusy(-1);
  return ok;
  }

//---------------------------------------------------------------------
bool Tpif::eraseCfg()  { return erase(CFG_ERASE); }
bool Tpif::eraseAll()  { return erase(UFM_ERASE | CFG_ERASE | FEATURE_ERASE); }

bool Tpif::eraseUfm() {
  return _doSimple(ISC_ERASE_UFM);
  }

//---------------------------------------------------------------------
bool Tpif::enableCfgInterfaceOffline() {
  bool ok = _doSimple(ISC_ENABLE_PROG, 0x08);
  nanosleep((struct timespec[]){{0, (5 * MICROSEC)}}, NULL);
  return ok;
  }

bool Tpif::enableCfgInterfaceTransparent() {
  bool ok = _doSimple(ISC_ENABLE_X, 0x08);
  nanosleep((struct timespec[]){{0, (5 * MICROSEC)}}, NULL);
  return ok;
  }

bool Tpif::disableCfgInterface() {
  waitUntilNotBusy(-1);

  TllWrBuf oBuf;
  oBuf.byte(ISC_DISABLE).byte(0).byte(0);
  bool ok = _cfgWrite(oBuf);

  if (ok) {
    oBuf.clear().byte(BYPASS).byte(0xff).byte(0xff).byte(0xff);
    ok = _cfgWrite(oBuf);
    }
  return ok;
  }

//---------------------------------------------------------------------
bool Tpif::_progPage(int Acmd, const uint8_t *p) {
  TllWrBuf oBuf;
  oBuf.byte(Acmd).byte(0).byte(0).byte(1);
  for (int i=0; i<CFG_PAGE_SIZE; i++)
    oBuf.byte(*p++);

  bool ok = _cfgWrite(oBuf);
  // sleep for 200us
  nanosleep((struct timespec[]){{0, (200 * MICROSEC)}}, NULL);
  return ok;
  }

//---------------------------------------------------------------------
bool Tpif::_readPage(int Acmd, uint8_t *p) {
  const int totalPages     = 1;
  const int numBytesToRead = CFG_PAGE_SIZE * totalPages;

  TllWrBuf oBuf;
  oBuf.byte(Acmd).byte(0x10).wordBE(totalPages);
  return _cfgWriteRead(oBuf, p, numBytesToRead);
  }

//---------------------------------------------------------------------
bool Tpif::_readPages(int Acmd, int numPages, uint8_t *p) {
  assert((numPages >= 0) && (p != 0));
  bool ok = true;
  for (int i=0; ok && (i<numPages); i++) {
    ok = _readPage(Acmd, p + CFG_PAGE_SIZE*i);
    }
  return ok;
  }

//---------------------------------------------------------------------
bool Tpif::progCfgPage(const uint8_t *p) {
  return _progPage(ISC_PROG_CFG_INCR, p);
  }

bool Tpif::readCfgPages(int numPages, uint8_t *p) {
  return _readPages(ISC_READ_CFG_INCR, numPages, p);
  }

bool Tpif::_progUfmPage(const uint8_t *p) {
  return _progPage(ISC_PROG_UFM_INCR, p);
  }

bool Tpif::readUfmPages(int numPages, uint8_t *p) {
  return _readPages(ISC_READ_UFM_INCR, numPages, p);
  }

bool Tpif::readUfmPages(int pageNumber, int numPages, uint8_t *p) {
  bool ok = enableCfgInterfaceTransparent();
//waitUntilNotBusy(-1);

  ok = _setUfmPageAddr(pageNumber);
  ok = readUfmPages(numPages, p);

  waitUntilNotBusy(-1);
  ok = progDone();
  ok = disableCfgInterface();
  return ok;
  }

bool Tpif::writeUfmPages(int pageNumber, int numPages, uint8_t *p) {
  bool ok = enableCfgInterfaceTransparent();
//waitUntilNotBusy(-1);

  ok = _setUfmPageAddr(pageNumber);
  for (int i=0; i<numPages; i++)
    ok = _progUfmPage(p + UFM_PAGE_SIZE*i);

  waitUntilNotBusy(-1);
  ok = progDone();
  ok = disableCfgInterface();
  return ok;
  }

//---------------------------------------------------------------------
bool Tpif::setUsercode(uint8_t* p) {
  assert(p);
  TllWrBuf oBuf;
  oBuf.byte(ISC_PROGRAM_USERCODE).byte(0).byte(0).byte(0);
  for (int i=0; i<4; i++)
    oBuf.byte(p[i]);

  bool ok = _cfgWrite(oBuf);
  // sleep for 200us
  nanosleep((struct timespec[]){{0, (200 * MICROSEC)}}, NULL);
  return ok;
  }

bool Tpif::getUsercode(uint8_t* p) {
  assert(p);
  TllWrBuf oBuf;
  oBuf.byte(READ_USERCODE).byte(0).byte(0).byte(0);
  return _cfgWriteRead(oBuf, p, 4);
  }

//---------------------------------------------------------------------
bool Tpif::getBusyFlag(int *pFlag) {
  *pFlag = 1;
  const int numBytesToRead = 1;

  TllWrBuf oBuf;
  oBuf.byte(CHECK_BUSY_FLAG).byte(0).byte(0).byte(0);

  uint8_t flag = 0;
  bool ok = _cfgWriteRead(oBuf, &flag, numBytesToRead);
  if (ok)
    *pFlag = (flag >> 7) & 1;

  return ok;
  }

//---------------------------------------------------------------------
bool Tpif::_isBusy() {
  int busyFlag = 0;
  getBusyFlag(&busyFlag);
  return (busyFlag == 1);
  }

bool Tpif::waitUntilNotBusy(int maxLoops) {
  int i;
  for (i=0; (maxLoops<0) || (i<maxLoops); i++)
    if (_isBusy() == false)
      return true;
  return false;
  }

//---------------------------------------------------------------------
bool Tpif::mcpWrite(uint8_t* p, int len) {
  return pLo->i2cWrite(MCP23008_ADDR, p, len);
  }

bool Tpif::mcpRead(int Areg, uint8_t* p) {
  uint8_t reg = (uint8_t)Areg;
  return pLo->i2cWriteRead(MCP23008_ADDR, &reg, p, 1);
  }

//---------------------------------------------------------------------
bool Tpif::appRead(uint8_t *p, int AnumBytes) {
  if (AnumBytes <= 0)
    return true;

  return pLo->i2cRead(I2C_APP_ADDR, p, AnumBytes);
  }

//---------------------------------------------------------------------
bool Tpif::appWrite(uint8_t *p, int AnumBytes) {
  if (AnumBytes <= 0)
    return true;

  assert(p != 0);

  return pLo->i2cWrite(I2C_APP_ADDR, p, AnumBytes);
  }

//---------------------------------------------------------------------
Tpif::Tpif() {
  pLo = new TlowLevel;
  }

Tpif::~Tpif() {
  delete pLo;
  }

// EOF ----------------------------------------------------------------
/*
*/
