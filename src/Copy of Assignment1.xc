/////////////////////////////////////////////////////////////////////////////////////////
//
// COMS20600 - WEEKS 3 and 4
// ASSIGNMENT 1
// CODE SKELETON
// TITLE: "LED Ant Defender Game"
//
// - this is the first assessed piece of coursework in the unit
// - this assignment is to be completed in pairs during week 3 and 4
// - it is worth 10% of the unit (i.e. 20% of the course work component)
//
// OBJECTIVE: given a code skeleton with threads and channels setup for you,
// implement a basic concurrent system on the XC-1A board
//
// NARRATIVE: You are given an XC code skeleton that provides you with
// the structure and helper routines to implement a basic game on the
// XC-1A board. Your task is to extend the given skeleton code to implement
// the following game:
//
// An �LED Ant� is represented by a position on the clock wheel of the
// XC-1A board. Each �LED Ant� is visualised by one active red LED on
// the 12-position LED clock marked with LED labels I, II, II,�, XII.
// No two LED Ants can have the same position on the clock. During the
// game, the user has to defend LED positions I, XII and XI from an
// LED Attacker Ant by controlling one LED Defender Ant and blocking the
// attacker's path.
//
// Defender Ant
// The user controls one LED Ant by pressing either button A (moving
// 1 position clockwise) or button D (moving 1 position anti-clockwise).
// The defender ant can only move to a position that is not already occupied
// by the attacker ant. The defender�s starting position is LED XII. A sound
// is played when the user presses a button.
//
// Attacker Ant
// A second LED Ant is controlled by the system and starts at LED position VI.
// It then attempts moving in one direction (either clockwise or anti-clockwise).
// This attempt is denied if the defender ant is already located there, in this
// case the attacker ant changes direction. To make the game more interesting:
// before attempting the nth move, the attacker ant will change direction if n is
// divisible by 23, 37 or 41. The game ends when the attacker has reached any one
// of the LED positions I, XII or XI.
//
/////////////////////////////////////////////////////////////////////////////////////////
#include <stdio.h>
#include <platform.h>

// Leds, buttons and speaker ports
out port cled0 = PORT_CLOCKLED_0;
out port cled1 = PORT_CLOCKLED_1;
out port cled2 = PORT_CLOCKLED_2;
out port cled3 = PORT_CLOCKLED_3;
out port cledG = PORT_CLOCKLED_SELG;
out port cledR = PORT_CLOCKLED_SELR;

// Port for buttons' leds
out port buttonLed = PORT_BUTTONLED;
in port buttons = PORT_BUTTON;
out port speaker = PORT_SPEAKER;

//numbers that function pinsneq returns that correspond to buttons
#define buttonA 14
#define buttonB 13
#define buttonC 11
#define buttonD 7

// Sound frequency
#define FRQ_A 39995
#define FRQ_B 40000

// Define bool, true and false
typedef unsigned int bool;
#define true 1
#define false 0

// Define delays
#define LEDDELAY 100000
#define DEFAULTDELAY 8000000

// Number of defends needed to win
#define NUMBER_OF_DEFENDS_TO_WIN 25

// Game lost signal
#define GAMELOST 100536

// Game won signal
#define GAMEWON 1336

// Pause signals
#define PAUSEOFF 1023
#define PAUSEON 1024

// Initial user and attacker positions
#define USERINITIALPOS 11
#define ATTACKERINITIALPOS 5

int mario[2][14] = {{660, 0,   660, 0,   660, 0, 510, 0,   660, 0,   770, 0,   380, 0}, {100, 150, 100, 300, 100, 300,   100, 100, 100, 300, 100, 550, 100, 575}};

// Forward declare waitMoment
void waitMoment();
void waitMomentCustom(int delay);

/////////////////////////////////////////////////////////////////////////////////////////
//
// Helper Functions provided for you
//
/////////////////////////////////////////////////////////////////////////////////////////
//DISPLAYS an LED pattern in one quadrant of the clock LEDs
int showLED(out port p, chanend fromVisualiser) {
	unsigned int lightUpPattern;

	while (true) {
		fromVisualiser :> lightUpPattern; //read LED pattern from visualiser process
		p <: lightUpPattern; //send pattern to LEDs
	}
	return 0;
}

