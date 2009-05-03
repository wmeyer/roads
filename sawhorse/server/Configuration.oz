%%
%% Sawhorse configuration file (to be compiled with ozc).
%%
functor
export
   Config
define
   Config = config(port:8080
		   requestTimeout: 300
		   keepAliveTimeout: 15
		   acceptTimeOut: 2*60*1000
		   documentRoot: "x-ozlib://wmeyer/sawhorse/public_html"
		   directoryIndex: "index.html"
		   serverName: "localhost"
		   serverAlias: nil
		   typesConfig: "x-ozlib://wmeyer/sawhorse/mime.types"
		   defaultType: mimeType(text plain)
		   mimeTypes: mimeTypes
		   serverAdmin: "admin@localhost"
		   logDir: "x-ozlib://wmeyer/sawhorse/sawhorse-log"
		   accessLogFile: "http-access.log"
		   accessLogLevel: trace
		   errorLogFile: stdout
		   errorLogLevel: trace
		   pluginDir: "x-ozlib://wmeyer/sawhorse/plugins"
		   plugins: unit
		  )
end
