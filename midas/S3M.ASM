;*	S3M.ASM
;*
;* Scream Tracker 3 Module Player, v1.13
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

; DEBUGGER = 1

INCLUDE "lang.inc"
INCLUDE "errors.inc"
INCLUDE "mglobals.inc"
INCLUDE "s3m.inc"
INCLUDE "mplayer.inc"
INCLUDE "sdevice.inc"
INCLUDE "ems.inc"
INCLUDE "timer.inc"



DATASEG



module		DD	?		; pointer to module structure
sdevice 	DD	?		; pointer to current Sound Device

playCount	DB	?		; player speed counter
speed		DB	?		; playing speed, default is 6
tempo		DB	?		; playing BPM tempo
masterVolume	DB	?		; master volume (0-64)
loopStart	DW	?		; song loop start position
loopEnd 	DW	?		; song loop end position
flags		DW	?		; module flags
upperLimit	DW	?		; upper period value limit
lowerLimit	DW	?		; lower period value limit

position	DW	?		; position in song
row		DW	?		; row in pattern
playOffset	DW	?		; offset to next pattern data in
					; current pattern
songLength	DW	?		; song length (number of positions)
maxinst 	DW	?		; maximum inst number
numChans	DW	?		; number of channels
firstSDChan	DW	?		; first Sound Device channel used
chan		DW	?		; current channel number
sdChan		DW	?		; current Sound Device channel number

oldOffset	DW	?		; old pattern data offset

loopRow 	DW	?		; pattern loop row
loopOffset	DW	?		; pattern loop position
loopFlag	DB	?		; pattern loop flag
loopCount	DB	?		; pattern loop counter
delayCount	DB	?		; pattern delay counter
delayFlag	DB	?		; pattern delay flag
skipFlag	DB	?		; row skip flag
pbFlag		DB	?		; pattern break flag

loopCnt 	DB	?		; song loop counter

setFrame	DW	?		; "set frame" flag - 1 if song data
					; is played, 0 if not
rows		DW	?		; saved row number for GetInformation
poss		DW	?		; saved position
pats		DW	?		; saved pattern number

s3mMemPtr	DD	?		; temporary memory pointer used by
					; some functions


channels	s3mChannel MPCHANNELS DUP (?)	; channel structures



IDATASEG


;/***************************************************************************\
;*     Scream Tracker 3 Module Player structure:
;\***************************************************************************/

mpS3M	ModulePlayer  < \
	mpUnInitialized, \
	5000, \
	far ptr s3mIdentify, \
	far ptr s3mInit, \
	far ptr s3mClose, \
	far ptr s3mLoadModule, \
	far ptr s3mFreeModule, \
	far ptr s3mPlayModule, \
	far ptr s3mStopModule, \
	far ptr s3mSetInterrupt, \
	far ptr s3mRemoveInterrupt, \
	far ptr s3mPlay, \
	far ptr s3mSetPosition, \
	far ptr s3mGetInformation,\
	far ptr s3mSetMasterVolume >


	; sine table for vibrato:
vibratoTable	DB	0,24,49,74,97,120,141,161
		DB	180,197,212,224,235,244,250,253
		DB	255,253,250,244,235,224,212,197
		DB	180,161,141,120,97,74,49,24

	; volume fade tables for Retrig Note:
retrigTable1	DB	0,-1,-2,-4,-8,-16,0,0
		DB	0,1,2,4,8,16,0,0

retrigTable2	DB	0,0,0,0,0,0,10,8
		DB	0,0,0,0,0,0,24,32


	; period table for one octave:
Periods 	DW	1712,1616,1524,1440,1356,1280,1208,1140,1076,1016
		DW	0960,0907


LABEL	cmdNames	DWORD
	DD	far ptr strNoCmd
	DD	far ptr strSetSpeed
	DD	far ptr strPosJump
	DD	far ptr strPattBreak
	DD	far ptr strVolSlide
	DD	far ptr strSlideDown
	DD	far ptr strSlideUp
	DD	far ptr strTonePort
	DD	far ptr strVibrato
	DD	far ptr strTremor
	DD	far ptr strArpeggio
	DD	far ptr strVibVSlide
	DD	far ptr strTPortVSlide
	DD	far ptr strNoCmd
	DD	far ptr strNoCmd
	DD	far ptr strSampleOffs
	DD	far ptr strNoCmd
	DD	far ptr strRetrigNote
	DD	far ptr strTremolo
	DD	far ptr strSpecial
	DD	far ptr strSetTempo
	DD	far ptr strNoCmd
	DD	far ptr strMasterVol
	DD	far ptr strNoCmd
	DD	far ptr strSetPanning
	DD	far ptr strNoCmd
	DD	far ptr strNoCmd

LABEL	scmdNames	DWORD
	DD	far ptr strSetFilter
	DD	far ptr strGlissCtrl
	DD	far ptr strSetFinetune
	DD	far ptr strVibWform
	DD	far ptr strTremWform
	DD	far ptr strNoCmd
	DD	far ptr strNoCmd
	DD	far ptr strNoCmd
	DD	far ptr strSetPanning
	DD	far ptr strNoCmd
	DD	far ptr strStereoCtrl
	DD	far ptr strPattLoop
	DD	far ptr strNoteCut
	DD	far ptr strNoteDelay
	DD	far ptr strPattDelay
	DD	far ptr strFunkRepeat


strNoCmd	DB	0
	;		1234567890A
strSlideUp	DB	"Slide Up",0
strSlideDown	DB	"Slide Down",0
strTonePort	DB	"Tone Porta",0
strVibrato	DB	"Vibrato",0
strTPortVSlide	DB	"TPrt+VolSld",0
strVibVSlide	DB	"Vib+VolSld",0
strTremor	DB	"Tremor",0
strSampleOffs	DB	"Sample Offs",0
strArpeggio	DB	"Arpeggio",0
strVolSlide	DB	"VolumeSlide",0
strPosJump	DB	"Pos. Jump",0
strPattBreak	DB	"Patt. Break",0
strSetSpeed	DB	"Set Speed",0
srtSetVolume	DB	"Set Volume",0
strRetrigNote	DB	"Retrig Note",0
strTremolo	DB	"Tremolo",0
strSpecial	DB	"Special Cmd",0
strSetTempo	DB	"Set Tempo",0
strMasterVol	DB	"Mast.Volume",0

		;	01234567890A
strSetFilter	DB	"Set Filter",0
strGlissCtrl	DB	"Gliss. Ctrl",0
strSetFinetune	DB	"SetFinetune",0
strVibWform	DB	"Vib.Wavefrm",0
strTremWform	DB	"Tre.Wavefrm",0
strSetPanning	DB	"Set Panning",0
strStereoCtrl	DB	"StereoCtrl",0
strPattLoop	DB	"Patt.Loop",0
strNoteCut	DB	"Note Cut",0
strNoteDelay	DB	"Note Delay",0
strPattDelay	DB	"Patt. Delay",0
strFunkRepeat	DB	"FunkRepeat",0




CODESEG


;/***************************************************************************\
;*
;* Function:	int s3mIdentify(uchar *header, int *recognized);
;*
;* Description: Checks if the header is a Scream Tracker 3 module header
;*
;* Input:	uchar *headeer		pointer to header, length MPHDRSIZE
;*		int *recognized 	pointer to result variable
;*
;* Returns:	MIDAS error code.
;*		*recognized set to 1 if header is a Scream Tracker 3 module
;*		header, 0 if not
;*
;\***************************************************************************/

PROC	s3mIdentify	FAR	header : dword, recognized : dword

	les	bx,[header]		; point es:bx to header
	xor	ax,ax
	cmp	[dword es:bx+s3mHeader.SCRM],"MRCS"     ; is SCRM field in
	je	@@iss3m 				; header "SCRM?"
	xor	ax,ax			; no - not an S3M
	jmp	@@detd

@@iss3m:
	mov	ax,1			; yes - module is a S3M

@@detd:
	les	bx,[recognized] 	; point es:bx to result
	mov	[es:bx],ax		; set *recognized to identification
					; result
	xor	ax,ax
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	int s3mInit(SoundDevice *SD);
;*
;* Description: Initializes Scream Tracker 3 Module Player
;*
;* Input:	SoundDevice *SD 	pointer to Sound Device to be used
;*					for playing
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	s3mInit 	FAR	SDev : dword

	mov	eax,[SDev]		; store Sound Device pointer in
	mov	[sdevice],eax		; sdevice

	mov	[mpS3M.status],mpInitialized	; Module Player is initialized

	xor	ax,ax			; success

	ret
ENDP




;/***************************************************************************\
;*
;* Function:	int s3mClose(void);
;*
;* Description: Uninitializes the Scream Tracker 3 Module Player
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	s3mClose FAR

	mov	[mpS3M.status],mpUnInitialized

	xor	ax,ax			; success
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	 int s3mDetectChannels(mpModule *s3m, ushort *numChns);
;*
;* Description:  Detects the number of channels in a Scream Tracker 3 module
;*
;* Input:	 mpModule *s3m		 pointer to module structure
;*		 ushort *numChns	 pointer to channel number variable
;*
;* Returns:	 MIDAS error code.
;*		 Number of channels in module stored in *numChns.
;*
;\***************************************************************************/

PROC	s3mDetectChannels	FAR	s3m : dword, numChns : dword
USES	si, di
LOCAL	numPatts : word, PpattPtr : dword, pattNum : word, maxChan : word

	les	si,[s3m]		; point es:si to module structure

	mov	ax,[es:si+mpModule.numPatts]	; store number of patterns
	mov	[numPatts],ax

	mov	eax,[es:si+mpModule.patterns]	; store pattern pointer
	mov	[PpattPtr],eax			; pointer

	mov	[pattNum],0
	mov	[maxChan],0		; maximum channel used = 0

