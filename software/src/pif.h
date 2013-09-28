// pif.h -------------------------------------------------------------
//
// Copyright (c) 2001 to 2013  te
//
// Licence: Creative Commons Attribution-ShareAlike 3.0 Unported License.
//          http://creativecommons.org/licenses/by-sa/3.0/
//---------------------------------------------------------------------
#ifndef pifH
#define pifH

#include "lowlevel.h"

#define CFG_PAGE_SIZE           16
#define UFM_PAGE_SIZE           16
#define CFG_PAGE_COUNT          2175
#define UFM_PAGE_COUNT          512

#define FEATURE_ERASE           (1<<1)
#define CFG_ERASE               (1<<2)
#define UFM_ERASE               (1<<3)

#define DEFAULT_BUSY_LOOPS      5

#define A_ADDR                  (0<<6)     /* sending an address */
#define D_ADDR                  (1<<6)     /* sending data       */

class TlowLevel;

//---------------------------------------------------------------------
class Tpif {
  private:
    TlowLevel *pLo;

    uint32_t _dwordBE(uint8_t *p);
    bool _cfgWrite(TllWrBuf& oBuf);
    bool _cfgWriteRead(TllWrBuf& oBuf, uint8_t *pRdData, size_t ArdLen);

    bool _doSimple(int Acmd, int Ap0=0);

    bool _progPage(int Acmd, const uint8_t *p);
    bool _readPages(int Acmd, int numPages, uint8_t *p);
    bool _readPage(int Acmd, uint8_t *p);

    bool _initUfmAddr();
    bool _setUfmPageAddr(int pageNumber);
    bool _progUfmPage(const uint8_t *p);

    bool _isBusy();

  public:
    bool getDeviceIdCode(uint32_t& v);

    bool getStatusReg(uint32_t& v);
    bool getTraceId(uint8_t* p);

    bool enableCfgInterfaceOffline();
    bool enableCfgInterfaceTransparent();
    bool disableCfgInterface();
    bool refresh();
    bool progDone();

    bool erase(int Amask);
    bool eraseAll();

    bool initCfgAddr();
    bool eraseCfg();
    bool progCfgPage(const uint8_t *p);
    bool readCfgPages(int numPages, uint8_t *p);

    bool eraseUfm();
    bool readUfmPages(int numPages, uint8_t *p);
    bool readUfmPages(int pageNumber, int numPages, uint8_t *p);
    bool writeUfmPages(int pageNumber, int numPages, uint8_t *p);

    bool getBusyFlag(int *pFlag);
    bool waitUntilNotBusy(int maxLoops=DEFAULT_BUSY_LOOPS);

    bool setUsercode(uint8_t* p);
    bool getUsercode(uint8_t* p);

    bool mcpWrite(uint8_t* p, int len);
    bool mcpRead(int reg, uint8_t* v);

    //---------------------
    bool appRead(uint8_t *p, int AnumBytes);
    bool appWrite(uint8_t *p, int AnumBytes);

    Tpif();
    ~Tpif();
  };

#endif
// EOF ----------------------------------------------------------------
