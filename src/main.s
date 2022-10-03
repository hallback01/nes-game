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
  ldx #$ff
  txs
  lda #$03
  sta $2006
  lda #$00
  sta $2006
  jsr wait_for_blank

main:
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

forever:
  jmp forever

nmi:
  ldx #$00 	; Set SPR-RAM address to 0
  stx $2003
@loop:	
  lda hello, x 	; Load the hello message into SPR-RAM
  sta $2004
  inx
  cpx #$20
  bne @loop
  rti

wait_for_blank:
   bit $2002
   bpl wait_for_blank
   rts 

hello:
  ; x pos, sprite, idk, y pos
  .byte $00, $00, $00, $00 	; Why do I need these here?
  .byte $00, $00, $00, $00
  .byte $6c, $00, $00, $6c
  .byte $6c, $01, $00, $76
  .byte $6c, $02, $00, $80
  .byte $6c, $00, $00, $8a
  .byte $6c, $03, $00, $94

palettes:
  ; Background Palette
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00

  ; Sprite Palette
  .byte $0f, $04, $11, $2a
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00

; Character memory
.segment "CHARS"
  .byte %00000000	; T (00)
  .byte %11111111
  .byte %00011000
  .byte %00011000
  .byte %00011000
  .byte %00011000
  .byte %00011000
  .byte %00011000

  .byte %11111111
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00011000

  .byte $00, $00, $00, $00, $00, $00, $00, $00

  .byte %11111111	; E (01)
  .byte %11111111
  .byte %11000000
  .byte %11111100
  .byte %11111100
  .byte %11000000
  .byte %11111111
  .byte %11111111
  .byte $00, $00, $00, $00, $00, $00, $00, $00

  .byte %11111111	; S (02)
  .byte %11111111
  .byte %11000000
  .byte %11111111
  .byte %11111111
  .byte %00000011
  .byte %11111111
  .byte %11111111
  .byte $00, $00, $00, $00, $00, $00, $00, $00

  .byte %11000000	; ! (03)
  .byte %11000000
  .byte %11000000
  .byte %11000000
  .byte %00000000
  .byte %00000000
  .byte %11000011
  .byte %11000011

  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000011
  .byte %00000011
  .byte %00000011
  .byte %00000011
  .byte $00, $00, $00, $00, $00, $00, $00, $00
