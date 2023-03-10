;Second Program - Mason Lane, 16/09/2020

;ARM1.s Source code for my first program on the ARM Cortex M3
;Function Modify some registers so we can observe the results in the debugger
;Author - Dave Duguid
;Modified September 2020 Mason Lane
; Directives
	PRESERVE8
	THUMB

INITIAL_MSP EQU 0x20001000

; Vector Table Mapped to Address 0 at Reset, Linker requires __Vectors to be exported
	AREA RESET, DATA, READONLY
	EXPORT 	__Vectors


__Vectors DCD INITIAL_MSP
		  DCD Reset_Handler ; reset vector
	 
	
		  ALIGN


;My program, Linker requires Reset_Handler and it must be exported
	AREA MYCODE, CODE, READONLY
	ENTRY

	EXPORT Reset_Handler
		
		
Reset_Handler PROC
	LDR R0, = 0xF000000F 	;Should not be 1
	BL part1a				
	
    LDR R0, = 0xF0F0FFF0 	;Should be 1
	BL part1a				
	
	LDR R0, = 0xfe0			;r0 is now 111111100000. we expect 111101101000
	BL part1b				
	BL part1b				;do it a second time, to ensure nothing changes given 111101101000
	
	
	LDR R0, = 0xF0F0FFF0 	
	LDR R1, = 0x0			;Empty R1
	BL part1c				;expect 20

	
	;Try left
	LDR R0, = 0x12345678	
	LDR R1, = 0x11
	LDR R2, = 0x0			
	
	BL rot_left_right		;Branch to Phase2 Function
	
	;Try right
	LDR R0, = 0x12345678	
	LDR R1, = 0x01
	LDR R2, = 0x0			
	
	BL rot_left_right		;Branch to Phase2 Function
	
	
	ENDP

	ALIGN
part1a PROC
	AND R1, R0, #0x800	;0x800 is a mask. We will then only have a 1 at 11 bits, or 0.
	LSR R1, R1, #11		;Since our number's msb will be the 11th bit, shift to get msb
	
	BX LR				;Return to Reset_Handler
	ENDP	
	ALIGN
		
part1b PROC
	ORR R0, R0, #0x8			;keep a 1 if it exists, or fill with 0x8 - which is 1000
	AND R0, R0, #0xFFFFFF7F		;In a 32 bit number, keep all but the 7th bit using this mask 11111111111111111111111101111111
	
	BX LR						;Return to Reset_Handler
	ENDP
	ALIGN
part1c PROC
	
	push {R0}		;R0 shouldn't be changed after the funtion
						;R2 is a temporarily used Register

	mov R1, R0, lsr#31	;R2 contains the MSB of input R0
loop
	movs R0,R0,lsl #2	;shift right by 2. set flags
	adc R1,R1,R0,lsr #31
	bne loop			;loop if non-zero
	pop {R0}
	BX LR				;Return to Reset_Handler

	ENDP
	ALIGN


;R0 contains input value
;R1 contains input shift and direction
;R2 is our Output
;R3 used for saving the top and bottom 16 bits at different stages
;R4 used for chosing shift direction, and amount for shift
rot_left_right PROC
	
	push {R5,R6,R7,R8}
	
	LDR R8, = 0xFFFF	;Mask of right half 
	AND R5, R0, R8		;and mask with R0, splitting r0 in half. Save bottom half to r5
	AND R6, R1, #0x10	;save shift direction in R6
	LSR R6, R6, #4		;shift msb right, making r6 1 or 0	
	AND R7, R1, #0xF	;get bits 3:0, the magnitude of shift
	
	CMP R6, #0		    ;0 means right, else left. 
	BNE left		
						
	LSR R5, R5, R7		;Shift right by magnitude
	B merge				

left
	LSL R5, R5, R7		;Shift left by magnitude
	AND R5, R5, R8		;Use mask to capture the 16bit lower half. ignore the rest that was shifted.
	
merge
	MOV R2, R5				;Save our bottom half to our R2 answer

	LDR R8, = 0xFFFF0000	;Mask for leftmost 16 bits
	AND R5, R0, R8			;Use mask to capture leftmost 16 bits of input
	ADD R2, R5				;Use add to merge. we stored the bottom half, now add r5 (top half) 
	pop {R5,R6,R7,R8}		;Reset registers
	BX LR			
	
	ENDP