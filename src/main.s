.segment "HEADER"
  ; .byte "NES", $1A      ; iNES header identifier
  .byte $4E, $45, $53, $1A
  .byte 2               ; 2x 16KB PRG code
  .byte 1               ; 1x  8KB CHR data
  .byte $01, $00        ; mapper 0, vertical mirroring

.segment "VECTORS"
  ;; When an NMI happens (once per frame if enabled) the label nmi:
  .addr nmi
  ;; When the processor first turns on or is reset, it will jump to the label reset:
  .addr reset
  ;; External interrupt IRQ (unused)
  .addr 0

; "nes" linker config requires a STARTUP section, even if it's empty
.segment "STARTUP"

; Main code segement for the program
.segment "CODE"

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

main:

  ; initialize memory
  lda #1
  sta $20
  lda #16
  sta $30 ; padel x position

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
  lda #%10000000	; Enable NMI
  sta $2000
  lda #%00010000	; Enable Sprites
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
  jsr draw
  jmp game_loop

wait_for_blank:
  bit $2002
  bpl wait_for_blank
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
