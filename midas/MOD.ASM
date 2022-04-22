;*	MOD.ASM
;*
;* Protracker Module Player, v1.13
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
INCLUDE "mglobals.inc"
INCLUDE "mod.inc"
INCLUDE "mplayer.inc"
INCLUDE "sdevice.inc"
INCLUDE "ems.inc"
INCLUDE "timer.inc"


DATASEG


;*
;* MOD player data structures
;*

module		DD	?		; pointer to module structure
sdevice 	DD	?		; current Sound Device

playCount	DB	?		; player speed counter
speed		DB	?		; playing speed, default is 6
tempo		DB	?		; playing BPM tempo
masterVolume	DB	?		; master volume (0-64)
pbFlag		DB	?		; pattern break flag
loopCnt 	DB	?		; song loop counter

position	DW	?		; position in song
row		DW	?		; row in pattern
songLength	DW	?		; song length (number of positions)
numChans	DW	?		; number of channels
firstSDChan	DW	?		; first Sound Device channel number
chan		DW	?		; current channel number
loopRow 	DW	?		; pattern loop row number
loopFlag	DB	?		; pattern loop flag
loopCount	DB	?		; pattern loop counter
delayCount	DB	?		; pattern delay count
delayFlag	DB	?		; pattern delay flag
skipFlag	DW	?		; 1 if some rows should be skipped
					; next time song is played. Set by
					; pattern loop and break commands.

setFrame	DW	?		; 1 if "set frame" (song is played),
					; 0 if not
rows		DW	?		; saved row number for GetInformation
poss		DW	?		; saved position
pats		DW	?		; saved pattern number

modMemPtr	DD	?		; temporary pointer used by some
					; functions


channels	modChannel  MPCHANNELS DUP (?)	    ; channel structures



IDATASEG



;/***************************************************************************\
;*     Protracker Module Player structure:
;\***************************************************************************/

mpMOD ModulePlayer    < \
	mpUnInitialized, \
	5000, \
	far ptr modIdentify, \
	far ptr modInit, \
	far ptr modClose, \
	far ptr modLoadModule, \
	far ptr modFreeModule, \
	far ptr modPlayModule, \
	far ptr modStopModule, \
	far ptr modSetInterrupt, \
	far ptr modRemoveInterrupt, \
	far ptr modPlay, \
	far ptr modSetPosition, \
	far ptr modGetInformation,\
	far ptr modSetMasterVolume >



	; sine table for vibrato:
vibratoTable	DB	0,24,49,74,97,120,141,161
		DB	180,197,212,224,235,244,250,253
		DB	255,253,250,244,235,224,212,197
		DB	180,161,141,120,97,74,49,24

	; 100% Protracker compatible period table:
LABEL	Periods 	WORD
; Tuning 0, Normal
	DW	856,808,762,720,678,640,604,570,538,508,480,453
	DW	428,404,381,360,339,320,302,285,269,254,240,226
	DW	214,202,190,180,170,160,151,143,135,127,120,113

; Tuning 1
	DW	850,802,757,715,674,637,601,567,535,505,477,450
	DW	425,401,379,357,337,318,300,284,268,253,239,225
	DW	213,201,189,179,169,159,150,142,134,126,119,113

; Tuning 2
	DW	844,796,752,709,670,632,597,563,532,502,474,447
	DW	422,398,376,355,335,316,298,282,266,251,237,224
	DW	211,199,188,177,167,158,149,141,133,125,118,112

; Tuning 3
	DW	838,791,746,704,665,628,592,559,528,498,470,444
	DW	419,395,373,352,332,314,296,280,264,249,235,222
	DW	209,198,187,176,166,157,148,140,132,125,118,111

; Tuning 4
	DW	832,785,741,699,660,623,588,555,524,495,467,441
	DW	416,392,370,350,330,312,294,278,262,247,233,220
	DW	208,196,185,175,165,156,147,139,131,124,117,110

; Tuning 5
	DW	826,779,736,694,655,619,584,551,520,491,463,437
	DW	413,390,368,347,328,309,292,276,260,245,232,219
	DW	206,195,184,174,164,155,146,138,130,123,116,109

; Tuning 6
	DW	820,774,730,689,651,614,580,547,516,487,460,434
	DW	410,387,365,345,325,307,290,274,258,244,230,217
	DW	205,193,183,172,163,154,145,137,129,122,115,109

; Tuning 7
	DW	814,768,725,684,646,610,575,543,513,484,457,431
	DW	407,384,363,342,323,305,288,272,256,242,228,216
	DW	204,192,181,171,161,152,144,136,128,121,114,108

; Tuning -8
	DW	907,856,808,762,720,678,640,604,570,538,508,480
	DW	453,428,404,381,360,339,320,302,285,269,254,240
	DW	226,214,202,190,180,170,160,151,143,135,127,120

; Tuning -7
	DW	900,850,802,757,715,675,636,601,567,535,505,477
	DW	450,425,401,379,357,337,318,300,284,268,253,238
	DW	225,212,200,189,179,169,159,150,142,134,126,119

; Tuning -6
	DW	894,844,796,752,709,670,632,597,563,532,502,474
	DW	447,422,398,376,355,335,316,298,282,266,251,237
	DW	223,211,199,188,177,167,158,149,141,133,125,118

; Tuning -5
	DW	887,838,791,746,704,665,628,592,559,528,498,470
	DW	444,419,395,373,352,332,314,296,280,264,249,235
	DW	222,209,198,187,176,166,157,148,140,132,125,118

; Tuning -4
	DW	881,832,785,741,699,660,623,588,555,524,494,467
	DW	441,416,392,370,350,330,312,294,278,262,247,233
	DW	220,208,196,185,175,165,156,147,139,131,123,117

; Tuning -3
	DW	875,826,779,736,694,655,619,584,551,520,491,463
	DW	437,413,390,368,347,328,309,292,276,260,245,232
	DW	219,206,195,184,174,164,155,146,138,130,123,116

; Tuning -2
	DW	868,820,774,730,689,651,614,580,547,516,487,460
	DW	434,410,387,365,345,325,307,290,274,258,244,230
	DW	217,205,193,183,172,163,154,145,137,129,122,115

; Tuning -1
	DW	862,814,768,725,684,646,610,575,543,513,484,457
	DW	431,407,384,363,342,323,305,288,272,256,242,228
	DW	216,203,192,181,171,161,152,144,136,128,121,114



	; command name pointers:
LABEL	cmdNames	DWORD
	DD	far ptr strArpeggio
	DD	far ptr strSlideUp
	DD	far ptr strSlideDown
	DD	far ptr strTonePortamento
	DD	far ptr strVibrato
	DD	far ptr strTPortVSlide
	DD	far ptr strVibVSlide
	DD	far ptr strTremolo
	DD	far ptr strSetPanning
	DD	far ptr strSampleOffs
	DD	far ptr strVolSlide
	DD	far ptr strPosJump
	DD	far ptr strSetVol
	DD	far ptr strPattBreak
	DD	far ptr strNoCmd
	DD	far ptr strSetSpeed

	; E-command name pointers:
LABEL	ecmdNames	DWORD
	DD	far ptr strSetFilter
	DD	far ptr strFineSldUp
	DD	far ptr strFineSldDown
	DD	far ptr strGlissCtrl
	DD	far ptr strSetVibWform
	DD	far ptr strSetFinetune
	DD	far ptr strPatternLoop
	DD	far ptr strSetTremWform
	DD	far ptr strSetPanning
	DD	far ptr strRetrig
	DD	far ptr strFineVSldUp
	DD	far ptr strFineVSldDown
	DD	far ptr strNoteCut
	DD	far ptr strNoteDelay
	DD	far ptr strPattDelay
	DD	far ptr strInvLoop


strNoCmd	DB	0
strSlideUp	DB	"Slide Up",0
strSlideDown	DB	"Slide Down",0
strTonePortamento DB	"Tone Porta",0
strVibrato	DB	"Vibrato",0
strTPortVSlide	DB	"TPrt+VolSld",0
strVibVSlide	DB	"Vib+VolSld",0
strTremolo	DB	"Tremolo",0
strSetPanning	DB	"Set Panning",0
strSampleOffs	DB	"Sample Offs",0
strArpeggio	DB	"Arpeggio",0
strVolSlide	DB	"VolumeSlide",0
strPosJump	DB	"Pos. Jump",0
strPattBreak	DB	"Patt. Break",0
strSetSpeed	DB	"Set Speed",0
strSetVol	DB	"Set Volume",0

strSetFilter	DB	"Set Filter",0
strFineSldUp	DB	"FineSld Up",0
strFineSldDown	DB	"FineSld Dwn",0
strGlissCtrl	DB	"Gliss. Ctrl",0
strSetVibWform	DB	"Vib.Wavefrm",0
strSetFinetune	DB	"SetFinetune",0
strPatternLoop	DB	"Patt.Loop",0
strSetTremWform DB	"Tre.Wavefrm",0
strRetrig	DB	"Retrig Note",0
strFineVSldUp	DB	"FineVSld Up",0
strFineVSldDown DB	"FineVSldDwn",0
strNoteCut	DB	"Note Cut",0
strNoteDelay	DB	"Note Delay",0
strPattDelay	DB	"Patt.Delay",0
strInvLoop	DB	"Invert Loop",0




