#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include <string.h>
#include "dict.h"

#define DEBUG 0 /* �ǥХå�������� 1 �� */
#define ANZAI 0 /* �ºغ�jmarcfilter���ν��Ϥˤ���Ȥ���1*/

#define BUF_SIZE 1024
#define LABEL_LENGTH 24
#define N 100
#define JPMARC_RS '\x1d' /* �쥳���ɥ��ѥ졼�� */
#define JPMARC_FS '\x1e' /* �ե�����ɥ��ѥ졼�� */
#define JPMARC_SF '\x1f' /* ���֥ե�����ɼ��̻Ҥκǽ��ʸ�� */
#define JISC6226_ESC "\x1b\x24\x40" /* 2�Х���ʸ�����������ץ������� */
#define ASCII_ESC "\x1b\x28\x42" /* 1�Х���ʸ�����������ץ������� */
#define GAIJINUM 11 /* �����ο� */
#define REPLACE_STR "\x21\x21" /* "��" ��������ˤʤ����� */
/*#define REPLACE_STR "\x22\x2e" *//* "��" ��������ˤʤ����� */

/* ����ȥ� */
struct entry {
    char field[4]; /* �ե�����ɼ��̻� ����: 001, 245 �ʤɡ� */
    int len; /* �ե������Ĺ �ǡ����ե�����ɤ�Ĺ�� FS�ޤ� */
    int addr; /* �ե�����ɤ���Ƭʸ���ΰ���
	          �ǡ����ե�����ɷ�����Ƭ��������а���*/
};
/* ���֥ǡ����ե������*/
struct subdatafield {
    /* ���֥ե�����ɼ��̻� */
    char id; /* ���֥ե�����ɼ���ʸ�� ����: A,B,D,X�ʤɡ�*/
    int datalen; /* �ǡ�������Ĺ�� */
    int mode; /* �ǡ������Υ⡼�� ��1:ASCII or 2:JIS�� */
    
    /* �ǡ���������  */
    char data[BUF_SIZE]; /* �ºݤΥǡ��� ����: JP, ��� �ʤɡ�*/
};
    
/* �ǡ����ե������ */
struct datafield {
    int num; /* �ǡ����ե��������ˤ��륵�֥ǡ����ե�����ɤο� */
    struct subdatafield sub[N]; /* ���֥ǡ����ե�����ɤ����� */
};

/* �ǥ��쥯�ȥ� */
struct directory {
    struct entry* e; /* ����ȥ� */
};

/* �ǡ����ե�����ɷ� */
struct datafieldgroup {
    struct datafield* d; /* �ǡ����ե������ */
};

/* ���쥳���� */
struct record {
    int num; /* ���쥳������ˤ��륨��ȥ��ǡ����ե�����ɤο� */
    char label[LABEL_LENGTH+1];  /* �쥳���ɥ�٥� */
    struct directory dir;     /* �ǥ��쥯�ȥ� */
    struct datafieldgroup data; /* �ǡ����ե�����ɷ� */
};

