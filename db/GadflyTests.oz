functor
import
   OS System Application
   ServerT at 'Server.ozf'
define
   proc {AssertRaises ExcepLabel Proc}
      try
	 {Proc}
	 fail
      catch X then {Label X} = ExcepLabel
      end
   end
   
   Log = System.showInfo

   fun {MakeRow TableRows}
      {FoldL TableRows
       fun {$ R TR}
	  {AdjoinAt R {Label TR} TR}
       end
       row
      }
   end

   fun {MakeRows Xs} {Map Xs MakeRow} end

   Filename = "test_database.dat"

   fun {Setup}
      Schema =
      schema(frequents(drinker(type:string) bar(type:atom) perweek
		       primaryKey:drinker#bar)
	     likes(drinker(type:string) beer(type:atom) perday
		   primaryKey:drinker#beer)
	     serves(bar(type:atom) beer(type:atom) quantity
		    primaryKey:bar#beer)
	     work(name(type:string) hours rate)
	     empty(nothing(type:atom))
	     accesses(page(type:string) hits month(type:int)
		      primaryKey:page#month
		     ))
      Server = {ServerT.create Schema Filename}
      WorkData = [
		  work(name:"carla"   hours:9   rate:3.5)
		  work(name:"cliff"   hours:26  rate:200.0)
		  work(name:"diane"   hours:3   rate:4.4)
		  work(name:"norm"    hours:45  rate:10.2)
		  work(name:"rebecca" hours:120 rate:12.9)
		  work(name:"sam"     hours:30  rate:40.2)
		  work(name:"woody"   hours:80  rate:5.4)
		 ]
      FrequentsData = [frequents(drinker:"adam"   bar:lolas    perweek:1)
		       frequents(drinker:"woody"  bar:cheers   perweek:5)
		       frequents(drinker:"sam"    bar:cheers   perweek:5)
		       frequents(drinker:"norm"   bar:cheers   perweek:3)
		       frequents(drinker:"wilt"   bar:joes     perweek:2)
		       frequents(drinker:"norm"   bar:joes     perweek:1)
		       frequents(drinker:"lola"   bar:lolas    perweek:6)
		       frequents(drinker:"norm"   bar:lolas    perweek:2)
		       frequents(drinker:"woody"  bar:lolas    perweek:1)
		       frequents(drinker:"pierre" bar:frankies perweek:0)
		      ]
      ServesData = [serves(bar:cheers   beer:bud         quantity:500)
		    serves(bar:cheers   beer:samaddams   quantity:255)
		    serves(bar:joes     beer:bud         quantity:217)
		    serves(bar:joes     beer:samaddams   quantity:13)
		    serves(bar:joes     beer:mickies     quantity:2222)
		    serves(bar:lolas    beer:mickies     quantity:1515)
		    serves(bar:lolas    beer:pabst       quantity:333)
		    serves(bar:winkos   beer:rollingrock quantity:432)
		    serves(bar:frankies beer:snafu       quantity:5)
		   ]
      LikesData = [likes(drinker:"adam"  beer:bud          perday:2)
		   likes(drinker:"wilt"  beer:rollingrock  perday:1)
		   likes(drinker:"sam"   beer:bud          perday:2)
		   likes(drinker:"norm"  beer:rollingrock  perday:3)
		   likes(drinker:"norm"  beer:bud          perday:2)
		   likes(drinker:"nan"   beer:sierranevada perday:1)
		   likes(drinker:"woody" beer:pabst        perday:2)
		   likes(drinker:"lola"  beer:mickies      perday:5)
		  ]
   in
      for R in WorkData do
	 {Server insert(R)}
      end
      {Server select(work('*')
		     orderBy:work(name)
		     result:$)}
      = WorkData
      for Data in [FrequentsData ServesData LikesData] do
	 for Row in Data do {Server insert(Row)} end
      end
      Server
   end

   proc {TestPrimaryKey Server}
      {Log "TestPrimaryKey"}
      {AssertRaises database
       proc {$} {Server insert(work(name:"sam" hours:0 rate:0.0))} end
      }
   end
   proc {TestComplexLiterals Server}
      {Log "TestComplexLiterals"}
      {Server insert(work(name:"jo" hours:~1 rate:3.1e~44#1.e26))}
      {Server select(work('*') where:[work(name) '=' "jo"] result:$)}
      = [work(name:"jo" hours:~1 rate:3.1e~44#1.e26)]
      {Server delete(work where:[work(name) '=' "jo"])}
      {Server select(work('*') where:[work(name) '=' "jo"] result:$)}
      = nil
   end
   proc {TestParameterizedInserts Server}
      {Log "TestParameterizedInsert"}
      for A in [
		accesses(page:"index.html" month:1 hits:2100)
		accesses(page:"index.html" month:2 hits:3300)
		accesses(page:"index.html" month:3 hits:1950)
		accesses(page:"products.html" month:1 hits:15)
		accesses(page:"products.html" month:2 hits:650)
		accesses(page:"products.html" month:3 hits:98)
		accesses(page:"people.html" month:1 hits:439)
		accesses(page:"people.html" month:2 hits:12)
		accesses(page:"people.html" month:3 hits:665)
	       ] do
	 {Server insert(A)}
      end
      {Server select(accesses(sum(hits))
		     where:[accesses(page) '=' "people.html"]
		     result:$)}
      = [accesses('sum(hits)':439+12+665)]

      {Server select(accesses(month sum(hits(as:totalhits)))
		     where:[accesses(month) '<>' 1]
		     orderBy:accesses(totalhits)
		     result:$)}
      = [accesses(month:3 totalhits:2713)
	 accesses(month:2 totalhits:3962)]
      
      {Server select(accesses(month sum(hits(as:totalhits)))
		     orderBy:desc(accesses(totalhits))
		     result:$)}
      = [accesses(month:2 totalhits:3962)
	 accesses(month:3 totalhits:2713)
	 accesses(month:1 totalhits:2554)
	]
      
      {Server select(accesses(month sum(hits(as:totalhits)))
		     having:[accesses(totalhits) '<' 3000]
		     orderBy:desc(accesses(totalhits))
		     result:$)}
      = [accesses(month:3 totalhits:2713)
	 accesses(month:1 totalhits:2554)]
      
      {Server select(accesses(countDistinct(month) countDistinct(page))
		     result:$)}
      = [accesses('countDistinct(month)':3
		  'countDistinct(page)':3)]

      {Server select(accesses(month hits page)
		     orderBy:[accesses(month) desc(accesses(hits))]
		     result:$)}
      = 
      [accesses(month:1 hits:2100 page:"index.html")
       accesses(month:1 hits:439 page:"people.html")
       accesses(month:1 hits:15 page:"products.html")
       accesses(month:2 hits:3300 page:"index.html")	  
       accesses(month:2 hits:650 page:"products.html")	  
       accesses(month:2 hits:12 page:"people.html")	  
       accesses(month:3 hits:1950 page:"index.html")	  
       accesses(month:3 hits:665 page:"people.html")	  
       accesses(month:3 hits:98 page:"products.html")
      ]
   end
   proc {TestTrivialQueries1 Server}
      {Log "TestTrivialQueries1"}
      {Server select(work(name hours)
		     orderBy:work(name)
		     result:$)}
      = [
	 work(name:"carla" hours:9)
	 work(name:"cliff" hours:26)
	 work(name:"diane" hours:3)
	 work(name:"norm" hours:45)
	 work(name:"rebecca" hours:120)
	 work(name:"sam" hours:30)
	 work(name:"woody" hours:80)
	]
   end
   proc {TestTrivialQueries3 Server}
      {Log "TestTrivialQueries3"}
      {Server select(serves(quantity bar beer)
		     orderBy:[serves(bar) serves(beer)]
		     result:$)}
      = [
	 serves(bar:cheers beer:bud quantity:500)
	 serves(bar:cheers beer:samaddams quantity:255)
	 serves(bar:frankies beer:snafu quantity:5)
	 serves(bar:joes beer:bud quantity:217)
	 serves(bar:joes beer:mickies quantity:2222)
	 serves(bar:joes beer:samaddams quantity:13)
	 serves(bar:lolas beer:mickies quantity:1515)
	 serves(bar:lolas beer:pabst quantity:333)
	 serves(bar:winkos beer:rollingrock quantity:432)
	]
   end
   proc {TestTrivialQueries4 Server}
      {Log "TestTrivialQueries4"}
      {Server select(frequents(bar perweek drinker)
		     where:[frequents(drinker) '=' "norm"]
		     orderBy:desc(frequents(perweek))
		     result:$
		    )}
      = [
	 frequents(bar:cheers perweek:3 drinker:"norm")
	 frequents(bar:lolas perweek:2 drinker:"norm")
	 frequents(bar:joes perweek:1 drinker:"norm")
	]
   end
   proc {TestSimpleRange Server}
      {Log "TestSimpleRange"}
      {Server select(work(name rate)
		     where:[[work(rate) '>=' 20.] 'AND' [work(rate) '<=' 100.]]
		     result:$)}
      = [work(name:"sam" rate:40.2)]
      
      {Server select(work(name rate) where:[work(rate) 'BETWEEN' 20.#100.] result:$)}
      = [work(name:"sam" rate:40.2)]
      
      {Server select(work(name rate)
		     where:['NOT' [work(rate) 'BETWEEN' 20.#100.]]
		     orderBy:work(rate)
		     result:$)}
      = [
	 work(name:"carla" rate:3.5)
	 work(name:"diane" rate:4.4)
	 work(name:"woody" rate:5.4)
	 work(name:"norm" rate:10.2)
	 work(name:"rebecca" rate:12.9)
	 work(name:"cliff" rate:200.0)
	]
   end
   proc {TestBetween Server}
      {Log "TestBetween"}
      {Server select(frequents(bar perweek drinker)
		     where:['NOT' [frequents(perweek) 'BETWEEN' 2#5]]
		     orderBy:frequents(drinker)
		     result:$)}
      = [
	 frequents(bar:lolas perweek:1 drinker:"adam")
	 frequents(bar:lolas perweek:6 drinker:"lola")
	 frequents(bar:joes perweek:1 drinker:"norm")
	 frequents(bar:frankies perweek:0 drinker:"pierre")
	 frequents(bar:lolas perweek:1 drinker:"woody")
	]
   end
   proc {TestIn Server}
      {Log "TestIn"}
      {Server select(likes(drinker beer perday)
		     where:[likes(beer) 'IN' [bud pabst]]
		     orderBy:likes(drinker)
		     result:$)}
      = [
	 likes(drinker:"adam" beer:bud perday:2)
	 likes(drinker:"norm" beer:bud perday:2)
	 likes(drinker:"sam" beer:bud perday:2)
	 likes(drinker:"woody" beer:pabst perday:2)
	]
   end
   proc {TestJoin1 Server}
      {Log "TestJoin1"}
      {Server select(frequents(drinker) serves(bar) likes(beer)
		     where:[[frequents(drinker) '=' likes(drinker)]
			    [serves(beer) '=' likes(beer)]
			    [serves(bar) '=' frequents(bar)]]
		     orderBy:[frequents(drinker) serves(bar)]
		     result:$)}
      = {MakeRows
	 [
	  [frequents(drinker:"lola") serves(bar:lolas) likes(beer:mickies)]
	  [frequents(drinker:"norm") serves(bar:cheers)likes(beer:bud)]
	  [frequents(drinker:"norm") serves(bar:joes) likes(beer:bud)]
	  [frequents(drinker:"sam") serves(bar:cheers) likes(beer:bud)]
	  [frequents(drinker:"woody") serves(bar:lolas) likes(beer:pabst)]
	 ]}
   end
   proc {TestJoin2 Server}
      {Log "TestJoin2"}
      {Server select(serves(quantity beer bar) frequents(perweek drinker bar)
		     where:[serves(bar) '=' frequents(bar)]
		     orderBy:[serves(quantity) serves(beer) frequents(perweek)
			      frequents(drinker) serves(bar) frequents(bar)]
		     result:$)}
      = {MakeRows
	 [
	  [serves(quantity:5 beer:snafu bar:frankies)
	   frequents(perweek:0 drinker:"pierre" bar:frankies)]
	  [serves(quantity:13 beer:samaddams bar:joes)
	   frequents(perweek:1 drinker:"norm" bar:joes)]
	  [serves(quantity:13 beer:samaddams bar:joes)
	   frequents(perweek:2 drinker:"wilt" bar:joes)]
	  [serves(quantity:217 beer:bud bar:joes)
	   frequents(perweek:1 drinker:"norm" bar:joes)]
	  [serves(quantity:217 beer:bud bar:joes)
	   frequents(perweek:2 drinker:"wilt" bar:joes)]
	  [serves(quantity:255 beer:samaddams bar:cheers)
	   frequents(perweek:3 drinker:"norm" bar:cheers)]
	  [serves(quantity:255 beer:samaddams bar:cheers)
	   frequents(perweek:5 drinker:"sam" bar:cheers)]
	  [serves(quantity:255 beer:samaddams bar:cheers)
	   frequents(perweek:5 drinker:"woody" bar:cheers)]
	  [serves(quantity:333 beer:pabst bar:lolas)
	   frequents(perweek:1 drinker:"adam" bar:lolas)]
	  [serves(quantity:333 beer:pabst bar:lolas)
	   frequents(perweek:1 drinker:"woody" bar:lolas)]
	  [serves(quantity:333 beer:pabst bar:lolas)
	   frequents(perweek:2 drinker:"norm" bar:lolas)]
	  [serves(quantity:333 beer:pabst bar:lolas)
	   frequents(perweek:6 drinker:"lola" bar:lolas)]
	  [serves(quantity:500 beer:bud bar:cheers)
	   frequents(perweek:3 drinker:"norm" bar:cheers)]
	  [serves(quantity:500 beer:bud bar:cheers)
	   frequents(perweek:5 drinker:"sam" bar:cheers)]
	  [serves(quantity:500 beer:bud bar:cheers)
	   frequents(perweek:5 drinker:"woody" bar:cheers)]
	  [serves(quantity:1515 beer:mickies bar:lolas)
	   frequents(perweek:1 drinker:"adam" bar:lolas)]
	  [serves(quantity:1515 beer:mickies bar:lolas)
	   frequents(perweek:1 drinker:"woody" bar:lolas)]
	  [serves(quantity:1515 beer:mickies bar:lolas)
	   frequents(perweek:2 drinker:"norm" bar:lolas)]
	  [serves(quantity:1515 beer:mickies bar:lolas)
	   frequents(perweek:6 drinker:"lola" bar:lolas)]
	  [serves(quantity:2222 beer:mickies bar:joes)
	   frequents(perweek:1 drinker:"norm" bar:joes)]
	  [serves(quantity:2222 beer:mickies bar:joes)
	   frequents(perweek:2 drinker:"wilt" bar:joes)]
	 ]}
   end
   proc {TestJoin3 Server}
      {Log "TestJoin3"}
      {Server select(likes(perday beer drinker) frequents(perweek drinker bar)
		     where:[[frequents(bar) '=' cheers]
			    [likes(drinker) '=' frequents(drinker)]
			    [likes(beer) '=' bud]]
		     orderBy:[likes(perday) frequents(bar) frequents(perweek)
			      likes(beer) frequents(drinker)]
		     result:$)}
      = {MakeRows
	 [
	  [likes(perday:2 beer:bud drinker:"norm")
	   frequents(perweek:3 drinker:"norm" bar:cheers)]
	  [likes(perday:2 beer:bud drinker:"sam")
	   frequents(perweek:5 drinker:"sam" bar:cheers)]
	 ]}
   end
   proc {TestComplex1 Server}
      {Log "TestComplex1"}
      {Server selectSync(likes(beer drinker) serves(countDistinct(bar(as:db)))
			 where:[likes(beer) '=' serves(beer)]
			 orderBy:[desc(serves(db)) likes(beer) likes(drinker)]
			 result:$)}
      = {MakeRows
	 [[likes(beer:bud drinker:"adam") serves(db:2)]
	  [likes(beer:bud drinker:"norm") serves(db:2)]
	  [likes(beer:bud drinker:"sam") serves(db:2)]
	  [likes(beer:mickies drinker:"lola") serves(db:2)]
	  [likes(beer:pabst drinker:"woody") serves(db:1)]
	  [likes(beer:rollingrock drinker:"norm") serves(db:1)]
	  [likes(beer:rollingrock drinker:"wilt") serves(db:1)]
	 ]}
   end
   proc {TestAverage Server}
      {Log "TestAverage"}
      {Server select(frequents(avg(perweek(as:a))) result:$)}
      = [frequents(a:2)]
   end
   proc {TestGroupAverage Server}
      {Log "TestGroupAverage"}
      {Server select(serves(bar avg(quantity(as:aq)))
		     orderBy:serves(bar)
		     result:$)}
      = [
	 serves(bar:cheers aq:377)
	 serves(bar:frankies aq:5)
	 serves(bar:joes aq:817)
	 serves(bar:lolas aq:924)
	 serves(bar:winkos aq:432)
	]
   end
   proc {TestStringComparison1 Server}
      {Log "TestStringComparison1"}
      {Server selectSync(frequents(bar perweek drinker)
			 where:[frequents(drinker) '>' "norm"]
			 orderBy:[frequents(bar) frequents(drinker)]
			 result:$)}
      = [
	 frequents(bar:cheers perweek:5 drinker:"sam")
	 frequents(bar:cheers perweek:5 drinker:"woody")
	 frequents(bar:frankies perweek:0 drinker:"pierre")
	 frequents(bar:joes perweek:2 drinker:"wilt")
	 frequents(bar:lolas perweek:1 drinker:"woody")
	]
   end
   proc {TestStringComparison2 Server}
      {Log "TestStringComparison2"}
      {Server selectSync(frequents(bar perweek drinker)
			 where:[frequents(drinker) '<=' "norm"]
			 orderBy:[frequents(bar) frequents(drinker)]
			 result:$)}
      = [
	 frequents(bar:cheers perweek:3 drinker:"norm")
	 frequents(bar:joes perweek:1 drinker:"norm")
	 frequents(bar:lolas perweek:1 drinker:"adam")
	 frequents(bar:lolas perweek:6 drinker:"lola")
	 frequents(bar:lolas perweek:2 drinker:"norm")
	]
   end
   proc {TestStringComparison3 Server}
      {Log "TestStringComparison3"}
      {Server select(frequents(bar perweek drinker)
		     where:[[frequents(drinker) '>' "norm"]
			    'OR' [frequents(drinker) '<' "b"]]
		     orderBy:[frequents(drinker) frequents(perweek)]
		     result:$)}
      = [
	 frequents(bar:lolas perweek:1 drinker:"adam")
	 frequents(bar:frankies perweek:0 drinker:"pierre")
	 frequents(bar:cheers perweek:5 drinker:"sam")
	 frequents(bar:joes perweek:2 drinker:"wilt")
	 frequents(bar:lolas perweek:1 drinker:"woody")
	 frequents(bar:cheers perweek:5 drinker:"woody")
	]
   end
   proc {TestStringComparison4 Server}
      {Log "TestStringComparison4"}
      {Server select(frequents(bar perweek drinker)
		     where:[[frequents(drinker) '<>' "norm"]
			    ["pierre" '<>' frequents(drinker)]]
		     orderBy:[frequents(drinker) frequents(perweek)]
		     result:$)}
      = [
	 frequents(bar:lolas perweek:1 drinker:"adam")
	 frequents(bar:lolas perweek:6 drinker:"lola")
	 frequents(bar:cheers perweek:5 drinker:"sam")
	 frequents(bar:joes perweek:2 drinker:"wilt")
	 frequents(bar:lolas perweek:1 drinker:"woody")
	 frequents(bar:cheers perweek:5 drinker:"woody")
	]
   end
   proc {TestStringComparison5 Server}
      {Log "TestStringComparison5"}
      {Server select(frequents(bar perweek drinker)
		     where:[frequents(drinker) '<>' "norm"]
		     orderBy:[frequents(drinker) frequents(perweek)]
		     result:$)}
      = [
	 frequents(bar:lolas perweek:1 drinker:"adam")
	 frequents(bar:lolas perweek:6 drinker:"lola")
	 frequents(bar:frankies perweek:0 drinker:"pierre")
	 frequents(bar:cheers perweek:5 drinker:"sam")
	 frequents(bar:joes perweek:2 drinker:"wilt")
	 frequents(bar:lolas perweek:1 drinker:"woody")
	 frequents(bar:cheers perweek:5 drinker:"woody")
	]
   end
   proc {TestDistinct Server}
      {Log "TestDistinct"}
      {Server select(distinct frequents(bar)
		     orderBy:frequents(bar)
		     result:$)}
      = [
	 frequents(bar:cheers)
	 frequents(bar:frankies)
	 frequents(bar:joes)
	 frequents(bar:lolas)
	]
   end
   proc {TestAggregations1 Server}
      {Log "TestAggregations1"}
      {Server select(serves(sum(quantity) avg(quantity)) count('*')
		     result:$)}
      = [{MakeRow [count('*':9) serves('sum(quantity)':5492 'avg(quantity)':610)]}]
   end
   proc {TestAggregations2 Server}
      {Log "TestAggregations2"}
      {Server select(count('*')
		     serves(beer sum(quantity(as:sq)) avg(quantity(as:aq)))
		     orderBy:desc(serves(sq))
		     result:$)}
      = {MakeRows [
		   [count('*':2) serves(beer:mickies sq:3737 aq:1868)]
		   [count('*':2) serves(beer:bud sq:717 aq:358)]
		   [count('*':1) serves(beer:rollingrock sq:432 aq:432)]
		   [count('*':1) serves(beer:pabst sq:333 aq:333)]
		   [count('*':2) serves(beer:samaddams sq:268 aq:134)]
		   [count('*':1) serves(beer:snafu sq:5 aq:5)]
		  ]}
   end
   proc {TestAggregations3 Server}
      {Log "TestAggregations3"}
      {Server select(count('*') serves(sum(quantity(as:sq)) avg(quantity(as:aq)))
		     where:[serves(beer) '<>' bud]
		     orderBy:desc(serves(sq))
		     result:$)}
      = [{MakeRow [count('*':7) serves(sq:4775 aq:682)]}]
   end
   proc {TestAggregations4 Server}
      {Log "TestAggregations4"}
      {Server select(count('*') serves(bar sum(quantity(as:sq)) avg(quantity(as:aq)))
		     where:[serves(beer) '<>' bud]
		     having:[[serves(sq) '>' 500] 'OR' [count('*') '>' 3]]
		     orderBy:desc(serves(sq))
		     result:$)}
      = {MakeRows [
		   [count('*':2) serves(bar:joes sq:2235 aq:1117)]
		   [count('*':2) serves(bar:lolas sq:1848 aq:924)]
		  ]}
   end
   proc {TestAggregations5 Server}
      {Log "TestAggregations5"}
      {Server select(count('*') serves(beer sum(quantity(as:sq)) avg(quantity(as:aq)))
		     where:[serves(beer) '<>' bud]
		     having:[serves(sq) '>' 100]
		     orderBy:[desc(count('*')) serves(beer)]
		     result:$)}
      = {MakeRows [
		   [count('*':2) serves(beer:mickies sq:3737 aq:1868)]
		   [count('*':2) serves(beer:samaddams sq:268 aq:134)]
		   [count('*':1) serves(beer:pabst sq:333 aq:333)]
		   [count('*':1) serves(beer:rollingrock sq:432 aq:432)]
		  ]}
   end
   proc {TestAggregations7 Server}
      {Log "TestAggregations7"}
      {Server select(likes(drinker beer perday) frequents(bar perweek)
		     where:[likes(drinker) '=' frequents(drinker)]
		     orderBy:[likes(drinker) desc(likes(perday)) desc(frequents(perweek))]
		     result:$)}
      =
      {MakeRows
       [
	[likes(drinker:"adam" beer:bud perday:2) frequents(bar:lolas perweek:1)]
	[likes(drinker:"lola" beer:mickies perday:5) frequents(bar:lolas perweek:6)]
	[likes(drinker:"norm" beer:rollingrock perday:3) frequents(bar:cheers perweek:3)]
	[likes(drinker:"norm" beer:rollingrock perday:3) frequents(bar:lolas perweek:2)]
	[likes(drinker:"norm" beer:rollingrock perday:3) frequents(bar:joes perweek:1)]
	[likes(drinker:"norm" beer:bud perday:2) frequents(bar:cheers perweek:3)]
	[likes(drinker:"norm" beer:bud perday:2) frequents(bar:lolas perweek:2)]
	[likes(drinker:"norm" beer:bud perday:2) frequents(bar:joes perweek:1)]
	[likes(drinker:"sam" beer:bud perday:2) frequents(bar:cheers perweek:5)]
	[likes(drinker:"wilt" beer:rollingrock perday:1) frequents(bar:joes perweek:2)]
	[likes(drinker:"woody" beer:pabst perday:2) frequents(bar:cheers perweek:5)]
	[likes(drinker:"woody" beer:pabst perday:2) frequents(bar:lolas perweek:1)]
       ]}
   end
   
   proc {TearDown Server}
      {ServerT.shutDown Server}
      {OS.unlink Filename}
   end

   proc {RunTests}
      Server = {Setup}
   in
      try
	 {TestPrimaryKey Server}
	 {TestComplexLiterals Server}
	 {TestParameterizedInserts Server}
	 {TestTrivialQueries1 Server}
	 {TestTrivialQueries3 Server}
	 {TestTrivialQueries4 Server}
	 {TestSimpleRange Server}
	 {TestBetween Server}
	 {TestIn Server}
	 {TestJoin1 Server}
	 {TestJoin2 Server}
	 {TestJoin3 Server}
	 {TestComplex1 Server}
	 {TestAverage Server}
	 {TestGroupAverage Server}
	 {TestStringComparison1 Server}
	 {TestStringComparison2 Server}
	 {TestStringComparison3 Server}
	 {TestStringComparison4 Server}
	 {TestStringComparison5 Server}
	 {TestDistinct Server}
	 {TestAggregations1 Server}
	 {TestAggregations2 Server}
	 {TestAggregations3 Server}
	 {TestAggregations4 Server}
	 {TestAggregations5 Server}
	 {TestAggregations7 Server}
	 {System.show done}
      finally
	 {TearDown Server}
      end
   end

   {RunTests}
   {Application.exit 0}
end
