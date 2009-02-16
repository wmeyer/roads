functor
import
   Util(intercalate:Intercalate) at 'x-ozlib://wmeyer/sawhorse/common/Util.ozf'
export
   GetApplication
   GetFunctor
   GetFunction
   AnalyzePath
   BuildPath
   StartsWith
define
   SpecialFunctions = [before after]
   
   fun {StartsWith Xs Y ?Zs}
      if Y == '' then Zs = Xs true
      elseif Xs \= nil andthen {Atom.toString Y} == Xs.1 then
	 Zs = Xs.2 true
      else
	 false
      end
   end

   fun {GetApplication State Path}
      App in
      if {AnalyzePath State Path _ ?App _ _ _} then
	 just(App)
      else
	 nothing
      end
   end
   
   fun {GetFunctor State Path}
      Functor in
      if {AnalyzePath State Path _ _ ?Functor _ _} then
	 just(Functor)
      else
	 nothing
      end
   end
   
   fun {GetFunction State Path}
      Fun in
      if {AnalyzePath State Path _ _ _ ?Fun _} then
	 just(Fun)
      else
	 nothing
      end
   end

   fun {BuildPath Xs}
      &/|{Intercalate {Filter {Map Xs Atom.toString} fun {$ X} X \= nil end} "/"}
   end

   fun {ToCandidates Rec}
      {Sort
       {Record.toListInd Rec}
       fun {$ F1#_ _#_}
	  F1 \= ''
       end
      }
   end
   
   %% Path: [string]
   %% The return parameters will only be bound if return is true.
   %% Components: unit(app:atom functor:atom function:atom basePath:string)
   %% ClosureId: Maybe string
   fun {AnalyzePath State Path ?Components ?AppR ?FunctorR ?FunctionR ?ClosureId}
      for AppPath#App in {ToCandidates State.applications} return:R default:false do
	 RemPath in
	 if {StartsWith Path AppPath ?RemPath} then
	    for FunctorPath#Functor in {ToCandidates App.functors} do
	       RemPath2 in
	       if {StartsWith RemPath FunctorPath ?RemPath2} then
		  for FunPath#Fun in
		      {ToCandidates {Record.subtractList Functor SpecialFunctions}}
		  do
		     RemPath3 in
		     if {StartsWith RemPath2 FunPath ?RemPath3} then
			ComponentsCandidate =
			unit(app:AppPath 'functor':FunctorPath
			     function:FunPath
			     basePath:{BuildPath [AppPath FunctorPath FunPath]}
			    )
			RemPath4 = if RemPath3 == nil then nil
				   elseif {List.last RemPath3} == nil then
				      {List.take RemPath3 {Length RemPath3}-1}
				   else RemPath3
				   end
		     in
			case RemPath4 of nil then
			   ClosureId = nothing
			   Components = ComponentsCandidate
			   AppR = App
			   FunctorR = Functor
			   FunctionR = Fun
			   {R true}
			[] [ClId] then
			   ClosureId = just(ClId)
			   Components = ComponentsCandidate
			   AppR = App
			   FunctorR = Functor
			   FunctionR = Fun
			   {R true}
			end
		     end
		  end
	       end
	    end
	 end
      end
   end
end
