#include <stdio.h>
#include <assert.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>

#define YYDEBUG 1

unsigned short code[4096];
int pc=0;


int yyval;
int line=1;
int errs=0;
int bit32=0;

void declare_label(int ind);
void process_op(int ins);
int ref_label(int ind, int type);

void
chkr(int r) {
	if (r&8)
		return;
	errs++;
	fprintf(stderr, "%d: invalid register\n", line);
	
}

int imm6(int v)
{
	if (v < 0 || v >= (1<<6)) {
		errs++;
		fprintf(stderr, "%d: invalid constant (must be >=0 <64)\n", line);
	}
	return(((v&0x3)<<5) | (((v>>2)&3)<<3) |(((v>>4)&1)<<12) | (((v>>5)&1)<<2));
}

int imm8(int v, int l)
{
	if (!bit32 && v&0x8000)
		v |= 0xffff0000;
	if (v < -(1<<7) || v >= (1<<7)) {
		errs++;
		fprintf(stderr, "%d: invalid constant (must be >=-128 <128)\n", (l?l:line));
	}
	return(((v&0x3)<<5) | (((v>>2)&7)<<10)| (((v>>5)&7)<<2));
}

int roffX(int v)
{
	if (bit32?v&3:v&1) {
		errs++;
		fprintf(stderr, "%d: invalid offset (must be word aligned)\n", line);
		return 0;
	}
	if (bit32) {
		if (v < 0 || v >= (1<<7)) {
			errs++;
			fprintf(stderr, "%d: invalid offset (must be >=0 <128)\n", line);
			return 0;
		}
		return ( (((v>>6)&1)<<5) |  (((v>>2)&1)<<6) | (((v>>3)&7)<<10));
	} else {
		if (v < 0 || v >= (1<<6)) {
			errs++;
			fprintf(stderr, "%d: invalid offset (must be >=0 <64)\n", line);
			return 0;
		}
		return ( (((v>>5)&1)<<5)  | (((v>>1)&1)<<6) | (((v>>2)&7)<<10));
	}	
}

int roff(int v)
{
	if (v < 0 || v >= (1<<5)) {
		errs++;
		fprintf(stderr, "%d: invalid offset (must be >=0 <32)\n", line);
		return 0;
	}
	if (bit32) {
		return ( ((v&1)<<5)  | (((v>>1)&1)<<12) | (((v>>2)&1)<<6) | (((v>>3)&3)<<10));
	} else {
		return ( ((v&1)<<5)  | (((v>>1)&1)<<6) | (((v>>2)&7)<<10));
	}	
}

int offX(int v)
{
	if (bit32?v&3:v&1) {
		errs++;
		fprintf(stderr, "%d: invalid offset (must be word aligned)\n", line);
		return 0;
	}
	if (bit32) {
		if (v < 0 || v >= (1<<9)) {
			errs++;
			fprintf(stderr, "%d: invalid offset (must be >=0 <512)\n", line);
			return 0;
		}
		v >>= 2;
	} else {
		if (v < 0 || v >= (1<<8)) {
			errs++;
			fprintf(stderr, "%d: invalid offset (must be >=0 <256)\n", line);
			return 0;
		}
		v >>= 1;
	}	
	return ( ((v&1)<<6)  | (((v>>1)&1)<<5) | (((v>>2)&3)<<11|(((v>>4)&7)<<2)));
}

int off(int v)
{
	if (v < 0 || v >= (1<<7)) {
		errs++;
		fprintf(stderr, "%d: invalid offset (must be >=0 <128)\n", line);
		return 0;
	}
	if (bit32) {
		return ( ((v&1)<<4)  | (((v>>1)&1)<<6)  | (((v>>2)&1)<<5) | (((v>>3)&3)<<11|(((v>>5)&3)<<2)));
	} else {
		return ( ((v&1)<<11)  | (((v>>1)&7)<<4)|(((v>>4)&1)<<12)|(((v>>5)&3)<<2));
	}	
}

int zoffX(int v)
{
	if (bit32?v&3:v&1) {
		errs++;
		fprintf(stderr, "%d: invalid offset (must be word aligned)\n", line);
		return 0;
	}
	if (bit32) {
		if (v < 0 || v >= (1<<9)) {
			errs++;
			fprintf(stderr, "%d: invalid offset (must be >=0 <512)\n", line);
			return 0;
		}
		v >>= 2;
	} else {
		if (v < 0 || v >= (1<<8)) {
			errs++;
			fprintf(stderr, "%d: invalid offset (must be >=0 <256)\n", line);
			return 0;
		}
		v >>= 1;
	}	
	return ( ((v&1)<<6)  |  (((v>>1)&7)<<10)|(((v>>4)&1)<<5)|(((v>>5)&7)<<7));
}

