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

#define MARC_RS '\x1d' /* �쥳���ɥ��ѥ졼�� */
#define MARC_FS '\x1e' /* �ե�����ɥ��ѥ졼�� */
#define MARC_SF '\x1f' /* ���֥ե�����ɼ��̻Ҥκǽ��ʸ�� */
void substr (char str1[], char str2[], int head, int len);
int get_length (char label[]);

int main (int argc, char* argv[])
{
    FILE *fp;
    char in;
    char label[LABEL_LENGTH+1];
    int rec_length; /* ��٥뤫������Ǥ���1�쥳���ɤ�Ĺ�� */
    int real_rec_length; /* �ºݤ�1�쥳���ɤ�Ĺ�� */
    int rec_count; /* �쥳���ɤο� */
    char* record; /* �쥳�������Τ�ʸ���� */

    if (argc != 2) {
        printf("USAGE: %s file \n", argv[0]);
        exit(EXIT_FAILURE);
    }
    /*�ե�����Υ����ץ�*/
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

	/*�쥳���ɤ�Ĺ�������  */
	rec_length = get_length(label);
	real_rec_length = 24;
	while(1){
	    real_rec_length++;
	    /* get label*/
	    if(fread((char *)&in,sizeof(char), 1, fp)== NULL){
		break;
	    }
	    /*�⤷�쥳���ɤν�����ä���*/
	    if(in == MARC_RS){
		if(real_rec_length != rec_length){
		    fprintf(stderr, "��٥�(%d)�ȼºݤΥ쥳����(%d)��Ĺ�������פ��ޤ���\n", rec_length, real_rec_length);
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

/* str2 �� head ���� len ʸ���ܤޤǤ� str1 �˥��ԡ� */
void substr (char str1[], char str2[], int head, int len)
{
    strncpy(str1, str2 + head, len);
    str1[len] = '\0';
}
/* ���쥳����Ĺ���֤�
 * ���쥳����Ĺ: �쥳���ɥ�٥����Ƭ����RS��ޤ᤿���쥳���ɤ�Ĺ��*/
int get_length (char label[])
{
    char buf[BUF_SIZE];
    substr(buf, label, 0, 5);
    return atoi(buf);
}
