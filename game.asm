#####################################################################
#
# CSCB58 Winter 2023 Assembly Final Project
# University of Toronto, Scarborough
#
# Student: Theo Landart, 1008152712, landartt, theo.landart@mail.utoronto.ca
#
# Bitmap Display Configuration:
# - Unit width in pixels: 4
# - Unit height in pixels: 4
# - Display width in pixels: 512
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestones have been reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 1, 2, and 3
#
# Which approved features have been implemented for milestone 3?
# (See the assignment handout for the list of additional features)
# 1. Health/score [2]
# 2. Fail condition [1]
# 3. Win condition [1]
# 4. Moving objects [2]
# 5. Moving platforms [2]
# 6. Double jump [1]
#
# Link to video demonstration for final submission:
# https://www.youtube.com/watch?v=moUooeaW2mA
#
# Are you OK with us sharing the video with people outside course staff?
# - yes, and please share this project github link as well!
# https://github.com/tlandart/b58-project (will unprivate after the course ends)
#
# Any additional information that the TA needs to know:
# - N/A
#
#####################################################################

.eqv DISPLAY_ADDRESS 0x10008000
.eqv KEYBOARD_ADDRESS 0xffff0000

.eqv WAIT_MS 33 # refresh every 33ms
.eqv FRAMES_FOR_SECOND 31 # approx how many frames it takes for 1 second to pass
.eqv TIME_START 30
.eqv HEALTH_START 3
.eqv BAT_ANIM_TIME 5
.eqv JUMP_TIME 15 # how many frames the upward part of jump lasts for
.eqv I_TIME 25 # how many frames the player is invincible for after getting hit

.eqv WIDTH        128
.eqv HEIGHT       64
.eqv WIDTH_M        127
.eqv HEIGHT_M       63
.eqv WIDTH_4        512
.eqv AREA         8192
.eqv AREA_4         32768

# colors
.eqv COL_BG 0x173CCF
.eqv COL_PLAT 0x8C8C8C
.eqv COL_PLAT_ACCENT 0xC4C4C4
.eqv COL_PLAYER1 0xFFFFFF
.eqv COL_PLAYER2 0x000000
.eqv COL_PLAYER3 0xFF0000
.eqv COL_CROSS 0xFFB300
.eqv COL_BAT1 0x5100FF
.eqv COL_BAT2 0x000000
.eqv COL_BAT3 0xFFFFFF
.eqv COL_HEALTH1 0xFF0000
.eqv COL_HEALTH2 0x00FF00

.data
Health:			.word 0
# whether the player moved or not during this frame
PlayerMoved:	.word 0
# whether the player is on a platform or not during this frame
OnPlatform:		.word 0
# whether the double jump is allowed or not on this frame
DoubleJump:		.word 0
# the state of jump animation the player is in
JumpTime:		.word 0
# the state of invincibility the player is in
ITime:			.word 0
# frames left before the time ticks down 1
TimerWait:		.word 0
# time left in seconds
Timer:			.word 0
# positions for the crosses flying around
CrossX:			.word 1, WIDTH_M, 1, WIDTH_M, 1, WIDTH_M, 1, WIDTH_M, 1, WIDTH_M
CrossY:			.word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
CrossDir:		.word 1, -1, 1, -1, 1, -1, 1, -1, 1, -1 # direction of ith cross
CrossWait:		.word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 # frames to wait before cross spawns
# positions for the annoying bat
BatX:			.word 0
BatY:			.word 32
BatDX:			.word 2 # pixels it moves on X axis per frame
BatDY:			.word 1 # pixels it moves on Y axis per frame
BatState:		.word 1 # animation state
BatStateCounter:.word BAT_ANIM_TIME # counter for animation state
# positions (centers) for the moving platforms
MovingPlatX:	.word 0, 0
MovingPlatDX:	.word 1, 1

.text
.globl main

### GET ADDRESS ###
# int GetAddress(int x, int y)
# returns the address of the pixel at (x,y)
GetAddress:
	lw $t1, 0($sp)		# pop y off stack
	addi $sp, $sp, 4
	lw $t0, 0($sp)		# pop x off stack
	addi $sp, $sp, 4
	
	# $t2 = address(x,y) = (y*width + x)*4
	li $t3, WIDTH
	mult $t3, $t1
	mflo $t3
	add $t2, $t3, $t0
	li $t3, 4
	mult $t3, $t2
	mflo $t2
	addi $t2, $t2, DISPLAY_ADDRESS

	addi $sp, $sp, -4	# push $t2 on stack
	sw $t2, 0($sp)

	jr $ra

### DRAW LINE ###
# void DrawLine(int x, int y, int w, int col)
# draw a line starting at (x,y) to the right with width w and color col
DrawLine:
	lw $t7, 0($sp)		# pop color off stack
	addi $sp, $sp, 4
	lw $t6, 0($sp)		# pop width off stack
	addi $sp, $sp, 4
	lw $t4, 0($sp)		# pop y off stack
	addi $sp, $sp, 4
	lw $t3, 0($sp)		# pop x off stack
	addi $sp, $sp, 4
	
	addi $sp, $sp, -4	# push $ra on stack
	sw $ra, 0($sp)
	
	# $t1 = GetAddress(x,y)
	addi $sp, $sp, -4	# push x on stack
	sw $t3, 0($sp)
	addi $sp, $sp, -4	# push y on stack
	sw $t4, 0($sp)
	jal GetAddress		# call GetAddress(x,y)
	lw $t1, 0($sp)		# pop GetAddress(x,y) off stack
	addi $sp, $sp, 4

DrawLineLoop: # draw w pixels
	sw $t7, 0($t1)
	addi $t1, $t1, 4
	addi $t6, $t6, -1
	bgtz $t6, DrawLineLoop

	lw $ra, 0($sp)		# pop $ra off stack
	addi $sp, $sp, 4
	jr $ra

### DRAW PLATFORM ###
# void DrawPlatform(int x, int y, int w)
# draw a platform centered at (x,y) with width w
DrawPlatform:
	lw $s2, 0($sp)		# pop w off stack
	addi $sp, $sp, 4
	lw $s1, 0($sp)		# pop y off stack
	addi $sp, $sp, 4
	lw $s0, 0($sp)		# pop x off stack
	addi $sp, $sp, 4
	
	addi $sp, $sp, -4	# push $ra on stack
	sw $ra, 0($sp)

	# $t6 = width of the platform to be drawn
	add $t6, $s2, $zero
	# $t2 = width/2
	sra $t2, $s2, 1
	# $t3 = x - width/2, or 0 if x - width/2 < 0
	sub $t3, $s0, $t2
	li $t4, 0
	bge $t3, $t4, DrawPlatformCheck
	# if x - width/2 < 0, set it to 0 and subtract $t3 from $t6
	# otherwise we skip this part
	add $t6, $t6, $t3
	li $t3, 0
	# now we can draw the platform starting at the address at $t1
DrawPlatformCheck:
	
	# draw the top row
	addi $sp, $sp, -4	# push $t3 onto the stack
	sw $t3, 0($sp)

	addi $sp, $sp, -4	# push x onto the stack
	sw $t3, 0($sp)
	addi $sp, $sp, -4	# push y onto the stack
	sw $s1, 0($sp)
	addi $sp, $sp, -4	# push w onto the stack
	sw $s2, 0($sp)
	addi $sp, $sp, -4	# push col onto the stack
	li $t9, COL_PLAT
	sw $t9, 0($sp)
	jal DrawLine		# call Drawline(x,y,w,col)
	
	lw $t3, 0($sp)		# pop $t3 off stack
	addi $sp, $sp, 4

	# draw the bottom row
	addi $sp, $sp, -4	# push $t3 onto the stack
	sw $t3, 0($sp)
	# call again but with x+1 and y+1 and w-2
	addi $t3, $t3, 1
	addi $s1, $s1, 1
	addi $s2, $s2, -2
	
	addi $sp, $sp, -4	# push x onto the stack
	sw $t3, 0($sp)
	addi $sp, $sp, -4	# push y onto the stack
	sw $s1, 0($sp)
	addi $sp, $sp, -4	# push w onto the stack
	sw $s2, 0($sp)
	addi $sp, $sp, -4	# push col onto the stack
	li $t9, COL_PLAT_ACCENT
	sw $t9, 0($sp)
	jal DrawLine		# call Drawline(x,y,w,col)
	
	lw $t3, 0($sp)		# pop $t3 off stack
	addi $sp, $sp, 4
	
	lw $ra, 0($sp)		# pop $ra off stack
	addi $sp, $sp, 4
	
	jr $ra

### ERASE PLATFORM ###
# void ErasePlatform(int x, int y, int w)
# erase a platform centered at (x,y) with width w
ErasePlatform:
	lw $s2, 0($sp)		# pop w off stack
	addi $sp, $sp, 4
	lw $s1, 0($sp)		# pop y off stack
	addi $sp, $sp, 4
	lw $s0, 0($sp)		# pop x off stack
	addi $sp, $sp, 4
	
	addi $sp, $sp, -4	# push $ra on stack
	sw $ra, 0($sp)

	# $t6 = width of the platform to be erased
	add $t6, $s2, $zero
	# $t2 = width/2
	sra $t2, $s2, 1
	# $t3 = x - width/2, or 0 if x - width/2 < 0
	sub $t3, $s0, $t2
	li $t4, 0
	bge $t3, $t4, ErasePlatformCheck
	# if x - width/2 < 0, set it to 0 and subtract $t3 from $t6
	# otherwise we skip this part
	add $t6, $t6, $t3
	li $t3, 0
	# now we can erase the platform starting at the address at $t1
