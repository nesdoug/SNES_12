; example 12 SNES code

.p816
.smart



.include "regs.asm"
.include "variables.asm"
.include "macros.asm"
.include "init.asm"
.include "unrle.asm"






.segment "CODE"

; enters here in forced blank
Main:
.a16 ; the setting from init code
.i16
	phk
	plb
	

	
; COPY PALETTES to PAL_BUFFER	
;	BLOCK_MOVE  length, src_addr, dst_addr
	BLOCK_MOVE  256, BG_Palette, PAL_BUFFER
	A8 ;block move will put AXY16. Undo that.
	
; DMA from PAL_BUFFER to CGRAM
	jsr DMA_Palette ; in init.asm
	
	
; DMA from Tiles to VRAM	
	lda #V_INC_1 ; the value $80
	sta VMAIN ; $2115 = set the increment mode +1
	
	
	ldx #$0000
	stx VMADDL ; set an address in the vram of $0000

; decompress 
	UNPACK_TO_VRAM Tiles

	
	
; DMA from Tilemap to VRAM	
	ldx #$6000
	stx VMADDL ; set an address in the vram of $6000
	
; decompress 
	UNPACK_TO_VRAM Tilemap

	
	
; DMA from Tilemap2 to VRAM	
	ldx #$6800
	stx VMADDL ; set an address in the vram of $6000
	
; decompress 
	UNPACK_TO_VRAM Tilemap2

	
	A8
;fix the BG off by 1 glitch at the bottom of the screen	
	lda #$ff ;-1
	sta BG1VOFS ; $210e ;write twice
	sta BG1VOFS
	sta BG2VOFS ; $2110 ;write twice
	sta BG2VOFS

	lda #1 ; mode 1, tilesize 8x8 all
	sta BGMODE ; $2105
	stz BG12NBA ; $210b BG 1 and 2 TILES at VRAM address $0000
	lda #$60 ; bg1 map at VRAM address $6000
	sta BG1SC ; $2107
	lda #$68 ; bg2 map at VRAM address $6800
	sta BG2SC ; $2108

	lda #BG1_ON ; layer 1 on main
	sta TM ; $212c
	
	lda #BG2_ON ; layer 2 on sub
	sta TS ; $212d
	
	
	lda #NMI_ON|AUTO_JOY_ON
	sta NMITIMEN ;$4200
	
	lda #FULL_BRIGHT ; $0f = turn the screen on (end forced blank)
	sta INIDISP ; $2100


Infinite_Loop:	
	A8
	XY16
	jsr Wait_NMI ;wait for the beginning of v-blank


	
	;which_effect
	A8
	lda change_mode
	beq @no_change
	stz change_mode
	
	
@inc_mode:
	lda which_effect
	inc a
	cmp #7
	bcc @ok ;0-6 ok
	lda #0
@ok:
	sta which_effect	
	
	
	lda which_effect
	bne @1
	jsr Set_CM0
	bra @end_change
@1:
	cmp #1
	bne @2
	jsr Set_CM1
	bra @end_change
@2:	
	cmp #2
	bne @3
	jsr Set_CM2
	bra @end_change
@3:	
	cmp #3
	bne @4
	jsr Set_CM3
	bra @end_change	
@4:	
	cmp #4
	bne @5
	jsr Set_CM4
	bra @end_change	
@5:	
	cmp #5
	bne @6
	jsr Set_CM5
	bra @end_change	
@6:	
	jsr Set_CM6
	
	
@end_change:

@no_change:



	jsr Pad_Poll ;read controllers
	
	A16
	lda pad1_new
	and #(KEY_B|KEY_Y|KEY_A|KEY_X) ;any button
	beq @no_buttons
	A8
	inc change_mode
@no_buttons:
	;A16 not needed
	jmp Infinite_Loop
	
	
	
;Set each color math effect
;CGWSEL = $2130
;ccmm--sd
;cc = main screen black if... 00 = never
;--11---- = prevent color math $30
;--00---- = allow color math
;------0- = fixed color
;------1- = sub screen
;
;CGADSUB = $2131
;shbo4321
;0------- add
;1------- subtract
;-0------ normal
;-1------ result is halved
;b = backdrop, o = sprites, 4321 = layers effected

