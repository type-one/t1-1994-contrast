;*	NSND.ASM
;*
;* No Sound Sound Device, v1.10
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
INCLUDE "mmem.inc"
INCLUDE "mglobals.inc"



;/***************************************************************************\
;*	 enum nsndFunctIDs
;*	 ----------------
;* Description:  ID numbers for No Sound Sound Device functions
;\***************************************************************************/

enum	nsndFunctIDs \
	ID_nsndDetect = ID_nsnd, \
	ID_nsndInit, \
	ID_nsndClose, \
	ID_nsndGetMixRate, \
	ID_nsndGetMode, \
	ID_nsndOpenChans, \
	ID_nsndCloseChans, \
	ID_nsndClearChans, \
	ID_nsndMute, \
	ID_nsndPause, \
	ID_nsndSetMaster, \
	ID_nsndPlaySound, \
	ID_nsndStopSound, \
	ID_nsndSetRate, \
	ID_nsndGetRate, \
	ID_nsndSetVol, \
	ID_nsndSetInst, \
	ID_nsndSetPos, \
	ID_nsndGetPos, \
	ID_nsndSetPanning, \
	ID_nsndGetPanning, \
	ID_nsndMuteChannel, \
	ID_nsndAddInst, \
	ID_nsndRemInst, \
	ID_nsndSetUpdRate, \
	ID_nsndPlay


DATASEG

STRUC	nsndInstrument
	length		dw	?		; length in bytes
	loopStart	dw	?		; Offset from beg.
	loopEnd 	dw	?		; Offset from beg.
	volume		dw	?		; Range 0-64
	flags		dw	?		; See below
ENDS

; Flag bits:
; 0 = Used
; 1 = Looped


; STATUS BITS:
; 0 = stop voice
; 1 = retrig note
; 2 = set volume
; 3 = set fc
; 4 = sample changed
; 8 = muted


STRUC	nsndChannel
	status		db	?		; See above
	inst		db	?		; Number
	frequency	dd	?		; In Hz
	volume		dw	?		; 0-64
	looped		db	?		; 0 / 8
	scurrent	dd	?		; Current position
	sstart		dd	?		; Sample start
	send		dd	?		; Sample end
	panning 	dw	?		; Panning position (see enum)
ENDS


chancount	dw	?			; Amount of channels
mixfreq 	dw	?			; Mixing frequency
updRate 	dw	?			; SD update rate

instpos 	dw	?			; Instrument to be filled next

mastervol	dw	?			; Oletus = maksimi

omode		dw	?			; Output mode
temp		dd	?			; Temp storage for some functions
numinsts	dw	?


label channels nsndChannel
	rept	32
	nsndChannel	 ?
	endm

Instruments	dd	?			; Pointer to instruments


IDATASEG

GLOBAL	LANG NSND : SoundDevice

NSND  SoundDevice     < 1,\			; Called according to tempo
	0,\					; Base I/O port
	0,\					; No IRQ
	0,\					; No DMA
	sdUnInitialized,\			; Status
	sdMono or sdStereo or sd16bit or sdNormalQ,\ ; Modes
	far ptr nsndID,\			; ID string
	far ptr nsndDetect,\
	far ptr nsndInit,\
	far ptr nsndClose,\
	far ptr nsndGetMixRate,\
	far ptr nsndGetMode, \
	far ptr nsndOpenChans,\
	far ptr empty,\ 			; Close Channels
	far ptr empty,\ 			; Clear Channels
	far ptr empty,\ 			; Mute
	far ptr empty,\ 			; Pause
	far ptr nsndSetMaster,\
	far ptr nsndPlaySound,\
	far ptr nsndStopSound,\
	far ptr nsndSetRate,\
	far ptr nsndGetRate,\
	far ptr nsndSetVol,\
	far ptr nsndSetInst,\
	far ptr nsndSetPos,\
	far ptr nsndGetPos,\
	far ptr nsndSetPanning,\
	far ptr nsndGetPanning,\
	far ptr nsndMuteChannel,\
	far ptr nsndAddInst,\
	far ptr nsndRemInst,\
	far ptr nsndSetUpdRate,\
	far ptr nsndPlay >