ErasePlatformCheck:
	
	# erase the top row
	addi $sp, $sp, -4	# push $t3 onto the stack
	sw $t3, 0($sp)

	addi $sp, $sp, -4	# push x onto the stack
	sw $t3, 0($sp)
	addi $sp, $sp, -4	# push y onto the stack
	sw $s1, 0($sp)
	addi $sp, $sp, -4	# push w onto the stack
	sw $s2, 0($sp)
	addi $sp, $sp, -4	# push col onto the stack
	li $t9, COL_BG
	sw $t9, 0($sp)
	jal DrawLine		# call Drawline(x,y,w,bg color)
	
	lw $t3, 0($sp)		# pop $t3 off stack
	addi $sp, $sp, 4

	# erase the bottom row
	addi $sp, $sp, -4	# push $t3 onto the stack
	sw $t3, 0($sp)
	# call again but with x+1 and y+1 and w-2
	addi $t3, $t3, 1
	addi $s1, $s1, 1
	addi $s2, $s2, -2
	
	addi $sp, $sp, -4	# push x onto the stack
	sw $t3, 0($sp)
	addi $sp, $sp, -4	# push y onto the stack
	sw $s1, 0($sp)
	addi $sp, $sp, -4	# push w onto the stack
	sw $s2, 0($sp)
	addi $sp, $sp, -4	# push col onto the stack
	li $t9, COL_BG
	sw $t9, 0($sp)
	jal DrawLine		# call Drawline(x,y,w,bg color)
	
	lw $t3, 0($sp)		# pop $t3 off stack
	addi $sp, $sp, 4
	
	lw $ra, 0($sp)		# pop $ra off stack
	addi $sp, $sp, 4
	
	jr $ra

### CHECK IF PLAYER IS ON PLATFORM ###
# bool IsPlayerOnPlatform(int playerx, int playery)
# returns 0 if player is on platform, nonzero otherwise
# (i.e. whether the color under it is the color of the top of a platform)
IsPlayerOnPlatform:
	lw $t1, 0($sp)		# pop playery off stack
	addi $sp, $sp, 4
	lw $t0, 0($sp)		# pop playerx off stack
	addi $sp, $sp, 4
	
	addi $sp, $sp, -4	# push $ra on stack
	sw $ra, 0($sp)

	# if $t1 >= HEIGHT_M - 3, return false
	li $t2, HEIGHT_M
	addi $t2, $t2, 3
	blt $t1, $t2, IsPlayerOnPlatformCheck
	li $t2, 1
	addi $sp, $sp, -4	# push 1 (false) onto the stack
	sw $t2, 0($sp)
	jr $ra
IsPlayerOnPlatformCheck:
	# else get the pixel address 3 under this and check that
	addi $t1, $t1, 3
	# $t3 = GetAddress(playerx+3,playery)
	addi $sp, $sp, -4	# push x on stack
	sw $t0, 0($sp)
	addi $sp, $sp, -4	# push y on stack
	sw $t1, 0($sp)
	jal GetAddress		# call GetAddress(x,y)
	lw $t3, 0($sp)		# pop GetAddress(x,y) off stack
	addi $sp, $sp, 4

	# $t3 = color at (playerx,playery) - color of platform
	lw $t3, 0($t3)
	subi $t3, $t3, COL_PLAT
	sw $t3, OnPlatform

	lw $ra, 0($sp)		# pop $ra off stack
	addi $sp, $sp, 4

	jr $ra

### CHECK IF PLAYER IS HIT BY A CROSS ###
# bool IsPlayerHitByCross()
# returns 1 if player is hit by a cross, 0 otherwise
IsPlayerHitByCross:
	li $s1, 0 # $s1 holds which cross we are currently looking at
IsPlayerHitByCrossLoop:
	lw $t0, CrossX($s1) # get x value
	lw $t1, CrossY($s1) # get y value

	addi $t2, $s6, 0 # get player x value
	addi $t3, $s7, 0 # get player y value

	# if CrossX-1, CrossX, or CrossX+1 is playerX, check y values
	addi $t2, $t2, -1
	beq $t0, $t2, IsPlayerHitByCrossLoopCheckY
	addi $t2, $t2, 1
	beq $t0, $t2, IsPlayerHitByCrossLoopCheckY
	addi $t2, $t2, 1
	beq $t0, $t2, IsPlayerHitByCrossLoopCheckY

	j IsPlayerHitByCrossLoopUpdate

IsPlayerHitByCrossLoopCheckY:
	# if any part of the player character touches the middle of the cross, return 1
	addi $t3, $t3, -3
	beq $t1, $t3, IsPlayerHitByCrossLoopYes
	addi $t3, $t3, 1
	beq $t1, $t3, IsPlayerHitByCrossLoopYes
	addi $t3, $t3, 1
	beq $t1, $t3, IsPlayerHitByCrossLoopYes
	addi $t3, $t3, 1
	beq $t1, $t3, IsPlayerHitByCrossLoopYes
	addi $t3, $t3, 1
	beq $t1, $t3, IsPlayerHitByCrossLoopYes
	addi $t3, $t3, 1
	beq $t1, $t3, IsPlayerHitByCrossLoopYes

IsPlayerHitByCrossLoopUpdate:
	addi $s1, $s1, 4 # increment
	blt $s1, 40, IsPlayerHitByCrossLoop
IsPlayerHitByCrossLoopNo: # we get here to return 0
	li $t1, 0
	addi $sp, $sp, -4	# push 0 on stack
	sw $t1, 0($sp)
	jr $ra
IsPlayerHitByCrossLoopYes: # jump here to return 1
	li $t1, 1
	addi $sp, $sp, -4	# push 1 on stack
	sw $t1, 0($sp)
	jr $ra

### CHECK IF PLAYER IS HIT BY THE BAT ###
# bool IsPlayerHitByBat()
# returns 1 if player is hit by the bat, 0 otherwise
IsPlayerHitByBat:
	lw $t0, BatX # get x value
	lw $t1, BatY # get y value

	addi $t2, $s6, 0 # get player x value
	addi $t3, $s7, 0 # get player y value

	# if BatX-2, BatX-1, BatX, BatX+1, BatX+2 is playerX, check y values
	addi $t0, $t0, -2
	beq $t0, $t2, IsPlayerHitByBatCheckY
	addi $t0, $t0, 1
	beq $t0, $t2, IsPlayerHitByBatCheckY
	addi $t0, $t0, 1
	beq $t0, $t2, IsPlayerHitByBatCheckY
	addi $t0, $t0, 1
	beq $t0, $t2, IsPlayerHitByBatCheckY
	addi $t0, $t0, 1
	beq $t0, $t2, IsPlayerHitByBatCheckY

	j IsPlayerHitByBatNo

IsPlayerHitByBatCheckY:
	# if any part of the player character touches the middle of the bat, return 1
	addi $t3, $t3, -3
	beq $t1, $t3, IsPlayerHitByBatYes
	addi $t3, $t3, 1
	beq $t1, $t3, IsPlayerHitByBatYes
	addi $t3, $t3, 1
	beq $t1, $t3, IsPlayerHitByBatYes
	addi $t3, $t3, 1
	beq $t1, $t3, IsPlayerHitByBatYes
	addi $t3, $t3, 1
	beq $t1, $t3, IsPlayerHitByBatYes
	addi $t3, $t3, 1
	beq $t1, $t3, IsPlayerHitByBatYes

IsPlayerHitByBatNo: # we get here to return 0
	li $t1, 0
	addi $sp, $sp, -4	# push 0 on stack
	sw $t1, 0($sp)
	jr $ra
IsPlayerHitByBatYes: # jump here to return 1

	li $t1, 1
	addi $sp, $sp, -4	# push 1 on stack
	sw $t1, 0($sp)
	jr $ra

### DRAW BAT ###
# void DrawBat()
# draws the bat
DrawBat:
	addi $sp, $sp, -4	# push $ra on stack
	sw $ra, 0($sp)

	lw $t2, BatState	# get state
	lw $t1, BatY		# get y
	lw $t0, BatX		# get x

	# if (x,y) is off the screen, skip to end
	blt $t0, 1, DrawBatEnd
	bgt $t0, WIDTH_M, DrawBatEnd
	blt $t1, 1, DrawBatEnd
	bgt $t1, HEIGHT_M, DrawBatEnd

	# depending on the state we draw differently
	beq $t2, -1, DrawBatState2

