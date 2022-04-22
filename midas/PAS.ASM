;*	PAS.ASM
;*
;* Pro Audio Spectrum Sound Device, v1.10
;*
;* Copyright 1994 Petteri Kangaslampi and Jarno Paananen
;*
;* This file is part of the MIDAS Sound System, and may only be
;* used, modified and distributed under the terms of the MIDAS
;* Sound System license, LICENSE.TXT. By continuing to use,
;* modify or distribute this file you indicate that you have
;* read the license and understand and accept it fully.
;*

;* NOTE! A lot of this code is ripped more or less directly from the PAS
;* SDK and might therefore seem messy.
;* I really do not understand some parts of this code... Perhaps I'll clear
;* it up some day when I have time.
;* (PK)



IDEAL
P386
JUMPS

INCLUDE "pas.inc"
INCLUDE "lang.inc"
INCLUDE "errors.inc"
INCLUDE "sdevice.inc"
INCLUDE "dsm.inc"
INCLUDE "dma.inc"



;/***************************************************************************\
;*       enum pasFunctIDs
;*       ----------------
;* Description:  ID numbers for PAS Sound Device functions
;\***************************************************************************/

enum    pasFunctIDs \
        ID_pasDetect = ID_pas, \
        ID_pasInit, \
        ID_pasClose



DATASEG


pasVersion	DB	?		; card version
pasSpeed	DW	?		; output rate value
pasRate 	DW	?		; actual output rate
pasMode 	DW	?		; output mode




IDATASEG


GLOBAL	PAS : SoundDevice

PAS		SoundDevice	< \
        0, 388h, 15, 5, sdUnInitialized, \
	sdStereo or sdMono or sd16bit or sd8bit or sdNormalQ, \
	far ptr pasID, \
	far ptr pasDetect, \
	far ptr pasInit, \
	far ptr pasClose, \
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


pasID   db      "Pro Audio Spectrum series Sound Device v1.10",0



_mvHWVersionBits	dw	-1	; holds the product feature bits
_mvTranslateCode	dw	0	; I/O base xor default_base

VERSION_PAS		equ	0	; Pro Audio Spectrum
VERSION_PASPLUS 	equ	1	; Pro Audio Plus card
VERSION_PAS16		equ	2	; Pro Audio 16 card
VERSION_CDPC		equ	3	; CDPC card & unit

;
; The following equates build up a mask of bits that we do wish to keep
; when comparing feature bits. The zero bits can be ignored, whereas, the
; the 1 bits must match.
;

PASdocare	equ	<(bMVA508 OR bMVDAC16 OR bMVOPL3 OR bMV101 )>
PASPLUSdocare	equ	<(bMVA508 OR bMVDAC16 OR bMVOPL3 OR bMV101 )>
PAS16docare	equ	<(bMVA508 OR bMVDAC16 OR bMVOPL3 OR bMV101 )>
CDPCdocare	equ	<(bMVA508 OR bMVDAC16 OR bMVOPL3 OR bMV101 )>

;
LABEL	ProductIDTable	WORD
	dw	PRODUCT_PROAUDIO and PASdocare
	dw	PRODUCT_PROPLUS  and PASPLUSdocare
	dw	PRODUCT_PRO16	 and PAS16docare
	dw	PRODUCT_CDPC	 and CDPCdocare
	dw	-1
;
LABEL	DoCareBits	WORD
	dw	PASdocare
	dw	PASPLUSdocare
	dw	PAS16docare
	dw	CDPCdocare
	dw	-1				; table terminator

mvhwShadowPointer	dd	0      ; points to the start of the data table

;
; These variables mirror the hardware state
;
HardwareShadowTable	db	(size MVState) dup (0)

; ---

CODESEG



PUBLIC	pasDetect
PUBLIC	pasInit
PUBLIC	pasClose




PROC	pasSearchHW	FAR
USES	si,di

;
; calculate the translation code
;
	mov	[PAS.port],di

	xor	di,DEFAULT_BASE 	; di holds the translation code

	mov	ax,0BC00H		; make sure MVSOUND.SYS is loaded
	mov	bx,'??'                 ; this is our way of knowing if the
	xor	cx,cx			; hardware is actually present.
	xor	dx,dx
	int	2fh			; get the ID pattern
	xor	bx,cx			; build the result
	xor	bx,dx
	cmp	bx,'MV'                 ; if not here, exit...
	jne	@@bad

