/*
 * Copyright (C) 2000 Yuka Egusa. All rights reserved.
 *
 *  $Id$
 */
#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include <string.h>

#define N 2043 /* データの最大バイト数（2043 = 2048 - 5） */

#define MARC_RS '\x1d' /* レコードセパレータ */
#define MARC_FS '\x1e' /* フィールドセパレータ */
#define MARC_SF '\x1f' /* サブフィールド識別子の最初の文字 */

int main (int argc, char* argv[])
{
    FILE *fp, *wfp;
    char flag; /*データの長さのフラグ 0|1|2|3 のどれか*/
    char clen[5]; /* データの長さ */
    int len; /* データの長さ */
    char data[N]; /* データ */
    if (argc != 3) {
        fprintf(stderr,"USAGE: %s infile outfile \n", argv[0]);
        exit(EXIT_FAILURE);
    }
    /*ファイルのオープン*/
    if ((fp = fopen(argv[1], "r")) == NULL) {
	perror("fopen");
	exit(EXIT_FAILURE);
    }
    if ((wfp = fopen(argv[2], "w")) == NULL) {
	perror("fopen");
	exit(EXIT_FAILURE);
    }
    while(1){
	while(1){
	    /* flag = '0|1|2|3' を 取ってくる（1バイト） */
	    if(fread((char*)&flag,sizeof(char), 1, fp)== NULL){
		break;
	    }
	    /* ノイズは読み飛ばす */
	    if(flag == '0' | flag == '1' | flag == '2' | flag == '3'){
		break;
	    }
	}
	/*データの長さを取ってくる（4バイト）*/
	if(fread(clen,sizeof(char), 4, fp)== NULL){
	    break;
	}
	clen[4] = '\0';
	
	/* データのバイト数を求める */
	/* flag+データ長のバイト数分（5バイト）を引くと求まる */
	len = atoi(clen) - 5;

	/* データを取ってくる （lenバイト）*/
	if(fread(data,sizeof(char), len, fp)== NULL){
	    break;
	}
	fwrite(data,sizeof(char), len, wfp);
    }
    fclose(fp);
    fclose(wfp);
    exit(EXIT_SUCCESS);
}
