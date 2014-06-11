; freemlib for Neo-Geo Example 02: Hello World on the Sprite Layer
;==============================================================================;
	; defines
	include "../../src/inc/neogeo.inc"
	include "../../src/inc/ram_bios.inc"
	include "../../src/inc/mess_macro.inc"
	include "ram_user.inc"
;------------------------------------------------------------------------------;
	; headers
	include "header_68k.inc"
	include "header_cart.inc"
;==============================================================================;
; USER
; Needs to perform actions according to the value in BIOS_USER_REQUEST.
; Must jump back to SYSTEM_RETURN at the end so the BIOS can have control.

USER:
	move.b	d0,REG_DIPSW		; kick watchdog
	lea		BIOS_WORKRAM,sp		; set stack pointer to BIOS_WORKRAM
	move.w	#0,LSPC_MODE		;
	move.w	#7,LSPC_IRQ_ACK		; ack. all IRQs

	move.w	#$2000,sr			; Enable VBlank interrupt, go Supervisor

	; Handle user request
	clr.l	d0
	move.b	(BIOS_USER_REQUEST).l,d0
	lsl.b	#2,d0				; shift value left to get offset into table
	lea		cmds_USER_REQUEST,a0
	movea.l	(a0,d0),a0
	jsr		(a0)

;------------------------------------------------------------------------------;
; BIOS_USER_REQUEST commands
cmds_USER_REQUEST:
	dc.l	userReq_StartupInit	; Command 0 (Initialize)
	dc.l	userReq_Eyecatch	; Command 1 (Custom eyecatch)
	dc.l	userReq_Game		; Command 2 (Demo Game/Game)
	dc.l	userReq_Game		; Command 3 (Title Display)

;------------------------------------------------------------------------------;
; userReq_StartupInit
; Initialize the backup work area.

userReq_StartupInit:
	move.b	d0,REG_DIPSW		; kick watchdog
	jmp		SYSTEM_RETURN

;------------------------------------------------------------------------------;
; userReq_Eyecatch
; Only to be fully coded if your game uses its own eyecatch (value at $114 is 1).
; Otherwise, jmp to SYSTEM_RETURN.

userReq_Eyecatch:
	move.b	d0,REG_DIPSW		; kick watchdog
	jmp		SYSTEM_RETURN

;------------------------------------------------------------------------------;
; userReq_Game
; This is the complex one. For this demo, we're only going to treat it as a
; combination of initialization and main loop, but for a real game, you might
; want to have BIOS_USER_REQUEST commands 2 and 3 do different things.

userReq_Game:
	move.b	d0,REG_DIPSW		; kick watchdog

	; perform your initialization

	; set up palettes
	move.b	d0,PALETTE_BANK0	; use palette bank 0
	lea		paletteData,a0
	lea		PALETTES,a1
	move.l	#(16*NUM_PALETTES)-1,d7
.ldpal:
	move.w	(a0)+,(a1)+
	dbra	d7,.ldpal

	jsr		FIX_CLEAR			; clear fix layer, add borders on sides
	jsr		LSP_1st				; clear first sprite

	jsr		CreateDisplay		; create initial display

; execution continues into main loop.
;------------------------------------------------------------------------------;
; mainLoop
; The game's main loop. This is where you run the actual game part.

mainLoop:
	move.b	d0,REG_DIPSW		; kick the watchdog

	; do things like:
	; Check Input
	jsr		WaitVBlank			; wait for the vblank
	; and other things that would normally happen in a game's main loop.

	jmp		mainLoop

;==============================================================================;
; PLAYER_START
; Called by the BIOS if one of the Start buttons is pressed while the player
; has enough credits (or if the the time runs out on the title menu?).
; We're not using this in this demo.

PLAYER_START:
	move.b	d0,REG_DIPSW		; kick the watchdog
	rts

;==============================================================================;
; DEMO_END
; Called by the BIOS when the Select button is pressed; ends the demo early.

DEMO_END:
	; if necessary, store any items in the (MVS) backup RAM.
	rts

