% Logging procedures.
%
% A Stream represents a file that receive log messages.
% It can be used by n Loggers.
% It can have an archiver that is called if the logfile has become too big.
% By default, the file is simply truncated.			   
%
% A Logger decorates log messages, filters unwanted messages
%%and sends the rest to its stream.
% By default, a logger sends its messages to the default stream (which is stderr by default)
% and filters all messages except errors.			   
functor
import
   Open(file:File text:TextFile)
   Property
   OS
   Error
export
   NewStream
   SetStreamPath
   
   SetDefaultLogLevel
   SetDefaultStream
   SetDefaultLogFile
   
   NewLogger
   RenamingArchiver
define
   IsWin = {Map {List.take {OS.uName}.sysname 3} Char.toLower} == "win"
   
   %% FileName: stdout, stderr or any filename
   %% maxSize: Maximum size of the current logfile in KB.
   %% archiver: a unary procedure that is called whenever the file has become
   %%           larger than that (afterwards the old file is deleted)
   %% dir: directory (default: current working directory)
   %% The result is simply a procedure to call with a value.
   %% It will return only when the message has been completely written.
   fun {NewStream I=init(IFileName ...)}
      Directory = {NewCell {CondSelect I dir "./"}}
      FileName = {NewCell IFileName}
      MaxSize = {CondSelect I maxSize unit}
      Archiver = {CondSelect I archiver proc {$ _} skip end}

      fun {IsStdIo}
	 {IsAtom @FileName}
      end
      
      fun {FullPath}
	 if {IsStdIo} then @FileName else {BuildPath @Directory @FileName} end
      end
      
      fun {OpenFile WithMode}
	 {New class $ from Open.file Open.text end
	  init(name:{FullPath}
	       flags:[create write text WithMode])
	 }
      end

      proc {Log Val}
	 TooBig
	 File = {OpenFile append}
      in
	 {File putS(Val)}
	 TooBig = MaxSize \= unit andthen {File tell(offset:$)} > MaxSize*1024
	 if {Not IsWin} orelse {Not {IsStdIo}} then
	    {File close}
	 end
	 if {Not {IsStdIo}} then
	    if TooBig then
	       {Archiver @Directory @FileName}
	       {{OpenFile truncate} close}
	    end
	 end
      end

      Stream
      P = {NewPort Stream}
      thread
	 for V#Sync in Stream do
	    case V of setPath#(D#F) then
	       Directory := D
	       FileName := F
	    else
	       {Log V}
	    end
	    Sync = unit
	 end
      end
   in
      proc {$ Val}
	 {Wait {Port.sendRecv P Val}}
      end
   end

   fun {BuildPath Dir FileName}
      LastDir = {Nth Dir {Length Dir}}
   in
      if LastDir == &/ orelse LastDir == &\\ then
	 {Append Dir FileName}
      else
	 {Append Dir &/|FileName}
      end
   end

   proc {SetStreamPath Stream Directory FileName}
      {Stream setPath#(Directory#FileName)}
   end
   
   %% ARCHIVER
   local
      proc {SplitFileName FileName ?BaseName ?Extension}
	 fun {PosOf Xs Y}
	    case Xs of X|Xr then
	       if X == Y then 1
	       else 1+{PosOf Xr Y}
	       end
	    else
	       1 % behind last
	    end
	 end
	 Tmp
      in
	 {List.takeDrop FileName {PosOf FileName &.}-1 BaseName Tmp}
	 Extension = if Tmp \= nil then Tmp.2 else nil end
      end
      
      fun {BuildFileName BaseName Extension}
	 {Append BaseName
	  if Extension \= nil then
	     &.|Extension
	  else
	     nil
	  end
	 }
      end
      fun {IsSuffix Xs Ys}
	 {List.isPrefix {Reverse Xs} {Reverse Ys}}
      end
   in
      fun {RenamingArchiver DaysToKeep}
	 SecondsToKeep = DaysToKeep*24*60*60
	 IsWindows = {List.isPrefix "win" {OS.uName}.sysname}
	 Move = if IsWindows then "MOVE" else "mv" end
	 Delete = if IsWindows then "DEL" else "rm" end
      in
	 proc {$ Dir FileName}
	    BaseName Extension
	    NewName
	 in
	    {SplitFileName FileName BaseName Extension}
	    %% rename file (with added timestamp)
	    NewName = {BuildFileName
		       {Append BaseName &_|{TimeStamp false}}
		       Extension}
	    {OS.system Move#" \""#FileName#"\" \""#NewName#"\"" _}
	    %% delete files that are too old
	    local
	       MyFiles = {Filter {OS.getDir Dir}
			  fun {$ F} {List.isPrefix BaseName F} andthen {IsSuffix Extension F} end
			 }
	       MyOldFiles = {Filter MyFiles
			     fun {$ F}
				MTime = {OS.stat {BuildPath Dir F}}.mtime
			     in
				{OS.time} - MTime > SecondsToKeep
			     end
			    }
	    in
	       for F in MyOldFiles do
		  {OS.system Delete#" \""#{BuildPath Dir F}#"\"" _}
	       end
	    end
	 end
      end
   end

   LevelValues = unit(nothing:0 error:1 debug:2 trace:3)

   %% Prefix used in decorated messages
   LevelNames = unit(~1:"A" 1:"E" 2:"D" 3:"T")
   

   %% The stream that will be used by new loggers by default.
   DefaultLogStream = {NewCell {NewStream init(stderr)}}
   proc {SetDefaultStream Stream}
      DefaultLogStream := Stream
   end

   proc {SetDefaultLogFile FileName}
      {SetDefaultStream {NewStream init(FileName)}}
   end
   
   %% The log level that will be used by new loggers by default.
   DefaultLogLevel = {NewCell LevelValues.error}
   local
      DefaultLogLevelSet = {NewCell false}
   in
      proc {SetDefaultLogLevel L}
	 if @DefaultLogLevelSet then
	    raise logging(triedToSetDefaultLogLevelMultipleTimes) end
	 end
	 DefaultLogLevel := LevelValues.L
	 DefaultLogLevelSet := true
      end
   end

   fun {TimeStamp Seps}
      T = {OS.localTime}
      Milli = {Property.get 'time.total'} mod 1000
      DateSep = if Seps then "-" else nil end
      DateTimeSep = if Seps then " " else nil end
      TimeSep = if Seps then ":" else nil end
      MilliSep = if Seps then "." else nil end
      fun {FormatInt I L}
	 S = {Int.toString I}
	 Prefix = {MakeList L-{Length S}}
      in
	 for P in Prefix do P = &0 end
	 {Append Prefix S}
      end
   in
      {VirtualString.toString
       (1900+T.year)#
       DateSep#{FormatInt 1+T.mon 2}#
       DateSep#{FormatInt 1+T.mDay 2}#
       DateTimeSep#{FormatInt T.hour 2}#
       TimeSep#{FormatInt T.min 2}#
       TimeSep#{FormatInt T.sec 2}#
       MilliSep#{FormatInt Milli 3}
      }
   end

   %% Create a new logger.
   %% Log messages will be prefixed by the current time, the message log level and the module name.
   %% module: a string that will be included in every message (if decorate is true)
   %% decorate: send plain messages if false
   %% stream: the stream to use
   %% logLevel:
   %%  nothing: a logger with that level will ignore all messages
   %%  error: to log errors
   %%  debug: to log debug output
   %%  trace: log everything
   fun {NewLogger Init=init(module:ModuleName ...)}
      Decorate = {CondSelect Init decorate true}
      MyName = if ModuleName \= nil then " ["#ModuleName#"] " else " " end
      Stream = {CondSelect Init stream unit}
      LogLevel = if {HasFeature Init logLevel} then
		    LevelValues.(Init.logLevel)
		 else unit end

      fun {GetLogLevel}
	 if LogLevel == unit then @DefaultLogLevel
	 else LogLevel
	 end
      end

      fun {GetStream}
	 if Stream == unit then @DefaultLogStream
	 else Stream
	 end
      end
      
      proc {Log L W}
	 if L =< {GetLogLevel} then
	    V = if {VirtualString.is W} then W else {Value.toVirtualString W 1000 1000} end
	    Message = if Decorate then
			 {TimeStamp true}#" "#LevelNames.L#MyName#V
		      else
			 V
		      end
	 in
	    {{GetStream} Message}
	 end
      end
   in
      unit(error:proc{$ V} {Log LevelValues.error V} end
	   exception:proc{$ E}
			{Log LevelValues.error
			 {Error.messageToVirtualString {Error.exceptionToMessage E}}}
		     end
	   debug:proc{$ V} {Log LevelValues.debug V} end
	   trace:proc{$ V} {Log LevelValues.trace V} end
	   t:fun {$ V} {Log LevelValues.trace V} V end
	  )
   end
end
