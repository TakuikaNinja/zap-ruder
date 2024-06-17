;
; Zapper reading kernels (NTSC)
; Copyright 2011, 2024 Damian Yerrick
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty provided
; the copyright notice and this notice are preserved in all source
; code copies.  This file is offered as-is, without any warranty.
;
.include "nes.inc"

; $4017.D4: Trigger switch (1: half-pressed; 0: released or fully pressed)
; $4017.D3: Light detector (0: bright)
;
; The three provided kernels work on machines with 113 2/3 CPU cycles
; per scanline.  These include Family Computer, Nintendo Entertainment
; System (NTSC version), PAL-M clones, and 50 Hz Dendy-style clones.
;   NTSC single player (X, Y) kernel
;   NTSC 2-player (Y) kernel
;   NTSC (Yon, Yoff) kernel
;
; Kernels for PAL NES, with its 106 9/16 CPU cycles per scanline,
; are left as an exercise for the reader:
;   PAL single player (X, Y) kernel
;   PAL 2-player (Y) kernel
;   PAL (Yon, Yoff) kernel

.export zapkernel_yonoff_ntsc, zapkernel_yon2p_ntsc, zapkernel_xyon_ntsc

; When nonzero, show a column of light pixels to ensure that the
; line duration and CYCLE_FRACTION are correct for this TV system
DEBUG_SHOW_TIMING = 0

; Fraction of a cycle to wait after each scanline;
; for NTSC this should be 2/3 of 256
CYCLE_FRACTION = 256 * 2 / 3

; the bit in $4017 (and occasionally $4016) that reflects
; whether the Zapper's light sensor is light (0) or dark (1)
P2F_LIGHT_SENSOR = $08

.align 256
;;
; Measures Zapper position by when the light sensor turns on and off.
; @param Y number of scanlines to test
; @return $0000: number of lines that the sensor was dark (Y position);
;   $0001: number of lines light (light intensity); $0002 clobbered
.proc zapkernel_yonoff_ntsc
off_lines = $00
on_lines = $01
cycle_fraction_accum = $02
  lda #0
  sta off_lines
  sta on_lines
  sta cycle_fraction_accum

; Wait for photosensor to turn ON
lineloop_on:
  ; 8
  lda #P2F_LIGHT_SENSOR
  and $4017
  beq hit_on

  ; 72
  jsr waste_12
  jsr waste_12
  jsr waste_12
  jsr waste_12
  jsr waste_12
  jsr waste_12

  ; 11
  lda off_lines
  and #LIGHTGRAY
  ora #BG_ON|OBJ_ON
.if ::DEBUG_SHOW_TIMING
  sta PPUMASK
.else
  nop
  nop
.endif

  ; 12.67
  clc
  lda cycle_fraction_accum
  adc #CYCLE_FRACTION
  sta cycle_fraction_accum
  bcs :+
:

  ; 10
  inc off_lines
  dey
  bne lineloop_on
  .assert >* = >lineloop_on, error, "branch crosses page boundary"
  rts

; Wait for photosensor to turn ON
lineloop_off:
  ; 8
  lda #P2F_LIGHT_SENSOR
  and $4017
  bne hit_off

hit_on:
  ; 72
  jsr waste_12
  jsr waste_12
  jsr waste_12
  jsr waste_12
  jsr waste_12
  jsr waste_12

  ; 11
  lda off_lines
  and #LIGHTGRAY
  ora #BG_ON|OBJ_ON
.if ::DEBUG_SHOW_TIMING
  sta PPUMASK
.else
  nop
  nop
.endif

  ; 12.67
  clc
  lda cycle_fraction_accum
  adc #CYCLE_FRACTION
  sta cycle_fraction_accum
  bcs :+
:

  ; 10
  inc on_lines
  dey
  bne lineloop_off
  .assert >* = >lineloop_off, error, "branch crosses page boundary"

hit_off:
waste_12:
  rts
.endproc

