;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;Whack-A-Mole Game;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;		
;This is my whack-a-mole submission for our ENSE 352 submission.
;
;Author: Mason Lane
;Date: 05/12/2020
;Purpose: Plays a whack-a-mole game repeatedly. 
;		  Follows given use-cases as well as several quality aditions.
;	This program satisfies the following use cases...
;		UC1 Turning on the system
;		UC2 Waiting for Player
;		UC3 Normal Game Play.
;		UC4 End Success. The user has won the game.
;		UC5 End Failure. The user has lost the game.
;	More information on the readme regarding additions/shortcomings. 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
; Directives
	PRESERVE8
	THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;Clock Info;;;;;;;;;;;
INITIAL_MSP EQU     0x20001000
RCC_APB2ENR	EQU		0x40021018

;;;;;;;;;GPIO I CONSTANTS;;;;;
GPIOA_CRL	EQU		0x40010800
GPIOA_CRH	EQU		0x40010804
GPIOA_IDR	EQU		0x40010808
GPIOA_ODR	EQU 	0x4001080C

GPIOB_CRL	EQU		0x40010C00
GPIOB_CRH	EQU		0x40010C04
GPIOB_IDR	EQU		0x40010C08
GPIOB_ODR	EQU 	0x40010C0C
	
GPIOC_CRL	EQU		0x40011000
GPIOC_CRH	EQU		0x40011004
GPIOC_IDR	EQU		0x40011008
GPIOC_ODR	EQU 	0x4001100C

;;;;;;;;;LED VALUES;;;;;;;;;;;
LED4ON 		EQU 	0x00000001
LED3ON 		EQU 	0x00000010	
LED2ON 		EQU 	0x00000002
LED1ON 		EQU 	0x00000001


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; SETTINGS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Settings may be modified as needed. Some functionality may lose quality. 
;Notes:
;	-With our debouncer & other timers - we can expect ~15 seconds @ round 
;	 1 & ~3 seconds at round 15...
;	-Play for 15 rounds by default. This may be modified. However, it 
;	 will impact the usability of our score/profficiency rating view
;	-Winning & Losing signal times are split into 3 & 4 values respectively.
;	 This is to allow various blinking animations. For example, by Adding 
;	 TimeB + TimeC, and multiplying by TimeA, we have a full loop of ~1min. 
;	 as requested by the usecase. If a user changes these, it will not be ~1min

PRELIMWAIT 			 EQU 0x00080000

REACTTIME 			 EQU 0x120000		;Starting time
DIFFICULTYSPIKE 	 EQU 0x10000		;Time to decriment per round
		
NUMCYCLES 			 EQU 15				;Score to reach

WINNINGSIGNALTIMEA   EQU 0x7C			;Multiplier 
WINNINGSIGNALTIMEB 	 EQU 0x40000		;First half of loop
WINNINGSIGNALTIMEC 	 EQU 0x20000		;Second half of loop

LOSINGSIGNALTIMEZERO EQU 0x1F			;Multiplier for scores of zero
LOSINGSIGNALTIMEA 	 EQU 0x3E			;Multiplier 
LOSINGSIGNALTIMEB 	 EQU 0x90000		;First half of loop
LOSINGSIGNALTIMEC 	 EQU 0x30000		;Second half of loop

DEBOUNCERTIME 		 EQU 0x35000		;Debouncer Timeframe. Will effect total react time aswell; 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
	ALIGN	
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Main ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Require: Constant values above must bet set. 
; Promise:
;	-Reset Handler Completes usecase 1 by default. 
;	-Configure Clock and IO Ports 
;	-Run StandBy until exit.
;	-Run normal gameplay until win/lose
;	-Compare score
;	-Branch to winner or loser based on R12 (score).
;	-Loop to StandBy
; Modifies:
;	Modifies registers based on functions below.
Reset_Handler		PROC		
	
	;config our io and clock
	BL ConfigClock
	BL ConfigGPIO
	
