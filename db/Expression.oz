%%
%% The language used in WHERE and HAVING clauses.
%%
%% Example:
%%  {Eval [['NOT' [6 'BETWEEN' 5#8]] 'AND' [t(a) '<' 3]] env(t:scope(a:2))}
%%
functor
import
   Comparison
export
   Is
   Eval
   ReferencedVars
   ReferencedScopes
   IsVar
   GetVarScope
   GetVarName
   NewVar
   MapVars
   IsLiteral
define
   fun {Is X}
      case X of [Operator Operand] andthen {IsUnaryOperator Operator} then
	 {IsOperand Operand}
      [] [O1 Op O2] andthen {IsBinaryOperator Op} then
	 {IsOperand O1} andthen {IsOperand O2}
      else false
      end
   end

   UnaryOperators =
   unit('NOT':Bool.'not')
   
   fun {IsUnaryOperator X} {IsAtom X} andthen {HasFeature UnaryOperators X} end

   BinaryOperators =
   unit('=':Value.'=='
	'>':Comparison.'>'
	'<':Comparison.'<'
	'>=':Comparison.'>='
	'<=':Comparison.'=<'
	'<>':Value.'\\='
	'AND':Bool.'and'
	'OR':Bool.'or'
	'BETWEEN':fun {$ X Y1#Y2} X >= Y1 andthen X =< Y2 end
	'IN':Member
       )

   fun {IsBinaryOperator X} {IsAtom X} andthen {HasFeature BinaryOperators X} end

   fun {IsOperand X}
      {IsVar X} orelse {IsLiteral X} orelse {Is X}
   end

   fun {IsPair X}
      case X of _#_ then true
      else false
      end
   end
   
   fun {IsLiteral X}
      {IsBool X} orelse
      {IsNumber X} orelse
      {IsAtom X} orelse
      {IsString X} orelse
      {IsPair X} andthen {Record.all X IsLiteral} orelse
      {IsList X} andthen {All X IsLiteral}
   end

   fun {IsVar L}
      {IsRecord L} andthen {Arity L} == [1] andthen {IsAtom L.1}
   end

   fun {NewVar Scope VarName} Scope(VarName) end

   fun {Eval C Env}
      case C of [Operator Operand] andthen {IsUnaryOperator Operator} then
	 {UnaryOperators.Operator {Eval Operand Env}}
      [] [Op1 Op Op2] andthen {IsBinaryOperator Op} then
	 {BinaryOperators.Op {Eval Op1 Env} {Eval Op2 Env}}
      elseif {IsVar C} then Env.{GetVarScope C}.{GetVarName C}
      else C
      end
   end

   fun {GetVarScope Var}
      {Label Var}
   end

   fun {GetVarName Var} Var.1 end

   fun {MapVars C Fun}
      case C of [Operator Operand] andthen {IsUnaryOperator Operator} then
	 [Operator {MapVars Operand Fun}]
      [] [Op1 Op Op2] andthen {IsBinaryOperator Op} then
	 [{MapVars Op1 Fun} Op {MapVars Op2 Fun}]
      elseif {IsVar C} then {Fun C}
      else C
      end
   end
   
   fun {ReferencedVars X}
      case X of [Operator Op] andthen {IsUnaryOperator Operator} then
	 {ReferencedVars Op}
      [] [Op1 Op Op2] andthen {IsBinaryOperator Op} then
	 {Append {ReferencedVars Op1} {ReferencedVars Op2}}
      elseif {IsVar X} then [X]
      else nil
      end
   end
   
   fun {ReferencedScopes X}
      Scopes = {NewDictionary}
   in
      for V in {ReferencedVars X} do Scopes.{GetVarScope V} := unit end
      {Dictionary.items Scopes}
   end
end
