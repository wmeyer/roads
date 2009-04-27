functor
export
   ActivateFirstForm
prepare
   ActivateFirstForm =
   "if(window.document.forms[0]&&window.document.forms[0].elements[0])"#
   " window.document.forms[0].elements[0].focus();"
end