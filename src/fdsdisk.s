.include "nes.inc"
.include "global.inc"

FOR_ACTION53 = 0
INES_HDR = $10
PRG_SIZE = $4000
.define FILE "ruder.nes" ; static inclusion after assembling PRG to $8000 is easier...

BOOT_ID = 4 ; highest file ID code to load while booting
FILE_COUNT = BOOT_ID + 1 + 1 ; lie about the file count so the BIOS continues seeking

.segment "SIDE1A"
; block 1
.byte $01
.byte "*NINTENDO-HVC*"
.byte $00 ; manufacturer
.byte "ZAP" ; game ID
.byte $20 ; normal disk
.byte $00 ; game version
.byte $00 ; side
.byte $00 ; disk
.byte $00 ; disk type
.byte $00 ; unknown
.byte BOOT_ID ; boot file ID
.byte $FF,$FF,$FF,$FF,$FF
.byte $36 ; year (heisei era)
.byte $06 ; month
.byte $14 ; day
.byte $49 ; country
.byte $61, $00, $00, $02, $00, $00, $00, $00, $00 ; unknown
.byte $36 ; year (heisei era)
.byte $06 ; month
.byte $14 ; day
.byte $00, $80 ; unknown
.byte $00, $00 ; disk writer serial number
.byte $07 ; unknown
.byte $00 ; disk write count
.byte $00 ; actual disk side
.byte $00 ; disk type?
.byte $00 ; disk version?
; block 2
.byte $02
.byte FILE_COUNT

.segment "PRG_HDR"
; block 3
.import __PRG_RUN__
.import __PRG_SIZE__
.byte $03
.byte 0,0
.byte "ZAPRUDER"
.word __PRG_RUN__
.word __PRG_SIZE__
.byte 0 ; PRG
; block 4
.byte $04
.segment "PRG"
.incbin "ruder.nes", $10, PRG_SIZE ; 

.segment "VEC_HDR"
; block 3
.import __VECTORS_RUN__
.import __VECTORS_SIZE__
.byte $03
.byte 1,1
.byte "VECTORS-"
.word __VECTORS_RUN__
.word __VECTORS_SIZE__
.byte 0 ; PRG
; block 4
.byte $04
; FDS vectors
.segment "VECTORS"
.proc allvectors
.incbin FILE, $400A, 2 ; NMI #1
.incbin FILE, $400A, 2 ; NMI #2
.addr bypass ; NMI #3, default used for license screen skip
.incbin FILE, $400C, 2 ; Reset
.incbin FILE, $400E, 2 ; IRQ
.endproc

.segment "CHR_HDR"
; block 3
.import __CHR_SIZE__
.import __CHR_RUN__
.byte $03
.byte 2,2
.byte "CHR-DATA"
.word __CHR_RUN__
.word __CHR_SIZE__
.byte 1 ; CHR
; block 4
.byte $04
.segment "CHR"
.incbin "obj/nes/bggfx.chr"
.incbin "obj/nes/spritegfx.chr"

; License screen bypass stub
.segment "BYP_HDR"
; block 3
.import __BYPASS_SIZE__
.import __BYPASS_RUN__
.byte $03
.byte 3,3
.byte "-BYPASS-"
.word __BYPASS_RUN__
.word __BYPASS_SIZE__
.byte 0 ; PRG
; block 4
.byte $04
.segment "BYPASS"
.proc bypass
  lda #$00 ; disable NMIs since we don't need them anymore
  sta PPUCTRL
  lda allvectors ; put real NMI handler in NMI vector 3
  sta $DFFA
  lda allvectors+1
  sta $DFFB
  lda #$35 ; tell the FDS that the BIOS "did its job"
  sta $0102
  lda #$ac
  sta $0103
  jmp ($FFFC) ; jump to reset FDS
.endproc

; This block is the last to load, and enables NMI by "loading" the NMI enable value
; directly into the PPU control register at PPU_CTRL.
; While the disk loader continues searching for one more boot file,
; eventually an NMI fires, allowing us to take control of the CPU before the
; license screen is displayed.
.segment "CHK_HDR"
; block 3
.import __CHK_SIZE__
.import __CHK_RUN__
.byte $03
.byte 4,4
.byte "-BYPASS-"
.word __CHK_RUN__
.word __CHK_SIZE__
.byte 0 ; PRG
; block 4
.byte $04
.segment "CHK"
.byte $80 ; enable NMI byte sent to PPU_CTRL

