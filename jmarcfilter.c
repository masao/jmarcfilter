/*
	ＪＭＡＲＣフォーマットを読むプログラム
	第３版  うりゃーと１レコードを全部読み取ってディレクトリ情報に忠実に
		フィールドを再現するバージョン

cc -o jmarcfilter jmarcfilter.c; strip jmarcfilter
cat @JMARC1 | jmarcfilter | less

	Hiroyuki Anzai    June, 1 1994

*/


#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<ctype.h>
#define TRUE 1
#define UTC 0x1f		/* delimiter */
#define FTC 0x1e		/* field terminator */
#define RTC 0x1d		/* record terminator */
#include "header.h"		/* print format */

static char *EBCDIC[257] = {
	"NUL","@@", "@@", "@@", "@@", "@@", "@@", "@@",
	"@@", "@@", "@@", "@@", "@@", "@@", "@@", "@@",
	"@@", "@@", "@@", "@@", "@@", "@@", "@@", "@@",
	"@@", "@@", "@@", "@@", "@@", "RS", "#",  "$" ,
	"@@", "@@", "@@", "@@", "@@", "@@", "@@", "@@",
	"@@", "@@", "@@", "@@", "@@", "@@", "@@", "@@",
	"@@", "@@", "@@", "@@", "@@", "@@", "@@", "@@",
	"@@", "@@", "@@", "@@", "@@", "@@", "@@", "@@",
	" ",  "@@", "@@", "@@", "@@", "@@", "@@", "@@",
	"@@", "@@", "[",  ".",  "<",  "(",  "+",  "|" ,
	"&",  "@@", "@@", "@@", "@@", "@@", "@@", "@@",
	"@@", "@@", "]",  "\\", "*",  ")",  ";",  "^" ,
	"-",  "/",  "@@", "@@", "@@", "@@", "@@", "@@",
	"@@", "@@", "|",  ",",  "%",  "_",  ">",  "?" ,
	"@@", "@@", "@@", "@@", "@@", "@@", "@@", "@@",
	"@@", "'",  ":",  "#",  "@",  "`",  "=",  "\"",
	"@@", "a",  "b",  "c",  "d",  "e",  "f",  "g" ,
	"h",  "i",  "@@", "@@", "@@", "@@", "@@", "@@",
	"@@", "j",  "k",  "l",  "m",  "n",  "o",  "p" ,
	"q",  "r",  "@@", "@@", "@@", "@@", "@@", "@@",
	"@@", "-",  "s",  "t",  "u",  "v",  "w",  "x" ,
	"y",  "z",  "@@", "@@", "@@", "@@", "@@", "@@",
	"@@", "@@", "@@", "@@", "@@", "@@", "@@", "@@",
	"@@", "@@", "@@", "@@", "@@", "@@", "@@", "@@",
	"{",  "A",  "B",  "C",  "D",  "E",  "F",  "G" ,
	"H",  "I",  "@@", "@@", "@@", "@@", "@@", "@@",
	"}",  "J",  "K",  "L",  "M",  "N",  "O",  "P" ,
	"Q",  "R",  "@@", "@@", "@@", "@@", "@@", "@@",
	"$",  "@@", "S",  "T",  "U",  "V",  "W",  "X" ,
	"Y",  "Z",  "@@", "@@", "@@", "@@", "@@", "@@",
	"0",  "1",  "2",  "3",  "4",  "5",  "6",  "7" ,
	"8",  "9",  "@@", "@@", "@@", "@@", "@@", "EO"};

void kanjishift(void);
void ascshift(void);
char *strmid(char *s1, int n);
void ebc2jis(char *st);
void putcode(int s1);
void putkanji(char *st, int len);
void putfield(char *s1, int n, char *tagtemp);
void puteuc(char *st);