//PROCESS TO COORDINATE DISPLAY of LED Ants
void visualiser(chanend fromUserAnt, chanend fromAttackerAnt, chanend toQuadrant0, chanend toQuadrant1, chanend
		toQuadrant2, chanend toQuadrant3) {

	// Initialize positions
	unsigned int userAntToDisplay = USERINITIALPOS;
	unsigned int attackerAntToDisplay = ATTACKERINITIALPOS;

	// Should exit?
    unsigned int terminationCode = 0;

    // Quadrants
    unsigned int q0, q1, q2, q3;
	int i, j, k;
	// Timer variables
	unsigned int t = 0, t0 = 0;
	timer tmr;


	while (true) {

		// Update positions, otherwise only quickly
		// 'blink' current positions to have two colors
		select {
			case fromUserAnt :> userAntToDisplay:
				break;
			case fromAttackerAnt :> attackerAntToDisplay:
				break;
			default:
				break;
		}

		if(userAntToDisplay == GAMELOST || userAntToDisplay == GAMEWON) {

			// Indicates if red leds should be user, if false use green
			bool flashRed = true;

			if(userAntToDisplay == GAMEWON) {
				flashRed = false;
				printf("Visualiser: Game Won\n");
			}
			// Display game lost animiation
			// i.e. flash red leds in a circle
			cledG <: !flashRed;
			cledR <: flashRed;

			// Clear the LEDs
			toQuadrant0 <: 0;
			toQuadrant1 <: 0;
			toQuadrant2 <: 0;
			toQuadrant3 <: 0;
			waitMoment();
			for(i = 0; i < 4; i++)
			{
				k = 0;
				for(int j = 0; j < 3; j++)
				{
					k += 16 << j;
					switch(i) {
						case 0: toQuadrant0 <: k; break;
						case 1: toQuadrant1 <: k; break;
						case 2: toQuadrant2 <: k; break;
						case 3: toQuadrant3 <: k; break;
					}
					waitMoment();
				}
			}
			continue;
		}

		// Position in a quadrant is encoded as multiple of 16:
		// 16 - first led, 32, second led, 48 - first end second, 64 - third etc.
		j =  16<<(userAntToDisplay%3);
		i =  16<<(attackerAntToDisplay%3);

		// Switch off red, green should be light up now
		cledG <: true;
		cledR <: false;

		// First display user ant, then quickly display attacker
		toQuadrant0 <: (j*(userAntToDisplay/3==0));
		toQuadrant1 <: (j*(userAntToDisplay/3==1));
		toQuadrant2 <: (j*(userAntToDisplay/3==2));
		toQuadrant3 <: (j*(userAntToDisplay/3==3));

		// Wait to make red led visible
		waitMomentCustom(LEDDELAY);

		// Switch LED color
		cledG <: false;
		cledR <: true;
		toQuadrant0 <: (i*(attackerAntToDisplay/3==0));
		toQuadrant1 <: (i*(attackerAntToDisplay/3==1));
		toQuadrant2 <: (i*(attackerAntToDisplay/3==2));
		toQuadrant3 <: (i*(attackerAntToDisplay/3==3));

		// Wait to make green led visible
		waitMomentCustom(LEDDELAY);
	}
}

//PLAYS a short sound (pls use with caution and consideration to other students in the labs!)
void playSound(unsigned int wavelength, out port speaker, int timePeriod) {
	timer tmr;
	int t, isOn = 1, i;
	tmr :> t;

	for (i = 0; i< timePeriod; i++) {
		isOn = !isOn;
		t += wavelength;
		tmr when timerafter(t) :> void;
		speaker <: isOn + wavelength;
	}
}