@@pattloop:
	les	si,[s3m]		; point es:si to module structure

	lgs	di,[es:si+mpModule.pattEMS]	; point gs:di to pattern EMS
	mov	bx,[pattNum]			; flags
	cmp	[byte gs:di+bx],0		; is pattern in EMS?
	lgs	di,[PpattPtr]			; point gs:di to pattern ptr
	je	@@noEMS

	cmp	[dword gs:di],0
	je	@@nextptrn

	; map pattern to conventional memory:
	call	emsMap LANG, [dword gs:di], seg s3mMemPtr offset s3mMemPtr
	test	ax,ax
	jnz	@@err

	les	si,[s3mMemPtr]		; point es:si to conventional memory
	jmp	@@dataok		; block

@@noEMS:
	cmp	[dword gs:di],0
	je	@@nextptrn
	les	si,[gs:di]		; no EMS - point es:si to pattern

@@dataok:
	add	si,2			; skip pattern length
	mov	cx,64			; cx = row counter

@@rowloop:
	mov	al,[es:si]		; read row flag byte
	inc	si
	test	al,al			; zero?
	jz	@@nextrow		; if is, move to next row

	mov	bl,al
	and	bx,01Fh 		; bx = channel number

	test	al,32			; is bit 5 of flag byte 1?
	jz	@@nonote		; if not, there is no note/instrument

	cmp	[byte es:si],255
	je	@@noted 		; skip empty or release notes
	cmp	[byte es:si],254
	je	@@noted

	cmp	[byte es:si+1],255	; skip empty instruments
	je	@@noted

	cmp	[maxChan],bx		; Channel is used. If channel number
	jae	@@noted 		; > maximum channel number used,
	mov	[maxChan],bx		; set maximum channel number

@@noted:
	add	si,2			; note and instrument processed


@@nonote:
	test	al,64			; if bit 6 is 1, there is a volume
	jz	@@novol 		; field
	inc	si			; skip volume


@@novol:
	test	al,128			; if bit 7 is 1, there is a command
	jz	@@rowloop		; field

	cmp	[byte es:si],1		; skip empty commands
	jb	@@cmddone
	cmp	[byte es:si],'Z'-'@'    ; skip invalid commands
	ja	@@cmddone

	cmp	[maxChan],bx		; Channel is used. If channel number
	jae	@@cmddone		; > maximum channel number used,
	mov	[maxChan],bx		; set maximum channel number

@@cmddone:
	add	si,2			; command and infobyte processed
	jmp	@@rowloop		; next flag byte

@@nextrow:
	loop	@@rowloop		; go to next row


@@nextptrn:
	add	[word PpattPtr],4	; pointer to next pattern pointer
	inc	[pattNum]		; next pattern
	mov	ax,[pattNum]
	cmp	ax,[numPatts]		; are there more patterns?
	jb	@@pattloop


	les	si,[s3m]		; point es:si to module structure

	xor	bx,bx			; channel number = 0
	mov	cx,MPCHANNELS		; search all channels
	xor	dx,dx			; max channel number = 0

	; now find the maximum channel number which has data and is used
	; according to the mpModule channel settings table:

@@cloop:
	cmp	[maxChan],bx		; is channel number too big?
	jb	@@cdone

	; this channel has data - now check if it is turned on:
	cmp	[es:si+bx+mpModule.chanSettings],0
	jz	@@notused

	mov	dx,bx			; channel has data and is turned on

@@notused:
	inc	bx			; next channel
	loop	@@cloop

@@cdone:
	; dx contains the actual number of channels
	les	bx,[numChns]		; store number of channels in
	inc	dx			; *numChns
	mov	[es:bx],dx

	xor	ax,ax			; success
	jmp	@@done

@@err:
	ERROR	ID_s3mDetectChannels

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	 int s3mFindUsedInsts(mpModule *s3m, ushort *used);
;*
;* Description:  Detects used instruments in a Scream Tracker 3 module
;*
;* Input:	 mpModule *s3m		 pointer to module structure
;*		 uchar	  *used 	 pointer to sample array
;*
;* Returns:	 MIDAS error code.
;*
;\***************************************************************************/

PROC	s3mFindUsedInsts	FAR	s3m : dword, used : dword
USES	si, di
LOCAL	numPatts : word, PpattPtr : dword, pattNum : word, maxi : word

	les	si,[s3m]		; point es:si to module structure

	mov	ax,[es:si+mpModule.numPatts]	; store number of patterns
	mov	[numPatts],ax
	mov	ax,[es:si+mpModule.numInsts]
	mov	[maxi],ax

	mov	cx,ax				; Clear array (mark unused)
	xor	al,al
	push	es
	les	di,[used]
	rep	stosb
	pop	es

	mov	eax,[es:si+mpModule.patterns]	; store pattern pointer
	mov	[PpattPtr],eax			; pointer

	mov	[pattNum],0

@@pattloop:
	les	si,[s3m]		; point es:si to module structure

	lgs	di,[es:si+mpModule.pattEMS]	; point gs:di to pattern EMS
	mov	bx,[pattNum]			; flags
	cmp	[byte gs:di+bx],0		; is pattern in EMS?
	lgs	di,[PpattPtr]			; point gs:di to pattern ptr
	je	@@noEMS

	; map pattern to conventional memory:
	cmp	[dword gs:di],0
	je	@@nextptrn

	call	emsMap LANG, [dword gs:di], seg s3mMemPtr offset s3mMemPtr
	test	ax,ax
	jnz	@@err

	les	si,[s3mMemPtr]		; point es:si to conventional memory
	jmp	@@dataok		; block

@@noEMS:
	cmp	[dword gs:di],0
	je	@@nextptrn
	les	si,[gs:di]		; no EMS - point es:si to pattern

@@dataok:
	add	si,2			; skip pattern length
	mov	cx,64			; cx = row counter
	lgs	di,[used]

@@rowloop:
	mov	al,[es:si]		; read row flag byte
	inc	si
	test	al,al			; zero?
	jz	@@nextrow		; if is, move to next row

	mov	bl,al
	and	bx,01Fh 		; bx = channel number

	test	al,32			; is bit 5 of flag byte 1?
	jz	@@nonote		; if not, there is no note/instrument

	movzx	bx,[es:si+1]
	test	bl,80h
	jnz	@@empty
	test	bl,bl
	jz	@@empty

	cmp	bx,[maxi]
	ja	@@empty 		; Insane instrument

	dec	bx
	mov	[byte gs:di+bx],1	; Mark used
@@empty:
	add	si,2			; note and instrument processed

@@nonote:
	test	al,64			; if bit 6 is 1, there is a volume
	jz	@@novol 		; field
	inc	si			; skip volume

@@novol:
	test	al,128			; if bit 7 is 1, there is a command
	jz	@@rowloop		; field
	add	si,2			; command and infobyte processed
	jmp	@@rowloop		; next flag byte

@@nextrow:
	loop	@@rowloop		; go to next row

@@nextptrn:
	add	[word PpattPtr],4	; pointer to next pattern pointer
	inc	[pattNum]		; next pattern
	mov	ax,[pattNum]
	cmp	ax,[numPatts]		; are there more patterns?
	jb	@@pattloop
	xor	ax,ax
	jmp	@@quit

@@err:	ERROR	ID_s3mFindUsedInsts
@@quit: ret
ENDP