;==============================================================================;
; COIN_SOUND
; Called by the BIOS when a coin is inserted; should play a coin drop sound.
; We don't actually do anything here since this isn't meant to take coins.

COIN_SOUND:
	; Send a sound code
	rts

;==============================================================================;
; VBlank
; VBlank interrupt, run things we want to do every frame.

VBlank:
	; check if the BIOS wants to run its vblank
	btst	#7,BIOS_SYSTEM_MODE
	bne		.gamevbl
	; run BIOS vblank
	jmp		SYSTEM_INT1

	; run the game's vblank
.gamevbl
	movem.l d0-d7/a0-a6,-(a7)	; save registers
	move.w	#4,LSPC_IRQ_ACK		; acknowledge the vblank interrupt
	move.b	d0,REG_DIPSW		; kick the watchdog

	; do things in vblank

.endvbl:
	jsr		SYSTEM_IO			; "Call SYSTEM_IO every 1/60 second."
	jsr		MESS_OUT			; Puzzle Bobble calls MESS_OUT just after SYSTEM_IO
	move.b	#0,flag_VBlank		; clear vblank flag so waitVBlank knows to stop
	movem.l (a7)+,d0-d7/a0-a6	; restore registers
	rte

;==============================================================================;
; IRQ2
; Level 2/timer interrupt, unused here. You could use it for effects, though.

IRQ2:
	move.w	#2,LSPC_IRQ_ACK		; ack. interrupt #2 (HBlank)
	move.b	d0,REG_DIPSW		; kick watchdog

	rte

;==============================================================================;
; WaitVBlank
; Waits for VBlank to finish (via a flag cleared at the end).

WaitVBlank:
	move.b	#1,flag_VBlank

.waitLoop
	tst.b	flag_VBlank
	bne.s	.waitLoop

	rts

;==============================================================================;
; include freemlib function files
	include "../../src/inc/sprites.inc"

;==============================================================================;
; CreateDisplay
; Creates the display for this demonstration.

CreateDisplay:
	jsr		Display_Sprite		; display a sprite
	jsr		Display_Message		; fix layer message
	rts

;------------------------------------------------------------------------------;
; Display_Sprite
; Displays the "Hello World!!!" metasprite.

