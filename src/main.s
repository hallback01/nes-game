.segment "HEADER"
  ; .byte "NES", $1A      ; iNES header identifier
  .byte $4E, $45, $53, $1A
  .byte 2               ; 2x 16KB PRG code
  .byte 1               ; 1x  8KB CHR data
  .byte $01, $00        ; mapper 0, vertical mirroring

.segment "VECTORS"
  .addr nmi
  .addr reset

  ;; IRQ (unused)
  .addr 0

; "nes" linker config requires a STARTUP section, even if it's empty
.segment "STARTUP"

; Main code segement for the program
.segment "CODE"

tick = $00

; divide variables
remainder = $02
number1 = $04
number2 = $06

; tick string
tick_string = $0010

; random seed (2 bytes)
random_seed = $000e

player_x = $0217
player_y = $0214

reset:

  sei		; disable IRQs
  cld		; disable decimal mode
  ldx #$40
  stx $4017	; disable APU frame IRQ
  ldx #$ff 	; Set up stack
  txs		;  .
  inx		; now X = 0
  stx $2000	; disable NMI
  stx $2001 	; disable rendering
  stx $4010 	; disable DMC IRQs
  jsr wait_for_blank
  ldx #$00
clear_memory:
  lda #$ff
  sta $0000, x
  sta $0100, x
  sta $0200, x
  sta $0300, x
  sta $0400, x
  sta $0500, x
  sta $0600, x
  sta $0700, x
  inx
  bne clear_memory

main:

  lda #$00
  sta $4014
  
  ; initialize memory
  lda #1
  sta $20
  lda #16
  sta player_x ; padel x position
  lda #192
  sta player_y ; padel y position
  lda #0
  sta $0215 ; padel sprite
  sta $0216 ; padel background

  ; initialize random seed
  lda #10
  sta random_seed
  sta random_seed + 1

  ; tick
  lda #0
  sta tick
  sta tick + 1

  ;set string draw data
  jsr set_string_data

; load palettes
load_palettes:
  lda $2002
  lda #$3f
  sta $2006
  lda #$00
  sta $2006
  ldx #$00
palette_loop:
  lda palettes, x
  sta $2007
  inx
  cpx #$20
  bne palette_loop

enable_rendering:
  jsr wait_for_vblank
  lda #%10000000	; Enable NMI
  sta $2000
  lda #%00010110	; Enable Sprites
  sta $2001

game_loop:
  
; read controller input, data is saved on address 0x20
  jsr poll_controller

  ; input
  ldx #$0 ;direction vector
  lda #%00000010 
  and $20
  beq no_left_press
  dex
no_left_press:

  lda #%00000001
  and $20
  beq no_right_press
  inx
no_right_press:

  ; add data to position
  clc
  txa
  adc player_x
  sta player_x

  ; wait for the ppu
  jsr wait_for_blank

  jmp game_loop

; Bit order: A, B, SELECT, START, UP, DOWN, LEFT, RIGHT
poll_controller: 

  lda #1
  sta $20 ; controller data pointer address
  
  ; send latch pulse to the primary controller
  sta $4016
  lda #0
  sta $4016

  ; read controller data
controller_read_loop:
  lda $4016
  lsr a
  rol $20
  bcc controller_read_loop

  rts

delay:
  ldy #$10
  ldx #$ff
delay1:
  nop
  dex
  bne delay1
  ldx #$ff
  dey
  bne delay1
  rts

draw:

  ;draw paddle, we need to draw 2 sprites
  ;sprite 1
  lda #192  ;y
  sta $2004
  lda #$00  ;sprite
  sta $2004
  lda #$00  ;palette 0
  sta $2004
  lda $30   ;x
  sta $2004

  ;sprite 2
  lda #192
  sta $2004
  lda #$00
  sta $2004
  lda #$00
  sta $2004
  lda $30
  clc
  sbc #7
  sta $2004

  rts

set_string_data:

  lda #08 ; Y value
  sta $0200
  sta $0204
  sta $0208
  sta $020c
  sta $0210

  lda #01 ; x value
  sta $0203
  lda #10
  sta $0207
  lda #19
  sta $020b
  lda #28
  sta $020f
  lda #37
  sta $0213

  lda #0 ; palette
  sta $0202
  sta $0206
  sta $020a
  sta $020e
  sta $0212

  rts

update_string:
  lda tick_string + 4
  clc
  sbc #'0' - 2
  sta $0201
  lda tick_string + 3
  clc
  sbc #'0' - 2
  sta $0205
  lda tick_string + 2
  clc
  sbc #'0' - 2
  sta $0209
  lda tick_string + 1
  clc
  sbc #'0' - 2
  sta $020d
  lda tick_string
  clc
  sbc #'0' - 2
  sta $0211
  rts

nmi:

  lda $05
  clc
  adc #1
  cmp #60
  sta $05
  bne dont_increase_tick
  lda #0
  sta $05

  clc
  lda tick
  adc #1
  sta tick
  bcc done
  clc
  lda tick + 1
  adc #1
  sta tick + 1