;/***************************************************************************\
;*
;* Function:	int s3mPlayModule(mpModule *module, ushort firstSDChannel,
;*		    ushort numChannels, ushort loopStart, ushort loopEnd);
;*
;*
;* Description: Starts playing a module
;*
;* Input:	mpModule *module	pointer to the module to be played
;*		ushort firstSDChannel	first Sound Device channel to use
;*		ushort numChannels	number of channels
;*		ushort loopStart	song loop start (0 = beginning)
;*		ushort loopEnd		song loop end (use 65535 for whole
;*					song if length is unknown)
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	s3mPlayModule	FAR	ms3m : dword, firstSDChannel : word, \
				numChannels : word, lpStart : word, \
				lpEnd : word
USES	si, di

	mov	eax,[ms3m]		; store module pointer in module
	mov	[module],eax
	les	si,[module]		; point es:si to module structure

	mov	ax,[es:si+mpModule.numInsts]	; get amount of insts from module
	mov	[maxinst],ax			; and store it

	mov	ax,[es:si+mpModule.songLength]	; get song length from module
	mov	[songLength],ax 		; and store it

	mov	ax,[firstSDChannel]	; store first SD channel number
	mov	[firstSDChan],ax
	mov	ax,[numChannels]	; store number of channels
	mov	[numChans],ax

	mov	al,[es:si+mpModule.speed]	; get module initial speed
	mov	[speed],al		; set speed to initial speed

	mov	ax,[es:si+mpModule.flags]	; store module flags
	mov	[flags],ax

	mov	bx,7FFFh		; bx = lower period limit
	mov	cx,64			; cx = upper period limit

	test	ax,10h			; is "amigalimits"-flag 1?
	jz	@@st3limits

	mov	bx,856*4		; yes, set Amiga period limits
	mov	cx,113*4

@@st3limits:
	mov	[upperLimit],bx 	; store period limits
	mov	[lowerLimit],cx

	movzx	ax,[es:si+mpModule.tempo]	; get initial tempo
	mov	[tempo],al			; set BPM tempo

	lgs	di,[sdevice]
	mov	bx,40
	mul	bx			; BPM*40 = rate in 100*Hz
	mov	[mpS3M.updRate],ax
	push	es gs			; set Sound Device update rate:
	call	[gs:di+SoundDevice.SetUpdRate] LANG, ax
	pop	gs es
	test	ax,ax
	jnz	@@err

	mov	ax,[es:si+mpModule.songLength]	; store song length
	mov	[songLength],ax

	mov	[chan],0

	; set initial panning values to channels:
@@panloop:
	mov	bx,[chan]
	movsx	ax,[es:si+bx+mpModule.chanSettings]
	add	bx,[firstSDChan]		; bx = Sound Device channel
						; number

	; set Sound Device panning:
	push	es gs
	call	[gs:di+SoundDevice.SetPanning] LANG, bx, ax
	pop	gs es
	test	ax,ax
	jnz	@@err

	inc	[chan]				; next channel
	mov	ax,[chan]
	cmp	ax,[numChans]
	jb	@@panloop


	; initialize player internal variables:
	mov	[playCount],0
	mov	[masterVolume],64
	mov	[playOffset],2		; skip pattern length word
	mov	[row],0
	mov	[loopFlag],0
	mov	[loopCount],0
	mov	[delayFlag],0
	mov	[delayCount],0
	mov	[pbFlag],0
	mov	[loopCnt],0
	mov	[skipFlag],0

	mov	ax,[lpStart]		; get loop start position
	mov	[loopStart],ax		; store loop start position
	mov	[position],ax		; set position to loop start
	mov	ax,[lpEnd]		; get loop end position
	mov	[loopEnd],ax		; store loop end position


	; clear player channel structures to all zeros:
	mov	ax,ds
	mov	es,ax
	mov	di,offset channels
	mov	cx,MPCHANNELS * SIZE s3mChannel
	xor	al,al
	cld
	rep	stosb

	mov	[mpS3M.status],mpPlaying

	xor	ax,ax			; success
	jmp	@@done

@@err:
	ERROR	ID_s3mPlayModule

@@done:
	ret

ENDP




;/***************************************************************************\
;*
;* Function:	int s3mStopModule(void);
;*
;* Description: Stops playing a module
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	s3mStopModule	FAR

	mov	[module],0		; point module to NULL for safety
	mov	[mpS3M.status],mpStopped

	xor	ax,ax			; success
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	int s3mSetInterrupt(void);
;*
;* Description: Starts playing the module using TempoTimer
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	s3mSetInterrupt 	FAR

	; start playing with the TempoTimer:
	call	tmrPlay LANG, seg s3mPlay offset s3mPlay, [sdevice]
	test	ax,ax
	jnz	@@err

	movzx	ax,[tempo]
	mov	bx,40			; BPM * 40 = playing rate in 100*Hz
	mul	bx
	call	tmrSetUpdRate LANG, ax	; set timer update rate
	test	ax,ax
	jnz	@@err

	xor	ax,ax			; success
	jmp	@@done

@@err:
	ERROR	ID_s3mSetInterrupt

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	int s3mRemoveInterrupt(void);
;*
;* Description: Stops playing with the TempoTimer
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	s3mRemoveInterrupt	FAR

	call	tmrStop LANG		; stop playing the module with timer
	test	ax,ax
	jnz	@@err

	xor	ax,ax			; success
	jmp	@@done

@@err:
	ERROR	ID_s3mRemoveInterrupt

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	int s3mPlay(void);
;*
;* Description: Plays one "frame" of the module. Usually called from
;*		the timer.
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	s3mPlay 	FAR
USES	di, si

	inc	[playCount]		; increment player counter
	mov	al,[speed]		; if player counter is equal to the
	cmp	[playCount],al		; speed, it's time to play the song
	jne	@@noplay		; data.

	call	s3mPlaySong		; play one row of the song data
	test	ax,ax
	jnz	@@err
	jmp	@@ok

@@noplay:
	; Song data is not played - just process the continuous commands
	call	s3mRunCommands
	test	ax,ax
	jnz	@@err

@@ok:	xor	ax,ax			; success
	jmp	@@done

@@err:
	ERROR	ID_s3mPlay

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	s3mRunCommands
;*
;* Description: Processes the continuous commands
;*
;* Returns:	MIDAS error code in ax
;*
;\***************************************************************************/

PROC NOLANGUAGE s3mRunCommands	NEAR

	mov	[chan],0		; channel number = 0
	mov	ax,[firstSDChan]	; start from first Sound Device
	mov	[sdChan],ax		; channel

	mov	di,offset channels	; point ds:di to channel structures
	lgs	si,[sdevice]		; point gs:si to Sound Device

@@chanloop:
	test	[di+s3mChannel.flags],128	; is there a command for
	jz	@@nocmd 			; this channel?

	movzx	bx,[di+s3mChannel.cmd]	; bx = command number
	cmp	bx,27			; is command number valid? (<=27)
	ja	@@nocmd

	add	bx,bx			; bx = index to command offset table
	movzx	ax,[di+s3mChannel.preinfo]	; ax = command infobyte
	call	[word contCommands+bx]	; process the command
	test	ax,ax			; error?
	jnz	@@done			; if yes, pass the error code on

@@nocmd:
	add	di,size s3mChannel	; next channel
	inc	[chan]
	inc	[sdChan]

	mov	ax,[chan]
	cmp	ax,[numChans]
	jb	@@chanloop

	call	s3mUpdBars		; update volume bars

@@done:
IFDEF DEBUGGER
	test	ax,ax
	jz	@@retu

	int 3

@@retu:
ENDIF
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	s3mPlaySong
;*
;* Description: Plays one row of song data
;*
;* Returns:	MIDAS error code in ax
;*
;\***************************************************************************/

PROC	s3mPlaySong	NEAR
LOCAL	pattPtr : dword

	mov	[playCount],0		; reset player counter

	cmp	[delayCount],0
	je	@@nodelay

	; pattern delay counter is non-zero. Decrement it and process
	; continuous commands.

	dec	[delayCount]
	call	s3mRunCommands
	; pass possible error code on
	jmp	@@done


@@nodelay:
	mov	[delayFlag],0			; Pattern Delay not active

	; clear flags from all channels:

	mov	di,offset channels
	mov	cx,[numChans]
@@cllp: mov	[di+s3mChannel.flags],0
	add	di,SIZE s3mChannel
	loop	@@cllp

	cmp	[skipFlag],0
	je	@@noskip

	mov	[skipFlag],0
	call	SkipRows
	test	ax,ax
	jne	@@done

@@noskip:
	les	si,[module]		; point es:si to module structure

	mov	bx,[position]
	lgs	di,[es:si+mpModule.orders]	; point gs:di to orders
	movzx	cx,[gs:di+bx]			; cx = current pattern number
	shl	cx,2

	lgs	di,[es:si+mpModule.patterns]	; point gs:di to current
	add	di,cx				; pattern pointer

	push	gs di
	lgs	di,[es:si+mpModule.pattEMS]	; point gs:di pattern EMS
	shr	cx,2				; flags
	mov	bx,cx
	cmp	[byte gs:di+bx],0		; is current pattern in EMS?
	pop	di gs
	je	@@noEMS

	; map pattern data to conventional memory:
	call	emsMap LANG, [dword gs:di], seg s3mMemPtr offset s3mMemPtr
	test	ax,ax
	jnz	@@done

	mov	eax,[s3mMemPtr] 	; store pattern data pointer
	mov	[pattPtr],eax
	jmp	@@dataok

@@noEMS:
	mov	eax,[gs:di]		; store pattern data pointer
	mov	[pattPtr],eax

@@dataok:
	les	si,[pattPtr]		; point es:si to pattern data
	mov	ax,[playOffset] 	; store current playing offset in
	mov	[oldOffset],ax		; oldOffset
	add	si,ax			; point es:si to current row data


@@dataloop:
	mov	al,[es:si]		; al = current channel flag byte
	inc	si
	test	al,al			; is flag byte zero?
	jz	@@rowend		; if is, end of row

	xor	bx,bx
	mov	bl,al
	and	bl,31			; bx = current channel number

	mov	di,offset channels
	imul	bx,bx,size s3mChannel	; point ds:di to current channel
	add	di,bx			; structure

	mov	[di+s3mChannel.flags],al	; store flag byte

	test	al,32			; if bit 5 of flag is 1, there is a
	jz	@@nonote		; note or instrument

	mov	cl,[es:si]			; get note number
	mov	[di+s3mChannel.note],cl 	; and store it
	inc	si
	mov	cl,[es:si]			; get instrument number
	mov	[di+s3mChannel.inst],cl 	; and store it
	inc	si

@@nonote:
	test	al,64			; if bit 6 of flag is 1, there is a
	jz	@@novol 		; volume change byte

	mov	cl,[es:si]		; get volume change byte
	mov	[di+s3mChannel.vol],cl	; and store it
	inc	si

@@novol:
	test	al,128			; if bit 7 of flag 1 is, there is a
	jz	@@nocmd 		; command

	mov	cl,[es:si]		; get command number
	mov	[di+s3mChannel.cmd],cl	; and store it
	inc	si
	mov	cl,[es:si]		; get command infobyte
	mov	[di+s3mChannel.info],cl ; and store it
	inc	si

@@nocmd:
	jmp	@@dataloop		; get next flag byte and datas


@@rowend:
	sub	si,[word pattPtr]	; play offset = si - pattern start
	mov	[playOffset],si 	; offset

	les	si,[module]		; save values for getInformation
	call	s3mSave
	test	ax,ax
	jnz	@@done



	; process possible new values on all channels:

	mov	[chan],0
	mov	ax,[firstSDChan]
	mov	[sdChan],ax

	mov	di,offset channels	; point ds:di to channel structure
	lgs	si,[sdevice]		; point gs:si to Sound Device