mainLoop
	BL StandBy
	BL NormalGameplay
	
	CMP R12, #NUMCYCLES
	BNE loserState
	BL Winner
	BL defaultState	
loserState
	BL Loser
defaultState
	BL mainLoop

	ENDP
		

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;; USE CASE 2 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  running standBy 
;  Require:
;	R0:  Used to set forward or back state. Determines which LEDs to light in 
;		 what order. 
;	R4:  Used in lighting LED & SetGPIOODRLDR
;	R5:	 Used in lighting LED & SetGPIOODRLDR
; 	R6:  Must be available. used for counters. Also, R6 is used for 
;		 temporarily storing R4
;	R7:	 Used for temporarily storing R4
;	R10: Stores our random number seed.
; Promise:
;	-Initialize by setting LED1. 
; 	-Run a standbyLoop until any button is pressed.
;	-Based on the LED on, determine whether to go forward or back 
;	-Based on the LED on, determine which LED to light next.
;	-Hold LED on for a short time, before looping.
;	-If a button is pressed, turn off all LEDs and return to main. 
; Modifies:
;	Modifies all listed registers. However, R10 is the only one that persists.
;	R10 will hold our random number seed. R10 differs based on the time a 
;	button is pressed.
	ALIGN
StandBy PROC
	PUSH {LR}
	BL SetGPIOODRLDR
	BL LEDOFF			;Turn off leds to be safe
	BL SetLED1			;Set LED1 by default
	MOV R6, #0
	MOV R0, #0x00
	
stbyLoop
	BL SetGPIOODRLDR	
	CMP R0, #0x01		;If R0 is 1, move LEDs forward
	BNE forward
backward 				;If R0 is 0, move LEDs backward
	PUSH{R6, R7}
	MOV R6, R4			;Which LED is currently on in R4, R5??? Remember this.
	MOV R7, R5
	BL LEDOFF			;turn off all LEDs. We remember which one was on, however.
	cmp R7, #LED4ON		;If LED4 is on, set LED3..
	BNE skipB1
	
	BL SetLED3
skipB1	
	cmp R6, #LED3ON		;If LED3 is on, set LED2. 
	BNE skipB2
	
	BL SetLED2
skipB2	
	cmp R6, #LED2ON		;If LED2 is on, set LED1. 
	BNE skipB3
	
	BL SetLED1
skipB3	
	POP{R6, R7}
	CMP R4, #LED1ON		;If LED1 is on, Set R0 to 0. We will now go "forward" in the next loop
	IT EQ
	MOVEQ R0, #0x00
	BL both
forward
	PUSH{R6, R7}
	MOV R6, R4			;Which LED is currently on in R4, R5??? Remember this.
	MOV R7, R5
	BL LEDOFF			;turn off all LEDs. We remember which one was on, however.
	cmp R6, #LED1ON		;If LED1 is on, set LED2. 
	BNE skipA1
	
	BL SetLED2
skipA1	
	cmp R6, #LED2ON		;If LED2 is on, set LED3. 
	BNE skipA2
	
	BL SetLED3
skipA2
	cmp R6, #LED3ON		;If LED3 is on, set LED4. 
	BNE skipA3
	
	BL SetLED4
skipA3	
	POP{R6, R7}
	CMP r5, #LED4ON		;If LED4 is on, Set R0 to 1. We will now go "backward" in the next loop
	IT EQ
	MOVEQ R0, #0x01
both
	BL SetGPIOODRLDR	
	BL GetButtonPressed		;At the end of each loop, check if a button was pressed
	CMP R7, #0x0
	BGT endStbyLoop			;End the loop if a button was pressed

	MOV R6, #0x0000ffff
stbyCounter					;Hold the LED on before looping & setting a new LED. 
	BL timer
	BL counter
	CMP R6, #0
	BNE stbyCounter
	
	BL stbyLoop
