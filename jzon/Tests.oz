%% Some tests for JSON.oz and UTF8.oz
%% (Uses the datasets in the "test" subdirectory.)
functor
import
   JSON at 'x-ozlib://wmeyer/jzon/JSON.ozf'
   UTF8 at 'x-ozlib://wmeyer/jzon/UTF8.ozf'
   Util
   System
   Application
define
   {System.showInfo "Preparing..."}
   
   %% from the JSON RFC
   ExampleArray = {VirtualString.toString
		   "["#
		   "      {"#
		   "         \"precision\": \"zip\","#
		   "         \"Latitude\":  37.7668,"#
		   "         \"Longitude\": -122.3959,"#
		   "         \"Address\":   \"\","#
		   "         \"City\":      \"SAN FRANCISCO\","#
		   "         \"State\":     \"CA\","#
		   "         \"Zip\":       \"94107\","#
		   "         \"Country\":   \"US\""#
		   "      },"#
		   "      {"#
		   "         \"precision\": \"zip\","#
		   "         \"Latitude\":  37.371991,"#
		   "         \"Longitude\": -122.026020,"#
		   "         \"Address\":   \"\","#
		   "         \"City\":      \"SUNNYVALE\","#
		   "         \"State\":     \"CA\","#
		   "         \"Zip\":       \"94085\","#
		   "         \"Country\":   \"US\""#
		   "      }"#
		   "]"
		  }
   DecodedExampleArray = {JSON.decode ExampleArray}
   ExampleArrayInOz =
   array(
      object(
	 'precision': "zip"
	 'Latitude': 37.7668
	 'Longitude': ~122.3959
	 'Address': ""
	 'City': "SAN FRANCISCO"
	 'State': "CA"
	 'Zip': "94107"
	 'Country': "US"
	 )
      object(
	 'precision': "zip"
	 'Latitude': 37.371991
	 'Longitude': ~122.026020
	 'Address': ""
	 'City': "SUNNYVALE"
	 'State': "CA"
	 'Zip': "94085"
	 'Country': "US"
	 )
      )

   ExampleObject =
   {VirtualString.toString
    "{"#
    "      \"Image\": {"#
    "          \"Width\":  800,"#
    "          \"Height\": 600,"#
    "          \"Title\":  \"View from 15th Floor\","#
    "          \"Thumbnail\": {"#
    "              \"Url\":    \"http://www.example.com/image/481989943\","#
    "              \"Height\": 125,"#
    "              \"Width\":  \"100\""#
    "          },"#
    "          \"IDs\": [116, 943, 234, 38793]"#
    "      }"#
    "}"
   }
   DecodedExampleObject = {JSON.decode ExampleObject}
   ExampleObjectInOz =
   object(
      'Image': object(
		  'Width': 800
		  'Height': 600
		  'Title': "View from 15th Floor"
		  'Thumbnail': object(
				  'Url': "http://www.example.com/image/481989943"
				  'Height': 125
				  'Width': "100"
				  )
		  'IDs': array(116 943 234 38793)
		  )
      )
   ISOSet = {Append
	     {List.number 0 127 1}
	     {List.number 160 255 1}
	    }
   JSONString = [&[&"
		 0x24 %% $
		 0xc2 0xa2 %% ¢
		 0xe2 0x82 0xac %% Euro sign
		 0xf4 0x8a 0xaf 0x8d %% something outside of the BMP
		 &"&]]
in
   {System.printInfo "Testing decoding"}

   %% DECODE tests
   DecodedExampleArray = ExampleArrayInOz
      
   DecodedExampleObject = ExampleObjectInOz

   %% data sets that should fail to decode
   for Fail in 1..33 do
      {System.printInfo "."}
      FailResult = {JSON.decode {Util.lazyRead "test/fail"#Fail#".json"}}
   in
      if {Not (
	        %% this one succeeds because we don't have a depth restriction
	       (Fail==18 andthen FailResult\=unit)
	       orelse
	       (Fail\=18 andthen FailResult==unit)
	      )} then
	 fail
      end
   end

   %% data sets that should succeed
   for Pass in 1..3 do
      {System.printInfo "."}
      ({JSON.decode {Util.lazyRead "test/pass"#Pass#".json"}} \= unit)=true
   end

   %% ENCODE tests
   {System.printInfo "\nTesting encoding"}
   %% test that objects do not change if they are encoded and then decoded
   local
      fun {Decoder Xs} {JSON.decodeWith UTF8.fromUTF8Preserving Xs} end
   in
      %% test both pretty printing and compact printing
      for Encoder in [JSON.encode JSON.print] do
	 {System.printInfo "."}
	 if {Not {JSON.equal
		  ExampleArrayInOz
		  {Decoder {Encoder ExampleArrayInOz}}}} then
	    fail
	 end
	 {System.printInfo "."}
	 if {Not {JSON.equal
		  ExampleObjectInOz
		  {Decoder {Encoder ExampleObjectInOz}}}} then
	    fail
	 end

	 for Pass in 1..3 do
	    {System.printInfo "."}
	    DataTxt = {Util.lazyRead "test/pass"#Pass#".json"}
	    Data = {Decoder DataTxt}
	 in
	    if {Not {JSON.equal
		     Data
		     {Decoder {Encoder Data}}}} then
	       fail
	    end
	 end
      end
   end
   
   %% testing reversibility of JSON string value encoding (when using preserving char enc.)
   local
      InOz = {JSON.decodeWith UTF8.fromUTF8Preserving JSONString}
      Back = {JSON.encode InOz}
   in
      Back = JSONString
   end

   {System.printInfo "\nTesting character encoding"}
   %% test result of decoding an UTF-8 string with the different decoders
   try
      _ = {UTF8.fromUTF8Strict JSONString}
      fail
   catch utf8(...) then skip end

   {UTF8.fromUTF8Loose JSONString} = "[\"$¢??\"]"

   {UTF8.fromUTF8Preserving JSONString} = "[\"$¢\\u20ac\\udbea\\udfcd\"]"
   
   %% testing reversibility of toUTF8
   for I in ISOSet do
      U8 = {UTF8.toUTF8 [I]}
   in
      {UTF8.fromUTF8Loose U8} = [I]
      {UTF8.fromUTF8Strict U8} = [I]
      {UTF8.fromUTF8Preserving U8} = [I]
   end
   
   %% testing reversibility of fromUTF8Preserving and fromUTF32ToUTF8
   for CP in 0..0x10ffff;3 do
      U32 = {UTF8.codePointToUTF32 CP}
      U8 = {UTF8.codePointToUTF8 CP}
      ISO = {UTF8.fromUTF8Preserving U8}
   in
      if CP mod 0x1000 == 0 then {System.printInfo "."} end
      {UTF8.fromUTF8ToUTF32 {UTF8.fromUTF32ToUTF8 U32}} = U32
      {UTF8.fromUTF8ToUTF32 U8} = U32
      {UTF8.toUTF8 ISO} = U8
   end

   {System.showInfo "\nAll passed."}
   {Application.exit 0}
end