;
; get the MVSOUND.SYS specified DMA and IRQ channel
;
	mov	ax,0bc04h		; get the DMA and IRQ numbers
	int	2fh
	mov	[PAS.DMA],bl		; save the correct DMA & IRQ
	mov	[PAS.IRQ],cl

;
; grab the version # in the interrupt mask. The top few bits hold the version #
;
	mov	dx,INTRCTLR		; board ID is in MSB 3 bits
	xor	dx,di			; adjust to other address
	in	al,dx
	cmp	al,-1			; bus float meaning not present?
	je	@@bad			; yes, there is no card here

	mov	ah,al			; save an original copy
	xor	al,fICrevbits		; the top bits wont change

	out	dx,al			; send out the inverted bits
	jmp	$+2
	jmp	$+2
	in	al,dx			; get it back...

	cmp	al,ah			; both should match now...
	xchg	al,ah			; (restore without touching the flags)
	out	dx,al

	jnz	@@bad			; we have a bad board

	and	ax,fICrevbits		; isolate the ID bits & clear AH
	mov	cl,fICrevshr		; shift the bits into a meaningful
	shr	al,cl			; position (least signficant bits)
	mov	si,ax			; save the version #
;
; We do have hardware! Load the product bit definitions
;
	sub	bx,bx
	mov	cx,bMVSCSI		; setup bx:cx for the original PAS

	or	al,al			; is this the first version of h/w?
	jz	@@hwdone		; yes, simple exit will do.


; All second generation Pro Audio cards use the MV101 and have SB emulation.
;
	or	cx,bMVSBEMUL+bMV101	; force SB emulation
;
; determine if the enhanced SCSI interface is present
;
	mov	dx,ENHANCEDSCSI 	; test for SCSI mod (U48)
	xor	dx,di			; modify via the translate code

	out	dx,al			; strobe
	jmp	$+2			; I/O bus delay
	in	al,dx			; get the bit

	and	al,1			; bit0==1 means old SCSI PAL
	cmp	al,1			; reverse sense
	sbb	ax,ax			; ax = ffff if enhanced SCSI
	and	ax,bMVENHSCSI		; save the bit
	or	cx,ax			; merge it in
;
; determine AT/PS2, CDPC slave mode
;
	mov	dx,MASTERMODRD		; check for the CDPC
	xor	dx,di			; modify via the translate code

	in	al,dx
	test	al,bMMRDatps2		; AT(1) or PS2(0)
	jnz	@@1
	or	cx,bMVPS2
    ;
    @@1:
	test	al,bMMRDmsmd		; Master(0) or Slave(1)
	jz	@@2
	or	cx,bMVSLAVE
    ;
    @@2:
	push	cx			; move the revision bits

	mov	dx,MASTERCHIPR
	xor	dx,di

	ERRIF	bMV101_REV-(000Fh SHL 11)

	in	al,dx			; get the low 4 bits of the chip rev
	and	ax,000Fh		; into ah
	mov	cl,11			; FROM 0000 0000 0000 1111b
	shl	ax,cl			; TO   0111 1000 0000 0000b

	pop	cx
	or	cx,ax			; merge in the bits
;
; determine the CDROM drive type, FM chip, 8/16 bit DAC, and mixer
;
	mov	dx,SLAVEMODRD		; check for the CDPC
	xor	dx,di			; modify via the translate code
	in	al,dx

	test	al,bSMRDdactyp		; 16 bit DAC?
	jz	@@3			; no, its an 8 bit DAC
	or	cx,bMVDAC16		; its a 16 bit DAC
    ;
    @@3:
	test	al,bSMRDfmtyp		; OPL3 chip?
	jz	@@4			; no, so it's the PAS16 card
	or	cx,bMVOPL3		; is an OPL3
    ;
    @@4:
	mov	dx,cx			; inference check for new mixer
	and	dx,bMVSLAVE+bMVDAC16	; Slave & 16 bit dac is the CDPC
	cmp	dx,bMVDAC16		; 16 bit DAC on master?
	jnz	@@5			; no, it's the CDPC with Nation mixer
	or	cx,bMVA508
    ;
    @@5:
	and	al,bSMRDdrvtyp		; isolate the CDROM drive type
	cmp	al,2			; Sony 535 interface?
	jnz	@@6			; no, continue on...
	and	cx,NOT (bMVSCSI+bMVENHSCSI) ; yes, flush the SCSI bits
	or	cx,bMVSONY		    ; set the 535 bit
    ;
    @@6:
;
; determine if MPU-401 emulation is active
;
	mov	dx,COMPATREGE		; compatibility register
	xor	dx,di			; modify via translate code
	in	al,dx
	test	al,cpMPUEmulation
	jz	@@7
	or	cx,bMVMPUEMUL
    ;
    @@7:
;
@@hwdone:
;
; loop on a table search to find identify the board
;
	push	bx			; save this high bits
	mov	bx,-2
    ;
    @@lp:
	add	bx,2
	cmp	[ProductIDTable+bx],-1	; at the end of the table?
	jz	@@badhw 		; yes, we can't identify this board
	mov	dx,cx			; dx holds the product bits
	and	dx,[DoCareBits+bx]	; keep the bits we care about
	cmp	dx,[ProductIDTable+bx]	; do these bits match a product?
	jne	@@lp			; no, keep looking

	mov	dx,bx
	shr	dx,1			; make word index a byte index
	pop	bx

	mov	[_mvTranslateCode],di	; save the translation code (ie. port)

	mov	ax,si			; load the h/w version #
	sub	ah,ah			; for our purposes, we will return SCSI
	xchg	ah,al			; into ah
	clc				; The board was identified !

	mov	[_mvHWVersionBits],cx	; save the good bits

	jmp	@@done
;
@@badhw:
	pop	bx			; flush the stack
	mov	ax,-2
	cwd
	stc
	jmp	@@done
;
@@bad:
	mov	ax,-1			; we got here due to a bad board
	cwd
	stc
;
@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:    int pasDetect(int *result);
;*
;* Description: Detects Pro Audio Spectrum soundcard
;*
;* Returns:     MIDAS error code.
;*              1 stored to *result if PAS was detected, 0 if not.
;*
;\***************************************************************************/

PROC    pasDetect       FAR     result : dword

    ; search the default address

	mov	di,DEFAULT_BASE 	; try the first address
	call	pasSearchHW
	cmp	dx,-1			; found?
	jnz	@@found 		; yes, exit now...

    ; search the first alternate address

	mov	di,ALT_BASE_1		; try the first alternate
	call	pasSearchHW
	cmp	dx,-1			; found?
	jnz	@@found 		; yes, exit now...

    ; search the second alternate address

	mov	di,ALT_BASE_2		; try the second alternate
	call	pasSearchHW
	cmp	dx,-1			; found?
	jnz	@@found 		; yes, exit now...

    ; search the third, or user requested alternate address

	mov	di,ALT_BASE_3		; try the third alternate
	call	pasSearchHW		; pass the third A, or user I/O

@@found:
        les     bx,[result]             ; point es:bx to result variable

        or      dx,dx                   ; if dx:ax negative, no card found
        js      @@nopas

	mov	[pasVersion],ah 	; store the PAS version
        mov     [word es:bx],1          ; PAS detected succesfully
        jmp     @@ok

@@nopas:
        mov     [word es:bx],0          ; no PAS found

@@ok:
        xor     ax,ax                   ; success

	ret
ENDP




;/***************************************************************************\
;*
;* Function:    int pasInit(ushort mixRate, ushort mode);
;*
;* Description: Initializes Pro Audio Spectrum
;*
;* Input:	mixRate 	mixing rate
;*		mode		output mode (see enum sdMode)
;*
;* Returns:     MIDAS error code
;*
;\***************************************************************************/

PROC	pasInit 	FAR	mixRate : word, mode : word
USES	si,di

	mov	[pasMode],0

	test	[mode],sd8bit		; force 8-bit?
	jnz	@@8b
	or	[pasMode],sd16bit	; if not, use 16 bits
	jmp	@@bit
@@8b:	or	[pasMode],sd8bit

@@bit:	test	[mode],sdMono		; force mono?
	jnz	@@mono
	or	[pasMode],sdStereo	; if not, use stereo
	jmp	@@mst
@@mono: or	[pasMode],sdMono

@@mst:	test	[mode],sdLowQ		; force low or high quality?
	jnz	@@lowq
	test	[mode],sdHighQ
	jnz	@@highq
	or	[pasMode],sdNormalQ	; if not, use normal quality
	jmp	@@mode
@@lowq: or	[pasMode],sdLowQ
	jmp	@@mode
@@highq:
	or	[pasMode],sdHighQ

