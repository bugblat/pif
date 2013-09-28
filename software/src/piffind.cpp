//---------------------------------------------------------------------
// piffind.cpp

using namespace std;

#include <stdio.h>
#include <stdlib.h>
#include "pifwrap.h"

//---------------------------------------------------------------------
int main() {
  char buff[200];
  pifHandle h = NULL;
  printf("\n====================hello==========================");
  h = pifInit();
  printf("\nhandle=%x", (unsigned)h);

  pifVersion(buff, sizeof(buff));
  printf("\n%s", buff);

  if (h) {
    uint32_t v = 99;
    bool x = getDeviceIdCode(h, &v);
    printf("\nresult=%d, ID code=%x", x, v);

    pifClose(h);
    }
  printf("\n==================== bye ==========================\n");
  return 0;
  }

// EOF ----------------------------------------------------------------
