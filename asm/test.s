	.=0	
	j	start
	.=4	
	j	trap
	.=8
	j 	intr
intr:	j	intr
trap:	j	trap
start:
	li	a0, 5
	li 	a1, 6
	li	a5, 0xfffe	// fffe - address for tests
l:		add a1, -1
		bnez a1, l
	add	a1, a0
	la	a2, loc
	lw	a3, (a2)	// 0099	
	sw	a3, (a5)
	lb	a3, (a2)	// ff99
	sw	a3, (a5)
	sw	a3, 2(a2)	// ff99
	lw	a4, 2(a2)	// ff99
	sw	a4, (a5)

	li 	a0, 0x55
	sb 	a0, 3(a2)	
	lw	a4, 2(a2)	// 5599
	sw	a4, (a5)
	lb	a1, 3(a2)	// 0055
	sw	a1, (a5)

	li	a0, 0x33
	li	a2, 0x55
	or	a2, a0		// 0077
	sw	a2, (a5)
	li	a2, 0x55
	and	a2, a0		// 0011
	sw	a2, (a5)
	li	a2, 0x55
	xor	a2, a0		// 0066
	sw	a2, (a5)
	li	a2, 0x5
	and	a2, 0x3		// 0001
	sw	a2, (a5)

	li	a2, 0x5
	li	a0, 0x3
	sub	a2, a0		// 0002
	sw	a2, (a5)

	li	a2, 1
	jal	subr
	add	a2, 1
	sw	a2, (a5)	// 4

	la	a0, subr
	jalr	a0
	add	a2, 1
	sw	a2, (a5)	// 7

	la	a0, loc
	mv	sp, a0
	lw	a1, 2(sp)	// 5599
	sw	a1, (a5)	
	add	sp, 2
	lw	a2, (sp)	// 5599
	sw	a1, (a5)	
	add	a2, 1
	sw	a2, 2(sp)	// 559a
	add	sp, -2
	lea	a1, 4(sp)	// loc+4
	lw	a1, (a1)	// 559a
	sw	a1, (a5)	
	
	li 	a0, 0
	li 	a1, 0
	bgez	a0, b1
		li a1, 1
b1:				// should be 0
	sw	a1, (a5)	
	li 	a0, -1
	bgez	a0, b2
		li a1, 2
b2:				// should be 2
	sw	a1, (a5)	
	li 	a1, 0
	li 	a0, 1
	bgez	a0, b3
		li a1, 3
b3:				// should be 0
	sw	a1, (a5)	
	li 	a1, 0
	li	a0, 0
	bltz	a0, b4
		li a1, 4
b4:				// should be 4
	sw	a1, (a5)	
	li 	a1, 0
	li	a0, -1
	bltz	a0, b5
		li a1, 5
b5:				// should be 0
	sw	a1, (a5)	
	li 	a1, 0
	li	a0, 1
	bltz	a0, b6
		li a1, 6
b6:				// should be 6
	sw	a1, (a5)	
	li 	a1, 0
	li	a0, 1
	bnez	a0, b7
		li a1, 7
b7:				// should be 0
	sw	a1, (a5)	
	li 	a1, 0
	li	a0, 0
	bnez	a0, b8
		li a1, 8
b8:				// should be 8
	sw	a1, (a5)	
	li 	a1, 0
	li	a0, -1
	bnez	a0, b9
		li a1, 9
b9:				// should be 0
	sw	a1, (a5)	
	li 	a1, 0
	li	a0, 1
	beqz	a0, b10
		li a1, 10
b10:				// should be 10
	sw	a1, (a5)	
	li 	a1, 0
	li	a0, 0
	beqz	a0, b11
		li a1, 11
b11:				// should be 0
	sw	a1, (a5)	
	li 	a1, 0
	li	a0, -1
	beqz	a0, b12
		li a1, 12
b12:				// should be 12
	sw	a1, (a5)	

	li 	s0, -3
	sra	s0
	sw	s0, (a5)	// fffe
	li 	s0, -3
	srl	s0
	sw	s0, (a5)	// 7ffe
	li 	s0, -3
	sll	s0
	sw	s0, (a5)	// fffa
	ebreak

loc:	.word	0x99
	.word	0x55
	.word	0x0
	.word	0x0
	.word	0x0
	.word	0x0
	.word	0x0

subr:	add	a2, 2
	jr	lr
