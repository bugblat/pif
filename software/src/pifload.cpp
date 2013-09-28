//---------------------------------------------------------------------
// pifload.cpp

using namespace std;

#include <string>

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "pifwrap.h"

extern const int g_iDataSize;
extern const unsigned char g_pucDataArray[];

#define CFG_PAGE_SIZE           16
#define UFM_PAGE_SIZE           16

static const int MICROSEC = 1000;              // nanosecs
static const int MILLISEC = 1000 * MICROSEC;   // nanosecs

//---------------------------------------------------------------------
static bool showDeviceID(pifHandle h) {
  uint32_t v = 0x12345678;
  bool res = pifGetDeviceIdCode(h, &v);
  printf("result=%d, ID code=%08x\n", res, v);
  return res;
  }

//---------------------------------------------------------------------
static bool showTraceID(pifHandle h) {
  uint8_t buff[8] = {1,2,3,4,5,6,7,8};
  bool res = pifGetTraceId(h, buff);
  printf("result=%d, Trace ID code= ", res);
  for (unsigned i=0; i<sizeof(buff); i++) {
    printf("%02x", buff[i]);
    switch(i) {
      case 3 : printf("_");  break;
      case 7 : printf("\n"); break;
      default: printf(".");  break;
      }
    }
  return res;
  }

//---------------------------------------------------------------------
static int mcp(pifHandle h) {
  uint8_t r = 0;
  pifMcpRead(h, 9, &r);
  return r;
  }

//---------------------------------------------------------------------
static int INITn(pifHandle h) {
  int r = mcp(h);
  return (r >> 6) & 1;
  }

//---------------------------------------------------------------------
static void showCfgStatus(pifHandle h) {
  uint32_t status=0;
  pifGetStatusReg(h, &status);

  /*printf("\n----------------------------");*/
  int init = INITn(h);
  printf("*** status = %8x, INITn = %d", status, init);

  string fcStatus;
  uint32_t errCode = (status >> 23) & 7;
  switch (errCode) {
    case 0: fcStatus = "No Error";      break;
    case 1: fcStatus = "ID ERR";        break;
    case 2: fcStatus = "CMD ERR";       break;
    case 3: fcStatus = "CRC ERR";       break;
    case 4: fcStatus = "Preamble ERR";  break;
    case 5: fcStatus = "Abort ERR";     break;
    case 6: fcStatus = "Overflow ERR";  break;
    case 7: fcStatus = "SDM EOF";       break;
    }
  printf("  Done=%d, CfgEna=%d, Busy=%d, Fail=%d, FlashCheck=%s\n",
            ((status >>  8) & 1),
            ((status >>  9) & 1),
            ((status >> 12) & 1),
            ((status >> 13) & 1), fcStatus.c_str());
  }

//---------------------------------------------------------------------
static int flipNybble(int nyb) {
  int x = nyb & 0xf;
  int v = ((x & (1<<0)) << 3) |
          ((x & (1<<1)) << 1) |
          ((x & (1<<2)) >> 1) |
          ((x & (1<<3)) >> 3);
  return v;
  }

//---------------------------------------------------------------------
static uint8_t flipByte(int x) {
  int lo = x & 0xf, hi = (x>>4), v = 0;
  v = flipNybble(hi) | (flipNybble(lo) << 4);
  return (uint8_t)v;
  }

//---------------------------------------------------------------------
static void configureXO2(pifHandle h) {
  int cfg_page_count = (g_iDataSize-1) / (CFG_PAGE_SIZE+1);
  cfg_page_count = 9212;

  printf("\n----------------------------\n");

  pifWaitUntilNotBusy(h, -1);

  pifDisableCfgInterface(h);
  showCfgStatus(h);
  pifEnableCfgInterfaceOffline(h);

  showCfgStatus(h);
  printf("erasing configuration memory..\n");
  pifEraseCfg(h);
  printf("erased..\n");

  pifInitCfgAddr(h);
  showCfgStatus(h);
  printf("programming configuration memory..\n"); // up to 2.2 secs in a -7000

  uint8_t frameData[CFG_PAGE_SIZE];
  for (int pageNum=0; pageNum<cfg_page_count; pageNum++) {
    uint8_t rawData[CFG_PAGE_SIZE];

    for (int i=0; i<CFG_PAGE_SIZE; i++) {
      int dataIx = 1                        // header byte
             + pageNum * (CFG_PAGE_SIZE+1)  // 16 bytes/frame + END_OF_FRAME
             + i;
      rawData[i] = (uint8_t)g_pucDataArray[dataIx];
      }
    for (int i=0; i<CFG_PAGE_SIZE; i++) {
//    frameData[i] = flipByte(rawData[CFG_PAGE_SIZE-1-i]); // FlashCheck 'Preamble ERR'
//    frameData[i] = flipByte(rawData[i]);           // no FlashCheck error but doesn't generate a 'done'
      frameData[i] =          rawData[i] ;           // FlashCheck 'CMD ERR'
      }

    pifProgCfgPage(h, frameData);

    if (((pageNum+1) % 20)==0)
      printf(".");
    if (((pageNum+1) % 1000)==0)
      printf("\n");
    }
  printf("\n");

  showCfgStatus(h);
/*
  for (int i=0; i<CFG_PAGE_SIZE; i++)
    frameData[i] = 0xff;
  pifProgCfgPage(h, frameData);
  showCfgStatus(h);
*/

  printf("programmed. transferring..\n");
  pifProgDone(h);
  pifRefresh(h);

  pifDisableCfgInterface(h);
  showCfgStatus(h);
  printf("configuration done\n");
  }

//---------------------------------------------------------------------
int main() {
//setbuf(stdout, NULL);
  printf("\n================== loader =========================\n");
  char buff[200];
  pifVersion(buff, sizeof(buff));
  printf("%s\n", buff);

  pifHandle h = NULL;
  h = pifInit();
//printf("handle=%x\n", (unsigned)h);
  if (h) {
    showDeviceID(h);
    showTraceID(h);
    //  showUsercode(h);
    configureXO2(h);

    pifClose(h);
    }

  printf("==================== bye ==========================\n");
  return 0;
  }

// EOF ----------------------------------------------------------------
