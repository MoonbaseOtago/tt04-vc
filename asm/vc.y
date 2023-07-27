%token t_la t_lr t_value t_sp t_epc t_csr t_s0 t_s1 t_a0 t_a1 t_a2 t_a3 t_a4 t_a5 t_and t_or t_xor t_sub t_add t_mv t_nop t_inv t_ebreak t_jalr t_jr t_lw t_lb t_sw t_sb t_lea t_lui t_li t_beqz t_bnez t_bltz t_bgez t_j t_jal t_sll t_srl t_sra t_word t_byte t_name t_nl 
%start  program
%%

exp:		e1 '+' exp		{ $$ = $1 + $3; }
	|	e1 '-' exp		{ $$ = $1 - $3; }
	|	e1			{ $$ = $1; }
	;

e1:		e2 '*' e1		{ $$ = $1 * $3; }
	|	e2 '/' e1		{ $$ = ($3==0?0:$1 / $3); }
	|	e2			{ $$ = $1; }
	;
e2:		'+' e2 			{ $$ = $2; }
	|	'-' e2 			{ $$ = -$2; }
	|	'(' exp ')' 		{ $$ = $2; }
	|	t_value 		{ $$ = $1; }
	;

xr:		rm 			{ $$ = 8|$1; }
	|	rx			{ $$ = $1; }
	;

rx: 		t_lr			{ $$ = 1; }
	|	t_epc			{ $$ = 3; }
	|	t_csr			{ $$ = 4; }
	;
r:		xr			{ $$ = $1; }
	|	t_sp			{ $$ = 2; }
	;
rm:		t_s0 			{ $$ = 0; }
	|	t_s1 			{ $$ = 1; }
	|	t_a0			{ $$ = 2; }
	|	t_a1			{ $$ = 3; }
	|	t_a2			{ $$ = 4; }
	|	t_a3			{ $$ = 5; }
	|	t_a4			{ $$ = 6; }
	|	t_a5			{ $$ = 7; }
	;

