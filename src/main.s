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
number_string = $0010

; random seed (2 bytes)
random_seed = $000e

; player movement
player_dir_x =  $40
player_dir_y =  $41
movement_tick = $42
tail_length = $43

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
  sta $0219
  sta $021a
  lda #8
  sta player_dir_x
  lda #0 
  sta player_dir_y
  
  lda #32
  sta tail_length
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
  ; enable nmi
  lda #%10000000
  sta $2000
  ; enable sprites, and the vertical first line for both the sprite and background
  lda #%00010110
  sta $2001

game_loop:
  
  ; read controller input, data is saved on address 0x20
  jsr poll_controller

  ; check if we should move the player (according to the timer)
  lda movement_tick
  cmp #15
  bmi no_movement 

  ; we are moving the player.
  lda #0
  sta movement_tick

  ; move the tail first
  jsr move_tail

  ; move the head
  ; x
  lda player_x
  clc
  adc player_dir_x
  sta player_x
  ; y
  lda player_y
  clc
  adc player_dir_y
  sta player_y

no_movement:

  ; input
  lda #%00000010 
  and $20
  beq no_left_press
  lda #0
  sta player_dir_y
  lda #$f8
  sta player_dir_x
no_left_press:

  lda #%00000001
  and $20
  beq no_right_press
  lda #0
  sta player_dir_y
  lda #8
  sta player_dir_x
no_right_press:

  lda #%00000100
  and $20
  beq no_down_press
  lda #0
  sta player_dir_x
  lda #8
  sta player_dir_y
no_down_press:

  lda #%00001000
  and $20
  beq no_up_press
  lda #0
  sta player_dir_x
  lda #$f8
  sta player_dir_y
no_up_press:

  ; wait for the ppu
  jsr wait_for_blank
  jmp game_loop

; moves the tail.
; loops backwards beginning at the very end of the tail
move_tail:

  lda tail_length
  ldx #0
:
  inx
  inx
  inx
  inx
  sbc #1
  cmp #0
  bne :-
  txa
  tay
  dey
  dey
  dey
  dey 
 
  lda tail_length
next_cell:

  ; check if we are at the beginning of the tail, if so, break the loop
  cmp #0
  beq tail_moved
  sbc #1
  pha
 
  ; copy the next cell's position to this one
  lda player_x, y
  sta player_x, x

  lda player_y, y
  sta player_y, x

  ; decrease x and y register by 4
  dex
  dex
  dex
  dex
  dey
  dey
  dey
  dey

  ; we go to the next tail piece
  pla
  jmp next_cell

tail_moved:
  rts

; bit order: A, B, SELECT, START, UP, DOWN, LEFT, RIGHT
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
  lda number_string + 4
  clc
  sbc #'0' - 2
  sta $0201
  lda number_string + 3
  clc
  sbc #'0' - 2
  sta $0205
  lda number_string + 2
  clc
  sbc #'0' - 2
  sta $0209
  lda number_string + 1
  clc
  sbc #'0' - 2
  sta $020d
  lda number_string
  clc
  sbc #'0' - 2
  sta $0211
  rts

nmi:

  ; background testing
  lda #0
  sta $2001
  lda #$20
  sta $2006
  lda #$e5
  sta $2006
  lda #2
  sta $2007

  lda #$20
  sta $2006
  lda #$00
  sta $2006

  lda $2007
  lda $2007
  sta $53

  lda #%00011110
  sta $2001

  ; save the registers to the stack
  sta $50
  stx $51
  sty $52

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

  ; increase movement tick timer
  lda movement_tick
  clc
  adc #1
  sta movement_tick

  ; send sprite data to ppu
  lda #$02
  ;sta $4014

  ; put back the from the stack to the registers
  lda $50
  ldx $51
  ldy $52

  ;return form interrupt
  rti

ticks_into_numbers:

  lda #0
  sta number_string
  sta number_string + 1
  sta number_string + 2
  sta number_string + 3
  sta number_string + 4
  sta number_string + 5 ; this is the string length

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
  ldy number_string + 5
  clc
  adc remainder
  sta number_string, y
  iny
  sty number_string + 5

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
  sbc number2 + 1
  bcc divide2
  sta remainder + 1
  sty remainder
  inc number1
divide2:
  dex
  bne divide1
  rts

; multiply number1 with number2 and places the result in number1
multiply:
  rts

; puts a random number between 0 and 255 in the A register (depending on the seed.. from the random seed variable)
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
  .byte $0f, $20, $11, $2a
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00

  ; Sprite Palette
  .byte $0f, $20, $11, $2a
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00

; Character memory
.segment "CHARS"
  ; Padel, sprite index 0
  .byte %11111111
  .byte %11111111
  .byte %11111111
  .byte %11111111
  .byte %11111111
  .byte %11111111
  .byte %11111111
  .byte %11111111
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
