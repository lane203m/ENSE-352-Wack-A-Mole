;First Program - Mason Lane, 16/09/2020

;ARM1.s Source code for my first program on the ARM Cortex M3
;Function Modify some registers so we can observe the results in the debugger
;Author - Dave Duguid
;Modified September 2020 Mason Lane
; Directives
	PRESERVE8
	THUMB
		
; Vector Table Mapped to Address 0 at Reset, Linker requires __Vectors to be exported
	AREA RESET, DATA, READONLY
	EXPORT 	__Vectors


__Vectors DCD 0x20002000 ; stack pointer value when stack is empty
	DCD Reset_Handler ; reset vector
	
	ALIGN


;My program, Linker requires Reset_Handler and it must be exported
	AREA MYCODE, CODE, READONLY
	ENTRY

	EXPORT Reset_Handler
		
		
Reset_Handler ;We only have one line of actual application code

	MOV  R0, #0x76 
	LDR R1, =0x35555555 ; Load the number into R0
	LDR R2, =0x13333333 ; Load the number into R1

	ADDS R3, R2, R1

	LDR R3, =0xFFFFFFFF
	;SUBS R3, R2, R2   ;Flags C and Z are set to 1. C=1 because we undergo a carry (unsigned overflow) In this case, we overflow our result register
					  ;Note, S is an optional suffix. If S is specified, the condition flags are updated on the result of the operation.
	ADDS R3, R1, R2   ;Flags C and Z are set to 1. C=1 because we undergo a carry (unsigned overflow) In this case, we overflow our result register
					  ;Note, S is an optional suffix. If S is specified, the condition flags are updated on the result of the operation.
					  ;The xPSR code is 0x21000000
	ADDS R1, R2, R3   ;In this case, we undergo a carry. However, the result is not zero. So our flags are C=1. Z=0 since R1 is not 0
	LDR R2, =0x2
	
	
					  ;The xPSR code is 0x21000000
	
	endp
	
	ALIGN
		
	END