void print_record (struct record rec);
char* get_datafieldgroup (char* datafieldgroup, char label[], FILE* fp);
int search (char key[], char *db[], int n);
void realchange (char str[], int len);
struct datafield get_001datafield (char datafield_str[]);
struct subdatafield get_subfield (int addr, char datafield_str[]);
struct datafield get_otherdatafield (char datafield_str[], struct entry e);
void  kanji (char str[]);
void  escape_kanji (char str[]);
int search_otergaiji (char str[]);
int get_label (char label[], FILE *fp);
void ebcdic2ascii (char label[]);
int get_length (char label[]);
char* get_dir (char* directory, int dir_lenght, FILE *fp);
int get_dirlen (char label[]); /* �ǥ��쥯�ȥ��Ĺ�����֤� */
struct entry get_direntry (char* directory, int num);
struct datafield get_datafield (char* data, struct entry e);
void substr (char str1[], char str2[], int head, int len);
int get_baseaddr (char label[]);
void print_data (struct entry e, struct datafield d);
int main (int argc, char* argv[])
{
    int i;
    FILE *fp;
    char* directory;             /* �ǥ��쥯�ȥ� */
    char* datafieldgroup;        /* �ǡ����ե�����ɷ� */
    struct record rec;           /* ���쥳���� */
    
    if (argc < 2) {
	printf("USAGE: %s file ...\n", argv[0]);
	exit(EXIT_FAILURE);
    }
    for (i = 1; i < argc; i++) {
	/*�ե�����Υ����ץ�*/
	if ((fp = fopen(argv[i], "r")) == NULL) { 
	    perror("fopen");
	    exit(EXIT_FAILURE);
	}
	while(1) {
	     /* �쥳���ɥ�٥�μ��� */
	    if (get_label(rec.label, fp) != LABEL_LENGTH) {
		/* �쥳���ɥ�٥�μ����˼��Ԥ����齪λ */
		break;
	    }
	    /* �ǥ��쥯�ȥ�μ��� */
	    directory = get_dir(directory, get_dirlen(rec.label), fp);
	    
	    /* �ǡ����ե�����ɷ��μ��� */
	    datafieldgroup = get_datafieldgroup(datafieldgroup, rec.label, fp);

	    /* ���쥳���ɤν���� */
	    rec.num = get_dirlen(rec.label) / 12;
	    rec.dir.e =  malloc(sizeof(struct entry) * rec.num);
	    rec.data.d =  malloc(sizeof(struct datafield) * rec.num);
	    
	    for (i = 0; i < rec.num; i++){
		/* ����ȥ�μ��� */
		rec.dir.e[i] = get_direntry(directory, i);
		/* �ǡ����ե�����ɤμ��� */
		rec.data.d[i] = get_datafield(datafieldgroup, rec.dir.e[i]);
	    }
	    
	    /* ���� */
	    print_record(rec);
	    
	    free(rec.dir.e);
	    free(rec.data.d);
	    free(directory);
	    free(datafieldgroup);
	}
	fclose(fp);
    }
    exit(EXIT_SUCCESS);
}
/* ���쥳���ɤ���� */
void print_record (struct record rec)
{
    int i;
#if ANZAI == 0    
    /* �쥳���ɥ�٥�ν��� */
    printf("%s\n\n", rec.label);
#endif
    for (i = 0; i < rec.num; i++){
    	/* ����ȥ�ȥǡ����ե�����ɤ���� */
	print_data(rec.dir.e[i], rec.data.d[i]);
    }
    printf("\n");
}
/* �쥳���ɥ�٥��ʸ����Ȥ���label�˼��� */
int get_label (char label[], FILE *fp)
{
    int label_length;
    label_length = fread(label, sizeof(char), LABEL_LENGTH, fp);
    label[24] = '\0';
    ebcdic2ascii(label);
    return label_length;
}

/* �ǡ����ե�����ɷ�����Ƭ���֤��֤�
 * ���쥳���ɤ���Ƭ����ΥХ��ȿ� */
int get_baseaddr (char label[])
{
    char buf[BUF_SIZE];
    substr(buf, label, 12, 5);
    return atoi(buf);   
}

/* �ǥ��쥯�ȥ��Ĺ������� */
int get_dirlen (char label[])
{
    return get_baseaddr(label) - LABEL_LENGTH;
}

/* �ǥ��쥯�ȥ��ʸ����Ȥ���directory�˼��� */
char* get_dir (char* directory, int dir_length, FILE *fp)
{
    directory = malloc(sizeof(char) * dir_length);
    fread(directory, sizeof(char), dir_length, fp);
    directory[dir_length - 1] =  '\0';
    ebcdic2ascii(directory);
    return directory;
}

/* �ǡ����ե�����ɷ��μ��� */
char* get_datafieldgroup (char* datafieldgroup, char label[], FILE* fp)
{
    int len;      /* �ǡ����ե�����ɷ���Ĺ�� */

    len = get_length(label) - get_baseaddr(label);
    datafieldgroup = malloc(sizeof(char) * (len + 1));
    
    /* �ǡ����ե�����ɷ��μ��� */
    fread(datafieldgroup, sizeof(char), len, fp);
    datafieldgroup[len] = '\0';

    return datafieldgroup;
}

/* ����ȥ�ȥǡ����ե�����ɤ���� */
void print_data (struct entry e, struct datafield d)
{
    int i;
    
#if ANZAI == 0
    if (strcmp(e.field, "001") == 0) {
	printf("%s  %s\n", e.field, d.sub[0].data);
    } else {
	for( i = 0; i < d.num; i++) {
	    printf("%s $%c %s\n", e.field, d.sub[i].id, d.sub[i].data);
	}
    }
#endif
    
#if ANZAI == 1
    if (strcmp(e.field, "001") == 0) {
	printf("%s%s\n", e.field, d.sub[0].data);
    } else {
	for( i = 0; i < d.num; i++) {
	    printf("%s$%c%s\n", e.field, d.sub[i].id, d.sub[i].data);
	}
    }
#endif	    

}

 /* �ǡ����ե�����ɤ�¤�ΤȤ����֤� */
