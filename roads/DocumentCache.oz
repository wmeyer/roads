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
	 of item(expired:E data:Data ...) andthen {IsFree E} then
	    just(Data)
	 else nothing
	 end
      end

      meth expire(id:Id)
	 case {CondSelect (@cache).items Id unit}
	 of item(expired:E ...) then E = unit
	 end
      end
      
      %% Duration: how long the item stays valid if not expired (milliseconds)
      %% Expire: A procedure which - when called - expires the cache item associated with id
      meth setDocument(id:Id duration:Duration data:Data result:Expire)
	 for break:Break do
	    Cache = @cache
	 in
	    case {CondSelect Cache.items Id unit}
	    of item(expired:E data:_) andthen {IsFree E} then Expire=E {Break}
	    else
	       NewItem = {CreateItem Data Duration}
	       NewCache = {AddItem Cache Id NewItem}
	    in
	       if {self Set(cache:NewCache success:$)} then
		  Expire = NewItem.expired
		  {Break}
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
      Expire
      thread
	 {Delay Duration}
	 Expire = unit
      end
   in
      item(expired:Expire data:Data)
   end

   fun {AddItem cache(items:Items current:R) Id Data}
      cache(items:{AdjoinAt Items Id Data} current:R)
   end
end

