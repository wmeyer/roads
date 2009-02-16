The Roads Web Application Framework
===================================

Roads is a basic web application framework written in Oz/Mozart.
It maps URLs to Oz functions which produce HTML code.


Examples
--------
The following function implements a minimal web app as described by Paul Graham in
"Take the Arc Challenge" (http://www.paulgraham.com/arcchallenge.html).

   fun {Said Session}
      Foo
   in 
      form(input(type:text bind:Foo)
	   input(type:submit)
	   method:post
	   action:fun {$ _}
		     p(a("click here"
			 href:fun {$ _}
				 p("you said: "#Foo)
			      end
			))
		  end
	  )
   end

This function takes a session object and returns a record which represents HTLM code.
There are two differences to vanilla HTML:
* The values of "action" and "href" attributes may be functions.
  In the resulting real HTML, these function values will be replaced with generated URLs.
  When the generated URLs are requested, the framework will make sure that the right
  function is called with the right program state.
* "Input" tags can have a "bind" attribute. Its value should be a dataflow variable.
  When the anonymous function specified for "action" is called, the variable "Foo" will be
  bound to the text that the user entered in the text field. Note: The values of input
  fields are also available in the parameter dictionary (see below).
This little web app will work correctly even if the user decides to open multiple tabs or
use the back button. This is implemented by using first class computation spaces.

Another example (this time we actually use the Session object):

   fun {Counter S}
      Count = {S.condGet count 0}
   in
      'div'(
	 h1("Counter: "#Count)
	 p(a("++" href:fun {$ S2} {S2.set count Count+1} {Counter S2} end)
	   "&nbsp;&nbsp;"
	   a("--" href:fun {$ S3} {S3.set count Count-1} {Counter S3} end)
	  )
	 )
   end


Routing and Application Organization
------------------------------------
Just defining a function does, of course, not make it available at an URL.



Sessions and the Session Object
-------------------------------
Roads manages a per-application session id which is stored in a cookie. A session expires
 after 1 hour of inactivity (configurable with the parameter "SessionDuration" in
 "Config.oz").
A session object has four dictionaries:
 * the private dictionary (functions: set, get, condGet, member, remove)
   To share data between consecutive function calls.
   This dictionary is copied before every function call, so the data is not shared
   if the session has been forked by opening a link in a new tab.
   The private dictionary is lost when a link with a normal URL is activated (i.e. a link
   that does not contain a function value or a special "call(<url>)" value in its href
   attribute.) [TODO: explain this better]
 * the shared dictionary
   (functions: setShared, getShared, condGetShared, memberShared, removeShared)
   To share data between all functions that are called within a session.
   A typical candidate: a  shopping cart in an online store application.
 * the parameter dictionary (functions: getParam, condGetParam, memberParam)
   This dictionary contains HTTP parameters of GET or POST requests.
 * the temporary dictionary (functions: setTmp, getTmp, condGetTmp, memberTmp, removeTmp)
   To shared data within a single function call.
   This can be especially useful together with postprocessing functions.


Consequences of using Computation Spaces
----------------------------------------
By default, all functions are executed in subordinated computation spaces. This goes
 together well with the way web applications work.
By using the back button, the user expects to go to a previous application state. Roads
 does exactly that, albeit only for parts of the program state: the private session
 dictionary, the value of input parameters and the state of dataflow variables
 (which are accessible by lexical scoping) are reversed to their previous state when going
 back to a function.
By opening a page in a new tab, the user expects to be able to use the application mostly
 independently from the other tabs. Roads makes this possible by cloning the associated
 computation space of a function before executing the function.
Global state cannot by modified directly from a subordinate computation space. However,
 you often need global side effects in web applications (e.g. when storing data in a
 database). There are two ways to deal with this:

 1. Turn off the use of computation spaces.
    There is a application-specific setting "forkedFunctions". When this is set to "false",
    no computations spaces are automatically created and side effects can be used as in
    normal Oz procedures.
    When computation spaces are wanted in special cases, this can be specified by wrapping
    function values in action and href attributes like this:
     a(href:fork(Function) "When this link is clicked, the program state is cloned.")

 2. Send data from subordinate spaces to the toplevel space via ports.        
    The operation "Port.sendRecv" allows to send data to a thread in the toplevel space
    and also to receive a reply from such a thread.
    It is possible to build abstractions like active objects on top of this.

Of course, data outside of a function's computation space or even outside of the process
 (like in external databases) is NEVER cloned or reversed. It must therefore be possible
 to expire URLs of pages which initiate irreversibles actions or access data which is
 no longer available. By default, generated URLs expire only when their session expires.
 [TODO: explain Session.expireLinksAfter, Session.expireLinksAfterInactivity, Session.createContext]


Application-specific Resources
------------------------------
TODO


HTML Postprocessing
-------------------
The examples used in this document do not produce valid HTML because some obligatory tags
 have been omitted for brevity's sake. However, it is easy to rectify this negligence. The
 framework allows to define a function which takes the HTML output of a function and the
 session object which was used by this function and returns some modified or extended
 output.
Such a postprocessing function can be defined both at application level and at functor
 level. This makes it possible to share HTML code either for ALL pages of an application or
 just for the pages/functions defined within one functor.
If we extend the application definition like in the following example, all generated HTML
 code will be valid:

   functor
   export
      Config
      PostProcess
   define
      Config = config(functors:unit('arc':'x-ozlib://wmeyer/roads/examples/Arc.ozf'))

      fun {PostProcess Session HtmlDoc}
         html(
	    head(title("My title"))
	    body(HtmlDoc)
             )
      end
   end
  [File: roads/examples/ArcApp.oz]

A postprocess function may also use values from the session dictionaries. Especially the
temporary dictionary is well suited to this task because it will be cleared automatically
after the function itself AND the postprocess function have been called.

Note that Roads will currently prepend all HTML code with
   <!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">


Limitations
-----------
- no template system
- no input validation
- no component or widget system
- no persistency solution
- only works with the Sawhorse webserver
  (which is a port of the "Haskell Web Server" at http://darcs.haskell.org/hws/ to Oz)


2009-01-21,
Wolfgang.Meyer@gmx.net