DrawBatState1:
	# $t3 = GetAddress(playerx,playery)
	addi $sp, $sp, -4	# push x on stack
	sw $t0, 0($sp)
	addi $sp, $sp, -4	# push y on stack
	sw $t1, 0($sp)
	jal GetAddress		# call GetAddress(x,y)
	lw $t3, 0($sp)		# pop GetAddress(x,y) off stack
	addi $sp, $sp, 4

	# manually draw the pixels

	li $t2, COL_BAT1
	
	subi $t3, $t3, WIDTH_4
	subi $t3, $t3, WIDTH_4
	addi $t3, $t3, -4

	# row 1
	sw $t2, 0($t3)
	addi $t3, $t3, 8
	sw $t2, 0($t3)
	
	addi $t3, $t3, WIDTH_4
	addi $t3, $t3, -8

	# row 2
	li $t2, COL_BAT2
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	li $t2, COL_BAT1
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	li $t2, COL_BAT2
	sw $t2, 0($t3)
	
	addi $t3, $t3, WIDTH_4
	addi $t3, $t3, -12

	# row 3
	li $t2, COL_BAT1
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	li $t2, COL_BAT3
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	li $t2, COL_BAT1
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	
	addi $t3, $t3, WIDTH_4
	addi $t3, $t3, -20

	# row 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 16
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)

	j DrawBatEnd

DrawBatState2:
	# $t3 = GetAddress(playerx,playery)
	addi $sp, $sp, -4	# push x on stack
	sw $t0, 0($sp)
	addi $sp, $sp, -4	# push y on stack
	sw $t1, 0($sp)
	jal GetAddress		# call GetAddress(x,y)
	lw $t3, 0($sp)		# pop GetAddress(x,y) off stack
	addi $sp, $sp, 4

	# manually draw the pixels

	subi $t3, $t3, WIDTH_4
	subi $t3, $t3, WIDTH_4
	addi $t3, $t3, -4

	# row 1
	li $t2, COL_BAT1
	sw $t2, 0($t3)
	addi $t3, $t3, 8
	sw $t2, 0($t3)
	
	addi $t3, $t3, WIDTH_4
	addi $t3, $t3, -16

	# row 2
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	li $t2, COL_BAT2
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	li $t2, COL_BAT1
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	li $t2, COL_BAT2
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	li $t2, COL_BAT1
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	
	addi $t3, $t3, WIDTH_4
	addi $t3, $t3, -24

	# row 3
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	li $t2, COL_BAT3
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	li $t2, COL_BAT1
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)

	j DrawBatEnd

DrawBatEnd:
	lw $ra, 0($sp)		# pop $ra off stack
	addi $sp, $sp, 4

	jr $ra

### ERASE BAT ###
# void EraseBat()
# erases the bat
EraseBat:
	addi $sp, $sp, -4	# push $ra on stack
	sw $ra, 0($sp)

	lw $t2, BatState	# get state
	lw $t1, BatY		# get y
	lw $t0, BatX		# get x

	# $t3 = GetAddress(playerx,playery)
	addi $sp, $sp, -4	# push x on stack
	sw $t0, 0($sp)
	addi $sp, $sp, -4	# push y on stack
	sw $t1, 0($sp)
	jal GetAddress		# call GetAddress(x,y)
	lw $t3, 0($sp)		# pop GetAddress(x,y) off stack
	addi $sp, $sp, 4

	# manually draw the pixels

	li $t2, COL_BG
	
	subi $t3, $t3, WIDTH_4
	subi $t3, $t3, WIDTH_4
	addi $t3, $t3, -4

	# row 1
	sw $t2, 0($t3)
	addi $t3, $t3, 8
	sw $t2, 0($t3)
	
	addi $t3, $t3, WIDTH_4
	addi $t3, $t3, -16
	
	# row 2
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	
	addi $t3, $t3, WIDTH_4
	addi $t3, $t3, -20
	
	# row 3
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	
	addi $t3, $t3, WIDTH_4
	addi $t3, $t3, -20
	
	# row 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 16
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)

	lw $ra, 0($sp)		# pop $ra off stack
	addi $sp, $sp, 4

	jr $ra

### DRAW CROSS ###
# void DrawCross(int i)
# draws cross (i/4)'s sprite
DrawCross:
	lw $t0, 0($sp)		# pop i off stack
	addi $sp, $sp, 4
	
	addi $sp, $sp, -4	# push $ra on stack
	sw $ra, 0($sp)

	lw $t2, CrossDir($t0)	# get dir
	lw $t1, CrossY($t0)		# get y
	lw $t0, CrossX($t0)		# get x

	# if (x,y) is off the screen, skip to end
	blt $t0, 1, DrawCrossEnd
	bgt $t0, WIDTH_M, DrawCrossEnd
	blt $t1, 1, DrawCrossEnd
	bgt $t1, HEIGHT_M, DrawCrossEnd

	# depending on the direction we draw differently
	bgtz $t2, DrawCrossRight

DrawCrossLeft:
	addi $t1, $t1, -1

	# $t3 = GetAddress(playerx,playery)
	addi $sp, $sp, -4	# push x on stack
	sw $t0, 0($sp)
	addi $sp, $sp, -4	# push y on stack
	sw $t1, 0($sp)
	jal GetAddress		# call GetAddress(x,y)
	lw $t3, 0($sp)		# pop GetAddress(x,y) off stack
	addi $sp, $sp, 4

	# manually draw the pixels

	li $t2, COL_CROSS

	# row 1
	sw $t2, 0($t3)
	
	addi $t3, $t3, WIDTH_4
	addi $t3, $t3, -4

	# row 2
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	
	addi $t3, $t3, WIDTH_4
	addi $t3, $t3, -8

	# row 3
	sw $t2, 0($t3)

	j DrawCrossEnd

DrawCrossRight:
	addi $t1, $t1, -1

	# $t3 = GetAddress(playerx,playery)
	addi $sp, $sp, -4	# push x on stack
	sw $t0, 0($sp)
	addi $sp, $sp, -4	# push y on stack
	sw $t1, 0($sp)
	jal GetAddress		# call GetAddress(x,y)
	lw $t3, 0($sp)		# pop GetAddress(x,y) off stack
	addi $sp, $sp, 4

	# manually draw the pixels
	
	li $t2, COL_CROSS

	# row 1
	sw $t2, 0($t3)
	
	addi $t3, $t3, WIDTH_4
	addi $t3, $t3, -8

	# row 2
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	
	addi $t3, $t3, WIDTH_4
	addi $t3, $t3, -4

	# row 3
	sw $t2, 0($t3)

DrawCrossEnd:
	lw $ra, 0($sp)		# pop $ra off stack
	addi $sp, $sp, 4

	jr $ra

### ERASE CROSS ###
# void EraseCross(int i)
# erases cross (i/4)'s sprite
EraseCross:
	lw $t0, 0($sp)		# pop i off stack
	addi $sp, $sp, 4
	
	addi $sp, $sp, -4	# push $ra on stack
	sw $ra, 0($sp)

	lw $t2, CrossDir($t0)	# get dir
	lw $t1, CrossY($t0)		# get y
	lw $t0, CrossX($t0)		# get x

	# depending on the direction we draw differently
	bgtz $t2, EraseCrossRight

EraseCrossLeft:
	addi $t1, $t1, -1

	# $t3 = GetAddress(playerx,playery)
	addi $sp, $sp, -4	# push x on stack
	sw $t0, 0($sp)
	addi $sp, $sp, -4	# push y on stack
	sw $t1, 0($sp)
	jal GetAddress		# call GetAddress(x,y)
	lw $t3, 0($sp)		# pop GetAddress(x,y) off stack
	addi $sp, $sp, 4

	# manually draw the pixels

	li $t2, COL_BG

	# row 1
	sw $t2, 0($t3)
	
	addi $t3, $t3, WIDTH_4
	addi $t3, $t3, -4

	# row 2
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	
	addi $t3, $t3, WIDTH_4
	addi $t3, $t3, -8

	# row 3
	sw $t2, 0($t3)

	j EraseCrossEnd

EraseCrossRight:
	addi $t1, $t1, -1

	# $t3 = GetAddress(playerx,playery)
	addi $sp, $sp, -4	# push x on stack
	sw $t0, 0($sp)
	addi $sp, $sp, -4	# push y on stack
	sw $t1, 0($sp)
	jal GetAddress		# call GetAddress(x,y)
	lw $t3, 0($sp)		# pop GetAddress(x,y) off stack
	addi $sp, $sp, 4

	# manually draw the pixels
	
	li $t2, COL_BG

	# row 1
	sw $t2, 0($t3)
	
	addi $t3, $t3, WIDTH_4
	addi $t3, $t3, -8

	# row 2
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	
	addi $t3, $t3, WIDTH_4
	addi $t3, $t3, -4

	# row 3
	sw $t2, 0($t3)

EraseCrossEnd:
	lw $ra, 0($sp)		# pop $ra off stack
	addi $sp, $sp, 4

	jr $ra