int addsp(int v)
{
	if (bit32?v&3:v&1) {
		errs++;
		fprintf(stderr, "%d: invalid offset (must be word aligned)\n", line);
		return 0;
	}
	if (bit32) {
		if (v < -(1<<8) || v >= (1<<8)) {
			errs++;
			fprintf(stderr, "%d: invalid offset (must be >=-256 <256)\n", line);
			return 0;
		}
		v >>= 2;
	} else {
		if (v < -(1<<7) || v >= (1<<7)) {
			errs++;
			fprintf(stderr, "%d: invalid offset (must be >=-128 <128)\n", line);
			return 0;
		}
		v >>= 1;
	}	
	return ( ((v&1)<<6)  | (((v>>1)&1)<<5) | (((v>>2)&3)<<11)|(((v>>4)&7)<<2) );
}

int luioff(int v, int l)
{
	if (v&0xff) {
		errs++;
		fprintf(stderr, "%d: invalid constant (must be 256 byte aligned)\n", l?l:line);
		return 0;
	}
	v>>=8;
	if (v < -(1<<6) || v >= (1<<7) ) {
		errs++;
		fprintf(stderr, "%d: invalid constant (must be signed 7 bits)\n", l?l:line);
		return 0;
	}
	return (((v&0x1f)<<2)| (((v>>5)&1)<<12) | (((v>>6)&1)<<11));
}

int lioff(int v)
{
	if (!bit32 && v&0x8000)
		v |= 0xffff0000;
	if (v < -(1<<7) || v >= (1<<7) ) {
		errs++;
		fprintf(stderr, "%d: invalid constant (must be signed 7 bits)\n", line);
		return 0;
	}
	return(((v&0x3)<<5) | (((v>>2)&7)<<10)| (((v>>5)&7)<<2));
}

int yylex(void);
void yyerror(char *err);

#include "vc.tab.c"

struct tab {char *name; int token; };

struct tab reserved[] = {
 	"la", t_la,
 	"lr", t_lr,
	"sp", t_sp,
	"epc", t_epc,
	"csr", t_csr,
	"s0", t_s0,
	"s1", t_s1,
	"a0", t_a0,
	"a1", t_a1,
	"a2", t_a2,
	"a3", t_a3,
	"a4", t_a4,
	"a5", t_a5,
	"and", t_and,
	"or", t_or,
	"xor", t_xor,
	"sub", t_sub,
	"add", t_add,
	"mv", t_mv,
	"nop", t_nop,
	"inv", t_inv,
	"ebreak", t_ebreak,
	"jalr", t_jalr,
	"jr", t_jr,
	"lw", t_lw,
	"lb", t_lb,
	"sw", t_sw,
	"sb", t_sb,
	"lea", t_lea,
	"lui", t_lui,
	"li", t_li,
	"beqz", t_beqz,
	"bnez", t_bnez,
	"bltz", t_bltz,
	"bgez", t_bgez,
	"j", t_j,
	"jal", t_jal,
	"sll", t_sll,
	"srl", t_srl,
	"sra", t_sra,
	"word", t_word,
	"byte", t_byte,
	0, 0
};

struct symbol {
	char *name;
	int offset;
	int index;
	struct symbol *next;
	unsigned char found;	// 0 referenced, 1 defined
};
int sym_index=0;
struct symbol *list=0;

struct reloc {
	int offset;
	int index;
	int line;
	int type;
	struct reloc *next;
};
int reloc_index=0;
struct reloc *reloc_first;
struct reloc *reloc_last;

void
declare_label(int ind)
{
	struct symbol *sp;
	for (sp = list; sp; sp = sp->next) 
	if (sp->index == ind) {
		if (sp->found) {
			errs++;
			fprintf(stderr, "%d: label '%s' declared twice\n", line, sp->name);
		}
//printf("ind=%d offset=%d\n", ind, pc);
		sp->offset = pc<<1;
		sp->found = 1;
		return;
	}
	assert(1);
}
int
ref_label(int ind, int type)
{
	struct reloc *rp;
	rp = malloc(sizeof(*rp));
	rp->offset = pc;
	rp->index = ind;
	rp->line = line-1;
	rp->type = type;
	rp->next = 0;
	if (reloc_last) {
		reloc_last->next = rp;
		reloc_last = rp;
	} else {
		reloc_first = rp;
		reloc_last = rp;
	}
	return 0;
}

