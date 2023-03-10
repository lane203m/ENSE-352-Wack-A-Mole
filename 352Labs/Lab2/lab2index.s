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
		
		
Reset_Handler PROC;We only have one line of actual application code

	BL Part1
	BL factorial

String1
	DCB "ENSE 352 is fun and I am learning ARM assembly!",0
	LDR R0, = String1

String2
	DCB "Yes I really love it!",0
	LDR R1, = String2


	LDR R4, =0
	MOV R2, R0
	BL countVowels
	MOV R5, R4

	LDR R4, =0
	MOV R2, R1
	BL countVowels
	MOV R6, R4
	

	
	B Reset_Handler
	ENDP
	
Part1	PROC

	LDR R1, = 0x00001111 ; Load the number into R1
	LDR R2, = 0x00002222 ; Load the number into R2
	LDR R3, = 0x00003333 ; Load the number into R3
	
	PUSH {R1}	;as we push, the SP will decrease
	PUSH {R2}
	PUSH {R3}
	
	POP {R3}	;as we pop, the SP will increase 
	POP {R2}
	POP {R1}
	
	PUSH {R1, R2, R3}	;the sp will decrease the same ammount
	POP {R3, R2, R1}	;the sp will return to before
	BX LR
	ENDP


factorial	PROC
	LDR R1, = 5		;This is our input. We expect 5!, or 1*2*3*4*5

	
	LDR R3, = 1		;We set the factorial answer to 1, since all factorial will begin with ! 
	
	LDR R2, = 1		;This is our loop  pointer
	ADD R4, R1, #1	;This is our loop goal, derived from the input
loop
	ADD R2, #1		;Increment the factorial (what we multiply by)
	
	MUL R3, R2		;Multiply
	CMP R2, R1		;Is our pointer the same as our goal?
	BNE loop
	
	BX LR
	ENDP
		
vowelDetected PROC
	ADD R4, #1
	
	B countVowels
	BX LR
	ENDP
	
countVowels PROC
	
	LDRB R3, [R2]
	
	ADD R2,  #1
	
	CMP R3, #'a'
	BEQ vowelDetected
	CMP R3, #'A'
	BEQ vowelDetected
	CMP R3, #'e'
	BEQ vowelDetected
	CMP R3, #'E'
	BEQ vowelDetected
	CMP R3, #'i'
	BEQ vowelDetected
	CMP R3, #'I'
	BEQ vowelDetected
	CMP R3, #'o'
	BEQ vowelDetected
	CMP R3, #'O'
	BEQ vowelDetected
	CMP R3, #'u'
	BEQ vowelDetected
	CMP R3, #'U'
	BEQ vowelDetected
	
	CBZ R3, endLoop
	
	B countVowels
endLoop
	BX LR
	ENDP
		
		
	ALIGN
		
	END
	


	