CODESEG

;/***************************************************************************\
;*
;* Function:	int modIdentify(uchar *header, int *recognized);
;*
;* Description: Checks if the header is a Protracker module header
;*
;* Input:	uchar *headeer		pointer to header, length MPHDRSIZE
;*		int *recognized 	pointer to result variable
;*
;* Returns:	MIDAS error code.
;*		*recognized set to 1 if header is a Protracker module header,
;*		0 if not
;*
;\***************************************************************************/

PROC	modIdentify	FAR	header : dword, recognized : dword

	les	bx,[header]

	mov	eax,[dword es:bx+modHeader.sign]     ; eax = header signature

	; check if the signature is valid:
	cmp	eax,".K.M"
	je	@@1
	cmp	eax,"!K!M"
	je	@@1
	cmp	eax,"4TLF"
	je	@@1
	cmp	eax,"ATCO"
	je	@@1

	mov	ebx,eax
        shr     ebx,8                           ; xCHN - signature
        cmp     ebx,"NHC"
	je	@@1

	mov	ebx,eax
        shr     ebx,16
        cmp     ebx,"HC"                        ; xxCH-sign
	je	@@1

        and     eax,0FFFFFFh
	cmp	eax,"ZDT"                       ; TDZx-sign
	je	@@1


; MTM-SUPPORT IS GONE FOR NOW!

;	 mov	 eax,[es:si]
;	 and	 eax,0ffffffh
;	 cmp	 eax,"MTM"
;	 je	 @@1

	; not a Protracker module
	xor	ax,ax
	jmp	@@iddone

@@1:	mov	ax,1

@@iddone:
	les	bx,[recognized] 	; store result in *recognized
	mov	[es:bx],ax

	xor	ax,ax			; always successful
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	int modInit(SoundDevice *SD);
;*
;* Description: Initializes Protracker Module Player
;*
;* Input:	SoundDevice *SD 	pointer to Sound Device to be used
;*					for playing
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	modInit 	FAR	SDev : dword

	mov	eax,[SDev]		; store Sound Device pointer in
	mov	[sdevice],eax		; sdevice

	mov	[mpMOD.status],mpInitialized	; Module Player is initialized

	xor	ax,ax			; success

	ret
ENDP



;/***************************************************************************\
;*
;* Function:	int modClose(void);
;*
;* Description: Uninitializes the Protracker Module Player
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	modClose FAR

	mov	[mpMOD.status],mpUnInitialized

	xor	ax,ax			; success
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	int modPlayModule(mpModule *module, ushort firstSDChannel,
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

PROC	modPlayModule	FAR	mmod : dword, firstSDChannel : word, \
				numChannels : word, loopStart : word, \
				loopEnd : word
USES	si,di

	mov	eax,[mmod]		; store module pointer in module
	mov	[module],eax
	les	si,[module]		; point es:si to module structure

	mov	ax,[es:si+mpModule.songLength]	; get song length from module
	mov	[songLength],ax 		; and store it

	mov	ax,[firstSDChannel]	; store first SD channel number
	mov	[firstSDChan],ax
	mov	ax,[numChannels]	; store number of channels
	mov	[numChans],ax

	; initialize player internal variables:
	mov	[position],0
	mov	[row],0
	mov	[masterVolume],64
	mov	[playCount],0
	mov	[speed],6		; initial speed is 6
	mov	[tempo],125		; initial BPM tempo is 125
	mov	[pbFlag],0
	mov	[loopRow],0
	mov	[loopFlag],0
	mov	[delayCount],0
	mov	[delayFlag],0
	mov	[skipFlag],0
	mov	[loopCnt],0

	mov	[mpMOD.updRate],5000	; set update rate to 50Hz
	lgs	di,[sdevice]
	call	[gs:di+SoundDevice.SetUpdRate] LANG, 5000
	test	ax,ax
	jnz	@@err


	; Set default panning values for all channels:

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

	; clear player channel structures:
	mov	ax,ds
	mov	es,ax
	mov	di,offset channels
	mov	cx,MPCHANNELS * SIZE modChannel
	xor	al,al
	cld
	rep	stosb

	mov	[mpMOD.status],mpPlaying

	xor	ax,ax			; success
	jmp	@@done

@@err:
	ERROR	ID_modPlayModule

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	int modStopModule(void);
;*
;* Description: Stops playing a module
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	modStopModule	FAR

	mov	[module],0		; point module to NULL for safety
	mov	[mpMOD.status],mpStopped

	xor	ax,ax			; success
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	int modSetInterrupt(void);
;*
;* Description: Starts playing the module using TempoTimer
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	modSetInterrupt 	FAR

	; start playing with the TempoTimer:
	call	tmrPlay LANG, seg modPlay offset modPlay, [sdevice]
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
	ERROR	ID_modSetInterrupt

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	int modRemoveInterrupt(void);
;*
;* Description: Stops playing with the TempoTimer
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	modRemoveInterrupt	FAR

	call	tmrStop LANG		; stop playing the module with timer
	test	ax,ax
	jnz	@@err

	xor	ax,ax			; success
	jmp	@@done

@@err:
	ERROR	ID_modRemoveInterrupt

@@done:
	ret
ENDP






;/***************************************************************************\
;*
;* Function:	int modPlay(void);
;*
;* Description: Plays one "frame" of the module. Usually called from
;*		the timer.
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	modPlay 	FAR
USES	di, si

	inc	[playCount]		; increment player counter
	mov	al,[speed]		; if player counter is equal to the
	cmp	[playCount],al		; speed, it's time to play the song
	jne	@@noplay		; data.

	call	modPlaySong		; play one row of the song data
	test	ax,ax
	jnz	@@err
	jmp	@@ok

@@noplay:
	; Song data is not played - just process the continuous commands
	call	modRunCommands
	test	ax,ax
	jnz	@@err

@@ok:	xor	ax,ax			; success
	jmp	@@done

@@err:
	ERROR	ID_modPlay

@@done:
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	modRunCommands
;*
;* Description: Processes the continuous commands
;*
;* Returns:	MIDAS error code in ax
;*
;\***************************************************************************/

PROC NOLANGUAGE modRunCommands	NEAR

	mov	[chan],0		; set channel number to 0
	mov	di,offset channels	; point ds:di to channel structures
	lgs	si,[sdevice]		; point gs:si to Sound Device

@@chanloop:
	movzx	bx,[di+modChannel.cmd]	; bx = command for this channel
	shl	bx,1
	movzx	ax,[di+modChannel.info] ; ax = command infobyte
	call	[contCmd+bx]		; process the command
	test	ax,ax			; error?
	jnz	@@done			; if yes, pass it on

	add	di,size modChannel	; point ds:di to next channel

	mov	ax,[chan]
	inc	ax			; next channel number
	cmp	ax,[numChans]
	jae	@@no
	mov	[chan],ax
	jmp	@@chanloop

@@no:
	call	modUpdBars		; update "fake" volume bars

	; pass possible error code on
@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	modPlaySong
;*
;* Description: Plays one row of song data
;*
;* Returns:	MIDAS error code in ax
;*
;\***************************************************************************/


PROC	modPlaySong	NEAR
LOCAL	trackNum : word

	mov	[playCount],0		; reset player counter

	cmp	[delayCount],0
	je	@@nodelay

	; pattern delay counter is non-zero. Decrement it and process
	; continuous commands.

	dec	[delayCount]
	call	modRunCommands
	; pass possible error code on
	jmp	@@done


@@nodelay:
	mov	[delayFlag],0		; no pattern delay active
	cmp	[skipFlag],0		; should some rows be skipped?
	je	@@noskip

	call	modSkipRows
	test	ax,ax			; error?
	jnz	@@done			; if yes, pass error code on

@@noskip:
	les	si,[module]		; point es:si to module structure
	mov	bx,[position]

	lgs	di,[es:si+mpModule.orders]	; point gs:di to orders
	movzx	bx,[byte gs:di+bx]		; bx = pattern number

	mov	cx,[numChans]		; cx = number of channels
	imul	bx,cx			; bx = first track number
	mov	[trackNum],bx		; store track number

	mov	di,offset channels	; point ds:di to channel structures

	; process pattern data for all channels:

@@dataloop:
	les	si,[module]		; point es:si to module structure
	mov	al,[di+modChannel.comp] ; al = compression info for current ch
	test	al,40h			; if bit 6 of compression info is 1,
	jz	@@empty 		; rows of same data follow


	and	al,3Fh			; al = number of rows of same data
	jz	@@nocomp		; if zero, go to next row
	dec	[di+modChannel.comp]	; decrease compression counter
	jmp	@@skip			; do not process pattern data

@@empty:
	and	al,3Fh			; al = number of empty rows
	jz	@@nocomp		; if zero, go to next row
	dec	[di+modChannel.comp]	; decrease compression counter

	mov	[di+modChannel.note],0	; no new note
	mov	[di+modChannel.inst],0	; no new instrument
	mov	[di+modChannel.cmd],0	; no new command
	mov	[di+modChannel.info],0	; no new infobyte
	jmp	@@skip			; do not process pattern data


