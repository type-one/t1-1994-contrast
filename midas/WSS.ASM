;*	WSS.ASM
;*
;* Windows Sound System Sound Device, v1.10
;*
;* Copyright 1994 Petteri Kangaslampi and Jarno Paananen
;*
;* This file is part of the MIDAS Sound System, and may only be
;* used, modified and distributed under the terms of the MIDAS
;* Sound System license, LICENSE.TXT. By continuing to use,
;* modify or distribute this file you indicate that you have
;* read the license and understand and accept it fully.
;*



IDEAL
P386
JUMPS

INCLUDE "lang.inc"
INCLUDE "errors.inc"
INCLUDE "sdevice.inc"
INCLUDE "dsm.inc"
INCLUDE "dma.inc"


;/***************************************************************************\
;*       enum wssFunctIDs
;*       ----------------
;* Description:  ID numbers for WSS Sound Device functions
;\***************************************************************************/

enum    wssFunctIDs \
        ID_wssDetect = ID_wss, \
        ID_wssInit, \
        ID_wssClose



DATASEG

wssSpd		DB	?		; WSS speed value
wssRate 	DW	?		; WSS actual playing rate
wssOLMute	DB	?		; WSS old left channel mute value
wssORMute	DB	?		; WSS old right channel mute value




IDATASEG


GLOBAL	WSS : SoundDevice

WSS		SoundDevice	< \
	0, 530h, 09h, 03h, sdUnInitialized, \
	sdMono or sdStereo or sd8bit or sd16bit or sdNormalQ, \
	far ptr wssID, \
	far ptr wssDetect, \
	far ptr wssInit, \
	far ptr wssClose, \
	far ptr dsmGetMixRate, \
	far ptr dsmGetMode, \
	far ptr dsmOpenChannels, \
	far ptr dsmCloseChannels, \
	far ptr dsmClearChannels, \
	far ptr dsmMute, \
	far ptr dsmPause, \
	far ptr dsmSetMasterVolume, \
	far ptr dsmPlaySound, \
	far ptr dsmStopSound, \
	far ptr dsmSetRate, \
	far ptr dsmGetRate, \
	far ptr dsmSetVolume, \
	far ptr dsmSetInstrument, \
	far ptr dsmSetPosition, \
	far ptr dsmGetPosition, \
	far ptr dsmSetPanning, \
	far ptr dsmGetPanning, \
	far ptr dsmMuteChannel, \
	far ptr dsmAddInstrument, \
	far ptr dsmRemInstrument, \
	far ptr dsmSetUpdRate, \
	far ptr dsmPlay >


LABEL	wssRates	WORD		; sampling rates for WSS
	DW	 8000, 00h
	DW	 5513, 01h
	DW	16000, 02h
	DW	11025, 03h
	DW	27429, 04h
	DW	18900, 05h
	DW	32000, 06h
	DW	22050, 07h
	DW	    0, 08h		; not supported
	DW	37800, 09h
	DW	    0, 0Ah
	DW	44100, 0Bh
	DW	48000, 0Ch
	DW	33075, 0Dh
	DW	 9600, 0Eh
	DW	 6615, 0Fh

wssID   db      "Windows Sound System Sound Device v1.10",0

CODESEG



PUBLIC	wssDetect
PUBLIC	wssInit
PUBLIC	wssClose



;/***************************************************************************\
;*
;* Function:	NOLANGUAGE
;*
;* Description: Waits until the WSS CODEC finishes initializing
;*
;* Returns:	carry set if error, otherwise carry clear
;*
;* Destroys:	ax, cx, dx
;*
;\***************************************************************************/

PROC NOLANGUAGE WaitCODEC	NEAR	; waits until CODEC finishes
					;  initializing. Carry set if error
	clc

	mov	dx,[WSS.port]		; dx = CODEC Index Address Register
	add	dx,4

	mov	cx,2000h

@@wait: in	al,dx
	or	al,al			; wait until bit 7 is zero or 2000h
	jns	@@ok			; reads
	loop	@@wait

	stc				; if read 2000h times, there is a
					; problem with the CODEC
@@ok:	ret

ENDP




;/***************************************************************************\
;*
;* Function:    int wssDetect(int *result);
;*
;* Description: Detects Windows Sound System soundcard
;*
;* Returns:     MIDAS error code.
;*              1 stored to *result if WSS was detected, 0 if not.
;*
;\***************************************************************************/

PROC    wssDetect       FAR     result : dword

        les     bx,[result]             ; store 0 in *result - no detection
        mov     [word es:bx],0

        xor     ax,ax
	ret
ENDP




;/***************************************************************************\
;*
;* Function:    int wssInit(ushort mixRate, ushort mode);
;*
;* Description: Initializes Windows Sound System
;*
;* Input:	mixRate 	mixing rate
;*		mode		output mode (see enum sdMode)
;*
;* Returns:     MIDAS error code
;*
;\***************************************************************************/

