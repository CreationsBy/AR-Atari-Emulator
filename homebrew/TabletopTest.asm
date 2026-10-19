; Tabletop Test, original cartridge source, GPL-2.0-or-later.
; 4K NTSC. Real 6507/TIA/RIOT code, not a frontend animation.
; D-pad moves blue sprite. Fire plays a TIA tone and enables missile 0.
; Select changes room/wall color. Reset restores initial state.
; Red sprite moves autonomously until P2 moves/fires, then P2 controls it until Reset.
; Hardware P0/playfield collision is copied to RAM.
VSYNC=$00
VBLANK=$01
WSYNC=$02
NUSIZ0=$04
COLUP0=$06
COLUP1=$07
COLUPF=$08
COLUBK=$09
CTRLPF=$0A
PF0=$0D
PF1=$0E
PF2=$0F
RESP0=$10
RESP1=$11
RESM0=$12
RESBL=$14
AUDC0=$15
AUDC1=$16
AUDF0=$17
AUDF1=$18
AUDV0=$19
AUDV1=$1A
GRP0=$1B
GRP1=$1C
ENAM0=$1D
ENABL=$1F
HMP0=$20
HMP1=$21
HMM0=$22
HMOVE=$2A
CXCLR=$2C
CXP0FB=$02
INPT4=$0C
INPT5=$0D
SWCHA=$0280
SWCHB=$0282
INTIM=$0284
TIM64T=$0296
PlayerX=$80
PlayerY=$81
EnemyX=$82
Counter=$83
Fire=$84
Room=$85
Collision=$86
Temp0=$87
Temp1=$88
SelectHeld=$89
Player2Active=$8A
EnemyY=$8B
Fire2=$8C

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
    LDA #$44
    STA PlayerX
    LDA #$30
    STA PlayerY
    LDA #$78
    STA EnemyX
    LDA #$28
    STA EnemyY
    LDA #$84
    STA COLUP0
    LDA #$46
    STA COLUP1
    LDA #$01
    STA CTRLPF
    LDA #$04
    STA AUDC0
    STA AUDC1
    LDA #$10
    STA AUDF0
    LDA #$18
    STA AUDF1

Frame:
    LDA #$02
    STA VBLANK
    STA VSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    LDA #$00
    STA VSYNC
    LDA #$2B
    STA TIM64T
    INC Counter
    LDA SWCHB
    AND #$01
    BNE NoReset
    JMP Reset
NoReset:
    LDA SWCHB
    AND #$02
    BNE ReleaseSelect
    LDA SelectHeld
    BNE Inputs
    INC Room
    INC SelectHeld
    JMP Inputs
ReleaseSelect:
    LDA #$00
    STA SelectHeld
Inputs:
    LDA SWCHA
    AND #$80
    BNE NoRight
    INC PlayerX
NoRight:
    LDA SWCHA
    AND #$40
    BNE NoLeft
    DEC PlayerX
NoLeft:
    LDA SWCHA
    AND #$20
    BNE NoDown
    INC PlayerY
NoDown:
    LDA SWCHA
    AND #$10
    BNE NoUp
    DEC PlayerY
NoUp:
    LDA PlayerX
    CMP #$20
    BCS XLowOK
    LDA #$20
XLowOK:
    CMP #$69
    BCC XHighOK
    LDA #$68
XHighOK:
    STA PlayerX
    LDA PlayerY
    CMP #$0C
    BCS YLowOK
    LDA #$0C
YLowOK:
    CMP #$4D
    BCC YHighOK
    LDA #$4C
YHighOK:
    STA PlayerY
    LDA Player2Active
    BNE SecondPlayer
    LDA SWCHA
    AND #$0F
    CMP #$0F
    BNE ActivateSecond
    LDA INPT5
    AND #$80
    BEQ ActivateSecond
    LDA Counter
    AND #$1F
    CLC
    ADC #$68
    STA EnemyX
    JMP SecondSound
ActivateSecond:
    INC Player2Active
SecondPlayer:
    LDA SWCHA
    AND #$08
    BNE NoRight2
    INC EnemyX