struct datafield get_datafield (char* datafieldgroup, struct entry e)
{
    char* datafield_str;
    struct datafield d;

    /* �ǡ����ե�����ɤ�ʸ����Ȥ��Ƽ��Ф� */
    datafield_str = malloc(sizeof(char) * e.len);
    substr(datafield_str, datafieldgroup, e.addr, e.len - 1);

    /* �ǡ����ե�����ɤ�¤�ΤȤ��Ƽ��� */
    if (strcmp(e.field, "001") == 0) {
	/* 001�ե�����ɤξ�� */
	d = get_001datafield(datafield_str);
    } else {
	/* 001�ե�����ɰʳ��ξ�� */
	d = get_otherdatafield(datafield_str, e);
    }
    free(datafield_str);
    return d;
}

/* 001�ե�����ɤΥǡ����ե�����ɤμ��� */
struct datafield get_001datafield (char datafield_str[])
{
    struct datafield d;

    /* ���֥ǡ����ե�����ɤο� */
    d.num = 1;
    
    /* ���֥ե�����ɼ���ʸ�� ����: A,B,D,X�ʤɡ�   */
    /* ��˥��֥ե�����ɼ���ʸ���Ϥʤ��Τ�Ŭ������ */
    d.sub[0].id = '1';
    
    /* �ǡ�������Ĺ�� */
    d.sub[0].datalen = 8;

    /* �ǡ������Υ⡼�� ��1:ASCII�� */
    d.sub[0].mode = 1;   

    /* �ºݤΥǡ��� ����: 20000001��*/
    substr(d.sub[0].data, datafield_str, 0, 8);
    ebcdic2ascii(d.sub[0].data);

    return d;
}

/* 001�ե�����ɰʳ��Υǡ����ե������
 *  ��= ���֥ǡ����ե�����ɤ�ޤ�ǡ����ե�����ɡˤμ��� */   
struct datafield get_otherdatafield (char datafield_str[], struct entry e)
{
    int i;
    struct datafield d; /* �ǡ����ե������ */
     
    d.num = 0; /* ���֥ǡ����ե�����ɤο� */
    for (i =0; i < e.len; i++) {
	if (datafield_str[i] == JPMARC_SF) {
	    /* �ƥ��֥ǡ����ե�����ɤ���� */
	    d.sub[d.num] = get_subfield(i, datafield_str);
	    d.num++;
	}
    }
    return d;
}

/* ���֥ǡ����ե�����ɤμ��� */
struct subdatafield get_subfield (int addr, char datafield_str[])
{
    char idbuf[BUF_SIZE];
    char buf[BUF_SIZE];
    struct subdatafield s; /* ���֥ǡ����ե������ */

    substr(idbuf, datafield_str, addr + 1, 5);
    ebcdic2ascii(idbuf);

    /* ���֥ե�����ɼ���ʸ�� ����: A,B,D,X�ʤɡ�   */
    s.id = idbuf[0];

    /* �ǡ�������Ĺ�� */
    substr(buf, idbuf, 1, 3);
    s.datalen = atoi(buf);

    /* �ǡ������Υ⡼�� ��1:ASCII or 2:JIS�� */
    substr(buf, idbuf, 4, 1);
    s.mode = atoi(buf);

    /* �ǡ��������� */
    substr(s.data, datafield_str, addr + 6, s.datalen);
    if ( s.mode == 1 ) { /* ASCII���ä��� */
	ebcdic2ascii(s.data);
    } else if (s.mode == 2 ) { /* JIS���ä��� */
	kanji(s.data);
    } else { /* �ɤ���Ǥ�ʤ��ä��鶯����λ */
	printf("!!!!!! NO MODE !!!!!\n");
	exit(EXIT_FAILURE);
    }
    return s;
}

/* �����ν�����ۤɤ�����
 * JIS X 0208 �����򥨥������ץ����ɤ�ޤ���֤��� */
