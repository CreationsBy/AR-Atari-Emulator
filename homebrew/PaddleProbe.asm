; Original controller test fixture, GPL-2.0-or-later. Not bundled in the app.
; Samples actual TIA capacitor inputs after known scanline delays.
.org $F000
Reset:
    SEI
    CLD
    LDX #$FF
    TXS
    LDA #$00
Clear:
    STA $00,X
    DEX
    BNE Clear
Frame:
    LDA #$82
    STA $01
    LDA #$02
    STA $00
    STA $02
    STA $02
    STA $02
    LDA #$00
    STA $00
    LDX #$25
Blank:
    STA $02
    DEX
    BNE Blank
    LDA #$00
    STA $01
    LDX #$64
First:
    STA $02
    DEX
    BNE First
    LDA $08
    STA $80
    LDA $09
    STA $81
    LDA $0280
    STA $82
    LDX #$5C
Second:
    STA $02
    DEX
    BNE Second
    LDA $08
    STA $83
    LDA #$02
    STA $01
    LDX #$1E
Overscan:
    STA $02
    DEX
    BNE Overscan
    JMP Frame
.org $FFFA
    .word Reset,Reset,Reset
