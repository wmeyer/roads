
functor
import
   System OS
   Boot at 'x-oz://boot/Boot'
   Resolve
   Property
   Pickle %% just to enter it
   Module %% dito
export
   'class':EagerModuleManager
require
   URL(make:                    UrlMake
       resolve:                 UrlResolve
       toVirtualString:         UrlToVs
       toAtom:                  UrlToAtom
      )
   
   DefaultURL(ozScheme
	      functorExt:   FunctorExt
	      nameToUrl:    ModNameToUrl
              isNatLibName: IsNatSystemName)
prepare
   OzScheme = {VirtualString.toString DefaultURL.ozScheme}

   fun {IsNative Url}
      {HasFeature {CondSelect Url info info} 'native'}
   end

   NONE   = {NewName}
   LINK   = {NewName}
   APPLY  = {NewName}
   ENTER  = {NewName}
   LOAD   = {NewName}
   SYSTEM = {NewName}
   NOTYPE = {NewName}

   proc {TraceOFF _ _}
      skip
   end

   class UnsitedBaseManager
      prop locking
      feat ModuleMap TypeCheckProc

      meth init(TypeChecker <= unit)
	 self.ModuleMap = {Dictionary.new}
	 self.TypeCheckProc = TypeChecker
      end

      meth !LINK(Url ExpectedType ?Entry ?Module)
	 %% Return module from "Url"
	 lock Key={UrlToAtom Url} ModMap=self.ModuleMap in
	    if {Dictionary.member ModMap Key} then
	       {self trace('link [found]' Url)}
	    else
	       %% MODIFIED HERE
	       NewF
	    in
	       {self trace('link [lazy]' Url)}
	       {Dictionary.put ModMap Key NewF}
	       NewF = if {CondSelect Url scheme unit}==OzScheme
		      then {self SYSTEM(Url $)}
		      else {self LOAD(  Url $)}
		      end
	    end
	    Entry  = {Dictionary.get ModMap Key}
	    Module =
	    if self.TypeCheckProc==unit then
	       Entry.1
	    else
	       case Entry of Module#ActualType then
		  case ExpectedType of !NOTYPE then Module
		  elsecase ActualType of !NOTYPE then Module
		  elsecase {Procedure.arity self.TypeCheckProc}
		  of 3 andthen
		     {self.TypeCheckProc ActualType ExpectedType}
		  then Module
		  [] 4 andthen
		     {self.TypeCheckProc
		      ActualType ExpectedType o(url: Key)} == ok
		  then Module
		  else
		     {Value.failed
		      system(module(typeMismatch Key
				    ActualType ExpectedType))}
		  end
	       end
	    end
	 end
      end

      meth !APPLY(Url Func $)
	 {self trace('apply' Url)}
	 %% Applies a functor and returns a module
	 IM={Record.mapInd Func.'import'
	     fun {$ ModName Info}
		EmbedUrl = if {HasFeature Info 'from'} then
			      {UrlMake Info.'from'}
			   else
			      {ModNameToUrl ModName}
			   end
	     in
		UnsitedBaseManager,LINK({UrlResolve Url EmbedUrl}
					{CondSelect Info 'type' NOTYPE} _ $)
	     end}
      in
	 {Func.apply IM}
      end

      meth !ENTER(Url Module ActualType)
	 {self trace('enter' Url)}
	 %% Stores "Module" under "Url"
	 lock Key={UrlToAtom Url} in
	    if {Dictionary.member self.ModuleMap Key} then
	       raise system(module(alreadyInstalled Key)) end
	    else
	       {Dictionary.put self.ModuleMap Key Module#ActualType}
	    end
	 end
      end

   end

define

   fun {NameOrUrlToUrl ModName UrlV}
      {Resolve.expand
       if UrlV==NONE then {ModNameToUrl ModName}
       else {UrlMake UrlV}
       end}
   end

   class BaseManager from UnsitedBaseManager

      meth link(name: ModName      <= NONE
		url:  UrlV         <= NONE
		type: ExpectedType <= NOTYPE
		?Module            <= _) = Message
	 Url = {NameOrUrlToUrl ModName UrlV}
      in
	 Module = UnsitedBaseManager,LINK(Url ExpectedType _ $)
	 if {Not {HasFeature Message 1}} then
	    thread try {Wait Module} catch _ then skip end end
	 end
      end

      meth enter(name: ModName    <= NONE
		 url:  UrlV       <= NONE
		 type: ActualType <= NOTYPE
		 Module)
	 Url = {NameOrUrlToUrl ModName UrlV}
      in
	 UnsitedBaseManager,ENTER(Url Module ActualType)
      end

      meth apply(name: ModName <= NONE
		 url:  UrlV    <= NONE
		 Func
		 ?Module       <= _) = Message
	 Url = if ModName==NONE andthen UrlV==NONE then
		  {UrlMake {OS.getCWD}#'/'}
	       else
		  {NameOrUrlToUrl ModName UrlV}
	       end
      in
	 Module = UnsitedBaseManager,APPLY(Url Func $)
	 if {Not {HasFeature Message 2}} then
	    thread try {Wait Module} catch _ then skip end end
	 end
      end

   end

   proc {TraceON X1 X2}
      {System.printError 'Module manager: '#X1#' '#{UrlToVs X2}#'\n'}
   end

   Trace = {NewCell
	    if {OS.getEnv 'OZ_TRACE_MODULE'}==false
	    then TraceOFF else TraceON end}

   PLATFORM = {Property.get 'platform.name'}

   class RootManager from BaseManager

      meth trace(M1 M2)
	 {{Access Trace} M1 M2}
      end

      meth !LOAD(Url $)
	 %% Takes a URL and returns a module
	 %% check if URL is annotated as denoting a `native functor'
	 if {IsNative Url} then
	    %% if yes, use the Foreign loader
	    {self Native(Url $)}
	 else
	    {self Pickle(Url Url $)}
	 end
      end

      meth Native(Url $)
	 {self trace('native module' Url)}
	 %% note that this method will not attempt to
	 %% localize. A derived class could redefine it
	 %% to attempt localization.
	 try
	    {Resolve.native.native {UrlToVs Url}#'-'#PLATFORM}#NOTYPE
	 catch system(foreign(dlOpen _) ...) then
	    raise system(module(notFound native {UrlToAtom Url})) end
	 [] error(url(_ _) ...) then
	    raise system(module(notFound native {UrlToAtom Url})) end
	 end
      end

      meth Pickle(Url ResUrl $) Func in
	 try
	    Func = {Resolve.pickle.load ResUrl}
	 catch error(url(O _) ...) then
	    raise system(module(notFound O {UrlToAtom Url})) end
	 end
	 {self APPLY(Url Func $)}#Func.'export'
      end

      meth SystemResolve(Auth Url $)
	 if Auth==boot orelse {IsNative Url} then Url
	 elsecase {Reverse {CondSelect Url path nil}}
	 of H|T then
	    if {Member &. H} then Url
	    else {AdjoinAt Url path
		  {Reverse {VirtualString.toString H#FunctorExt}|T}}
	    end
	 end
      end

      meth SystemApply(Auth Url $)
	 U = {self SystemResolve(Auth Url $)}
      in
	 if {IsNative U} then
	    {self Native(U $)}
	 else
	    {self Pickle(U U $)}
	 end
      end

      meth GetSystemName(Url IsBoot $)
	 case {CondSelect Url path unit}
	 of [Name] then
	    %% drop the extension of any
	    {String.token Name &. $ _}
	 elseif IsBoot then
	    raise error(module(urlSyntax {UrlToAtom Url})) end
	 else unit
	 end
      end

      meth GetSystemBoot(Name $)
	 {self trace('boot module' Name)}
	 {Boot.getInternal Name}#NOTYPE
      end

      meth !SYSTEM(Url0 $)
	 Auth Url
      in
	 try
	    Auth = {StringToAtom {CondSelect Url0 authority ""}}
	    Url  = {self SystemResolve(Auth Url0 $)}
	 catch _ then
	    raise error(module(urlSyntax {UrlToAtom Url0})) end
	 end
	 {self trace('system method' Url)}
	 if {IsNative Url} then {self Native(Url $)}
	 elsecase {StringToAtom {CondSelect Url authority ""}}
	 of boot then
	    %% a boot module may either be provided internally
	    %% (i.e. statically linked in) or as a DLL
	    {self trace('boot module' Url)}
	    try {self GetSystemBoot({self GetSystemName(Url true $)} $)}
	    catch _ then
	       {self Native({UrlMake {UrlToAtom Url}#'.so{native}'} $)}
	    end
	 [] system then Name={self GetSystemName(Url false $)} in
	    {self trace('system module' Url)}
	    if Name \= unit andthen {IsNatSystemName Name} then
	       RootManager,SYSTEM({UrlMake OzScheme#'://boot/'#Name} $)
	    else
	       {self Pickle(Url Url $)}
	    end
	 [] contrib then
	    {self trace('contrib module' Url)}
	    {self Pickle(Url Url $)}
	 else
	    raise error(module(urlSyntax {UrlToAtom Url})) end
	 end
      end

   end

   RM = {New RootManager init}
   
   %% Register volatile system modules
   {RM enter(url:'x-oz://system/OS.ozf'       OS)}
   {RM enter(url:'x-oz://system/Property.ozf' Property)}
   {RM enter(url:'x-oz://system/Pickle.ozf'   Pickle)}
   {RM enter(url:'x-oz://system/System.ozf'   System)}
   {RM enter(url:'x-oz://system/Resolve.ozf'  Resolve)}
   {RM enter(url:'x-oz://system/Module.ozf'   Module)}

   class EagerModuleManager
      from RootManager
      prop sited

      meth !SYSTEM(Url $)
	 {RM LINK(Url NOTYPE $ _)}
      end

   end
end
