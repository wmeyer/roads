functor
import
   Server
   Open
   System
   Application
   Panel
   Property
define
   {System.showInfo "starting..."}
   
   S = {Server.start config}

   StdIn = {New class $ from Open.file Open.text end init(name:stdin flags:[read text])}

   fun lazy {StdInStream}
      case {StdIn getS($)} of false then nil
      [] X then X|{StdInStream}
      end
   end

   fun {StripCr Xs}
      case Xs of nil then nil
      elseif {List.last Xs} == 13 then {List.take Xs {Length Xs}-1}
      else Xs
      end
   end
   
   for Cmd in {StdInStream} do
      case {StripCr Cmd}
      of "restart" then {System.showInfo "Restarting server..."} {Server.restart S config}
      [] "shutdown" then {System.showInfo "Killing server..."}
	 {Server.kill S} {Application.exit 0}
      [] "panel" then {Panel.object open}
      [] "gc" then {System.showInfo "Executing garbage collection..."}
	 {System.gcDo} {System.showInfo "done"}
      [] "memory" then
	 {System.showInfo "Memory stats:"}
	 {System.showInfo "active: "#{Property.get 'gc.active'}}
	 {System.showInfo "size: "#{Property.get 'gc.size'}}
      [] "help" then {System.showInfo "Commands: restart shutdown panel gc memory help"}
      [] C then {System.showInfo "Unknown command: "#C}
      end
   end
end
