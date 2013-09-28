// llbufs.h ----------------------------------------------------------
//
// Copyright (c) 2001 to 2013  te
//
// Licence: Creative Commons Attribution-ShareAlike 3.0 Unported License.
//          http://creativecommons.org/licenses/by-sa/3.0/
//---------------------------------------------------------------------
#ifndef llbufsH
#define llbufsH

#include <stdint.h>
#include <memory.h>
#include <assert.h>

//---------------------------------------------------------------------
#define LL_WR_BUFF_SIZE       64        /* CFG_PAGE_SIZE is 16 bytes */
class TllWrBuf {
  private:
    uint8_t Fbuf[LL_WR_BUFF_SIZE];
    int     Flen;

  public:
    TllWrBuf(int v) { clear(); byte(v); }
    TllWrBuf()      { clear(); }

    TllWrBuf& clear() {
      Flen = 0;
      memset(Fbuf, 0, sizeof(Fbuf));
      return *this;
      }
    TllWrBuf& byte(int v) {
      assert(Flen < LL_WR_BUFF_SIZE);
      Fbuf[Flen] = (uint8_t)v;
      Flen++;
      return *this;
      }
    TllWrBuf& wordLE(int v) {
      uint32_t x = v;
      byte(x);
      byte(x >> 8);
      return *this;
      }
    TllWrBuf& wordBE(int v) {
      uint32_t x = v;
      byte(x >> 8);
      byte(x);
      return *this;
      }
    TllWrBuf& dwordLE(int v) {
      uint32_t x = v;
      wordLE(x);
      wordLE(x >> 16);
      return *this;
      }
    TllWrBuf& dwordBE(int v) {
      uint32_t x = v;
      wordBE(x >> 16);
      wordBE(x);
      return *this;
      }

    uint8_t *data() { return Fbuf; }
    int     length(){ return Flen; }
  };
#undef LL_WR_BUFF_SIZE

#endif
// EOF ----------------------------------------------------------------
