makefile(
   lib : [
	  'App.ozf'
	  'AsyncExcept.ozf'
	  'Configuration.ozf'
	  'MimeTypes.ozf'
	  'Plugin.ozf'
	  'Server.ozf'
	  'Timeout.ozf'
	  'SocketSupport.o' 'SocketSupport.so'
	 ]
   rules:o('SocketSupport.so':ld('SocketSupport.o'))
   )