done:

  jsr random
  sta $30

  jsr ticks_into_numbers
  jsr update_string

dont_increase_tick:  
  lda #$02
  sta $4014

  rti

ticks_into_numbers:

  lda #0
  sta tick_string
  sta tick_string + 1
  sta tick_string + 2
  sta tick_string + 3
  sta tick_string + 4
  sta tick_string + 5 ; this is the string length

  lda tick
  sta number1
  lda tick+1
  sta number1 + 1

  lda #10
  sta number2
  lda #0
  sta number2 + 1

num_not_done:
  jsr divide

  lda #'0' 
  ldy tick_string + 5
  clc
  adc remainder
  sta tick_string, y
  iny
  sty tick_string + 5

  lda number1 + 1
  cmp #0
  bne num_not_done 
  lda number1
  cmp #0
  bne num_not_done
  rts

wait_for_blank:
  bit $2002
  bpl wait_for_blank
  rts

wait_for_vblank:

  lda $2002
  and #%10000000
  bne wait_for_vblank
  rts

divide: 

  ; set remainder to zero
  lda #0
  sta remainder
  sta remainder + 1

  ; set up counter
  ldx #16
divide1:
  asl number1
  rol number1 + 1
  rol remainder
  rol remainder + 1
  lda remainder
  sec
  sbc number2
  tay
  lda remainder + 1
  sbc number2 +1
  bcc divide2
  sta remainder + 1
  sty remainder
  inc number1
divide2:
  dex
  bne divide1
  rts

; puts a random number between 0 and 255 in the A register
random:
  ldy #8
  lda random_seed

random1:
  asl
  rol random_seed + 1
  bcc random2
  eor #$39
random2:
  dey
  bne random1
  sta random_seed
  cmp #0
  rts

palettes:
  ; Background Palette
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00

  ; Sprite Palette
  .byte $20, $0f, $11, $2a
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00

; Character memory
.segment "CHARS"
  ; Padel, sprite index 0
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %11111111
  .byte %11111111

  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte $00, $00, $00, $00, $00, $00, $00, $00

  ; character '0', index 1
  .byte %11111111
  .byte %11111111
  .byte %11000011
  .byte %11000011
  .byte %11000011
  .byte %11000011
  .byte %11111111
  .byte %11111111
  .byte $00, $00, $00, $00, $00, $00, $00, $00

  ; character '1', index 2
  .byte %01111000
  .byte %01111000
  .byte %00011000
  .byte %00011000
  .byte %00011000
  .byte %00011000
  .byte %11111111
  .byte %11111111
  .byte $00, $00, $00, $00, $00, $00, $00, $00

  ; character '2', index 3
  .byte %11111111
  .byte %11111111
  .byte %00000011
  .byte %11111111
  .byte %11111111
  .byte %11000000
  .byte %11111111
  .byte %11111111
  .byte $00, $00, $00, $00, $00, $00, $00, $00

  ; character '3', index 4
  .byte %11111111
  .byte %11111111
  .byte %00000011
  .byte %00111111
  .byte %00111111
  .byte %00000011
  .byte %11111111
  .byte %11111111
  .byte $00, $00, $00, $00, $00, $00, $00, $00

  ; character '4', index 5
  .byte %11000011
  .byte %11000011
  .byte %11000011
  .byte %11111111
  .byte %11111111
  .byte %00000011
  .byte %00000011
  .byte %00000011
  .byte $00, $00, $00, $00, $00, $00, $00, $00

  ; character '5', index 6
  .byte %11111111
  .byte %11111111
  .byte %11000000
  .byte %11111111
  .byte %11111111
  .byte %00000011
  .byte %11111111
  .byte %11111111
  .byte $00, $00, $00, $00, $00, $00, $00, $00

  ; character '6', index 7
  .byte %11111111
  .byte %11111111
  .byte %11000000
  .byte %11111111
  .byte %11111111
  .byte %11000011
  .byte %11111111
  .byte %11111111
  .byte $00, $00, $00, $00, $00, $00, $00, $00

  ; character '7', index 8
  .byte %11111111
  .byte %11111111
  .byte %00000011
  .byte %00000011
  .byte %00001100
  .byte %00110000
  .byte %00110000
  .byte %11000000
  .byte $00, $00, $00, $00, $00, $00, $00, $00

  ; character '8', index 9
  .byte %11111111
  .byte %11111111
  .byte %11000011
  .byte %11111111
  .byte %11111111
  .byte %11000011
  .byte %11111111
  .byte %11111111
  .byte $00, $00, $00, $00, $00, $00, $00, $00

  ; character '9', index A
  .byte %11111111
  .byte %11111111
  .byte %11000011
  .byte %11111111
  .byte %11111111
  .byte %00000011
  .byte %11111111
  .byte %11111111
  .byte $00, $00, $00, $00, $00, $00, $00, $00