//READ BUTTONS and send to userAnt
void buttonListener(in port b, out port spkr, chanend toUserAnt, chanend fromController) {
	int r = 0;
	bool muteSound = false, pause = false, buttonAorDwasPressed = false;
	bool canProceed = true;

	while (true) {
		select {


			// check if some buttons are pressed
			case b when pinsneq(15) :> r:
				printf("Buttons \n");
				break;
			case fromController :> canProceed:
				printf("From controller\n");
				r = 0; // No buttons presssed
				break;
		}

		if(!canProceed)
			continue;


		switch(r) {
			case buttonB:
				// Toogle mute sound
				muteSound = !muteSound;
				// Wait to slow down movements when buttons are pressed
				waitMomentCustom(DEFAULTDELAY*2);
				break;
			case buttonC:
				// Toogle pause
				pause = !pause;
				// Wait to slow down movements when buttons are pressed
				waitMomentCustom(DEFAULTDELAY*2);
				break;
			case buttonA:
			case buttonD:
				// Wait a bit shorter to slow down controling buttons
				waitMoment();
				buttonAorDwasPressed = true;
				break;
			default:
				break;
		}

		// Display B and/or C led
		buttonLed <: (2 * muteSound) + (4 * pause); ;

		// play sound if not muted
		if (!muteSound)
			playSound(20000, spkr, 50);

		// Don't do anything if A or D wasn't pressed (no move)
		if(!buttonAorDwasPressed)
			continue;

		printf("Gonna send to user buttons buttons\n");

		// send button pattern to userAnt
		toUserAnt <: r;
	}
}

// WAIT function
// Allow to specify delay
void waitMomentCustom(int delay) {
	timer tmr;
	int waitTime;
	tmr :> waitTime;
	waitTime += delay;
	tmr when timerafter(waitTime) :> void;
}

// Use default delay
void waitMoment() {
	waitMomentCustom(DEFAULTDELAY);
}

// Make mouse position not exceeding certain values
// so that it moves in a circle
void normalizeAntPosition(unsigned int& antPosition)
{
	// Normalize position when mod 12 == 0
	// Two cases depending on direction of move
	if(antPosition == -1 ) antPosition = 11;
	else if(antPosition == 12) antPosition = 0;
}

//DEFENDER PROCESS... The defender is controlled by this process userAnt,
//which has channels to a buttonListener, visualiser and controller
void userAnt(chanend fromButtons, chanend toVisualiser, chanend toController) {

	// Loop to keep the game going
	while(true) {
		//the current defender position
		unsigned int userAntPosition = USERINITIALPOS;

		//the input pattern from the buttonListener
		int buttonInput = 0;

		//the next attempted defender position after considering button
		unsigned int attemptedAntPosition = 0;

		//the verdict of the controller if move is allowed
		int moveAllowed = false;

		// Code send from controoler
		int code = 0;

		// Flag indicating if game is over
		bool isLost = false;
		bool isWon = false;

		// Report initial position
		toVisualiser <: userAntPosition;

		waitMoment();

		// Code for userAnt behaviour
		while (true) {

			buttonInput = -1;
			// See what buttons are pressed and attempt to move left or right
			select {
				case fromButtons :> buttonInput:
					// Prevent from listenting buttons
					//nie wkonujr sie
					if(isLost || isWon) {
						printf("Continuing\n");
						continue;
					}

					break;
				case toController :> code:

					printf("User controller wants something!\n");
					switch(code) {
					case GAMELOST:
						isLost = true;
						break;

					case GAMEWON:
						isWon = true;
						break;

					default:
						isWon = false; isLost = false;
						break;

					}
					break;
			}

			// Check if the game is still going on... restart loop if game over
			if(isLost || isWon)
			{
				if(isWon) {
					printf("User: Game Won\n");
					toVisualiser <: GAMEWON;
				} else {
					printf("User: Game Lost\n");
					toVisualiser <: GAMELOST;
				}
				break;
			}

			//if (buttonInput == buttonC) isPaused = !isPaused;
			if (buttonInput == buttonA) attemptedAntPosition = userAntPosition + 1;
			else if (buttonInput == buttonD) attemptedAntPosition = userAntPosition - 1;
			else if (buttonInput == buttonC){
				// Handle pause:
				toController <: PAUSEON;

				while(true) {
					bool endPause = false;
					select {
						case fromButtons :> buttonInput:
							if(buttonInput == buttonC) {
								endPause = true;
								toController <: PAUSEOFF;
							}
							break;
						default:
							break;
					}
					if(endPause)
						break;
				}
			}
			else
				continue; // Don't attempt anything on other buttons

			// Make sure it goes in circle
			normalizeAntPosition(attemptedAntPosition);

			//Check whether position already occupied
			toController <: attemptedAntPosition;

			// Wait for response
			toController :> moveAllowed;


			if(moveAllowed == true) {
				userAntPosition = attemptedAntPosition;
				toVisualiser <: userAntPosition;
			} else if (moveAllowed == GAMELOST || GAMEWON){
				printf("MAM CIE!");
				isLost = (moveAllowed == GAMELOST);
				isWon = !isLost;
				continue;
			}
		}
	}
}