@@nocomp:
	; No compression - process next row of pattern data
	push	di
	mov	bx,[trackNum]
	lgs	di,[es:si+mpModule.pattEMS] ; point gs:di to track EMS flags
	mov	al,[byte gs:di+bx]		 ; al = EMS flag

	lgs	di,[es:si+mpModule.patterns]  ; point gs:di to track pointers
	shl	bx,2
	mov	edx,[gs:di+bx]		; edx = pointer to track memory

	pop	di

	cmp	al,0			; is EMS flag 0?
	je	@@noEMS 		; if so, pattern is not in EMS


	; map pattern data to conventional memory:
	push	cx
	call	emsMap LANG, edx, seg modMemPtr offset modMemPtr
	pop	cx
	test	ax,ax			; error?
	jnz	@@done			; if so, pass it on

	les	si,[modMemPtr]		; point es:si to track in
	jmp	@@dataok		; conventional memory


@@noEMS:
	mov	si,dx
	shr	edx,16			; point es:si to track data
	mov	es,dx

@@dataok:
	add	si,[di+modChannel.playoff]	; add playing position to si

	; es:si now points to current row of track data

	mov	dl,[es:si]		; dl = first data byte
	inc	si

	mov	al,dl
	and	al,7Fh
	cmp	al,01111000b		; if data = x1111000b, the row is
	je	@@emptyrow		; empty

	and	al,01111000b		; if data = x1110xxxb, there is a
	cmp	al,01110000b		; note and an instrument
	je	@@noteInst

	and	al,01110000b		; if data = x110xxxxb, there is a
	cmp	al,01100000b		; command
	je	@@command


	; there is a note, instrument and command:
	mov	al,dl
	and	al,7Eh			; al = note number
	shr	al,1
	mov	[di+modChannel.note],al

	mov	ah,dl			; ah = first data byte
	mov	al,[es:si]		; al = next data byte
	inc	si

	mov	dh,al
        and     dh,0Fh                  ; dh = command number
	mov	[di+modChannel.cmd],dh

	shr	ax,4
	and	ax,1Fh			; ax = instrument number
	mov	[di+modChannel.inst],al

	mov	al,[es:si]
	inc	si			; al = next data byte = command
	mov	[di+modChannel.info],al ; infobyte

	add	[di+modChannel.playoff],3	; 3 bytes played

	jmp	@@checkcomp		; check for compression info


	; there is only a command:
@@command:
	mov	al,dl
	and	al,0Fh			; al = command number
	mov	[di+modChannel.cmd],al

	mov	al,[es:si]
	inc	si			; al = next data byte = command
	mov	[di+modChannel.info],al ; infobyte

	mov	[di+modChannel.note],0	; there is no new note or
	mov	[di+modChannel.inst],0	; instrument

	add	[di+modChannel.playoff],2

	jmp	@@checkcomp


	; there is a note and an instrument:

@@noteInst:
	mov	ah,dl			; ah = first data byte
	mov	al,[es:si]		; al = next
	inc	si

	mov	dh,al			; dh = second data byte
	and	dh,1Fh			; dh = instrument number
	mov	[di+modChannel.inst],dh

	shr	ax,5
	and	ax,3Fh			; al = note number
	mov	[di+modChannel.note],al

	mov	[di+modChannel.cmd],0	; no command
	mov	[di+modChannel.info],0	; no infobyte

	add	[di+modChannel.playoff],2

	jmp	@@checkcomp


	; empty row:

@@emptyrow:
	mov	[di+modChannel.note],0	; no new note
	mov	[di+modChannel.inst],0	; no new instrument
	mov	[di+modChannel.cmd],0	; no new command
	mov	[di+modChannel.info],0	; no new infobyte
	inc	[di+modChannel.playoff]

@@checkcomp:
	test	dl,80h			; if bit 7 of first data byte is 1,
	jz	@@skip
	mov	al,[es:si]		; a compression info byte follows
	inc	si
	mov	[di+modChannel.comp],al ; store it
	inc	[di+modChannel.playoff] ; one more byte played

@@skip:
	inc	[trackNum]		; next channel
	add	di,SIZE modChannel	; point ds:di to next channel
	loop	@@dataloop

	les	si,[module]
	call	modSave 		; save values for GetInformation()


	; Process possible new values on all channels:

	mov	[chan],0		; channel number = 0
	mov	di,offset channels	; point ds:di to channel structures
	lgs	si,[sdevice]		; point gs:si to Sound Device


@@chanloop:
	xor	bx,bx
	mov	bl,[di+modChannel.inst] 	; check if there is a new
	test	bl,bl				; instrument
	jz	@@nonewinst

	mov	[di+modChannel.sample],bl	; set instrument number

	push	si
	les	si,[module]
	les	si,[es:si+mpModule.insts]	; point es:si to instruments
	dec	bx
	imul	bx,bx,SIZE mpInstrument 	; bx = offset in instruments
	add	si,bx				; point es:si to new inst
	mov	al,[es:si+mpInstrument.volume]		; al = volume
	mov	bx,[es:si+mpInstrument.sdInstHandle]	; bx = SD inst handle
	pop	si

	mov	[di+modChannel.volume],al	; set new volume
	or	[di+modChannel.status],1	; status bit 0 = 1 - new inst
	mov	[di+modChannel.coff],0		; current Sample Offset = 0

	mov	ax,[chan]		; ax = Sound Device channel number
	add	ax,[firstSDChan]

	; set Sound Device instrument:
	push	gs
	call	[gs:si+SoundDevice.SetInstrument] LANG, ax, bx
	pop	gs
	test	ax,ax			; error?
	jnz	@@done			; if so, pass it on


	cmp	[masterVolume],64	; is master volume 64
	je	@@nonewinst		; if so, current volume is OK

	mov	al,[di+modChannel.volume]
	call	SetSDVolume		; set volume to Sound Device
	test	ax,ax
	jnz	@@done


@@nonewinst:
	movzx	dx,[di+modChannel.note]
	test	dx,dx			; is there a new note?
	jz	@@nonewnote

	movzx	bx,[di+modChannel.sample]	; bx = current instrument
	test	bx,bx
	jz	@@nonewnote

	push	si

	les	si,[module]
	les	si,[es:si+mpModule.insts]
	dec	bx			; point es:si to current instrument
	imul	bx,bx,SIZE mpInstrument
	add	si,bx

	mov	al,[es:si+mpInstrument.finetune]   ; al = instrument finetune
	pop	si

	dec	dx
	add	dx,dx
	mov	bl,12*3*2
	mul	bl			; bx = period table offset for
	mov	bx,ax			; new note
	add	bx,dx

	mov	[di+modChannel.snote],bx	; store period table offset
	mov	bx,[Periods+bx] 	; bx = period number for this note

	; check if current command is a tone portamento:
	mov	al,[di+modChannel.cmd]
	cmp	al,3			; Tone Portamento
	je	@@tport
	cmp	al,5			; Tone Portamento + VSlide
	je	@@tport

	mov	[di+modChannel.period],bx	; save period
	or	[di+modChannel.status],3	; status bit 1 = 1 - new note

	mov	ah,[di+modChannel.cmd]
	mov	al,[di+modChannel.info]
	and	ax,0FF0h		; is current command ED (Note Delay)?
	cmp	ax,0ED0h
	je	@@notedone		; if is, do not set note


	movzx	ebx,bx
	mov	eax,3546895		; eax = PAL clock constant
	cdq				; PAL clock constant / period
	idiv	ebx			; = playing rate

	mov	ebx,eax 		; ebx = playing rate

	mov	ax,[chan]		; ax = SD channel number
	add	ax,[firstSDChan]

	cmp	[di+modChannel.cmd],9	; is command 9 (sample offset)
	je	@@smpoff

	mov	[di+modChannel.vibpos],0	; clear vibrato position
	mov	[di+modChannel.trepos],0	; clear tremolo position

	cmp	[di+modChannel.coff],0	; if current sample offset is != 0,
	jne	@@dooffset		; do not set position

	; Start playing sound with rate ebx:
	push	es gs
	call	[gs:si+SoundDevice.PlaySound] LANG, ax, ebx
	pop	gs es
	test	ax,ax
	jnz	@@done

	jmp	@@notedone


@@dooffset:
	; sample offset - only set playing rate
	push	es gs
	call	[gs:si+SoundDevice.SetRate] LANG, ax, ebx
	pop	gs es
	test	ax,ax
	jnz	@@done

	jmp	@@setoffset

@@smpoff:
	; sample offset command
	push	es gs
	call	[gs:si+SoundDevice.SetRate] LANG, ax, ebx
	pop	gs es
	test	ax,ax
	jnz	@@done

	mov	bh,[di+modChannel.info] 	; if command infobyte is 0,
	test	bh,bh				; use previous sample offset
	jnz	@@so1				; value as new offset
	mov	bh,[di+modChannel.loff]

@@so1:
	mov	[di+modChannel.loff],bh 	; save current sample offset
	add	[di+modChannel.coff],bh 	; add infobyte to offset

@@setoffset:
	; set sample offset
	xor	bl,bl			; bx = new sample playing position
	mov	bh,[di+modChannel.coff]

	mov	ax,[chan]		; ax = SD channel number
	add	ax,[firstSDChan]

	; set playing position:
	push	es gs
	call	[gs:si+SoundDevice.SetPosition] LANG, ax, bx
	pop	gs es
	test	ax,ax
	jnz	@@done

	jmp	@@notedone


