#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include <string.h>
#include "dict.h"

#define DEBUG 0 /* デバックする時は 1 に */
#define ANZAI 0 /* 安斎作jmarcfilter風の出力にするときは1*/

#define BUF_SIZE 1024
#define LABEL_LENGTH 24
#define N 100
#define JPMARC_RS '\x1d' /* レコードセパレータ */
#define JPMARC_FS '\x1e' /* フィールドセパレータ */
#define JPMARC_SF '\x1f' /* サブフィールド識別子の最初の文字 */
#define JISC6226_ESC "\x1b\x24\x40" /* 2バイト文字エスケープシーケンス */
#define ASCII_ESC "\x1b\x28\x42" /* 1バイト文字エスケープシーケンス */
#define GAIJINUM 11 /* 外字の数 */
#define REPLACE_STR "\x21\x21" /* "　" 外字辞書にない外字 */
/*#define REPLACE_STR "\x22\x2e" *//* "〓" 外字辞書にない外字 */

/* エントリ */
struct entry {
    char field[4]; /* フィールド識別子 （例: 001, 245 など） */
    int len; /* フィールド長 データフィールドの長さ FS含む */
    int addr; /* フィールドの先頭文字の位置
	          データフィールド群の先頭からの相対位置*/
};
/* サブデータフィールド*/
struct subdatafield {
    /* サブフィールド識別子 */
    char id; /* サブフィールド識別文字 （例: A,B,D,Xなど）*/
    int datalen; /* データ部の長さ */
    int mode; /* データ部のモード （1:ASCII or 2:JIS） */
    
    /* データ（部）  */
    char data[BUF_SIZE]; /* 実際のデータ （例: JP, 東京 など）*/
};
    
/* データフィールド */
struct datafield {
    int num; /* データフィールド内にあるサブデータフィールドの数 */
    struct subdatafield sub[N]; /* サブデータフィールドの配列 */
};

/* ディレクトリ */
struct directory {
    struct entry* e; /* エントリ */
};

/* データフィールド群 */
struct datafieldgroup {
    struct datafield* d; /* データフィールド */
};

