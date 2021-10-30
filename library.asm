; some DMA functions

.segment "CODE"

DMA_Palette:
;copies the buffer to the CGRAM
	php
	A8
	XY16
	stz $2121 ;Palette Address 
	ldx #$2200 ;1 reg 1 write, to PAL_DATA 2122
	stx $4300 ; and 4301
	ldx	#.loword(PAL_BUFFER)
	stx $4302 ; and 4303
	lda #^PAL_BUFFER ;bank #
	sta $4304
	ldx #$200 ;512 bytes
	stx $4305 ; and 4306
	lda #1
	sta $420B ; DMA_ENABLE start dma, channel 0
	plp
	rts
	
	
DMA_OAM:
;copy from OAM BUFFER to the OAM RAM
	php
	A16
	XY8
	stz $2102 ;OAM address
	
	lda #$0400 ;1 reg 1 write, 2104 oam data
	sta $4300
	lda #.loword(OAM_BUFFER)
	sta $4302 ; source
	ldx #^OAM_BUFFER
	stx $4304 ; bank
	lda #544
	sta $4305 ; length
	ldx #1
	stx $420B ; DMA_ENABLE start dma, channel 0
	plp
	rts			



