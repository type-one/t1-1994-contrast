;*	GUS.ASM
;*
;* Gravis Ultrasound Sound Device, v3.35
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
;*	 enum gusFunctIDs
;*	 ----------------
;* Description:  ID numbers for GUS Sound Device functions
;\***************************************************************************/

enum	gusFunctIDs \
	ID_gusDetect = ID_gus, \
	ID_gusInit, \
	ID_gusClose, \
	ID_gusGetMixRate, \
	ID_gusGetMode, \
	ID_gusOpenChans, \
	ID_gusCloseChans, \
	ID_gusClearChans, \
	ID_gusMute, \
	ID_gusPause, \
	ID_gusSetMaster, \
	ID_gusPlaySound, \
	ID_gusStopSound, \
	ID_gusSetRate, \
	ID_gusGetRate, \
	ID_gusSetVol, \
	ID_gusSetInst, \
	ID_gusSetPos, \
	ID_gusGetPos, \
	ID_gusSetPanning, \
	ID_gusGetPanning, \
	ID_gusMuteChannel, \
	ID_gusAddInst, \
	ID_gusRemInst, \
	ID_gusSetUpdRate, \
	ID_gusPlay,\
	ID_gusInitHeap,\
	ID_gusFreeHeap,\
	ID_gusMalloc,\
	ID_gusFree,\
	ID_gusCoreFree,\
	ID_gusAllocBlock


DATASEG

STRUC	gusInstrument
	sample		dd	?		; ptr to sample in GUS mem
	surround	dd	?		; ptr to surround sample in GUS mem / 0
	length		dw	?		; length in bytes
	loopStart	dw	?		; Offset from beg.
	loopEnd 	dw	?		; Offset from beg.
	volume		dw	?		; Range 0-64
	flags		dw	?		; See below
ENDS

; Flag bits:
; 0 = Used
; 2 = Looped


; STATUS BITS:
; 0 = stop voice
; 1 = retrig note
; 2 = set volume
; 3 = set fc
; 4 = sample changed
; 5 = sample on/off (used for pause)
; 8 = muted


STRUC	gusChannel
	status		db	?		; See above
	inst		db	?		; Number
	fc		dw	?		; In FC-format
	frequency	dd	?		; In Hz
	volume		dw	?		; 0-64
	surround	db	?		; Surround flag
	looped		db	?		; 0 / 8 (for GUS)
	scurrent	dd	?		; Current position for GUS
	sstart		dd	?		; Sample start for GUS
	send		dd	?		; Sample end for GUS
	panning 	dw	?		; Panning position (see enum)
ENDS


STRUC	ghb					; GUS Heap Block
	next		dd	?		; Pointer to next block
	gusmem		dd	?		; Pointer to GUS memory
	length		dd	?		; Length of this block (Rounded to 32 byte border)
ENDS

; lengthFlags:
;		0 free / allocated



chancount	dw	?			; Amount of channels
voicesel	dw	?			; Voice Select register
selreg		dw	?			; Select Register

mixfreq 	dw	?			; Mixing frequency
updRate 	dw	?			; SD update rate

instpos 	dw	?			; Instrument to be filled next

muted		dw	?			; 0 = unmuted, 1 = muted
paused		dw	?			; 0 = not, 1 = paused
mastervol	dw	?			; Oletus = maksimi
masterchanged	dw	?			; Overrides channel set volume
numInsts	dw	?			; Max instrument.

memamount	dd	?			; Amount of memory on GUS
memavail	dd	?			; Memory available on GUS
largestblock	dd	?			; Largest block of memory on GUS
gusHeapStart	dd	?			; First block of GUS heap
gusHeap 	DD	?			; pointer to GUS heap
monoFlag	dw	?			; Force mono output
temp		dd	?			; Temporary storage


label channels gusChannel
	rept	32
	gusChannel	?
	endm

Instruments	dd	?			; Pointer to GUS instruments



IDATASEG


GLOBAL	GUS : SoundDevice

IFNDEF	__TP__
PUBLIC	gusHeapStart
ENDIF

GUS SoundDevice       < 1,\			; Called according to tempo
			220h,\			; Default base I/O port
			0,\			; No IRQ
			0,\			; No DMA
			sdUnInitialized,\	; Status
			sdMono or sdStereo or sd16bit or sdHighQ,\ ; Modes
			far ptr gusID,\ 	; ID string
			far ptr gusDetect,\
			far ptr gusInit,\
			far ptr gusClose,\
			far ptr gusGetMixRate,\
			far ptr gusGetMode, \
			far ptr gusOpenChans,\
			far ptr gusCloseChans,\
			far ptr gusClearChans,\
			far ptr gusMute,\
			far ptr gusPause,\
			far ptr gusSetMaster,\
			far ptr gusPlaySound,\
			far ptr gusStopSound,\
			far ptr gusSetRate,\
			far ptr gusGetRate,\
			far ptr gusSetVol,\
			far ptr gusSetInst,\
			far ptr gusSetPos,\
			far ptr gusGetPos,\
			far ptr gusSetPanning,\
			far ptr gusGetPanning,\
			far ptr gusMuteChannel,\
			far ptr gusAddInst,\
			far ptr gusRemInst,\
			far ptr gusSetUpdRate,\
			far ptr gusPlay >


; Mixing frequencies for channel amounts 14-32

chantab dw	44100,41160,38587,36317,34300,32494,30870,29400,28063,26843
	dw	25725,24696,23746,22866,22050,21289,20580,19916,19293



LABEL	voltable	WORD
	dw	01200h
	dw	09300h,0A900h,0B400h,0BC00h,0C180h,0C580h,0C980h,0CD80h
	dw	0CF40h,0D240h,0D440h,0D640h,0D840h,0DA40h,0DC40h,0DE40h
	dw	0DEF0h,0DFA0h,0E1A0h,0E2A0h,0E3A0h,0E4A0h,0E5A0h,0E6A0h
	dw	0E7A0h,0E8A0h,0E9A0h,0EAA0h,0EBA0h,0ECA0h,0EDA0h,0EEA0h
	dw	0EEF0h,0EFE0h,0EF60h,0F1E0h,0F160h,0F1E0h,0F260h,0F2E0h
	dw	0F360h,0F3E0h,0F460h,0F4E0h,0F560h,0F5E0h,0F660h,0F6E0h
	dw	0F760h,0F7E0h,0F860h,0F8E0h,0F960h,0F9E0h,0FA60h,0FAF0h
	dw	0FB70h,0FBF0h,0FC70h,0FCF0h,0FD70h,0FD90h,0FDB0h,0FDD0h

gusID	db	"Gravis Ultrasound Sound Device v3.35",0



CODESEG

;******* GUS Register Select - Macro ************

MACRO	regsel	register
	mov	dx,[selreg]
	mov	al,register
	out	dx,al
ENDM



;/***************************************************************************\
;*
;* Function:	int gusDetect(int *result)
;*
;* Description: Detects Gravis UltraSound and fills in GUS SoundDevice
;*		structure with appropriate values for port, DMA and IRQ
;*
;* Returns:	MIDAS error code.
;*		1 stored to *result if GUS was detected, 0 if not.
;*
;\***************************************************************************/

PROC	gusDetect FAR	result : far ptr
USES	si

	mov	[GUS.port],210h 		; Base address
	les	si,[result]

@@detectloop:
	mov	ax,[GUS.port]			; Base address (Set before!)
	add	ax,103h
	mov	[selreg],ax			; Register select (2x0h+103h)
	dec	ax
	mov	[voicesel],ax			; Voice select (2x0h+102h)

	call	gusReset

	regsel	44h
	add	dx,2
	xor	ax,ax
	out	dx,al				; upper bits of address

	regsel	43h
	inc	dx
	xor	ax,ax				; Address 0
	out	dx,ax
	add	dx,3
	mov	al,055h
	out	dx,al				; Poke data 1 (55h)

	regsel	43h
	inc	dx
	mov	ax,1				; Address 1
	out	dx,ax
	add	dx,3
	mov	al,0AAh
	out	dx,al				; Poke data 2 (AAh)

	regsel	43h
	inc	dx
	xor	ax,ax				; Address 0
	out	dx,ax
	add	dx,3
	in	al,dx				; Peek data 1
	cmp	al,055h
	jne	@@nogusinthisaddress

	regsel	43h
	inc	dx
	mov	ax,1				; Address 1
	out	dx,ax
	add	dx,3
	in	al,dx				; Peek data 2
	cmp	al,0AAh
	je	@@found

@@nogusinthisaddress:
	add	[GUS.port],10h
	cmp	[GUS.port],270h 		; GUS port range is 210h-260h
	jne	@@detectloop

	mov	[GUS.port],0
	mov	[word es:si],0
	jmp	@@quit

@@found:
	mov	[word es:si],1
@@quit: xor	ax,ax
	ret

ENDP

