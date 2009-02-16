functor
export
   DivList
   DivMap
   DivMapInd
define
   fun {DivList Xs}
      {List.toTuple 'div' Xs}
   end
   fun {DivMap Xs F}
      {DivList
       {Map Xs F}
      }
   end
   fun {DivMapInd Xs F}
      {DivList
       {List.mapInd Xs F}
      }
   end
end