nsndID	 db	 "No Sound Sound Device v1.10",0



CODESEG


;/***************************************************************************\
;*
;* Function:	int nsndDetect(int *result)
;*
;* Description: Detects "No Sound"
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	nsndDetect FAR result : far ptr

	les	bx,[result]
	mov	[word es:bx],1
	xor	ax,ax
	ret

ENDP

;/***************************************************************************\
;*
;* Function:	int nsndInit(ushort rate, ushort mode)
;*
;* Description: Initializes NSND for playing
;*
;* Input:	ushort rate		Mixing rate
;*		ushort mode		Mode
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	nsndInit FAR	 rate : word, mode : word
USES	di

	mov	ax,[mode]
	mov	[omode],ax

	mov	ax,[rate]
	mov	[mixfreq],ax

	mov	[instpos],1			; First instrument to be filled
	mov	[mastervol],64			; Default master volume

	call	memAlloc LANG, MAXINSTS * SIZE nsndInstrument, seg temp offset temp
						; Alloc room for instruments
	test	ax,ax
	jnz	@@err

	mov	ebx,[temp]
	mov	[Instruments],ebx

	les	di,[temp]
	xor	eax,eax
	mov	cx,MAXINSTS * SIZE nsndInstrument
	cld
	rep	stosb				; Clear instrument datas

	mov	[NSND.status],sdOK		; SD initialized
	xor	ax,ax
	ret

@@err:	ERROR	ID_nsndInit
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	int nsndClose()
;*
;* Description: Closes up the GUS.
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	nsndClose FAR

	call	memFree LANG, [Instruments]	; Free instruments
	test	ax,ax
	jnz	@@err

	mov	[instpos],1			; Flush instruments
	mov	[NSND.status],sdUnInitialized
	xor	ax,ax
	ret

@@err:	ERROR	ID_nsndClose
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int nsndGetMixRate(ushort *rate)
;*
;* Description: Returns the mixing rate of the SD
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	nsndGetMixRate FAR	rate : far ptr

	mov	ax,[mixfreq]			; Get mixing rate
	les	bx,[rate]
	mov	[es:bx],ax
	xor	ax,ax
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	int nsndGetMode(ushort *mode)
;*
;* Description: Returns the output mode
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	nsndGetMode	 FAR	mode : far ptr

	mov	ax,[omode]
	les	bx,[mode]
	mov	[es:bx],ax
	xor	ax,ax
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int nsndOpenChans(ushort numChans)
;*
;* Description: Opens channels from the NSND
;*
;* Input:	short NumChans		Amount of channels to open
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	nsndOpenChans	 FAR	 chans:word
USES	si,di

	cld

	mov	bx,[chans]
	mov	[chancount],bx

	mov	ax,ds
	mov	es,ax
	mov	di,offset channels

	xor	al,al
	mov	cx,size nsndChannel*32
	rep	stosb				; Clear channel blocks

	mov	cx,[chans]			; to the table
	xor	bx,bx				; Start from channel 0

@@panloop:
	mov	[bx+channels.panning],panMiddle ; Panning position
	add	bx,SIZE nsndChannel
	loop	@@panloop

	xor	ax,ax
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int nsndSetMaster(uchar master)
;*
;* Description: Sets the master volume for the NSND
;*
;* Input:	uchar master		New master volume (0-64)
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	nsndSetMaster	 FAR	 master:word

	mov	ax,[master]
	cmp	ax,64
	jbe	@@od
	mov	ax,64
@@od:	cmp	[mastervol],ax
	je	@@poiss
	mov	[mastervol],ax
@@poiss:
	xor	ax,ax
	ret
ENDP

;/***************************************************************************\
;*
;* Function:	int nsndPlaySound(ushort chan, ulong freq)
;*
;* Description: Starts a sound with a frequency
;*
;* Input:	ushort chan		Channel number
;*		ulong freq		Playing frequency
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	nsndPlaySound	 FAR	 chan:word, freq:dword
USES	si

	mov	bx,[chan]
	cmp	[chancount],bx
	jle	@@errchn

	imul	bx,bx,size nsndChannel		; Get channel block

	mov	eax,[freq]			; Frequency 0?
	test	eax,eax
	jz	@@quit

	mov	[bx+channels.frequency],eax
	or	[bx+channels.status],8		; FC changed

	movzx	dx,[bx+channels.inst]		; Instrument number
	test	dx,dx
	jz	@@errinst			; No instrument?
	cmp	dx,[numinsts]
	ja	@@errinst
	dec	dx				; Table starts from 1
	imul	dx,dx,SIZE nsndInstrument

	les	si,[Instruments]
	add	si,dx

	mov	[bx+channels.scurrent],0	; Retrig
	and	[bx+channels.status],NOT 17	; AND stop sound and sample changed off
	or	[bx+channels.status],2		; Retrig

@@quit: xor	ax,ax
	ret

@@errchn:
	mov	ax,errInvalidChanNumber
	jmp	@@err
@@errinst:
	mov	ax,errInvalidInstHandle
@@err:	ERROR	ID_nsndPlaySound
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int nsndStopSound(ushort chan)
;*
;* Description: Stops sound on a channel
;*
;* Input:	ushort chan		Channel number
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	nsndStopSound	 FAR	 chan:word

	mov	bx,[chan]
	cmp	[chancount],bx
	jle	@@err

	imul	bx,bx,size nsndChannel		 ; Channel block

	and	[bx+channels.status], NOT 18	; AND Retrig and sample change off
	or	[bx+channels.status],1		; Stop sound

	xor	ax,ax
	ret

@@err:	mov	ax,errInvalidChanNumber
	ERROR	ID_nsndStopSound
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int nsndSetRate(ushort chan, ulong freq)
;*
;* Description: Sets the playing rate for a channel
;*
;* Input:	ushort chan		Channel number
;*		ulong  freq		New playing frequency
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	nsndSetRate	 FAR	 chan:word, freq:dword

	mov	bx,[chan]
	cmp	[chancount],bx
	jle	@@err

	imul	bx,bx,size nsndChannel

	mov	eax,[freq]
	mov	[bx+channels.frequency],eax
	or	[bx+channels.status],8
	xor	ax,ax
	ret

@@err:	mov	ax,errInvalidChanNumber
	ERROR	ID_nsndSetRate
	ret

ENDP


;/***************************************************************************\
;*
;* Function:	int nsndGetRate(ushort chan, ulong *rate)
;*
;* Description: Returns the playing rate for a channel
;*
;* Input:	ushort chan		Channel number
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	nsndGetRate	 FAR	 chan : word, rate : far ptr

	mov	bx,[chan]
	cmp	[chancount],bx
	jle	@@err

	mov	bx,[chan]
	imul	bx,bx,size nsndChannel

	test	[bx+channels.status],40h
	jnz	@@stopped

	mov	eax,[bx+channels.frequency]
	les	bx,[rate]
	mov	[es:bx],eax
	xor	ax,ax
	ret

@@stopped:
	les	bx,[rate]
	mov	[dword es:bx],0
	xor	ax,ax
	ret

@@err:	mov	ax,errInvalidChanNumber
	ERROR	ID_nsndGetRate
	ret

ENDP



;/***************************************************************************\
;*
;* Function:	int nsndSetVol(ushort chan, uchar volume)
;*
;* Description: Sets the volume for a channel
;*
;* Input:	ushort chan		Channel number
;*		uchar  volume		New playing volume
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	nsndSetVol	 FAR	 chan:word, vol:word

	mov	ax,[vol]
	cmp	ax,64
	jbe	@@not64 			; Max volume = 64
	mov	ax,64
@@not64:
	mov	bx,[chan]
	cmp	[chancount],bx
	jle	@@err

	imul	bx,bx,size nsndChannel

	mov	[bx+channels.volume],ax
	or	[bx+channels.status],4
	xor	ax,ax
	ret

@@err:	mov	ax,errInvalidChanNumber
	ERROR	ID_nsndSetVol
	ret

ENDP

;/***************************************************************************\
;*
;* Function:	int nsndSetInst(ushort chan, ushort inst)
;*
;* Description: Sets up an instrument for playing
;*
;* Input:	ushort chan		Channel number
;*		ushort inst		Instrument number from AddInstrument
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	nsndSetInst	 FAR	 chan:word, inst:word
USES	edi, si

	mov	bx,[chan]
	cmp	[chancount],bx
	jle	@@errchn
	imul	bx,bx,size nsndChannel		 ; Channel block

	mov	ax,[inst]
	test	ax,ax
	jz	@@errinst			; No instrument at all?
	cmp	ax,[numinsts]
	ja	@@errinst

	mov	dx,ax
	dec	dx				; Table starts from 1
	imul	dx,dx,SIZE nsndInstrument
	les	si,[Instruments]
	add	si,dx

	cmp	[bx+channels.inst],al
	je	@@nochange

	mov	[bx+channels.inst],al		; Set instrument

	mov	[bx+channels.scurrent],0	; Tell start position to GUS

	test	[es:si+nsndInstrument.flags],2 ; Is sample looped?
	jz	@@noloop

	movzx	edi,[es:si+nsndInstrument.loopEnd]
	movzx	ecx,[es:si+nsndInstrument.loopStart]
	mov	al,8				; Enable loop
	jmp	@@duu

@@noloop:
	movzx	eax,[es:si+nsndInstrument.length]
	xor	edi,edi
	add	edi,eax 			; Sample end address
	xor	al,al				; No loop
@@duu:
	mov	[bx+channels.looped],al 	; Put loop flag
	mov	[bx+channels.sstart],ecx	; Tell loop start to GUS
	mov	[bx+channels.send],edi		; And loop end
	or	[bx+channels.status],16 	; Sample changed

@@nochange:
	cmp	[es:si+nsndInstrument.length],0
	je	@@stop				; If length 0, stop sound

	mov	ax,[es:si+nsndInstrument.volume] ; Set volume

	mov	[bx+channels.volume],ax
	or	[bx+channels.status],4
	xor	ax,ax
	ret

@@stop: call	nsndStopSound LANG, [chan]
	ret

@@errchn:
	mov	ax,errInvalidChanNumber
	jmp	@@err
@@errinst:
	mov	ax,errInvalidInstHandle
@@err:	ERROR	ID_nsndSetInst
	ret

ENDP

;/***************************************************************************\
;*
;* Function:	int nsndSetPos(ushort chan, ushort pos)
;*
;* Description: Sets the playing position for a channel
;*
;* Input:	ushort chan		Channel number
;*		ushort pos		New playing position
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	nsndSetPos	 FAR	 chan:word, pos:word
USES	si

	mov	bx,[chan]
	cmp	[chancount],bx
	jle	@@err
	imul	bx,bx,size nsndChannel		 ; Channel block

	movzx	dx,[bx+channels.inst]
	test	dx,dx
	jz	@@quit				; No instrument?

	dec	dx				; Table starts from 1
	imul	dx,dx,SIZE nsndInstrument
	les	si,[Instruments]
	add	si,dx

	movzx	ecx,[pos]
	cmp	[es:si+nsndInstrument.length],cx ; Over from end?
	jae	@@ok

	movzx	ecx,[es:si+nsndInstrument.loopStart] ; Yep. Start from loop
	test	[es:si+nsndInstrument.flags],2
	jnz	@@ok

	call	nsndStopSound LANG, [chan]
	ret

@@ok:	mov	[bx+channels.scurrent],ecx	; Set start position
	and	[bx+channels.status],NOT 17	; AND stop sound and sample changed off
	or	[bx+channels.status],2		; Retrig

@@quit:
	xor	ax,ax
	ret

@@err:	mov	ax,errInvalidChanNumber
	ERROR	ID_nsndSetPos
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int nsndGetPos(ushort chan, ushort *pos)
;*
;* Description: Gets the playing position of a channel
;*
;* Input:	ushort chan		Channel number
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	nsndGetPos	 FAR	 chan:word, pos : far ptr
USES	si

	mov	bx,[chan]
	cmp	[chancount],bx
	jle	@@err

	imul	bx,bx,size nsndChannel		 ; Channel block

	test	[bx+channels.status],40h
	jnz	@@stopped

	mov	ax,[word bx+channels.scurrent]
	test	ax,ax
	jnz	@@oke
	inc	ax
@@oke:
	les	bx,[pos]
	mov	[es:bx],ax
	xor	ax,ax
	ret

@@stopped:					; No sound is being played
	les	bx,[pos]
	mov	[word es:bx],0
	xor	ax,ax
	ret

@@err:	mov	ax,errInvalidChanNumber
	ERROR	ID_nsndGetPos
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int nsndSetPanning(ushort chan, short panning)
;*
;* Description: Sets the panning position for a channel
;*
;* Input:	ushort channel		Channel number
;*		short panning		Panning info (See enum)
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	nsndSetPanning	 FAR	 chan:word, panning:word

	mov	bx,[chan]
	cmp	[chancount],bx
	jle	@@err

	imul	bx,bx,size nsndChannel		 ; Channel block

	mov	ax,[panning]
	mov	[bx+channels.panning],ax	; Panning position

	xor	ax,ax
	ret

@@err:	mov	ax,errInvalidChanNumber
	ERROR	ID_nsndSetPanning
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	int nsndGetPanning(ushort chan, short *pan)
;*
;* Description: Gets the panning position for a channel
;*
;* Input:	ushort channel		Channel number
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	nsndGetPanning	 FAR	 channel : word, pan : far ptr

	mov	bx,[channel]
	cmp	[chancount],bx
	jle	@@err

	imul	bx,bx,size nsndChannel		 ; Channel block
	mov	ax,[bx+channels.panning]	; Panning position
	les	bx,[pan]
	mov	[es:bx],ax
	xor	ax,ax
	ret

@@err:	mov	ax,errInvalidChanNumber
	ERROR	ID_nsndGetPanning
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	int nsndMuteChannel(ushort chan, ushort mute)
;*
;* Description: Mutes or unmutes a channel
;*
;* Input:	ushort chan		Channel number
;*		ushort mute		UnMute = 0 / Mute = 1
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	nsndMuteChannel  FAR	 chan:word, mute:word

	mov	bx,[chan]
	cmp	[chancount],bx
	jle	@@err
	imul	bx,bx,SIZE nsndChannel

	mov	ax,[mute]
	cmp	ax,1
	je	@@mute
	and	[bx+channels.status],07fh
	jmp	@@pois
@@mute:
	or     [bx+channels.status],80h

@@pois: xor	ax,ax
	ret

@@err:	mov	ax,errInvalidChanNumber
	ERROR	ID_nsndMuteChannel
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	int nsndAddInst(uchar *sample, ushort type, ushort length,
;*				ushort loopStart, ushort loopEnd, uchar volume,
;*				ushort loop, ushort *sdNum)
;*
;* Description: Adds an instrument to the NSND SD internal tables for
;*		use
;*
;* Input:	far ptr sample		pointer to sample
;*		ushort smpType		sample type
;*		ushort length		sample length
;*		ushort loopStart	loop start offset
;*		ushort loopEnd		loop end offset
;*		ushort volume		sample default volume
;*		ushort loop		sample loop flag
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	nsndAddInst	 FAR	 inst:far ptr, stype:word, length:word, loopStart:word,\
				loopEnd:word, volume:word, loop:word, sdNum: far ptr
USES	si,di

	cmp	[stype],smp8bit
	jne	@@invainst

	mov	ax,[instpos]
	dec	ax				; Table starts from 1
	imul	ax,ax,SIZE nsndInstrument
	les	di,[Instruments]
	add	di,ax

	mov	ax,[length]
	mov	[es:di+nsndInstrument.length],ax ; Sample length

	mov	ax,[loopStart]
	mov	[es:di+nsndInstrument.loopStart],ax ; Loop start offset

	mov	ax,[loopEnd]
	mov	[es:di+nsndInstrument.loopEnd],ax  ; Loop end offset

	mov	ax,[volume]
	cmp	ax,64
	jbe	@@oke
	mov	ax,64
@@oke:	mov	[es:di+nsndInstrument.volume],ax ; Default volume

	mov	ax,[loop]			; Loop flag
	and	ax,1
	add	ax,ax
	or	ax,1				; Used flag
	mov	[es:di+nsndInstrument.flags],ax

@@qwit: push	[instpos]			; Return instrument number

	mov	ax,[instpos]
	mov	bx,ax
	dec	bx
	imul	bx,bx,SIZE nsndInstrument
	les	si,[Instruments]
	add	si,bx
@@search:					; Search next free instrument
	test	[es:si+nsndInstrument.flags],1
	jz	@@found
	add	si,SIZE nsndInstrument
	inc	ax
	jmp	@@search

@@found:
	mov	[instpos],ax
	pop	ax
	les	bx,[sdNum]
	mov	[es:bx],ax
	cmp	ax,[numinsts]
	jbe	@@noo
	mov	[numinsts],ax
@@noo:	xor	ax,ax
	ret

@@invainst:
	mov	ax,errInvalidInst
	ERROR	ID_nsndAddInst
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	int nsndRemInst(ushort inst)
;*
;* Description: Removes an instrument from the NSND SD internal tables
;*
;* Input:	ushort	inst		Instrument number from AddInstrument
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	nsndRemInst	 FAR	 inst:word
USES	si

	mov	bx,[inst]
	dec	bx
	imul	bx,bx,SIZE nsndInstrument
	les	si,[Instruments]

	test	[es:si+nsndInstrument.flags],1
	jz	@@nothing

	mov	[es:si+nsndInstrument.flags],0	 ; Free instrument

	mov	ax,[inst]
	cmp	[instpos],ax
	jl	@@nothing

	mov	[instpos],ax			; Lowest instrument number
@@nothing:
	xor	ax,ax
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	int nsndSetUpdRate(ushort rate)
;*
;* Description: Sets the update rate of SD.
;*
;* Input:	ushort	rate			Rate in Hz*100
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	nsndSetUpdRate	 FAR	 rate:word

	mov	ax,[rate]
	mov	[updRate],ax
	xor	ax,ax
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int nsndPlay(ushort *callMP)
;*
;* Description: Updates the NSND "registers" according to the Sound Device
;*		internal datas
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	nsndPlay FAR	callMP : far ptr
LOCAL	chanc:word

USES	si

	mov	[chanc],0			; Start from channel 0
	mov	si,offset channels		; Channel data
@@loop:
	test	[si+nsndChannel.status],40h
	jnz	@@skip

	mov	eax,[si+nsndChannel.frequency]
	imul	eax,eax,100
	xor	edx,edx
	movzx	ebx,[updRate]
	idiv	ebx

	mov	ebx,[si+nsndChannel.scurrent]
	add	ebx,eax

	mov	ecx,[si+nsndChannel.send]

@@retry:
	cmp	ebx,ecx
	jle	@@okay

	test	[si+nsndChannel.looped],8
	jnz	@@looped

	or	[si+nsndChannel.status],40h
	xor	ebx,ebx
	jmp	@@okay

@@looped:
	mov	eax,[si+nsndChannel.send]
	sub	eax,[si+nsndChannel.sstart]
	sub	ebx,eax
	jmp	@@retry

@@okay: mov	[si+nsndChannel.scurrent],ebx

@@skip: test	[si+nsndChannel.status],3	; Retrig / stop sound?
	jz	@@nothing

	and	[si+nsndChannel.status],NOT 1	; And stop sound off

	test	[si+nsndChannel.status],2
	jnz	@@retrig

	or	[si+nsndChannel.status],40h	; Stopped
	jmp	@@nothing

@@retrig:
	and	[si+nsndChannel.status],NOT 43h
@@nothing:
	and	[si+nsndChannel.status],NOT 12

	add	si,size nsndChannel		 ; Do all channels in order
	inc	[chanc]
	mov	ax,[chancount]
	cmp	[chanc],ax
	jb	@@loop

	les	bx,[callMP]
	mov	[word es:bx],1
	xor	ax,ax
	ret
ENDP

PROC	empty	FAR
	xor	ax,ax
	ret
ENDP
END