@@tport:
	; tone portamento
	mov	[di+modChannel.toperi],bx	; store period as slide dest
	jmp	@@notedone


@@nonewnote:
	; no new note - reset period and volume

	; set period:
	call	SetPeriod
	test	ax,ax
	jnz	@@done

	; set volume:
	mov	al,[di+modChannel.volume]
	call	SetSDVolume
	test	ax,ax
	jnz	@@done


@@notedone:
	movzx	bx,[di+modChannel.cmd]	; bx = command number
	add	bx,bx
	movzx	ax,[di+modChannel.info] ; ax = command infobyte
	call	[commands+bx]		; process command
	test	ax,ax
	jnz	@@done

	add	di,size modChannel	; point ds:di to next channel

	mov	ax,[chan]
	inc	ax			; next channel number
	cmp	ax,[numChans]
	jae	@@no
	mov	[chan],ax
	jmp	@@chanloop

@@no:	cmp	[pbFlag],0
	jne	@@break

	inc	[row]			; next row
	cmp	[row],64		; did we reach pattern end?
	jb	@@noend

	mov	[row],0

	; pattern end - reset playing offset and compression info on
	; all channels:

@@break:
	mov	cx,[numChans]
	mov	di,offset channels
@@l1:	mov	[di+modChannel.playoff],0
	mov	[di+modChannel.comp],0
	add	di,size modChannel
	loop	@@l1

	inc	[position]		; next song position

	mov	bx,[songLength]
	cmp	[position],bx		; did we reach song end?
	jb	@@noend

	mov	[position],0		; restart song
	inc	[loopCnt]		; increase song loop conter

@@noend:
	mov	[pbFlag],0		; clear pattern break flag
	call	modUpdBars		; update volume bars

	xor	ax,ax			; success
@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	SetSDVolume
;*
;* Description: Sets SD volume to current channel, scaled according to
;*		masterVolume
;*
;* Input:	al		volume
;*
;* Returns:	MIDAS error code in ax
;*
;\***************************************************************************/

PROC	SetSDVolume	NEAR

	mul	[masterVolume]		; bx = volume scaled according to
	shr	ax,6			; master volume
	mov	bx,ax

	mov	ax,[chan]		; ax = Sound Device channel number
	add	ax,[firstSDChan]

	; set Sound Device volume:
	push	gs
	call	[gs:si+SoundDevice.SetVolume] LANG, ax, bx
	pop	gs

	; pass possible error code on

	ret
ENDP



;/***************************************************************************\
;*
;* Function:	SetSDPeriod
;*
;* Description: Sets Sound Device playing period for current channel
;*
;* Input:	ebx		period number
;*
;* Returns:	MIDAS error code in ax
;*
;\***************************************************************************/

PROC	SetSDPeriod	NEAR

	test	ebx,ebx 			; skip if zero period
	jz	@@ok

	movzx	ebx,bx
	mov	eax,3546895		; eax = PAL clock constant
	cdq				; PAL clock constant / period
	idiv	ebx			; = playing rate

	mov	ebx,eax 		; ebx = playing rate

	mov	ax,[chan]		; ax = SD channel number
	add	ax,[firstSDChan]

	; Set Sound Device playing rate:
	push	gs
	call	[gs:si+SoundDevice.SetRate] LANG, ax, ebx
	pop	gs

	; pass possible error code on
	jmp	@@done

@@ok:
	xor	ax,ax

@@done:
	ret
ENDP





;/***************************************************************************\
;*	Protracker command processing:
;\***************************************************************************/


; Command F - Set Speed

PROC	SetSpeed	NEAR

	test	al,al			; skip if zero speed
	jz	@@ok

	cmp	[ptTempo],1		; are BPM tempos used?
	jne	@@speed 		; if not, value is always speed

	cmp	al,32			; is infobyte >= 32?
	jbe	@@speed

	; infobyte >= 32 - it is the BPM tempo, not speed

	mov	[tempo],al		; store new tempo
	xor	ah,ah

	mov	bx,40
	mul	bx			; ax = update rate in 100*Hz
	mov	[mpMOD.updRate],ax
	mov	bx,ax

	; set Sound Device update rate:
	push	gs bx
	call	[gs:si+SoundDevice.SetUpdRate] LANG, bx
	pop	bx gs
	test	ax,ax
	jnz	@@done

	; set timer update rate:
	push	gs
	call	tmrSetUpdRate LANG, bx		; set timer update rate
	pop	gs

	jmp	@@done

@@speed:
	mov	[speed],al		; set speed

@@ok:	xor	ax,ax
@@done:
	ret
ENDP




; Command B - Position Jump

PROC	PositionJump	NEAR

	cmp	[position],ax		; is jump forward?
	jl	@@fwd

	inc	[loopCnt]		; no, increase song loop counter

@@fwd:
	dec	ax
	mov	[position],ax		; set new position
	mov	[pbFlag],1		; break to new pattern
	mov	[row],0 		; start from row 0
	xor	ax,ax			; success
	ret
ENDP



; Command D - Pattern Break

PROC	PatternBreak	NEAR

	mov	ah,al
	and	al,0fh
	shr	ah,4			; ax = new row (infobyte is in
	aad				; BCD)
	cmp	ax,63
	jbe	@@ok
	mov	ax,63
@@ok:	mov	[row],ax		; store new row

	mov	[skipFlag],1		; skip rows next time
	mov	[pbFlag],1		; break pattern flag on
	xor	ax,ax
	ret
ENDP




; Command C - Set Volume

PROC	SetVolume	NEAR

	cmp	al,64
	jbe	@@vok			; make sure volume is <= 64
	mov	al,64

@@vok:
	mov	[di+modChannel.volume],al
	call	SetVol

	; pass possible error code on
	ret
ENDP




; Command A - Volume Slide

PROC	VolumeSlide	NEAR

	mov	bl,[di+modChannel.volume]	; bl = current volume

	test	al,0F0h
	jnz	@@add

	; Upper nybble of infobyte is 0 - substract lower from volume
	sub	bl,al
	jns	@@setv
	xor	bl,bl
	jmp	@@setv

@@add:
	; Upper nybble of infobyte is nonzero - add it to volume
	shr	al,4
	add	bl,al
	cmp	bl,64
	jle	@@setv
	mov	bl,64
@@setv:
	or	[di+modChannel.status],1
	mov	[di+modChannel.volume],bl
	mov	al,bl
	call	SetSDVolume

	; pass possible error value on

	ret
ENDP




; Command E2 - Fine Slide Down

PROC	FineSlideDown	NEAR

	and	ax,0Fh
	cmp	[playCount],0		; no only if playCount is zero
	jne	@@ok

	call	SlideDown
	jmp	@@done

@@ok:
	xor	ax,ax			; success

@@done:
	ret
ENDP




; Command 2 - Slide Down

PROC	SlideDown NEAR

	add	[di+modChannel.period],ax
	call	CheckLimits
	call	SetPeriod
	ret
ENDP



; Command E1 - Fine Slide Up

PROC	FineSlideUp NEAR

	and	ax,0Fh
	cmp	[playCount],0		; no only if playCount is zero
	jne	@@ok

	call	SlideUp
	jmp	@@done

@@ok:
	xor	ax,ax			; success

@@done:
	ret
ENDP




; Command 1 - Slide Up

PROC	SlideUp 	NEAR
	sub	[di+modChannel.period],ax
	call	CheckLimits
	call	SetPeriod
	ret
ENDP



; make sure channel period is within limits

PROC	CheckLimits	NEAR

	cmp	[di+modChannel.period],113
	jge	@@ok1
	mov	[di+modChannel.period],113
@@ok1:
	cmp	[di+modChannel.period],856
	jle	@@ok2
	mov	[di+modChannel.period],856
@@ok2:
	ret
ENDP




; Command 3 - Tone Portamento

PROC	TonePortamento NEAR

	test	ax,ax			; is infobyte 0?
	jnz	@@1

	movzx	ax,[di+modChannel.notepsp]	; if yes, use old speed

@@1:	mov	[di+modChannel.notepsp],al	; store portamento speed
	mov	bx,[di+modChannel.toperi]
	test	bx,bx				; portamento destination zero?
	jz	@@setperiod			; if yes, skip

	cmp	[di+modChannel.period],bx	; should we slide up?
	jg	@@up

	; slide down:
	add	[di+modChannel.period],ax	; increase period
	cmp	[di+modChannel.period],bx	; past portamento dest?
	jl	@@setperiod
	mov	[di+modChannel.period],bx	; if yes, set to porta dest
	mov	[di+modChannel.toperi],0	; do not slide anymore
	jmp	@@setperiod

@@up:
	; slide up:
	sub	[di+modChannel.period],ax	; decrease period
	cmp	[di+modChannel.period],bx	; past portamento dest?
	jg	@@setperiod
	mov	[di+modChannel.period],bx	; if yes, set to porta dest
	mov	[di+modChannel.toperi],0	; do not slide anymore

@@setperiod:
	call	SetPeriod
	ret