endStbyLoop
	BL LEDOFF
	POP {LR}
	BX LR
	ENDP
		
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;; USE CASE 3 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  running normalGameplay 
;  Require:
; 	R6:  Must be available. used for counters
;	R8:  Must be available. used for storing random number & led state.  
;		 (which of the random LEDs are still on)
;	R9:	 Must be available. used for storing user input. Also temporarily 
;		 stores react time decriment #
;	R11: Stores react time. 
;	R12: Starts at 0. Increases with each successful round. Is score. 
; Promise:
; 	-Start with a preliminary wait. Run a round until react timer is up or 
;	 all LEDs are off. 
;   -Decriments the reacttime each round. 
;	-End function if time runs out, an off led is pressed, or 15 rounds are 
;	 completed.
;	-If input is given, run a debouncer. Will inadvertantly extend the react 
;	 time. 
; Modifies:
;	Modifies all listed registers. However, R12 is the only register that 
;	needs to persist
	ALIGN
NormalGameplay PROC
	PUSH {LR}
	MOV R12, #0
	MOV R9, #0
	
	LDR R11, = REACTTIME
	
continue
	LDR R6, = PRELIMWAIT			;Wait for a given time.
prelimWait
	BL counter
	CMP R6, #0
	BNE prelimWait

	BL timer
	BL randomNumber					;Get a random number greater than 1
	CMP R8, #0x01
	BLT continue 	
	BL SetLEDS						;Set LEDs according to random #
	MOV R6, R11
	PUSH {R6}
reactTimer							;Loop until reaction time R6 is 0, or all LEDs are turned off

	BL SetGPIOODRLDR
	BL GetButtonPressed
	ORR R9, R7						
	PUSH {R9}						;Save a copy of our R9.
	CMP R9, #0x0
	BEQ noInput						;Call the debouncer if we have input

	MOV R6, #DEBOUNCERTIME			;Debouncer. Used to ensure user cannot touble-tap by mistake. This plays into the total react time.
deBouncer
	BL counter
	CMP R6, #0
	BNE deBouncer	
noInput								;Skip debouncer when we have no input.
;The following conditions behave very similar. Use the first section as reference & assume the same is said for other LED cases.
	AND R9, #0x1					;Was somthing pressed? 
	CMP R9, #0x1
	BNE not1
	BL UnsetLED1					;If the button associated to LED1 is pressed, unset LED1. 
	PUSH {R8}
	AND R8, #0x1					;Check if this LED was supposed to be unset. 
	CMP R8, #0x1
	BNE badInput					;If it shouldnt have been unset, badInput
	POP {R8}
	EOR R8, #0x1
not1								;button was never pressed
	POP {R9}						;reset R9 
	PUSH {R9}
	AND R9, #0x4
	CMP R9, #0x4
	BNE not2
	BL UnsetLED2
	PUSH {R8}
	AND R8, #0x2
	CMP R8, #0x2
	BNE badInput
	POP {R8}
	EOR R8, #0x2
not2
	POP {R9}
	PUSH {R9}
	AND R9, #0x10
	CMP R9, #0x10
	BNE not3
	BL UnsetLED3
	PUSH {R8}
	AND R8, #0x4
	CMP R8, #0x4
	BNE badInput
	POP {R8}
	EOR R8, #0x4
not3	
	POP {R9}
	PUSH {R9}
	AND R9, #0x20
	CMP R9, #0x20
	BNE not4
	BL UnsetLED4
	PUSH {R8}
	AND R8, #0x8
	CMP R8, #0x8
	BNE badInput
	POP {R8}
	
	EOR R8, #0x8
not4
	BL goodInput		;All passes checked. Input was good. This will happen if we have no input, or all input is good.
badInput				;Bad input
	POP {R8,R9,R6}		;Pop these to clean up.
	MOV R6, #1			;Cheating our value to cause a lose state. R6 will become 0, and R8 being 1 will make our system think the user ran out of time.
	MOV R8, #1
	PUSH {R6}			;Push these so we have somthing to pop. Branching to badInput skips some pushes.
	PUSH {R9}			;we will go into goodInput even with badInput. 
