/*
 * Copyright (C) 2000 Yuka Egusa. All rights reserved.
 *
 *  $Id$
 */
#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include <string.h>

#define GOMI_LENGTH 5

#define MARC_RS '\x1d' /* レコードセパレータ */
#define MARC_FS '\x1e' /* フィールドセパレータ */
#define MARC_SF '\x1f' /* サブフィールド識別子の最初の文字 */

int main (int argc, char* argv[])
{
    FILE *fp;
    char in;
    char gomi[GOMI_LENGTH+1];
    int igomi;
    int count;

    /* gomiの初期化*/
    gomi[GOMI_LENGTH] = '\0';

    if (argc != 2) {
        printf("USAGE: %s file \n", argv[0]);
        exit(EXIT_FAILURE);
    }
    /*ファイルのオープン*/
    if ((fp = fopen(argv[1], "r")) == NULL) {
	perror("fopen");
	exit(EXIT_FAILURE);
    }
    while(1){
	/*レコードセパレータの前にノイズがあるので読み飛ばす*/
	while(1){
	    if(fread((char*)&in,sizeof(char), 1, fp)== NULL){
		break;
	    }
	    if(in == '0' || in =='1'){
		break;
	    }
	}
	/*ゴミの下4桁を取ってくる*/
	if(fread(gomi,sizeof(char), GOMI_LENGTH-1, fp)== NULL){
	    break;
	}
	igomi = atoi(gomi);
	/*if(igomi > 10000) {
	    igomi = igomi - 10000;
	    }*/
	count=5;
	while(1) {
	    count++;
	    if(fread((char*)&in,sizeof(char), 1, fp)== NULL){
		break;
	    }
	    if(!(igomi < count && count <= igomi+5) ){
		printf("%c", in);
	    }
	    /*もしレコードの終りだったら*/
	    if(in == MARC_RS){
		break;
	    }
	}
    }
    fclose(fp);
    exit(EXIT_SUCCESS);
}