/* 書誌レコード */
struct record {
    int num; /* 書誌レコード内にあるエントリやデータフィールドの数 */
    char label[LABEL_LENGTH+1];  /* レコードラベル */
    struct directory dir;     /* ディレクトリ */
    struct datafieldgroup data; /* データフィールド群 */
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
int get_dirlen (char label[]); /* ディレクトリの長さを返す */
struct entry get_direntry (char* directory, int num);
struct datafield get_datafield (char* data, struct entry e);
void substr (char str1[], char str2[], int head, int len);
int get_baseaddr (char label[]);
void print_data (struct entry e, struct datafield d);
int main (int argc, char* argv[])
{
    int i;
    FILE *fp;
    char* directory;             /* ディレクトリ */
    char* datafieldgroup;        /* データフィールド群 */
    struct record rec;           /* 書誌レコード */
    
    if (argc < 2) {
	printf("USAGE: %s file ...\n", argv[0]);
	exit(EXIT_FAILURE);
    }
    for (i = 1; i < argc; i++) {
	/*ファイルのオープン*/
	if ((fp = fopen(argv[i], "r")) == NULL) { 
	    perror("fopen");
	    exit(EXIT_FAILURE);
	}
	while(1) {
	     /* レコードラベルの取得 */
	    if (get_label(rec.label, fp) != LABEL_LENGTH) {
		/* レコードラベルの取得に失敗したら終了 */
		break;
	    }
	    /* ディレクトリの取得 */
	    directory = get_dir(directory, get_dirlen(rec.label), fp);
	    
	    /* データフィールド群の取得 */
	    datafieldgroup = get_datafieldgroup(datafieldgroup, rec.label, fp);

	    /* 書誌レコードの初期化 */
	    rec.num = get_dirlen(rec.label) / 12;
	    rec.dir.e =  malloc(sizeof(struct entry) * rec.num);
	    rec.data.d =  malloc(sizeof(struct datafield) * rec.num);
	    
	    for (i = 0; i < rec.num; i++){
		/* エントリの取得 */
		rec.dir.e[i] = get_direntry(directory, i);
		/* データフィールドの取得 */
		rec.data.d[i] = get_datafield(datafieldgroup, rec.dir.e[i]);
	    }
	    
	    /* 出力 */
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
/* 書誌レコードを出力 */
void print_record (struct record rec)
{
    int i;
#if ANZAI == 0    
    /* レコードラベルの出力 */
    printf("%s\n\n", rec.label);
#endif
    for (i = 0; i < rec.num; i++){
    	/* エントリとデータフィールドを出力 */
	print_data(rec.dir.e[i], rec.data.d[i]);
    }
    printf("\n");
}
/* レコードラベルを文字列としてlabelに取得 */
int get_label (char label[], FILE *fp)
{
    int label_length;
    label_length = fread(label, sizeof(char), LABEL_LENGTH, fp);
    label[24] = '\0';
    ebcdic2ascii(label);
    return label_length;
}

/* データフィールド群の先頭位置を返す
 * 書誌レコードの先頭からのバイト数 */
int get_baseaddr (char label[])
{
    char buf[BUF_SIZE];
    substr(buf, label, 12, 5);
    return atoi(buf);   
}

/* ディレクトリの長さを取得 */
int get_dirlen (char label[])
{
    return get_baseaddr(label) - LABEL_LENGTH;
}

/* ディレクトリを文字列としてdirectoryに取得 */
char* get_dir (char* directory, int dir_length, FILE *fp)
{
    directory = malloc(sizeof(char) * dir_length);
    fread(directory, sizeof(char), dir_length, fp);
    directory[dir_length - 1] =  '\0';
    ebcdic2ascii(directory);
    return directory;
}

/* データフィールド群の取得 */
char* get_datafieldgroup (char* datafieldgroup, char label[], FILE* fp)
{
    int len;      /* データフィールド群の長さ */

    len = get_length(label) - get_baseaddr(label);
    datafieldgroup = malloc(sizeof(char) * (len + 1));
    
    /* データフィールド群の取得 */
    fread(datafieldgroup, sizeof(char), len, fp);
    datafieldgroup[len] = '\0';

    return datafieldgroup;
}

/* エントリとデータフィールドを出力 */
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

 /* データフィールドを構造体として返す */
struct datafield get_datafield (char* datafieldgroup, struct entry e)
{
    char* datafield_str;
    struct datafield d;

    /* データフィールドを文字列として取り出す */
    datafield_str = malloc(sizeof(char) * e.len);
    substr(datafield_str, datafieldgroup, e.addr, e.len - 1);

    /* データフィールドを構造体として取得 */
    if (strcmp(e.field, "001") == 0) {
	/* 001フィールドの場合 */
	d = get_001datafield(datafield_str);
    } else {
	/* 001フィールド以外の場合 */
	d = get_otherdatafield(datafield_str, e);
    }
    free(datafield_str);
    return d;
}

/* 001フィールドのデータフィールドの取得 */
struct datafield get_001datafield (char datafield_str[])
{
    struct datafield d;

    /* サブデータフィールドの数 */
    d.num = 1;
    
    /* サブフィールド識別文字 （例: A,B,D,Xなど）   */
    /* 注）サブフィールド識別文字はないので適当な値 */
    d.sub[0].id = '1';
    
    /* データ部の長さ */
    d.sub[0].datalen = 8;

    /* データ部のモード （1:ASCII） */
    d.sub[0].mode = 1;   

    /* 実際のデータ （例: 20000001）*/
    substr(d.sub[0].data, datafield_str, 0, 8);
    ebcdic2ascii(d.sub[0].data);

    return d;
}

/* 001フィールド以外のデータフィールド
 *  （= サブデータフィールドを含むデータフィールド）の取得 */   
struct datafield get_otherdatafield (char datafield_str[], struct entry e)
{
    int i;
    struct datafield d; /* データフィールド */
     
    d.num = 0; /* サブデータフィールドの数 */
    for (i =0; i < e.len; i++) {
	if (datafield_str[i] == JPMARC_SF) {
	    /* 各サブデータフィールドを取得 */
	    d.sub[d.num] = get_subfield(i, datafield_str);
	    d.num++;
	}
    }
    return d;
}

/* サブデータフィールドの取得 */
struct subdatafield get_subfield (int addr, char datafield_str[])
{
    char idbuf[BUF_SIZE];
    char buf[BUF_SIZE];
    struct subdatafield s; /* サブデータフィールド */

    substr(idbuf, datafield_str, addr + 1, 5);
    ebcdic2ascii(idbuf);

    /* サブフィールド識別文字 （例: A,B,D,Xなど）   */
    s.id = idbuf[0];

    /* データ部の長さ */
    substr(buf, idbuf, 1, 3);
    s.datalen = atoi(buf);

    /* データ部のモード （1:ASCII or 2:JIS） */
    substr(buf, idbuf, 4, 1);
    s.mode = atoi(buf);

    /* データ（部） */
    substr(s.data, datafield_str, addr + 6, s.datalen);
    if ( s.mode == 1 ) { /* ASCIIだったら */
	ebcdic2ascii(s.data);
    } else if (s.mode == 2 ) { /* JISだったら */
	kanji(s.data);
    } else { /* どちらでもなかったら強制終了 */
	printf("!!!!!! NO MODE !!!!!\n");
	exit(EXIT_FAILURE);
    }
    return s;
}

/* 外字の処理をほどこし、
 * JIS X 0208 漢字をエスケープコードを含めて返す。 */
void  kanji (char str[])
{
    realchange(str, strlen(str)); /* 外字の処理 */
    escape_kanji(str); /* JIS X 0208 漢字をエスケープコードを含める */
}

/* JIS X 0208 漢字をエスケープコードを含めて返す。 */
void  escape_kanji (char str[])
{
    char buf[BUF_SIZE];
    strcpy(buf, str);
    sprintf(str, "%s%s%s", JISC6226_ESC, buf, ASCII_ESC);
}

/* str2 の head から len 文字目までを str1 にコピー */
void substr (char str1[], char str2[], int head, int len)
{
    strncpy(str1, str2 + head, len);
    str1[len] = '\0';
}

/* エントリを取得 */
struct entry get_direntry (char* directory, int num)
{
    struct entry e; /* エントリ */
    int addr; /* エントリの先頭位置 */
    char entry[13], buf[BUF_SIZE];
    
    addr = 12 * num;

    substr(entry, directory, addr, 12);

    /* フィールド識別子 （例: 001, 245 など）*/
    substr(e.field, entry, 0, 3);

    /* フィールド長: データフィールドの長さ FS含む */
    substr(buf, entry, 3, 4);
    e.len = atoi(buf);
    
    /* フィールドの先頭文字の位置: 
       データフィールド群の先頭からの相対位置 */
    substr(buf, entry, 7, 5);
    e.addr = atoi(buf);
    
    return e;
	
}

/* 書誌レコード長を返す
 * 書誌レコード長: レコードラベルの先頭からRSを含めた書誌レコードの長さ*/
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

/* 外字辞書にある文字 → 該当文字, その他の外字 → REPLACE＿STR ,
 * 制御文字 → "", "−" → "長音" の 処理
 * 第一引数 str[]: エスケープシーケンスを含まない2バイトの文字列 */
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
	printf("len:%d is 奇数です\n", len);
	exit(EXIT_FAILURE);
    }
    for (i = 0; i < len; i = i + 2) {	
	strncpy(buf, str + i, 2);
	buf[i + 2] = '\0';
	addr = search(buf, dict, GAIJINUM);
	if ( addr != -1) { /* 外字辞書にある外字の処理 */
#if ANZAI == 1	    
	    strcat(new, dictout[addr]);
#endif	    
#if ANZAI == 0
	    strcat(new, dictout2[addr]);
	} else if( search_otergaiji(buf) != -1) {
	    /* 外字辞書にない外字の処理 */
	    strcat(new, REPLACE_STR); 
	} else if ( (buf[0] == '\x1c') &&
		    (buf[1] >= '\x4e' && buf[1] <= '\x53')) {
	    /* 制御コードなので追加しない */
	} else if (buf[0] =='\x21' && buf[1] == '\x5d') { /* もしマイナスならば */
	    /* マイナスを長音に変更するため前の文字を取ってくる */
	    strncpy(bbuf, str + i - 2, 2);
	    bbuf[i] = '\0';
	    if(( bbuf[0] == '\x24' || bbuf[0] == '\x25')
	       && (bbuf[1] >= '\x21' && bbuf[1] <= '\x76')) {
		/* もし前がカタカナもしくは平仮名だったら */
		strcat(new, "\x21\x3c"); /* 長音に変更 */
	    } else {
		strcat(new, buf); /* そのままマイナスに */
	    }		
#endif	    
	} else { /* 外字がなかったらそのまま追加 */
	    strcat(new, buf);
	}
    }
    strcpy(str, new);
}

/* その他の外字があるか判定 あれば1 なければ-1 */
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
    
/* keyが db にあれば その位置を返す*/
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