;/***************************************************************************\
;*
;* Function:	int gusInit(ushort rate, ushort mode)
;*
;* Description: Initializes the GUS for playing
;*
;* Input:	ushort rate		Mixing rate (no effect on GUS)
;*		ushort mode		Mode (see enum) (mono flag only)
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	gusInit FAR	rate : word, mode : word
USES	di

	mov	[instpos],1			; First instrument to be filled
	mov	[numInsts],0			; No instruments
	mov	[mastervol],64			; Default master volume
	mov	[masterchanged],0

	mov	ax,[mode]
	and	ax,sdMono			; AND mono bit
	mov	[monoFlag],ax			; 1 if mono, 0 otherwise

	mov	ax,[GUS.port]			; Base address (Set before!)
	add	ax,103h
	mov	[selreg],ax			; Register select (2x0h+103h)
	dec	ax
	mov	[voicesel],ax			; Voice select (2x0h+102h)

	call	gusReset			; Reset GUS

	mov	[memamount],0			; Initial memory amount
	mov	cx,4				; Max amount of 256k chunks
	xor	bx,bx				; Start from 00000h

@@memloop:
	regsel	44h
	add	dx,2
	mov	ax,bx
	out	dx,al				; upper bits of address

	regsel	43h
	inc	dx
	xor	ax,ax				; Address 0
	out	dx,ax
	add	dx,3
	mov	al,055h
	out	dx,al				; Poke data 1 (55h)

	regsel	43h
	inc	dx
	mov	ax,1				; Address 1
	out	dx,ax
	add	dx,3
	mov	al,0AAh
	out	dx,al				; Poke data 2 (AAh)

	regsel	43h
	inc	dx
	xor	ax,ax				; Address 0
	out	dx,ax
	add	dx,3
	in	al,dx				; Peek data 1
	cmp	al,055h
	jne	@@poiss

	regsel	43h
	inc	dx
	mov	ax,1				; Address 1
	out	dx,ax
	add	dx,3
	in	al,dx				; Peek data 2
	cmp	al,0AAh
	jne	@@poiss

	add	[memamount],256*1024		; Add amount of memory by 256k
	add	bx,4				; Next 256k chunk
	loop	@@memloop

@@poiss:					; No more memory
	cmp	[memamount],0
	jne	@@memok 			; NO MEMORY!

	mov	ax,errSDFailure 		; NO GUS
	jmp	@@err

@@memok:
	mov	eax,[memamount] 		; Initialize mem variables
	mov	[memavail],eax
	mov	[largestblock],eax


; Clear the all 32 channels

	mov	dx,[GUS.port]			; Mixer
	mov	al,3
	out	dx,al				; Disable Line in & out

	regsel	0eh
	add	dx,2
	mov	al,31 OR 0c0h
	out	dx,al				; Set number of active
						; voices to 32 just for
						; sure

	mov	cx,32				; Number of voices
@@resetloop:
	mov	dx,[voicesel]			; Voice Select
	mov	ax,cx
	out	dx,al

	regsel	0				; Voice control
	add	dx,2				; data low
	mov	al,3				; Stop voice
	out	dx,al

	regsel	9				; Current Volume
	inc	dx				; data high
	mov	ax,0500h			; Zero volume
	out	dx,ax

	regsel	12				; Pan Position
	add	dx,2				; data low
	mov	al,8				; Center
	out	dx,al

	regsel	13				; Volume Ramping
	add	dx,2				; data low
	mov	al,3				; disable
	out	dx,al

	regsel	6				; Ramp Rate
	add	dx,2
	mov	al,2fh				; Rate
	out	dx,al
	loop	@@resetloop

	regsel	4ch				; RESET
	add	dx,2
	mov	al,3
	out	dx,al				; Enable GF1 and DACs

	call	initHeap			; Initialize GUS-heap
	test	ax,ax
	jne	@@err

	call	memAlloc LANG, MAXINSTS * SIZE gusInstrument,\
		seg temp offset temp
						; Alloc room for instruments
	test	ax,ax
	jne	@@err

	mov	ebx,[temp]
	mov	[Instruments],ebx

	mov	di,bx
	shr	ebx,16
	mov	es,bx
	xor	eax,eax
	mov	cx,MAXINSTS * SIZE gusInstrument
	cld
	rep	stosb				; Clear instrument datas

	mov	[GUS.status],sdOK		; SD initialized
	xor	ax,ax
	ret

@@err:	ERROR	ID_gusInit			; Heap error
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	gusReset
;*
;* Description: Resets the GUS card
;*
;* Destroys:	ax, dx
;*
;\***************************************************************************/
PROC	gusReset NEAR

	regsel	4ch				; RESET
	add	dx,2
	mov	al,0
	out	dx,al				; RESET!

	call	gusdelay
	call	gusdelay

	mov	al,1
	out	dx,al				; Enable GF1

	call	gusdelay
	call	gusdelay
	ret
ENDP