### DRAW NUMBER ###
# void DrawNumber(int x, int y, int num)
# erase and draws the digit num at (x,y) (num must be from 0 to 9)
DrawNumber:
	lw $s2, 0($sp)		# pop col off stack
	addi $sp, $sp, 4
	lw $s1, 0($sp)		# pop num off stack
	addi $sp, $sp, 4
	lw $t1, 0($sp)		# pop y off stack
	addi $sp, $sp, 4
	lw $t0, 0($sp)		# pop x off stack
	addi $sp, $sp, 4
	
	addi $sp, $sp, -4	# push $ra on stack
	sw $ra, 0($sp)

	# $t3 = GetAddress(x,y)
	addi $sp, $sp, -4	# push x on stack
	sw $t0, 0($sp)
	addi $sp, $sp, -4	# push y on stack
	sw $t1, 0($sp)
	jal GetAddress		# call GetAddress(x,y)
	lw $t3, 0($sp)		# pop GetAddress(x,y) off stack
	addi $sp, $sp, 4

	# first, erase the area around the digit
	li $t4, COL_BG

	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, WIDTH_4
	sw $t4, 0($t3)
	addi $t3, $t3, -4
	sw $t4, 0($t3)
	addi $t3, $t3, -4
	sw $t4, 0($t3)
	addi $t3, $t3, WIDTH_4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, WIDTH_4
	sw $t4, 0($t3)
	addi $t3, $t3, -4
	sw $t4, 0($t3)
	addi $t3, $t3, -4
	sw $t4, 0($t3)
	addi $t3, $t3, WIDTH_4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)

	# move back to top left
	subi $t3, $t3, WIDTH_4
	subi $t3, $t3, WIDTH_4
	subi $t3, $t3, WIDTH_4
	subi $t3, $t3, WIDTH_4
	addi $t3, $t3, -8

	addi $t4, $s2, 0

	beq $s1, 0, DrawNumber0
	beq $s1, 1, DrawNumber1
	beq $s1, 2, DrawNumber2
	beq $s1, 3, DrawNumber3
	beq $s1, 4, DrawNumber4
	beq $s1, 5, DrawNumber5
	beq $s1, 6, DrawNumber6
	beq $s1, 7, DrawNumber7
	beq $s1, 8, DrawNumber8
	beq $s1, 9, DrawNumber9
	j DrawNumberEnd

DrawNumber0:
	# row 1
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 2
	sw $t4, 0($t3)
	addi $t3, $t3, 8
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 3
	sw $t4, 0($t3)
	addi $t3, $t3, 8
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 4
	sw $t4, 0($t3)
	addi $t3, $t3, 8
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 5
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)

	j DrawNumberEnd

DrawNumber1:
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, WIDTH_4
	sw $t4, 0($t3)
	addi $t3, $t3, WIDTH_4
	sw $t4, 0($t3)
	addi $t3, $t3, WIDTH_4
	sw $t4, 0($t3)
	addi $t3, $t3, WIDTH_4
	sw $t4, 0($t3)

	j DrawNumberEnd

DrawNumber2:
	# row 1
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 2
	addi $t3, $t3, 8
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 3
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 4
	sw $t4, 0($t3)

	addi $t3, $t3, WIDTH_4

	# row 5
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)

	j DrawNumberEnd
	
DrawNumber3:
	# row 1
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 2
	addi $t3, $t3, 8
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 3
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 4
	addi $t3, $t3, 8
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 5
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)

	j DrawNumberEnd
	
DrawNumber4:
	# row 1
	sw $t4, 0($t3)
	addi $t3, $t3, 8
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 2
	sw $t4, 0($t3)
	addi $t3, $t3, 8
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 3
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 4
	addi $t3, $t3, 8
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 5
	addi $t3, $t3, 8
	sw $t4, 0($t3)

	j DrawNumberEnd
	
DrawNumber5:
	# row 1
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 2
	sw $t4, 0($t3)

	addi $t3, $t3, WIDTH_4

	# row 3
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 4
	addi $t3, $t3, 8
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 5
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)

	j DrawNumberEnd
	
DrawNumber6:
	# row 1
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 2
	sw $t4, 0($t3)

	addi $t3, $t3, WIDTH_4

	# row 3
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 4
	sw $t4, 0($t3)
	addi $t3, $t3, 8
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 5
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)

	j DrawNumberEnd
	
DrawNumber7:
	# row 1
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 2 and later
	addi $t3, $t3, 8
	sw $t4, 0($t3)
	addi $t3, $t3, WIDTH_4
	sw $t4, 0($t3)
	addi $t3, $t3, WIDTH_4
	sw $t4, 0($t3)
	addi $t3, $t3, WIDTH_4
	sw $t4, 0($t3)

	j DrawNumberEnd
	
DrawNumber8:
	# row 1
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 2
	sw $t4, 0($t3)
	addi $t3, $t3, 8
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 3
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 4
	sw $t4, 0($t3)
	addi $t3, $t3, 8
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 5
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)

	j DrawNumberEnd
	
DrawNumber9:
	# row 1
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 2
	sw $t4, 0($t3)
	addi $t3, $t3, 8
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 3
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, -8

	addi $t3, $t3, WIDTH_4

	# row 4 and later
	addi $t3, $t3, 8
	sw $t4, 0($t3)
	addi $t3, $t3, WIDTH_4
	sw $t4, 0($t3)

	j DrawNumberEnd

DrawNumberEnd:
	lw $ra, 0($sp)		# pop $ra off stack
	addi $sp, $sp, 4
	jr $ra

### DRAW HEALTH ###
# void DrawHealth()
# draws the player's health in the bottom left corner
DrawHealth:
	addi $sp, $sp, -4	# push $ra on stack
	sw $ra, 0($sp)

	li $t0, 1
	li $t1, HEIGHT
	addi $t1, $t1, -3
	# $t3 = GetAddress($t0,$t1)
	addi $sp, $sp, -4	# push x on stack
	sw $t0, 0($sp)
	addi $sp, $sp, -4	# push y on stack
	sw $t1, 0($sp)
	jal GetAddress		# call GetAddress(x,y)
	lw $t3, 0($sp)		# pop GetAddress(x,y) off stack
	addi $sp, $sp, 4

	lw $t0, Health
	li $t2, 0 # incrementing variable

DrawHealthLoop:
	li $t4, COL_HEALTH1
	bge $t2, $t0, DrawHealthLoopCheck
	li $t4, COL_HEALTH2
DrawHealthLoopCheck:
	sw $t4, 0($t3)
	addi $t3, $t3, 4
	sw $t4, 0($t3)
	addi $t3, $t3, WIDTH_4
	sw $t4, 0($t3)
	addi $t3, $t3, -4
	sw $t4, 0($t3)
	subi $t3, $t3, WIDTH_4

	# increment
	addi $t3, $t3, 8
	addi $t2, $t2, 1
	blt $t2, HEALTH_START, DrawHealthLoop

	lw $ra, 0($sp)		# pop $ra off stack
	addi $sp, $sp, 4
	jr $ra

### DRAW PLAYER ###
# void DrawPlayer(int x, int y)
# draws the player sprite at (x,y)
DrawPlayer:
	lw $t1, 0($sp)		# pop y off stack
	addi $sp, $sp, 4
	lw $t0, 0($sp)		# pop x off stack
	addi $sp, $sp, 4
	
	addi $sp, $sp, -4	# push $ra on stack
	sw $ra, 0($sp)

	addi $t0, $t0, -1
	addi $t1, $t1, -3

	# $t3 = GetAddress(playerx,playery)
	addi $sp, $sp, -4	# push x on stack
	sw $t0, 0($sp)
	addi $sp, $sp, -4	# push y on stack
	sw $t1, 0($sp)
	jal GetAddress		# call GetAddress(x,y)
	lw $t3, 0($sp)		# pop GetAddress(x,y) off stack
	addi $sp, $sp, 4

	# manually draw the pixels

	# $t5 = hair/suit color
	li $t5, COL_PLAYER2
	# hair and suit are red if invincible, black otherwise
	lw $t4, ITime
	blez $t4, DrawPlayerCheck
	li $t5, COL_PLAYER3
DrawPlayerCheck:

	li $t0, DISPLAY_ADDRESS
	addi $t0, $t0, AREA_4 # the last pixel on the screen

	# row 1 - only draw if the address is on the screen (only a vertical check is needed because the player vertically clips the screen but just stops horizontally)
	ble $t3, DISPLAY_ADDRESS, DrawPlayerRow1Check
	bge $t3, $t0, DrawPlayerRow1Check

	move $t2, $t5
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, -8
DrawPlayerRow1Check:
	
	addi $t3, $t3, WIDTH_4

	# row 2 - only draw if the address is on the screen
	ble $t3, DISPLAY_ADDRESS, DrawPlayerRow2Check
	bge $t3, $t0, DrawPlayerRow2Check

	move $t2, $t5
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	li $t2, COL_PLAYER1
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	move $t2, $t5
	sw $t2, 0($t3)
	addi $t3, $t3, -8