ENDP



; Set period on channel to Sound Device

PROC	SetPeriod	NEAR

	movzx	ebx,[di+modChannel.period]

	; Set Sound Device period:
	call	SetSDPeriod

	ret
ENDP



; Command 4 - Vibrato

PROC	Vibrato 	NEAR

	test	al,0Fh			; is new vibrato depth non-zero?
	jnz	@@1

	mov	bl,[di+modChannel.vibcmd]	; bl = old vibrato infobyte
	and	bl,0Fh		       ; no, set old vibrato depth
	or	al,bl

@@1:
	test	al,0F0h 		; is new vibrato speed non-zero?
	jnz	@@2

	mov	bl,[di+modChannel.vibcmd]	; bl = old vibrato infobyte
	and	bl,0F0h 		 ; no, set old vibrato speed
	or	al,bl

@@2:
	mov	[di+modChannel.vibcmd],al	; store new vibrato infobyte

	mov	bl,[di+modChannel.vibpos]	; bx = vibrato table position
	and	bx,1Fh
	xor	eax,eax
	mov	al,[vibratoTable+bx]	; eax = vibrato value
	mov	cl,[di+modChannel.vibcmd]
	and	cl,0Fh			; multiply with depth
	mul	cl
	shr	ax,7			; divide with 128

	movzx	ebx,[di+modChannel.period]	; ebx = channel base period

	test	[di+modChannel.vibpos],32      ; is vibrato position >= 32?
	jnz	@@vibneg

	; vibrato position < 32 - positive
	add	ebx,eax
	jmp	@@setperiod

@@vibneg:
	; vibrato position >= 32 - negative
	sub	ebx,eax

@@setperiod:
	mov	al,[di+modChannel.vibcmd]	; add vibrato speed  to
	shr	al,4
	add	[di+modChannel.vibpos],al	; vibrato position

	; Set period to Sound Device:
	call	SetSDPeriod

	ret
ENDP




; Command 0 - Arpeggio

PROC	Arpeggio	NEAR

	test	ax,ax			; is infobyte zero?
	jz	@@ok			; skip if is

	mov	dx,ax			; save infobyte

	mov	bx,[di+modChannel.snote]    ; bx = base index to period table

	movzx	ax,[playCount]
	mov	cl,3			; divide player counter with 3
	div	cl
	test	ah,ah			; is modulus zero?
	jz	@@a0			; if yes, use base note
	dec	ah			; is modulus one?
	jz	@@a1			; if yes, use infobyte upper nybble

	; modulus is 2 - use infobyte lower nybble
	and	dx,0Fh
	add	dx,dx			; add infobyte lower nybble to note
	add	bx,dx
	jmp	@@a0

@@a1:
	; modulus is 1 - use infobyte upper nybble
	shr	dx,4
	add	dx,dx			; add infobyte upper nybble to note
	add	bx,dx

@@a0:
	movzx	ebx,[Periods+bx]	; get period value

	; set period to Sound Device:
	call	SetSDPeriod
	jmp	@@done

@@ok:
	xor	ax,ax

@@done:
	ret
ENDP



; Command 5 - Tone Portamento and Volume Slide

PROC	TPortVSlide	NEAR

	call	VolumeSlide		; do volume slide
	test	ax,ax
	jnz	@@done

	xor	ax,ax
	call	TonePortamento		; do tone portamento with 0 infobyte

@@done:
	ret
ENDP




; Command 6 - Vibrato and Volume Slide

PROC	VibratoVSlide	NEAR

	call	VolumeSlide		; do volume slide
	test	ax,ax
	jnz	@@done

	xor	ax,ax
	call	Vibrato 		; do vibrato with 0 infobyte

@@done:
	ret
ENDP



; Command 8 - Set Panning

PROC	SetPanning NEAR

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


; Command E8 - 16-Step Set Panning

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


; Command E9 - Retrig Note

PROC	SetRetrigNote NEAR

	mov	[di+modChannel.retrigc],1

	xor	ax,ax
	ret
ENDP



PROC	RetrigNote NEAR

	cmp	[playCount],0		; playing song data?
	jne	@@noset

	call	SetRetrigNote		; yes, just set count
	jmp	@@done

@@noset:
	and	al,0Fh			; should note be retrigged?
	cmp	[di+modChannel.retrigc],al	; (retrig count = infobyte)
	jb	@@no

	or	[di+modChannel.status],3	; note triggered
	mov	[di+modChannel.retrigc],1	; reset retrig count

	mov	ax,[chan]		; ax = Sound Device channel number
	add	ax,[firstSDChan]

	; Start from beginning of sample:
	push	gs
	call	[gs:si+SoundDevice.SetPosition], ax, 0
	pop	gs
	jmp	@@done

@@no:	inc	[di+modChannel.retrigc]
	xor	ax,ax

@@done:
	ret
ENDP




; Command 7 - Tremolo

PROC	Tremolo 	NEAR

	test	al,0Fh			; is new tremolo depth non-zero?
	jnz	@@1

	mov	bl,[di+modChannel.trecmd]	; bl = old tremolo infobyte
	and	bl,0Fh		       ; no, set old tremolo depth
	or	al,bl

@@1:
	test	al,0F0h 		; is new tremolo speed non-zero?
	jnz	@@2

	mov	bl,[di+modChannel.trecmd]	; bl = old tremolo infobyte
	and	bl,0F0h 		 ; no, set old tremolo speed
	or	al,bl

@@2:
	mov	[di+modChannel.trecmd],al	; store new tremolo infobyte

	mov	bl,[di+modChannel.trepos]	; bx = tremolo table position
	and	bx,1Fh
	xor	eax,eax
	mov	al,[vibratoTable+bx]	; eax = tremolo value
	mov	cl,[di+modChannel.trecmd]
	and	cl,0Fh			; multiply with depth
	mul	cl
	shr	ax,7			; divide with 128


	movzx	bx,[di+modChannel.volume]	; bx = channel base volume

	test	[di+modChannel.trepos],32      ; is position >= 32 ?
	jnz	@@neg

	; Position < 32 - positive
	add	bx,ax
	jmp	@@setvol

@@neg:
	; Position >= 32 - negative
	sub	bx,ax

@@setvol:
	mov	al,[di+modChannel.trecmd]
	shr	al,4				; add tremolo speed to
	add	[di+modChannel.trepos],al	; vibrato position

	or	[di+modChannel.status],1

	; Make sure volume is within limits:
	cmp	bx,0
	jge	@@11
	xor	bx,bx
@@11:
	cmp	bx,64
	jle	@@22
	mov	bx,64
@@22:
	mov	al,bl
	; Set volume to Sound Device:
	call	SetSDVolume

	ret
ENDP




; Command E - extended commands. Infobyte upper nybble is command number

PROC	ECommand NEAR

	mov	bl,al
        and     bx,0F0h
	shr	bx,3			; bx = index to offset table
	and	ax,0Fh			; al = infobyte
	call	[ecmds+bx] LANG 	; process command

	ret
ENDP



; Command E6 - Pattern Loop

PROC	PatternLoop NEAR

	cmp	[playCount],0		; do only when playing song data
	jne	@@ok

	cmp	al,0			; if infobyte is zero, set loop
	je	@@setloop		; starting row

	cmp	[loopFlag],0		; already looping?
	je	@@setcount

	dec	[loopCount]		; yes, just decrease loop counter
	jnz	@@loop			; counter zero?
	mov	[loopFlag],0		; yes, do not loop anymore
	jmp	@@ok

@@loop:
	mov	ax,[loopRow]
	dec	ax			; loop to saved row
	mov	[row],ax
	mov	[skipFlag],1		; skip to new row next time
	jmp	@@ok

@@setcount:
	; start looping - set loop counter
	mov	[loopCount],al		; loop counter = infobyte
	mov	ax,[loopRow]
	dec	ax			; loop to saved row
	mov	[row],ax
	mov	[loopFlag],1		; looping
	mov	[skipFlag],1		; skip to new row next time
	jmp	@@ok

@@setloop:
	mov	ax,[row]		; save current row as loop destination
	mov	[loopRow],ax
@@ok:
	xor	ax,ax
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	modSkipRows
;*
;* Description: Skips to current row in pattern data
;*
;* Returns:	MIDAS error code in ax
;*
;\***************************************************************************/

PROC	modSkipRows	NEAR
LOCAL	skipCount : word, chanCount : word, trackNum : word

	mov	di,offset channels	; point ds:di to channel structures

	mov	cx,[numChans]

	; Reset playing offset and compression info from all channels:
@@clearlp:
	mov	[di+modChannel.playoff],0
	mov	[di+modChannel.comp],0
	add	di,size modChannel
	loop	@@clearlp


	les	si,[module]		; point es:si to module structure
	mov	bx,[position]
	lgs	di,[es:si+mpModule.orders]	; point gs:di to orders
	movzx	ax,[byte gs:di+bx]		; ax = current pattern

	mul	[numChans]		; ax = current track number
	mov	[trackNum],ax		; save track number

	mov	di,offset channels	; point ds:di to channel structures

	mov	ax,[numChans]
	mov	[chanCount],ax		; set channel counter


