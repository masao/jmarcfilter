/* definition for print format */
#define RECORDNUMBER 0	 		/* Print Record Number Yes or No */
#define RECLEN 0			/* Print Record Length Y or N */
#define PRINTLEADER 0			/* Print Leader Y or N */
#define LEADERFORM "leader :%s \n"	/* Leader Print Format */

/* you can select format printing TAG001 or not */
#define TAG001 1			/* Print TAG 001 */
#define TAG001FORM "001%s\n"		/* TAG 001 Print Format */

/* you can select format printing TAG or SFC or TAG+SFC or nothing. */
#define PRINTTAG 0			/* Print Tag Y or N */
#define TAGFORM "%7s:"			/* Tag Print Format */

#define PRINTSFC 0			/* Print SubField Code Y or N */
#define SFCFORM "$%c "			/* SFC Print Format */

#define PRINTTAGSFC 1			/* Print TAG + SFC Y or N */
#define TAGSFCFORM "%3s$%c"		/* TAG + SFC Print Format */

/* these are terminators */
#define SUBFIELD_T "\n"			/* SF TERMINATOR */
#define FIELD_T ""  			/* FIELD TERMINATOR */
/*#define RECORD_T "ENDXTHEEND\n"*/	/* RECORD TERMINATOR */
#define RECORD_T "\n"			/* RECORD TERMINATOR */

/* these are tags in need(go-list) */
/*#define USEGOLIST	*/		/* using golist yes or no */
static char *GOLISTTAG = "251A251D251F270A270B270D275A275B350A350B360B751A751X751B";