DrawPlayerRow2Check:
	
	addi $t3, $t3, WIDTH_4

	# row 3 - only draw if the address is on the screen
	ble $t3, DISPLAY_ADDRESS, DrawPlayerRow3Check
	bge $t3, $t0, DrawPlayerRow3Check

	li $t2, COL_PLAYER1
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, -8
DrawPlayerRow3Check:
	
	addi $t3, $t3, WIDTH_4

	# row 4 - only draw if the address is on the screen
	ble $t3, DISPLAY_ADDRESS, DrawPlayerRow4Check
	bge $t3, $t0, DrawPlayerRow4Check

	move $t2, $t5
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	li $t2, COL_PLAYER3
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	move $t2, $t5
	sw $t2, 0($t3)
	addi $t3, $t3, -8
DrawPlayerRow4Check:
	
	addi $t3, $t3, WIDTH_4

	# row 5 - only draw if the address is on the screen
	ble $t3, DISPLAY_ADDRESS, DrawPlayerRow5Check
	bge $t3, $t0, DrawPlayerRow5Check

	move $t2, $t5
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	li $t2, COL_PLAYER1
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	move $t2, $t5
	sw $t2, 0($t3)
	addi $t3, $t3, -8
DrawPlayerRow5Check:
	
	addi $t3, $t3, WIDTH_4

	# row 6 - only draw if the address is on the screen
	ble $t3, DISPLAY_ADDRESS, DrawPlayerRow6Check
	bge $t3, $t0, DrawPlayerRow6Check

	move $t2, $t5
	sw $t2, 0($t3)
	addi $t3, $t3, 8
	sw $t2, 0($t3)
DrawPlayerRow6Check:
	
	lw $ra, 0($sp)		# pop $ra off stack
	addi $sp, $sp, 4

	jr $ra

### ERASE PLAYER ###
# void ErasePlayer(int x, int y)
# erases the player sprite at (x,y)
ErasePlayer:
	lw $t1, 0($sp)		# pop y off stack
	addi $sp, $sp, 4
	lw $t0, 0($sp)		# pop x off stack
	addi $sp, $sp, 4
	
	addi $sp, $sp, -4	# push $ra on stack
	sw $ra, 0($sp)

	addi $t0, $t0, -1
	addi $t1, $t1, -3

	# $t3 = GetAddress(playerx,playery)
	addi $sp, $sp, -4	# push x on stack
	sw $t0, 0($sp)
	addi $sp, $sp, -4	# push y on stack
	sw $t1, 0($sp)
	jal GetAddress		# call GetAddress(x,y)
	lw $t3, 0($sp)		# pop GetAddress(x,y) off stack
	addi $sp, $sp, 4

	# manually draw the pixels

	li $t2, COL_BG
	
	li $t0, DISPLAY_ADDRESS
	addi $t0, $t0, AREA_4

	# row 1 - only erase if the address is on the screen
	ble $t3, DISPLAY_ADDRESS, ErasePlayerRow1Check
	bge $t3, $t0, ErasePlayerRow1Check

	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, -8
ErasePlayerRow1Check:
	
	addi $t3, $t3, WIDTH_4

	# row 2 - only erase if the address is on the screen
	ble $t3, DISPLAY_ADDRESS, ErasePlayerRow2Check
	bge $t3, $t0, ErasePlayerRow2Check

	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, -8
ErasePlayerRow2Check:
	
	addi $t3, $t3, WIDTH_4

	# row 3 - only erase if the address is on the screen
	ble $t3, DISPLAY_ADDRESS, ErasePlayerRow3Check
	bge $t3, $t0, ErasePlayerRow3Check

	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, -8
ErasePlayerRow3Check:
	
	addi $t3, $t3, WIDTH_4

	# row 4 - only erase if the address is on the screen
	ble $t3, DISPLAY_ADDRESS, ErasePlayerRow4Check
	bge $t3, $t0, ErasePlayerRow4Check

	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, -8
ErasePlayerRow4Check:
	
	addi $t3, $t3, WIDTH_4

	# row 5 - only erase if the address is on the screen
	ble $t3, DISPLAY_ADDRESS, ErasePlayerRow5Check
	bge $t3, $t0, ErasePlayerRow5Check

	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, 4
	sw $t2, 0($t3)
	addi $t3, $t3, -8
ErasePlayerRow5Check:
	
	addi $t3, $t3, WIDTH_4

	# row 6 - only erase if the address is on the screen
	ble $t3, DISPLAY_ADDRESS, ErasePlayerRow6Check
	bge $t3, $t0, ErasePlayerRow6Check

	sw $t2, 0($t3)
	addi $t3, $t3, 8
	sw $t2, 0($t3)
ErasePlayerRow6Check:
	
	lw $ra, 0($sp)		# pop $ra off stack
	addi $sp, $sp, 4

	jr $ra

HandleKeypress:
	lw $t2, 4($t1)
	beq $t2, 0x61, HandleKeypress_a
	beq $t2, 0x64, HandleKeypress_d
	beq $t2, 0x20, HandleKeypress_w
	beq $t2, 0x77, HandleKeypress_w
	beq $t2, 0x73, HandleKeypress_s
	beq $t2, 0x70, HandleKeypress_p
	beq $t2, 0x71, end

HandleKeypress_a:
	# if $s6 < 2, dont move. otherwise move left
	li $t2, 2
	blt $s6, $t2, HandleKeypress_aCheck
	addi $s6, $s6, -1
	li $t2, 1
	sw $t2, PlayerMoved
HandleKeypress_aCheck:
	jr $ra

HandleKeypress_d:
	# if $s6 > WIDTH - 3, dont move. otherwise move right
	li $t2, WIDTH
	addi $t2, $t2, -3
	bgt $s6, $t2, HandleKeypress_dCheck
	addi $s6, $s6, 1
	li $t2, 1
	sw $t2, PlayerMoved
HandleKeypress_dCheck:
	jr $ra

HandleKeypress_w:
	# if player is on a platform or double jump enabled, JUMP! otherwise do nothing
	lw $t0, OnPlatform
	bne $t0, 0, HandleKeypress_wCheckPlatform
	# if on a platform, jump
	li $t2, JUMP_TIME
	sw $t2, JumpTime
	j HandleKeypress_wCheckDouble
HandleKeypress_wCheckPlatform:
	lw $t1, DoubleJump
	bne $t1, 1, HandleKeypress_wCheckDouble
	# if double jump enabled and not on a platform, jump and disable double jump
	li $t2, JUMP_TIME
	sw $t2, JumpTime
	li $t1, 0
	sw $t1, DoubleJump
HandleKeypress_wCheckDouble:
	jr $ra

HandleKeypress_s:
	# if player is on a platform, move down, otherwise do nothing
	lw $t0, OnPlatform
	li $t1, 0
	bne $t0, $t1, HandleKeypress_sCheck
	addi $s7, $s7, 1
	li $t2, 1
	sw $t2, PlayerMoved
HandleKeypress_sCheck:
	jr $ra

HandleKeypress_p:
	j main

main:

# loop to fill background
FillBackground:
	li $t1, DISPLAY_ADDRESS # $t1 = top left pixel
	li $t2, AREA # $t2 = number of pixels to fill (all of them, in this case)
	li $t0, COL_BG
FillBackgroundLoop:
	sw $t0, 0($t1)
	addi $t1, $t1, 4 # go to next pixel
	addi $t2, $t2, -1
	bgtz $t2, FillBackgroundLoop
FillBackgroundEnd:

# reset crosses to random positions and wait times
	li $s1, 0 # $s1 holds which cross we are currently on
crossresetloop:
	sra $t1, $s1, 2 # $t1 = $s1 / 4 so the index number
	andi $t0, $t1, 0x1 # $t0 = the first bit i.e. whether its even or odd
	beq $t0, 0, crossresetloopeven
	j crossresetloopodd
crossresetloopeven:
	# for even numbers, go right and start on the left
	li $t0, -1
	li $t1, 1
	j crossresetloopparityend
crossresetloopodd:
	# for odd numbers, go left and start on the right
	li $t0, WIDTH
	addi $t0, $t0, 1
	li $t1, -1
crossresetloopparityend:
	sw $t0, CrossX($s1) # set x value
	sw $t1, CrossDir($s1) # set direction value

	li $v0, 42
	li $a0, 0
	li $a1, 47
	syscall
	addi $a0, $a0, 10
	sw $a0, CrossY($s1) # random y value

	li $v0, 42
	li $a0, 0
	li $a1, 100
	syscall
	sw $a0, CrossWait($s1) # random wait value

	addi $s1, $s1, 4 # increment
	blt $s1, 40, crossresetloop
crossresetend:

	# reset bat
	li $v0, 42
	li $a0, 0
	li $a1, WIDTH_M
	syscall
	sw $a0, BatX # random, from 0-WIDTH_M
	li $t0, 32
	sw $t0, BatY
	li $t0, 2
	sw $t0, BatDX
	li $t0, 1
	sw $t0, BatDY
	li $t0, -1
	sw $t0, BatState
	li $t0, BAT_ANIM_TIME
	sw $t0, BatStateCounter

	# reset platforms
	li $s1, 0
	li $t0, 10
	sw $t0, MovingPlatX($s1)
	li $t0, 1
	sw $t0, MovingPlatDX($s1)
	li $s1, 4
	li $t0, 118
	sw $t0, MovingPlatX($s1)
	li $t0, -1
	sw $t0, MovingPlatDX($s1)

	# reset health
	li $t0, HEALTH_START
	sw, $t0, Health

	# reset double jump (we start in the air so we have it)
	li $t0, 1
	sw, $t0, DoubleJump

	# reset jump frame
	li $t0, 0
	sw, $t0, JumpTime

	# reset invincibility time
	li $t0, 0
	sw, $t0, ITime
	
	# reset timer and timer wait
	lw $t0, Timer
	addi $t0, $zero, TIME_START
	sw $t0, Timer
	lw $t0, TimerWait
	addi $t0, $t0, 1
	sw $t0, TimerWait # decrement timer

	# use $s4 and $s5 for OLD player x and OLD player y
	li $s4, 64
	li $s5, 0
	# use $s6 and $s7 for player x and player y
	li $s6, 64
	li $s7, 0

