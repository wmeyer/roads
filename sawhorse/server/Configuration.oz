%%
%% Sawhorse configuration file (to be compiled with ozc).
%%
functor
export
   Config
define
   Config = config(port:8081
		   requestTimeout: 300
		   keepAliveTimeout: 15
		   acceptTimeOut:2*60*1000
		   documentRoot: "public_html"
		   directoryIndex: "index.html"
		   serverName: "localhost"
		   serverAlias: nil
		   typesConfig: "./mime.types"
		   defaultType:mimeType(text plain)
		   mimeTypes:mimeTypes
		   serverAdmin:"admin@localhost"
		   logDir:"log"
		   accessLogFile:"http-access.log"
		   accessLogLevel:trace
		   errorLogFile:stdout
		   errorLogLevel:trace
		   pluginDir:"x-ozlib://wmeyer/sawhorse/plugins"
		   plugins:unit
		  )
end