PROC	wssInit 	FAR	mixRate : word, mode : word
USES	si,di
LOCAL	wssMode : word

	mov	[wssMode],0

	test	[mode],sd8bit		; force 8-bit?
	jnz	@@8b
	or	[wssMode],sd16bit	; if not, use 16 bits
	jmp	@@bit
@@8b:	or	[wssMode],sd8bit

@@bit:	test	[mode],sdMono		; force mono?
	jnz	@@mono
	or	[wssMode],sdStereo	; if not, use stereo
	jmp	@@mst
@@mono: or	[wssMode],sdMono

@@mst:	test	[mode],sdLowQ		; force low or high quality?
	jnz	@@lowq
	test	[mode],sdHighQ
	jnz	@@highq
	or	[wssMode],sdNormalQ	; if not, use normal quality
	jmp	@@mode
@@lowq: or	[wssMode],sdLowQ
	jmp	@@mode
@@highq:
	or	[wssMode],sdHighQ

@@mode: ; wssMode set up OK

	mov	dx,[WSS.port]
	add	dx,4			; dx = CODEC Index Address Register
	in	al,dx			; is the CODEC busy?
	or	al,al
        jns     @@notbusy

        mov     ax,errSDFailure         ; CODEC busy - failure
        jmp     @@err

@@notbusy:
	mov	al,0Ch			; select misc. register
	out	dx,al
	inc	dx
	in	al,dx			; AL = CODEC version

	mov	bl,al

	xor	al,al
	out	dx,al			; write 0 to misc. register
	in	al,dx			; and read it back
	cmp	al,bl			; if value changed this is not a
        je      @@codecok               ; CODEC

        mov     ax,errSDFailure         ; value changed - not a CODEC
        jmp     @@err

@@codecok:
	mov	bl,[WSS.IRQ]
	cmp	bl,7
	je	@@IRQ7
	cmp	bl,9
	je	@@IRQ9
	cmp	bl,10
	je	@@IRQ10
	cmp	bl,11
	je	@@IRQ11

        mov     ax,errSDFailure         ; invalid IRQ number
        jmp     @@err

@@IRQ7: mov	al,08h			; IRQ value for CODEC configuration
	jmp	@@IRQd

@@IRQ9: mov	al,10h			; IRQ value for CODEC configuration
	jmp	@@IRQd

@@IRQ10:
	mov	al,18h			; IRQ value for CODEC configuration
	jmp	@@IRQd

@@IRQ11:
	mov	al,20h			; IRQ value for CODEC configuration


@@IRQd:
	mov	bl,[WSS.DMA]
	cmp	bl,0
	je	@@DMA0
	cmp	bl,1
	je	@@DMA1
	cmp	bl,3
	je	@@DMA3

        mov     ax,errSDFailure         ; invalid DMA number
        jmp     @@err

@@DMA0: or	al,01h			; DMA value for CODEC configuration
	jmp	@@DMAd

@@DMA1: or	al,02h			; DMA value for CODEC configuration
	jmp	@@DMAd

@@DMA3: or	al,03h			; DMA value for CODEC configuration

@@DMAd: mov	dx,[WSS.port]
	out	dx,al			; set IRQ and DMA numbers

	; WSS does _NOT_ seem to use any interrupts if using autoinit
	; DMA, so setting a IRQ-handler is unnecessary.

	; now search for closest match of the mixing rate from the wssRates
	; table

	mov	cx,16			; 16 possible values
	xor	si,si			; pointer to rate table
	mov	dx,32767		; distance from best match
	xor	bx,bx			; rate number for best match

@@rl:	mov	ax,[wssRates+si]	; get a rate from table
	add	si,2
	sub	ax,[mixRate]		; distance from wanted mixing rate
	js	@@1			; if this rate is smaller, ignore
	cmp	ax,dx			; is distance greater than best match?
	jae	@@1			; if is, ignore

	mov	bx,[wssRates+si]	; rate number for this match
	mov	dx,ax			; distance

@@1:	add	si,2			; next rate
	loop	@@rl

	mov	[wssSpd],bl		; store rate number
	shl	bx,2
	mov	ax,[wssRates+bx]	; get actual mixing rate from table
	mov	[wssRate],ax		; store actual mixing rate

        ; initialize DSM:
	call	dsmInit LANG, [wssRate], [wssMode]
        test    ax,ax
        jnz     @@err

        ; start playing the DMA buffer:
        movzx   ax,[WSS.DMA]
	call	dmaPlayBuffer LANG, seg dsmBuffer offset dsmBuffer, \
                ax, 1
        test    ax,ax
        jnz     @@err

	mov	dx,[WSS.port]
	add	dx,4
	mov	al,0Ah
	out	dx,al
	inc	dx
	in	al,dx			; external mute on
	or	al,40h
	out	dx,al

	mov	cx,1200h		; delay to prevent clicks (value from
					;  CODEC.ASM, ExtMute, WSS SDK 1.0)