loop:
	# game over check
	# if player is under the map, i.e. playery >= HEIGHT + 4, die
	li $t0, HEIGHT
	addi $t0, $t0, 4
	bge $s7, $t0, GameOver
	
	# if player health <= 0, die
	lw $t0, Health
	blez $t0, GameOver

	# reset whether player moved or not this frame
	li $t2, 0
	sw $t2, PlayerMoved
	
	# see if player is standing on platform
	# $t0 = IsPlayerOnPlatform(x,y)
	addi $sp, $sp, -4	# push x on stack
	sw $s6, 0($sp)
	addi $sp, $sp, -4	# push y on stack
	sw $s7, 0($sp)
	jal IsPlayerOnPlatform		# call IsPlayerOnPlatform(x,y)

	# see if player got hit, and handle it
	jal IsPlayerHitByCross		# call IsPlayerHitByCross()
	lw $t0, 0($sp)		# pop IsPlayerHitByCross() off stack
	addi $sp, $sp, 4

	# if we got hit by a cross, don't even check the bat. otherwise check if we got hit by a bat
	beq $t0, 1, bathitcheck
	jal IsPlayerHitByBat		# call IsPlayerHitByBat()
	lw $t0, 0($sp)		# pop IsPlayerHitByCross() off stack
	addi $sp, $sp, 4
bathitcheck:

	# if invincible, we don't get hit no matter what
	# decrement i-frame counter
	lw $t1, ITime
	blez $t1, invincibilitycheck
	li $t0, 0 # set hit detection to 0 (dont get hit)
	addi $t1, $t1, -1
	sw $t1, ITime
invincibilitycheck:

	# if hit, wait 250 ms, take away 1 health and if health == 0, game over
	bne $t0, 1, crosshitcheck
	
	#li $v0, 32
	#li $a0, 250
	#syscall

	# reset i-frame (become invincible)
	li $t1, I_TIME
	sw $t1, ITime

	# set player to be redrawn
	li $t0, 1
	sw $t0, PlayerMoved

	lw $t0, Health
	addi $t0, $t0, -1
	sw $t0, Health
crosshitcheck:

	# move down (gravity) not on a platform AND if we're not jumping
	# if $t0 != 0 and JumpTime == 0
	lw $t0, OnPlatform
	lw $t2, JumpTime
	beq $t0, 0, gravitycheck
	bne $t2, 0, gravitycheck
	addi $s7, $s7, 1
	li $t2, 1
	sw $t2, PlayerMoved
gravitycheck:
	
	# check for keyboard input
	li $t1, 0xffff0000
	lw $t2, 0($t1)
	bne $t2, 1, handlekeypresscheck
	jal HandleKeypress
handlekeypresscheck:

	# handle jumping: if JumpTime > 0, subtract 1 and move up 1
	lw $t2, JumpTime
	blez $t2, jumpcheck
	addi $t2, $t2, -1
	sw $t2, JumpTime
	addi $s7, $s7, -1
	li $t2, 1
	sw $t2, PlayerMoved
jumpcheck:

	# handle double jump: if on a platform and JumpTime <= 0, re-enable double jump
	lw $t2, JumpTime
	lw $t0, OnPlatform
	bgtz $t2, doublejumpcheck # if JumpTime > 0, skip
	bne $t0, 0, doublejumpcheck # if not on a platform, skip
	li $t1, 1
	sw $t1, DoubleJump # enable DoubleJump
doublejumpcheck:

	# update crosses
	li $s1, 0 # $s1 holds which cross we are currently on
crosscheckloop:
	# erase cross only if CrossWait($s1) <= 0
	lw $t0, CrossWait($s1)
	bgtz $t0, crosschecklooperasewait
crosschecklooperasewait:

	addi $sp, $sp, -4	# push $s1 on stack (for the function)
	sw $s1, 0($sp)
	jal EraseCross		# call EraseCross($s1)

	# update cross location using direction only if CrossWait($s1) <= 0
	lw $t0, CrossWait($s1)
	bgtz $t0, crosscheckloopwaitupdate

	lw $t2, CrossDir($s1)
	lw $t0, CrossX($s1)
	add $t0, $t0, $t2
	sw $t0, CrossX($s1)
	j crosscheckloopwait
crosscheckloopwaitupdate:
	# otherwise, decrement waiting time
	lw $t0, CrossWait($s1)
	addi $t0, $t0, -1
	sw $t0, CrossWait($s1)
crosscheckloopwait:

	# if a cross is off the screen, change dir and give it a new, random, y value and a new, random, wait value
	lw $t0, CrossX($s1)
	blt $t0, 0, crosscheck
	bge $t0, WIDTH, crosscheck
	j crosscheckupdate
crosscheck:
	# move back to edge
	lw $t2, CrossDir($s1)
	li $t3, WIDTH_M
	beq $t2, 1, crosscheckdir
	li $t3, 1
crosscheckdir:
	sw $t3, CrossX($s1)

	lw $t2, CrossDir($s1)
	li $t0, -1
	mult $t2, $t0
	mflo $t2
	sw $t2, CrossDir($s1) # flip direction

	li $v0, 42
	li $a0, 0
	li $a1, 47
	syscall
	addi $a0, $a0, 10
	sw $a0, CrossY($s1) # random y value

	li $v0, 42
	li $a0, 0
	li $a1, 100
	syscall
	sw $a0, CrossWait($s1) # random wait value

crosscheckupdate:
	# draw cross only if CrossWait($s1) <= 0
	lw $t0, CrossWait($s1)
	bgtz $t0, crosscheckupdatedrawwait

	addi $sp, $sp, -4	# push $s1 on stack
	sw $s1, 0($sp)
	jal DrawCross		# call DrawCross($s1)
crosscheckupdatedrawwait:

	addi $s1, $s1, 4
	blt $s1, 40, crosscheckloop
crosscheckend:

	# update bat

	# update bat's animation state
	# if the bat state counter <= 0, reset and change bat's state
	lw $t0, BatStateCounter
	blez $t0, batstatecheck
	addi $t0, $t0, -1
	sw $t0, BatStateCounter
	j batstatecheckend
batstatecheck:
	li $t0, BAT_ANIM_TIME
	sw $t0, BatStateCounter # reset counter
	lw $t0, BatState
	li $t1, -1
	mult $t0, $t1
	mflo $t0
	sw $t0, BatState # flip bat's state
batstatecheckend:

	jal EraseBat		# call EraseBat()

	# update bat's position

	# update x
	lw $t0, BatX	# get bat x
	lw $t1, BatDX	# get bat dx
	add $t0, $t0, $t1

	# if x + dx <= 1, flip dx
	# or if x + dx >= WIDTH - 2, flip dx
	ble $t0, 1, batxcheckflip
	li $t2, WIDTH
	addi $t2, $t2, -2
	bge $t0, $t2, batxcheckflip
	# otherwise, save BatX = x + dx
	sw $t0, BatX
	j batxcheck
batxcheckflip:
	# if we're here, we need to flip BatDX, and it might become 2 (or -2)

	blez $t1, batxchecknegative
batxcheckpositive:
	# if its positive
	# theres a 1 in 3 chance that DX becomes -1
	li $v0, 42
	li $a0, 0
	li $a1, 3
	syscall
	bne $a0, 2, batxcheckpositivechance # if random number from 1-3 = 2, change to -1
	li $t1, -1
	sw $t1, BatDX
	j batxcheck
batxcheckpositivechance: # otherwise, change to -2
	li $t1, -2
	sw $t1, BatDX
	j batxcheck

batxchecknegative:
	# if its negative
	# theres a 1 in 3 chance that DX becomes 1
	li $v0, 42
	li $a0, 0
	li $a1, 3
	syscall
	bne $a0, 2, batxchecknegativechance # if random number from 1-3 = 2, change to 1
	li $t1, 1
	sw $t1, BatDX
	j batxcheck
batxchecknegativechance: # otherwise, change to 2
	li $t1, 2
	sw $t1, BatDX
	j batxcheck
batxcheck:

	# update y
	lw $t0, BatY	# get bat y
	lw $t1, BatDY	# get bat dy
	add $t0, $t0, $t1

	# if y + dy <= 1, flip dy
	# or if y + dy >= HEIGHT - 1, change dy
	ble $t0, 1, batycheckflip
	li $t2, HEIGHT
	addi $t2, $t2, -1
	bge $t0, $t2, batycheckflip
	# otherwise, save BatY = y + dy
	sw $t0, BatY
	j batycheck
