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

#define MARC_RS '\x1d' /* �쥳���ɥ��ѥ졼�� */
#define MARC_FS '\x1e' /* �ե�����ɥ��ѥ졼�� */
#define MARC_SF '\x1f' /* ���֥ե�����ɼ��̻Ҥκǽ��ʸ�� */

void substr (char str1[], char str2[], int head, int len);
int main (int argc, char* argv[])
{
    FILE *fp;
    char in;
    int count;
    int num;

    if (argc != 2) {
        fprintf(stderr,"USAGE: %s infile\n", argv[0]);
        exit(EXIT_FAILURE);
    }
    /*�ե�����Υ����ץ�*/
    if ((fp = fopen(argv[1], "r")) == NULL) {
	perror("fopen");
	exit(EXIT_FAILURE);
    }
    
    printf("     |1234567890|1234567890|1234567890|1234567890|1234567890|");
    printf("\n-----+----------+----------+----------+----------+----------+");
    num = 0;    
    count = 0;
    while(1){
	if((num % 50) == 0) {
	    printf("\n%5d|",num);
	}
	num++;
	if(fread((char*)&in,sizeof(char), 1, fp)== NULL){
	    break;
	}
	if(in == MARC_FS){
	    printf("*"); /* �ե�����ɼ��̻� */
	}
	else if(in == MARC_SF){
	    printf("$"); /* ���֥ե�����ɼ��̻Ҥκǽ��ʸ�� */
	}
	else {
	    printf("%c",in);
	}
	if((num % 10) == 0){
	    printf("|");
	}
	/*�⤷�쥳���ɤν�����ä���*/
	if(in == MARC_RS){
	    count++;
	    num = 0;
	    printf("\n\n     |1234567890|1234567890|1234567890|1234567890|1234567890|");
	    printf("\n-----+----------+----------+----------+----------+----------+");
	}
    }
    printf("%s = %d\n", argv[1],count);
    fclose(fp);
    exit(EXIT_SUCCESS);
}