main(int argc, char *argv[])
{
	int reclen, i, j, k, n, fieldlen, basebase, baseadd, fieldcnt, cntmax;
	char *buf, *marc, *c, *leader, *temp, *tag[100], *dataelement[100];
	char field[5], address[5];
	char UT[1], FT[1], RT[1];
	sprintf(UT, "%c", UTC);
	sprintf(FT, "%c", FTC);
	sprintf(RT, "%c", RTC);
	c = (char *)malloc(sizeof(char)*1);
	buf = (char *)malloc(sizeof(char)*13);
	temp = (char *)malloc(sizeof(char)*6);
	leader = (char *)malloc(sizeof(char)*25);
	if ((buf == NULL) || (c == NULL) || (leader == NULL) || (temp == NULL))
		{
		printf("Memory shortage!\n");
		exit(1);
		}
	/*
	printf("%d %s %s\n", argc, argv[0], argv[1]);
	exit(0);
	*/
	if (argc == 2) cntmax = atoi(argv[1]);
		else cntmax = 99999;

/* getting MARC RECORDS (MAIN LOOP) */
while(TRUE){
	++n;
	if (RECORDNUMBER) 
  		printf("\nRecord : %4d  ", n);

	/* READING 5 chars (Record Length) */
	strcpy(buf, "");
	for(i = 0; i < 5; i++){
		*c = getchar();
		if (*c == EOF) goto EndFile;
		strcat(buf, c);
		}

	strcpy(temp, buf);
	ebc2jis(buf);
	reclen = atoi(buf);
	if (RECLEN)
		printf("(RECORD LENGTH %d)\n", reclen);
	marc = (char *)malloc(sizeof(char)*(reclen + 1));
	if (marc == NULL){
		printf("\nCANT malloc for MARC RECORD!\n");
		exit(1);
		}
	strcpy(marc, temp);
	i = 5;

	/* Reading data for 6 - rellen chars */
	while(TRUE){
		if ((*c = getchar()) == EOF) goto EndFile;
		strcat(marc, c);
		if ((++i) == reclen) break;
		}

	/* READING Leader block */
	strncpy(leader, marc, 24);
	strcpy(leader+24, "\0");
	ebc2jis(leader);
	if (PRINTLEADER)
		printf(LEADERFORM, leader);

	/* READING Directory block and data element */
	basebase = strcspn(marc, FT) + 1;
	i = basebase - 25;	/* leader 24 chars */
	fieldcnt = i / 12;
	for(i = 0; i < fieldcnt; i++){
		strcpy(buf, "");
		k = 25 + 12*i;
		strncpy(buf, strmid(marc, k), 12);
		strcpy(buf+12, "\0");
		ebc2jis(buf);
		tag[i] = (char *)malloc(sizeof(char)*4);
		if (tag[i] == NULL) exit(1);
		strncpy(tag[i], buf, 3);
		strcpy(tag[i]+3, "\0");
		strncpy(field, strmid(buf,4), 4);
		fieldlen = atoi(field);
		strncpy(address, strmid(buf,8), 5);
		strcpy(address+5, "\0");
		baseadd = atoi(address) + basebase;
		dataelement[i] = (char *)malloc(sizeof(char)*(fieldlen+1));
		if (dataelement[i] == NULL) exit(1);
		strncpy(dataelement[i], strmid(marc, baseadd) +1, fieldlen);
		strcpy(dataelement[i]+fieldlen, "\0");
#if defined(USEGOLIST)
		if ((PRINTTAG) && (strstr(GOLISTTAG, tag[i]) != NULL))
			printf(TAGFORM, tag[i]);
#endif
#if !defined(USEGOLIST)
		if (PRINTTAG != NULL)
			printf(TAGFORM, tag[i]);
#endif
		if (strncmp(tag[i], "001", 3) == 0) {
			ebc2jis(dataelement[i]);
			strcpy(dataelement[i]+8, "\0");
			if (TAG001)
				printf(TAG001FORM, dataelement[i]);
			}
		else putfield(dataelement[i], fieldlen, tag[i]);	
	}

	strncpy(buf, strmid(marc, baseadd) + fieldlen + 1, 1);
	strcpy(buf+1, "\0");

	/* check Record Terminator */
	if (strncmp(buf, RT,1) != 0) {
		printf("Where is record teminator? %s Good-bye.\n", buf);
		exit(1);
		}
	printf(RECORD_T);

	/* free memory */
	for(i = fieldcnt -1; i >= 0; i--){
		free(tag[i]);
		free(dataelement[i]);
		}
	free(marc);
	if (n == cntmax) exit(0);

	}	/* this is the end of while loop */

/* End of File */
EndFile:
	/*puts("End of File.");*/
	exit(0);
}		/* this is the end of program function MAIN */


void kanjishift(void)
{
	putchar(27);
	putchar(36);					/* shift code */
	putchar(64);					/* ESC $ @    */
}

void ascshift(void)
{
	putchar(27);
	putchar(40);					/* shift code */
	putchar(66);					/* ESC ( B    */
}

void ebc2jis(char *st)
{
	int c, i, n;
	char s[1];
	n = strcspn(st, "\0\n");
	for(i = 0; i < n; i ++){
		strncpy(s, st + i, 1);
		c = (int)s[0];
		c = (c & 0x000000ff);
		strncpy(st+i, EBCDIC[c], 1);
		}
	strcpy(st+n, "\0");
}

char *strmid(char *s1, int n)
{
        int i, ren;
        ren = strlen(s1);
        if ((n <= 0) || (ren <= 0) || (n > ren))
                return(NULL);
        for(i = 0; i < n-1; i++){
                s1++;
        }
        return(s1);
}

void putcode(int s1)
{
	s1 = (s1 & 0x000000ff);
	printf("{%x}", s1);
}