Display_Sprite:
	; tell MESS_OUT we're busy messing with the data, so don't run.
	; this is more of a safeguard; your program should probably have a flag
	; called LSPC_BUSY (or GPU_BUSY, VRAM_BUSY, whatever...) that's used in
	; situations like this instead.
	bset.b	#0,BIOS_MESS_BUSY

	move.w	#1,LSPC_INCR		; set vram increment = 1

	; draw "Hello" sprite using VRAM writes
	;--------------------------------------
	; set up SCB1 for each sprite
	; sprite  1: H
	move.w	#$0040,LSPC_ADDR
	move.w	#$0040,LSPC_DATA	; tile $00040: H
	move.w	#$0000,LSPC_DATA	; palette 0, tile msb 0, no attributes
	; sprite  2: E
	move.w	#$0080,LSPC_ADDR
	move.w	#$0041,LSPC_DATA	; tile $00041: E
	move.w	#$0000,LSPC_DATA	; palette 0, tile msb 0, no attributes
	; sprite  3: L 1
	move.w	#$00C0,LSPC_ADDR
	move.w	#$0042,LSPC_DATA	; tile $00042: L
	move.w	#$0000,LSPC_DATA	; palette 0, tile msb 0, no attributes
	; sprite  4: L 2
	move.w	#$0100,LSPC_ADDR
	move.w	#$0042,LSPC_DATA	; tile $00042: L
	move.w	#$0000,LSPC_DATA	; palette 0, tile msb 0, no attributes
	; sprite  5: O
	move.w	#$0140,LSPC_ADDR
	move.w	#$0043,LSPC_DATA	; tile $00043: O
	move.w	#$0000,LSPC_DATA	; palette 0, tile msb 0, no attributes

	; set up SCB2 for sprites 1-5
	move.w	#$8001,LSPC_ADDR
	move.w	#$0FFF,LSPC_DATA	; Sprite 1: full scale in X ($F) and Y ($FF)
	move.w	#$0FFF,LSPC_DATA	; Sprite 2: full scale in X ($F) and Y ($FF)
	move.w	#$0FFF,LSPC_DATA	; Sprite 3: full scale in X ($F) and Y ($FF)
	move.w	#$0FFF,LSPC_DATA	; Sprite 4: full scale in X ($F) and Y ($FF)
	move.w	#$0FFF,LSPC_DATA	; Sprite 5: full scale in X ($F) and Y ($FF)

	; set up SCB3 for sprite 1
	move.w	#$8201,LSPC_ADDR
	move.w	#((496-80)<<7)|1,LSPC_DATA	; Y pos = 80, sprite height = 1
	; set up SCB3 for sprites 2-5 (sticky bit)
	move.w	#$0040,LSPC_DATA	; Sprite 2 sticky bit
	move.w	#$0040,LSPC_DATA	; Sprite 3 sticky bit
	move.w	#$0040,LSPC_DATA	; Sprite 4 sticky bit
	move.w	#$0040,LSPC_DATA	; Sprite 5 sticky bit

	; set up SCB4 for sprite 1
	move.w	#$8401,LSPC_ADDR
	move.w	#(64<<7),LSPC_DATA	; X pos = 64

	; Draw a random test sprite using freemlib's spr_Load
	;----------------------------------------------------
	move.w	#12,d0
	lea		sprite_Test,a0
	jsr		spr_Load

	; draw "World!" sprite with a freemlib metasprite
	;------------------------------------------------
	move.w	#6,d0
	lea		metaspr_World,a0
	jsr		mspr_Load

	; sprite  6: W
	; sprite  7: O
	; sprite  8: R
	; sprite  9: L
	; sprite 10: D
	; sprite 11: !!!

	; time to put sprite data into the VRAM.

	bclr.b	#0,BIOS_MESS_BUSY	; tell MESS_OUT it can run again
	rts

;------------------------------------------;
; Metasprite data for "World!!!" sprites.
metaspr_World:
	dc.w	6					; number of sprites
	; pointers to sprite data
	dc.l	sprite_World_W
	dc.l	sprite_World_O
	dc.l	sprite_World_R
	dc.l	sprite_World_L
	dc.l	sprite_World_D
	dc.l	sprite_World_Exc	; (the "!!!" is actually one tile)

;-------------------------------------;
; Sprite Data for Hello World sprite. ;

; sprmac_SpriteData's parameters:
; \1			Sprite Height (in tiles)		(word) (bottom 6 bits of SCB3)
; \2			X position						(word) 9 bits (SCB4); X<<7
; \3			Y position						(word) 9 bits (SCB3); convert to (496-Y)<<7
; \4			Pointer to SCB1 tilemap data	(long)
; \5			Horizontal Shrink (0-F)			(byte)
; \6			Vertical Shrink (00-FF)			(byte)

; Note: The sticky bit is not handled with this macro; it's handled in mspr_Load.

; "World!!!"
sprite_World_W:		sprmac_SpriteData	1,160,80,sprite_HelloWorldW_SCB1,$0F,$FF
sprite_World_O:		sprmac_SpriteData	1,160,80,sprite_HelloWorldO_SCB1,$0F,$FF
sprite_World_R:		sprmac_SpriteData	1,160,80,sprite_HelloWorldR_SCB1,$0F,$FF
sprite_World_L:		sprmac_SpriteData	1,160,80,sprite_HelloWorldL_SCB1,$0F,$FF
sprite_World_D:		sprmac_SpriteData	1,160,80,sprite_HelloWorldD_SCB1,$0F,$FF
sprite_World_Exc:	sprmac_SpriteData	1,160,80,sprite_HelloWorldExc_SCB1,$0F,$FF

sprite_Test:		sprmac_SpriteData	2,224,96,sprite_Test_SCB1,$0F,$FF

;-------------------------------------------;
; Initial SCB1 data for Hello World sprite. ;
; To make things simple, we'll use sprmac_SCB1Data to store our sprite data.