@@chanloop:
	mov	[skipCount],0		; set skipped rows counter to 0

	cmp	[row],0 		; should we skip to row 0?
	je	@@endskip		; if so, we are finished skipping

	les	si,[module]		; point es:si to module structure

	mov	bx,[trackNum]		; bx = current track number
	push	di
	lgs	di,[es:si+mpModule.pattEMS] ; point gs:di to track EMS flags
	mov	al,[byte gs:di+bx]		 ; al = EMS flag

	lgs	di,[es:si+mpModule.patterns]  ; point gs:di to track pointers
	shl	bx,2
	mov	edx,[gs:si+bx]		; edx = pointer to track memory

	pop	di

	cmp	al,0			; is EMS flag 0?
	je	@@noEMS 		; if so, pattern is not in EMS


	; map pattern data to conventional memory:
	call	emsMap LANG, edx, seg modMemPtr offset modMemPtr
	test	ax,ax			; error?
	jnz	@@done			; if so, pass it on

	les	si,[modMemPtr]		; point es:si to track in
	jmp	@@dataok		; conventional memory


@@noEMS:
	mov	si,dx
	shr	edx,16			; point es:si to track data
	mov	es,dx

@@dataok:
	add	si,[di+modChannel.playoff]	; add playing position to si


	; now skip rows:
@@rowloop:
	mov	ax,[skipCount]		; ax = number of rows skipped
	cmp	[row],ax		; are we at correct row?
	je	@@endskip		; if so, we are finished

	mov	al,[di+modChannel.comp] ; al = compression info for current ch
	test	al,40h			; if bit 6 of compression info is 1,
	jz	@@empty 		; rows of same data follow


	and	al,3Fh			; al = number of rows of same data
	jz	@@nocomp		; if zero, go to next row
	dec	[di+modChannel.comp]	; decrease compression counter
	jmp	@@skip			; do not process pattern data

@@empty:
	and	al,3Fh			; al = number of empty rows
	jz	@@nocomp		; if zero, go to next row
	dec	[di+modChannel.comp]	; decrease compression counter

	mov	[di+modChannel.note],0	; no new note
	mov	[di+modChannel.inst],0	; no new instrument
	mov	[di+modChannel.cmd],0	; no new command
	mov	[di+modChannel.info],0	; no new infobyte
	jmp	@@skip			; do not process pattern data


@@nocomp:
	; no compression - process next row of pattern data
	mov	dl,[es:si]		; dl = first data byte
	inc	si

	mov	al,dl
	and	al,7Fh
	cmp	al,01111000b		; if data = x1111000b, the row is
	je	@@emptyr		; empty

	and	al,01111000b		; if data = x1110xxxb, there is a
	cmp	al,01110000b		; note and an instrument
	je	@@noteInst

	and	al,01110000b		; if data = x110xxxxb, there is a
	cmp	al,01100000b		; command
	je	@@command


	; there is a note, instrument and command:
	mov	al,dl
	and	al,7Eh			; al = note number
	shr	al,1
	mov	[di+modChannel.note],al

	mov	ah,dl			; ah = first data byte
	mov	al,[es:si]		; al = next data byte
	inc	si

	mov	dh,al
	and	dh,0Fh			; dh = command number
	mov	[di+modChannel.cmd],dh

	shr	ax,4
	and	ax,1Fh			; ax = instrument number
	mov	[di+modChannel.inst],al

	mov	al,[es:si]
	inc	si			; al = next data byte = command
	mov	[di+modChannel.info],al ; infobyte

	add	[di+modChannel.playoff],3	; 3 bytes played

	jmp	@@checkcomp		; check for compression info


	; there is only a command:
@@command:
	mov	al,dl
	and	al,0fh			; al = command number
	mov	[di+modChannel.cmd],al

	mov	al,[es:si]
	inc	si			; al = next data byte = command
	mov	[di+modChannel.info],al ; infobyte

	mov	[di+modChannel.note],0	; there is no new note or
	mov	[di+modChannel.inst],0	; instrument

	add	[di+modChannel.playoff],2

	jmp	@@checkcomp


	; there is a note and an instrument:
@@noteInst:
	mov	ah,dl			; ah = first data byte
	mov	al,[es:si]		; al = next
	inc	si

	mov	dh,al			; dh = second data byte
	and	dh,1Fh			; dh = instrument number
	mov	[di+modChannel.inst],dh

	shr	ax,5
	and	ax,3Fh			; al = note number
	mov	[di+modChannel.note],al

	mov	[di+modChannel.cmd],0	; no command
	mov	[di+modChannel.info],0	; no infobyte

	add	[di+modChannel.playoff],2

	jmp	@@checkcomp


	; empty row:
@@emptyr:
	mov	[di+modChannel.note],0	; no new note
	mov	[di+modChannel.inst],0	; no new instrument
	mov	[di+modChannel.cmd],0	; no new command
	mov	[di+modChannel.info],0	; no new infobyte
	inc	[di+modChannel.playoff]

@@checkcomp:
	test	dl,80h			; if bit 7 of first data byte is 1,
	jz	@@skip
	mov	al,[es:si]		; a compression info byte follows
	inc	si
	mov	[di+modChannel.comp],al ; store it
	inc	[di+modChannel.playoff] ; one more byte played


@@skip:
	; one row of data processed
	inc	[skipCount]
	jmp	@@rowloop



@@endskip:
	; all rows succesfully skipped for this channel - we are now playing
	; at the correct row
	inc	[trackNum]		; next track
	add	di,SIZE modChannel	; next channel

	dec	[chanCount]
	jnz	@@chanloop

	mov	[skipFlag],0		; do not skip data now

	xor	ax,ax

@@done:
	ret
ENDP



; Command EA - Fine Volume Slide Up

PROC	FineVolumeSlideUp NEAR

	cmp	[playCount],0		; do only when playing song data
	jne	@@ok

	add	[di+modChannel.volume],al	; add infobyte to volume
	cmp	[di+modChannel.volume],64	; make sure volume is within
	jle	@@set				; limits (<= 64)
	mov	[di+modChannel.volume],64

@@set:
	call	SetVol
	jmp	@@done

@@ok:
	xor	ax,ax

@@done:
	ret
ENDP




; Command EB - Fine Volume Slide Down

PROC	FineVolumeSlideDown	NEAR

	cmp	[playCount],0		; do only when playing song data
	jne	@@ok

	sub	[di+modChannel.volume],al	; substract infobyte from vol
	cmp	[di+modChannel.volume],0	; make sure volume is positive
	jge	@@set
	mov	[di+modChannel.volume],0

@@set:
	call	SetVol
	jmp	@@done

@@ok:
	xor	ax,ax

@@done:
	ret
ENDP




; Command EC - Note Cut

PROC	NoteCut 	NEAR

	cmp	[playCount],al		; cut note when play counter is equal
	jne	@@ok			; to infobyte

	; Cut note by setting colume to zero:
	mov	[di+modChannel.volume],0
	call	SetVol
	jmp	@@done

@@ok:
	xor	ax,ax

@@done:
	ret
ENDP



; Command ED - Note Delay

PROC	NoteDelay	NEAR

	cmp	[playCount],al		; start note when player count is
	jne	@@ok			; equal to infobyte

	movzx	ebx,[di+modChannel.period]	; ebx = period
	test	bx,bx				; skip if zero period
	jz	@@ok

	or	[di+modChannel.status],3	; note set

	movzx	ebx,bx
	mov	eax,3546895		; eax = PAL clock constant
	cdq				; PAL clock constant / period
	idiv	ebx			; = playing rate

	mov	ebx,eax 		; ebx = playing rate

	mov	ax,[chan]		; ax = SD channel number
	add	ax,[firstSDChan]

	; Start playing sound:
	push	gs
	call	[gs:si+SoundDevice.PlaySound] LANG, ax, ebx
	pop	gs
	jmp	@@done

@@ok:
	xor	ax,ax

@@done:
	ret
ENDP




; Command EE - Pattern Delay

PROC	PatternDelay	NEAR

	cmp	[delayFlag],0		; do not set delay counter if pattern
	jne	@@ok			; delay is already active

	mov	[delayCount],al 	; pattern delay count = infobyte
	mov	[delayFlag],1		; pattern delay active

@@ok:
	xor	ax,ax

	ret
ENDP




;/***************************************************************************\
;*
;* Function:	SetVol
;*
;* Description: Sets current channel volume to Sound Device
;*
;* Returns:	MIDAS error code in ax
;*
;\***************************************************************************/

PROC	SetVol		NEAR

	or	[di+modChannel.status],1	; volume set
	mov	al,[di+modChannel.volume]	; al = channel volume
	mov	bl,[masterVolume]
	mul	bl
	shr	ax,6				; bx = volume scaled according
	mov	bx,ax				; to master volume

	mov	ax,[chan]		; ax = Sound Device channel number
	add	ax,[firstSDChan]

	; Set Sound Device playing volume:
	push	gs
	call	[gs:si+SoundDevice.SetVolume] LANG, ax, bx
	pop	gs

	ret
ENDP




; Do nothing - just clear ax to mark success

PROC	DoNothing	NEAR

	xor	ax,ax
	ret
ENDP




;/***************************************************************************\
;*     Calling offset tables to commands:
;\***************************************************************************/

	; Commands run when song data is played:
