functor
import
   Application
   Resolve OS System
define
   From = {Atom.toString {Resolve.localize 'x-ozlib://wmeyer/roads/Roads.plugin.ozf'}.1}
   To = {Atom.toString {Resolve.localize 'x-ozlib://wmeyer/sawhorse/plugins'}.1}
   Res = {OS.system "cp \""#From#"\" \""#To#"\""}
   if Res \= 0 then
      {System.showInfo "Error copying plugin."}
   end
   {Application.exit Res}
end
