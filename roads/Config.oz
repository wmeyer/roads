functor
export
   Applications
   ExpireSessionsOnRestart
   SessionDuration
define
   Applications = unit(
		     'said':'x-ozlib://wmeyer/roads/examples/Said.ozf'
		     'examples':'x-ozlib://wmeyer/roads/examples/ExamplesApp.ozf'
		     'poll':'x-ozlib://wmeyer/pollapp/PollApp.ozf'
		      )
   ExpireSessionsOnRestart = true
   SessionDuration = 60*60*1000
end