// Changes direction if move is divisble by 31, 37 or 43
unsigned int shouldChangeDirection(int moveCount)
{
	return (moveCount % 31 == 0 || moveCount % 37 == 0
			|| moveCount % 43 == 0);
}

//ATTACKER PROCESS... The attacker is controlled by this process attackerAnt,
// which has channels to the visualiser and controller
void attackerAnt(chanend toVisualiser, chanend toController) {

	// Loop to keep the game going
	while(true) {
		// moves of attacker so far
		int moveCounter = 0;

		// current attacker position
		unsigned int attackerAntPosition = ATTACKERINITIALPOS;

		// Least common multiple of 31, 37, 43
		const unsigned int leastCommonMultiple = 49321;

		// The next attempted position after considering move direction
		unsigned int attemptedAntPosition = 0;

		// The current direction the attacker is moving
		int currentDirection = 1;

		//the verdict of the controller if move is allowed
		bool moveAllowed = false, paused = false;

		// Code given from controller
		int code = 0;

		// Is game won?
		bool isWon = false;

		// Show initial position
		toVisualiser <: attackerAntPosition;

		while (true) {
			waitMoment();

			select {
				case toController :> code:
					if(code == PAUSEOFF) paused = false;
					else if(code == PAUSEON) paused = true;
					else if(code == GAMEWON) isWon = true;
					break;
				default:
					break;
			}

			// If game is won, return to the begining
			if(isWon) { printf("Attacker: Game Won 1\n");
				break; }

			if(paused) continue;

			// To avoid overflow of move count
			// use least common multiple of all three numbers
			// to 'reset' the counter
			if(moveCounter == leastCommonMultiple) moveCounter = 0;

			// Check if should change direction
			if(shouldChangeDirection(moveCounter))
				currentDirection = !currentDirection;

			// Attempt new positon left or right based on current direction
			if(currentDirection) attemptedAntPosition = attackerAntPosition + 1;
			else attemptedAntPosition = attackerAntPosition - 1;

			normalizeAntPosition(attemptedAntPosition);

			//Check whether position already occupied
			toController <: attemptedAntPosition;

			// Get the reponse from controller
			toController :> moveAllowed;

			// If controller allowed, move!
			if(moveAllowed == true) {
				attackerAntPosition = attemptedAntPosition;
			}
			// Check if the game is still going on... get out of loop if needed
			else if(moveAllowed == GAMELOST) {
				printf("ATTAK: GAMELOST\n");
				// Make sure last 'winning' position is shown
				toVisualiser <: attemptedAntPosition;
				// Break the inner loop, reinitialize variables, restart the game
				break;
			}
			// Check if game was won, then just exit
			else if(moveAllowed == GAMEWON) {
				printf("Attacker: Game Won 2\n");
				break;
			// Otherwise perform a move in other direction
			} else {
				// If attacker is next to the user and not allowed to move
				// then change direction
				currentDirection = !currentDirection;

				// Move in oppsite direction than we wanted before
				// Attempt new positon left or right based on current direction
				if(currentDirection) attemptedAntPosition = attackerAntPosition + 1;
				else attemptedAntPosition = attackerAntPosition - 1;
				normalizeAntPosition(attemptedAntPosition);
				attackerAntPosition = attemptedAntPosition;
			}

			// Move Ant wherever it was decided
			toVisualiser <: attackerAntPosition;

			// Wait to slow down movements so the player moves
			// In more or less same pace
			waitMoment();

			moveCounter++;
		}
	}
}