LABEL	commands	WORD
	DW	offset Arpeggio
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset Vibrato
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset Tremolo
	DW	offset SetPanning
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset PositionJump
	DW	offset SetVolume
	DW	offset PatternBreak
	DW	offset ECommand
	DW	offset SetSpeed

	; Continuous commands, run when song data is not played:
LABEL	contCmd 	WORD
	DW	offset Arpeggio
	DW	offset SlideUp
	DW	offset SlideDown
	DW	offset TonePortamento
	DW	offset Vibrato
	DW	offset TPortVSlide
	DW	offset VibratoVSlide
	DW	offset Tremolo
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset VolumeSlide
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset ECommand
	DW	offset DoNothing

	; Protracker extended E-commands:
LABEL	ecmds		WORD
	DW	offset DoNothing
	DW	offset FineSlideUp
	DW	offset FineSlideDown
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset DoNothing
	DW	offset PatternLoop
	DW	offset DoNothing
	DW	offset SetPanning16
	DW	offset RetrigNote
	DW	offset FineVolumeSlideUp
	DW	offset FineVolumeSlideDown
	DW	offset NoteCut
	DW	offset NoteDelay
	DW	offset PatternDelay
	DW	offset DoNothing

ENDP



;/***************************************************************************\
;*
;* Function:	int modSetPosition(ushort pos)
;*
;* Description: Jumps to a specified position in module
;*
;* Input:	ushort	pos		Position to jump to
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	modSetPosition	FAR	pos : word
USES	di

	mov	ax,[pos]		; ax = new position

	cmp	ax,0			; new position negative?
	jge	@@ok1
	mov	ax,[songLength] 	; if is, set to end of song
	dec	ax

@@ok1:
	mov	[position],ax		; set new position
	mov	[poss],ax

	mov	[row],0 		; start from row 0

	mov	bx,[songLength]
	cmp	[position],bx		; is position past song end?
	jl	@@ok2

	mov	[position],0		; if is, start from the beginning

@@ok2:
	; clear playing offset and compression info from all channels:

	mov	cx,[numChans]
	mov	di,offset channels
@@chanloop:
	mov	[di+modChannel.playoff],0
	mov	[di+modChannel.comp],0
	add	di,size modChannel
	loop	@@chanloop

	mov	[pbFlag],0		; clear pattern break and loop
	mov	[loopFlag],0		; flags

	xor	ax,ax			; success

	ret
ENDP




;/***************************************************************************\
;*
;* Function:	int modGetInformation(mpInformation *info);
;*
;* Description: Fills the Module Player information structure
;*
;* Input:	mpInformation *info	information structure to be filled
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	modGetInformation	FAR	info : dword
USES	si,di,ds

	les	si,[info]		; point es:si to information structure
	mov	di,offset channels	; point ds:di to channel structures

	mov	ax,[setFrame]
	mov	[es:si+mpInformation.setFrame],ax      ; copy set-frame flag
	mov	[setFrame],0			; set set-frame flag to 0

	mov	ax,[rows]
	mov	[es:si+mpInformation.row],ax
	mov	ax,[poss]			; copy saved row, position and
	mov	[es:si+mpInformation.pos],ax	       ; pattern numbers
	mov	ax,[pats]
	mov	[es:si+mpInformation.pattern],ax

	movzx	ax,[speed]
	mov	[es:si+mpInformation.speed],ax	       ; copy speed and tempo values
	movzx	ax,[tempo]
	mov	[es:si+mpInformation.BPM],ax

	movzx	ax,[loopCnt]			; copy song loop counter
	mov	[es:si+mpInformation.loopCnt],ax

	mov	cx,[es:si+mpInformation.numChannels]   ; cx = number of channels
	les	si,[es:si+mpInformation.chans]	       ; es:si points to channel
						; information structure

@@chanloop:
	mov	[es:si+mpChanInfo.flags],0	; clear channel info flags

	mov	ax,[di+modChannel.snote]	; ax = current period table
						; index
	mov	bl,12*3*2
	div	bl				; convert ax to note number
	mov	al,ah
	xor	ah,ah
	shr	ax,1

	mov	bl,12				; divide note number with 12
	div	bl				; al = octave, ah = note

	inc	al
	shl	al,4				; set octave to upper nybble
	or	al,ah				; and note to lower

	mov	[es:si+mpChanInfo.note],al	; store note and octave

	or	[es:si+mpChanInfo.flags],32


	mov	al,[di+modChannel.sample]		; copy current
	mov	[es:si+mpChanInfo.instrument],al	; instrument number
	or	[es:si+mpChanInfo.flags],32

	mov	al,[di+modChannel.info] 		; copy command
	mov	[es:si+mpChanInfo.infobyte],al		; infobyte

	mov	al,[di+modChannel.volume]		; copy volume
	mov	[es:si+mpChanInfo.volume],al

	mov	al,[di+modChannel.volbar]		; copy volume bar
	mul	[masterVolume]
	shr	ax,6
	mov	[es:si+mpChanInfo.volumebar],al

	mov	al,[di+modChannel.cmd]
	and	al,0Fh				; if command number is
	jnz	@@cmd				; non-zero, or infobyte is
	cmp	[di+modChannel.info],0		; non-zero, there is a command
	jne	@@cmd

	; no command - point commandname to empty string:
	mov	[es:si+mpChanInfo.command],0
	mov	[word es:si+mpChanInfo.commandname],offset strNoCmd
	mov	[word es:si+2+mpChanInfo.commandname],seg strNoCmd
	jmp	@@cmdok

@@cmd:
	or	[es:si+mpChanInfo.flags],128	; there is a command

	movzx	bx,al
	cmp	bx,0Eh				; E-command?
	jne	@@notecmd

	; the command is E-command. Store infobyte upper nybble + 10h as the
	; command number and infobyte lower nybble as infobyte:
	mov	al,[es:si+mpChanInfo.infobyte]
	shr	al,4
	movzx	bx,al
	add	al,10h
	mov	[es:si+mpChanInfo.command],al
	and	[es:si+mpChanInfo.infobyte],0Fh

	shl	bx,2
	mov	eax,[ecmdNames+bx]			; eax = command name
	mov	[es:si+mpChanInfo.commandname],eax	; string pointer
	jmp	@@cmdok

@@notecmd:
	; normal command
	mov	[es:si+mpChanInfo.command],al

	shl	bx,2			; eax = command name string pointer
	mov	eax,[cmdNames+bx]
	mov	[es:si+mpChanInfo.commandname],eax	 ; store pointer

@@cmdok:
	add	si, SIZE mpChanInfo	; next channel
	add	di, SIZE modChannel
	loop	@@chanloop

	xor	ax,ax			; success
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	int modSetMasterVolume(uchar volume)
;*
;* Description: Sets the module player master volume
;*
;* Input:	uchar  volume		  New master volume
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	modSetMasterVolume  FAR     vol : word

	mov	ax,[vol]
	cmp	al,64
	jbe	@@ok
	mov	al,64
@@ok:
	mov	[masterVolume],al
	xor	ax,ax			; success
	ret
ENDP



;/***************************************************************************\
;*
;* Function:	modSave
;*
;* Description: Saves row, position and pattern values for GetInformation()
;*
;\***************************************************************************/

PROC	modSave 	NEAR
USES	di

	mov	[setFrame],1		; set set-frame flag
	mov	ax,[row]
	mov	[rows],ax		; save row and position
	mov	bx,[position]
	mov	[poss],bx

	lgs	di,[es:si+mpModule.orders]
	movzx	bx,[gs:di+bx]		; save pattern number
	mov	[pats],bx

	xor	ax,ax

	ret
ENDP




;/***************************************************************************\
;*
;* Function:	modUpdBars
;*
;* Description: Updates "fake" volume bars
;*
;\***************************************************************************/

PROC	modUpdBars	NEAR
USES	di

	mov	di,offset channels	; point ds:di to channel structures
	mov	cx,[numChans]

@@chanloop:
	cmp	[di+modChannel.volbar],0	; is volume bar zero?
	je	@@1
	dec	[di+modChannel.volbar]		; if not, decrement it
@@1:
	test	[di+modChannel.status],1	; has volume been changed?
	jz	@@nochange
	mov	al,[di+modChannel.volume]
	test	[di+modChannel.status],2	; force new volume?
	jnz	@@force
	cmp	[di+modChannel.volbar],al	; do not force volume
	jbe	@@nochange			; is bar above volume level?
@@force:
	mov	[di+modChannel.volbar],al	; set new volume

@@nochange:
	and	[di+modChannel.status],not 3	; clear volume change bits
	add	di,SIZE modChannel		; next channel
	loop	@@chanloop

	xor	ax,ax
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	int modConvertSample(uchar *sample, ushort length);
;*
;* Description: Converts signed 8-bit sample to unsigned.
;*
;* Input:       uchar *sample           pointer to sample data
;*		ushort length		sample length in bytes
;*
;* Returns:	MIDAS error code
;*
;\***************************************************************************/

PROC	modConvertSample	FAR	sample : dword, slength : word

	les	bx,[sample]		; point es:bx to sample data
	mov	cx,[slength]		; cx = sample length
	test	cx,cx			; skip if zero length
	jz	@@ok

