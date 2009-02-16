#include "mozart.h"
#include <map>

typedef std::map<int, OZ_Term> TermMap;


OZ_BI_define(newMap,0,1)
{
  OZ_Term res = OZ_makeForeignPointer((void*)new TermMap);
  OZ_RETURN(res);
}
OZ_BI_end

OZ_BI_define(deleteMap,1,0)
{
  OZ_declareTerm(0, theMap);
  TermMap* termMap = (TermMap*) OZ_getForeignPointer(theMap);
  for(TermMap::iterator it = termMap->begin(); it != termMap->end(); ++it)
    {
      OZ_unprotect(&(*termMap)[it->first]);
    }
  delete termMap;
  return OZ_ENTAILED;
}
OZ_BI_end

OZ_BI_define(removeAll,1,0)
{
  OZ_declareTerm(0, theMap);
  TermMap* termMap = (TermMap*) OZ_getForeignPointer(theMap);
  for(TermMap::iterator it = termMap->begin(); it != termMap->end();)
    {
      TermMap::iterator thisIt = it;
      ++it;
      OZ_unprotect(&(*termMap)[thisIt->first]);
      termMap->erase(thisIt);
    }
  return OZ_ENTAILED;
}
OZ_BI_end

OZ_BI_define(put,3,0)
{
  OZ_declareTerm(0, theMap);
  OZ_declareInt(1, key);
  OZ_declareTerm(2, term);
  TermMap* termMap = (TermMap*) OZ_getForeignPointer(theMap);
  TermMap::iterator it = termMap->find(key);
  if( it != termMap->end() )
    {
      OZ_unprotect(&(*termMap)[it->first]);
    }
  (*termMap)[key] = term;
  OZ_protect(&(*termMap)[key]);
  return OZ_ENTAILED;
}
OZ_BI_end

OZ_BI_define(get,2,1)
{
  OZ_declareTerm(0, theMap);
  OZ_declareInt(1, key);
  TermMap* termMap = (TermMap*) OZ_getForeignPointer(theMap);
  TermMap::const_iterator it = termMap->find(key);
  if( it != termMap->end() ) {
    OZ_RETURN(it->second);
  }
  else {
    OZ_RETURN( OZ_raiseC( "keyNotFound", 0 ) );
  }
}
OZ_BI_end

OZ_BI_define(condGet,3,1)
{
  OZ_declareTerm(0, theMap);
  OZ_declareInt(1, key);
  OZ_declareTerm(2, defVal);
  TermMap* termMap = (TermMap*) OZ_getForeignPointer(theMap);
  TermMap::const_iterator it = termMap->find(key);
  if( it != termMap->end() ) {
    OZ_RETURN(it->second);
  }
  else {
    OZ_RETURN( defVal );
  }
}
OZ_BI_end

OZ_BI_define(member,2,1)
{
  OZ_declareTerm(0, theMap);
  OZ_declareInt(1, key);
  TermMap* termMap = (TermMap*) OZ_getForeignPointer(theMap);
  TermMap::const_iterator it = termMap->find(key);
  OZ_RETURN_BOOL(it != termMap->end());
}
OZ_BI_end


OZ_BI_define(map_remove,2,0)
{
  OZ_declareTerm(0, theMap);
  OZ_declareInt(1, key);
  TermMap* termMap = (TermMap*) OZ_getForeignPointer(theMap);
  TermMap::iterator it = termMap->find(key);
  if( it != termMap->end() ) {
    OZ_unprotect(&(*termMap)[it->first]);
    termMap->erase(it);
  }
  return OZ_ENTAILED;
}
OZ_BI_end

OZ_BI_define(items,1,1)
{
  OZ_declareTerm(0, theMap);
  TermMap* termMap = (TermMap*) OZ_getForeignPointer(theMap);
  size_t numElements = termMap->size();
  OZ_Term* asArray = new OZ_Term[numElements];
  size_t i = 0;
  for(TermMap::iterator it = termMap->begin(); it != termMap->end(); ++it)
    {
      asArray[i] = it->second;
      ++i;
    }
  OZ_Term result = OZ_toList(numElements, asArray);
  delete [] asArray;
  OZ_RETURN(result);
}
OZ_BI_end

OZ_C_proc_interface * oz_init_module(void)
{
  static OZ_C_proc_interface table[] = {
    {"new",0,1,newMap},
    {"put",3,0,put},
    {"get",2,1,get},
    {"condGet",3,1,condGet},
    {"member",2,1,member},
    {"remove",2,0,map_remove},
    {"removeAll",1,0,removeAll},
    {"delete",1,0,deleteMap},
    {"items",1,1,items},
    {0,0,0,0}
  };
  return table;
}
