declare

[JSON] = {Module.link ['x-ozlib://wmeyer/jzon/JSON.ozf']}

ExampleValue = object(name:"Jason" age:9)
ExampleJSON = {JSON.encode ExampleValue} %% convert to a JSON text in UTF-8

in   
{System.show
 {JSON.decode ExampleJSON}} %% convert back to an Oz object (with strings in ISO 8859-1)

{System.showInfo
 {JSON.print ExampleValue}} %% convert to pretty-printer JSON text (in UTF-8)