void
process_op(int ins)
{
	static int over=0;

	if (pc >= (sizeof(code)/sizeof(code[0]))) {
		if (!over) {
			fprintf(stderr, "%d: ran out of code space\n", line-1);
			errs++;
			over = 1;
		}
		return;
	}
//printf("@%x %o\n", pc, ins);
	code[pc++] = ins;
}

FILE *fin;
int eof=0;

void
yyerror(char *err)
{
	errs++;
	fprintf(stderr, "%d: %s\n", line, err);
}

int
yylex(void)
{
	int c;

	if (eof)
		return 0;
	c = fgetc(fin);
	while (c == ' ' || c == '\t')
		c = fgetc(fin);
	if (c == EOF) {
		eof = 1;
		line++;
		return t_nl;
	} else
	if (c == '/') {
		c = fgetc(fin);
		if (c != '/') {
			ungetc(c, fin);
			return c;
		}
		for (;;) {
			c = fgetc(fin);
			if (c == EOF || c == '\n')
				break;
		}
		line++;
		return t_nl;
	} else
	if (c == '#') {
		for (;;) {
			c = fgetc(fin);
			if (c == EOF || c == '\n')
				break;
		}
		line++;
		return t_nl;
	} else
	if (c == '\n') {
		line++;
		return t_nl;
	} else
	if (c >= '0' && c <= '9') {
		int ind;
		char v[100];
		char c1;
		c1 = c;
		ind = 0;
		v[ind++] = c;
		c = fgetc(fin);
		if (c1 == '0' && (c == 'x' || c == 'X')) {
			v[ind++] = c;
			c = fgetc(fin);
			while (isxdigit(c)) {
				if (ind < (sizeof(v)-1))
					v[ind++] = c; 
				c = fgetc(fin);
			}
			v[ind] = 0;
			ungetc(c, fin);
			yylval = strtol(v, NULL, 16);
		} else
		if (c1 == '0') {
			while (c >= '0' && c <= '7') {
				if (ind < (sizeof(v)-1))
					v[ind++] = c; 
				c = fgetc(fin);
			}
			v[ind] = 0;
			ungetc(c, fin);
			yylval = strtol(v, NULL, 8);
		} else {
			while (isdigit(c)) {
				if (ind < (sizeof(v)-1))
					v[ind++] = c; 
				c = fgetc(fin);
			}
			v[ind] = 0;
			ungetc(c, fin);
			yylval = strtol(v, NULL, 0);
		}
		return t_value;
	} else
	if ((c >= 'a' && c <= 'z') ||
	    (c >= 'A' && c <= 'Z') || c == '_') {		
		int i;
		int ind=0;
		char v[256];
		struct symbol *sp;

		while ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') ||
            	       (c >= 'A' && c <= 'Z') || c == '_' ) {
			if (ind < (sizeof(v)-1))
				v[ind++] = c; 
			c = fgetc(fin);
		}
		ungetc(c, fin);
		v[ind] = 0;
		for (i = 0; reserved[i].name; i++)
		if (strcmp(v, reserved[i].name) == 0)
			return reserved[i].token;
		for (sp = list; sp; sp=sp->next)
		if (strcmp(v, sp->name) == 0) {
			yylval = sp->index;
			return t_name;
		}
		sp = malloc(sizeof(*sp));
		sp->index = sym_index++;
		sp->found = 0;
		sp->name = strdup(v);
		sp->next = list;
		list = sp;
		yylval = sp->index;
		return t_name;
	} else {
		if (c == '/') {
			c = fgetc(fin);
			if (c == '/') {		
				while (c != '\n' && c != EOF)
					c = fgetc(fin);
				return t_nl;
			}
			ungetc(c, fin);
			c = '/';
		}
		return c;
	}
}

