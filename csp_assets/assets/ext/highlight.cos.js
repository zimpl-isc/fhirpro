/*! `cos` grammar compiled for Highlight.js 11.10.0 */
  (function(){
    var hljsGrammar = (function () {
  'use strict';

  /*
  Language: Caché Object Script
  Author: Nikita Savchenko <zitros.lab@gmail.com>, Brandon Thomas <brandon.thomas@intersystems.com>
  Category: enterprise, scripting
  Website: https://cedocs.intersystems.com/latest/csp/docbook/DocBook.UI.Page.cls
  */

  /** @type LanguageFn */
  function cos(hljs) {
    const STRINGS = {
      className: 'string',
      variants: [
        {
          begin: '"',
          end: '"',
          contains: [
            { // escaped
              begin: "\"\"",
              relevance: 0
            }
          ]
        }
      ]
    };

    const NUMBERS = {
      className: "number",
      begin: "\\b(\\d+(\\.\\d*)?|\\.\\d+)",
      relevance: 0
    };

    const COS_KEYWORDS =
      //'property parameter class classmethod clientmethod extends as break ' +
      'catch close continue do d|0 else elseif for goto halt hang h|0 if job '
      + 'j|0 kill k|0 lock l|0 merge new open quit q|0 read r|0 return set s|0 '
      + 'tcommit throw trollback try tstart use view while write w|0 xecute x|0 '
      + 'zkill znspace zn ztrap zwrite zw zzdump zzwrite print zbreak zinsert '
      + 'zload zprint zremove zsave zzprint mv mvcall mvcrt mvdim mvprint zquit '
      + 'zsync ascii';

    return {
      name: 'Caché Object Script',
      case_insensitive: true,
      aliases: [ "cls" ],
      keywords: COS_KEYWORDS,
      contains: [
        NUMBERS,
        STRINGS,
        hljs.C_LINE_COMMENT_MODE,
        hljs.C_BLOCK_COMMENT_MODE,
        {
          className: "ISC_ClassMember",
          begin: /^(?:IncludeGenerator|Include|ClassMethod|Class|Method|ClientMethod|Property|Parameter|Query|XData|Storage|Trigger|Index)/
        },
        {
          className: "ISC_Include",
          begin: /(?<=^Include .*|^#include .*)[%a-z0-9.]+/
        },
        {
          className: "ISC_ClassName",
          begin: /(?<=##class\(|extends .*| as array of | as list of | as )[%a-z0-9.]+/
        },
        {
          className: "comment",
          begin: /;/,
          end: "$",
          relevance: 0
        },
        { // Functions and user-defined functions: write $ztime(60*60*3), $$myFunc(10), $$^Val(1)
          className: "ISC_Function",
          begin: /(?:\$\$?)\^?[a-zA-Z0-9]+/
        },
        { // Macro command: quit $$$OK
          className: "ISC_Macro",
          begin: /\$\$\$[a-zA-Z0-9]+/
        },
        { // Global variable: set ^globalName = 12 write ^globalName
          className: "symbol",
          begin: /\^%?[a-zA-Z0-9][\w]*/
        },
        { // Some control constructions: do ##class(Package.ClassName).Method(), ##super()
          className: "ISC_System",
          begin: /##class|##super|#define|#dim/
        },
        { // TODO: This needs work
          className: "ISC_MethodParameter",
          begin: /(?<=^Classmethod .*|Method .*)[%a-z0-9.]+(?=\)|[, =](?<! As ))/
        },
        {
          className: "ISC_Variable",
          begin: /(?<=set |do |while |write |catch |return |quit )[a-zA-Z0-9]+/
        },
        {
          className: "ISC_Method",
          begin: /(?<=\.|\s|)([%a-zA-Z0-9]+)(?=\()/
        },
        { // Special (global) variables: write %request.Content; Built-in classes: %Library.Integer
          className: "built_in",
          begin: /%[a-z]+(?:\.[a-z]+)*/
        },
        
        // sub-languages: are not fully supported by hljs by 11/15/2015
        // left for the future implementation.
        {
          begin: /&sql\(/,
          end: /\)/,
          excludeBegin: true,
          excludeEnd: true,
          subLanguage: "sql"
        },
        {
          begin: /&(js|jscript|javascript)</,
          end: />/,
          excludeBegin: true,
          excludeEnd: true,
          subLanguage: "javascript"
        },
        {
          // this breaks first and last tag, but this is the only way to embed a valid html
          begin: /&html<\s*</,
          end: />\s*>/,
          subLanguage: "xml"
        }
      ]
    };
  }

  return cos;

})();

    hljs.registerLanguage('cos', hljsGrammar);
  })();