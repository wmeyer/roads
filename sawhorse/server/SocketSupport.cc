//
// This module does nothing on Windows. Using SO_REUSEADDR is not necessary there,
// and getting it to link on Windows is difficult...
//
#include "mozart.h"
#ifndef WIN32
#include <sys/socket.h>
#endif


OZ_BI_define(set_reuse_addr,1,0)
{
  OZ_declareInt(1, socket);
#ifndef WIN32
  int reuse_addr = 1;
  setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, (void*)&reuse_addr, sizeof(reuse_addr));
#endif
  return OZ_ENTAILED;
}
OZ_BI_end

OZ_C_proc_interface * oz_init_module(void)
{
  static OZ_C_proc_interface table[] = {
    {"set_reuse_addr",1,0,set_reuse_addr},
    {0,0,0,0}
  };
  return table;
}
