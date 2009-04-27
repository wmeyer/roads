functor
import
   Util at 'x-ozlib://wmeyer/sawhorse/common/Util.ozf'
   IdIssuer(create) at 'x-ozlib://wmeyer/sawhorse/pluginSupport/IdIssuer.ozf'
   Open
   OS
   System
   Resolve
export
   Check
   Checked
   Convert
   ConvertAndCheck
   SetExecutable
   SetOptions
define
   %% returns true iff the given JavaScript code does not produce any JSLint errors;
   %% outputs to stdout
   fun {Check JS}
      TmpFN = {TmpFileName}
      {WriteInto TmpFN "/*jslint "#@JSLintOptions#" */"#JS}
      Res = {OS.system @JSLint#TmpFN} == 0
   in
      {OS.unlink TmpFN}
      Res
   end

   %% Set executable to use to call JSLint. The filename containing the input
   %% will simply be appended.
   proc {SetExecutable EXE}
      JSLint := EXE
   end

   %% Set options to use for JSLint.
   %% E.g. "nomen: true, debug: true, evil: false, onevar: true".
   proc {SetOptions OPTS}
      JSLintOptions := OPTS
   end

   %% Convert JS-code represented as an Oz list to real JS source code as a string.
   fun {Convert Xs}
      {VirtualString.toString {VSMap Xs fun {$ X} {TransformJS X 0} end}}
   end

   %% 
   fun {ConvertAndCheck Xs}
      {Checked {Convert Xs}}
   end

   fun {Checked JS}
      JSS = if {VirtualString.is JS} then JS
	    else {Util.intercalate JS "\n"}
	    end
   in
      if {Not {Check JSS}} then
	 {System.showInfo "JavaScript validation FAILED."}
	 raise javascript(validationFailed) end
      end
      JSS
   end
   
   %% private
   
   IsWindows = {List.isPrefix "win" {OS.uName}.sysname}
   JSLint = {NewCell ""}
   if IsWindows then
      JSLINTJS = {Resolve.localize "x-ozlib://wmeyer/javascript/jslint_wsh.js"}.1
   in
      JSLint := {VirtualString.toString "cscript.exe //B \""#JSLINTJS#"\" <"}
   else
      JSLINTJS = {Resolve.localize "x-ozlib://wmeyer/javascript/jslint_rhino.js"}.1
   in
      JSLint := {VirtualString.toString
		 "java org.mozilla.javascript.tools.shell.Main \""#JSLINTJS#"\" "}
   end

   JSLintOptions = {NewCell nil}

   TmpIdIssuer = {IdIssuer.create 4}
   fun {TmpFileName}
      {VirtualString.toString "tmpfile"#{TmpIdIssuer}#".js"}
   end
   
   proc {WriteInto FN T}
      F = {New class $ from Open.file Open.text end
	   init(name:FN flags:[write create truncate])}
   in
      {F write(vs:T)}
      {F close}
   end
   
   fun {StripSingleQuotes Xs}
      case Xs of &'|Xr then {List.take Xr {Length Xr}-1}
      else Xs
      end
   end

   fun {AtomToJS X}
      {StripSingleQuotes {Atom.toString X}}
   end
   
   fun {TupleToJS L R I}
      {AtomToJS L}#"("#{Util.intercalate
			{Map {Record.toList R}
			 fun {$ E} {VirtualString.toString {TransformJS E I+1}} end}
			" "}
      #")"
   end

   fun {VSMap Xs F}
      {List.toTuple '#' {Map Xs F}}
   end

   fun {Spaces I}
      case I of 0 then nil
      else 32|{Spaces I-1}
      end
   end

   fun {ObjectToJS X I}
      "{"#
      {Util.intercalate
       {Map {Record.toListInd X}
	fun {$ Ind#V}
	   {VirtualString.toString
	    {AtomToJS Ind}#": "#{TransformJS V I+3}}
	end
       }
       ", "
      }#
      " }"
   end
   
   fun {ArrayToJS X I}
      "{"#
      {Util.intercalate
       {Map {Record.toList X}
	fun {$ V}
	   {VirtualString.toString
	    {TransformJS V I+3}}
	end
       }
       ", "
      }#
      " }"
   end

   fun {TransformJS X I}
      case X of '#'(...) then {Util.intercalate
			       {Map {Record.toList X}
				 fun {$ Z}
				    {VirtualString.toString {TransformJS Z I}}
				 end
				}
			       "."}
      [] Y|_ then
	 if {Char.is Y} then "\""#X#"\" "
	 else "{\n"#{Spaces I+1}#{VSMap X fun {$ Z} {TransformJS Z I+1} end}
	    #"\n"#{Spaces I}#"}\n"
	 end
      [] ';' then "; "
      [] function then "function "
      [] object(...) then {ObjectToJS X I}
      [] array(...) then {ArrayToJS X I}
      elseif {Atom.is X} then {AtomToJS X}#" "
      elseif {Number.is X} then X
      elseif {Tuple.is X} then
	 if {Arity X} == [1] andthen X.1 == nil then {AtomToJS {Label X}}#"()"
	 else {TupleToJS {Label X} X I}
	 end
      end
   end
end