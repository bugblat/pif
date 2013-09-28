// lowlevel.cpp -------------------------------------------------------
//
// Copyright (c) 2001 to 2013  te
//
// Licence: Creative Commons Attribution-ShareAlike 3.0 Unported License.
//          http://creativecommons.org/licenses/by-sa/3.0/
//---------------------------------------------------------------------

#include <assert.h>

#ifdef  _DEBUG
# include <stdio.h>
#endif

#include "lowlevel.h"
#include "bcm2835.h"

#define XO2_I2C_CLOCK_SPEED     (400 * 1000)

#define MCP_FPGA_TDO            (1 << 0)
#define MCP_FPGA_TDI            (1 << 1)
#define MCP_FPGA_TCK            (1 << 2)
#define MCP_FPGA_TMS            (1 << 3)
#define MCP_FPGA_JTAGENn        (1 << 4)  // JTAG enable when Lo
#define MCP_FPGA_PROGn          (1 << 5)
#define MCP_FPGA_INITn          (1 << 6)
#define MCP_FPGA_DONE           (1 << 7)

//---------------------------------------------------------------------
void TlowLevel::_setI2Caddr(int AslaveAddr) {
  if (Fi2cSlaveAddr != AslaveAddr)
    bcm2835_i2c_setSlaveAddress(AslaveAddr);
  Fi2cSlaveAddr = AslaveAddr;
  }

//---------------------------------------------------------------------
bool TlowLevel::i2cWrite(int AslaveAddr, const uint8_t *pWrData, size_t AwrLen) {
  _setI2Caddr(AslaveAddr);
  FlastResult = bcm2835_i2c_write((char *)pWrData, AwrLen);
  return (FlastResult==BCM2835_I2C_REASON_OK);
  }

//---------------------------------------------------------------------
bool TlowLevel::i2cRead(int AslaveAddr, uint8_t *pRdData, size_t ArdLen) {
  _setI2Caddr(AslaveAddr);
  FlastResult = bcm2835_i2c_read((char *)pRdData, ArdLen);
  return (FlastResult==BCM2835_I2C_REASON_OK);
  }

//---------------------------------------------------------------------
// The max write is 1.
bool TlowLevel::i2cWriteRead(int AslaveAddr,
                          const uint8_t *pWrData,
                          uint8_t *pRdData, size_t ArdLen) {
  _setI2Caddr(AslaveAddr);
  FlastResult = bcm2835_i2c_read_register_rs((char *)pWrData,
                                                  (char *)pRdData, ArdLen);

  return (FlastResult==BCM2835_I2C_REASON_OK);
  }

//---------------------------------------------------------------------
void TlowLevel::_setSpiConfig(bool Aconfig) {
  // TODO
  }

//---------------------------------------------------------------------
bool TlowLevel::spiWrite(bool aConfig, const uint8_t *pWrData, size_t AwrLen) {
  _setSpiConfig(aConfig);
  FlastResult = 0;
  bcm2835_spi_writenb((char *)pWrData, AwrLen);
  return true;
  }

//---------------------------------------------------------------------
bool TlowLevel::spiRead(bool aConfig, uint8_t *pRdData, size_t ArdLen) {
  _setSpiConfig(aConfig);
  FlastResult = 0;
  bcm2835_spi_transfern((char *)pRdData, ArdLen);
  return true;
  }

//---------------------------------------------------------------------
bool TlowLevel::spiWriteRead(bool aConfig,
                          const uint8_t *pWrData, size_t AwrLen,
                          uint8_t *pRdData, size_t ArdLen) {
  _setSpiConfig(aConfig);
  FlastResult = 0;

  uint8_t *buff = new uint8_t[AwrLen + ArdLen];
  memcpy(buff, pWrData, AwrLen);
  memcpy(buff+AwrLen, pRdData, ArdLen);
  bcm2835_spi_transfern((char *)buff, AwrLen + ArdLen);
  memcpy(pRdData, buff+AwrLen, ArdLen);
  delete[] buff;
  return true;
  }

//---------------------------------------------------------------------
TlowLevel::TlowLevel() : Fi2cSlaveAddr(~I2C_APP_ADDR) {
  int res = bcm2835_init();
  Finitialised = (res == 1);

  if (Finitialised) {
    // i2c initialise
    //bcm2835_set_debug(10);
    bcm2835_i2c_begin();
    bcm2835_i2c_set_baudrate(XO2_I2C_CLOCK_SPEED);

    // MCP23008 bits
    _setI2Caddr(MCP23008_ADDR);
    TllWrBuf oBuf;
    oBuf.clear().byte(6).byte(0xff);                            // all pullups
    i2cWrite(MCP23008_ADDR, oBuf.data(), oBuf.length());
    oBuf.clear().byte(9).byte(0xf7);                            // output reg
    i2cWrite(MCP23008_ADDR, oBuf.data(), oBuf.length());
    oBuf.clear().byte(0).byte(0xe1);                            // set inputs
    i2cWrite(MCP23008_ADDR, oBuf.data(), oBuf.length());

    _setI2Caddr(I2C_APP_ADDR);

    // spi initialise
    bcm2835_spi_begin();
    bcm2835_spi_setBitOrder(BCM2835_SPI_BIT_ORDER_MSBFIRST);      // default
    bcm2835_spi_setDataMode(BCM2835_SPI_MODE0);                   // default
//  bcm2835_spi_setClockDivider(BCM2835_SPI_CLOCK_DIVIDER_65536); // default
    bcm2835_spi_setClockDivider(BCM2835_SPI_CLOCK_DIVIDER_32);    // 8MHz
    bcm2835_spi_chipSelect(BCM2835_SPI_CS0);                      // default
    bcm2835_spi_setChipSelectPolarity(BCM2835_SPI_CS0, LOW);      // default
    }
  }

//---------------------------------------------------------------------
TlowLevel::~TlowLevel() {
  if (Finitialised) {
    bcm2835_spi_end();
    bcm2835_i2c_end();
    bcm2835_close();
    }
  Finitialised = false;
  }

// EOF ----------------------------------------------------------------
/*
    // Send a byte to the slave and simultaneously read a byte back from the slave
    // If you tie MISO to MOSI, you should read back what was sent
    uint8_t data = bcm2835_spi_transfer(0x23);
    printf("Read from SPI: %02X\n", data);

*/
