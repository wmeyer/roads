#include "mozart.h"
#include "md5.h"
#include "md5.c"

OZ_BI_define(createHash,1,1)
{
  OZ_declareDetTerm(0,val);
  int len;
  char* cVal = OZ_stringToC(val, &len); // lifetime of cVal is managed by OZ_stringToC

  md5_state_s state;
  md5_init(&state);
  md5_append(&state, (const md5_byte_t*)cVal, len);
  md5_byte_t digest[16];
  md5_finish(&state, digest);
  OZ_Term result = OZ_string((char*)digest);
  OZ_RETURN(result);
}
OZ_BI_end
 
OZ_C_proc_interface * oz_init_module(void)
{
  static OZ_C_proc_interface table[] = {
    {"createHash",1,1,createHash},
    {0,0,0,0}
  };
  return table;
}
