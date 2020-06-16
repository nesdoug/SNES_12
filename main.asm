; example 11 SNES code

.p816
.smart

.segment "ZEROPAGE"
temp1: .res 2
temp2: .res 2
temp3: .res 2
temp4: .res 2
temp5: .res 2
temp6: .res 2
pad1: .res 2
pad1_new: .res 2
pad2: .res 2
pad2_new: .res 2
in_nmi: .res 2
which_effect: .res 1
change_mode: .res 1




.include "defines.asm"
.include "macros.asm"
.include "init.asm"
.include "unrle.asm"







.segment "CODE"

; enters here in forced blank
main:
.a16 ; just a standardized setting from init code
.i16
	phk
	plb
	

	
; DMA from BG_Palette to CGRAM
	A8
	stz $2121 ; $2121 cg address = zero
	
	stz $4300 ; transfer mode 0 = 1 register write once
	lda #$22  ; $2122
	sta $4301 ; destination, pal data
	ldx #.loword(BG_Palette)
	stx $4302 ; source
	lda #^BG_Palette
	sta $4304 ; bank
	ldx #256
	stx $4305 ; length
	lda #1
	sta $420b ; start dma, channel 0
	
	
; DMA from Tiles to VRAM	
	lda #V_INC_1 ; the value $80
	sta vram_inc ; $2115 = set the increment mode +1
	ldx #$0000
	stx vram_addr ; set an address in the vram of $0000
	
	lda #1
	sta $4300 ; transfer mode, 2 registers 1 write
			  ; $2118 and $2119 are a pair Low/High
	lda #$18  ; $2118
	sta $4301 ; destination, vram data

; decompress first
	AXY16
	lda #.loword(Tiles)
	ldx #^Tiles
	jsl unrle ; unpacks to 7f0000 UNPACK_ADR
	; returns y = length
	; ax = unpack address (x is bank)
	sta $4302 ; source
	txa
	A8
	sta $4304 ; bank
	sty $4305 ; length
	lda #1
	sta $420b ; start dma, channel 0
	
	
	
; DMA from Tilemap to VRAM	
	ldx #$6000
	stx vram_addr ; set an address in the vram of $6000
	
; decompress first
	AXY16
	lda #.loword(Tilemap)
	ldx #^Tilemap
	jsl unrle ; unpacks to 7f0000 UNPACK_ADR
	; returns y = length
	; ax = unpack address (x is bank)
	sta $4302 ; source
	txa
	A8
	sta $4304 ; bank
	sty $4305 ; length
	lda #1
	sta $420b ; start dma, channel 0
	
	
	
; DMA from Tilemap2 to VRAM	
	ldx #$6800
	stx vram_addr ; set an address in the vram of $6000
	
; decompress first
	AXY16
	lda #.loword(Tilemap2)
	ldx #^Tilemap2
	jsl unrle ; unpacks to 7f0000 UNPACK_ADR
	; returns y = length
	; ax = unpack address (x is bank)
	sta $4302 ; source
	txa
	A8
	sta $4304 ; bank
	sty $4305 ; length
	lda #1
	sta $420b ; start dma, channel 0	
	
;fix the BG off by 1 glitch at the bottom of the screen	
	lda #$ff ;-1
	sta bg1_scroll_y ; $210e ;write twice
	sta bg1_scroll_y
	sta bg2_scroll_y ; $2110 ;write twice
	sta bg2_scroll_y

	lda #1 ; mode 1, tilesize 8x8 all
	sta bg_size_mode ; $2105
	stz bg12_tiles ; $210b BG 1 and 2 TILES at VRAM address $0000
	lda #$60 ; bg1 map at VRAM address $6000
	sta tilemap1 ; $2107
	lda #$68 ; bg2 map at VRAM address $6800
	sta tilemap2 ; $2108

	lda #BG1_ON ; layer 1 on main
	sta main_screen ; $212c
	
	lda #BG2_ON ; layer 2 on sub
	sta sub_screen ; $212d
	
	lda #NMI_ON|AUTO_JOY_ON
	sta $4200
	
	lda #FULL_BRIGHT ; $0f = turn the screen on (end forced blank)
	sta fb_bright ; $2100


InfiniteLoop:	
	A8
	XY16
	jsr wait_nmi ;wait for the beginning of v-blank


	
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



	jsr pad_poll ;read controllers
	
	A16
	lda pad1_new
	and #(KEY_B|KEY_Y|KEY_A|KEY_X) ;any button
	beq @no_buttons
	A8
	inc change_mode
@no_buttons:
	;A16 not needed
	jmp InfiniteLoop
	
	
	
;Set each color math effect
;color_add_sel = $2130
;ccmm--sd
;cc = main screen black if... 00 = never
;--11---- = prevent color math $30
;--00---- = allow color math
;------0- = fixed color
;------1- = sub screen
;
;color_add_des = $2131
;shbo4321
;0------- add
;1------- subtract
;-0------ normal
;-1------ result is halved
;b = backdrop, o = sprites, 4321 = layers effected

;color_fixed = $2132
;bgr ccccc
;3 writes, each with a color bit set


Set_CM0:
.a8
;nothing, turn off color math
	lda #$30
	sta color_add_sel ; $2130
	
;turn off fixed color	
	lda #$e0
	sta color_fixed ; $2132
	rts
	
	
Set_CM1:
.a8
;color math = add
;turn on color math, subscreen
	lda #$02
	sta color_add_sel ; $2130
	
;adding, not half, affect all layers	
	lda #$3f
	sta color_add_des ; $2131
	rts	
	
	
Set_CM2:
.a8
;color math = add half
;turn on color math, subscreen
	lda #$02
	sta color_add_sel ; $2130
	
;adding, half, affect all layers	
	lda #$7f
	sta color_add_des ; $2131
	rts	
	
	
Set_CM3:
.a8
;color math = subtract
;turn on color math, subscreen
	lda #$02
	sta color_add_sel ; $2130
	
;subtract, not half, affect all layers	
	lda #$bf
	sta color_add_des ; $2131
	rts	

	
Set_CM4:
.a8
;color math = subtract half
;turn on color math, subscreen
	lda #$02
	sta color_add_sel ; $2130
	
;subtract, half, affect all layers	
	lda #$ff
	sta color_add_des ; $2131
	rts	

	
Set_CM5:
.a8
;color math = only the fixed color, add
;turn on color math, fixed color
	lda #$00
	sta color_add_sel ; $2130
	
;adding, not half, affect all layers	
	lda #$3f
	sta color_add_des ; $2131
	
;set the fixed color to red 50%
	lda #$2f ;red at 50%
	sta color_fixed ; $2132
	rts
	
	
	
	
Set_CM6:
.a8
;always clip the main screen to black.
;and add the sub screen = show only the sub screen.
;turn on color math, subscreen
	lda #$c2 ;= clip main always to black
	sta color_add_sel ; $2130
	
;adding, not half, affect all layers	
	lda #$3f
	sta color_add_des ; $2131
	
;turn off fixed color	
	lda #$e0
	sta color_fixed ; $2132
	rts	
	
	
	
	
wait_nmi:
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
	
	
pad_poll:
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
	

.include "header.asm"	


.segment "RODATA1"

BG_Palette:
; 256 bytes
.incbin "ImageConverter/Background.pal"

Tiles:
; 4bpp tileset
.incbin "ImageConverter/BG_Tiles.rle"



Tilemap:
.incbin "ImageConverter/rocks.rle"

Tilemap2:
.incbin "ImageConverter/RGB.rle"