batycheckflip:
	# if we're here, we need to flip BatDY, and it might become 2 (or -2)

	blez $t1, batychecknegative
batycheckpositive:
	# if its positive
	# theres a 1 in 3 chance that DY becomes -2
	li $v0, 42
	li $a0, 0
	li $a1, 3
	syscall
	bne $a0, 2, batycheckpositivechance # if random number from 1-3 = 2, change to -2
	li $t1, -2
	sw $t1, BatDY
	j batycheck
batycheckpositivechance: # otherwise, change to -1
	li $t1, -1
	sw $t1, BatDY
	j batycheck

batychecknegative:
	# if its negative
	# theres a 1 in 3 chance that DY becomes 2
	li $v0, 42
	li $a0, 0
	li $a1, 3
	syscall
	bne $a0, 2, batychecknegativechance # if random number from 1-3 = 2, change to 2
	li $t1, 2
	sw $t1, BatDY
	j batycheck
batychecknegativechance: # otherwise, change to 1
	li $t1, 1
	sw $t1, BatDY
	j batycheck
batycheck:

	jal DrawBat			# call DrawBat()

	# draw moving platforms

	# erase first one
	li $t5, 0
	lw $t0, MovingPlatX($t5)
	li $t1, 15
	li $t2, 20
	addi $sp, $sp, -4
	sw $t0, 0($sp)		# push x on stack
	addi $sp, $sp, -4
	sw $t1, 0($sp)		# push y on stack
	addi $sp, $sp, -4
	sw $t2, 0($sp)		# push w on stack
	jal ErasePlatform

	# update first one
	li $t5, 0
	lw $t0, MovingPlatX($t5)	# get platform x
	lw $t1, MovingPlatDX($t5)	# get platform dx
	add $t0, $t0, $t1

	# if x - w/2 + dx <= 0, flip dx
	# or if x + w/2 + dx >= WIDTH, flip dx
	addi $t0, $t0, -10
	ble $t0, 0, plat1checkflip
	addi $t0, $t0, 20
	bge $t0, WIDTH, plat1checkflip
	# otherwise, save MovingPlatX = x + dx
	addi $t0, $t0, -10
	sw $t0, MovingPlatX($t5)
	
	# once the platform moves, move player if on top
	# if playery = platformy-3 AND playerx >= platformx - w/2 AND playerx <= platformx + w/2 AND playerx + dx > 1 AND playerx + dx < WIDTH - 1
	bne $s7, 12, plat1check
	addi $t0, $t0, -10
	blt $s6, $t0, plat1check
	addi $t0, $t0, 20
	bgt $s6, $t0, plat1check
	add $t2, $s6, $t1
	ble $t2, 1, plat1check
	li $t0, WIDTH
	addi $t0, $t0, -1
	bge $t2, $t0, plat1check
	# if we're here, save the player's new x (playerx += dx)
	add $s6, $s6, $t1
	li $t0, 1
	sw $t0, PlayerMoved # set player to be redrawn
	j plat1check
plat1checkflip:
	# if we're here, flip dx
	li $t2, -1
	mult $t1, $t2
	mflo $t2
	sw $t2, MovingPlatDX($t5)
plat1check:

	# draw first one
	li $t5, 0
	lw $t0, MovingPlatX($t5)
	li $t1, 15
	li $t2, 20
	addi $sp, $sp, -4
	sw $t0, 0($sp)		# push x on stack
	addi $sp, $sp, -4
	sw $t1, 0($sp)		# push y on stack
	addi $sp, $sp, -4
	sw $t2, 0($sp)		# push w on stack
	jal DrawPlatform

	# erase second one
	li $t5, 4
	lw $t0, MovingPlatX($t5)
	li $t1, 45
	li $t2, 20
	addi $sp, $sp, -4
	sw $t0, 0($sp)		# push x on stack
	addi $sp, $sp, -4
	sw $t1, 0($sp)		# push y on stack
	addi $sp, $sp, -4
	sw $t2, 0($sp)		# push w on stack
	jal ErasePlatform

	# update second one
	li $t5, 4
	lw $t0, MovingPlatX($t5)	# get platform x
	lw $t1, MovingPlatDX($t5)	# get platform dx
	add $t0, $t0, $t1

	# if x - w/2 + dx <= 0, flip dx
	# or if x + w/2 + dx >= WIDTH, flip dx
	addi $t0, $t0, -10
	ble $t0, 0, plat2checkflip
	addi $t0, $t0, 20
	bge $t0, WIDTH, plat2checkflip
	# otherwise, save MovingPlatX = x + dx
	addi $t0, $t0, -10
	sw $t0, MovingPlatX($t5)
	
	# once the platform moves, move player if on top
	# if playery = platformy-3 AND playerx >= platformx - w/2 AND playerx <= platformx + w/2 AND playerx + dx > 1 AND playerx + dx < WIDTH - 1
	bne $s7, 42, plat2check
	addi $t0, $t0, -10
	blt $s6, $t0, plat2check
	addi $t0, $t0, 20
	bgt $s6, $t0, plat2check
	add $t2, $s6, $t1
	ble $t2, 1, plat2check
	li $t0, WIDTH
	addi $t0, $t0, -1
	bge $t2, $t0, plat2check
	# if we're here, save the player's new x (playerx += dx)
	add $s6, $s6, $t1
	li $t0, 1
	sw $t0, PlayerMoved # set player to be redrawn
	j plat2check
plat2checkflip:
	# if we're here, flip dx
	li $t2, -1
	mult $t1, $t2
	mflo $t2
	sw $t2, MovingPlatDX($t5)
plat2check:

	# draw second one
	li $t5, 4
	lw $t0, MovingPlatX($t5)
	li $t1, 45
	li $t2, 20
	addi $sp, $sp, -4
	sw $t0, 0($sp)		# push x on stack
	addi $sp, $sp, -4
	sw $t1, 0($sp)		# push y on stack
	addi $sp, $sp, -4
	sw $t2, 0($sp)		# push w on stack
	jal DrawPlatform

	# if the player moved, erase and redraw him
	# otherwise, skip this code
	lw $t0, PlayerMoved
	li $t1, 1
	bne $t0, $t1, movecheck

	# erase player
	addi $sp, $sp, -4	# push x on stack
	sw $s4, 0($sp)
	addi $sp, $sp, -4	# push y on stack
	sw $s5, 0($sp)
	jal ErasePlayer		# call ErasePlayer(old x, old y)

	# set old x and old y to x and y
	add $s4, $s6, $zero
	add $s5, $s7, $zero

	# draw player in the new location
	addi $sp, $sp, -4	# push x on stack
	sw $s6, 0($sp)
	addi $sp, $sp, -4	# push y on stack
	sw $s7, 0($sp)
	jal DrawPlayer		# call DrawPlayer(x,y)
movecheck:

	# draw static platforms
	# put a platform on the first quarter
	li $a0, 32
	li $a1, 25
	li $a2, 50
	addi $sp, $sp, -4
	sw $a0, 0($sp)		# push x on stack
	addi $sp, $sp, -4
	sw $a1, 0($sp)		# push y on stack
	addi $sp, $sp, -4
	sw $a2, 0($sp)		# push w on stack
	jal DrawPlatform
	
	# put a platform in the middle
	li $a0, 64
	li $a1, 35
	li $a2, 50
	addi $sp, $sp, -4
	sw $a0, 0($sp)		# push x on stack
	addi $sp, $sp, -4
	sw $a1, 0($sp)		# push y on stack
	addi $sp, $sp, -4
	sw $a2, 0($sp)		# push w on stack
	jal DrawPlatform
	
	# put a platform on the third quarter
	li $a0, 96
	li $a1, 25
	li $a2, 50
	addi $sp, $sp, -4
	sw $a0, 0($sp)		# push a0 on stack
	addi $sp, $sp, -4
	sw $a1, 0($sp)		# push a1 on stack
	addi $sp, $sp, -4
	sw $a2, 0($sp)		# push a2 on stack
	jal DrawPlatform

	# draw GUI elements
	jal DrawHealth		# call DrawHealth()

	# handle time

	# decrease timer wait. if it hits 0 decrement time and draw time
	lw $t0, TimerWait
	addi $t0, $t0, -1
	sw $t0, TimerWait
	bgtz $t0, timercheck

	# decrease timer
	lw $t0, TimerWait
	addi $t0, $t0, FRAMES_FOR_SECOND
	sw $t0, TimerWait # reset timer wait
	lw $t0, Timer
	addi $t0, $t0, -1
	sw $t0, Timer # decrement timer

	# draw time
	# draw the first digit of time
	lw $t2, Timer # $t2 = first digit of time (currentTime % 10)
	li $t0, 10
	div $t2, $t2, $t0
	mfhi $t2

	li $t0, 5
	li $t1, 1
	li $t3, COL_HEALTH2
	addi $sp, $sp, -4
	sw $t0, 0($sp)		# push x on stack
	addi $sp, $sp, -4
	sw $t1, 0($sp)		# push y on stack
	addi $sp, $sp, -4
	sw $t2, 0($sp)		# push num on stack
	addi $sp, $sp, -4
	sw $t3, 0($sp)		# push col on stack
	jal DrawNumber		# call DrawNumber(x,y,num,col)
	
	# draw the second digit of time
	lw $t2, Timer # $t2 = second digit of time ((currentTime/10) % 10)
	li $t0, 10
	div $t2, $t2, $t0
	mflo $t2
	div $t2, $t2, $t0
	mfhi $t2

	li $t0, 1
	li $t1, 1
	li $t3, COL_HEALTH2
	addi $sp, $sp, -4
	sw $t0, 0($sp)		# push x on stack
	addi $sp, $sp, -4
	sw $t1, 0($sp)		# push y on stack
	addi $sp, $sp, -4
	sw $t2, 0($sp)		# push num on stack
	addi $sp, $sp, -4
	sw $t3, 0($sp)		# push col on stack
	jal DrawNumber		# call DrawNumber(x,y,num,col)

	# if timer hit 0 you win
	lw $t0, Timer
	blez $t0, YouWin