ins:		t_and  rm ',' rm 	{ $$ = 0x8c61|($2<<7)|($4<<2); }      
	|	t_or  rm ',' rm         { $$ = 0x8c41|($2<<7)|($4<<2); } 
	|	t_xor  rm ',' rm        { $$ = 0x8c21|($2<<7)|($4<<2); } 
	|	t_sub  rm ',' rm        { $$ = 0x8c01|($2<<7)|($4<<2); } 
	|	t_and  rm ',' exp	{ $$ = 0x8801|($2<<7)|imm6($4); }
	|	t_add  t_sp ',' exp 	{ $$ = 0x6101 | addsp($4); }
	|	t_add  t_sp ',' r       { $$ = 0x8002|(2<<7)|($4<<2); } 
	|	t_add  rm ',' exp	{ $$ = 0x0001|($2<<7)|imm8($4, 0); }
	|	t_add  rm ',' r        	{ $$ = 0x9002|((8|$2)<<7)|($4<<2); } 
	|	t_add  rx ',' r        	{ $$ = 0x9002|($2<<7)|($4<<2); } 
	|	t_mv   r ',' r        	{ $$ = 0x8002|($2<<7)|($4<<2); } 
	|	t_nop  			{ $$ = 0x0001; }
	|	t_inv  		 	{ $$ = 0x0000; }
	|	t_ebreak  		{ $$ = 0x9002; }
	|	t_jalr r  		{ $$ = 0x9002|($2<<7); }
	|	t_jr r  		{ $$ = 0x8002|($2<<7); }
	|	t_lw r ',' exp '(' t_sp ')'{ $$ = 0x4002|($2<<7)|offX($4); }
	|	t_lw r ',' '(' t_sp ')'	{ $$ = 0x4002|($2<<7)|offX(0); }
	|	t_lb r ',' exp '(' t_sp ')'{ $$ = 0x6002|($2<<7)|off($4); chkr($2); }
	|	t_lb r ',' '(' t_sp ')'	{ $$ = 0x6002|($2<<7)|off(0); chkr($2); }
	|	t_lw r ',' exp '(' rm ')'{ $$ = 0x4000|($6<<7)|roffX($4)|(($2&7)<<2); chkr($2); }
	|	t_lw r ',' '(' rm ')'	{ $$ = 0x4000|($5<<7)|roffX(0)|(($2&7)<<2); chkr($2); }
	|	t_lb r ',' exp '(' rm ')'{ $$ = 0x6000|($6<<7)|roff($4)|(($2&7)<<2); chkr($2); }
	|	t_lb r ',' '(' rm ')'	{ $$ = 0x6000|($5<<7)|roff(0)|(($2&7)<<2); chkr($2); }
	|	t_sw r ',' exp '(' t_sp ')'{ $$ = 0xc002|($2<<7)|offX($4); }
	|	t_sw r ',' '(' t_sp ')'	{ $$ = 0xc002|($2<<7)|offX(0); }
	|	t_sb r ',' exp '(' t_sp ')'{ $$ = 0xe002|($2<<7)|off($4); chkr($2); }
	|	t_sb r ',' '(' t_sp ')'	{ $$ = 0xe002|($2<<7)|off(0); chkr($2); }
	|	t_sw r ',' exp '(' rm ')'{ $$ = 0xc000|($6<<7)|roffX($4)|(($2&7)<<2); chkr($2); }
	|	t_sw r ',' '(' rm ')'	{ $$ = 0xc000|($5<<7)|roffX(0)|(($2&7)<<2); chkr($2); }
	|	t_sb r ',' exp '(' rm ')'{ $$ = 0xe000|($6<<7)|roff($4)|(($2&7)<<2); chkr($2); }
	|	t_sb r ',' '(' rm ')'	{ $$ = 0xe000|($5<<7)|roff(0)|(($2&7)<<2); chkr($2); }
	|	t_lea rm ',' exp '(' t_sp ')' { $$ = 0x0000 | ($2<<2) | zoffX($4); }
	|	t_lea rm ',' '(' t_sp ')'{ $$ = 0x0000 | ($2<<2) | zoffX(0); }
	|	t_lui    rm ',' exp	{ $$ = 0x6001 | ((8|$2)<<7) | luioff($4,0); }	
	|	t_li     rm ',' exp	{ $$ = 0x4001 | ($2<<7) | lioff($4); }
	|	t_beqz	rm ',' t_name	{ $$ = 0xc001 | ($2<<7); ref_label($4, 3); }
	|	t_bnez	rm ',' t_name	{ $$ = 0xe001 | ($2<<7); ref_label($4, 3); }
	|	t_bltz	rm ',' t_name	{ $$ = 0xe003 | ($2<<7); ref_label($4, 3); }
	|	t_bgez	rm ',' t_name	{ $$ = 0xc003 | ($2<<7); ref_label($4, 3); }
	|	t_j	t_name		{ $$ = 0xa001; ref_label($2, 2); }
	|	t_jal	t_name		{ $$ = 0x2001; ref_label($2, 2); }
	|	t_sll	rm 		{ $$ = 0x0002 | ($2<<7); }
	|	t_srl	rm 		{ $$ = 0x8001 | ($2<<7); }
	|	t_sra	rm 		{ $$ = 0x8401 | ($2<<7); }
	|	t_la	rm ',' t_name	{ ref_label($4, 4); code[pc++] = 0x6001|((8|$2)<<7); $$ = 0x0001 | ($2<<7); ref_label($4, 5); }
	|	'.' t_word exp		{ $$ = $3; }
	|	'.' t_word t_name 	{ $$ = 0; ref_label($3, 1);}
	|	'.' t_word t_name '+' exp { $$ = $5; ref_label($3, 1); }
	;


label:		t_name ':'		{ declare_label($1); }
	;

line:		label t_nl 		
	|	label ins t_nl		{ process_op($2);  }
	|	ins t_nl		{ process_op($1);  }
	|	'.' '=' exp t_nl	{ pc = $3/2; }
	|	'.' '=' '.' '+' exp t_nl{ pc += $5/2; }
	|	t_nl
	;

program:	line
	|	program line
	;