;COLDATA = $2132
;bgr ccccc
;3 writes, each with a color bit set


Set_CM0:
.a8
;nothing, turn off color math
	lda #$30
	sta CGWSEL ; $2130
	
;turn off fixed color	
	lda #$e0
	sta COLDATA ; $2132
	rts
	
	
Set_CM1:
.a8
;color math = add
;turn on color math, subscreen
	lda #$02
	sta CGWSEL ; $2130
	
;adding, not half, affect all layers	
	lda #$3f
	sta CGADSUB ; $2131
	rts	
	
	
Set_CM2:
.a8
;color math = add half
;turn on color math, subscreen
	lda #$02
	sta CGWSEL ; $2130
	
;adding, half, affect all layers	
	lda #$7f
	sta CGADSUB ; $2131
	rts	
	
	
Set_CM3:
.a8
;color math = subtract
;turn on color math, subscreen
	lda #$02
	sta CGWSEL ; $2130
	
;subtract, not half, affect all layers	
	lda #$bf
	sta CGADSUB ; $2131
	rts	

	
Set_CM4:
.a8
;color math = subtract half
;turn on color math, subscreen
	lda #$02
	sta CGWSEL ; $2130
	
;subtract, half, affect all layers	
	lda #$ff
	sta CGADSUB ; $2131
	rts	

	
Set_CM5:
.a8
;color math = only the fixed color, add
;turn on color math, fixed color
	lda #$00
	sta CGWSEL ; $2130
	
;adding, not half, affect all layers	
	lda #$3f
	sta CGADSUB ; $2131
	
;set the fixed color to red 50%
	lda #$2f ;red at 50%
	sta COLDATA ; $2132
	rts
	
	
	
	
Set_CM6:
.a8
;always clip the main screen to black.
;and add the sub screen = show only the sub screen.
;turn on color math, subscreen
	lda #$c2 ;= clip main always to black
	sta CGWSEL ; $2130
	
;adding, not half, affect all layers	
	lda #$3f
	sta CGADSUB ; $2131
	
;turn off fixed color	
	lda #$e0
	sta COLDATA ; $2132
	rts	
	
	
	
	
Wait_NMI:
.a8
.i16
;should work fine regardless of size of A
	lda in_nmi ;load A register with previous in_nmi
@check_again:	
	WAI ;wait for an interrupt
	cmp in_nmi	;compare A to current in_nmi
				;wait for it to change
				;make sure it was an nmi interrupt
	beq @check_again
	rts	
	
	
Pad_Poll:
.a8
.i16
	php
	A8
@wait:
; wait till auto-controller reads are done
	lda $4212
	lsr a
	bcs @wait
	
	A16
	lda pad1
	sta temp1 ; save last frame
	lda $4218 ; controller 1
	sta pad1
	eor temp1
	and pad1
	sta pad1_new
	
	lda pad2
	sta temp1 ; save last frame
	lda $421a ; controller 2
	sta pad2
	eor temp1
	and pad2
	sta pad2_new
	plp
	rts	
	
	
	
;jsl here	
DMA_VRAM:
.a16
.i16
; do during forced blank	
; first set VRAM_Addr and VRAM_Inc
; a = source
; x = source bank
; y = length in bytes
	php
	rep #$30 ;axy16
	sta $4302 ; source and 4303
	sep #$20 ;a8
	txa
	sta $4304 ; bank
	lda #$18
	sta $4301 ; destination, vram data
	sty $4305 ; length, and 4306
	lda #1
	sta $4300 ; transfer mode, 2 registers, write once = 2 bytes
	sta $420b ; start dma, channel 0
	plp
	rtl		
	

.include "header.asm"	


.segment "RODATA1"

BG_Palette:
; 256 bytes
.incbin "M1TE/Background.pal"

Tiles:
; 4bpp tileset
.incbin "M1TE/BG_Tiles.rle"



Tilemap:
.incbin "M1TE/rocks.rle"

Tilemap2:
.incbin "M1TE/RGB.rle"