timercheck:

	# sleep
	li $v0, 32
	li $a0, WAIT_MS
	syscall
	j loop

GameOver:
# loop to darken background
GameOverFill:
	li $t1, DISPLAY_ADDRESS # $t1 = top left pixel
	li $t2, AREA # $t2 = number of pixels to fill (all of them, in this case)
GameOverFillLoop:
	# col = (col & 0xfefefe) >> 1 darkens the color
	lw $t0, 0($t1)
	andi $t0, $t0, 0xfefefe
	sra $t0, $t0, 1
	sw $t0, 0($t1)
	addi $t1, $t1, 4 # go to next pixel
	addi $t2, $t2, -1
	bgtz $t2, GameOverFillLoop
GameOverFillEnd:

	li $t6, 1
GameOverFinalLoop:
	# now draw the text manually
	li $t2, 38
	li $t3, 28

	# $t1 = GetAddress(x,y)
	addi $sp, $sp, -4	# push x on stack
	sw $t2, 0($sp)
	addi $sp, $sp, -4	# push y on stack
	sw $t3, 0($sp)
	jal GetAddress		# call GetAddress(x,y)
	lw $t1, 0($sp)		# pop GetAddress(x,y) off stack
	addi $sp, $sp, 4

	# flip $t6 to -1 or 1
	li $t7, -1
	mult $t6, $t7
	mflo $t6

	# set color depending on $t6
	li $t0, COL_PLAYER1
	beq $t6, -1, GameOverFinalLoopColorCheck
	li $t0, COL_PLAT_ACCENT
GameOverFinalLoopColorCheck:

	# row 1
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 28
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, -208

	# row 2
	sw $t0, 0($t1)
	addi $t1, $t1, 24

	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 44
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 24
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 4

	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, -208

	# row 3
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 28
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, -208

	# row 4
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 44
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 12
	
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 12
	
	sw $t0, 0($t1)
	addi $t1, $t1, 24
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 4

	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, -208

	# row 5
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 28
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, -180

	# row 7
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	
	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, -92

	# row 8
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 24
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 24
	sw $t0, 0($t1)
	
	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, -96

	# row 9
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 24
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, -96

	# row 10
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 24
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 24
	sw $t0, 0($t1)
	
	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, -96

	# row 11
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)

	# draw time
	# draw the first digit of time
	lw $t2, Timer # $t2 = first digit of time (currentTime % 10)
	li $t0, 10
	div $t2, $t2, $t0
	mfhi $t2

	li $t0, 76
	li $t1, 34
	li $t3, COL_PLAYER1

	addi $sp, $sp, -4
	sw $t0, 0($sp)		# push x on stack
	addi $sp, $sp, -4
	sw $t1, 0($sp)		# push y on stack
	addi $sp, $sp, -4
	sw $t2, 0($sp)		# push num on stack
	addi $sp, $sp, -4
	sw $t3, 0($sp)		# push col on stack
	jal DrawNumber		# call DrawNumber(x,y,num,col)
	
	# draw the second digit of time
	lw $t2, Timer # $t2 = second digit of time ((currentTime/10) % 10)
	li $t0, 10
	div $t2, $t2, $t0
	mflo $t2
	div $t2, $t2, $t0
	mfhi $t2

	li $t0, 72
	li $t1, 34
	li $t3, COL_PLAYER1

	addi $sp, $sp, -4
	sw $t0, 0($sp)		# push x on stack
	addi $sp, $sp, -4
	sw $t1, 0($sp)		# push y on stack
	addi $sp, $sp, -4
	sw $t2, 0($sp)		# push num on stack
	addi $sp, $sp, -4
	sw $t3, 0($sp)		# push col on stack
	jal DrawNumber		# call DrawNumber(x,y,num,col)

	# check for p press to restart
	li $t4, 0xffff0000
	lw $t5, 0($t4)
	bne $t5, 1, GameOverFinalLoopKeyCheck
	lw $t2, 4($t4)
	beq $t2, 0x70, HandleKeypress_p
	beq $t2, 0x71, end
GameOverFinalLoopKeyCheck:

	# sleep
	li $v0, 32
	li $a0, 500
	syscall
	j GameOverFinalLoop

YouWin:
# loop to lighten background
YouWinFill:
	li $t1, DISPLAY_ADDRESS # $t1 = top left pixel
	li $t2, AREA # $t2 = number of pixels to fill (all of them, in this case)
YouWinFillLoop:
	# col = (col & 0x7f7f7f) << 1 lightens the color
	lw $t0, 0($t1)
	andi $t0, $t0, 0x7f7f7f
	sll $t0, $t0, 1
	sw $t0, 0($t1)
	addi $t1, $t1, 4 # go to next pixel
	addi $t2, $t2, -1
	bgtz $t2, YouWinFillLoop
YouWinFillEnd:

	li $t6, 1
YouWinFinalLoop:
	# now draw the text manually
	li $t2, 43
	li $t3, 28

	# $t1 = GetAddress(x,y)
	addi $sp, $sp, -4	# push x on stack
	sw $t2, 0($sp)
	addi $sp, $sp, -4	# push y on stack
	sw $t3, 0($sp)
	jal GetAddress		# call GetAddress(x,y)
	lw $t1, 0($sp)		# pop GetAddress(x,y) off stack
	addi $sp, $sp, 4

	# flip $t6 to -1 or 1
	li $t7, -1
	mult $t6, $t7
	mflo $t6

	# set color depending on $t6
	li $t0, COL_PLAYER1
	beq $t6, -1, YouWinFinalLoopColorCheck
	li $t0, COL_PLAT_ACCENT
YouWinFinalLoopColorCheck:

	# row 1
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 32
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 12
	sw $t0, 0($t1)

	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, -160

	# row 2
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 32
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)

	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, -160

	# row 3
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 12

	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 32
	
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)

	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, -160

	# row 4
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 16

	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 32
	
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)

	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, -160

	# row 5
	addi $t1, $t1, 8
	sw $t0, 0($t1)
	addi $t1, $t1, 16

	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 32

	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 12
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)

	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, -160

	# row 7
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 24

	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, -144

	# row 8
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 24

	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 32

	sw $t0, 0($t1)
	addi $t1, $t1, 16
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)

	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, -144

	# row 9
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 32

	sw $t0, 0($t1)
	addi $t1, $t1, 16
	
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, -144

	# row 10
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 24

	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 32

	sw $t0, 0($t1)
	addi $t1, $t1, 16
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8
	sw $t0, 0($t1)

	addi $t1, $t1, WIDTH_4
	addi $t1, $t1, -144

	# row 11
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)
	addi $t1, $t1, 8

	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 4
	sw $t0, 0($t1)
	addi $t1, $t1, 16

	sw $t0, 0($t1)
	addi $t1, $t1, 16
	
	sw $t0, 0($t1)
	addi $t1, $t1, 16
	sw $t0, 0($t1)

	# draw health
	lw $t2, Health # $t2 = first digit of health (currentHealth % 10)
	li $t0, 10
	div $t2, $t2, $t0
	mfhi $t2

	li $t0, 81
	li $t1, 34
	li $t3, COL_PLAYER1

	addi $sp, $sp, -4
	sw $t0, 0($sp)		# push x on stack
	addi $sp, $sp, -4
	sw $t1, 0($sp)		# push y on stack
	addi $sp, $sp, -4
	sw $t2, 0($sp)		# push num on stack
	addi $sp, $sp, -4
	sw $t3, 0($sp)		# push col on stack
	jal DrawNumber		# call DrawNumber(x,y,num,col)

	# check for p press to restart
	li $t4, 0xffff0000
	lw $t5, 0($t4)
	bne $t5, 1, YouWinFinalLoopKeyCheck
	lw $t2, 4($t4)
	beq $t2, 0x70, HandleKeypress_p
	beq $t2, 0x71, end
YouWinFinalLoopKeyCheck:

	# sleep
	li $v0, 32
	li $a0, 500
	syscall
	j YouWinFinalLoop

end:
li $v0, 10
syscall