goodInput				
	POP {R9}
	POP {R6}
	BL counter			
	PUSH {R6}
	MOV R9, #0
	CMP R8, #0			;Is R8 0? if so, LEDs were turned off in enough time. branch to allOff	
	BEQ allOff
	CMP R6, #0			;Is r6 0? If not, continue to reactTimer until the LEDs are off or time runs out
	BNE reactTimer
	CMP R8, #0			;Is R8 0? If not, the user has run out of time & the LEDs are not unset. end the game now. They lose. if we reach here, endGame is inevitable 
	BNE endGame
allOff							;all LEDs are off
	MOV R9, #DIFFICULTYSPIKE	;Set R9 to hold our difficulty spike
	SUB R11, R9					;reduce our reactTime by R9
	POP {R9}					
	MOV R9, #0					;Reset R9
	BL LEDOFF					;Set all LED off as a precaution 
	ADD R12, #1					
	CMP R12, #NUMCYCLES			;We beat the level. Increment by 1. If we reach NUMCYCLES, we win! Else, branch to continue & loop
	BNE continue
	PUSH {R8}
endGame							;Game ends
	POP {R8}
	BL LEDOFF					
	LDR R6, = PRELIMWAIT
exitWait						;Run prelim wait one more time...	
	BL counter
	CMP R6, #0
	BNE exitWait	
	POP {LR}
	BX LR
	ENDP	


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;; USE CASE 4 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  Setting the winning state 
;  Require:
; 	R6:  Must be available. used for counters
;	R8:  Must be available. used for input 
;	R12: Must be set. used to load R8 with input value of our score. 
;		 Also ensures user is not a score of 0.
; Promise:
; 	Will display a winner state derived from random #s & then user score. 
;	The score display will run for ~1min unless settings are changed
; Modifies:
;	Modifies various registers. Changes do not need to persist into other 
;	functions
	ALIGN
Winner    PROC
    PUSH {LR}
	LDR R6, =0x001F			;Loop for given time.
flash
	
	PUSH {R6}
	LDR R6, =0x0000FFFF		
wait						;Loop for FFFF
	BL counter
	CMP R6, #0
	BNE wait
again
	BL timer
	BL randomNumber			;generate a random # greater than 0.
	CMP R8, #0x01
	BLT again 	
	BL LEDOFF				;Turn off existing LEDs
	BL SetLEDS				;Turn on LEDs according to random number
	POP {R6}
	BL counter
	CMP R6, #0				;Loop until 0x1F is reduced to 0. 
	BNE flash
	BL LEDOFF
	
	MOV R6, #WINNINGSIGNALTIMEA	
highScore 					;Below will loop for TimeA * (TimeB+TimeC)
	MOV R8, R12
	BL SetLEDS				;Set LEDs based on score
	
	PUSH {R6}
	MOV R6, #WINNINGSIGNALTIMEB	;Loop with LEDs on for TimeB
onLoop
	BL counter
	CMP R6, #0x0
	BNE onLoop
	
	POP {R6}
	
	PUSH {R6}
	MOV R6, #WINNINGSIGNALTIMEC	;Loop with LEDs off for TimeC
	BL LEDOFF
offLoop
	BL counter
	CMP R6, #0x0
	BNE offLoop
	POP {R6}
	
	
	BL counter
	CMP R6, #0x0			;End loop when R6 for TimeA is reduced to 0
	BNE highScore
	
	POP {LR}
    BX LR
    ENDP


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;; USE CASE 5 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  Setting the losing state 
;  Require:
; 	R6:  Must be available. used for counters
;	R8:  Must be available. used for input 
;	R9:  Must be available. used for unique counter
; 	R10: Must be available. used for unique counter
;	R12: Must be set. used to load R8 with input value of our score. 
;		 Also ensures user is not a score of 0.
; Promise:
; 	Will display a failure state & then user score. 
;	failure state persists if score is 0 - since no score can be shown
;	will run for ~1min unless settings are changed
; Modifies:
;	Modifies various registers. Changes do not need to persist into other 
;	functions 
	ALIGN