; sprmac_SCB1Data's parameters:
; \1			Tile Number				(long) 20 bits; SCB1 even, SCB1 odd (bits 4-7)
; \2			Palette Number			(byte) 8 bits; SCB1 odd (bits 8-15)
; \3			Auto-Animation (0,4,8)	(byte) 2 bits; SCB1 odd (bits 2,3) 4=2bit, 8=3bit
; \4			Vertical Flip			(byte) 1 bit; SCB1 odd (bit 1)
; \5			Horizontal Flip			(byte) 1 bit; SCB1 odd (bit 0)

sprite_HelloWorldH_SCB1:	sprmac_SCB1Data	$00040,0,0,0,0		; H			spr1
sprite_HelloWorldE_SCB1:	sprmac_SCB1Data	$00041,0,0,0,0		; E			spr2
sprite_HelloWorldL_SCB1:	sprmac_SCB1Data	$00042,0,0,0,0		; L			spr3,spr4,spr9
sprite_HelloWorldO_SCB1:	sprmac_SCB1Data	$00043,0,0,0,0		; O			spr5,spr7
sprite_HelloWorldW_SCB1:	sprmac_SCB1Data	$00044,0,0,0,0		; W			spr6
sprite_HelloWorldR_SCB1:	sprmac_SCB1Data	$00045,0,0,0,0		; R			spr8
sprite_HelloWorldD_SCB1:	sprmac_SCB1Data	$00046,0,0,0,0		; D			spr10
sprite_HelloWorldExc_SCB1:	sprmac_SCB1Data	$00047,0,0,0,0		; !!!		spr11

sprite_Test_SCB1:
	sprmac_SCB1Data	$00048,0,0,0,0
	sprmac_SCB1Data	$00048,0,0,0,0
	sprmac_SCB1Data	$00048,0,0,0,0
	sprmac_SCB1Data	$00048,0,0,0,0
	sprmac_SCB1Data	$00048,0,0,0,0
	sprmac_SCB1Data	$00048,0,0,0,0

;------------------------------------------------------------------------------;
; Display_Message
; Writes some tiles to the fix layer, to show how sprites interact with it.

Display_Message:
	bset.b	#0,BIOS_MESS_BUSY	; tell MESS_OUT we're busy messing with the data
	movea.l	BIOS_MESS_POINT,a0	; get current message pointer
	move.l	#string_HelloSpr,(a0)+	; add fix layer text
	move.l	a0,BIOS_MESS_POINT  ; Update pointer
	bclr.b	#0,BIOS_MESS_BUSY	; tell MESS_OUT it can run again
	rts

; centering: 7 cells on each side (6 if accounting for side clear)
string_HelloSpr:
	messmac_Format	0,$00FF		; command 01: bytes+end code; top byte $00, end code $FF
	messmac_SetIncr	$20			; command 02: vram auto-increment $20 (horiz.)
	messmac_SetAddr	$70EF		; command 03: set vram addr to $70F0
	messmac_OutData
	dc.b	"fix layer text for testing",$FF
	dc.b	$00
	dc.w	$0000

;==============================================================================;
; [Palettes]
NUM_PALETTES	equ 4		; used in palette loading loop

paletteData:
	; Palette Set $00 (Fix/Spr)
	dc.w	$8000			; reference color, must be $8000 black
	dc.w	$7FFF			; White
	dc.w	$0000			; normal Black
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	;--------------------------------------------------------------------------;
	; Palette Set $01 (Fix/Spr)
	dc.w	$0000			; transparent color
	dc.w	$0F00			; Red
	dc.w	$0000			; Black
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	;--------------------------------------------------------------------------;
	; Palette Set $02 (Fix/Spr)
	dc.w	$0000			; transparent color
	dc.w	$00F0			; Green
	dc.w	$0000			; Black
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	;--------------------------------------------------------------------------;
	; Palette Set $03 (Fix/Spr)
	dc.w	$0000			; transparent color
	dc.w	$000F			; Blue
	dc.w	$0000			; Black
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000
	dc.w	$0000