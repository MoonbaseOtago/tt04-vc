![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg)

# VC - a RISC-V C native ISA

This project is essentially a what-if - What if the RISC-V compressed instruction set was a self
contained ISA of its own? a bit like an ARM thumb native chip.

This CPU is a quick and dirty chip for Tiny Tapeout, it's not optimised for speed or size.

This spec is for two variants:
- a 16-bit chip (built here for TT)
- a 32-bit chip - essentially 32-bit registers, with minor changes to offsets in lw/sw/etc to 4 bytes

## Architecture

This chip has 8 general purpose registers: s0,s1,a0,a1,a2,a3,a4,a5. And 4 special purpose ones: lr, sp, epc, csr.

All instructions can access the general purpose registers, only some can access the special purpose ones, in particular:
- mv rm, rm 
- lw/sw rm, off(sp)
- jr rm
- lr is written by jal/jalr
- sp is used by load/store to sp, add to sp, and lea
- epc is set by traps
- csr currently only contains an interrupt enable bit, set/cleared when epc is used

## traps/interrupts

Reset sets the PC to 0, traps (currently invalid instruction, ebreak) jump to 4, interrupts (with interrupts enabled) jump to 8.

traps and interrupts save the next PC in EPC and clear the IE flag, the old IE flag is saved in EPC[0]. jr epc executes a return from interrupt/exception, IE is restored from EPC[0]. IE can be set/cleared by writing
a new value to csr[0].

An ISR might execute something like:

        add   sp, -4
        sw    epc, (sp)
        .... handle interrupt, maybe turn interrupts on while processing
        lw    epc, (sp)		
        add   sp, 4
        jr    epc

Or if it's quick and doesn't want to be reentrant:
	
        .... handle interrupt, don't turn interrupts on while processing
        jr    epc


## Differences from RISC-V C extension

- Memory instructions only come in lw/sw and lb/sb versions (lb/sb replace ld/sd) words are 16 or 32-bits
- offsets one lw/sw instructions are multiples of 2 or 4 bytes depending on the word size
- instructions that have 5-bit register fields are now 4-bit (or 3 in some cases), those unused bits are
repurposed into upper bits of constants or offsets
- addisp4n (now called "lea") is an offset of 2 or 4 depending on word size
- addi16sp (now called "add sp, V") is a multiple of 2 or 4 depending on word size
- srl/sra/sll shift by 1 bit
- lwsp (et al) (now called "lw r, of(sp)" has offsets which are multiples of 2/4 depending on word size
- bgez and bltz have been added

Register numbers:
|Register|3-bit number|4-bit number|
|:-------|:----------:|-----------:|
|0 |-|0|
|lr|-|1|
|sp|-|2|
|epc|-|3|
|csr|-|4|
|s0|0|8|
|s1|1|9|
|a0|2|10|
|a1|3|11|
|a2|4|12|
|a3|5|13|
|a4|6|14|
|a5|7|15|

## Encodings

|15:13|12   |11   |10   |9:7  |6:5  |4:2  |1:0  |Instruction		| Constant 	|
|:----|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---------------------:|		|
|000  |0    |0    |0    |0    |0    |0    |00   | illegal instruction 	|				|
|000  |C    |C    |C    |C    |C    |RD   |00   | lea RD, C(SP)         | U 9:7-5-12:10-6-W		|
|010  |C    |C    |C    |RS1  |C    |RD   |00   | lw RD, C(RS1)		| U 5-12:10-6-W			|
|011  |C    |C    |C    |RS1  |C    |RD   |00   | lb RD, C(RS1)		| U   12:10-6-5 / 11:10-6-12-5	|
|110  |C    |C    |C    |RS1  |C    |RS2  |00   | sw RS2, C(RS1)	| U 5-12:10-6-W			|
|111  |C    |C    |C    |RS1  |C    |RS2  |00   | sb RS2, C(RS1)	| U   12:10-6-5 / 11:10-6-12-5    |
|000  |0    |0    |0    |0    |0    |0    |01   | nop		 	|				|
|000  |C    |C    |C    |RD   |C    |C    |01   | add RD, C		| S 11-10:12-6:2		|
|001  |C    |C    |C    |C    |C    |C    |01   | jal PC+C		| S 12-8-10:9-6-7-2-11-5:3	|
|010  |C    |C    |C    |RD   |C    |C    |01   | li RD, C		| S 11:10-12-6:2 		|
|011  |C    |C    |0    |2    |C    |C    |01   | add sp, C		| S 11-12-4:3-5-2-6-W		|
|011  |C    |C    |1    |RD   |C    |C    |01   | lui RD, C		| S 11-12-6:2-00000000  	|
|100  |0    |0    |0    |RD   |0    |0    |01   | srl RD		|   				|
|100  |0    |0    |1    |RD   |0    |0    |01   | sra RD		|   				|
|100  |C    |1    |0    |RD   |C    |C    |01   | and RD, C		| U 12-6:2			|
|100  |0    |1    |1    |RD   |00   |RS2  |01   | sub RD, RS2		| 				|
|100  |0    |1    |1    |RD   |01   |RS2  |01   | xor RD, RS2		|   				|
|100  |0    |1    |1    |RD   |10   |RS2  |01   | or RD, RS2		|   				|
|100  |0    |1    |1    |RD   |11   |RS2  |01   | and RD, RS2		|   				|
|101  |C    |C    |C    |C    |C    |C    |01   | j PC+C		| S 12-8-10:9-6-7-2-11-5:3	|
|110  |C    |C    |C    |RS1  |C    |C    |01   | beqz PC+C		| S 12-6:5-2-11:10-4:3 		|
|111  |C    |C    |C    |RS1  |C    |C    |01   | bnez PC+C		| S 12-6:5-2-11:10-4:3 		|
|000  |0    |0    |0    |RD   |0    |0    |10   | sll RD	 	|				|
|010  |C    |C    |RD   |RD   |C    |C    |10   | lw RD, C(sp)		| U 11-3:2-12-6:4-W		|
|011  |C    |C    |C    |RD   |C    |C    |10   | lb RD, C(sp)		| U 3:2-12-6:4-11/U 2-12-6:4-11-3 |
|100  |0    |0    |0    |RS1  |0    |0    |10   | jr RS1		|   				|
|100  |0    |0    |RD   |RD   |0,RS2|RS2  |10   | mv RD, RS2		|  				|
|100  |1    |0    |0    |RS1  |0    |0    |10   | jalr RS1		|   				|
|100  |1    |0    |0    |RD   |0    |RS2  |10   | add RD, RS2		|   				|
|110  |C    |C    |C    |C    |0RS2 |RS2  |10   | sw RS2, C(sp)		| U 11-3:2-12-6:4-W		|
|111  |C    |C    |C    |C    |C    |RS2  |10   | sb RS2, C(sp)		| U 3:2-12-6:4-11/U 2-12-6:4-11-3 |
|110  |C    |C    |C    |RS1  |C    |C    |11   | bgez PC+C		| S 12-6:5-2-11:10-4:3		| 
|111  |C    |C    |C    |RS1  |C    |C    |11   | bltz PC+C		| S 12-6:5-2-11:10-4:3		|