Loser    PROC
    PUSH {LR}
	MOV R6, #LOSINGSIGNALTIMEZERO
zeroReset
	MOV R8, #0x9
	MOV R9, #0
	MOV R10, #0

	PUSH {R6}
waveTwo

resetWave
;Run the following for TimeB and TimeC.Light on for B, Light off for C
	BL SetLEDS
	MOV R6, #LOSINGSIGNALTIMEB
bgLoop1
	BL counter
	CMP R6, #0x0
	BNE bgLoop1	
	BL LEDOFF
	MOV R6, #LOSINGSIGNALTIMEC
bgLoop2
	BL counter
	CMP R6, #0x0
	BNE bgLoop2
	ADD R9, #1
	ADD R10, #1
	CMP R9, #2
	BNE resetWave		;Reset if we have not blinked twice
	SUB R9, #1
	MOV R8, #6
	CMP R10, #4			;Reset if we have not blinked twice with the new arrangement of LED
	BNE resetWave	
	CMP R12, #0
	BNE showScore		;Show user's score. If the users score is 0, blink over and over.
	POP {R6} 
	BL counter 
	CMP R6, #0
	BNE zeroReset		;Will cause a loop to blink over and over until R6 for LOSINGSIGNALTIMEZERO reaches 0.
	BL finishLoop
	
showScore
	POP {R6} 
	MOV R6, #LOSINGSIGNALTIMEA		;Below will loop for TimeA * (TimeB+TimeC)
lowScore 
	MOV R8, R12
	BL SetLEDS						;SetLEDs based on score 
	
	PUSH {R6}
	MOV R6, #LOSINGSIGNALTIMEB
slowOnLoop							;Loop for TimeB
	BL counter
	CMP R6, #0x0
	BNE slowOnLoop
	
	POP {R6}
	
	PUSH {R6}
	MOV R6, #LOSINGSIGNALTIMEC
	BL LEDOFF						;Turn off LEDs
slowOffLoop							;Loop for TimeC
	BL counter
	CMP R6, #0x0
	BNE slowOffLoop
	POP {R6}
	
	
	BL counter
	CMP R6, #0x0
	BNE lowScore					;Loop for timeA until R6 representing it is 0
finishLoop	
	
	POP {LR}
    BX LR
    ENDP				


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;; INPUT/OUTPUT HANDLERS ;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  Getting IDR and ODR so we may read/write to it
;  Require:
; 	R1: Must be available. Should not change unless pushed for later 
;	R2: Must be available. Should not change unless pushed for later
;	R3: Must be available. Should not change unless pushed for later
; 	R4: Must be available. Should not change unless pushed for later 
;	R5: Must be available. Should not change unless pushed for later
;	R7: Must be available. Should not change unless pushed for later
; Promise:
; 	used to get the current input/output of the user/led. Must be called to 
;	record input. It will return values of R4, R5, R7 which we will 
;	read/write to
; Modifies:
;	R1, R2, R3, R4, R5, R7. These 6 registers are very important 
	ALIGN
SetGPIOODRLDR	PROC
	LDR R1, = GPIOA_ODR ;led 1,2,3   
	LDR R2, = GPIOB_ODR ;led 4	
	LDR R3, = GPIOB_IDR ;4 buttons	
	LDR R4, [R1]
	LDR R5, [R2]
	LDR R7, [R3]
	BX LR
	ENDP
		
	
	ALIGN