;/***************************************************************************\
;*
;* Function:	int gusClose()
;*
;* Description: Closes up the GUS.
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	gusClose FAR

	call	gusReset

	mov	dx,[GUS.port]			; Mixer
	xor	al,al
	out	dx,al				; Enable Line in & out

	call	freeHeap
	test	ax,ax
	jnz	@@err

	call	memFree LANG, [Instruments]	; Free instruments
	test	ax,ax
	jnz	@@err

	mov	[instpos],1			; Flush instruments
	mov	[GUS.status],sdUnInitialized
	ret					; ax already 0

@@err:	ERROR	ID_gusClose
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int gusGetMixRate(ushort *rate)
;*
;* Description: Returns the mixing rate of the SD
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	gusGetMixRate FAR	rate:far ptr
	mov	ax,[mixfreq]			; Get mixing rate
	les	bx,[rate]
	mov	[es:bx],ax
	xor	ax,ax				; Can't fail
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	int gusGetMode(ushort *mode)
;*
;* Description: Returns the output mode
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	gusGetMode	FAR	mode:far ptr

	mov	ax,sd16bit or sdHighQ
	mov	bx,2
	sub	bx,[monoFlag]			; 1 if mono (=sdMono)
						; 2 if not (=sdStereo)
	or	ax,bx
	les	bx,[mode]
	mov	[es:bx],ax
	xor	ax,ax				; Can't fail
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int gusOpenChans(ushort chans)
;*
;* Description: Open channels from the GUS
;*
;* Input:	ushort chans		Number of channels to open
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	gusOpenChans	FAR    chans:word
USES	si,di

	cld

	mov	bx,[chans]
	mov	[chancount],bx

	mov	[muted],0
	mov	[paused],0

	cmp	[surround],0
	je	@@nsurr
	add	bx,bx
	cmp	bx,32
	ja	@@err
@@nsurr:
	cmp	bx,14
	jae	@@okei
	mov	bx,14
@@okei:
	mov	cx,bx

	sub	bx,14
	add	bx,bx
	mov	bx,[chantab+bx] 		; Take the mixing rate
	mov	[mixfreq],bx

	regsel	0eh
	add	dx,2
	mov	ax,cx
	dec	ax				; Amount-1
	or	al,0c0h
	out	dx,al

	mov	ax,ds
	mov	es,ax
	mov	di,offset channels

	xor	al,al
	mov	cx,size gusChannel*32
	rep	stosb				; Clear channel blocks

	mov	cx,[chans]			; to the table
	xor	bx,bx				; Start from channel 0

@@panloop:
	mov	dx,[voicesel]			; Voice Select
	mov	ax,[chans]
	sub	ax,cx
	out	dx,al

	regsel	12				; Pan Position
	add	dx,2				; data low

	mov	[bx+channels.panning],panMiddle ; Panning position

	mov	al,8				; Middle
	out	dx,al

	mov	[bx+channels.status],1		; Stop sound
	cmp	[surround],0
	je	@@nss

	mov	ax,[chancount]
	imul	ax,ax,size gusChannel		; Get surround chan
	mov	si,ax
	add	si,bx
	mov	[si+channels.status],81h	; Stop sound and mute

@@nss:	add	bx,SIZE gusChannel

	loop	@@panloop

	mov	dx,[GUS.port]
	xor	ax,ax
	out	dx,al				; Enable line in and out

	call	gusMute LANG, 0
	test	ax,ax
	jnz	@@err2
	ret

@@err:	mov	ax,errNoChannels		; Too much channels
@@err2: ERROR	ID_gusOpenChans
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int gusCloseChans()
;*
;* Description: Closes channels from the GUS
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	gusCloseChans	 FAR
	call	gusClearChans LANG
	mov	[chancount],0
	xor	ax,ax				; Can't fail
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int gusClearChans()
;*
;* Description: Clears the channels from the GUS
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	gusClearChans	 FAR
USES	si

	xor	bx,bx
	mov	cx,[chancount]
@@clloop:
	mov	dx,[voicesel]			; Voice Select
	mov	ax,[chancount]
	sub	ax,cx
	out	dx,al

	regsel	0				; Voice control
	add	dx,2
	mov	al,3
	out	dx,al				; Stop sound

	call	gusdelay

	out	dx,al				; Stop sound

	regsel	12				; Pan Position
	add	dx,2				; data low

	mov	[bx+channels.panning],panMiddle ; Panning position
	mov	[bx+channels.inst],0		; No instrument
	and	[bx+channels.status], NOT 80h	; Not muted

	mov	al,8				; Middle
	out	dx,al

	or	[bx+channels.status],1		; Stop sound
	cmp	[surround],0
	je	@@nss

	mov	ax,[chancount]
	imul	ax,ax,size gusChannel		; Get surround chan
	mov	si,ax
	add	si,bx
	or	[si+channels.status],81h	; Stop sound and mute

	mov	dx,[voicesel]			; Voice Select
	mov	ax,[chancount]
	add	ax,ax				; Surround channel
	sub	ax,cx
	out	dx,al

	regsel	0				; Voice control
	add	dx,2
	mov	al,3
	out	dx,al				; Stop sound

	call	gusdelay

	out	dx,al				; Stop sound

@@nss:	add	bx,SIZE gusChannel
	loop	@@clloop
	xor	ax,ax				; Can't fail
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int gusMute(ushort mute)
;*
;* Description: Mutes/unmutes GUS channels
;*
;* Input:	ushort mute		UnMute = 0 / Mute = 1
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	gusMute FAR	mute:word
	mov	ax,[mute]
	mov	[muted],ax
	mov	bl,1				; Enable GF1 (Disable DACs)
	test	ax,ax
	jnz	@@mute
	mov	bl,3				; Enable DACs (Unmute)
@@mute:
	regsel	4ch				; RESET
	add	dx,2
	mov	al,bl
	out	dx,al
	xor	ax,ax				; Can't fail
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	int gusPause(ushort pause)
;*
;* Description: Pauses/unpauses GUS SD
;*
;* Input:	ushort pause		Unpause = 0 / Pause = 1
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	gusPause FAR	 pause:word
	mov	ax,[pause]
	mov	[paused],ax
	test	ax,ax
	jnz	@@pause

	xor	cx,cx
	xor	bx,bx
@@chloop:
	test	[si+channels.status],20h
	jz	@@off

	mov	dx,[voicesel]			; Select voice
	mov	ax,cx
	out	dx,al

	regsel	0
	add	dx,2
	mov	al,[si+channels.looped]
	out	dx,al

@@off:	add	si,SIZE gusChannel
	inc	cx
	cmp	cx,32
	jne	@@chloop
	jmp	@@done

@@pause:
	xor	cx,cx
	xor	si,si
@@chloop2:
	mov	dx,[voicesel]			; Select voice
	mov	ax,cx
	out	dx,al

	regsel	80h
	add	dx,2
	in	al,dx

	and	al,1				; Voice on / off
	xor	al,1				; To active high
	shl	al,5				; to bit 5
	and	[si+channels.status],NOT 20h
	or	[si+channels.status],al

	regsel	0
	add	dx,2
	mov	al,3
	out	dx,al				; Stop

	add	si,SIZE gusChannel
	inc	cx
	cmp	cx,32
	jne	@@chloop2

@@done: xor	ax,ax
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	int gusSetMaster(uchar master)
;*
;* Description: Sets the master volume for the GUS
;*
;* Input:	uchar master		New master volume (0-64)
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	gusSetMaster	FAR	master:word

	mov	ax,[master]
	mov	[mastervol],ax
	mov	[masterchanged],1
	xor	ax,ax				; Can't fail
	ret
ENDP

;/***************************************************************************\
;*
;* Function:	int gusPlaySound(ushort chan, ulong freq)
;*
;* Description: Starts a sound with a frequency
;*
;* Input:	ushort chan		Channel number
;*		ulong freq		Playing frequency
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	gusPlaySound	FAR	chan:word, freq:dword
USES	si
LOCAL	fc:word

	mov	bx,[chan]
	cmp	[chancount],bx
	jle	@@errchan

	imul	bx,bx,size gusChannel		; Get channel block

	mov	eax,[freq]
	mov	[bx+channels.frequency],eax

	shl	eax,10
	xor	edx,edx
	movzx	ecx,[mixfreq]			; GUS freq = frequency / mixing rate
	idiv	ecx
	and	ax,0fffeh			; Bit 0 unused
	mov	[bx+channels.fc],ax
	mov	[fc],ax
	or	[bx+channels.status],8		; FC changed

	movzx	dx,[bx+channels.inst]		; Instrument number
	test	dx,dx
	jz	@@errinst			; No instrument?
	cmp	dx,[numInsts]
	ja	@@errinst

	dec	dx				; Table starts from 1
	imul	dx,dx,SIZE gusInstrument

	les	si,[Instruments]
	add	si,dx
	cmp	[es:si+gusInstrument.length],0
	je	@@quit

	mov	ecx,[es:si+gusInstrument.sample] ; Start address
	mov	[bx+channels.scurrent],ecx	; Tell start position to GUS
	and	[bx+channels.status],NOT 17	; AND stop sound and sample changed off
	or	[bx+channels.status],2		; Retrig

	cmp	[surround],0
	je	@@quit

	mov	bx,[chan]
	add	bx,[chancount]
	imul	bx,bx,size gusChannel		; Get channel block

	mov	eax,[freq]
	mov	[bx+channels.frequency],eax

	mov	ax,[fc]
	mov	[bx+channels.fc],ax
	or	[bx+channels.status],8		; FC changed

	mov	ecx,[es:si+gusInstrument.surround] ; Start address
	mov	[bx+channels.scurrent],ecx	; Tell start position to GUS
	and	[bx+channels.status],NOT 17	; AND stop sound and sample changed off
	or	[bx+channels.status],2		; Retrig

@@quit:
	xor	ax,ax
	ret

@@errchan:
	mov	ax,errInvalidChanNumber
	jmp	@@err
@@errinst:
	mov	ax,errInvalidInstHandle
@@err:	ERROR	ID_gusPlaySound
	ret

ENDP


;/***************************************************************************\
;*
;* Function:	int gusStopSound(ushort chan)
;*
;* Description: Stops sound on a channel
;*
;* Input:	ushort chan		Channel number
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	gusStopSound	FAR	chan:word

	mov	bx,[chan]
	cmp	[chancount],bx
	jle	@@err

	imul	bx,bx,size gusChannel		; Channel block

	and	[bx+channels.status], NOT 18	; AND Retrig and sample change off
	or	[bx+channels.status],1		; Stop sound

	cmp	[surround],0
	je	@@quit

	mov	bx,[chan]
	add	bx,[chancount]
	imul	bx,bx,size gusChannel		; Channel block

	and	[bx+channels.status], NOT 18	; AND Retrig and sample change off
	or	[bx+channels.status],1		; Stop sound

@@quit: xor	ax,ax
	ret

@@err:	mov	ax,errInvalidChanNumber
	ERROR	ID_gusStopSound
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int gusSetRate(ushort chan, ulong freq)
;*
;* Description: Sets the playing rate for a channel
;*
;* Input:	ushort chan		Channel number
;*		ulong freq		New playing frequency
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	gusSetRate	FAR	chan:word, freq:dword

	mov	bx,[chan]
	cmp	[chancount],bx
	jle	@@err

	imul	bx,bx,size gusChannel

	mov	eax,[freq]
	mov	[bx+channels.frequency],eax

	shl	eax,10
	xor	edx,edx
	movzx	ecx,[mixfreq]			; GUS freq = frequency / mixing rate
	idiv	ecx
	and	ax,0fffeh			; bit 0 unused
	mov	[bx+channels.fc],ax
	or	[bx+channels.status],8

	cmp	[surround],0
	je	@@quit

	mov	bx,[chan]
	add	bx,[chancount]
	imul	bx,bx,size gusChannel

	mov	[bx+channels.fc],ax
	mov	eax,[freq]
	mov	[bx+channels.frequency],eax
	or	[bx+channels.status],8

@@quit: xor	ax,ax
	ret

@@err:	mov	ax,errInvalidChanNumber
	ERROR	ID_gusSetRate
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int gusGetRate(ushort chan, ulong *freq)
;*
;* Description: Returns the playing rate for a channel
;*
;* Input:	ushort chan		Channel number
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	gusGetRate	FAR	chan : word, freq:far ptr

	mov	bx,[chan]
	cmp	[chancount],bx
	jle	@@err

	mov	dx,[voicesel]			; Select voice
	mov	ax,bx
	out	dx,al

	regsel	80h				; Voice control
	add	dx,2
	in	al,dx
	test	al,1
	jnz	@@stopped			; Is sound on?

	mov	bx,[chan]
	imul	bx,bx,size gusChannel

	mov	eax,[bx+channels.frequency]
	les	bx,[freq]
	mov	[es:bx],eax
	xor	ax,ax
	ret

@@stopped:
	les	bx,[freq]
	mov	[dword es:bx],0
	xor	ax,ax
	ret

@@err:	mov	ax,errInvalidChanNumber
	ERROR	ID_gusGetRate
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	int gusSetVol(ushort chan, uchar volume)
;*
;* Description: Sets the volume for a channel
;*
;* Input:	ushort chan		Channel number
;*		uchar  volume		New playing volume
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	gusSetVol	FAR	chan:word, vol:word

	mov	ax,[vol]
	cmp	ax,64
	jbe	@@not64 			; Max volume = 64
	mov	ax,64
@@not64:
	mov	bx,[chan]
	cmp	[chancount],bx
	jle	@@err

	imul	bx,bx,size gusChannel

	mov	[bx+channels.volume],ax
	or	[bx+channels.status],4

	cmp	[surround],0
	je	@@quit

	mov	bx,[chan]
	add	bx,[chancount]
	imul	bx,bx,size gusChannel

	mov	[bx+channels.volume],ax
	or	[bx+channels.status],4

@@quit: xor	ax,ax
	ret

@@err:	mov	ax,errInvalidChanNumber
	ERROR	ID_gusSetVol
	ret

ENDP

;/***************************************************************************\
;*
;* Function:	int gusSetInst(ushort chan, ushort inst)
;*
;* Description: Sets up an instrument for playing
;*
;* Input:	ushort chan		Channel number
;*		ushort inst		Instrument number from AddInstrument
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	gusSetInst	FAR	chan:word, inst:word
USES	edi, si

	mov	bx,[chan]
	cmp	[chancount],bx
	jle	@@errchn
	imul	bx,bx,size gusChannel		; Channel block

	mov	ax,[inst]
	test	ax,ax
	jz	@@errinst			; No instrument at all?
	cmp	ax,[numInsts]
	ja	@@errinst

	mov	dx,ax
	dec	dx				; Table starts from 1
	imul	dx,dx,SIZE gusInstrument
	les	si,[Instruments]
	add	si,dx

	cmp	[bx+channels.inst],al
	je	@@nochange

	mov	[bx+channels.inst],al		; Set instrument

	cmp	[es:si+gusInstrument.length],0
	je	@@stop

	mov	ecx,[es:si+gusInstrument.sample] ; Start address
	mov	[bx+channels.scurrent],ecx	; Tell start position to GUS

	test	[es:si+gusInstrument.flags],2 ; Is sample looped?
	jz	@@noloop

	mov	edi,ecx
	movzx	eax,[es:si+gusInstrument.loopEnd]
	add	edi,eax 			; Loop end address
	movzx	eax,[es:si+gusInstrument.loopStart]
	add	ecx,eax 			; Loop start address
	mov	al,8				; Enable loop
	jmp	@@duu

@@noloop:
	movzx	eax,[es:si+gusInstrument.length]
	mov	edi,ecx
	add	edi,eax 			; Sample end address
	xor	al,al				; No loop
@@duu:
	mov	[bx+channels.looped],al 	; Put loop flag
	mov	[bx+channels.sstart],ecx	; Tell loop start to GUS
	mov	[bx+channels.send],edi		; And loop end
	or	[bx+channels.status],16 	; Sample changed

@@nochange:
	mov	ax,[es:si+gusInstrument.volume] ; Set volume

	mov	[bx+channels.volume],ax
	or	[bx+channels.status],4

@@poiss:
	cmp	[surround],0
	je	@@quit

	mov	bx,[chan]
	add	bx,[chancount]
	imul	bx,bx,size gusChannel		; Channel block

	mov	ax,[inst]

	cmp	[bx+channels.inst],al
	je	@@nochange2

	mov	[bx+channels.inst],al		; Set instrument

	mov	ecx,[es:si+gusInstrument.surround] ; Start address
	mov	[bx+channels.scurrent],ecx	; Tell start position to GUS

	test	[es:si+gusInstrument.flags],2	; Is sample looped?
	jz	@@noloop2

	mov	edi,ecx
	movzx	eax,[es:si+gusInstrument.loopEnd]
	add	edi,eax 			; Loop end address
	movzx	eax,[es:si+gusInstrument.loopStart]
	add	ecx,eax 			; Loop start address
	mov	al,8				; Enable loop
	jmp	@@duu2

@@noloop2:
	movzx	eax,[es:si+gusInstrument.length]
	mov	edi,ecx
	add	edi,eax 			; Sample end address
	xor	al,al				; No loop
@@duu2:
	mov	[bx+channels.looped],al 	; Put loop flag
	mov	[bx+channels.sstart],ecx	; Tell loop start to GUS
	mov	[bx+channels.send],edi		; And loop end
	or	[bx+channels.status],16 	; Sample changed

@@nochange2:
	mov	ax,[es:si+gusInstrument.volume]      ; Set volume
	mov	[bx+channels.volume],ax
	or	[bx+channels.status],4

@@quit:
	xor	ax,ax
	ret

@@stop: call	gusStopSound LANG, [chan]
	ret

@@errinst:
	mov	ax,errInvalidInstHandle
	jmp	@@err
@@errchn:
	mov	ax,errInvalidChanNumber
@@err:	ERROR	ID_gusSetInst
	ret
ENDP

;/***************************************************************************\
;*
;* Function:	int gusSetPos(ushort chan, ushort pos)
;*
;* Description: Sets the playing position for a channel
;*
;* Input:	ushort chan		Channel number
;*		ushort pos		New playing position
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	gusSetPos	FAR	chan:word, pos:word
USES	si

	mov	bx,[chan]
	cmp	[chancount],bx
	jle	@@err
	imul	bx,bx,size gusChannel		; Channel block

	movzx	dx,[bx+channels.inst]
	test	dx,dx
	jz	@@quit				; No instrument?

	dec	dx				; Table starts from 1
	imul	dx,dx,SIZE gusInstrument
	les	si,[Instruments]
	add	si,dx

	movzx	ecx,[pos]
	cmp	[es:si+gusInstrument.length],cx ; Over from end?
	jae	@@ok

	movzx	ecx,[es:si+gusInstrument.loopStart] ; Yep. Start from loop
	test	[es:si+gusInstrument.flags],2
	jnz	@@ok

	call	gusStopSound LANG, [chan]
	ret

@@ok:	add	ecx,[es:si+gusInstrument.sample] ; Add sample start to position
	mov	[bx+channels.scurrent],ecx	; Set start position
	and	[bx+channels.status],NOT 17	; AND stop sound and sample changed off
	or	[bx+channels.status],2		; Retrig

	cmp	[surround],0
	je	@@quit

	mov	bx,[chan]
	add	bx,[chancount]
	imul	bx,bx,size gusChannel		; Channel block

	movzx	ecx,[pos]
	add	ecx,[es:si+gusInstrument.surround] ; Add sample start to position
	mov	[bx+channels.scurrent],ecx	; Set start position
	and	[bx+channels.status],NOT 17	; AND stop sound and sample changed off
	or	[bx+channels.status],2		; Retrig

@@quit:
	xor	ax,ax
	ret

@@err:	mov	ax,errInvalidChanNumber
	ERROR	ID_gusSetPos
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int gusGetPos(ushort chan, ushort *pos)
;*
;* Description: Gets the playing position of a channel
;*
;* Input:	ushort chan		Channel number
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	gusGetPos	FAR	chan:word, pos:far ptr
USES	si

	mov	bx,[chan]
	cmp	[chancount],bx
	jle	@@err

	mov	dx,[voicesel]			; Select voice
	mov	ax,bx
	out	dx,al

	regsel	80h				; Voice control
	add	dx,2
	in	al,dx
	test	al,1
	jnz	@@stopped			; Is sound on?

	imul	bx,bx,size gusChannel		; Channel block

	regsel	8ah				; Current position high
	inc	dx
	in	ax,dx
	xor	ecx,ecx
	mov	cx,ax
	and	cx,01fffh
	shl	ecx,7

	regsel	8bh				; Current position low
	inc	dx
	in	ax,dx
	shr	ax,9
	or	cx,ax

	movzx	bx,[bx+channels.inst]
	dec	bx
	imul	bx,bx,SIZE gusInstrument

	les	si,[Instruments]
	sub	ecx,[es:si+bx+gusInstrument.sample]

	mov	ax,cx
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
	ERROR	ID_gusGetPos
	ret

ENDP


;/***************************************************************************\
;*
;* Function:	int gusSetPanning(ushort chan, short panning)
;*
;* Description: Sets the panning position for a channel
;*
;* Input:	ushort channel		Channel number
;*		short panning		Panning info (See enum)
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	gusSetPanning	FAR	chan:word, panning:word

	mov	dx,[voicesel]			; Voice Select
	mov	ax,[chan]
	cmp	[chancount],ax
	jle	@@err
	out	dx,al

	mov	bx,[chan]
	imul	bx,bx,size gusChannel		; Channel block

	regsel	12				; Pan Position
	add	dx,2				; data low
	mov	ax,[panning]

	mov	[bx+channels.panning],ax	; Panning position

	cmp	[monoFlag],1
	je	@@jatkuu			; Skip if forced mono

	cmp	ax,panSurround
	jne	@@juuh

	cmp	[surround],0
	jne	@@huu
	xor	ax,ax
	jmp	@@juuh

@@huu:	xor	al,al				; To extreme left
	out	dx,al

	mov	dx,[voicesel]			; Voice Select
	mov	ax,[chan]
	add	ax,[chancount]			; Surround channel
	out	dx,al

	regsel	12				; Pan Position
	add	dx,2				; data low
	mov	al,15				; To extreme right
	out	dx,al

	mov	[bx+channels.surround],1	; This is a surround channel
	mov	al,[bx+channels.status] 	; Copy status (mute)

	mov	cx,[chancount]
	imul	cx,cx,size gusChannel		; Channel block
	add	bx,cx

	mov	[bx+channels.surround],1	; This is a surround, too
	mov	[bx+channels.status],al
	jmp	@@jatkuu

@@juuh: mov	[bx+channels.surround],0	; Normal channel

	mov	bx,[chan]
	add	bx,[chancount]
	cmp	bx,32
	jae	@@skib
	imul	bx,bx,size gusChannel		; Channel block
	mov	[bx+channels.surround],0	; No longer surround channel (?)
	or	[bx+channels.status],80h	; Mute channel

@@skib: sar	ax,3
	or	ax,ax				; Sign
	jns	@@pos
	inc	ax
@@pos:	add	ax,7
	out	dx,al

@@jatkuu:
	mov	[masterchanged],1		; Force reset of volume
@@quit: xor	ax,ax
	ret

@@err:	mov	ax,errInvalidChanNumber
	ERROR	ID_gusSetPanning
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	int gusGetPanning(ushort chan, short *panning)
;*
;* Description: Gets the panning position for a channel
;*
;* Input:	ushort channel		Channel number
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	gusGetPanning	FAR	channel : word, panning : far ptr

	mov	bx,[channel]
	cmp	[chancount],bx
	jle	@@err
	imul	bx,bx,size gusChannel		; Channel block
	mov	ax,[bx+channels.panning]	; Panning position
	les	bx,[panning]
	mov	[es:bx],ax
	xor	ax,ax
	ret

@@err:	mov	ax,errInvalidChanNumber
	ERROR	ID_gusGetPanning
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	int gusMuteChannel(ushort chan, ushort mute)
;*
;* Description: Mutes or unmutes a channel
;*
;* Input:	ushort chan		Channel number
;*		ushort mute		UnMute = 0 / Mute = 1
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	gusMuteChannel	FAR	chan:word, mute:word

	mov	bx,[chan]
	cmp	[chancount],bx
	jle	@@err
	imul	bx,bx,SIZE gusChannel

	mov	[masterchanged],1

	mov	ax,[mute]
	cmp	ax,1
	je	@@mute
	and	[bx+channels.status],07fh
	jmp	@@guu
@@mute:
	or     [bx+channels.status],80h

@@guu:	cmp	[bx+channels.surround],0
	je	@@pois

	mov	bx,[chan]
	add	bx,[chancount]
	imul	bx,bx,SIZE gusChannel

	mov	ax,[mute]
	cmp	ax,1
	je	@@mute2
	and	[bx+channels.status],07fh
	jmp	@@pois
@@mute2:
	or     [bx+channels.status],80h

@@pois: xor	ax,ax
	ret

@@err:	mov	ax,errInvalidChanNumber
	ERROR	ID_gusMuteChannel
	ret

ENDP



;/***************************************************************************\
;*
;* Function:	int gusAddInst(uchar *sample, ushort smpType, ushort length,\
;*			       ushort loopStart, ushort loopEnd,\
;*			       ushort volume, ushort loop, ushort *sdInstNum)
;*
;* Description: Adds an instrument to the GUS SD internal tables for
;*		use and moves it to GUS memory
;*
;* Input:	uchar  *sample		pointer to sample
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

PROC	gusAddInst	FAR	inst:far ptr, stype:word, length:word, loopStart:word,\
				loopEnd:word, volume:word, loop:word, sdNum:far ptr
USES	si,di
LOCAL	gusmem:dword, gusmem2:dword

	cmp	[stype],smp8bit
	jne	@@errinst

	mov	ax,[instpos]
	dec	ax				; Table starts from 1
	imul	ax,ax,SIZE gusInstrument
	les	di,[Instruments]
	add	di,ax

	cmp	[length],0
	je	@@nsurr

	push	es
	call	gusMalloc LANG, [length], seg temp offset temp
	pop	es
	test	ax,ax
	jnz	@@err

	mov	eax,[temp]
	mov	[gusmem],eax

	mov	[es:di+gusInstrument.sample],eax   ; Sample start
	mov	[es:di+gusInstrument.surround],0

	cmp	[surround],0
	je	@@nsurr

	push	es
	call	gusMalloc LANG, [length], seg temp offset temp
	pop	es
	test	ax,ax
	jnz	@@err

	mov	eax,[temp]
	mov	[gusmem2],eax
	mov	[es:di+gusInstrument.surround],eax ; Surround sample start

@@nsurr:
	mov	ax,[length]
	mov	[es:di+gusInstrument.length],ax ; Sample length

	mov	ax,[loopStart]
	mov	[es:di+gusInstrument.loopStart],ax ; Loop start offset

	mov	ax,[loopEnd]
	mov	[es:di+gusInstrument.loopEnd],ax  ; Loop end offset

	mov	ax,[volume]
	cmp	ax,64
	jbe	@@oke
	mov	ax,64
@@oke:	mov	[es:di+gusInstrument.volume],ax ; Default volume

	mov	ax,[loop]			; Loop flag
	and	ax,1
	add	ax,ax
	or	ax,1				; Used flag
	mov	[es:di+gusInstrument.flags],ax


	les	si,[inst]			; Pointer to sample

	mov	cx,[length]
	test	cx,cx
	jz	@@qwit

	mov	ebx,[gusmem]			; Start in GUS memory
	mov	di,bx
	shr	ebx,16

@@dumploop2:
	regsel	44h				; Addr hi
	add	dx,2				; 3x5
	mov	ax,bx
	out	dx,al				; upper bits of address

	regsel	43h				; Addr lo
@@dumploop:
	mov	dx,[selreg]
	inc	dx				; 3x4
	mov	ax,di
	out	dx,ax
	add	dx,3				; 3x7
	mov	al,[es:si]			; Get data
	inc	si
	xor	al,80h				; Unsigned (MUUTA!)
	out	dx,al

	add	di,1				; Inc ei aseta carry„
	jc	@@yli64
	loop	@@dumploop			; Dump the whole sample
	jmp	@@quit

@@yli64:
	inc	bx				; Crossed 64kb border
	loop	@@dumploop2			; Dump the whole sample


@@quit: test	[loop],1
	jz	@@noloob			; Looped?

@@loobed:					; Copy loop to next 32 byte border
	les	si,[inst]
	add	si,[loopStart]

	mov	dx,di
	and	dx,01fh 			; Alimmat pois
	mov	cx,64
	sub	cx,dx

@@dumploop3:
	regsel	44h				; Addr hi
	add	dx,2				; 3x5
	mov	ax,bx
	out	dx,al				;upper bits of address

	regsel	43h				; Addr lo
@@dumploop4:
	mov	dx,[selreg]
	inc	dx				; 3x4
	mov	ax,di

	out	dx,ax
	add	dx,3				; 3x7
	mov	al,[es:si]			; Get data
	inc	si
	xor	al,80h				; Unsigned (MUUTA!)
	out	dx,al

	add	di,1				; Inc ei aseta carry„
	jc	@@yli642
	loop	@@dumploop3			; Do whole loop
	jmp	@@qwti

@@yli642:
	inc	bx				; Crossed 64kb border
	loop	@@dumploop4			; Do whole loop
	jmp	@@qwti


@@noloob:					; Copy the last byte
	dec	si
	mov	dx,di
	and	dx,01fh 			; Alimmat pois
	mov	cx,64
	sub	cx,dx

@@dumploop5:
	regsel	44h				; addr hi
	add	dx,2				; 3x5
	mov	ax,bx
	out	dx,al				; upper bits of address

	regsel	43h				; addr lo
@@dumploop6:
	mov	dx,[selreg]
	inc	dx				; 3x4
	mov	ax,di

	out	dx,ax
	add	dx,3				; 3x7
	mov	al,[es:si]			; Get data
	xor	al,80h				; Unsigned (MUUTA!)
	out	dx,al

	add	di,1				; Inc ei aseta carry„
	jc	@@yli643
	loop	@@dumploop6
	jmp	@@qwti
@@yli643:
	inc	bx				; Crossed 64kb border
	loop	@@dumploop5

@@qwti: cmp	[surround],0
	je	@@qwit

	call	CopySurroundSample LANG, [inst], [length], [loopStart],\
					 [loop], [gusmem2]


@@qwit: push	[instpos]			; Return instrument number

	mov	ax,[instpos]
	mov	bx,ax
	dec	bx
	imul	bx,bx,SIZE gusInstrument
	les	si,[Instruments]
	add	si,bx
@@search:					; Search next free instrument
	test	[es:si+gusInstrument.flags],1
	jz	@@found
	add	si,SIZE gusInstrument
	inc	ax
	jmp	@@search

@@found:
	mov	[instpos],ax
	pop	ax
	les	bx,[sdNum]
	mov	[es:bx],ax

	cmp	ax,[numInsts]
	jbe	@@huu
	mov	[numInsts],ax
@@huu:
	xor	ax,ax
	ret


@@errinst:
	mov	ax,errInvalidInst
@@err:	ERROR	ID_gusAddInst
	ret
ENDP



PROC	CopySurroundSample NEAR inst:far ptr, length:word, loopStart:word,\
				loop:word, gusmem:dword
USES	si,di

	les	si,[inst]			; Pointer to sample

	mov	cx,[length]

	mov	ebx,[gusmem]			; Start in GUS memory
	mov	di,bx
	shr	ebx,16

@@dumploop2:
	regsel	44h
	add	dx,2				;3x5
	mov	ax,bx
	out	dx,al				;upper bits of address

	regsel	43h
@@dumploop:
	mov	dx,[selreg]
	inc	dx				; 3x4
	mov	ax,di
	out	dx,ax
	add	dx,3				; 3x7
	mov	al,[es:si]			; Get data
	inc	si
	xor	al,80h				; Unsigned (MUUTA!)
	not	al				; 180 degree phase transformation
	out	dx,al

	add	di,1				; Inc ei aseta carry„
	jc	@@yli64
	loop	@@dumploop			; Dump the whole sample
	jmp	@@quit

@@yli64:
	inc	bx				; Crossed 64kb border
	loop	@@dumploop2			; Dump the whole sample

@@quit: test	[loop],1
	jz	@@noloob			; Looped?

@@loobed:					; Copy loop to next 32 byte border
	les	si,[inst]
	add	si,[loopStart]

	mov	dx,di
	and	dx,01fh 			; Alimmat pois
	mov	cx,64
	sub	cx,dx

@@dumploop3:
	regsel	44h
	add	dx,2				;3x5
	mov	ax,bx
	out	dx,al				;upper bits of address

	regsel	43h
@@dumploop4:
	mov	dx,[selreg]
	inc	dx				; 3x4
	mov	ax,di

	out	dx,ax
	add	dx,3				; 3x7
	mov	al,[es:si]			; Get data
	inc	si
	xor	al,80h				; Unsigned (MUUTA!)
	not	al				; 180 degree phase transformation
	out	dx,al

	add	di,1				; Inc ei aseta carry„
	jc	@@yli642
	loop	@@dumploop3			; Do whole loop
	jmp	@@qwit

@@yli642:
	inc	bx				; Crossed 64kb border
	loop	@@dumploop4			; Do whole loop
	jmp	@@qwit



@@noloob:					; Copy the last byte
	dec	si
	mov	dx,di
	and	dx,01fh 			; Alimmat pois
	mov	cx,64
	sub	cx,dx

@@dumploop5:
	regsel	44h
	add	dx,2				;3x5
	mov	ax,bx
	out	dx,al				;upper bits of address

	regsel	43h
@@dumploop6:
	mov	dx,[selreg]
	inc	dx				; 3x4
	mov	ax,di

	out	dx,ax
	add	dx,3				; 3x7
	mov	al,[es:si]			; Get data
	xor	al,80h				; Unsigned (MUUTA!)
	not	al				; 180 degree phase transformation
	out	dx,al

	add	di,1				; Inc ei aseta carry„
	jc	@@yli643
	loop	@@dumploop6
	jmp	@@qwit
@@yli643:
	inc	bx				; Crossed 64kb border
	loop	@@dumploop5
@@qwit:
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int gusRemInst(ushort inst)
;*
;* Description: Removes an instrument from the GUS SD internal tables
;*		and frees it from GUS memory
;*
;* Input:	ushort	inst		Instrument number from AddInstrument
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	gusRemInst	FAR	inst:word
USES	si

	mov	bx,[inst]
	dec	bx
	imul	bx,bx,SIZE gusInstrument
	les	si,[Instruments]
	add	si,bx

	test	[es:si+gusInstrument.flags],1
	jz	@@nothing

	mov	[es:si+gusInstrument.flags],0	; Free instrument

	cmp	[es:si+gusInstrument.length],0
	je	@@nsurround

	push	es
	call	gusFree LANG, [es:si+gusInstrument.sample]
	pop	es
	test	ax,ax
	jnz	@@err

	cmp	[es:si+gusInstrument.surround],0
	je	@@nsurround

	call	gusFree LANG, [es:si+gusInstrument.surround]
	test	ax,ax
	jnz	@@err

@@nsurround:
	mov	ax,[inst]
	cmp	ax,[instpos]
	jae	@@nothing

	mov	[instpos],ax			; Lowest instrument number
@@nothing:
	cmp	[numInsts],ax
	jne	@@juu

	les	si,[Instruments]
	mov	cx,ax
	mov	bx,1
	mov	ax,bx
@@search:					; Search next free instrument
	test	[es:si+gusInstrument.flags],1
	jz	@@nop
	mov	ax,bx

@@nop:	add	si,SIZE gusInstrument
	inc	bx
	loop	@@search
	mov	[numInsts],ax
@@juu:	xor	ax,ax
	ret

@@err:	ERROR	ID_gusRemInst
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	int gusSetUpdRate(ushort rate)
;*
;* Description: Sets the update rate of SD.
;*
;* Input:	ushort	rate			Rate in Hz*100
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/

PROC	gusSetUpdRate	FAR	rate:word

	mov	ax,[rate]
	mov	[updRate],ax
	xor	ax,ax
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int gusPlay(int *callMP)
;*
;* Description: Updates the GUS registers according to the Sound Device
;*		internal datas
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	gusPlay FAR	callMP : far ptr
LOCAL	chanc:word

USES	si
	cmp	[paused],0
	jne	@@paused

	mov	[chanc],0			; Start from channel 0
	mov	si,offset channels		; Channel data
@@loop:
	mov	dx,[voicesel]			; Select voice
	mov	ax,[chanc]
	out	dx,al

	test	[si+gusChannel.status],3	; Retrig / stop sound?
	jz	@@nothing

	and	[si+gusChannel.status],NOT 1	; And stop sound off

	regsel	0				; Voice control
	add	dx,2
	mov	al,3				; Stop voice
	out	dx,al

	regsel	9				; Current volume
	inc	dx
	mov	ax,1200h			; To zero
	out	dx,ax

	regsel	0dh				; Ramp control
	add	dx,2
	mov	al,3				; Stop
	out	dx,al

	call	gusdelay

	out	dx,al				; Stop

	regsel	0				; Voice control
	add	dx,2
	mov	al,3				; Stop voice
	out	dx,al

	regsel	9				; Current volume
	inc	dx
	mov	ax,1200h			; To zero
	out	dx,ax

	test	[si+gusChannel.status],2
	jz	@@stopped			; Only stop

	mov	ecx,[si+gusChannel.send]	; Set sample end

	regsel	4				; End position high
	inc	dx
	mov	eax,ecx
	shr	eax,7
	out	dx,ax
	regsel	5				; End position low
	inc	dx
	mov	eax,ecx
	shl	ax,9
	out	dx,ax

	mov	ecx,[si+gusChannel.sstart]	; Set loop start

	regsel	2				; Start position high
	inc	dx
	mov	eax,ecx
	shr	eax,7
	out	dx,ax
	regsel	3				; Start position low
	inc	dx
	mov	eax,ecx
	shl	ax,9
	out	dx,ax

	mov	ecx,[si+gusChannel.scurrent]	; Set starting address

	regsel	10				; Current position high
	inc	dx
	mov	eax,ecx
	shr	eax,7
	out	dx,ax
	regsel	11				; Current position low
	inc	dx
	mov	eax,ecx
	shl	ax,9
	out	dx,ax

	call	gusdelay			; Delay

	out	dx,ax

	regsel	10				; Current position high
	inc	dx
	mov	eax,ecx
	shr	eax,7
	out	dx,ax

	regsel	7				; Ramp start
	add	dx,2
	mov	al,12h				; From 0
	out	dx,al

	regsel	8				; Ramp end
	add	dx,2
	mov	ax,[si+gusChannel.volume]	; To set volume

	test	[si+gusChannel.status],80h
	jz	@@oek
	xor	ax,ax
@@oek:
	mov	bx,[mastervol]
	mul	bl
	shr	ax,6
	mov	bx,ax
	add	bx,bx
	mov	ax,[voltable+bx]
	mov	al,ah

	cmp	[si+gusChannel.surround],0
	je	@@hu
	sub	al,10h				; Halve the volume
@@hu:	out	dx,al

	regsel	6				; Ramp Rate
	add	dx,2
	mov	al,0fh				; Rate
	out	dx,al
	jmp	@@setfc

@@nothing:
	cmp	[masterchanged],0
	jnz	@@set
	test	[si+gusChannel.status],4
	jz	@@setfc
@@set:	and	[si+gusChannel.status],NOT 4
	regsel	89h
	inc	dx
	in	ax,dx
	mov	cx,ax
	xor	cl,cl

	mov	ax,[si+gusChannel.volume]	; To set volume
	test	[si+gusChannel.status],80h
	jz	@@oek2
	xor	ax,ax
@@oek2: mov	bx,[mastervol]
	mul	bl
	shr	ax,6
	mov	bx,ax
	add	bx,bx
	mov	bx,[voltable+bx]

	cmp	[si+gusChannel.surround],0
	je	@@hu2
	sub	bh,10h				; Halve the volume
@@hu2:	xor	bl,bl
	cmp	cx,bx
	je	@@setfc
	cmp	cx,bx
	jb	@@yli
	xchg	cx,bx
	mov	cl,40h
@@yli:
	regsel	0dh				; Ramp Control
	add	dx,2
	mov	al,3
	out	dx,al				; Stop Ramp

	call	gusdelay

	out	dx,al				; Stop Ramp

	regsel	7				; Ramp start
	add	dx,2
	mov	al,ch				; From lower
	out	dx,al

	regsel	8				; Ramp end
	add	dx,2
	mov	al,bh				; To higher volume
	out	dx,al

	regsel	6				; Ramp Rate
	add	dx,2
	mov	al,1fh				; Rate
	out	dx,al

	regsel	0dh				; Ramp Control
	add	dx,2
	mov	al,cl
	out	dx,al				; GO!

	call	gusdelay

	out	dx,al				; GO!


@@setfc:
	test	[si+gusChannel.status],8
	jz	@@stopped

	and	[si+gusChannel.status],NOT 8
	regsel	1				; Frequency control
	inc	dx
	mov	ax,[si+gusChannel.fc]
	out	dx,ax

@@stopped:
	test	[si+gusChannel.status],2
	jz	@@retrigged

	regsel	0				; Voice control
	mov	al,[si+gusChannel.looped]	; Enable voice and possible loop
	add	dx,2
	out	dx,al

	regsel	0dh				; Ramp Control
	add	dx,2
	xor	al,al
	out	dx,al				; GO!

	call	gusdelay			; Delay

	out	dx,al				; GO!

	regsel	0				; Write it again
	mov	al,[si+gusChannel.looped]
	add	dx,2
	out	dx,al

	and	[si+gusChannel.status],NOT 2	; Retrig done
	jmp	@@retrigged
@@no:
	test	[si+gusChannel.status],16
	jz	@@retrigged			; No sample changed

	cmp	[ALE],1
	jne	@@noALE


;±± GUS-AMIGA-LOOP-EMULATOR (GALE) (TM) V1.1!!! ±±


	mov	dx,[voicesel]			; Select voice
	mov	ax,[chanc]
	out	dx,al

	regsel	80h				; Voice control
	add	dx,2
	in	al,dx

	xor	ebx,ebx 			; Offset from loop start
	test	al,1
	jz	@@soundon

	test	[si+gusChannel.looped],8	; Next sample looped?
	jz	@@stopsound			; No

	mov	ebx,[si+gusChannel.sstart]
	jmp	@@startfromloop 		; Start from loop start

@@soundon:
	regsel	8ah				; Current position high
	inc	dx
	in	ax,dx
	xor	ecx,ecx
	mov	cx,ax
	and	cx,01fffh
	shl	ecx,7

	regsel	8bh				; Current position low
	inc	dx
	in	ax,dx
	shr	ax,9
	or	cx,ax

	regsel	84h				; Sample end position high
	inc	dx
	in	ax,dx
	xor	ebx,ebx
	mov	bx,ax
	and	bx,01fffh
	shl	ebx,7

	regsel	85h				; Sample end position low
	inc	dx
	in	ax,dx
	shr	ax,9
	or	bx,ax

	sub	ebx,ecx 			; Bytes to sample / loop end

	mov	eax,[si+gusChannel.frequency]
	imul	eax,eax,100			; updRate is Hz*100
	xor	edx,edx
	push	ebx
	movzx	ebx,[updRate]
	idiv	ebx				; eax = bytes to play until next update
	pop	ebx

	cmp	ebx,eax
	jge	@@retrigged			; Some sample still to go

	test	[si+gusChannel.looped],8	; Looped?
	jz	@@stopsound

	mov	ecx,[si+gusChannel.send]
	sub	ecx,ebx
	mov	ebx,ecx

@@startfromloop:
; EBX = Starting position

	mov	ecx,[si+gusChannel.send]	; Set sample end

	regsel	4				; End position high
	inc	dx
	mov	eax,ecx
	shr	eax,7
	out	dx,ax
	regsel	5				; End position low
	inc	dx
	mov	eax,ecx
	shl	ax,9
	out	dx,ax

	mov	ecx,[si+gusChannel.sstart]	; Set loop start

	regsel	2				; Start position high
	inc	dx
	mov	eax,ecx
	shr	eax,7
	out	dx,ax
	regsel	3				; Start position low
	inc	dx
	mov	eax,ecx
	shl	ax,9
	out	dx,ax

	regsel	10				; Current position high
	inc	dx
	mov	eax,ebx
	shr	eax,7
	out	dx,ax
	regsel	11				; Current position low
	inc	dx
	mov	eax,ecx
	shl	ax,9
	out	dx,ax

	regsel	0				; Voice control
	mov	al,[si+gusChannel.looped]	; Enable voice and possible loop
	add	dx,2
	out	dx,al

	call	gusdelay			; Delay

	out	dx,al

	regsel	10				; Current position high
	inc	dx
	mov	eax,ebx
	shr	eax,7
	out	dx,ax
	regsel	11				; Current position low
	inc	dx
	mov	eax,ecx
	shl	ax,9
	out	dx,ax


	and	[si+gusChannel.status],NOT 16	; Change done
	jmp	@@retrigged


@@stopsound:
	regsel	0				; Voice control
	add	dx,2
	mov	al,3				; Stop voice
	out	dx,al

	regsel	9				; Current volume
	inc	dx
	mov	ax,1200h			; To zero
	out	dx,ax

	regsel	0dh				; Ramp control
	add	dx,2
	mov	al,3				; Stop
	out	dx,al

	call	gusdelay

	out	dx,al

	regsel	0				; Voice control
	add	dx,2
	mov	al,3				; Stop voice
	out	dx,al


	regsel	9				; Current volume
	inc	dx
	mov	ax,1200h			; To zero
	out	dx,ax

@@noALE:
	and	[si+gusChannel.status],NOT 16	; Change done

@@retrigged:
	add	si,size gusChannel		; Do all channels in order
	inc	[chanc]
	mov	ax,[chancount]
	cmp	[surround],0
	je	@@ij
	add	ax,ax				; Plus Surround channels
@@ij:
	cmp	[chanc],ax
	jb	@@loop

	mov	[masterchanged],0

	les	bx,[callMP]
	mov	[word es:bx],1			; Call mp.Play!
@@done: xor	ax,ax
	ret

@@paused:
	les	bx,[callMP]
	mov	[word es:bx],0			; Don't call mp.Play!
	jmp	@@done
ENDP

PROC	gusdelay NEAR
	push	dx ax
	mov	dx,300h
	rept	8
	in	al,dx
	endm
	pop	ax dx
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	int initHeap()
;*
;* Description: Initializes the GUS heap
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/


PROC	initHeap NEAR
USES	di

	mov	ax,MAXINSTS * SIZE ghb
	cmp	[surround],0
	je	@@kool

	add	ax,ax				; Room for surround
						; blocks, too

@@kool:
	push	ax
	call	memAlloc LANG, ax, seg temp offset temp
						; Alloc room for heap blocks

	pop	cx				; Size to CX
	test	ax,ax
	jne	@@err

	mov	ebx,[temp]
	mov	[gusHeapStart],ebx
	mov	[gusHeap],ebx

	les	di,[temp]
	xor	eax,eax
						; Size already in CX
	cld
	rep	stosb				; Clear instrument datas

	les	bx,[temp]
	mov	eax,[memamount]
	mov	[es:bx+ghb.next],0		; First block
	mov	[es:bx+ghb.gusmem],0		; From start of GUS mem
	mov	[es:bx+ghb.length],eax		; Whole GUS memory
	xor	ax,ax
	ret

@@err:	ERROR	ID_gusInitHeap
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int freeHeap()
;*
;* Description: Uninitializes the GUS heap
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/


PROC	freeHeap NEAR
	call	memFree LANG, [gusHeap]
	test	ax,ax
	jnz	@@err
	xor	ax,ax
	ret

@@err:	ERROR	ID_gusFreeHeap
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int gusMalloc(ushort length, ulong *mem)
;*
;* Description: Allocates GUS memory (with best fit alcorithm)
;*
;* Input:	ushort length		Length of the block to be allocated (Rounded up to next 32 bytes)
;*
;* Returns:	MIDAS error code.
;*
;\***************************************************************************/
PROC	gusMalloc FAR	length:word, mem:far ptr
USES	si,di
LOCAL	bestfitoff:word, bestfitseg:word, leastslack:dword

	movzx	eax,[length]
	test	eax,eax
	jz	@@done

	mov	ebx,eax 			; Round up to next 64 byte border (possible 32 bytes extra)
	and	ebx,1fh
	mov	ecx,64
	sub	ecx,ebx
	add	eax,ecx

	mov	[bestfitseg],0
	mov	[leastslack],7ffffffh

	cmp	[memavail],eax			; Is there that much memory left
	jl	@@notenoughmem

	cmp	[largestblock],eax		; Do we have to defragment?
	jg	@@noneedtodefragment

	push	eax
	call	gusDefragment
	pop	eax

	cmp	[largestblock],eax
	jl	@@notenoughmem

