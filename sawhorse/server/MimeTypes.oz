functor
import
   Regex at 'x-oz://contrib/regex'
   Util(lazyRead:LazyRead lines:Lines words:Words
	regexGroups:RegexGroups extension:Extension
	filterRecordsByLabel:FilterRecordsByLabel)
   at 'x-ozlib://wmeyer/sawhorse/common/Util.ozf'
export
   MimeTypeOf
   Init
define
   fun {MimeTypeOf Config Filename}
      case {Extension Filename}
      of nil then Config.defaultType
      [] Ext then {CondSelect Config.mimeTypes {StringToAtom Ext} Config.defaultType}
      end
   end

   fun {Init Filename}
      {ParseMimeTypes {LazyRead Filename}}
   end

   fun {StripComments L}
      {List.takeWhile L fun {$ C} C \= &# end}
   end
   
   fun {ParseMimeTypes Xs}
      TypesWithExtensions = {FilterRecordsByLabel just
			     {Map {Lines Xs}
			      fun {$ L} {ParseMimeLine {StripComments L}} end
			     }}
      D = {NewDictionary} %% we use a dictionary to remove duplicates
   in
      for just(Type#Exts) in TypesWithExtensions  do
	 for Ext in Exts do
	    D.{StringToAtom Ext} := Type
	 end
      end
      {Dictionary.toRecord mimeTypes D}
   end

   local
      MimeRegex = {Regex.make "^([^/]+)/([^ \t]+)[ \t]+(.*)$"}
   in
      fun {ParseMimeLine L}
	 case {RegexGroups MimeRegex L}
	 of group(1:Part1 2:Part2 3:Exts ...) then
	    just(mimeType({ByteString.toString Part1}
			  {ByteString.toString Part2})#
		 {Words {ByteString.toString Exts}})
	 else nothing
	 end
      end
   end
end
