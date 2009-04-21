declare
[Roads] = {Module.link ['x-ozlib://wmeyer/roads/Roads.ozf']}

fun {HelloWorld Session}
   html(head(title("Hello"))
	body(p("Hello, world!"))
       )
end

in

{Roads.registerFunction hello HelloWorld}
{Roads.run}