void putfield(char *s1, int m, char *tagtemp)
{
	int i, j, n, c, l, KANJI;
	char s[1], *buf, *temp, *tagsfc;
	n = 0; j = 0;
	buf = (char *)malloc(sizeof(char)*4);
	tagsfc = (char *)malloc(sizeof(char)*6);
	if ((buf == NULL) || (tagsfc == NULL)) exit(1);
	while(TRUE){	/* each subfield 1 loop */
		strncpy(s, s1+n, 1);
		strcpy(s+1, "\0");
		c = (int)s[0];
		if (c != UTC) {
			puts("I cant find Subfield separator");
			exit(1);
			}
		strncpy(s, s1+n+1, 1);
		strcpy(s+1, "\0");
		ebc2jis(s);
		strcpy(tagsfc, tagtemp);
		strcat(tagsfc, s);
#if defined(USEGOLIST)
		if (strstr(GOLISTTAG, tagsfc) != NULL) {
			if (PRINTSFC)
				printf(SFCFORM, s[0]);
			else if (PRINTTAGSFC)
				printf(TAGSFCFORM, tagtemp, s[0]);
		}
#endif
#if !defined(USEGOLIST)
		if (PRINTSFC)
			printf(SFCFORM, s[0]);
		else if (PRINTTAGSFC)
			printf(TAGSFCFORM, tagtemp, s[0]);
#endif
		strncpy(buf, s1+n+2, 3);
		strcpy(buf+3, "\0");
		ebc2jis(buf);
		l = atoi(buf);
		strncpy(s, s1+n+5, 1);
		strcpy(s+1, "\0");
		ebc2jis(s);
		i = atoi(s);
		if (i == 1) KANJI = 0;
		else if (i == 2) KANJI = 1;
		else {
			puts("I cant distinguish Kanji / Alphabetical.");
			exit(1);
			}
		temp = (char *)malloc(sizeof(char)*l+1);
		if (temp == NULL) exit(1);
		strncpy(temp, s1+n+6, l);
		strcpy(temp+l, "\0");
#if defined(USEGOLIST)
		if (strstr(GOLISTTAG, tagsfc) != NULL) {
			j++;
			if (KANJI == 0) {
				ebc2jis(temp);
				printf("%s",temp);
				}
			else putkanji(temp, l);
			printf(SUBFIELD_T);
		}
#endif
#if !defined(USEGOLIST)
			j++;
			if (KANJI == 0) {
				ebc2jis(temp);
				printf("%s",temp);
				}
			else putkanji(temp, l);
			printf(SUBFIELD_T);
#endif
		free(temp);
		n = n + l + 6;
		if (n == m-1) break;
		}
	free(buf);
	free(tagsfc);
	if (j != 0) printf(FIELD_T);
	strncpy(s, s1+n, 1);
	strcpy(s+1, "\0");
	c = (int)s[0];
	if (c != FTC) {
		puts("WARNING - no Field Terminator !");
		exit(1);
	}
}

void putkanji(char *st, int len)
/* スイッチで追加文字への対応は一応可能であるが、面倒である */
/* 配列変数の利用も考えられるが、どちらにしても面倒である */ 
{
	int kanji, kanf, kanb, i;
	kanjishift();
	for(i = 0; i < len /2; i++){
	kanf = (int)(*(st+(i*2)));
	kanf = (kanf & 0x000000ff);
	kanb = (int)(*(st+(i*2)+1));
	kanb = (kanb & 0x000000ff);
	kanji = kanf * 256 + kanb;
	switch(kanji){
	case 0x2a24:
		puteuc("Ａａ");
		break;
	case 0x2a2b:
		puteuc("Ｅｅ");
		break;
	case 0x2a2f:
		puteuc("Ｉｉ");
		break;
	case 0x2a34:
		puteuc("Ｏｏ");
		break;
	case 0x2a39:
		puteuc("Ｕｕ");
		break;
	case 0x2a43:
		puteuc("ａａ");
		break;
	case 0x2a50:
		puteuc("ｅｅ");
		break;
	case 0x2a56:
		puteuc("ｉｉ");
		break;
	case 0x2a5e:
		puteuc("ｏｏ");
		break;
	case 0x2a6c:
		puteuc("ｕｕ");
		break;
	case 0x2231:
		puteuc("／");
		break;
	default:
		putchar(kanf);
		putchar(kanb);
	}
	}
	ascshift();
}

void puteuc(char *st)
{
	int i, a, b, c;
	for(i = 0; i < (strlen(st)/2); i++){
		a = (int)(*(st+(i*2)));
		b = (int)(*(st+(i*2)+1));
        	a = (a & 0x000000ff);
		b = (b & 0x000000ff); 
/*
		c = a * 256 + b;
		c = euc2jis(c);
		a = c / 256 ;
		b = c - 256 * a;
*/
	a = a - 0x80;
	b  = b -0x80;
		putchar(a);
		putchar(b);
		}
}

/*

        11, April       第１版完成
                        ＥＢＣＤＩＣと漢字の出力をシフトコードでわける。
        18, April       第２版完成
                        タグをリーダーの情報からつける
         6, May         ＥＢＣＤＩＣ表をＪＭＡＲＣマニュアルの付録のものと
                        差し換える。
         7, May         追加文字への対応開始
                        現時点でローマ字への伸ばす音のみに対処
        12, May         引き数への対処

	 1, June	第３版作成開始
			ディレクトリとの関連で読み込み手続きを抜本改革開始
	 6, June	ＥＵＣ漢字をＪＩＳ漢字として出力する関数を製作し、
			プログラムに組み込む。
	24, June	ダブルスラッシュを／で翻字するように処理を変更。

*/
