// pifwrap.h ----------------------------------------------------------
//
// Copyright (c) 2001 to 2013  te
//
// a C wrapper for the pif code
//
// Licence: Creative Commons Attribution-ShareAlike 3.0 Unported License.
//          http://creativecommons.org/licenses/by-sa/3.0/
//---------------------------------------------------------------------
#ifndef pifwrapH
#define pifwrapH

#include <stdint.h>

#if defined _WIN32 || defined __CYGWIN__
  #define PIF_DLL_IMPORT __declspec(dllimport)
  #define PIF_DLL_EXPORT __declspec(dllexport)
  #define PIF_DLL_LOCAL
#else
  #if __GNUC__ >= 4
    #define PIF_DLL_IMPORT __attribute__ ((visibility ("default")))
    #define PIF_DLL_EXPORT __attribute__ ((visibility ("default")))
    #define PIF_DLL_LOCAL  __attribute__ ((visibility ("hidden")))
  #else
    #define PIF_DLL_IMPORT
    #define PIF_DLL_EXPORT
    #define PIF_DLL_LOCAL
  #endif
#endif

// Add '-DBUILDING_LIBPIF' and '-fvisibility=hidden' to the makefile flags

#if BUILDING_LIBPIF // && HAVE_VISIBILITY
  #define PIF_API extern PIF_DLL_EXPORT
#else
  #define PIF_API extern
#endif

typedef void * pifHandle;

//---------------------------------------------------------------------
#ifdef __cplusplus
  extern "C" {
#endif
PIF_API int pifVersion(char *outStr, int outLen);

PIF_API int  pifGetDeviceIdCode(pifHandle h, uint32_t* v);

PIF_API int  pifGetStatusReg(pifHandle h, uint32_t* v);
PIF_API int  pifGetTraceId(pifHandle h, uint8_t* p);

PIF_API int  pifEnableCfgInterfaceOffline(pifHandle h);
PIF_API int  pifEnableCfgInterfaceTransparent(pifHandle h);
PIF_API int  pifDisableCfgInterface(pifHandle h);
PIF_API int  pifRefresh(pifHandle h);
PIF_API int  pifProgDone(pifHandle h);

PIF_API int  pifErase(pifHandle h, int Amask);
PIF_API int  pifEraseAll(pifHandle h);

PIF_API int  pifInitCfgAddr(pifHandle h);
PIF_API int  pifEraseCfg(pifHandle h);
PIF_API int  pifProgCfgPage(pifHandle h, const uint8_t *p);
PIF_API int  pifReadCfgPages(pifHandle h, int numPages, uint8_t *p);

PIF_API int  pifEraseUfm(pifHandle h);
PIF_API int  pifReadUfmPages(pifHandle h, int pageNumber, int numPages, uint8_t *p);
PIF_API int  pifWriteUfmPages(pifHandle h, int pageNumber, int numPages, uint8_t *p);

PIF_API int  pifGetBusyFlag(pifHandle h, int *pFlag);
PIF_API int  pifWaitUntilNotBusy(pifHandle h, int maxLoops);

PIF_API int  pifSetUsercode(pifHandle h, uint8_t* p);
PIF_API int  pifGetUsercode(pifHandle h, uint8_t* p);

//---------------------
PIF_API int  pifMcpWrite(pifHandle h, uint8_t* p, int len);
PIF_API int  pifMcpRead(pifHandle h, int reg, uint8_t* v);

//---------------------
PIF_API int  pifAppRead(pifHandle h, uint8_t *p, int AnumBytes);
PIF_API int  pifAppWrite(pifHandle h, uint8_t *p, int AnumBytes);

PIF_API pifHandle pifInit();
PIF_API void      pifClose(pifHandle h);

#ifdef __cplusplus
  }
#endif

#endif
// EOF ----------------------------------------------------------------
