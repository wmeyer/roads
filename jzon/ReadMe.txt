JZON 0.2
========

A simple JSON parser and printer for Oz/Mozart.
Contact me at Wolfgang.Meyer@gmx.net for bug reports and questions.


Compilation
-----------
Go to the JZON directory and execute

> ./build.sh

to build the library. If this succeeds, run the test suite by executing

> ozengine Tests.ozf


Usage
-----
The most important functions are JSON.decode and JSON.encode.
These functions automatically convert from/to the UTF-8 Unicode encoding.
(UTF-8 is the default encoding for JSON text; Oz/Mozart uses the ISO 8859-1 encoding.)
Other encodings can be used, too (see JSO.decodeWith / JSON.encodeWith).
JSON.print is like JSON.encode, but uses pretty printing.

See SimpleExample.oz for a very simple usage example.


Mapping between JSON values and Oz values
-----------------------------------------
true                    true
false                   false
null                    null
quoted UTF-8 string     Oz string (list of integers)
array                   tuple with the label "array"
object                  record with the label "object"
number with decimal     float
point and/or exponent
other numbers           int

For example:
{ "emptyArray":[]       object('emptyArray':array
  "float":3.1415               'float':3.1415
  "text":"abcd"                'text':"abcd2
  "numbers":[1,2,3]            'numbers':array(1 2 3)
}                             )