@@chanloop:
	test	[di+s3mChannel.flags],32	; if flag bit 5 is 1, there
	jz	@@nonewnote			; is a new note or instrument

	movzx	bx,[di+s3mChannel.inst] 	; ebx = new instrument number
	or	bl,bl
	jz	@@nonewinst
	js	@@nonewinst
	cmp	bx,[maxinst]
	ja	@@nonewinst

	mov	[di+s3mChannel.sample],bl	; store new instrument number

	push	si
	les	si,[module]
	les	si,[es:si+mpModule.insts]	; point es:si to new
	dec	bx				; instrument structure
	imul	bx,bx,SIZE mpInstrument
	add	si,bx

	mov	al,[es:si+mpInstrument.volume]		; al = inst volume
	mov	bx,[es:si+mpInstrument.sdInstHandle]	; bx = inst SD handle
	pop	si

	mov	[di+s3mChannel.volume],al	; set instrument volume
	or	[di+s3mChannel.status],1	; volume changed

	; set instrument to Sound Device:
	push	gs
	call	[gs:si+SoundDevice.SetInstrument] LANG, [sdChan], bx
	pop	gs
	test	ax,ax
	jnz	@@done

	cmp	[masterVolume],64		; is master volume != 64?
	je	@@nonewinst

	call	SetVolume
	test	ax,ax
	jnz	@@done


@@nonewinst:
	mov	bl,[di+s3mChannel.note] 	; bl = new note number
	cmp	bl,255				; is note empty note?
	je	@@nonewnote

	mov	[di+s3mChannel.snote],bl	; save new note number

	cmp	bl,254				; is note key off?
	je	@@keyoff

	test	[di+s3mChannel.flags],128	; is there a command?
	jz	@@nondelay
	cmp	[di+s3mChannel.cmd],"S"-"@"     ; is command S-command?
	jne	@@nondelay
	mov	al,[di+s3mChannel.info]
	and	al,0F0h 			; is command Note Delay?
	cmp	al,0D0h
	je	@@nonewnote			; if is, do not set note


@@nondelay:
	mov	cl,bl				; cl = new note octave
	shr	cl,4

	; Calculate sampling rate that corresponds to new note. A crazy
	; method, but this is what the Scream Tracker 3 documentation
	; says:

;			  8363 * 16 * ( period(NOTE) >> octave(NOTE) )
;	 note_st3period = --------------------------------------------
;			  middle_c_finetunevalue(INSTRUMENT)
;
;	 note_amigaperiod = note_st3period / 4
;
;	 note_herz=14317056 / note_st3period


	and	bx,0Fh
	add	bx,bx
	movzx	eax,[Periods+bx]		; eax = new note period
	imul	eax,eax,8363*16 		; eax = 8363 * 16 * period
	shr	eax,cl				;	/ 2^oct

	movzx	bx,[di+s3mChannel.sample]
	test	bx,bx
	jz	@@nonewnote

	push	si
	les	si,[module]
	les	si,[es:si+mpModule.insts]
	dec	bx				; point es:si to current
	imul	bx,bx,SIZE mpInstrument 	; instrument structure
	add	si,bx

	mov	ebx,[es:si+mpInstrument.c2Rate] ; ebx = instrument C4 sampling
	pop	si				; rate

	test	ebx,ebx 			; is c2Rate zero?
	jz	@@nonewnote
	cdq					; eax = period = 8366 * 16
	idiv	ebx				;   * period / 2^oct / c2Rate

	test	[di+s3mChannel.flags],128	; is there a command?
	jz	@@ncd
	cmp	[di+s3mChannel.cmd],7		; is command a Tone Portamento
	je	@@tport
	cmp	[di+s3mChannel.cmd],12		; or Tone Portamento + VSlide?
	je	@@tport

@@ncd:	mov	[di+s3mChannel.vibpos],0	; clear vibrato position
	or	[di+s3mChannel.status],3	; note has been played

	mov	bl,[di+s3mChannel.cmd]		; bl = command

	cmp	bl,"I"-"@"                      ; is current command tremor?
	je	@@notremor

	mov	[di+s3mChannel.trefl],0 	; no - clear tremor flag
	mov	[di+s3mChannel.trecnt],0	; and tremor counter

@@notremor:
	cmp	bl,"Q"-"@"                      ; is current command retrig?
	je	@@noretrig

	mov	[di+s3mChannel.retrigc],0	; no - clear retrig counter


@@noretrig:
	mov	[di+s3mChannel.period],ax	; store current period number

	mov	ebx,eax 			; ebx = period
	test	ebx,ebx 			; do not set note if period
	jz	@@nonewnote			; is zero

	mov	eax,14317056
	cdq				; ebx = note sampling rate in Hz
	idiv	ebx
	mov	ebx,eax

	test	[di+s3mChannel.flags],128	; is there a command?
	jz	@@nosoffs
	cmp	[di+s3mChannel.cmd],"O"-"@"     ; is command Sample Offset?
	je	@@smpoffset

@@nosoffs:
	; start playing current note with Sound Device:
	push	gs
	call	[gs:si+SoundDevice.PlaySound] LANG, [sdChan], ebx
	pop	gs
	test	ax,ax
	jnz	@@done
	jmp	@@notedone


@@smpoffset:
	; current command is Sample offset. Set the sampling rate:
	push	gs
	call	[gs:si+SoundDevice.SetRate] LANG, [sdChan], ebx
	pop	gs
	test	ax,ax
	jnz	@@done

	xor	bl,bl
	mov	bh,[di+s3mChannel.info] 	; bx = sample offset position
	test	bh,bh				; is infobyte zero?
	jnz	@@sozero
	mov	bh,[di+s3mChannel.preinfo]	; use previous infobyte

@@sozero:
	; set playing position:
	push	gs
	call	[gs:si+SoundDevice.SetPosition] LANG, [sdChan], bx
	pop	gs
	test	ax,ax
	jnz	@@done
	jmp	@@notedone


@@tport:
	; current command is Tone Portamento - store period as Tone Portamento
	; destination:
	mov	[di+s3mChannel.toperi],ax
	jmp	@@nonewnote


@@keyoff:
	; note is key off - stop playing sound:
	push	gs
	call	[gs:si+SoundDevice.StopSound] LANG, [sdChan]
	pop	gs

@@nonewnote:
	test	[di+s3mChannel.flags],128	; is there a command?
	jz	@@resper
	cmp	[di+s3mChannel.cmd],'H'-'@'     ; is command vibrato?
	je	@@perdone

@@resper:
	; no new note - reset channel period:
	call	SetPeriod
	test	ax,ax
	jnz	@@done

@@perdone:
	test	[di+s3mChannel.flags],128	; is there a command?
	jz	@@resvol
	mov	bl,[di+s3mChannel.cmd]
	cmp	bl,"I"-"@"                      ; is command tremor
	je	@@notedone
	cmp	bl,"R"-"@"                      ; or tremolo?
	je	@@notedone

@@resvol:
	; command not tremor or tremolo - reset volume:
	call	SetVolume

@@notedone:
	test	[di+s3mChannel.flags],64	; if flag bit 6 is 1, there is
	jz	@@nosetvolume			; a volume byte:

	mov	al,[di+s3mChannel.vol]		; al = new volume
	cmp	al,64
	jb	@@volok 			; make sure volume is < 64
	mov	al,63
@@volok:
	mov	[di+s3mChannel.volume],al	; set volume
	call	SetVolume
	test	ax,ax
	jnz	@@done


@@nosetvolume:
	test	[di+s3mChannel.flags],128	; if flag bit 7 is 1, there
	jz	@@nocommand			; is a command

	mov	al,[di+s3mChannel.info] 	; al = command infobyte
	test	al,al				; if infobyte not zero, store
	jz	@@noinfo			; it as the previous infobyte
	mov	[di+s3mChannel.preinfo],al
@@noinfo:
	movzx	ax,[di+s3mChannel.preinfo]	; ax = command infobyte

	movzx	bx,[di+s3mChannel.cmd]		; bx = command number
	cmp	bx,"Z"-"@"                      ; make sure command is valid
	ja	@@nocommand
	add	bx,bx
	call	[commands+bx]			; process command
	test	ax,ax
	jnz	@@done


@@nocommand:
	add	di,size s3mChannel		; next channel
	inc	[chan]
	inc	[sdChan]

	mov	ax,[chan]
	cmp	ax,[numChans]
	jb	@@chanloop

	cmp	[pbFlag],0
	jne	@@break
	inc	[row]			; next row
	cmp	[row],64		; did we reach pattern end?
	jb	@@noend

	mov	[row],0

	; pattern end - move to next position:
@@break:
	call	NextPosition
	test	ax,ax
	jnz	@@done

@@noend:
	mov	[pbFlag],0		; clear pattern break flag
	call	s3mUpdBars		; update volume bars

@@done:
IFDEF DEBUGGER
	test	ax,ax
	jz	@@retu

	int 3

@@retu:
ENDIF
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	NextPosition
;*
;* Description: Move to next song position
;*
;* Returns:	MIDAS error code in ax
;*
;\***************************************************************************/

PROC	NextPosition	NEAR
USES	es, gs, si, di

	les	si,[module]		; point es:si to module structure

	mov	bx,[position]

@@nextp:
	inc	bx			; go to next position

	cmp	bx,[songLength] 	; did we reach song end?
	jae	@@restart		; if so, restart

	cmp	bx,[loopEnd]		; did we reach song loop end?
	jae	@@restart		; if so, restart

	lgs	di,[es:si+mpModule.orders]	; point gs:di to orders
	cmp	[byte gs:di+bx],0FEh		; pattern number 0FEh?
	je	@@nextp 			; if yes, go to next pos
	cmp	[byte gs:di+bx],0FFh		; pattern number 0FFh?
	jne	@@norestart			; if not, do not restart

@@restart:
	inc	[loopCnt]		; increase song loop counter
	mov	bx,[loopStart]		; restart song

@@norestart:
	mov	[playOffset],2		; skip pattern length word
	mov	[position],bx		; store new position
	xor	ax,ax
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	SetVolume
;*
;* Description: Sets the volume on current channel to Sound Device, scaled
;*		according to master volume
;*
;* Returns:	MIDAS error code in ax
;*
;\***************************************************************************/