@@w1:	in	al,84h			; a "safe" I/O port
	loop	@@w1


	mov	si,2

	; For some unknown reason this has to be done twice. Don't ask me
	; why. Apparently something isn't initialized quite as it should
	; be, but this seems to work fine this way.

@@ratelp:
	call	WaitCODEC

	mov	dx,[WSS.port]
	add	dx,4			; enable MCE and select Clock and
	mov	al,48h			; Data Format Register (08h)
	out	dx,al

	inc	dx
	mov	al,[wssSpd]		; Clock Frequency Source & Divide
	test	[wssMode],sd16bit
	jz	@@no16
	or	al,40h			; 16-bit signed linear (0 - 8-bit
					; unsigned linear)
@@no16:
	test	[wssMode],sdStereo	; stereo?
	jz	@@nostereo
	or	al,10h			; if yes, set stereo bit 1

@@nostereo:
	out	dx,al

	call	WaitCODEC

	dec	si			; do it again...
	jnz	@@ratelp

	mov	dx,[WSS.port]
	add	dx,4
	mov	al,49h			; retain MCE
	out	dx,al
	inc	dx
	mov	al,04h or 08h		; single DMA channel, enable
	out	dx,al			; autocalibration

	call	WaitCODEC

	mov	dx,[WSS.port]
	add	dx,4
	mov	al,08h			; disable MCE
	out	dx,al

@@wacal:
	mov	dx,[WSS.port]
	add	dx,4
	mov	al,11
	out	dx,al			; wait until autocalibration is
	inc	dx			; finished
	in	al,dx
	test	al,32
	jnz	@@wacal


	mov	cx,1200h		; delay to prevent clicks (value from
					;  CODEC.ASM, ExtMute, WSS SDK 1.0)
@@w2:	in	al,84h			; a "safe" I/O port
	loop	@@w2

	mov	dx,[WSS.port]
	add	dx,4
	mov	al,0Ah
	out	dx,al
	inc	dx			; external mute off
	in	al,dx
	and	al,NOT 40h
	out	dx,al


	mov	dx,[WSS.port]
	add	dx,6			; acknowledge CODEC interrupt (just
	xor	al,al			;  for safety...)
	out	dx,al


	mov	dx,[WSS.port]
	add	dx,4			; select the lower base count
	mov	al,0Fh
	out	dx,al
	inc	dx
	mov	al,255			; set the low byte of count (DMAC
	out	dx,al			; takes care of wrapping)

	dec	dx
	mov	al,0Eh			; select the upper base count
	out	dx,al
	inc	dx
	mov	al,255			; set the high byte of count
	out	dx,al


	mov	dx,[WSS.port]
	add	dx,4			; write to the Interface Configuration
	mov	al,09h
	out	dx,al

	inc	dx
	mov	al,05h			; use DMA playback
	out	dx,al

	dec	dx
	mov	al,06h
	out	dx,al			; mute off from left channel
	inc	dx
	in	al,dx
	mov	[wssOLMute],al
	and	al,NOT 128
	out	dx,al

	dec	dx
	mov	al,07h
	out	dx,al			; mute off from right channel
	inc	dx
	in	al,dx
	mov	[wssORMute],al
	and	al,NOT 128
	out	dx,al

@@ok:
	mov	[WSS.status],sdOK
        xor     ax,ax                   ; WSS succesfully initialized
        jmp     @@done


@@err:  ERROR   ID_wssInit

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:    int wssClose(void)
;*
;* Description: Uninitializes Windows Sound System
;*
;* Returns:     MIDAS error code
;*
;\***************************************************************************/

PROC	wssClose	FAR

        cmp     [WSS.status],sdOK
        je      @@sok

        mov     ax,errSDFailure
        jmp     @@err

@@sok:
	mov	dx,[WSS.port]
	add	dx,4

	mov	al,06h
	out	dx,al			; old mute setting to left channel
	inc	dx
	mov	al,[wssOLMute]
	out	dx,al

	dec	dx
	mov	al,07h
	out	dx,al			; old mute setting to right channel
	inc	dx
	mov	al,[wssORMute]
	out	dx,al

	dec	dx			; Pin Control Register
	mov	al,0Ah
	out	dx,al
	inc	dx
	xor	al,al			; turn off interrupts
	out	dx,al

	inc	dx
	out	dx,al			; acnowledge outstanding interrupts

	sub	dx,2
	mov	al,09h			; Interface Configuration Register
	out	dx,al
	inc	dx
	xor	al,al			; turn off CODEC's DMA
	out	dx,al

	movzx	ax,[WSS.DMA]
	call	dmaStop LANG, ax	; stop DMA playing
        test    ax,ax
        jnz     @@err

	call	dsmClose LANG		; uninitialize DSM
        test    ax,ax
        jnz     @@err

	mov	[WSS.status],sdUnInitialized

        xor     ax,ax
        jmp     @@done


@@err:  ERROR   ID_wssClose

@@done:
	ret
ENDP



END
