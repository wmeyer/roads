#include "mozart.h"

#ifdef WIN32
#include <windows.h>
#include <Wincrypt.h>
#else
#include <stdio.h>
#endif

#ifndef BYTE
#define BYTE unsigned char
#endif
 
OZ_BI_define(create_generator,0,1)
{
#ifdef WIN32
  HCRYPTPROV   hCryptProv;
  if (!CryptAcquireContext(&hCryptProv, NULL, NULL, PROV_RSA_FULL, 0)){
    if (GetLastError() == NTE_BAD_KEYSET){	  
      CryptAcquireContext(&hCryptProv, NULL, NULL, PROV_RSA_FULL, CRYPT_DELETEKEYSET);
      if (!CryptAcquireContext(&hCryptProv, NULL, NULL, PROV_RSA_FULL, CRYPT_NEWKEYSET)){
	OZ_RETURN_INT(0);
      }
    }
    else {
      OZ_RETURN_INT(0);
    }
  }
  OZ_RETURN( OZ_makeForeignPointer((void*)hCryptProv) );
#else
  FILE* fp = fopen("/dev/urandom","r");
  OZ_RETURN( OZ_makeForeignPointer((void*)fp) );
#endif
}
OZ_BI_end
 
OZ_BI_define(generate,2,1)
{
  OZ_declareTerm(0, contextT);
  OZ_declareInt(1, numBytes);
  BYTE* bytes = new BYTE[numBytes];
#ifdef WIN32
  HCRYPTPROV hCryptProv = (HCRYPTPROV) OZ_getForeignPointer(contextT);
  if (!CryptGenRandom(hCryptProv, numBytes, bytes))
    {
      delete [] bytes;
      OZ_RETURN( OZ_raiseC( "errorCallingCryptGenRandom", 0 ) );
    }
#else
  FILE *fp = (FILE*) OZ_getForeignPointer(contextT);
  for (unsigned int i=0; i < numBytes; ++i)
    {
      int f = fgetc(fp);
      if( f == EOF ) { --i; continue; }
      bytes[i] = f & 0xff;
    }
#endif
  OZ_Term* terms = new OZ_Term[numBytes];
  for(unsigned i = 0; i < numBytes; ++i )
    {
      terms[i] = OZ_int(bytes[i]);
    }
  delete [] bytes;
  OZ_Term result = OZ_toList(numBytes, terms);
  delete [] terms;
  OZ_RETURN(result);
}
OZ_BI_end

OZ_BI_define(close_generator,1,0)
{
  OZ_declareTerm(0, contextT);
#ifdef WIN32
  HCRYPTPROV hCryptProv = (HCRYPTPROV) OZ_getForeignPointer(contextT);
  CryptReleaseContext(hCryptProv, 0);
#else
  FILE *fp = (FILE*) OZ_getForeignPointer(contextT);
  fclose(fp);
#endif
}
OZ_BI_end

OZ_C_proc_interface * oz_init_module(void)
{
  static OZ_C_proc_interface table[] = {
    {"create_generator",0,1,create_generator},
    {"generate",2,1,generate},
    {"close_generator",1,0,close_generator},
    {0,0,0,0}
  };
  return table;
}
