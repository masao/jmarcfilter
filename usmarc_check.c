/*
 * Copyright (C) 2000 Yuka Egusa. All rights reserved.
 *
 *  $Id$
 */
#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include <string.h>

#define LABEL_LENGTH 24
#define RECORD_LENGTH 5
#define BUF_SIZE 1024

#define MARC_RS '\x1d' /* レコードセパレータ */
#define MARC_FS '\x1e' /* フィールドセパレータ */
#define MARC_SF '\x1f' /* サブフィールド識別子の最初の文字 */
void substr (char str1[], char str2[], int head, int len);
int get_length (char label[]);

int main (int argc, char* argv[])
{
    FILE *fp;
    char in;
    char label[LABEL_LENGTH+1];
    int rec_length; /* ラベルから取得できる1レコードの長さ */
    int real_rec_length; /* 実際の1レコードの長さ */
    int rec_count; /* レコードの数 */
    char* record; /* レコード全体の文字列 */

    if (argc != 2) {
        printf("USAGE: %s file \n", argv[0]);
        exit(EXIT_FAILURE);
    }
    /*ファイルのオープン*/
    if ((fp = fopen(argv[1], "r")) == NULL) {
	perror("fopen");
	exit(EXIT_FAILURE);
    }
    rec_count = 0;
    while(1){
	/* get label*/
	if(fread(label,sizeof(char), LABEL_LENGTH, fp)== NULL){
	    break;
	}
	label[LABEL_LENGTH] = '\0';

	/*レコードの長さを取得  */
	rec_length = get_length(label);
	real_rec_length = 24;
	while(1){
	    real_rec_length++;
	    /* get label*/
	    if(fread((char *)&in,sizeof(char), 1, fp)== NULL){
		break;
	    }
	    /*もしレコードの終りだったら*/
	    if(in == MARC_RS){
		if(real_rec_length != rec_length){
		    fprintf(stderr, "ラベル(%d)と実際のレコード(%d)の長さが一致しません。\n", rec_length, real_rec_length);
		}
		rec_count++;
		break;
	    }
	}
    }
    printf("recort count = %d\n", rec_count);
    fclose(fp);
    exit(EXIT_SUCCESS);
}

/* str2 の head から len 文字目までを str1 にコピー */
void substr (char str1[], char str2[], int head, int len)
{
    strncpy(str1, str2 + head, len);
    str1[len] = '\0';
}
/* 書誌レコード長を返す
 * 書誌レコード長: レコードラベルの先頭からRSを含めた書誌レコードの長さ*/
int get_length (char label[])
{
    char buf[BUF_SIZE];
    substr(buf, label, 0, 5);
    return atoi(buf);
}