// COLLISION DETECTOR
// the controller process responds to permission-to-move requests
// from attackerAnt and userAnt. The process also checks if an attackerAnt
// has moved to LED positions I, XII and XI.
void controller(chanend fromAttacker, chanend fromUser, chanend toButtons) {

	// Loop to keep the game going
	while(true) {

		// Current level
		int level = 1;

		// Check how many times ant successfully defended
		int defendedCount = 1;

		// is game finished?
		bool isLost = false, isWon = false;

		//position last reported by userAnt
		unsigned int lastReportedUserAntPosition = 11;

		//position last reported by attackerAnt
		unsigned int lastReportedAttackerAntPosition = 5;

		//position last reported by attackerAnt or userAnt
		unsigned int attempt = 0;

		//printf("Start of new game\n");

		// Enable buttons
		toButtons <: true;

		//start game when user moves
		fromUser :> attempt;

		if(attempt == PAUSEOFF || attempt == PAUSEON)
			continue;
		else
			fromUser <: 1;

		//and remember its position
		lastReportedUserAntPosition = attempt;

		while (true) {
			select {
				case fromAttacker :> attempt:

					// Slow down, depending on level
					waitMomentCustom(DEFAULTDELAY / level);

					//check whether attacker can move
					if (attempt != lastReportedUserAntPosition) {
						lastReportedAttackerAntPosition = attempt;

						// Check if the game is over - attacker occupied one of 'defened' positions
						if(lastReportedAttackerAntPosition == 10
							|| lastReportedAttackerAntPosition == 11
							|| lastReportedAttackerAntPosition == 0) {

							printf("Controller sending gamelost to attacker\n");
							// Send a 'game over' signal to attacker and user
							fromAttacker <: GAMELOST;
							isLost = true;
							break;
						}

						fromAttacker <: 1; //allow to move
					} else {
						// do not allow to move if position was taken
						fromAttacker <: 0;

						if(defendedCount >= NUMBER_OF_DEFENDS_TO_WIN)
						{
							isWon = true;
							defendedCount = 0;
							break;
						}

						// Check if should increase level
						if(defendedCount % 5 == 0) {
							level *= 2;
						}

						// increase defended count
						defendedCount++;
					}
					break;
				case fromUser :> attempt:
					//check whether user can move
					if(attempt == PAUSEOFF) {
						// Resumed from user -> Resume attacker
						fromAttacker <: PAUSEOFF;
					} else if(attempt == PAUSEON) {
						// User is paused -> Pause attacker
						fromAttacker <: PAUSEON;
					} else if (attempt != lastReportedAttackerAntPosition) {
						lastReportedUserAntPosition = attempt;
						fromUser <: 1; //allow to move
					} else {

						fromUser <: 0; //do not allow to move
					}
					break;
				}

				if(isLost) {
					//printf("Send to sending to buttons\n");
					//toButtons <: false;
					printf("Send to user\n");
					fromUser <: GAMELOST;
					waitMoment();
					printf("Send to sending to buttons\n");
					toButtons <: false;

					printf("Sent!\n");


					//printf("Restarting controller\n");
					// Break controller inner loop and restart
					break;
				}
				else if(isWon)
				{
					toButtons <: false;
					printf("Controller: Game Won\n");
					fromAttacker <: GAMEWON;
					fromUser <: GAMEWON;
					waitMoment();
					break;
				}
			}
	}
}

//MAIN PROCESS defining channels, orchestrating and starting the processes
int main(void) {

	//channel from buttonListener to userAnt
	chan buttonsToUserAnt;

	//channel from userAnt to Visualiser
	chan userAntToVisualiser;

	//channel from attackerAnt to Visualiser
	chan attackerAntToVisualiser;

	//channel from attackerAnt to Controller
	chan attackerAntToController;

	//channel from userAnt to Controller
	chan userAntToController;

	//channel between buttons and controller
	chan buttonsToController;

	chan quadrant0, quadrant1, quadrant2, quadrant3; //helper channels for LED visualisation

	par{
		//PROCESSES FOR YOU TO EXPAND
		on stdcore[1]: userAnt(buttonsToUserAnt, userAntToVisualiser, userAntToController);
		on stdcore[2]: attackerAnt(attackerAntToVisualiser, attackerAntToController);
		on stdcore[3]: controller(attackerAntToController, userAntToController, buttonsToController);

		//HELPER PROCESSES
		on stdcore[0]: buttonListener(buttons, speaker, buttonsToUserAnt, buttonsToController);
		on stdcore[0]: visualiser(userAntToVisualiser, attackerAntToVisualiser, quadrant0, quadrant1, quadrant2, quadrant3);
		on stdcore[0]: showLED(cled0,quadrant0);
		on stdcore[1]: showLED(cled1,quadrant1);
		on stdcore[2]: showLED(cled2,quadrant2);
		on stdcore[3]: showLED(cled3,quadrant3);
	}
	return 0;
}