PROC	SetVolume	NEAR

	mov	al,[di+s3mChannel.volume]
	call	SetSDVolume
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	SetSDVolume
;*
;* Description: Sets volume to Sound Device, scaled according to master volume
;*
;* Input:	al		volume
;*
;* Returns:	MIDAS error code in ax
;*
;\***************************************************************************/

PROC	SetSDVolume	NEAR

	or	[di+s3mChannel.status],1	; volume changed
	mov	bl,[masterVolume]
	mul	bl				; ax = actual volume
	shr	ax,6

	; set volume to Sound Device:
	push	gs
	call	[gs:si+SoundDevice.SetVolume] LANG, [sdChan], ax
	pop	gs

	ret
ENDP




;/***************************************************************************\
;*
;* Function:	SetSDPeriod
;*
;* Description: Sets period to Sound Device
;*
;* Input:	ax		period value
;*
;* Returns:	MIDAS error code in ax
;*
;\***************************************************************************/

PROC	SetSDPeriod	NEAR

	test	ax,ax			; skip if period is zero
	jz	@@ok

	movzx	ecx,ax
	mov	eax,14317056		; eax = sampling rate corresponding
	cdq				; to the period value
	idiv	ecx

	push	gs
	call	[gs:si+SoundDevice.SetRate] LANG, [sdChan], eax
	pop	gs
	jmp	@@done

@@ok:
	xor	ax,ax

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	SetPeriod
;*
;* Description: Sets the period on current channel to Sound Device and
;*		limits it to period limits.
;*
;* Returns:	MIDAS error code in ax
;*
;\***************************************************************************/

PROC	SetPeriod	NEAR

	; Adapted from STMIK 0.9beta with all the bugs that make S3M slides
	; sound so interesting... ;)

	mov	ax,[di+s3mChannel.period]	; ax = channel period

	mov	dx,[flags]		; are Amiga-limits used?
	test	dx,10h
	jz	@@noamiga

	cmp	ax,[upperLimit]
	jbe	@@abelow		; make sure period is below upper
	mov	ax,[upperLimit] 	; limit
	mov	[di+s3mChannel.period],ax
@@abelow:
	cmp	ax,[lowerLimit]
	jae	@@noamiga		; make sure period is above lower
	mov	ax,[lowerLimit] 	; limit
	mov	[di+s3mChannel.period],ax

@@noamiga:
	; no amiga limits - check with S3M limits

	cmp	ax,[upperLimit]
	jbe	@@below 		; make sure period is below upper
	mov	ax,[upperLimit] 	; limit
	test	dx,10h			; S3M bug! If Amiga-limits are not
	jz	@@below 		; used, new period is not set to
	mov	[di+s3mChannel.period],ax	; channel structure
@@below:
	cmp	ax,[lowerLimit]
	jae	@@above 		; make sure period is above lower
	mov	ax,[lowerLimit] 	; limit
	test	dx,10h			; S3M bug! If Amiga-limits are not
	jz	@@above 		; used, new period is not set to
	mov	[di+s3mChannel.period],ax	; channel structure
@@above:

	call	SetSDPeriod		; set period to Sound Device

@@oiud: ret
ENDP




;/***************************************************************************\
;*
;* Function:	SkipRows
;*
;* Description: Skips rows of song data. Used by Pattern Break and Pattern
;*		Loop commands
;*
;* Input:	cx		number of rows to skip
;*
;* Returns:	MIDAS error code in ax
;*
;\***************************************************************************/

PROC	SkipRows	NEAR
LOCAL	rowCount : word, pattPtr : dword
USES	es,gs,si,di

	mov	cx,[row]
	test	cx,cx
	je	@@done
	mov	[rowCount],cx		; store row counter

	les	si,[module]		; point es:si to module structure

	mov	bx,[position]
	lgs	di,[es:si+mpModule.orders]	; point gs:di to orders
	movzx	cx,[gs:di+bx]			; cx = current pattern number
	shl	cx,2

	lgs	di,[es:si+mpModule.patterns]	; point gs:di to current
	add	di,cx				; pattern pointer

	push	gs di
	lgs	di,[es:si+mpModule.pattEMS]	; point gs:di pattern EMS
	shr	cx,2				; flags
	mov	bx,cx
	cmp	[byte gs:di+bx],0		; is current pattern in EMS?
	pop	di gs
	je	@@noEMS

	; map pattern data to conventional memory:
	call	emsMap LANG, [dword gs:di], seg s3mMemPtr offset s3mMemPtr
	test	ax,ax
	jnz	@@done

	mov	eax,[s3mMemPtr] 	; store pattern data pointer
	mov	[pattPtr],eax
	jmp	@@dataok

@@noEMS:
	mov	eax,[gs:di]		; store pattern data pointer
	mov	[pattPtr],eax

@@dataok:
	les	si,[pattPtr]		; point es:si to pattern data
	add	si,[playOffset] 	; point es:si to current row data


@@dataloop:
	mov	al,[es:si]		; al = current channel flag byte
	inc	si
	test	al,al			; is flag byte zero?
	jz	@@rowend		; if is, end of row

	test	al,32			; if bit 5 of flag is 1, there is a
	jz	@@nonote		; note or instrument
	add	si,2			; skip note and instrument bytes

@@nonote:
	test	al,64			; if bit 6 of flag is 1, there is a
	jz	@@novol 		; volume change byte
	inc	si			; skip volume change byte

@@novol:
	test	al,128			; if bit 7 of flag 1 is, there is a
	jz	@@nocmd 		; command
	add	si,2			; skip command and infobyte

@@nocmd:
	jmp	@@dataloop		; get next flag byte and datas


@@rowend:
	dec	[rowCount]
	jnz	@@dataloop

	sub	si,[word pattPtr]	; play offset = si - pattern start
	mov	[playOffset],si 	; offset

@@done:
	xor	ax,ax
	ret
ENDP





;/***************************************************************************\
;*     Scream Tracker 3 command processing:
;\***************************************************************************/


; Command A - Set Speed

PROC	SetSpeed	NEAR

	mov	al,[di+s3mChannel.info] 	; get current infobyte
	test	al,al				; is it zero?
	jz	@@ok
	mov	[speed],al			; no, set speed to infobyte
@@ok:
	xor	ax,ax
	ret
ENDP




; Command B - Position Jump

PROC	PositionJump	NEAR

	movzx	ax,[di+s3mChannel.info] ; ax = infobyte
	cmp	[position],ax		; jump backward?
	jb	@@noend
	inc	[loopCnt]		; yes, increase song loop counter

@@noend:
	dec	ax			; next position will be correct
	mov	[position],ax		; set new position
	mov	[row],0 		; start from row 0
	mov	[pbFlag],1		; break to new pattern
	xor	ax,ax
	ret
ENDP



; Command C - Pattern Break

PROC	PatternBreak	NEAR

	mov	[pbFlag],1		; set pattern break flag
	mov	[skipFlag],1		; skip rows next time

	mov	al,[di+s3mChannel.info] ; al = infobyte
	mov	ah,al
	and	al,0Fh
	shr	ah,4			; ax = new row number (infobyte is
	aad				; in BCD)
	cmp	ax,63
	jbe	@@ok
	mov	ax,63
@@ok:	mov	[row],ax		; set new row number
	xor	ax,ax
	ret
ENDP




; Command D - Volume Slide

PROC	VolumeSlide	NEAR

	mov	bl,al			; bl = upper nybble - amount to add
	shr	bl,4			; to volume
	mov	cl,al			; cl = lower nybble - amount to
	and	cl,0Fh			; substract from volume

	cmp	cl,0Fh			; is lower nybble 0Fh?
	je	@@addfine		; if is, fine volume slide up
	cmp	bl,0Fh			; is upper nybble 0Fh?
	je	@@subfine		; if is, fine volume slide down

	test	cl,cl			; is lower nybble zero?
	jz	@@add			; is is, slide up
	jmp	@@sub

@@subfine:
	; fine volume slide down
	cmp    [playCount],0		; do only if player counter is 0
	jne    @@ok

@@sub:	sub	[di+s3mChannel.volume],cl	; volume slide down -
	jns	@@setv				; substract infobyte lower
	mov	[di+s3mChannel.volume],0	; nybble from volume. Check
	jmp	@@setv				; that volume is not negative

@@addfine:
	; fine volume slide down
	test	bl,bl			; S3M "bug" - if upper nybble is zero,
	jz	@@sub			; normal slide down with speed 0Fh.

	cmp	[playCount],0		; fine slide - do only if player
	jne	@@ok			; counter is 0

@@add:	add	[di+s3mChannel.volume],bl	; volume slide up - add
	cmp	[di+s3mChannel.volume],64	; infobyte upper nybble to
	jb	@@setv				; volume. Check that volume
	mov	[di+s3mChannel.volume],63	; is < 64

@@setv:
	call	SetVolume		; set volume to Sound Device
	jmp	@@done

@@ok:
	xor	ax,ax

@@done:
	ret
ENDP




; Command E - Slide Down

PROC	SlideDown NEAR

	cmp	[playCount],0		; is player counter 0?
	je	@@dofine		; if is, do only fine slides

	cmp	ax,0E0h 		; player counter is != 0 - do not
	jae	@@ok			; do fine slides
	shl	ax,2			; ax = period slide speed
	jmp	@@doslide


@@dofine:
	cmp	ax,0E0h 		; player counter is 0 - do only
	jbe	@@ok			; fine slides
	cmp	ax,0F0h 		; extra fine slide?
	jbe	@@efine

	and	ax,0Fh			; fine slide - use lower nybble * 4
	shl	ax,2			; as period slide speed
	jmp	@@doslide

@@efine:
	and	ax,0Fh			; extra fine slide - use lower nybble
					; as period slide speed