@@noneedtodefragment:
	les	si,[gusHeapStart]

@@findbest:
	push	eax
	call	findFreeBlock
	pop	eax
	jc	@@notanymore

	mov	ebx,[es:si+ghb.length]
	and	ebx, NOT 1fh			; And flags off
	sub	ebx,eax
	js	@@nxt				; Too small

	cmp	[leastslack],ebx
	jl	@@nxt				; Not the best

	mov	[leastslack],ebx		; Set to be the best
	mov	bx,es
	mov	[bestfitseg],bx
	mov	[bestfitoff],si

@@nxt:
	mov	ecx,[es:si+ghb.next]		; Advance to next block
	test	ecx,ecx
	jz	@@notanymore
	mov	si,cx
	shr	ecx,16
	mov	es,cx
	jmp	@@findbest

@@notanymore:
	cmp	[bestfitseg],0			; Was there any free blocks big enough?
	je	@@notenoughmem
	cmp	[leastslack],0
	je	@@justalloc

	push	eax
	call	allocBlock LANG, seg temp offset temp ; Allocate new block
	test	ax,ax
	jnz	@@memerr

	pop	eax
	lgs	di,[temp]

	mov	si,[bestfitoff]
	mov	bx,[bestfitseg]
	mov	es,bx

	mov	ebx,[es:si+ghb.gusmem]		; Copy pointer
	mov	[gs:di+ghb.gusmem],ebx
	mov	[gs:di+ghb.length],eax		; Set block length
	or	[gs:di+ghb.length],1		; Mark as allocated

	add	[es:si+ghb.gusmem],eax		; Move free block "upwards"
	sub	[es:si+ghb.length],eax		; Sub free block length

	mov	bx,es
	shl	ebx,16
	mov	bx,si

	mov	[gs:di+ghb.next],ebx		; Link blocks
	cmp	[gusHeapStart],ebx
	jne	@@notfirst			; The first block?

	mov	bx,gs				; Set this block to HeapStart
	shl	ebx,16
	mov	bx,di
	mov	[gusHeapStart],ebx
	jmp	@@donee