int
main(int argc, char **argv)
{
	int i, src_out=0,dump_symbols=0;
	struct reloc *rp;
	char *in_name = 0;
	char *out_name = "a.out";

	yydebug = 0;
	for (i = 1; i < argc; i++) {	
		if (strcmp(argv[i], "-y") == 0) {
			yydebug = 1;
		} else
		if (strcmp(argv[i], "-m") == 0) {
			dump_symbols = 1;
		} else
		if (strcmp(argv[i], "-s") == 0) {
			src_out = 1;
		} else
		if (strcmp(argv[i], "-32") == 0) {
			bit32 = 1;
		} else
		if (strcmp(argv[i], "-o") == 0 && i != (argc-1)) {
			i++;
			out_name = argv[i];
		} else {
			if (in_name) {
				fprintf(stderr, "too many inout files\n");
				errs++;
			}
			in_name = argv[i];
		}
	}

	if (!in_name) {
		fprintf(stderr, "No file specified\n");
		return 1;
	}
	fin = fopen(in_name, "r");
	if (!fin) {
		fprintf(stderr, "Can't open '%s'\n", in_name);
		return 1;
	}
	if (yyparse()) {
		//fprintf(stderr, "%d: syntax error\n", line);
		return 1;
	}
	for (rp = reloc_first; rp; rp = rp->next) {
		struct symbol *sp;
		int found = 0;
		for (sp = list; sp; sp=sp->next) 
		if (rp->index == sp->index) {
			int v, delta;
			found = 1;
			if (!sp->found) {
				errs++;
				fprintf(stderr, "%d: '%s' not defined\n", rp->line, sp->name);
			} else
			switch (rp->type) {
			case 1: code[rp->offset] += sp->offset;
				break;
			case 2:	// jmp
				delta = sp->offset-(rp->offset<<1);
				if (delta < -(1<<10) || delta >= (1<<10)) {
					errs++;
					fprintf(stderr, "%d: '%s' jmp too far\n", rp->line, sp->name);
				} else {
					v = (((delta>>1)&7)<<3) | (((delta>>4)&1)<<11) | (((delta>>5)&1)<<2) | (((delta>>6)&1)<<7) | (((delta>>7)&1)<<6) | (((delta>>8)&3)<<9)| (((delta>>10)&1)<<8) | (((delta>>11)&1)<<12);
//printf("reloc[%d] delta=0x%d v=0x%x line=%d '%s'\n", rp->offset, delta, v, rp->line, sp->name);
					code[rp->offset] |= v;
				}
				break;
			case 3:	// branch
				delta = sp->offset-(rp->offset<<1);
				if (delta < -(1<<6) || delta >= (1<<6)) {
					errs++;
					fprintf(stderr, "%d: '%s' branch too far\n", rp->line, sp->name);
				} else {
					v = (((delta>>1)&3)<<3) | (((delta>>3)&3)<<10) | (((delta>>5)&1)<<2) | (((delta>>6)&3)<<5) | (((delta>>8)&1)<<12);
					code[rp->offset] |= v;
				}
				break;
			case 4:	// la lui part
				delta = sp->offset;
				if (delta >= (1<<15)) {
					errs++;
					fprintf(stderr, "%d: '%s' la too far\n", rp->line, sp->name);
				} else {
					if (delta&0x80) {
						delta = (delta&~0xff)+0x100;
					} else {
						delta = delta&~0xff;
					}
					code[rp->offset] |= luioff(delta, rp->line);
				}
				break;
			case 5:	// la add part
				delta = sp->offset&0xff;
				if (delta&0x80) 
					delta = -(0x100-delta);
				code[rp->offset] |= imm8(delta, rp->line);
				break;
			}
		}
		assert(found);
	}
	if (!errs) {
		if (src_out) {
			FILE *fout = fopen(out_name, "wb");
			if (fout) {
				for (i = 0; i < pc; i++) {
					fprintf(fout, "	m[16'h%02x] = 8'h%02x;\n", i*2, code[i]&0xff);
					fprintf(fout, "	m[16'h%02x] = 8'h%02x;\n", i*2+1, (code[i]>>8)&0xff);	
				}
				fclose(fout);
			} else {
				fprintf(stderr, "Can't open output file '%s'\n", out_name);
				errs++;
			}
		} else {
			FILE *fout = fopen(out_name, "w");
			if (fout) {
				fwrite(code, 1, pc*2, fout);	
				fclose(fout);
			} else {
				fprintf(stderr, "Can't open output file '%s'\n", out_name);
				errs++;
			}
		}
		if (dump_symbols) {
			struct symbol *sp;
			for (sp = list; sp; sp=sp->next) 
				fprintf(stderr, "'%s':	%04x\n", sp->name, sp->offset);
		}
	}
	return errs != 0?1:0;
}