NoRight2:
    LDA SWCHA
    AND #$04
    BNE NoLeft2
    DEC EnemyX
NoLeft2:
    LDA SWCHA
    AND #$02
    BNE NoDown2
    INC EnemyY
NoDown2:
    LDA SWCHA
    AND #$01
    BNE NoUp2
    DEC EnemyY
NoUp2:
    LDA EnemyX
    CMP #$20
    BCS XLowOK2
    LDA #$20
XLowOK2:
    CMP #$89
    BCC XHighOK2
    LDA #$88
XHighOK2:
    STA EnemyX
    LDA EnemyY
    CMP #$0C
    BCS YLowOK2
    LDA #$0C
YLowOK2:
    CMP #$4D
    BCC YHighOK2
    LDA #$4C
YHighOK2:
    STA EnemyY
SecondSound:
    LDA INPT5
    EOR #$80
    AND #$80
    STA Fire2
    BEQ Quiet2
    LDA #$06
    BNE Volume2
Quiet2:
    LDA #$00
Volume2:
    STA AUDV1
    LDA INPT4
    EOR #$80
    AND #$80
    STA Fire
    BEQ Quiet
    LDA #$08
    BNE Volume
Quiet:
    LDA #$00
Volume:
    STA AUDV0
    LDA Room
    AND #$01
    BEQ GreenRoom
    LDA #$28
    BNE WallColor
GreenRoom:
    LDA #$C8
WallColor:
    STA COLUPF
    LDA CXP0FB
    STA Collision
    STA CXCLR
    LDA PlayerX
    LDX #$00
    JSR Position
    LDA EnemyX
    LDX #$01
    JSR Position
    LDA PlayerX
    LDX #$02
    JSR Position
    STA WSYNC
    STA HMOVE
WaitBlank:
    LDA INTIM
    BNE WaitBlank
    STA WSYNC
    LDA #$00
    STA VBLANK
    LDY #$00
Kernel:
    STA WSYNC
    TYA
    SEC
    SBC PlayerY
    CMP #$08
    BCS EmptyP0
    TAX
    LDA Sprite,X
    JMP DrawP0
EmptyP0:
    LDA #$00
DrawP0:
    STA GRP0
    TYA
    SEC
    SBC EnemyY
    CMP #$08
    BCS EmptyP1
    TAX
    LDA Sprite,X
    JMP DrawP1
EmptyP1:
    LDA #$00
DrawP1:
    STA GRP1
    STA WSYNC
    LDA PF0Rows,Y
    STA PF0
    LDA PF1Rows,Y
    STA PF1
    LDA PF2Rows,Y
    STA PF2
    LDA #$00
    CPY #$3C
    BNE NoMissile
    LDA Fire
    BEQ NoMissile
    LDA #$02
NoMissile:
    STA ENAM0
    INY
    CPY #$60
    BNE Kernel
    LDA #$02
    STA WSYNC
    STA VBLANK
    LDA #$00
    STA GRP0
    STA GRP1
    STA ENAM0
    LDX #$1D
Overscan:
    STA WSYNC
    DEX
    BNE Overscan
    JMP Frame

; Standard coarse/fine TIA horizontal positioning, invoked during VBLANK.
Position:
    STA WSYNC
    SEC
Subtract15:
    SBC #$0F
    BCS Subtract15
    EOR #$07
    ASL A
    ASL A
    ASL A
    ASL A
    STA HMP0,X
    STA RESP0,X
    RTS
Sprite:
    .byte $18,$3C,$7E,$DB,$FF,$24,$66,$42
PF0Rows:
    .byte $10,$10,$10,$10,$10,$10,$FF,$FF,$FF,$FF,$10,$10,$10,$10,$10,$10
    .byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    .byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    .byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    .byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    .byte $10,$10,$10,$10,$10,$10,$FF,$FF,$FF,$FF,$10,$10,$10,$10,$10,$10
PF1Rows:
    .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$08,$08,$08,$08,$08,$08,$08,$08,$08,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00
PF2Rows:
    .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00
.org $FFFA
    .word Reset,Reset,Reset