@@notfirst:
	push	eax
	mov	eax,ebx
	call	findPrevBlock			; Find block linked to the free block
	pop	eax
	jc	@@heapcorr			; No such block!

	mov	bx,gs
	shl	ebx,16
	mov	bx,di
	mov	[es:si+ghb.next],ebx		; Link to previous block


@@donee:
	sub	[memavail],eax
	push	gs
	call	checkCoreFree			; Update biggest block
	pop	gs
	test	ax,ax
	jnz	@@err
	mov	eax,[gs:di+ghb.gusmem]		; Return pointer
	les	bx,[mem]
	mov	[es:bx],eax
	xor	ax,ax
	ret

@@justalloc:					; Realloc?
	or	[es:si+ghb.length],1
	sub	[memavail],eax
	push	es
	call	checkCoreFree
	pop	es
	test	ax,ax
	jnz	@@err
	mov	eax,[es:si+ghb.gusmem]
@@done: les	bx,[mem]
	mov	[es:bx],eax
	xor	ax,ax
	ret

@@memerr:
	pop	ebx				; pop saved pointer
	jmp	@@err

@@heapcorr:
	mov	ax,errCardHeapCorrupted
	jmp	@@err

@@notenoughmem:
	mov	ax,errOutOfCardMemory
@@err:	ERROR	ID_gusMalloc
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	int gusFree(ulong mem)
;*
;* Description: Deallocates GUS memory
;*
;* Input:	ulong block		Pointer to allocated GUS mem
;*
;* Returns:	1 if success, 0 if not
;*
;* Destroys:	ax, bx, cx, dx
;*
;\***************************************************************************/
PROC	gusFree FAR   block:dword
USES	si,di
LOCAL	freed:dword

	mov	eax,[block]

	lgs	di,[gusHeapStart]
