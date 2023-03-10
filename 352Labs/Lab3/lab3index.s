;;; Equates
end_of_stack	equ 0x20001000			;Allocating 4kB of memory for the stack
RAM_START		equ	0x20000000


;;; Includes
	;; empty

;;; Vector definitions

	area vector_table, data, readonly
__Vectors
	DCD	0x20002000		; initial stack pointer value
	DCD	Reset_Handler	; program entry point
	export __Vectors

	align

;;; Our mainline code begins here
	area	mainline, code
	entry
	export	Reset_Handler

;;; Procedure definitions

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Description:
;;;
Reset_Handler proc
	;; Copy the string of characters from flash to RAM buffer so it 
	;; can be sorted

	;;bl normalSub
	
	ldr r1,=string1
	mov r2,#RAM_START
	mov r3,#string1size
	bl byte_copy
	
	mov r1, r2
	add r2, #25			;Arbitrary offset,as long as buffers r1 and and r2 don't overlap.
	bl sort
  

	
	
	;; we are finished
doneMain	b	doneMain		; finished mainline code.
	endp
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
string1
	dcb	"EBFZACGLDA"
string1size	equ . - string1

	align
size1
	dcd	string1size
	


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	ALIGN
sort PROC

	;; include here the body of your routine
	ldr		r10,=end_of_stack
	subs 	r10,sp,r10			;R10 contains number of bytes available in stack			
	cmp		r10,#36 			;this subroutine requires at least 9 words (36 bytes) of free space in the stack 
	bgt		no_overflow
	mov		r10,#1				;not enough space in stack for this procedure
	bx 		lr


