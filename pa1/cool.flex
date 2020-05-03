 /*
  *  The scanner definition for COOL.
  */

 /*
  *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
  *  output, so headers and global definitions are placed here to be visible
  * to the code in the file.  Dont remove anything that was here initially
  */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>
#include <string>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;


/*
 *  Add Your own definitions here
 */
static int comment_recurses = 0;
%}

 /*
  * Define names for regular expressions here.
  */
ARROW          =>

%Start          INLINE_COMMENTS
%Start          MULTILINE_COMMENTS
%Start          STRING
%%

 /* INLINE COMMENTS */
"--" {
    BEGIN INLINE_COMMENTS;
}

<INLINE_COMMENTS>[^\n] { }

<INLINE_COMMENTS>"\n" {
    curr_lineno++;
    BEGIN 0;
}

<INLINE_COMMENTS><<EOF>> { 
    yylval.error_msg = "EOF in comment";
    BEGIN 0;
    return ERROR;
}


 /* MULTILINE COMMENTS */
"(*" {
    comment_recurses++;
    BEGIN MULTILINE_COMMENTS;
}

<MULTILINE_COMMENTS>"(*" {
    comment_recurses++;
}

<MULTILINE_COMMENTS>"*)" {
    comment_recurses--;
    if (comment_recurses == 0) {
      BEGIN 0;
    }
}

<MULTILINE_COMMENTS>"\n" {
    curr_lineno++;
}

 /* [^\n()*]* */
<MULTILINE_COMMENTS>[^\n] { }

 /* <MULTILINE_COMMENTS>[()*] { } */


<MULTILINE_COMMENTS><<EOF>> { 
    yylval.error_msg = "EOF in comment";
    BEGIN 0;
    return ERROR;
}

"*)" {
    yylval.error_msg = "Unmatched *)";
    return ERROR;
}

 /* ===========================================
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  * ===========================================
  */

(\") {
    BEGIN STRING;
    yymore();
}

<STRING>[^\\\"\n]* { yymore(); }

 /* Escape sequence for all chacters except n */
<STRING>\\[^n] { yymore(); }

<STRING>\\\n {
    curr_lineno++;
    yymore();
}

<STRING>\n {
    yylval.error_msg = "Unterminated string constant";
    BEGIN 0;
    curr_lineno++;
    return ERROR;
}

 /* yyrestart(yyin); */
<STRING><<EOF>> {
    yylval.error_msg = "EOF in string constant";
    BEGIN 0;
    return ERROR;
}

 /* End quote */
<STRING>(\") {
    std::string regex_match(yytext, yyleng);

    /* removing the quotation marks */
    std::string str = regex_match.substr(1, regex_match.length() - 1);

    std::string output = "";
    std::size_t idx;
    
    if (str.find_first_of('\0') != std::string::npos) {
        yylval.error_msg = "String contains null character";
        BEGIN 0;
        return ERROR;    
    }

    idx = str.find_first_of("\\");
    while (idx != std::string::npos) {
        output += str.substr(0, idx);

        if (str[idx+1] == 'b'){
            output += "\b";
        }
        else if (str[idx+1] == 't'){
            output += "\t";
        }
        else if (str[idx+1] == 'n'){
            output += "\n";
        }
        else if (str[idx+1] == 'f'){
            output += "\f";
        }
        else {
            output += str[idx + 1];
        }

        str = str.substr(idx + 2);
        idx = str.find_first_of("\\");
    }

    output += str;

    if (output.length() > 1024) {
        yylval.error_msg = "String constant too long";
        BEGIN 0;
        return ERROR;    
    }

    cool_yylval.symbol = stringtable.add_string((char *)output.c_str());
    BEGIN 0;
    return STR_CONST;
}
  
 /* ====================================================================
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  * ====================================================================
  */

 /* CLASS */
(?i:class) { return CLASS; }

 /* ELSE */
(?i:else) { return ELSE; }

 /* FI */
(?i:fi) { return FI; }

 /* IF */
(?i:if) { return IF; }

 /* IN */
(?i:in) { return IN; }

 /* INHERITS */
(?i:inherits) { return INHERITS; }

 /* LET */
(?i:let) { return LET; }

 /* LOOP */
(?i:loop) { return LOOP; }

 /* POOL */
(?i:pool) { return POOL; }

 /* THEN */
(?i:then) { return THEN; }

 /* WHILE */
(?i:while) { return WHILE; }

 /* CASE */
(?i:case) { return CASE; }

 /* ESAC */
(?i:esac) { return ESAC; }

 /* OF */
(?i:of) { return OF; }

 /* NEW */
(?i:new) { return NEW; }

 /* ISVOID */
(?i:isvoid) { return ISVOID; }

 /* NOT */
(?i:not) { return NOT; }

 /* NEWLINES */
"\n" { curr_lineno++; }

 /* WHITESPACE */
[\r\f\v\t ]+ { }

 /* INTEGER CONSTANTS */
[0-9]+ {
    cool_yylval.symbol = inttable.add_string(yytext);
    return INT_CONST;
}

 /* BOOL CONSTANTS */
t(?i:rue)  {
    cool_yylval.boolean = 1;
  	return BOOL_CONST;
}

f(?i:alse) {
  	cool_yylval.boolean = 0;
  	return BOOL_CONST;
}

 /* TYPEID */
[A-Z][A-Za-z0-9_]* {
    cool_yylval.symbol = idtable.add_string(yytext);
    return TYPEID;
}

 /* OBJECTID */
[a-z][A-Za-z0-9_]* {
    cool_yylval.symbol = idtable.add_string(yytext);
    return OBJECTID;
}

 /* ============
  * OPERATORS
  * ============
  */

 /* ASSIGN */
"<-" { return ASSIGN; }

 /* LE */
"<=" { return LE; }

 /* DARROW */
"=>" { return DARROW; }

"@" { return int('@'); }

"~" { return int('~'); }

"+" { return int('+'); }

"-" { return int('-'); }

"*" { return int('*'); }

"/" { return int('/'); }

"=" { return int('='); }
 
":" { return int(':'); }

"<" { return int('<'); }

"," { return int(','); }

"." { return int('.'); }

";" { return int(';'); }

"}" { return int('}'); }

")" { return int(')'); }

"(" { return int('('); }

"{" { return int('{'); }

 /* ====================================
  * ERROR - When none of the above match
  * ====================================
  */

[^\n] {
    yylval.error_msg = yytext;
    return ERROR;
}

%%
