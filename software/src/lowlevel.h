// lowlevel.h ---------------------------------------------------------
//
// Copyright (c) 2001 to 2013 te
//
// Licence: Creative Commons Attribution-ShareAlike 3.0 Unported License.
//          http://creativecommons.org/licenses/by-sa/3.0/
//---------------------------------------------------------------------
#ifndef lowlevelH
#define lowlevelH

#include <stdint.h>
#include "llbufs.h"

#define MCP23008_ADDR       0x20

#define I2C_CFG_ADDR        0x40
#define I2C_APP_ADDR        0x41
#define I2C_RST_ADDR        0x43

#define RW_CONFIG           true
#define RW_APP              (!RW_CONFIG)

//---------------------------------------------------------------------
class TlowLevel {
  private:
    int   Fi2cSlaveAddr;
    bool  Finitialised;
    int   FlastResult;

    void _setI2Caddr(int AslaveAddr);
    void _setSpiConfig(bool Aconfig);

  public:
    //-------------------------------------------
    bool i2cWrite(int AslaveAddr, const uint8_t *pWrData, size_t AwrLen);
    bool i2cRead(int AslaveAddr, uint8_t *pRdData, size_t ArdLen);
    bool i2cWriteRead(int AslaveAddr, const uint8_t *pWrData,
                                            uint8_t *pRdData, size_t ArdLen);

    bool spiWrite(bool aConfig, const uint8_t *pWrData, size_t AwrLen);
    bool spiRead(bool aConfig, uint8_t *pRdData, size_t ArdLen);
    bool spiWriteRead(bool aConfig, const uint8_t *pWrData, size_t AwrLen,
                                            uint8_t *pRdData, size_t ArdLen);
    int lastReturnCode() { return FlastResult; }

    //-------------------------------------------
    TlowLevel();
    ~TlowLevel();
  };

#endif

// EOF ----------------------------------------------------------------