@@doslide:
	add	[di+s3mChannel.period],ax      ; slide down - add ax to period
	call	SetPeriod			; set period to Sound Device
	jmp	@@done

@@ok:
	xor	ax,ax

@@done:
	ret
ENDP




; Command F - Slide Up

PROC	SlideUp 	NEAR

	cmp	[playCount],0		; is player counter 0?
	je	@@dofine		; if is, do only fine slides

	cmp	ax,0E0h 		; player counter is != 0 - do not
	jae	@@ok			; do fine slides
	shl	ax,2			; ax = period slide speed
	jmp	@@doslide


@@dofine:
	cmp	ax,0E0h 		; player counter is 0 - do only
	jbe	@@ok			; fine slides
	cmp	ax,0F0h 		; extra fine slide?
	jbe	@@efine

	and	ax,0Fh			; fine slide - use lower nybble * 4
	shl	ax,2			; as period slide speed
	jmp	@@doslide

@@efine:
	and	ax,0Fh			; extra fine slide - use lower nybble
					; as period slide speed

@@doslide:
	sub	[di+s3mChannel.period],ax	; slide down - substract ax
						; from period
	call	SetPeriod			; set period to Sound Device
	jmp	@@done

@@ok:
	xor	ax,ax

@@done:
	ret
ENDP




; Command G - Tone Portamento

PROC NOLANGUAGE TonePortamento	NEAR

	movzx	ax,[di+s3mChannel.info] 	; ax = infobyte
	test	ax,ax				; is infobyte zero?
	jnz	@@old

ContinueTonePortamento:
	movzx	ax,[di+s3mChannel.notepsp]	; if is, use old porta speed

@@old:	mov	[di+s3mChannel.notepsp],al	; store portamento speed
	mov	bx,[di+s3mChannel.toperi]	; bx = slide destination
	test	bx,bx				; is destination zero?
	jz	@@setperiod			; if is, skip

	shl	ax,2			; period slide speed = speed * 4

	cmp	[di+s3mChannel.period],bx	; should we slide up?
	jg	@@up

	; slide down:
	add	[di+s3mChannel.period],ax	; increase period
	cmp	[di+s3mChannel.period],bx	; past portamento dest?
	jl	@@setperiod
	mov	[di+s3mChannel.period],bx	; if yes, set to porta dest
	mov	[di+s3mChannel.toperi],0	; do not slide anymore
	jmp	@@setperiod

@@up:
	; slide up:
	sub	[di+s3mChannel.period],ax	; decrease period
	cmp	[di+s3mChannel.period],bx	; past portamento dest?
	jg	@@setperiod
	mov	[di+s3mChannel.period],bx	; if yes, set to porta dest
	mov	[di+s3mChannel.toperi],0	; do not slide anymore

@@setperiod:
	call	SetPeriod
	ret
ENDP




; Command H - Vibrato

PROC NOLANGUAGE Vibrato 	NEAR

	mov	al,[di+s3mChannel.info] 	; al = infobyte
	test	al,al
	jnz	@@nozero
	mov	al,[di+s3mChannel.vibcmd]

@@nozero:
	test	al,0F0h 		; is infobyte upper nybble zero?
	jnz	@@1

	mov	ah,[di+s3mChannel.vibcmd]	; yes, use old vibrato
						; infobyte upper nybble
	and	al,0fh
	and	ah,0f0h
	or	al,ah
@@1:
	mov	[di+s3mChannel.vibcmd],al	; store vibrato infobyte

ContinueVibrato:
	mov	bl,[di+s3mChannel.vibpos]
	and	bx,1Fh				; bx = vibrato position
	mov	al,[vibratoTable+bx]		; al = vibrato value
	mov	cl,[di+s3mChannel.vibcmd]	; multiply with depth
	and	cl,0Fh
	mul	cl

	shr	ax,4				; divide with 16 - ST2 vibrato

	test	[flags],1			; is Scream Tracker 2 vibrato
	jnz	@@st2vib			; used?
	shr	ax,1				; no, divide still with 2

@@st2vib:
	movzx	eax,ax				; eax = vibrato value

	movzx	ebx,[di+s3mChannel.period]	; ebx = vibrato base period

	test	[di+s3mChannel.vibpos],32	; is vibrato position >= 32?
	jnz	@@vibneg

	add	ebx,eax 			; vibrato position < 32 -
	jmp	@@setper			; positiove

@@vibneg:
	sub	ebx,eax 			; vibrato position >= 32 -
						; negative

@@setper:
	mov	al,[di+s3mChannel.vibcmd]
	shr	al,4				; update vibrato position
	add	[di+s3mChannel.vibpos],al

	mov	ax,bx				; set new period to
	call	SetSDPeriod			; Sound Device
	ret
ENDP


; Command I - Tremor

PROC NOLANGUAGE Tremor	NEAR

	mov	bl,[di+s3mChannel.trecnt]	; bl = tremor count
	test	bl,bl				; is tremor counter zero?
	jz	@@change

	dec	bl				; no, decrement it
	mov	[di+s3mChannel.trecnt],bl
	jmp	@@ok				; and skip the rest

@@change:
	mov	al,[di+s3mChannel.info] 	; al = infobyte
	cmp	[di+s3mChannel.trefl],1 	; is current tremor flag 1?
	je	@@off				; if is, turn sound off

	; current tremor flag is 0 - turn sound on for infobyte upper nybble
	; frames:

	shr	al,4
	mov	[di+s3mChannel.trecnt],al	; tremor count = upper nybble
	mov	[di+s3mChannel.trefl],1 	; set flag to 1
	call	SetVolume			; set normal channel volume
	jmp	@@done

@@off:	; current tremor flag is 1 - turn sound on for infobyte lower nybble
	; frames:

	and	al,0Fh
	mov	[di+s3mChannel.trecnt],al	; tremor count = lower nybble
	mov	[di+s3mChannel.trefl],0 	; set flag to 0
	xor	al,al
	call	SetSDVolume			; Set Sound Device volume to 0
	jmp	@@done
@@ok:
	xor	ax,ax
@@done:
	ret
ENDP



; Command J - Arpeggio

PROC NOLANGUAGE Arpeggio	NEAR

	mov	bl,[di+s3mChannel.snote]	; bl = current note

	mov	cl,bl
	and	bx,0Fh				; bx = note number,
	shr	cl,4				; cl = octave

	push	cx
	movzx	ax,[playCount]
	mov	cl,3			; divide player counter with 3
	div	cl			; - ah = modulus
	pop	cx

	test	ah,ah			; is modulus zero?
	jz	@@a0			; if yes, play with base note
	dec	ah			; is it 1?
	jz	@@a1

	; modulus is 2 - add infobyte lower nybble to note
	mov	al,[di+s3mChannel.preinfo]
	and	ax,0Fh
	add	bx,ax
	jmp	@@a0

@@a1:
	; modulus is 1 - add infobyte upper nybble to note
	movzx	ax,[di+s3mChannel.preinfo]
	shr	ax,4
	add	bx,ax

@@a0:
	cmp	bx,12			; check if we crossed an octave
	jb	@@nooct 		; boundary
	sub	bx,12			; yes, substract 12 from note and
	inc	cl			; increment octave
@@nooct:

	; Calculate sampling rate that corresponds to new note. A crazy
	; method, but this is what the Scream Tracker 3 documentation
	; says:

;			  8363 * 16 * ( period(NOTE) >> octave(NOTE) )
;	 note_st3period = --------------------------------------------
;			  middle_c_finetunevalue(INSTRUMENT)
;
;	 note_amigaperiod = note_st3period / 4
;
;	 note_herz=14317056 / note_st3period


	add	bx,bx
	movzx	eax,[Periods+bx]		; eax = new note period
	imul	eax,eax,8363*16 		; eax = 8363 * 16 * period
	shr	eax,cl				;	/ 2^oct

	movzx	bx,[di+s3mChannel.sample]

	push	si
	les	si,[module]
	les	si,[es:si+mpModule.insts]
	dec	bx				; point es:si to current
	imul	bx,bx,SIZE mpInstrument 	; instrument structure
	add	si,bx

	mov	ebx,[es:si+mpInstrument.c2Rate] ; ebx = instrument C4 sampling
	pop	si				; rate

	cdq					; eax = period = 8366 * 16
	idiv	ebx				;   * period / 2^oct / c2Rate

	call	SetSDPeriod		; set new period to Sound Device
	ret
ENDP




; Command K - Vibrato and Volume Slide

PROC NOLANGUAGE VibratoVolumeSlide	NEAR

	call	VolumeSlide
	test	ax,ax
	jnz	@@done

	call	ContinueVibrato
@@done:
	ret
ENDP



; Command L - Tone Portamento and Volume Slide

PROC NOLANGUAGE TonePortamentoVolumeSlide NEAR

	call	VolumeSlide
	test	ax,ax
	jnz	@@done

	call	ContinueTonePortamento
@@done:
	ret
ENDP




; Command Q - Retrig Note

PROC NOLANGUAGE RetrigNote	NEAR

	mov	al,[di+s3mChannel.retrigc]	; get retrig count
	dec	al				; decrement it
	cmp	al,0				; if counter is <= 0, retrig
	jle	@@retrig

	mov	[di+s3mChannel.retrigc],al	; store new counter
	jmp	@@ok

@@retrig:
	push	gs
	call	[gs:si+SoundDevice.SetPosition], [sdChan], 0
	pop	gs
	test	ax,ax
	jnz	@@done

	mov	al,[di+s3mChannel.preinfo]
	mov	bl,al				; set infobyte lower nybble
	and	al,0Fh				; as retrig count
	mov	[di+s3mChannel.retrigc],al

	; Retrig note volume slides: (this apprarently, works, though I
	; do not why)

	shr	bl,4				; bx = infobyte upper nybble
	xor	bh,bh				; = index to retrig table
	mov	al,[retrigTable2+bx]		; get value from table
	test	al,al				; was it zero?
	jz	@@1

	mov	cl,[di+s3mChannel.volume]	; not zero, multiply volume
	mul	cl				; with table value
	shr	ax,4				; and divide with 16
	mov	[di+s3mChannel.volume],al	; set new volume
	jmp	@@check