;;
; Measures two Zappers' position by when their light sensors turn on.
; @param Y number of scanlines to test
; @return $0000: number of lines that the sensor in port 1 was dark;
;   $0001: number of lines that the sensor in port 2 was dark;
;   $0002-$0004 clobbered
.proc zapkernel_yon2p_ntsc
off_lines1 = $00
off_lines2 = $01
cycle_fraction_accum = $02
mask_1     = $03
mask_2     = $04
  lda #0
  sta off_lines1
  sta off_lines2
  sta cycle_fraction_accum
  lda #P2F_LIGHT_SENSOR
  sta mask_1
  sta mask_2

lineloop_on:
  ; 20
  lda mask_1
  and $4016
  sta mask_1
  cmp #1
  lda #0
  adc off_lines1
  sta off_lines1

  ; 20
  lda mask_2
  and $4017
  sta mask_2
  cmp #1
  lda #0
  adc off_lines2
  sta off_lines2
  
  ; 44
  jsr waste_12
  jsr waste_12
  jsr waste_12
  nop
  nop
  nop
  nop

  ; 12
.if ::DEBUG_SHOW_TIMING
  tya
  tya
  and #LIGHTGRAY
  ora #BG_ON|OBJ_ON
  sta PPUMASK
.else
  jsr waste_12
.endif

  ; 12.67
  clc
  lda cycle_fraction_accum
  adc #CYCLE_FRACTION
  sta cycle_fraction_accum
  bcs :+
:

  ; 5
  dey
  bne lineloop_on
  .assert >* = >lineloop_on, error, "branch crosses page boundary"

hit_off:
waste_12:
  rts
.endproc

;;
; Read both the horizontal and vertical position of when the
; light sensor of the Zapper in port 2 turns on.
;
; Ideally, the jsr should begin 10 cycles before the start of
; rendering, so place sprite 0 wisely.
;
; Analog properties of the Zapper's light filtering circuit add so
; much noise that the (X, Y) kernel's X position varies randomly
; within a range of at least 5 units (90 pixels).  That makes this
; zapkernel impractical to use except as a cautionary exercise.
; @return X: horizontal position; Y: distance from bottom
.align 256
.proc zapkernel_xyon_ntsc
  ldx #0    ; this zapkernel keeps cycle_fraction_accum in X
  lda #P2F_LIGHT_SENSOR
 
lineloop:
  ; 84
  bit $4017
  beq bail0
  bit $4017
  beq bail1
  bit $4017
  beq bail2
  bit $4017
  beq bail3
  bit $4017
  beq bail4
  bit $4017
  beq bail5
.if ::DEBUG_SHOW_TIMING
  lda #BG_ON|OBJ_ON|TINT_R|TINT_G
  sta PPUMASK
  nop
  nop
  lda #BG_ON|OBJ_ON
  sta PPUMASK
  lda #P2F_LIGHT_SENSOR
.else
  bit $4017
  beq bail6
  bit $4017
  beq bail7
  bit $4017
  beq bail8
.endif
  bit $4017
  beq bail9
  bit $4017
  beq bail10
  bit $4017
  beq bail11
  bit $4017
  beq bail12
  bit $4017
  beq bail13

  ; We can afford more spacing for the last two light sensor checks
  ; because they should occur during horizontal blanking.
  ; 14
  clc
  bit $4017
  beq bail14
  txa
  adc #CYCLE_FRACTION  ; set up carry for use after next check
  tax

  ; 10.67
  lda #P2F_LIGHT_SENSOR
  bit $4017
  beq bail15
  bcs :+
:

  ; 5
  dey
  bne lineloop
  .assert >* = >lineloop, error, "branch crosses page boundary"

bail0:
  ldx #0
  rts
bail1:
  ldx #1
  rts
bail2:
  ldx #2
  rts
bail3:
  ldx #3
  rts
bail4:
  ldx #4
  rts
bail5:
  ldx #5
  rts
bail6:
  ldx #6
  rts
bail7:
  ldx #7
  rts
bail8:
  ldx #8
  rts
bail9:
  ldx #9
  rts
bail10:
  ldx #10
  rts
bail11:
  ldx #11
  rts
bail12:
  ldx #12
  rts
bail13:
  ldx #13
  rts
bail14:
  ldx #14
  rts
bail15:
  ldx #15
  rts
.endproc