void  kanji (char str[])
{
    realchange(str, strlen(str)); /* �����ν��� */
    escape_kanji(str); /* JIS X 0208 �����򥨥������ץ����ɤ�ޤ�� */
}

/* JIS X 0208 �����򥨥������ץ����ɤ�ޤ���֤��� */
void  escape_kanji (char str[])
{
    char buf[BUF_SIZE];
    strcpy(buf, str);
    sprintf(str, "%s%s%s", JISC6226_ESC, buf, ASCII_ESC);
}

/* str2 �� head ���� len ʸ���ܤޤǤ� str1 �˥��ԡ� */
void substr (char str1[], char str2[], int head, int len)
{
    strncpy(str1, str2 + head, len);
    str1[len] = '\0';
}

/* ����ȥ����� */
struct entry get_direntry (char* directory, int num)
{
    struct entry e; /* ����ȥ� */
    int addr; /* ����ȥ����Ƭ���� */
    char entry[13], buf[BUF_SIZE];
    
    addr = 12 * num;

    substr(entry, directory, addr, 12);

    /* �ե�����ɼ��̻� ����: 001, 245 �ʤɡ�*/
    substr(e.field, entry, 0, 3);

    /* �ե������Ĺ: �ǡ����ե�����ɤ�Ĺ�� FS�ޤ� */
    substr(buf, entry, 3, 4);
    e.len = atoi(buf);
    
    /* �ե�����ɤ���Ƭʸ���ΰ���: 
       �ǡ����ե�����ɷ�����Ƭ��������а��� */
    substr(buf, entry, 7, 5);
    e.addr = atoi(buf);
    
    return e;
	
}

/* ���쥳����Ĺ���֤�
 * ���쥳����Ĺ: �쥳���ɥ�٥����Ƭ����RS��ޤ᤿���쥳���ɤ�Ĺ��*/
int get_length (char label[])
{
    char buf[BUF_SIZE];
    substr(buf, label, 0, 5);
    return atoi(buf);
}

static char e2a_table[] = {
    '\000', '\001', '\002', '\003', '\004', '\005', '\006', '\007', 
    '\010', '\011', '\012', '\013', '\014', '\015', '\016', '\017', 
    '\020', '\021', '\022', '\023', '\024', '\025', '\026', '\027', 
    '\030', '\031', '\032', '\033', '\034', '\035', '\036', '\037', 
    '\040', '\041', '\042', '\043', '\044', '\045', '\046', '\047', 
    '\050', '\051', '\052', '\053', '\054', '\055', '\056', '\057', 
    '\060', '\061', '\062', '\063', '\064', '\065', '\066', '\067', 
    '\070', '\071', '\072', '\073', '\074', '\075', '\076', '\077', 
    ' ',    '\101', '\102', '\103', '\104', '\105', '\106', '\107', 
    '\110', '\111', '[',    '.',    '<',    '(',    '+',    '!', 
    '&',    '\121', '\122', '\123', '\124', '\125', '\126', '\127', 
    '\130', '\131', ']',    '\\',    '*',    ')',    ';',    '^', 
    '-',    '/',    '\142', '\143', '\144', '\145', '\146', '\147', 
    '\150', '\151', '|',    ',',    '%',    '_',    '>',    '?', 
    '\160', '\161', '\162', '\163', '\164', '\165', '\166', '\167', 
    '\170', '\'',   ':',    '#',    '@',    '`',    '=',    '"', 
    '\200', 'a',    'b',    'c',    'd',    'e',    'f',    'g', 
    'h',    'i',    '\212', '\213', '\214', '\215', '\216', '\217', 
    '\220', 'j',    'k',    'l',    'm',    'n',    'o',    'p', 
    'q',    'r',    '\232', '\233', '\234', '\235', '\236', '\237', 
    '\240', '-',    's',    't',    'u',    'v',    'x',    'w', 
    'y',    'z',    '\252', '\253', '\254', '\255', '\256', '\257', 
    '\260', '\261', '\262', '\263', '\264', '\265', '\266', '\267', 
    '\270', '\271', '\272', '\273', '\274', '\275', '\276', '\277', 
    '{',    'A',    'B',    'C',    'D',    'E',    'F',    'G', 
    'H',    'I',    '\312', '\313', '\314', '\315', '\316', '\317', 
    '}',    'J',    'K',    'L',    'M',    'N',    'O',    'P', 
    'Q',    'R',    '\332', '\333', '\334', '\335', '\336', '\337', 
    '$',    '\341', 'S',    'T',    'U',    'V',    'W',    'X', 
    'Y',    'Z',    '\352', '\353', '\354', '\355', '\356', '\357', 
    '0',    '1',    '2',    '3',    '4',    '5',    '6',    '7', 
    '8',    '9',    '\372', '\373', '\374', '\375', '\376', '\377' };

