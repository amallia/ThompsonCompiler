
%option noyywrap
%{
	#include <stdio.h>
%}

open		"("
close		")"
star		"*"
pipe		"|"
char		[a-zA-Z0-9]

%%
[ \t]		{ /* skip blanks */ }
{open}		{  					 		return OPEN;	}
{close}	{ 	 				 		return CLOSE;	}
{star} 		{	 				 		return STAR; 	}
{pipe}		{   					 	return PIPE; 	}
{char}		{ yylval.Value = yytext[0]; return CHAR;	}
[\n\r]		{ return EOL; }
%%