GetButtonPressed PROC
	PUSH {R8}
	
	LSR R7, #4		;Move input bits right. 
	MOV R8, #0xFFD	;Mask bits we dont want
	EOR R7, R8		

	POP {R8}
	BX LR 
	ENDP 


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;; LED MANIPULATORS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  Set multiple LEDs at once
;  Require:
; 	R9: Must be available
;	R8: Must be set
; Promise:
; 	uses R8 to set the R9 led value. Then call various setLED functions
;	based on R9.
; Modifies:
;	Modifies R9. Returns to previous R9. Modifications persist with SetLED 
;	functions
	ALIGN
SetLEDS PROC
	PUSH {LR}
	PUSH {R9}
	MOV R9, R8
	AND R9, #0x1	;Only set and LED if R9 contains the desired set bit	
	CMP R9, #0x1
	BNE dontSet1
	BL SetLED1
dontSet1
	MOV R9, R8
	AND R9, #0x2
	CMP R9, #0x2
	BNE dontSet2
	BL SetLED2
dontSet2
	MOV R9, R8
	AND R9, #0x4
	CMP R9, #0x4
	BNE dontSet3
	BL SetLED3
dontSet3	
	MOV R9, R8
	AND R9, #0x8
	CMP R9, #0x8
	BNE dontSet4
	BL SetLED4
dontSet4
	
	POP {R9}
	POP {LR}
	BX LR
	ENDP


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  Set various LEDs if called 
;  Require:
; 	SetGPIOODRLDR must have been called. 
;	R4, R5 should be set & ready for modification
; Promise:
; 	stores a unique LEDnON value to R4 or R5. Stores to a GPIOx_ODR
;	this will turn on the desired LED
; Modifies:
;	Modifies R4. Stores to a GPIOx_ODR	
	ALIGN
SetLED1 PROC
	EOR R4, #LED1ON	;EOR allows us to toggle on/off
	STR R4, [R1]
	BX LR
	ENDP
		
	ALIGN
SetLED2 PROC
	EOR R4, #LED2ON
	STR R4, [R1]
	BX LR
	ENDP
		
	ALIGN
SetLED3 PROC
	EOR R4, #LED3ON
	STR R4, [R1]
	BX LR
	ENDP
				
	ALIGN
SetLED4 PROC
	EOR R5, #LED4ON
	STR R5, [R2]
	BX LR
	ENDP


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  Unset various LEDs if called 
;  Require:
; 	SetGPIOODRLDR must have been called. 
;	R4, R5 should be set & ready for modification
; Promise:
; 	this will ensure the desired LED is always off if called. It cannot be on.
; Modifies:
;	Modifies R4 or R5. Stores to a GPIOx_ODR	
	ALIGN	
UnsetLED1 PROC
	ORR R4, #LED1ON
	EOR R4, #LED1ON
	STR R4, [R1]
	BX LR
	ENDP
		
	ALIGN
UnsetLED2 PROC
	ORR R4, #LED2ON
	EOR R4, #LED2ON
	STR R4, [R1]
	BX LR
	ENDP
		
	ALIGN
UnsetLED3 PROC
	ORR R4, #LED3ON
	EOR R4, #LED3ON
	STR R4, [R1]
	BX LR
	ENDP
		
	ALIGN
UnsetLED4 PROC
	ORR R5, #LED4ON
	EOR R5, #LED4ON
	STR R5, [R2]
	BX LR
	ENDP
	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  Unset all LEDs used to reset the entire array of LEDs
;  Require:
; 	SetGPIOODRLDR must have been called. 
;	R4, R5 should be set & ready for modification
; Promise:
; 	this will ensure the desired LED is always off if called. It cannot be on.
; Modifies:
;	Modifies R4 or R5. Stores to a GPIOx_ODR
	ALIGN
LEDOFF PROC
	MOV R5, #0x0000
	STR R5, [R2]
	
	MOV R4, #0x0000
	STR R4, [R1]
	BX LR
	ENDP
		
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;; CONFIGURATION/SETUP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;			
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  Configurating clocks on our board
;  Require:
; 	R1: Must be available
;	R0: Must be available
; Promise:
; 	stores the configuration settings to our RCC_APB2ENR
; Modifies:
;	Will modify RCC_APB2ENR's configuration. 
;	This will open clocks on ports 00011100
;	We configure ports A,B,C		  cba
	ALIGN