@@sloop:
	cmp	[gs:di+ghb.gusmem],eax
	je	@@found

	mov	ebx,[gs:di+ghb.next]
	test	ebx,ebx
	jz	@@invalid
	mov	di,bx
	shr	ebx,16
	mov	gs,bx
	jmp	@@sloop

@@found:
	test	[gs:di+ghb.length],1
	jz	@@heapcorr			; Not even allocated

	and	[gs:di+ghb.length],NOT 1	; Free this block

	mov	ebx,[gs:di+ghb.length]
	mov	[freed],ebx

	mov	ebx,[gs:di+ghb.next]
	test	ebx,ebx
	jz	@@nonextblock			; Last block

	mov	si,bx
	shr	ebx,16
	mov	es,bx

	test	[es:si+ghb.length],1
	jnz	@@nonextblock			; Next allocated -> Can't merge blocks

	mov	edx,[es:si+ghb.next]
	mov	[gs:di+ghb.next],edx
	mov	edx,[es:si+ghb.length]		; Merge blocks
	add	[gs:di+ghb.length],edx

	push	gs
	call	freeBlock LANG, es si		; Free block
	pop	gs
	test	ax,ax
	jnz	@@err

@@nonextblock:
	mov	bx,gs
	shl	ebx,16
	mov	bx,di
	cmp	[gusHeapStart],ebx
	je	@@firstblock			; First block

	mov	eax,ebx
	call	findPrevBlock
	jc	@@heapcorr			; No such block! (Heap corrupt?)

	test	[es:si+ghb.length],1
	jnz	@@firstblock			; previous allocated -> can't merge blocks

	mov	edx,[gs:di+ghb.next]
	mov	[es:si+ghb.next],edx
	mov	edx,[gs:di+ghb.length]		; Merge blocks
	add	[es:si+ghb.length],edx

	call	freeBlock LANG, gs di		; Free block
	test	ax,ax
	jnz	@@err

