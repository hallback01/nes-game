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
  sta $30 ; padel x position

  ; tick
  lda #0
  sta tick
  sta tick + 1

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
  adc $30
  sta $30

  ; wait for the ppu
  jsr delay

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

nmi:

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

  jsr ticks_into_numbers

  lda #$00
  sta $2003

  jsr draw
  jmp game_loop

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
  lda remainder
  cmp #0
  beq num_done
  lda #'0' - 1  
  ldy tick_string + 5
  adc remainder
  sta tick_string, y
  iny
  sty tick_string + 5
  jmp num_not_done
num_done:

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