ConfigClock PROC
	LDR R1, = RCC_APB2ENR
	LDR R0, [R1]
	
	MOV R0, #0
	ORR R0, #0x1c
	STR R0, [R1]
	
	BX LR
	ENDP
		
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  Configurating IO Ports on our board
;  Require:
; 	R1: Must be available
;	R0: Must be available
; Promise:
; 	stores the configuration settings for GPIOB_CRL, GPIOB_CRH, GPIOA_CRL
; Modifies:
;	Will modify GPIOB_CRL, GPIOB_CRH, GPIOA_CRL's configuration. 
;	GPIOB_CRL: PB0 is output for A3. PB4 is input for D5, PB6 is input for D10
;	GPIOB_CRH: PB8 is input for D15, PB9 is input for D14
;	GPIOA_CRL: PA0 is output for A0, PA1 is output for A1, PA4 is output for A2 
	ALIGN
ConfigGPIO  PROC
	LDR R1, = GPIOB_CRL
	LDR R0, [R1]
	
	LDR R2, =0x04040003	
	ORR R0, R0, R2
	LDR R2, =0xf4f4fff3
	AND R0, R0, R2
	STR R0, [R1]
	;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;
	LDR R1, = GPIOB_CRH
	LDR R0, [R1]
	
	LDR R2, =0x00000044	
	ORR R0, R0, R2
	LDR R2, =0xFFFFFF44
	AND R0, R0, R2
	STR R0, [R1]
	;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;
	LDR R1, = GPIOA_CRL
	LDR R0, [R1]

	LDR R2, =0x00030033
	ORR R0, R0, R2
	LDR R2, =0xFFF3FF33
	AND R0, R0, R2
	STR R0, [R1]
	BX LR
	ENDP
		
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;; TIMER AND COUNTER FUNCTIONS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  Primary counter function. Counts down until R6 is 0. 
;  Require:
; 	R6: Must be set outside of function. This allows our counter to run for 
;       many different functions.
; Promise:
; 	Returns R6 after one iteration. 
; Modifies:
;	Will modify R6, which stores our current count. 
	ALIGN
counter PROC
	CMP R6, #0
	IT NE
	SUBNE R6, #1
	BX LR
	ENDP
		
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;		
;  timer function. Counts up until R6 is 0xffffffff. Used in generating our 
;  random number seed.
;
;  Require:
; 	R10: Must be available 
; Promise:
; 	Returns R10 after one iteration. Counts up or resets 
; Modifies:
;	Will modify R10, which stores our current time. 		
	ALIGN
timer PROC
	CMP R10, #0xffffffff
	IT EQ
	MOVEQ R10, #0x1
	IT NE
	ADDNE R10, #1
	BX LR
	ENDP
	
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;RANDOM NUMBER GENERATOR;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;		
;This solution was derived in collaboration w/ Zachary Philson
;randomNumber
;Author: Zachary Philson
;Date: 02/12/2020
;Purpose: Returns a random number derived from a clock/coutner's state. 
;Edited By: Mason Lane
;
; Require:
; 	R0: Will be used temporarily. Push existing values
; 	R1: Will be used temporarily. Push existing values
; 	R10: Must be a value derived from our timer 
; Promise:
; 	Returns 4 bits which we will use for our random number. R10 acts as our seed.
; Modifies:
;	Will modify R8, which stores our random number. 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	ALIGN
randomNumber    PROC
    push {R0,R1}
    LDR R0, = 1669525       
    LDR R1, = 1013904223   

    MUL R8,R10,R0			
    ADD R8,R8,R2
              
    LSL R8, #28            	
	LSR R8, #28			;Derive 4 bits from our large number R8
    pop{R0,R1}
    BX LR
    ENDP

;-----------------------------------------------------------------------
;End of program 
	END