@@firstblock:
	mov	eax,[freed]
	add	[memavail],eax
	call	checkCoreFree
	test	ax,ax
	jnz	@@err
	xor	ax,ax
	ret

@@heapcorr:
	mov	ax,errCardHeapCorrupted
	jmp	@@err

@@invalid:
	mov	ax,errInvalidBlock
@@err:	ERROR	ID_gusFree
	ret
ENDP


PROC	allocBlock NEAR block:far ptr
	les	bx,[gusHeapStart]
	mov	cx,MAXINSTS
	cmp	[surround],0
	je	@@findloop
	add	cx,cx				; Include surround blocks
@@findloop:
	cmp	[es:bx+ghb.length],0
	je	@@found
	add	bx,size ghb
	loop	@@findloop
	jmp	@@err
@@found:
	mov	ax,es
	shl	eax,16
	mov	ax,bx
	les	bx,[block]
	mov	[es:bx],eax
	xor	ax,ax
	ret

@@err:	mov	ax,errInvalidBlock
	ERROR	ID_gusAllocBlock
	ret
ENDP

PROC	freeBlock NEAR block:far ptr
	les	bx,[block]
	mov	[es:bx+ghb.next],0
	mov	[es:bx+ghb.gusmem],0
	mov	[es:bx+ghb.length],0
	xor	ax,ax
	ret
