ENSE 352 Semester Project 

Whack-A-Mole
Author: Mason Lane
SID:    200376573
Date:   06/12/2020


This is a game written in assembly language for the STM32F103 NUCLEO-64
It is accompanied by a circuit constructed on a breadboard. The circuit 
is built with 4 output leds and 4 respective buttons for input.


Regarding the presentation video, please note that audio was recorded without mono or single channel set.
As a result, using stereo sound will output the video through left-sided speakers only. Please consider this if you are.
listening with right-sided only (if one is hanging out, etc). Further, The volume may need to be set as high as possible.

 


This game satisfies 5 use cases. 
	UC1: Turning on the System
		Boot with reset button
		Enter UC2
	UC2: Waiting for Player
		LEDs shift back and forth until input is given (any 4). 
		Enter UC3
	UC3: Normal Gameplay 
		Prelim Wait time
		Random selection of LEDs are turned on
		User presses corresponding buttons, turning each off before reactTime expires
		reactTime is shortened for the next round
		If 15 rounds are won, enter UC4. Else, Return to step 1 (prelim wait)
	    Alt Path
		If the user presses the wrong button or runs out of time, enter UC5
	UC4: End Success
		Displays many random flashing LEDs for a short period to signify a win.
		Displays score for ~1min. Score is 15 so all LEDs are on (binary #: 8,4,2,1). Blinks fast
	UC5: End Failure
		Slowly blinks a distinct set of LEDs to signify a loss.
		If score is 1-14, Display score for ~1min. Score is 1-14 so some LEDs are on (binary #: 8,4,2,1). Blinks slowly
	    Alt Path
		If score is 0, display the disting set of LEDs over and over. 



How to Play. Assume all settings are default; 
	-Begin by pressing the reset button
	-A series of lights will indicate that the system is in standby.
	-Any input on the red,blue,green, or black buttons will begin the game.

	-Once a round starts, a random assortment of LEDs will turn on
	-Press the lit LED's respective buttons to turn them off or "whack" the moles. 
	-The debouncer being used limits you to one input at a time. 
	-Trying to turn off multiple buttons at the same time will likely only turn off one LED & may bypass the debouncer, causing a loss. 
	 Therfore, pretend you only have one hammer. This is the norm for most whack-a-mole games. 
	-You will have a limited time to press these buttons 
	-If you fail to turn off each LED, or press a button for an off LED, you will lose the game.
	-You must complete 15 rounds by default. Until you have completed 15 rounds, or caused a loss, you will continue to get more rounds. 
	-Each round will reduce the reactionTime. You start with ~15 seconds & end with ~3

	-If you have completed each round, you win!
	-Many random LEDs will flash briefly
	-You may then observe your score of 15 for 1 minute. 
	-The game will return to standby

	-If you have not completed each round, you lose...
	-Distinct LEDs will blink momentarily 
	-You may then observe your score for 1 minute.
	-If your score was 0, the LEDs will continue to blink distinctly as there is no binary value to show 
	-The game will return to standby



Included Settings
	-The user may adjust settings for PrelimWait, ReactTime, NumCycles & Winning/LosingSignalTime at lines 64-84.
	-Winning & Losing signals have been split into 8 distinct values which effect the mood (blink pace) of various signals. 
		-I advise mainly changing WINNINGSIGNALTIME, WINNINGSIGNALTIMEA & LOSINGSIGNALTIMEZERO, LOSINGSIGNALTIMEA. The others simply facilitate the rate of flashing signals
	
	PRELIMWAIT: 		How long to wait per round. 		Default: 0x80000 

	REACTTIME: 		Time to react each round.    		Default: 0x120000
	DIFFICULTYSPIKE: 	Time to depricate REACTTIME by.		Default: 0x10000				
	NUMCYCLES: 		Rounds to play. Score to reach. 	Default: 15				
	
	WINNINGSIGNALTIME: 	Main signal time for random numbers.	Default: 0xFFFF		

	The winning/losing signal times below comprise of the values needed to display LEDs for ~1min. A * (B+C), loop. 
	Note, LOSINGSIGNALTIMEZERO is a unique case for when a user has a score of 0. It should be double LOSINGSIGNALTIMEA.

	WINNINGSIGNALTIMEA   	Multiplier. 				Default: 0x89			 
	WINNINGSIGNALTIMEB      First half of loop. 			Default: 0x40000		
	WINNINGSIGNALTIMEC 	Second half of loop. 			Default: 0x20000		

	LOSINGSIGNALTIMEZERO 	Multiplier for scores of zero.		Default: 0x12		
	LOSINGSIGNALTIMEA 	Multiplier.  				Default: 0x3D			
	LOSINGSIGNALTIMEB 	First half of loop. 			Default: 0x90000		
	LOSINGSIGNALTIMEC 	Second half of loop. 			Default: 0x30000		

	DEBOUNCERTIME 		Debouncer Window			Default: 0x35000		;



Problems Encountered
	-Trouble pushing/poping. Made management of my registers more difficult than needed.

	-There are several segments I would have liked to split into smaller functions for organization/re-use.
	 Specifically, stand-by has functions I would like to refactor which might also simplify NormalGameplay 

	-I use a counter function to avoid having many different types of counters. 
         However, this makes other functions messier as I need to modify R6 frequently

	-Modifying settings may impair the stability of my game
		-Score/Profficiency displays do not have exception handlers to show scores greater than 15.
		-Changing the reactTimes may cause the game's reactTime to overflow or speed too fast. There are no exceptions.
		 So, if I set my react time to FFFF & its decriment to 5555, we would never make it to 15 rounds. This is to the user's discretion 
		-Modifying the debouncer time may enable multiple inputs at the risk of stability. I advise users to avoid adjusting this setting. 
		-PrelimWait is used in displaying the 
		-Losing and winning signal times are 3 values. A*(B+C) to create 1 minute displays. 

	-Debouncer inadvertently extends the ReactTime. Though, it is not exceptionally impactful unless poorly set in settings.  



Features I could Not Implement
	-"If the cycles completed are less than 1 or greater than 15, then you will have to decide how you’ll deal with that"
		-I handle cases where the user completes 0 rounds. When 0, I display the losing state repeatedly. However, I do not adequately handle scores > 15. 
		-If NumCycles is 20 & the user scores 15, it will appear in their profficiency display like they've won.
		-However, there are still features that differentiate the two states. 
			-Winners get a many, fast flashes of random LEDs, while losers get a distinct blink of ordered LEDs. 
			-Further, Profficiency scores blink slowly if you've lost & fast when you've won.
			-By differentiating the winning/losing state further, I believe I have handled the conditions in UC5. However, they could be handled better. 
			-Users will know they've lost no matter what - but they will not know precicely their score if it was over 15 but less than NumCycles 
	-Settings for Winning/LosingSignaltime & ReactTime may be changed, but may also impact the stability of the system. There are not checks for unrealistic/unstable settings. 
	-Times vary around ~1min. Since I blinked my results, it made counting for exactly 1 minute difficult.  The worst I timed was 50 seconds. 


Extra Features
	-Standby mode cycles LEDs back and forth. While an example for UC2, a simpler method could have been used. 
	-Included a debouncer to allow multiple LED gameplay
	-Implemented multiple LED (many-mole) gameplay
	-Extra settings are included that relate to my special additions, including a larger array of winningsignal types
	-Losing singal (the score) is now accompanied by an initial signal to further differentiate between winning/losing. 



Future Expansions
	-I would have liked to reduce reactTime exponentially. So, exponentially lower the time until we bottomed out at ~1/4 of the initial time. 
	 	-I would do this by slowly growing the decriment value for reactTime - intially getting the decriment as a fraction of reactTime. 
		-This would have been more elegant & "fun", with difficulty more akin to the real world game. 
	-I believe the debouncer time should be included in the reactTime somehow - or perhaps derived from it. This way it could be apart of the total time & not impact it inadvertently. 
	-My Winning/Losing signal times could instead be derived from a master signal time & fractioned as needed. This way, I would only include 2/3 values instead of 8. 
		-So for instance, my signals comprise of a value like y = A * (B+C). By default, this will display a signal for ~1min. 
		-It would be better to declare Y and derive A,B & C via functions. 
	-The random number generator needs to loop until it has values > 0. This could be improved.
	-I could display the profficiency scores more effectively. This could be by displaying larger numbers by blinking in binary - followed by a long pause to indicate where a # starts/ends.
		-Doing this, I could display segments of a number 4 bits at a time. 