@@1:	mov	al,[retrigTable1+bx]	      ; value from table zero - get
	add	[di+s3mChannel.volume],al     ; volume increment from table 1

@@check:
	mov	al,[di+s3mChannel.volume]
	cmp	al,0				; make sure that volume is
	jge	@@notbelow			; not below zero
	mov	[di+s3mChannel.volume],0
@@notbelow:
	cmp	al,64
	jl	@@eiyli64			; make sure that volume is
	mov	[di+s3mChannel.volume],63	; not above 63
@@eiyli64:
	or	[di+s3mChannel.status],3	; force volume value
	call	SetVolume			; set volume to Sound Device
	jmp	@@done

@@ok:
	xor	ax,ax
@@done:
	ret
ENDP




; Command R - Tremolo

PROC NOLANGUAGE Tremolo 	NEAR

	mov	al,[di+s3mChannel.info] 	; al = infobyte
	test	al,al
	jnz	@@nozero
	mov	al,[di+s3mChannel.vibcmd]

@@nozero:
	test	al,0F0h 		; is infobyte upper nybble zero?
	jnz	@@1

	mov	ah,[di+s3mChannel.vibcmd]	; yes, use old vibrato
						; infobyte upper nybble
	and	al,0fh
	and	ah,0f0h
	or	al,ah
@@1:
	mov	[di+s3mChannel.vibcmd],al	; store vibrato infobyte

	mov	bl,[di+s3mChannel.vibpos]
	and	bx,1Fh				; bx = vibrato position
	mov	al,[vibratoTable+bx]		; al = vibrato value
	mov	cl,[di+s3mChannel.vibcmd]	; multiply with depth
	and	cl,0Fh
	mul	cl

	shr	ax,7				; divide with 128

	movzx	bx,[di+s3mChannel.volume]	; bx = tremolo base volume

	test	[di+s3mChannel.vibpos],32	 ; is vibrato positio >= 32?
	jnz	@@vibneg

	add	bx,ax				; vibrato position < 32 -
	jmp	@@setvol			; positiove

@@vibneg:
	sub	bx,ax				; vibrato position >= 32 -
						; negative

@@setvol:
	mov	al,[di+s3mChannel.vibcmd]
	shr	al,4				; update vibrato position
	add	[di+s3mChannel.vibpos],al

	or	[di+s3mChannel.status],1	; volume changed

	cmp	bx,0
	jge	@@notbelow			; make sure volume is not
	xor	bx,bx				; negative
@@notbelow:
	cmp	bx,64
	jl	@@notabove			; make sure volume is not
	mov	bx,63				; above 64
@@notabove:
	mov	al,bl
	call	SetSDVolume			; set new volume to
	ret					; Sound Device
ENDP




; Command T - Set Tempo

PROC NOLANGUAGE SetTempo	NEAR

	mov	al,[di+s3mChannel.info] 	; al = infobyte
	mov	[tempo],al			; BPM tempo = infobyte

	xor	ah,ah
	mov	bx,40				; BPM * 40 = update rate in
	mul	bx				; 100*Hz
	mov	[mpS3M.updRate],ax
	mov	bx,ax

	; Set Sound Device update rate
	push	gs bx
	call	[gs:si+SoundDevice.SetUpdRate] LANG, bx
	pop	bx gs
	test	ax,ax
	jnz	@@done

	; Set Timer update rate:
	push	gs
	call	tmrSetUpdRate LANG, bx
	pop	gs

@@done:
	ret
ENDP




; Command V - Set Master Volume

PROC NOLANGUAGE SetMasterVolume 	NEAR

	mov	al,[di+s3mChannel.info] 	; al = infobyte

	cmp	al,64
	jbe	@@1				; make sure master volume
	mov	al,64				; is not above 64

@@1:	mov	[masterVolume],al		; store master volume

	xor	ax,ax

	ret
ENDP


; Command X - Set Panning

PROC NOLANGUAGE SetPanning NEAR

	mov	al,[di+s3mChannel.info] 	; al = infobyte
	cmp	[usePanning],0		; should panning command be supported?
	je	@@ok			; skip if not

	cmp	al,0A4h 		; DMP-compatible surround panning
	jne	@@nsurround		; value 0A4h

	mov	ax,panSurround		; set surround panning
	jmp	@@set

@@nsurround:
	cmp	al,128			; skip illegal panning values
	ja	@@ok

	sub	al,40h			; convert DMP panning values to
	cbw				; MIDAS (0-128) to (-64 - 64)

@@set:
	mov	bx,[chan]		; bx = Sound Device channel number
	add	bx,[firstSDChan]

	; Set Sound Device panning:
	push	gs
	call	[gs:si+SoundDevice.SetPanning], bx, ax
	pop	gs
	jmp	@@done

@@ok:
	xor	ax,ax

@@done:
	ret
ENDP






; Command S - Special Commands