ENDP

; es:si = far ptr to current block
; Returns: es:si = next free block
; Carry set if not found

PROC	findFreeBlock NEAR

@@sloop:
	test	[es:si+ghb.length],1
	jz	@@found

	mov	eax,[es:si+ghb.next]   ; Advance to next block
	test	eax,eax
	jz	@@nofree
	mov	si,ax
	shr	eax,16
	mov	es,ax
	jmp	@@sloop

@@found:
	clc
	ret
@@nofree:
	stc
	ret
ENDP



; eax = far ptr to current block
; Returns: es:si = prev block
; Carry set if not found

PROC	findPrevBlock NEAR

	les	si,[gusHeapStart]
@@sloop:
	cmp	[es:si+ghb.next],eax
	je	@@found

	mov	ebx,[es:si+ghb.next]
	test	ebx,ebx
	jz	@@done
	mov	si,bx
	shr	ebx,16
	mov	es,bx
	jmp	@@sloop

@@found:
	clc
	ret
@@done:
	stc
	ret
ENDP



; No parameters, also checks heap integrity
; Returns MIDAS error code

PROC	checkCoreFree	NEAR
USES	si

	les	si,[gusHeapStart]
	xor	edx,edx 			; Start from size 0
	xor	ecx,ecx 			; Total mem size
@@findloop:
	mov	eax,[es:si+ghb.length]
	mov	ebx,eax
	and	ebx,NOT 31			; ebx = size
	add	ecx,ebx 			; Add to total
	test	eax,1				; Allocated flag
	jnz	@@findnext			; Allocated
	cmp	ebx,edx 			; Largest?
	jle	@@findnext
	mov	edx,ebx
@@findnext:
	mov	eax,[es:si+ghb.next]   ; Advance to next block
	test	eax,eax
	jz	@@done
	mov	si,ax
	shr	eax,16
	mov	es,ax
	jmp	@@findloop

@@done:
	mov	[largestblock],edx
	cmp	[memamount],ecx 		; All memory in heap?
	jne	@@heapcorr			; heap corrupt!
	xor	ax,ax
	ret

@@heapcorr:
	mov	ax,errCardHeapCorrupted
	ERROR	ID_gusCoreFree
	ret
ENDP

;/***************************************************************************\
;*
;* Function:	gusDefragment
;*
;* Description: Defragments the GUS memory
;*
;* Destroys:	ax, bx, cx, dx
;*
;\***************************************************************************/
PROC	gusDefragment FAR   length:word
	ret
ENDP

END