@@mode: ; pasMode set up OK


	mov	di,[PAS.port]		; PAS I/O port
	call	pasSearchHW		; search for hardware at this port
	cmp	dx,-1			; hardware found OK?
        jne     @@hwok

        mov     ax,errSDFailure         ; Sound Device hardware failure
        jmp     @@err

@@hwok:
	mov	[pasVersion],ah 	; save PAS version ID

	xor	di,DEFAULT_BASE 	; save port XOR default port
	mov	[_mvTranslateCode],di


	; from PAS SDK...

;
; setup a pointer to our local hardware state table
;
	mov	bx,offset HardwareShadowTable
        mov     ax,seg HardwareShadowTable
        mov     es,ax
	mov	[word mvhwShadowPointer+0],bx
        mov     [word mvhwShadowPointer+2],es

        mov     [es:bx+MVState._audiomixr],31h    ; lowest filter setting
        mov     [es:bx+MVState._crosschannel],09h ; cross channel l-2-l, r-2-r
;
; find the int 2F interface and if found, use it's state table pointer
;
	mov	ax,0BC00h		; MVSOUND.SYS ID check
	mov	bx,'??'
	sub	cx,cx
	sub	dx,dx

	int	2fh			; will return something if loaded

	xor	bx,cx
	xor	bx,dx
	cmp	bx,'MV'                 ; is the int 2F interface here?
	jnz	@@spdone		; no, exit home

	mov	ax,0BC02H		; get the pointer
	int	2fh
	cmp	ax,'MV'                 ; busy or intercepted
	jnz	@@spdone

	mov	[word mvhwShadowPointer+0],bx
	mov	[word mvhwShadowPointer+2],dx
;
@@spdone:

	mov	dx,INTRCTLRST			; flush any pending PCM irq
	xor	dx,[_mvTranslateCode]		; xlate the board address
	out	dx,al


	; calculate sample rate

	les	di,[mvhwShadowPointer]

	mov	eax,1193180
	xor	edx,edx
	movzx	ebx,[mixRate]
	div	ebx
	mov	[es:di+MVState._samplerate],ax	; save output speed
	mov	[pasSpeed],ax

	test	[pasMode],sdStereo
	jz	@@nostereo
	mov	ax,[pasSpeed]
	shr	ax,1			; multiply output rate with 2 if
	mov	[pasSpeed],ax		; stereo
	mov	[es:di+MVState._samplerate],ax

@@nostereo:
	mov	eax,1193180
	xor	edx,edx
	movzx	ebx,[pasSpeed]		; calculate actual output rate
	div	ebx

	test	[pasMode],sdStereo
	jz	@@nostereo2		; divide with 2 if stereo to get
	shr	eax,1			; actual output rate

@@nostereo2:
	mov	[pasRate],ax

	les	di,[mvhwShadowPointer]
	mov	al,00110110b		; 36h Timer 0 & square wave
	mov	dx,TMRCTLR
	xor	dx,[_mvTranslateCode]	; xlate the board address

	cli

	out	dx,al			; setup the mode, etc
	mov	[es:di+MVState._tmrctlr],al

	mov	ax,[es:di+MVState._samplerate]	; pre-calculated & saved in
	mov	dx,SAMPLERATE			; prior code
	xor	dx,[_mvTranslateCode]	; xlate the board address
	out	dx,al			; output the timer value

	jmp	$+2

	xchg	ah,al
	out	dx,al
	sti

	mov	dx,CROSSCHANNEL
	xor	dx,[_mvTranslateCode]

	mov	al,[es:di+MVState._crosschannel]     ; Stop PAS' DMA transfer
	or	al,bCCdrq
	mov	[es:di+MVState._crosschannel],al
	out	dx,al


	call	dsmInit LANG, [pasRate], [pasMode]
        test    ax,ax                   ; error initializing DSM?
        jnz     @@err

	movzx	ax,[PAS.DMA]
	mov	bx,1			; use auto-initialization
	call	dmaPlayBuffer LANG, seg dsmBuffer offset dsmBuffer, \
		ax, bx			; start playing the DMA buffer
        test    ax,ax
        jnz     @@err


	les	di,[mvhwShadowPointer]
	test	[pasMode],sd16bit
	jz	@@no16bit
	mov	cx,(((NOT(bSC216bit+bSC212bit) AND 0FFh)*256) + bSC216bit)
	mov	dx,SYSCONFIG2
	xor	dx,[_mvTranslateCode]	; xlate the board address
	in	al,dx
	and	al,ch			; clear the bits
	or	al,cl			; set the appropriate bits
	out	dx,al
