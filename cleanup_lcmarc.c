/*
 * Copyright (C) 2000 Yuka Egusa. All rights reserved.
 *
 *  $Id$
 */
#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include <string.h>

#define N 2043 /* �ǡ����κ���Х��ȿ���2043 = 2048 - 5�� */

#define MARC_RS '\x1d' /* �쥳���ɥ��ѥ졼�� */
#define MARC_FS '\x1e' /* �ե�����ɥ��ѥ졼�� */
#define MARC_SF '\x1f' /* ���֥ե�����ɼ��̻Ҥκǽ��ʸ�� */

int main (int argc, char* argv[])
{
    FILE *fp, *wfp;
    char flag; /*�ǡ�����Ĺ���Υե饰 0|1|2|3 �Τɤ줫*/
    char clen[5]; /* �ǡ�����Ĺ�� */
    int len; /* �ǡ�����Ĺ�� */
    char data[N]; /* �ǡ��� */
    if (argc != 3) {
        fprintf(stderr,"USAGE: %s infile outfile \n", argv[0]);
        exit(EXIT_FAILURE);
    }
    /*�ե�����Υ����ץ�*/
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
	    /* flag = '0|1|2|3' �� ��äƤ����1�Х��ȡ� */
	    if(fread((char*)&flag,sizeof(char), 1, fp)== NULL){
		break;
	    }
	    /* �Υ������ɤ����Ф� */
	    if(flag == '0' | flag == '1' | flag == '2' | flag == '3'){
		break;
	    }
	}
	/*�ǡ�����Ĺ�����äƤ����4�Х��ȡ�*/
	if(fread(clen,sizeof(char), 4, fp)== NULL){
	    break;
	}
	clen[4] = '\0';
	
	/* �ǡ����ΥХ��ȿ������ */
	/* flag+�ǡ���Ĺ�ΥХ��ȿ�ʬ��5�Х��ȡˤ�����ȵ�ޤ� */
	len = atoi(clen) - 5;

	/* �ǡ������äƤ��� ��len�Х��ȡ�*/
	if(fread(data,sizeof(char), len, fp)== NULL){
	    break;
	}
	fwrite(data,sizeof(char), len, wfp);
    }
    fclose(fp);
    fclose(wfp);
    exit(EXIT_SUCCESS);
}