no_overflow
	mov r10,#0					;good, no errors
	cmp r3, #1
	ble endSort					;end if string is size 1
	
	cmp r3, #2
	bne splitArray				;split if our string, or splitstring is larger than 2 
	push{r1,r2,r3}				;remember the result of our split or string. For now, r1,r2,r3 is a split array or our string
	
	ldrb r2, [r1]				;r2 is first letter
	ldrb r3, [r1 , #1]			;r3 is last letter
	
	;Sort R2 and R3 and store them back into RAM
	cmp r2, r3					;check which one is larger
	bgt r2Greater
	
								;r2 < r3
	strb r2, [r1]						
	strb r3, [r1 , #1]
	
	pop {r1, r2, r3}
	b endSort
	
r2Greater
								;r2 > r3
	strb r3, [r1]
	add r1, #1
	strb r2, [r1]
	
	pop {r1, r2, r3}
	b endSort
	

splitArray 
	push {r1, r2, r3, r4, r5, r6, r7}		
	push {r1, r2, r3}
	
	lsr r3, #1						;r3 == r3/2
	
	
	push {LR}						;remember this spot
	bl sort							;sort
	pop {LR}	
	mov r4, r1						;r4 (sublist1) is ptr input array
	mov r5, r3						;size of sublist1 size
	
	
	pop {r1, r2, r3}				;resetting to our previous r1,r2,r3 (before sort)
	push {r1, r2, r3}

	add r1, r1, r5					;r1 (sublist2) = r1(ptr input) + size of sublist 1		
	lsr r3, #1						;size_sublist2 = size_input_array / 2 

	push {LR}
	bl sort
	pop {LR}

	
	mov r6, r1						;r6 (sublist2) is ptr input array
	mov r7, r3						;size of sublist2 
	
	pop {r1, r2, r3}				;reset to our previous r1
	
	;ptr_sorted_array = merge (ptr_sublist1, ptr_sublist2, size_input_array)
	;R1: pointer to an auxiliary buffer
	mov r1, r2

	mov r2, r4						;r2 is sublist1
	mov r4, r6						;r4 is sublist2
	mov r6, r7						;r6 is sublist2 size. We already store sublist 1 size in r5
	
	push {LR}
	bl merge					    ;r1 = buffer, r2 = sublist1 r4= sublist2 r5 = sublist1Size, r6 = sublist2Size
	pop {LR}
	and r9, r3, #1
	cmp r9, #1
	;push {r1, r2, r3, r4, r5, r6, r7}	
	bne notOdd
	
	pop {r1, r2, r3}				;resetting to our previous r1,r2,r3 (before sort)
	push {r1, r2, r3}

	add r1, r1, r5					;r1 (sublist2) = r1(ptr input) + size of sublist 1	
	mov r3, #1						;size_sublist2 = size_input_array / 2 

	push {LR}
	bl sort
	pop {LR}

	
	mov r6, r1						;r6 (sublist2) is ptr input array
	mov r7, r3						;size of sublist2 
	
	pop {r1, r2, r3}				;reset to our previous r1
	push {r1, r2, r3}
	mov r4, r1						;r4 (sublist1) is ptr input array
	mov r5, r3						;size of sublist1 size
	sub r5, r3, #1
	
	;ptr_sorted_array = merge (ptr_sublist1, ptr_sublist2, size_input_array)
	;R1: pointer to an auxiliary buffer
	pop {r1, r2, r3}
	
	mov r1, r2

	mov r2, r4						;r2 is sublist1
	mov r4, r6						;r4 is sublist2
	mov r6, r7						;r6 is sublist2 size. We already store sublist 1 size in r5
	
	push {LR}
	bl merge					    ;r1 = buffer, r2 = sublist1 r4= sublist2 r5 = sublist1Size, r6 = sublist2Size
	pop {LR}
	
	mov r5, r1
	mov r1, r2
	mov r2, r5
	
	push{r1, r2, r3}
	;pop {R1, R2, R3, R4, R5, R6, R7}
notOdd
	
	
	pop {R1, R2, R3, R4, R5, R6, R7}		

	
endSort		

	bx	lr
	
	ENDP



	ALIGN
byte_copy  	PROC
			push {r1,r2,r3,r4}

			mov r5, #0
loop
		ldrb r4, [r1]
			strb r4, [r2]
	
			add r1,#1
			add r2,#1
			add r5,#1
			cmp r3,r5
			bne loop
    
			pop	{r1,r2,r3,r4}
			bx	lr
			ENDP











	ALIGN
merge		PROC
			
			;;;checking if there is enough space in stack
			ldr		r10,=end_of_stack
			subs 	r10,sp,r10			;R10 contains number of bytes available in stack			
			cmp		r10,#36				;this subroutine requires at least 9 words (36 bytes) of free space in the stack 
			bgt		no_stack_overflow
			mov		r10,#1				;not enough space in stack for this procedure
			bx 		lr
			
			
no_stack_overflow
			mov 	r10,#0
			push	{r3,lr}
			push	{r1,r2,r4,r5,r6,r7,r8}
		
		
check		cbnz	r5,load_sub1		;when r5 is 0, we are done checking sublist 1
			mov		r7,#0x8F			;done with sublist 1, loading high value in R7
			b		load_sub2
load_sub1		
			ldrb	r7,[r2]				;R7 contains current ASCII code of character in sublist1
			cbnz	r6,load_sub2
			mov		r8,#0x8F			;done with sublist 2, loading high value in R8
			b		compare
load_sub2							
			ldrb	r8,[r4]				;R8 contains current ASCII code of character in sublist2

compare		cmp 	r7,r8
			bne		charac_diff							
			strb	r7,[r1]				;both characters are equal, we copy both to the aux buffer;
			add		r1,#1
			strb	r8,[r1]
			add		r1,#1
			;;;Updating indexes
     	    cbz		r5,cont_sub2		;index for sublist 1 will be zero when we are done inspecting that sublist
			subs 	r5,#1
			add		r2,#1	
cont_sub2	cbz		r6,check_if_done	;index for sublist 2 will be zero when we are done inspecting that sublist
			subs 	r6,#1
			add		r4,#1
check_if_done	
			cmp 	r5,r6
			bne 	check
			cmp		r5,#0				;both indexes are zero, then we are done
			beq 	finish
			b		check
		
charac_diff	;;;Only copy to aux buffer the charecter with smallest code, update its corresponding index	
			bgt		reverse_order
			strb	r7,[r1]				;character in sublist1 in less than the code of character in sublist2
			add		r1,#1
			cmp		r5,#0
			beq		check_if_done		;index for sublist 1 will be zero when we are done inspecting that sublist
			subs 	r5,#1
			add		r2,#1		
			b		check_if_done
reverse_order		
			strb	r8,[r1]				;character in sublist2 in less than character in sublist1.
			add		r1,#1
			cmp		r6,#0
			beq		check_if_done		;index for sublist 1 will be zero when we are done inspecting that sublist
			subs 	r6,#1	
			add		r4,#1
			b		check_if_done	

finish		pop	{r1,r2,r4,r5,r6,r7,r8}		
			;r1 contains now the memory address of source buffer ... in this case aux_buffer
			;r2 constains now vthe memory address of destination buffer ... in this case sublist1
			add r3,r5,r6	;size of sorted string is the additiong of the size of both sublists
			
			bl 		byte_copy				;;;copy aux buffer to input buffer	
		
			pop 	{r3,pc}			
			ENDP

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; End of assembly file
	align
	end