@@lp:	xor	[byte es:bx],80h	; convert sample byte
	inc	bx
	loop	@@lp

@@ok:
	xor	ax,ax

	ret
ENDP




;/***************************************************************************\
;*
;* Function:	int modConvertTrack(void *track, ushort type,
;*			ushort *trackLen);
;*
;* Description: Converts one Protracker format track to internal format
;*
;* Input:	void *track		pointer to track data
;*		ushort type		track type (0 = normal Protracker)
;*		ushort *trackLen	pointer to track length variable
;*
;* Returns:	MIDAS error code.
;*		Converted track length stored in *trackLen.
;*
;\***************************************************************************/

PROC	modConvertTrack FAR	track : dword, trackType : word, \
				trackLen : dword
LOCAL	period : word, note : word, inst : word, cmd : word, tLength : word, \
	lastOff : word, firstData : word, lastData : dword, comp : word, \
	rowCount : byte
USES	si,di

	mov	[rowCount],64		; row counter = 64
	les	si,[track]		; point es:si to track data

	mov	di,si			; point es:di to conversion dest
	mov	[lastOff],di

	mov	[firstData],1		; flag - first data, no compression
	mov	[lastData],0		; no previous pattern data
	mov	[comp],0		; no compression

@@rowloop:
;	MTM support, now removed:
;	 cmp	 [type],1
;	 je	 @@mtm

	; Read period from pattern data:
	mov	ax,[es:si]
	xchg	ah,al
	mov	bh,ah
	and	ax,0FFFh
	mov	[period],ax

	; Read instrument number:
	mov	bl,[es:si+2]
	shr	bl,4
	and	bh,0F0h
	or	bl,bh
	xor	bh,bh
	mov	[inst],bx

	; Read command and infobyte:
	mov	ax,[es:si+2]
	xchg	ah,al
	and	ax,0FFFh
	mov	[cmd],ax

	; Find note number corresponding to the period:
	mov	[note],0		; no note
	cmp	[period],0		; is period zero?
	je	@@nosearch		; if yes, there is no note
	push	si

	mov	cx,36			; there are 36 note numbers
	xor	si,si			; si = period table index
	mov	bx,1			; current note number = 1

@@findnote:
	mov	ax,[Periods+si] 	; ax = period for this note
	cmp	[period],ax		; equal to period in pattern?
	je	@@found
	inc	bx			; no, try next note
	add	si,2
	loop	@@findnote

	; no note found for period - invalid pattern data
	pop	si
	jmp	@@error

@@found:
	; note corresponding to the period found
	mov	[note],bx
	pop	si

@@nosearch:
	add	si,4			; point es:si to next row


@@compress:
	cmp	[cmd],0 		; is there a command?
	jne	@@cmd

	; there is no command
	cmp	[note],0		; is there a note?
	jne	@@ncmd
	cmp	[inst],0		; or instrument
	jne	@@ncmd

	; no note, command or instrument
	mov	[lastData],0		; an empty row

	cmp	[firstData],1		; is this the first row?
	je	@@putempty

	mov	bx,[lastOff]		; does previous row already have
	test	[byte es:bx],80h	; compression info?
	jne	@@cinfo

	mov	[comp],1		; add compression info - empty rows

	or	[byte es:bx],80h	; compression info follows prev. row
	mov	[byte es:di],1		; one empty row
	jmp	@@next			; do next row


	; There was already compression info:
@@cinfo:
	cmp	[comp],1		; is compression info empty rows?
	jne	@@putempty		; if not, put empty row
	inc	[byte es:di]		; one more empty row
	jmp	@@next

	; store one empty row:
@@putempty:
	cmp	[comp],0		; is there compression info?
	je	@@1			; if yes, save space it
	inc	di
	mov	[comp],0		; no compression info

@@1:	mov	[byte es:di],01111000b	; one empty row
	mov	[lastOff],di		; store destination pointer
	inc	di
	jmp	@@next


	; there is a command:
@@cmd:
	cmp	[note],0		; is there a note?
	jne	@@all
	cmp	[inst],0		; or an instrument
	jne	@@all

	; only a command:
	movzx	eax,[cmd]		; eax = command

	cmp	[firstData],1		; is this the first row?
	je	@@putcmd
	cmp	eax,[lastData]		; is command same as the previous
	jne	@@putcmd		; row? if not, store it

	; this row has the same data as the previous one:
	mov	bx,[lastOff]
	test	[byte es:bx],80h	; is there compression info?
	jne	@@cinfo2

	mov	[comp],2		; compression - rows of same data
	or	[byte es:bx],80h	; compression info follows
	mov	[byte es:di],01000001b	; one same row
	jmp	@@next

	; There was already compression info:
@@cinfo2:
	cmp	[comp],2		; is compression info same data?
	jne	@@putcmd		; if not, store this row
	inc	[byte es:di]		; one more row of same data
	jmp	@@next

	; store command and infobyte:
@@putcmd:
	cmp	[comp],0		; is there compression info?
	je	@@2			; if yes, save space for it
	inc	di
	mov	[comp],0
@@2:	mov	[lastData],eax		; save this row data
	or	ax,0110000000000000b	; there is only a command
	mov	[lastOff],di		; store destination pointer
	xchg	ah,al
	stosw				; store data
	jmp	@@next



	; there is a note and an instrument with no command:

@@ncmd: movzx	eax,[note]
	shl	ax,8			; eax = data for this row
	or	ax,[inst]
	shl	eax,16

	cmp	[firstData],1		; is this the first row?
	je	@@putnote
	cmp	eax,[lastData]		; is this row same as the previous?
	jne	@@putnote

	; this row has the same data as the previous one:
	mov	bx,[lastOff]
	test	[byte es:bx],80h	; is there compression info?
	jne	@@cinfo3

	mov	[comp],2		; compression - rows of same data
	or	[byte es:bx],80h	; compression info follows
	mov	[byte es:di],01000001b	; one same row
	jmp	@@next

	; There was already compression info:
@@cinfo3:
	cmp	[comp],2		; is compression info same data?
	jne	@@putnote		; if not, store this row
	inc	[byte es:di]		; one more row of same data
	jmp	@@next

	; store note and instrument:
@@putnote:
	cmp	[comp],0		; is there compression info?
	je	@@3			; if yes, save space for it
	inc	di
	mov	[comp],0
@@3:	mov	[lastData],eax		; save this row data
	mov	ax,[note]
	shl	ax,5
	or	ax,[inst]
	or	ax,0111000000000000b	; there is a note and instrument
	mov	[lastOff],di		; save destination pointer
	xchg	ah,al
	stosw				; store data
	jmp	@@next


	; there is a note, instrument and command:
@@all:	movzx	eax,[note]
	shl	ax,8			; eax = data for this row
	or	ax,[inst]
	shl	eax,16
	or	ax,[cmd]

	cmp	[firstData],1		; is this the first row?
	je	@@putall
	cmp	eax,[lastData]		; is this row same as the previous?
	jne	@@putall

	; this row has the same data as the previous one:
	mov	bx,[lastOff]
	test	[byte es:bx],80h	; is there compression info?
	jne	@@cinfo4

	mov	[comp],2		; compression - rows of same data
	or	[byte es:bx],80h	; compression info follows
	mov	[byte es:di],01000001b	; one same row
	jmp	@@next

	; There was already compression info:
@@cinfo4:
	cmp	[comp],2		; is compression info same data?
	jne	@@putall		; if not, store this row
	inc	[byte es:di]		; one more row of same data
	jmp	@@next

	; store note and instrument:
@@putall:
	mov	[lastData],eax		; save this row data

	cmp	[comp],0		; is there compression info?
	je	@@4			; if yes, save space for it
	inc	di
	mov	[comp],0

@@4:	mov	[lastOff],di		; store destination pointer

	mov	ax,[note]
	shl	ax,5			; write note and instrument
	or	ax,[inst]
	shr	ax,4
	stosb
	mov	ax,[inst]
	shl	al,4
	or	al,[byte cmd+1] 	; command
	stosb
	mov	al,[byte cmd]		; command infobyte
	stosb


@@next:
	; go to next row:
	mov	[firstData],0		; not the first row
	dec	[rowCount]
	jnz	@@rowloop

	cmp	[comp],0		; was there compression info for
	je	@@nocomp		; last data?

	inc	di			; leave space for it

@@nocomp:
	sub	di,[word track] 	; calculate compressed length

	les	bx,[trackLen]
	mov	[es:bx],di		; store compressed length in *trackLen

	xor	ax,ax			; success
	jmp	@@done

@@error:
	mov	ax,errInvalidPatt	; invalid pattern data
	ERROR	ID_modConvertTrack

@@done:
	ret
ENDP

END


; MTM track conversion code: (removed)

; MTM-Data coming

IF 0

@@mtm:	movzx	ax,[es:si]
	shr	ax,2
	mov	[note],ax

	mov	ax,[es:si]
	xchg	ah,al
	and	ax,03f0h
	shr	ax,4
	mov	[inst],ax

	mov	ax,[es:si+1]
	xchg	ah,al
	and	ax,0fffh
	mov	[cmd],ax

	add	si,3
	jmp	@@back
ENDIF