@@no16bit:
	mov	al,bCCmono		; get the stereo/mono mask bit
	test	[pasMode],sdStereo
	jz	@@nostereox
	sub	al,al
@@nostereox:
	or	al,bCCdac		; get the direction bit mask
	or	al,bCCenapcm		; enable the PCM state machine
	mov	dx,CROSSCHANNEL
	xor	dx,[_mvTranslateCode]	; xlate the board address

	mov	ah,0fh + bCCdrq 	; get a mask to load non PCM bits
	and	ah,[es:di+MVState._crosschannel]
					; grab all but PCM/DRQ/MONO/DIRECTION
	or	al,ah			; merge the two states
	xor	al,bCCenapcm		; disable the PCM bit
	out	dx,al			; send to the hardware
	jmp	$+2
	xor	al,bCCenapcm		; enable the PCM bit
	out	dx,al			; send to the hardware
	mov	[es:di+MVState._crosschannel],al  ; and save the new state
;
; Setup the audio filter sample bits
;
	mov	al,[es:di+MVState._audiofilt]
	or	al,(bFIsrate+bFIsbuff)	; enable the sample count/buff counters
	mov	dx,AUDIOFILT
	xor	dx,[_mvTranslateCode]	; xlate the board address
	out	dx,al
	mov	[es:di+MVState._audiofilt],al

	mov	al,[es:di+MVState._crosschannel] ; get the state
	mov	dx,CROSSCHANNEL
	xor	dx,[_mvTranslateCode]	; xlate the board address
	or	al,bCCdrq		; set the DRQ bit to control it
	out	dx,al
	mov	[es:di+MVState._crosschannel],al ; and save the new state

@@ok:
	mov	[PAS.status],sdOK

        xor     ax,ax                   ; success
        jmp     @@done

@@err:
        ERROR   ID_pasInit

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:    int pasClose()
;*
;* Description: Uninitializes Pro Audio Spectrum
;*
;* Returns:     MIDAS error code
;*
;\***************************************************************************/

PROC	pasClose	FAR

	cmp	[PAS.status],sdOK
	jne	@@err

	les	di,[mvhwShadowPointer]
;
; clear the audio filter sample bits
;
	mov	dx,AUDIOFILT
	xor	dx,[_mvTranslateCode]	  ; xlate the board address
	cli			; drop dead...
	mov	al,[es:di+MVState._audiofilt]	 ; get the state
	and	al,not (bFIsrate+bFIsbuff) ; flush the sample timer bits
	mov	[es:di+MVState._audiofilt],al	 ; save the new state
	out	dx,al

	test	[pasMode],sd16bit
	jz	@@no16bit

;
; disable the 16 bit stuff
;
	mov	dx,SYSCONFIG2
	xor	dx,[_mvTranslateCode]	  ; xlate the board address
	in	al,dx
	and	al,not bSC216bit+bSC212bit ; flush the 16 bit stuff
	out	dx,al
;
@@no16bit:

;
; clear the appropriate Interrupt Control Register bit
;
	mov	ah,bICsampbuff
	and	ah,bICsamprate+bICsampbuff
	not	ah
	mov	dx,INTRCTLR
	xor	dx,[_mvTranslateCode]	  ; xlate the board address
	in	al,dx
	and	al,ah			; kill sample timer interrupts
	out	dx,al
	mov	[es:di+MVState._intrctlr],al

	mov	al,[es:di+MVState._crosschannel] ; get the state
	mov	dx,CROSSCHANNEL
	xor	dx,[_mvTranslateCode]	; xlate the board address
	and	al,not bCCdrq		; clear the DRQ bit
	and	al,not bCCenapcm	; clear the PCM enable bit
	or	al,bCCdac
	out	dx,al

	mov	[es:di+MVState._crosschannel],al ; and save the new state

	movzx	ax,[PAS.DMA]
	call	dmaStop LANG, ax	; stop DMA playing
        test    ax,ax
        jnz     @@err

	call	dsmClose LANG		; uninitialize DSM
        test    ax,ax
        jnz     @@err

	mov	[PAS.status],sdUnInitialized

        xor     ax,ax
        jmp     @@done

@@err:
        ERROR   ID_pasClose

@@done:
	ret
ENDP



END