PROC NOLANGUAGE SpecialCommands 	NEAR

	mov	bl,al			; al = infobyte (can't be zero!)
	and	ax,0Fh			; ax = actual S-command infobyte

	and	bx,0F0h 		; bx = index to S-command offset
	shr	bx,3			; table
	call	[scommands+bx]		; process command
	ret
ENDP


; Command S8 - 16-Step Set Panning

PROC NOLANGUAGE SetPanning16 NEAR

	cmp	[usePanning],0		; should panning command be supported?
	je	@@ok			; skip if not

	sub	ax,8
	js	@@ski
	inc	ax
@@ski:
	sal	ax,3

	mov	bx,[chan]		; bx = Sound Device channel number
	add	bx,[firstSDChan]

	; Set Sound Device panning:
	push	gs
	call	[gs:si+SoundDevice.SetPanning], bx, ax
	pop	gs
	jmp	@@done
@@ok:
	xor	ax,ax
@@done:
	ret
ENDP



; Command SC - Note Cut

PROC NOLANGUAGE NoteCut 	NEAR

	cmp	[playCount],al		; cut note when player count is equal
	jne	@@ok			; to infobyte

	mov	[di+s3mChannel.volume],0	; set volume to zero
	call	SetVolume		; set volume to Sound Device
	jmp	@@done

@@ok:
	xor	ax,ax

@@done:
	ret
ENDP




; Command SD - Note Delay

PROC NOLANGUAGE NoteDelay	NEAR

	cmp	[playCount],al		; start note whey player counter is
	jne	@@ok			; equal to infobyte

	mov	bl,[di+s3mChannel.note] 	; bl = note
	cmp	bl,255				; skip if empty note
	je	@@nonewnote
	cmp	bl,254				; is note key off?
	je	@@keyoff

	mov	[di+s3mChannel.snote],bl	; set note

	mov	cl,bl				; cl = new note octave
	shr	cl,4

	; Calculate sampling rate that corresponds to new note. A crazy
	; method, but this is what the Scream Tracker 3 documentation
	; says:

;			  8363 * 16 * ( period(NOTE) >> octave(NOTE) )
;	 note_st3period = --------------------------------------------
;			  middle_c_finetunevalue(INSTRUMENT)
;
;	 note_amigaperiod = note_st3period / 4
;
;	 note_herz=14317056 / note_st3period


	and	bx,0Fh
	add	bx,bx
	movzx	eax,[Periods+bx]		; eax = new note period
	imul	eax,eax,8363*16 		; eax = 8363 * 16 * period
	shr	eax,cl				;	/ 2^oct

	movzx	bx,[di+s3mChannel.sample]

	push	si
	les	si,[module]
	les	si,[es:si+mpModule.insts]
	dec	bx				; point es:si to current
	imul	bx,bx,SIZE mpInstrument 	; instrument structure
	add	si,bx

	mov	ebx,[es:si+mpInstrument.c2Rate] ; ebx = instrument C4 sampling
	pop	si				; rate

	test	ebx,ebx 			; is c2Rate zero?
	jz	@@1
	cdq					; eax = period = 8366 * 16
	idiv	ebx				;   * period / 2^oct / c2Rate

@@1:	or	[di+s3mChannel.status],3	; force volume
	mov	[di+s3mChannel.period],ax	; store current period number

	mov	ebx,eax 			; ebx = period
	test	ebx,ebx 			; do not set note if period
	jz	@@nonewnote			; is zero

	mov	eax,14317056
	cdq				; ebx = note sampling rate in Hz
	idiv	ebx

	; start playing current note with Sound Device:
	push	gs
	call	[gs:si+SoundDevice.PlaySound] LANG, [sdChan], eax
	pop	gs
	test	ax,ax
	jmp	@@done

@@nonewnote:
	jmp	@@ok

@@keyoff:
	; note is key off - stop playing sound:
	push	gs
	call	[gs:si+SoundDevice.StopSound] LANG, [sdChan]
	pop	gs
	jmp	@@done


@@ok:
	xor	ax,ax

@@done:
	ret
ENDP




; Command SB - Pattern Loop

PROC NOLANGUAGE PatternLoop	NEAR

	cmp	[playCount],0		; do only when player count is 0
	jne	@@ok

	test	al,al			; if infobyte is zero, set loop
	jz	@@setloop		; start

	cmp	[loopFlag],0		; already looping?
	je	@@setcount		; if not, set loop count

	dec	[loopCount]		; decrement loop counter
	jnz	@@loop			; if not zero, jump to loop beginning
	mov	[loopFlag],0		; zero - do not loop
	jmp	@@ok


@@loop: mov	ax,[loopRow]
	dec	ax			; set loop start row
	mov	[row],ax

	mov	ax,[loopOffset] 	; and playing offset
	mov	[playOffset],ax
	jmp	@@ok

@@setcount:
	mov	[loopCount],al		; set loop counter
	mov	[loopFlag],1		; looping
	jmp	@@loop

@@setloop:
	mov	ax,[row]		; save loop start row and playing
	mov	[loopRow],ax		; offset
	mov	ax,[oldOffset]
	mov	[loopOffset],ax

@@ok:
	xor	ax,ax

	ret
ENDP




; Command SD - Pattern Delay

PROC NOLANGUAGE PatternDelay  NEAR

	cmp	[delayFlag],0		; pattern delay already active?
	jne	@@ok

	mov	[delayCount],al 	; set delay counter
	mov	[delayFlag],1

@@ok:
	xor	ax,ax
	ret
ENDP




; Empty

PROC NOLANGUAGE DoNothing	NEAR

	xor	ax,ax
	ret
ENDP




;/***************************************************************************\
;*     Calling offset tables to commands:
;\***************************************************************************/

	; Commands run when song data is played:
LABEL	commands	WORD
	DW	offset DoNothing
	DW	offset SetSpeed
	DW	offset PositionJump
	DW	offset PatternBreak
	DW	offset VolumeSlide
	DW	offset SlideDown
	DW	offset SlideUp
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset Tremor
	DW	offset Arpeggio
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset RetrigNote
	DW	offset DoNothing
	DW	offset SpecialCommands
	DW	offset SetTempo
	DW	offset DoNothing
	DW	offset SetMasterVolume
	DW	offset DoNothing
	DW	offset SetPanning
	DW	offset DoNothing
	DW	offset DoNothing

	; continuous commands:
LABEL	contCommands	WORD
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset VolumeSlide
	DW	offset SlideDown
	DW	offset SlideUp
	DW	offset TonePortamento
	DW	offset Vibrato
	DW	Offset Tremor
	DW	offset Arpeggio
	DW	offset VibratoVolumeSlide
	DW	offset TonePortamentoVolumeSlide
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset RetrigNote
	DW	offset Tremolo
	DW	offset SpecialCommands
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset DoNothing


	; S-commands:
LABEL	scommands	WORD
	DW	offset DoNothing	; 0
	DW	offset DoNothing	; 1
	DW	offset DoNothing	; 2
	DW	offset DoNothing	; 3
	DW	offset DoNothing	; 4
	DW	offset DoNothing	; 5
	DW	offset DoNothing	; 6
	DW	offset DoNothing	; 7
	DW	offset SetPanning16	; 8
	DW	offset DoNothing	; 9
	DW	offset DoNothing	; A
	DW	offset PatternLoop	; B
	DW	offset NoteCut		; C
	DW	offset NoteDelay	; D
	DW	offset PatternDelay	; E
	DW	offset DoNothing	; F



;/***************************************************************************\
;*
;* Function:	int s3mSetPosition(ushort pos)
;*
;* Description: Jumps to a specified position in module
;*
;* Input:	ushort	pos		Position to jump to
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	s3mSetPosition	FAR	pos : word
USES	si,di

	mov	bx,[pos]		; bx = new position
	cmp	bx,0			; is new position negative
	jge	@@noneg
	mov	bx,[songLength] 	; yes, set it to song end
	dec	bx
@@noneg:
	mov	[row],0

	les	si,[module]		; point es:si to module structure
@@findpos:
	cmp	bx,[songLength] 	; past song end?
	jge	@@restart		; if so, restart from beginning

	lgs	di,[es:si+mpModule.orders]
	mov	cl,[gs:di+bx]		; cl = pattern number for this pos
	cmp	cl,0FEh 		; is pattern 0FEh?
	je	@@next			; if is, skip
	cmp	cl,0FFh 		; is pattern 0FFh?
	je	@@next			; if is, skip
	jmp	@@posok

@@next:
	inc	bx			; next position
	jmp	@@findpos

@@restart:
	xor	bx,bx			; restart song - set position to 0
	mov	[loopStart],0		; set song loop start to 0

@@posok:
	mov	[position],bx		; store new position
	mov	[poss],bx
	mov	[playOffset],2		; skip pattern length word
	mov	[playCount],0

	xor	ax,ax
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	int s3mGetInformation(mpInformation *info);
;*
;* Description: Fills the Module Player information structure
;*
;* Input:	mpInformation *info	information structure to be filled
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	s3mGetInformation	FAR	info : dword
USES	si, di

	les	si,[info]		; point es:si to info structure
	mov	di,offset channels	; point ds:di to channel structures

	mov	ax,[setFrame]			; copy set-frame flag
	mov	[es:si+mpInformation.setFrame],ax
	mov	[setFrame],0			; and set it to zero

	mov	ax,[rows]			; copy saved row, position
	mov	[es:si+mpInformation.row],ax	; and pattern numbers
	mov	ax,[poss]
	mov	[es:si+mpInformation.pos],ax
	mov	ax,[pats]
	mov	[es:si+mpInformation.pattern],ax

	movzx	ax,[speed]
	mov	[es:si+mpInformation.speed],ax	; copy speed and BPM tempo
	movzx	ax,[tempo]
	mov	[es:si+mpInformation.BPM],ax

	movzx	ax,[loopCnt]			; copy song loop counter
	mov	[es:si+mpInformation.loopCnt],ax

	mov	cx,[es:si+mpInformation.numChannels]   ; cx = channel counter
	les	si,[es:si+mpInformation.chans]		; point es:si to
							; channel info
@@chanloop:
	mov	al,[di+s3mChannel.flags]	; copy channel flags
	mov	[es:si+mpChanInfo.flags],al

	mov	al,[di+s3mChannel.snote]	; copy note number
	mov	[es:si+mpChanInfo.note],al

	mov	al,[di+s3mChannel.sample]	; copy instrument number
	mov	[es:si+mpChanInfo.instrument],al

	mov	al,[di+s3mChannel.info] 	; copy command infobyte
	mov	[es:si+mpChanInfo.infobyte],al

	mov	al,[di+s3mChannel.volume]	; copy volume
	mov	[es:si+mpChanInfo.volume],al

	mov	al,[di+s3mChannel.volbar]	; copy volume bar
	mul	[masterVolume]
	shr	ax,6
	mov	[es:si+mpChanInfo.volumebar],al

	test	[di+s3mChannel.flags],128	; is there a command?
	jz	@@nocmd

	movzx	bx,[di+s3mChannel.cmd]		; bx = command number

	cmp	bx,"S"-"@"                      ; is command a S-command?
	jne	@@noscmd

	; S-command
	mov	al,[es:si+mpChanInfo.infobyte]
	shr	al,4				; command number = infobyte
	movzx	bx,al				; upper nybble + 20h
	add	al,20h				; infobyte = infobyte lower
	mov	[es:si+mpChanInfo.command],al	; nybble
	and	[es:si+mpChanInfo.infobyte],0Fh

	shl	bx,2
	mov	eax,[scmdNames+bx]		; eax = command name pointer
	mov	[es:si+mpChanInfo.commandname],eax	; store name pointer
	jmp	@@cmddone


@@noscmd:
	mov	[es:si+mpChanInfo.command],bl	; store command number

	shl	bx,2
	mov	eax,[cmdNames+bx]		; eax = command name pointer
	mov	[es:si+mpChanInfo.commandname],eax	; store name pointer
	jmp	@@cmddone

@@nocmd:
	; no command:
	mov	[es:si+mpChanInfo.command],0	; command number = 0

	; point command name string to empty:
	mov	[word es:si+mpChanInfo.commandname],offset strNoCmd
	mov	[word es:si+2+mpChanInfo.commandname],seg strNoCmd

@@cmddone:
	add	si,SIZE mpChanInfo		; next channel
	add	di,SIZE s3mChannel
	loop	@@chanloop

	xor	ax,ax
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	s3mSave
;*
;* Description: Saves row, position and pattern values for GetInformation()
;*
;\***************************************************************************/

PROC	s3mSave 	NEAR

	mov	[setFrame],1		; set set-frame flag
	mov	ax,[row]
	mov	[rows],ax		; save row and position
	mov	bx,[position]
	mov	[poss],bx

	lgs	di,[es:si+mpModule.orders]
	movzx	ax,[gs:di+bx]		; save pattern number
	mov	[pats],ax

	xor	ax,ax
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	s3mUpdBars
;*
;* Description: Updates "fake" volume bars
;*
;\***************************************************************************/

PROC	s3mUpdBars	NEAR
USES	di

	mov	di,offset channels	; point ds:di to channel structures
	mov	cx,[numChans]

@@chanloop:
	cmp	[di+s3mChannel.volbar],0	; is volume bar zero?
	je	@@1
	dec	[di+s3mChannel.volbar]		; if not, decrement it
@@1:
	test	[di+s3mChannel.status],1	; has volume been changed?
	jz	@@nochange
	mov	al,[di+s3mChannel.volume]
	test	[di+s3mChannel.status],2	; force new volume?
	jnz	@@force
	cmp	[di+s3mChannel.volbar],al	; do not force volume
	jbe	@@nochange			; is bar above volume level?
@@force:
	mov	[di+s3mChannel.volbar],al	; set new volume

@@nochange:
	and	[di+s3mChannel.status],not 3	; clear volume change bits
	add	di,SIZE s3mChannel		; next channel
	loop	@@chanloop

	xor	ax,ax
	ret
ENDP


;/***************************************************************************\
;*
;* Function:	int s3mSetMasterVolume(uchar volume)
;*
;* Description: Sets the module player master volume
;*
;* Input:	uchar  volume		  New master volume
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	s3mSetMasterVolume  FAR     vol : word

	mov	ax,[vol]
	cmp	al,64
	jle	@@ok
	mov	al,64
@@ok:
	mov	[masterVolume],al
	xor	ax,ax			; success
	ret
ENDP


END

