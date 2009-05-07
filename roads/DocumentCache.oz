functor
export
   'class':DocumentCache
define

   class DocumentCache
      attr cache
	 
      meth init
	 cache := cache(items:unit
			current:{NewCell true}
		       )
      end

      %% Id: Caller has to make sure this is unique
      meth getDocument(id:Id result:Result)
	 Result =
	 case {CondSelect (@cache).items Id unit}
	 of item(expired:E data:Data expire:EP) andthen {IsFree E} then
	    just(Data#EP)
	 else nothing
	 end
      end
      
      %% Duration: how long the item stays valid if not expired (milliseconds)
      %% Expire: A procedure which - when called - expires the cache item associated with id
      meth setDocument(id:Id duration:Duration data:Data result:Expire)
	 Expire =
	 for return:Return do
	    Cache = @cache
	 in
	    case {CondSelect Cache.items Id unit}
	    of item(expired:E data:_ expire:EP) andthen {IsFree E} then {Return EP}
	    else
	       NewItem
	       NewCache = {AddItem Cache Id NewItem}
	    in
	       if {self Set(cache:NewCache success:$)} then
		  NewItem = {CreateItem Data Duration}
		  {Return NewItem.expire}
	       end
	    end
	 end
      end
      
      meth Set(cache:C success:Success)
	 Success = (C.current) := false
	 if Success then 
	    cache := cache(items:C.items current:{NewCell true})
	 end
      end
   end

   fun {CreateItem Data Duration}
      Expired
      thread
	 {Delay Duration}
	 Expired = unit
      end
      proc {Expire}
	 Expired = unit
      end
   in
      item(expired:Expired data:Data expire:Expire)
   end

   fun {AddItem cache(items:Items current:R) Id Data}
      cache(items:{AdjoinAt Items Id Data} current:R)
   end
end