void ebcdic2ascii (char label[])
{
    int i, length;
    length = strlen(label);
    for (i = 0; i < length; i++) {
	label[i] = e2a_table[(unsigned char)label[i]];
    }
}

/* ��������ˤ���ʸ�� �� ����ʸ��, ����¾�γ��� �� REPLACE��STR ,
 * ����ʸ�� �� "", "��" �� "Ĺ��" �� ����
 * ������ str[]: ���������ץ������󥹤�ޤޤʤ�2�Х��Ȥ�ʸ���� */
void realchange (char str[], int len)
{
    extern char *dict[];
#if ANZAI == 1    
    extern char *dictout[];
#endif    
#if ANZAI == 0
    extern char *dictout2[];
    char bbuf[BUF_SIZE];
#endif    
    char buf[BUF_SIZE];
    char new[BUF_SIZE] = "";
    int i, addr;

    if ( (len % 2) != 0) {
	printf("len:%d is ����Ǥ�\n", len);
	exit(EXIT_FAILURE);
    }
    for (i = 0; i < len; i = i + 2) {	
	strncpy(buf, str + i, 2);
	buf[i + 2] = '\0';
	addr = search(buf, dict, GAIJINUM);
	if ( addr != -1) { /* ��������ˤ��볰���ν��� */
#if ANZAI == 1	    
	    strcat(new, dictout[addr]);
#endif	    
#if ANZAI == 0
	    strcat(new, dictout2[addr]);
	} else if( search_otergaiji(buf) != -1) {
	    /* ��������ˤʤ������ν��� */
	    strcat(new, REPLACE_STR); 
	} else if ( (buf[0] == '\x1c') &&
		    (buf[1] >= '\x4e' && buf[1] <= '\x53')) {
	    /* ���楳���ɤʤΤ��ɲä��ʤ� */
	} else if (buf[0] =='\x21' && buf[1] == '\x5d') { /* �⤷�ޥ��ʥ��ʤ�� */
	    /* �ޥ��ʥ���Ĺ�����ѹ����뤿������ʸ�����äƤ��� */
	    strncpy(bbuf, str + i - 2, 2);
	    bbuf[i] = '\0';
	    if(( bbuf[0] == '\x24' || bbuf[0] == '\x25')
	       && (bbuf[1] >= '\x21' && bbuf[1] <= '\x76')) {
		/* �⤷�����������ʤ⤷����ʿ��̾���ä��� */
		strcat(new, "\x21\x3c"); /* Ĺ�����ѹ� */
	    } else {
		strcat(new, buf); /* ���Τޤޥޥ��ʥ��� */
	    }		
#endif	    
	} else { /* �������ʤ��ä��餽�Τޤ��ɲ� */
	    strcat(new, buf);
	}
    }
    strcpy(str, new);
}

/* ����¾�γ��������뤫Ƚ�� �����1 �ʤ����-1 */
int search_otergaiji (char str[])
{
    if((str[0] >= '\x30' && str[0] <='\x7e')
       && (str[1] >= '\xa1' && str[1] <= '\xfe')) {
	return 1;
    } else if ( (str[0] >= '\x29' && str[0] <='\x2f')
		&& (str[1] >= '\x21' && str[1] <= '\x7e')) {
	return 1;
    } else if ( (str[0] == '\x22')
		&& (str[1] >= '\x2f' && str[1] <= '\x68')) {
	return 1;
    } else {
	return -1;
    }
}
    
/* key�� db �ˤ���� ���ΰ��֤��֤�*/
int search (char key[], char *db[], int n)
{
    int left = 0, right = n - 1, mid;
    int count = 0;
    while(left <= right) {
        count++;
        mid = (left + right) / 2;
        if (strcmp(key, db[mid]) == 0){
            return(mid);
        } else if (strcmp(key, db[mid]) < 0){
            right = mid - 1;
        } else {
            left = mid + 1;
        }
    }
    return(-1);
}
