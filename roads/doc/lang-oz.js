/**
 * @fileoverview
 * Registers a language handler for Oz.
 *
 * Based on the Mozart OPI file oz.el.
 *
 * @author Wolfgang.Meyer@gmx.net
 */

PR.registerLangHandler(
    PR.createSimpleLexer(
        [
         // Whitespace is made up of spaces, tabs and newline characters.
         [PR.PR_PLAIN,       /^[\t\n\r \xA0]+/, null, '\t\n\r \xA0'],
         [PR.PR_COMMENT,     /^%.*/],
         [PR.PR_STRING,      /^(?:\"(?:[^\"\\]|\\[\s\S])*(?:\"|$)|\'(?:[^\'\\]|\\[\s\S])*(?:\'|$))/, null, '"\'']
	 ],
	[
         [PR.PR_COMMENT, /^(?:%[^\r\n]*)/],
         [PR.PR_KEYWORD,     /^(?:local|proc|fun|case|if|cond|or|dis|choice|not|thread|try|raise|lock|for|from|prop|attr|feat|in|then|else|of|elseof|elsecase|elseif|catch|finally|with|require|prepare|import|export|define|declare|do|end|$)\b/],
         // A number is a hex integer literal, a decimal real literal, or in
         // scientific notation.
         [PR.PR_PUNCTUATION,
          /^[+\-]?(?:0x[\da-f]+|(?:(?:\.\d+|\d+(?:\.\d*)?)(?:e[+\-]?\d+)?))/i],
	 ]),
    ['oz']);
