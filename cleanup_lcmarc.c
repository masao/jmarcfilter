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
#define LABEL_LENGTH 24
#define ENTRY_LENGTH 12

#define MARC_RS '\x1d' /* �쥳���ɥ��ѥ졼�� */
#define MARC_FS '\x1e' /* �ե�����ɥ��ѥ졼�� */
#define MARC_SF '\x1f' /* ���֥ե�����ɼ��̻Ҥκǽ��ʸ�� */
void substr (char str1[], char str2[], int head, int len);
int get_rec_length (char label[]);
int main (int argc, char* argv[])
{
    int i;
    FILE *fp;
    char in;
    char gomi[GOMI_LENGTH+1];
    int igomi;
    char label[LABEL_LENGTH+1];
    char rec_flag;
    int count;
    char tmp[1024];
    double field_countr;
    int field_count;
    int dir_count;

    /* gomi�ν����*/
    gomi[GOMI_LENGTH] = '\0';
    /* label �ν����*/
    label[LABEL_LENGTH] = '\0';

    if (argc != 2) {
        printf("USAGE: %s file \n", argv[0]);
        exit(EXIT_FAILURE);
    }
    /*�ե�����Υ����ץ�*/
    if ((fp = fopen(argv[1], "r")) == NULL) {
	perror("fopen");
	exit(EXIT_FAILURE);
    }
    while(1){
	    
	/*���ߤ��äƤ���*/
	if(fread(gomi,sizeof(char), GOMI_LENGTH, fp)== NULL){
	    break;
	}
	igomi = atoi(gomi);
	if(igomi > 10000) {
	    igomi = igomi - 10000;
	}
	count=5;
	while(1) {
	    count++;
	    if(fread((char*)&in,sizeof(char), 1, fp)== NULL){
		break;
	    }
	    if(!(igomi < count && count <= igomi+5) ){
		printf("%c", in);
	    }
	    /*�⤷�쥳���ɤν�����ä���*/
	    if(in == MARC_RS){
		break;
	    }
	}
    }
    fclose(fp);
    exit(EXIT_SUCCESS);
}
/* str2 �� head ���� len ʸ���ܤޤǤ� str1 �˥��ԡ� */
void substr (char str1[], char str2[], int head, int len)
{
    strncpy(str1, str2 + head, len);
    str1[len] = '\0';
}
int get_rec_length (char label[])
{
    char tmp[1024];
    int rec_length;
    substr(tmp,label, 0, 5);
    rec_length = atoi(tmp) - 24;
    return rec_length;
}
