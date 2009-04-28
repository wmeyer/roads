makefile(
   lib:['Cache.ozf' 'Cookie.ozf' 'IdIssuer.ozf' 'NonSituatedDictionary.ozf'
	'Random.o' 'Random.so' 'RandomNumberGenerator.ozf' 'RandomBytesGenerator.ozf'
	'md5oz.o' 'md5.so'
	'Map.o' 'Map.so' 'Map.ozf'
       ]
   rules:o('md5.so':ld('md5oz.o'))
   )
