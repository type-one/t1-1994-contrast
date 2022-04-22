;*	DSM.ASM
;*
;* Digital Sound Mixer, v1.11
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
INCLUDE "dsm.inc"
INCLUDE "dma.inc"
INCLUDE "mmem.inc"
INCLUDE "ems.inc"
INCLUDE "sdevice.inc"



TBUF_MAX = 2048 			; maximum size of temporary buffer



DATASEG

dsmMixRate	DW	?		; mixing rate in Hz
dsmMode 	DW	?		; output mode (see enum sdMode)
dsmVolTableMem	DD	?		; pointer to volume table returned
					; by memAlloc(). Used for deallocating
dsmVolTableSeg	DW	?		; volume table segment
dsmTempBuffer	DD	?		; temporary mixing buffer for 8-bit
					; modes
dsmTBufSize	DW	?		; temp. buffer size in bytes
dsmChannels	DD	?		; pointer to channel datas
dsmChOpen	DW	?		; number of open channels
dsmMasterVolume DB      ?               ; master volume
dsmInstruments	DD	?		; instrument structures
dsmUpdateMix	DW	?		; amount of data to mix between two
					; updates
dsmMixLeft	DW	?		; amount of data to be mixed before
					; the next update
dsmMixPos	DW	?		; mixing position in buffer
dsmSamplePtr    DD      ?               ; conventional memory sample pointer,
                                        ; used internally by some functions
dsmMuted        DW      ?               ; 1 if muted, 0 if not
dsmPaused       DW      ?               ; 1 if paused, 0 if not


;/***************************************************************************\
;*	Global variables for C version:
;\***************************************************************************/

IFNDEF __TP__

dsmBuffer	dmaBuffer  ?		; final mixing buffer
dsmDMAPos	DW	?		; mixing buffer playing position

ENDIF



CODESEG


;/***************************************************************************\
;*     Code segment variables used by some mixing routines:
;\***************************************************************************/

_mixCount	DW	?		; mixing counter
_bpvalue	DW	?		; bp value in some mixing routines




;/***************************************************************************\
;*
;* Macro:	ChnPtr	segreg, indexreg, channum
;*
;* Description: Points a segment:index register pair to the channel structure
;*		of a channel. Also jumps to @@err if channel number is too
;*		big.
;*
;* Input:	segreg		segment register to be used
;*		indexreg	index register to be used
;*		channum 	number of the channel
;*
;* Destroys:	ax, dx
;*
;\***************************************************************************/

MACRO	ChanPtr segreg, indexreg, channum
LOCAL   chok

	mov	ax,channum
	cmp	ax,[dsmChOpen]		; channel number too big?
        jb      chok
        mov     ax,errInvalidChanNumber
        jmp     @@err

chok:
	mov	indexreg,SIZE dsmChannel
	mul	indexreg			; segreg:indexreg points to
	mov	indexreg,[word dsmChannels]	; the channel structure
	add	indexreg,ax
	mov	segreg,[word dsmChannels+2]
ENDM



;/***************************************************************************\
;*
;* Macro:	InstPtr segreg, indexreg, instnum
;*
;* Description: Points a segment:index register pair to the instrument
;*		structure for instrument instnum.
;*
;* Input:	segreg		segment register to be used
;*		indexreg	index register to be used
;*		instnum 	number of the instrument
;*
;* Destroys:	ax, dx
;*
;\***************************************************************************/

MACRO	InstPtr segreg, indexreg, instnum

	; point segreg:indexreg to beginning of instrument structures:
	mov	segreg,[word dsmInstruments + 2]
	mov	indexreg,[word dsmInstruments]

	mov	ax,instnum
	mov	dx,SIZE dsmInstrument	; segreg:indexreg points to instrument
	mul	dx			; data structure
	add	indexreg,ax
ENDM



;/***************************************************************************\
;*
;* Macro:	NumLabel lblname, lblnum
;*
;* Description: Creates a numbered label in the source, format _namenum
;*		(ie. _table1)
;*
;* Input:	lblname 	name for the label
;*		lblnum		number for the label
;*
;\***************************************************************************/

MACRO	NumLabel lblname, lblnum
_&lblname&lblnum:
ENDM



;/***************************************************************************\
;*
;* Macro:	JmpTable lblname, lblcount
;*
;* Description: Creates a jump offset table in the source. The table consists
;*		of near offsets of labels _lblname0 - _lblnameX
;*
;* Input:	lblname 	name of labels to be used for the table
;*		lblcount	number of labels
;*
;\***************************************************************************/

MACRO	dwoffs lblname, lblnum
	DW	offset _&lblname&lblnum
ENDM

MACRO	JmpTable lblname, lblcount
;LOCAL	 numb
numb = 0
REPT	lblcount
	dwoffs lblname, %numb
numb = numb + 1
ENDM
ENDM


;/***************************************************************************\
;*
;* Macro:	MixLoop 	mname, mixLp, DIinc, BPinc, counter
;*
;* Description: Generates code for inner mixing loop
;*
;* Input:	mname		mixing loop name (ie. m8mna)
;*		mixLp		macro that contains code for mixing loop
;*		DIinc		DI increment after each loop (32 times)
;*		BPinc		BP increment (0 if BP should not be modified)
;*		counter 	loop counter (ie. cx)
;*
;\***************************************************************************/

MACRO	MixLoop 	mname, mixLp, DIinc, BPinc, counter
LOCAL	lp

LABEL	&mname	WORD
JmpTable	&mname, 17


lp:
num = 0
REPT	16
	NumLabel &mname, %num
	&mixLp %num
	num = num + 1
ENDM
	NumLabel &mname, %num

IF DIinc NE 0
	add	di,DIinc		; mix next 32 bytes
ENDIF
IF BPinc NE 0
	add	bp,BPinc
ENDIF
	dec	counter
	jnz	lp
	retn

ENDM	MixLoop



;/***************************************************************************\
;*
;* Function:    dsmClearBuffer
;*
;* Description: Clears the DMA buffer
;*
;* Returns:     MIDAS error code
;*
;\***************************************************************************/

PROC    dsmClearBuffer  FAR

        test    [dsmMode],sd16bit       ; check if output mode is 16-bit
	jnz	@@16

        push    di                              ; no, the buffer is unsigned
        mov     es,[dsmBuffer.bsegment]         ; 8-bit - clear with 80h
        xor     di,di                           ; bytes
        mov     al,80h
	mov	cx,[dsmBuffer.blength]
	cld
	rep	stosb
	pop	di
	jmp	@@ok

@@16:
	push	di
        mov     es,[dsmBuffer.bsegment]         ; 16-bit signed buffer
        xor     di,di                           ; - clear with zero words
        xor     ax,ax
	mov	cx,[dsmBuffer.blength]
	shr	cx,1
	cld
	rep	stosw
	pop	di

@@ok:
        xor     ax,ax
        ret
ENDP




;/***************************************************************************\
;*
;* Function:     int dsmInit(ushort mixRate, ushort mode);
;*
;* Description:  Initializes DSM
;*
;* Input:	 ushort mixRate 	 mixing rate
;*		 ushort mode		 mixing mode (see enum sdMode)
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	dsmInit 	FAR	mixRate : word, mode : word

        cld

	mov	[dsmChOpen],0		; no open channels
	mov	[dsmChannels],0 	; point channel structures to NULL
        mov     [dsmMuted],0            ; not muted
        mov     [dsmPaused],0           ; not paused

	mov	ax,[mode]

        or      ax,sdNormalQ
        and     ax,not sdLowQ           ; only normal quality output
        and     ax,not sdHighQ

	mov	[dsmMode],ax

	mov	ax,[mixRate]
	mov	[dsmMixRate],ax
	mov	bx,25			; calculate mixing buffer size.
	xor	dx,dx			; dsmPlay _must_ be called at least
	div	bx			; 50 times per second, so the buffer
					; is 1/25th second long
	test	[dsmMode],sd16bit	; 16-bit mixing?
	jz	@@b16			; if yes, multiply buffer length with
	shl	ax,1			; two

@@b16:	test	[dsmMode],sdStereo	; stereo?
	jz	@@bst			; if yes, multiply buffer length with
	shl	ax,1			; two

@@bst:
        add     ax,16                   ; make buffer length a multiple of 16
        and     ax,0FFF0h

        ; allocate DMA buffer:
	call	dmaAllocBuffer LANG, ax, seg dsmBuffer offset dsmBuffer
        test    ax,ax                   ; buffer allocated succesfully?
        jnz     @@err


	mov	ax,VOLLEVELS * 256 * 2 + 16	; volume table size in bytes

	test	[dsmMode],sd8bit	; is a temporary mixing buffer needed?
	jz	@@notb
	test	[dsmMode],sdLowQ
	jnz	@@notb

	mov	bx,[dsmBuffer.blength]	; size of temporary 16-bit mixing
	shl	bx,1			; buffer for 8-bit modes
	cmp	bx,TBUF_MAX		; maximum size is TBUF_MAX, as in
	jbe	@@tbok			; the real mode we have to save
	mov	bx,TBUF_MAX		; memory...

@@tbok: mov	[dsmTBufSize],bx	; save temporary buffer size
	add	ax,bx			; temporary buffer and volume table
					; are in the same segment, with the
					; buffer following the volume table
@@notb:
        ; allocate memory for volume table:
        call    memAlloc LANG, ax, seg dsmVolTableMem offset dsmVolTableMem
        test    ax,ax
        jnz     @@err

        mov     dx,[word dsmVolTableMem+2]      ; point dx:ax to allocated
        mov     ax,[word dsmVolTableMem]        ; block

	add	ax,15
	shr	ax,4			; calculate volume table segment
	add	dx,ax			; ( (off+15)/16 + seg )
	mov	[dsmVolTableSeg],dx

	test	[dsmMode],sd8bit	; is a temporary mixing buffer used?
	jz	@@notb2
	test	[dsmMode],sdLowQ
	jnz	@@notb2

	mov	[word dsmTempBuffer],256*2*VOLLEVELS	; temp buffer offset
	mov	[word dsmTempBuffer+2],dx		; and segment

@@notb2:
	mov	[dsmMasterVolume],64	; set master volume to maximum
	mov	[dsmMixPos],0		; start mixing from the beginning
					; of the buffer
	call	dsmSetUpdRate LANG, 5000 ; set the update rate to 50Hz
        test    ax,ax
        jnz     @@err

	; Allocate memory for instrument structures:
        call    memAlloc LANG, MAXINSTS * SIZE dsmInstrument, \
                        seg dsmInstruments offset dsmInstruments
        test    ax,ax
        jnz     @@err

        les     di,[dsmInstruments]     ; point es:di to instrument structures
	mov	cx,MAXINSTS

	; initialize all instrument to reasonable states:
@@instlp:
	mov	[es:di+dsmInstrument.inuse],0	; instrument not in use
	mov	[es:di+dsmInstrument.sample],0	; point sample to NULL
	add	di,SIZE dsmInstrument		; point es:di to next inst
	loop	@@instlp


	; now clear the DMA playing buffer, as it may contain garbage
        call    dsmClearBuffer

        jmp     @@done


@@err:
        ERROR   ID_dsmInit

@@done:
	ret
ENDP





;/***************************************************************************\
;*
;* Function:     int dsmClose(void);
;*
;* Description:  Uninitializes DSM
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	dsmClose	FAR

	; Deallocate mixing buffer:
	call	dmaFreeBuffer LANG, seg dsmBuffer offset dsmBuffer
        test    ax,ax
        jnz     @@err

	; Deallocate volume table and possible temporary buffer:
	call	memFree LANG, [dsmVolTableMem]
        test    ax,ax
        jnz     @@err

	; Deallocate instrument structures:
	call	memFree LANG, [dsmInstruments]
        test    ax,ax
        jnz     @@err

        xor     ax,ax                   ; success
        jmp     @@done

@@err:
        ERROR   ID_dsmClose

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:    int dsmGetMixRate(ushort *mixRate);
;*
;* Description: Reads the actual mixing rate
;*
;* Returns:     Midas error code.
;*              Mixing rate, in Hz, is stored in *mixRate
;*
;\***************************************************************************/

PROC    dsmGetMixRate   FAR     mixRate : dword

	mov	ax,[dsmMixRate]
        les     bx,[mixRate]
        mov     [es:bx],ax              ; store mixing rate to *mixRate

        xor     ax,ax                   ; always successful

	ret
ENDP




;/***************************************************************************\
;*
;* Function:    int dsmGetMode(ushort *mode);
;*
;* Description: Reads the actual output mode
;*
;* Returns:     MIDAS error code.
;*              Output mode is stored in *mode.
;*
;\***************************************************************************/

PROC    dsmGetMode      FAR     mode : dword

	mov	ax,[dsmMode]
        les     bx,[mode]
        mov     [es:bx],ax              ; store output mode in *mode

        xor     ax,ax                   ; always successful

	ret
ENDP




;/***************************************************************************\
;*
;* Function:     int dsmOpenChannels(unsigned channels);
;*
;* Description:  Opens channels for output
;*
;* Input:        unsigned channels      number of channels to open
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	dsmOpenChannels FAR	channels : word
USES	di

        mov     [dsmMuted],0            ; not muted
        mov     [dsmPaused],0           ; not paused

        ; calculate channel structure table size:
	mov	ax,SIZE dsmChannel
	mul	[channels]

        ; allocate memory for channel structures:
        call    memAlloc LANG, ax, seg dsmChannels offset dsmChannels
        test    ax,ax
        jnz     @@err

        mov     ax,[channels]           ; save number of channels
        mov     [dsmChOpen],ax

        ; Both 8 and 16-bit modes require a 16-bit signed volume table.
        ; Now calculate the volume table:

	mov	es,[dsmVolTableSeg]
	xor	edi,edi 		; index in table
	mov	cx,256*VOLLEVELS	; number of volume table entries

@@vtlp: mov	ax,di

        and     ax,0FFh                 ; ax = signed volume table entry
        sub     ax,128                  ; at full volume (volume table is
        shl     ax,8                    ; 16-bit signed)

	mov	bx,di
	shr	bx,8			; bx = volume
        imul    bx                      ; multiply with volume
	mov	bx,VOLLEVELS - 1
        idiv    bx                      ; divide with maximum volume

        cwd
        idiv    [dsmChOpen]             ; divide with number of channels

        mov     [es:edi+edi],ax         ; store value in volume table

@@vtlb: inc	edi			; next value
	loop	@@vtlp


	call	dsmClearChannels LANG	; clear all channels
        test    ax,ax
        jnz     @@err

        xor     ax,ax                   ; successful
        jmp     @@done


@@err:
        ERROR   ID_dsmOpenChannels

@@done:
	ret
ENDP





;/***************************************************************************\
;*
;* Function:     int dsmCloseChannels(void);
;*
;* Description:  Closes open channels
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC    dsmCloseChannels FAR

        ; Check that channels have been opened
        cmp     [dsmChOpen],0
        jne     @@chok
        mov     ax,errNoChannels
        jmp     @@err

@@chok:
        ; deallocate channel structures:
        call    memFree LANG, [dsmChannels]
        test    ax,ax
        jnz     @@err

	mov	[dsmChOpen],0		; no open channels

        call    dsmClearBuffer          ; clear DMA buffer
        jmp     @@done

@@err:
        ERROR   ID_dsmCloseChannels

@@done:
	ret
ENDP





;/***************************************************************************\
;*
;* Function:     int dsmClearChannels(void);
;*
;* Description:  Clears open channels (removes all sounds)
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	dsmClearChannels  FAR

	mov	cx,[dsmChOpen]		; number of open channels
	test	cx,cx			; if none open, error
        jnz     @@chok
        mov     ax,errNoChannels
        jmp     @@err

@@chok:
        les     bx,[dsmChannels]        ; point es:bx to channel structures

@@chlp:
	mov	[es:bx+dsmChannel.hasData],0	; no data to be played
	mov	[es:bx+dsmChannel.muted],0	; not muted
	mov	[es:bx+dsmChannel.inst],0	; no instrument selected
        mov     [es:bx+dsmChannel.instChanged],0     ; instrument not changed
        mov     [es:bx+dsmChannel.smpPos],smpNone       ; no sample
        mov     [es:bx+dsmChannel.rate],0       ; no rate set
	mov	[es:bx+dsmChannel.panning],panMiddle

        add     bx,SIZE dsmChannel      ; next channel
	loop	@@chlp

        xor     ax,ax                   ; success
        jmp     @@done


@@err:
        ERROR   ID_dsmClearChannels

@@done:
	ret
ENDP





;/***************************************************************************\
;*
;* Function:     int dsmMute(int mute);
;*
;* Description:  Mutes all channels
;*
;* Input:        int mute               1 = mute, 0 = un-mute
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	dsmMute 	FAR		mute : word

        mov     ax,[mute]
        mov     [dsmMuted],ax

	ret
ENDP





;/***************************************************************************\
;*
;* Function:     int dsmPause(int pause);
;*
;* Description:  Pauses or resumes the playing
;*
;* Input:        int pause              1 = pause, 0 = resume
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	dsmPause	FAR		pause : word

        mov     ax,[pause]              ; copy paused flag
        mov     [dsmPaused],ax

        call    dsmClearBuffer LANG     ; clear playing buffer

        ret
ENDP





;/***************************************************************************\
;*
;* Function:     int dsmSetMasterVolume(uchar masterVolume);
;*
;* Description:  Sets the master volume
;*
;* Input:        uchar masterVolume     master volume (0 - 64)
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC    dsmSetMasterVolume FAR  masterVolume : byte

        mov     al,[masterVolume]
        mov     [dsmMasterVolume],al

        xor     ax,ax                   ; always successful

        ret
ENDP





;/***************************************************************************\
;*
;* Function:     int dsmPlaySound(unsigned channel, ulong rate);
;*
;* Description:  Plays a sound
;*
;* Input:        unsigned channel       channel number
;*               ulong rate             playing rate in Hz
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	dsmPlaySound	FAR	channel : word, rate : dword

	call	dsmSetPosition LANG, [channel], 0	; start from the
	test	ax,ax					; beg. of the sample
        jnz     @@err
	call	dsmSetRate LANG, [channel], [rate]	; set playing rate
	test	ax,ax
        jnz     @@err

        xor     ax,ax                   ; success
        jmp     @@done

@@err:
        ERROR   ID_dsmPlaySound

@@done:
	ret
ENDP





;/***************************************************************************\
;*
;* Function:     int dsmStopSound(unsigned channel);
;*
;* Description:  Stops playing a sound
;*
;* Input:        unsigned channel       channel number
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	dsmStopSound	FAR	channel : word

	ChanPtr es, bx, [channel]	; point es:bx to channel structure
	mov	[es:bx+dsmChannel.hasData],0	; channel has no data to
						; be played
        xor     ax,ax
        jmp     @@done

@@err:
        ERROR   ID_dsmStopSound

@@done:
	ret
ENDP





;/***************************************************************************\
;*
;* Function:     int dsmSetRate(unsigned channel, ulong rate);
;*
;* Description:  Sets the playing rate
;*
;* Input:        unsigned channel        channel number
;*		 ulong rate		 playing rate in Hz
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	dsmSetRate	FAR	channel : word, rate : dword

	ChanPtr es, bx, [channel]	; point es:bx to channel structure

	mov	eax,[rate]
	mov	[es:bx+dsmChannel.rate],eax	; set playing rate on channel

        xor     ax,ax                   ; success
        jmp     @@done

@@err:
        ERROR   ID_dsmSetRate
@@done:
	ret
ENDP





;/***************************************************************************\
;*
;* Function:     int dsmGetRate(unsigned channel, ulong *rate);
;*
;* Description:  Returns the playing rate or zero if nothing is being
;*		 played
;*
;* Input:        unsigned channel       channel number
;*               ulong *rate            pointer to playing rate
;*
;* Returns:      MIDAS error code.
;*               Playing rate, in Hz, or zero, if nothing is being
;*               played, is stored in *rate
;*
;\***************************************************************************/

PROC    dsmGetRate      FAR     channel : word, rate : dword
USES    si

        lgs     si,[rate]               ; point gs:si to rate variable

	ChanPtr es, bx, [channel]	; point es:bx to channel structure

	cmp	[es:bx+dsmChannel.hasData],0	; data on channel?
	je	@@nodata

        ; get playing rate:
        mov     eax,[es:bx+dsmChannel.rate]
        jmp     @@ok

@@nodata:
        ; no data - return 0 in *rate:
        xor     eax,eax
@@ok:
        mov     [gs:si],eax             ; store playing rate in *rate
        xor     ax,ax                   ; success
        jz      @@done

@@err:
        ERROR   ID_dsmGetRate
@@done:
	ret
ENDP





;/***************************************************************************\
;*
;* Function:     int dsmSetVolume(unsigned channel, uchar volume);
;*
;* Description:  Sets the volume
;*
;* Input:        unsigned channel       channel number
;*               uchar volume           volume (0 - 64)
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC    dsmSetVolume    FAR     channel : word, volume : byte

	ChanPtr es, bx, [channel]	; point es:bx to channel structure

        mov     al,[volume]             ; ax = new volume
        cmp     al,64                   ; is volume > 64?
	jbe	@@ok
        mov     al,64                   ; volume limit is 64

@@ok:	mov	[es:bx+dsmChannel.volume],al	; set new volume

        xor     ax,ax                   ; success
        jmp     @@done

@@err:
        ERROR   ID_dsmSetVolume

@@done:
	ret
ENDP





;/***************************************************************************\
;*
;* Function:     int dsmSetInstrument(unsigned channel, ushort inst);
;*
;* Description:  Sets instrument number
;*
;* Input:        unsigned channel       channel number
;*               ushort inst            instrument number
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	dsmSetInstrument FAR	channel : word, inst : word
USES	si

	ChanPtr es, bx, [channel]	; point es:bx to channel structure

	mov	ax,[inst]

        test    ax,ax
        jns     @@1                     ; check that the instrument number
        jz      @@badinst               ; is valid - 0 < inst <= MAXINSTS
        cmp     ax,MAXINSTS
        jbe     @@1

@@badinst:
        mov     ax,errInvalidInstHandle ; invalid instrument handle
        jmp     @@err

@@1:
	dec	ax			; instrument numbers start from 1
	InstPtr gs, si, ax		; point gs:si to instrument structure
	cmp	[gs:si+dsmInstrument.inuse],1	; is instrument in use?
        je      @@2

        mov     ax,errInvalidInstHandle ; invalid instrument handle
        jmp     @@err

@@2:
        mov     ax,[inst]
	mov	[es:bx+dsmChannel.inst],ax	; set new instrument number

        mov     al,[gs:si+dsmInstrument.volume] ; set instrument default
        mov     [es:bx+dsmChannel.volume],al    ; volume as the playing volume

        cmp     [ALE],1
        je      @@ale


        ; no Amiga Loop Emulation - copy instrument data (sample pointer etc.
        ; to channel structure so that instrument will be used now):

        call    dsmUseInstrument

	cmp	[es:bx+dsmChannel.hasData],1
	jne	@@nodata

        ; Data is being played on the channel - reset the playing position
        ; to make sure playing does not continue past the end of the
        ; instrument
	call	dsmSetPosition LANG, [channel], [es:bx+dsmChannel.pos]
        test    ax,ax
        jnz     @@err

@@nodata:
        xor     ax,ax                   ; success
        jmp     @@done


@@ale:
        ; Amiga Loop Emulation is active - do not set instrument values to
        ; channel structure. Just flag that the instrument has been changed.
        ; The values will be set when the current sample or sample loop ends
        ; or the playing position is set.
        mov     [es:bx+dsmChannel.instChanged],1        ; instrument has been
                                                        ; changed

        ; If data is being played, we are done.
        cmp     [es:bx+dsmChannel.hasData],1
        je      @@aledone

        ; Data is not being played - if the new sample is looping and a
        ; sampling rate has been set, start playing from the loop
        ; beginning
        cmp     [gs:si+dsmInstrument.looping],1
        jne     @@aledone

        ; Start playing from loop start: (dsmSetPosition() sets the
        ; instrument values to channel structure)
        call    dsmSetPosition LANG, [channel], \
                [gs:si+dsmInstrument.loopStart]
        test    ax,ax
        jnz     @@err


@@aledone:
        xor     ax,ax
        jmp     @@done

@@err:
        ERROR   ID_dsmSetInstrument

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:    dsmUseInstrument
;*
;* Description: Sets the instrument values on a channel to the channel
;*              structure so that the instrument specified by
;*              dsmChannel.inst will be used for playing.
;*
;* Input:       es:bx                   pointer to channel structure
;*
;* Destroys:    eax, dx
;*
;\***************************************************************************/

PROC NOLANGUAGE dsmUseInstrument        NEAR

        push    gs si

        mov     ax,[es:bx+dsmChannel.inst]      ; ax = instrument number
        dec     ax                              ; (table starts from 0)
        InstPtr gs, si, ax                      ; point ds:si to inst struct

        mov     eax,[gs:si+dsmInstrument.sample]        ; copy sample
        mov     [es:bx+dsmChannel.sample],eax           ; pointer

        mov     al,[gs:si+dsmInstrument.smpType]        ; copy sample type
        mov     [es:bx+dsmChannel.smpType],al

        mov     al,[gs:si+dsmInstrument.smpPos]         ; copy sample position
        mov     [es:bx+dsmChannel.smpPos],al

        mov     ax,[gs:si+dsmInstrument.slength]        ; copy sample length
        mov     [es:bx+dsmChannel.slength],ax

        mov     ax,[gs:si+dsmInstrument.loopStart]      ; copy sample loop
        mov     [es:bx+dsmChannel.loopStart],ax         ; start

        mov     ax,[gs:si+dsmInstrument.loopEnd]        ; copy sample loop
        mov     [es:bx+dsmChannel.loopEnd],ax           ; end

        mov     al,[gs:si+dsmInstrument.looping]        ; copy inst looping
        mov     [es:bx+dsmChannel.looping],al           ; flag

        mov     [es:bx+dsmChannel.instChanged],0

        pop     si gs

        ret
ENDP





;/***************************************************************************\
;*
;* Function:     int dsmSetPosition(unsigned channel, ushort pos);
;*
;* Description:  Sets the playing position from the beginning of instrument
;*
;* Input:        unsigned channel        channel number
;*		 ushort pos		 new position
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	dsmSetPosition	FAR	channel : word, pos : word
USES	si

	ChanPtr es, bx, [channel]	; point es:bx to channel structure

        cmp     [es:bx+dsmChannel.instChanged],1        ; has instrument been
        jne     @@noinstch                              ; changed?
        call    dsmUseInstrument                        ; use new instrument

@@noinstch:
	mov	cx,[pos]		; cx = new position

        mov     ax,[es:bx+dsmChannel.inst]      ; current instrument
        test    ax,ax                   ; is there a instrument selected?
	jz	@@noset 		; if not, then don't play

        cmp     [es:bx+dsmChannel.smpType],smpNone      ; is there a sample?
	je	@@noset

        cmp     [es:bx+dsmChannel.looping],1    ; is instrument looping?
	je	@@looping

        ; instrument is not looping - stop playing if new position is past
        ; sample length:
        cmp     cx,[es:bx+dsmChannel.slength]
        jb      @@set
        call    dsmStopSound LANG, [channel]
        test    ax,ax
        jnz     @@err
	jmp	@@noset

@@looping:
        ; instrument is looping - if new position is past loop end, set it to
        ; loop start:
        cmp     cx,[es:bx+dsmChannel.loopEnd]
        jb      @@set
        mov     cx,[es:bx+dsmChannel.loopStart]

@@set:
	mov	[es:bx+dsmChannel.pos],cx	; set position
	mov	[es:bx+dsmChannel.posl],0	; set position fraction to 0
	mov	[es:bx+dsmChannel.hasData],1	; channel has data

@@noset:
        xor     ax,ax                   ; success
        jmp     @@done

@@err:
        ERROR   ID_dsmSetPosition

@@done:
	ret
ENDP





;/***************************************************************************\
;*
;* Function:     int dsmGetPosition(unsigned channel, ushort *pos);
;*
;* Description:  Gets the playing position
;*
;* Input:        unsigned channel       channel number
;*               ushort *pos            pointer to the position variable
;*
;* Returns:      MIDAS error code.
;*               Playing position from the beginning of instrument is stored
;*               in *pos.
;*
;\***************************************************************************/

PROC    dsmGetPosition  FAR     channel : word, pos : dword

	ChanPtr es, bx, [channel]	; point es:bx to channel structure
	mov	ax,[es:bx+dsmChannel.pos]

        les     bx,[pos]
        mov     [es:bx],ax              ; store playing position in *pos

        xor     ax,ax
        jmp     @@done

@@err:
        ERROR   ID_dsmGetPosition

@@done:
	ret
ENDP





;/***************************************************************************\
;*
;* Function:    int dsmSetPanning(unsigned channel, short panning);
;*
;* Description: Sets the panning status of a channel
;*
;* Input:       unsigned channel      channel number
;*              short panning         panning information (see enum sdPanning)
;*
;* Returns:     MIDAS error code
;*
;\***************************************************************************/

PROC	dsmSetPanning	FAR	channel : word, panning : word

	ChanPtr es, bx, [channel]	; point es:bx to channel structure
	mov	ax,[panning]
        mov     [es:bx+dsmChannel.panning],al

        xor     ax,ax                   ; success
        jmp     @@done

@@err:
        ERROR   ID_dsmSetPanning

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:    int dsmGetPanning(unsigned channel, short *panning);
;*
;* Description: Returns the panning status of a channel
;*
;* Input:       unsigned channel        channel number
;*              short *panning          pointer to panning variable
;*
;* Returns:     MIDAS error code.
;*              Panning information is stored in *panning
;*
;\***************************************************************************/

PROC    dsmGetPanning   FAR     channel : word, panning : dword

	ChanPtr es, bx, [channel]	; point es:bx to channel structure
        movsx   ax,[es:bx+dsmChannel.panning]   ; ax = panning value

        cmp     al,panSurround          ; if panning is panSurround, clear
        jne     @@panok                 ; upper nybble, as panSurround is a
        mov     ax,panSurround          ; positive value even if bit 7 is 1

@@panok:
        les     bx,[panning]
        mov     [es:bx],ax              ; store panning info in *panning

        xor     ax,ax                   ; success
	jmp	@@done

@@err:
        ERROR   ID_dsmGetPanning

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:     int dsmMuteChannel(unsigned channel, int mute);
;*
;* Description:  Mutes/un-mutes a channel
;*
;* Input:	 ushort channel 	 channel number
;*		 ushort mute		 1 = mute, 0 = un-mute
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	dsmMuteChannel	FAR	channel : word, mute : word

	ChanPtr es, bx, [channel]	; point es:bx to channel structure
	mov	ax,[mute]
	mov	[es:bx+dsmChannel.muted],al

        xor     ax,ax                   ; success
	jmp	@@done

@@err:
        ERROR   ID_dsmMuteChannel

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:    int dsmAddInstrument(void far *sample, int smpType,
;*                      ushort length, ushort loopStart, ushort loopEnd,
;*                      uchar volume,  int loop, ushort *instHandle);
;*
;* Description:  Adds a new instrument to the instrument list
;*
;* Input:        void far *sample       Pointer to sample data. MUST be
;*                                      in conventional memory. Sample
;*                                      data is copied into another memory
;*                                      location and so sample should be
;*                                      deallocated after this function
;*                                      call.
;*               int smpType            sample type (see enum smpTypes)
;*               ushort length          sample length
;*               ushort loopStart       sample loop start
;*               ushort loopEnd         sample loop end
;*               uchar volume           sample default volume (0 - 64)
;*               int loop               looping (1 = looping sample, 0 = not)
;*               ushort *instHandle     pointer to variable to store the SD
;*                                      instrument handle
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC    dsmAddInstrument FAR    sample : dword, smpType : word, \
		slength : word, loopStart : word, loopEnd : word,\
                volume : byte, sloop : word, instHandle : dword
USES	si
LOCAL	instNum : word

	les	si,[dsmInstruments]	; point es:si to instrument structures
	xor	bx,bx			; bx = instrument number
	mov	cx,MAXINSTS

	; Attempt to find first unused instrument:
@@ilp:	cmp	[es:si+dsmInstrument.inuse],0
	je	@@inst
	add	si,SIZE dsmInstrument	; point es:si to next inst struct
	inc	bx			; next instrument
	loop	@@ilp

        mov     ax,errNoInstHandles     ; no free instrument handles
        jmp     @@err


@@inst:
	; Unused instrument found. bx contains the instrument number and
	; es:si points to the instrument structure

	mov	[instNum],bx

	mov	[es:si+dsmInstrument.inuse],1	; instrument is in use

	cmp	[smpType],smpNone	; is there a sample?
	je	@@nosmp
	cmp	[slength],0
	je	@@nosmp

	cmp	[useEMS],0		; should EMS memory be used?
	je	@@conv

        lea     ax,[si+dsmInstrument.sample]    ; point es:ax to current
                                                ; dsmInstrument.sample
	push	es
        call    emsAlloc LANG, [slength], es ax ; allocate EMS for sample
	pop	es
        test    ax,ax
        jz      @@emsok

        cmp     ax,errOutOfEMS          ; check if the error was about lack
        jne     @@err                   ; of EMS or something else

        ; Not enough EMS memory. If forceEMS == 1, only EMS memory
        ; should be used.
        cmp     [forceEMS],1            ; use conventional memory if
        jne     @@conv                  ; forceEMS != 1

        mov     ax,errOutOfEMS          ; out of EMS memory
        jmp     @@err

@@emsok:
        ; map EMS block to conventional memory:
        push    es
        call    emsMap LANG, [es:si+dsmInstrument.sample], \
                seg dsmSamplePtr offset dsmSamplePtr
        pop     es
        test    ax,ax
        jnz     @@err

        push    ds es si di
        les     di,[dsmSamplePtr]       ; point es:di to EMS block in memory
        lds     si,[sample]             ; point ds:si to sample data
	mov	cx,[slength]
	cld
        rep     movsb                   ; copy sample data to EMS memory block
	pop	di si es ds

	mov	[es:si+dsmInstrument.smpPos],sdSmpEMS	; sample is in EMS
        jmp     @@smpok


@@conv:
        ; allocate conventional memory for sample:
        lea     ax,[si+dsmInstrument.sample]    ; point es:ax to current
                                                ; dsmInstrument.sample
        push    es
        call    memAlloc LANG, [slength], es ax
	pop	es
        test    ax,ax
        jnz     @@err

	push	si di ds es
        les     di,[es:si+dsmInstrument.sample] ; point es:di to memory
                                                ; allocated for sample
        lds     si,[sample]             ; point ds:si to sample data
        mov     cx,[slength]
	cld
        rep     movsb                   ; copy sample data to new memory area
	pop	es ds di si

        ; sample is in conventional memory:
        mov     [es:si+dsmInstrument.smpPos],sdSmpConv

	jmp	@@smpok

@@nosmp:
        ; no sample:
        mov     [es:si+dsmInstrument.sample],0
	mov	[es:si+dsmInstrument.smpType],smpNone
	mov	[es:si+dsmInstrument.smpPos],sdSmpNone

@@smpok:
        mov     ax,[smpType]
	mov	[es:si+dsmInstrument.smpType],al	; copy sample type

        ; copy instrument data: length, loop and volume:
        mov     ax,[slength]
	mov	[es:si+dsmInstrument.slength],ax
	mov	ax,[loopStart]
	mov	[es:si+dsmInstrument.loopStart],ax
	mov	ax,[loopEnd]
	mov	[es:si+dsmInstrument.loopEnd],ax
        mov     al,[volume]
	mov	[es:si+dsmInstrument.volume],al
	mov	ax,[sloop]
	mov	[es:si+dsmInstrument.looping],al

	mov	ax,[instNum]
        inc     ax                      ; instrument handle numbers start at 1
        les     bx,[instHandle]         ; store instrument handle in
        mov     [es:bx],ax              ; *instHandle

        xor     ax,ax                   ; success
	jmp	@@done


@@err:
        ERROR   ID_dsmAddInstrument

@@done:
	ret
ENDP





;/***************************************************************************\
;*
;* Function:    int dsmRemInstrument(ushort inst);
;*
;* Description: Removes an instrument from the instrument list, and
;*              deallocates sample memory
;*
;* Input:	ushort inst		instrument number
;*
;* Returns:     MIDAS error code
;*
;\***************************************************************************/

PROC	dsmRemInstrument FAR	inst : word

        mov     ax,[inst]

        test    ax,ax
        jnz     @@1                     ; check that the instrument number
        cmp     ax,MAXINSTS             ; is valid - 0 < inst <= MAXINSTS
        jbe     @@1

        mov     ax,errInvalidInstHandle ; invalid instrument handle
        jmp     @@err

@@1:
	dec	ax
	InstPtr es, bx, ax		; point es:bx to inst data structure

        cmp     [es:bx+dsmInstrument.inuse],1   ; is instrument in use?
        je      @@2

        mov     ax,errInvalidInstHandle ; invalid instrument handle
        jmp     @@err

@@2:
        cmp     [es:bx+dsmInstrument.smpPos],sdSmpConv
        je      @@conv

        cmp     [es:bx+dsmInstrument.smpPos],sdSmpNone
        je      @@dealloc

        ; sample is in EMS - deallocate
        push    es bx
        call    emsFree LANG, [es:bx+dsmInstrument.sample]
        pop     bx es
        test    ax,ax
        jnz     @@err

        jmp     @@dealloc

@@conv:
        ; sample is in conventional memory - deallocate
        push    es bx
	call	memFree LANG, [es:bx+dsmInstrument.sample]
        pop     bx es
        test    ax,ax
        jnz     @@err


@@dealloc:
	mov	[es:bx+dsmInstrument.inuse],0	; instrument not in use

        xor     ax,ax                   ; success
        jmp     @@done

@@err:
        ERROR   ID_dsmRemInstrument

@@done:
	ret
ENDP





;/***************************************************************************\
;*
;* Function:     int dsmSetUpdRate(ushort updRate);
;*
;* Description:  Set channel updating rate (depends on song tempo)
;*
;* Input:	 ushort updRate 	 updating rate in 100*Hz
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	dsmSetUpdRate	FAR	updRate : word

	mov	ax,100
	mul	[dsmMixRate]		; ax = amount of data between two
	div	[updRate]		; updates

	test	[dsmMode],sd16bit
        jz      @@no16                  ; multiply amount by 2 if 16-bit
	shl	ax,1

@@no16: test	[dsmMode],sdStereo
        jz      @@nostereo              ; multiply amount by 2 if stereo
	shl	ax,1

@@nostereo:
	mov	[dsmUpdateMix],ax
	mov	[dsmMixLeft],ax

        xor     ax,ax                   ; always successful

	ret
ENDP





;/***************************************************************************\
;*
;* Function:     int dsmPlay(int *callMP);
;*
;* Description:  Updates sound device registers or mixes data
;*
;* Returns:      MIDAS error code.
;*               *callMP contains 1 if registers were updated or data mixed
;*               so that new values can be set by, for example, calling the
;*               music player.
;*
;\***************************************************************************/

PROC    dsmPlay         FAR     callMP : dword
LOCAL	mixBytes : word, mixCount : word
USES	si,di

	cld

        cmp     [dsmPaused],1           ; is playing paused?
        je      @@paused                ; if yes, skip mixing

	mov	ax,[dsmDMAPos]

	mov	bx,[dsmMixPos]		; mixing position
	cmp	bx,ax			; is dsmMixPos < dmaGetPos()?
	jae	@@1

	mov	cx,ax			; cx = maximum amout to mix
	sub	cx,bx			; = dmaGetPos() - dsmMixPos
	jmp	@@2

@@1:	mov	cx,[dsmBuffer.blength]	; cx = maximum amount to mix
	sub	cx,bx			; = (dsmBufferSize - dsmMixPos)
	add	cx,ax			;   + dmaGetPos()

@@2:	sub	cx,16			; keep 16 bytes of safety distance
					; between mixing pos and DMA pos
	cmp	cx,16
	jl	@@stopmix		; skip if < 16 bytes space in buffer

	cmp	cx,[dsmMixLeft] 	; don't mix more data than there is
	jbe	@@3			; to mix before the next update
	mov	cx,[dsmMixLeft]

@@3:	test	[dsmMode],sd16bit	; 16-bit?
	jz	@@no16			; if yes, mix only an integral number
	and	cx,not 1		; of words
	test	[dsmMode],sdStereo	; 16-bit stereo?
	jz	@@cok			; if yes, mix only an integral number
	and	cx,not 2		; of dwords
	jmp	@@cok

@@no16:
	test	[dsmMode],sdStereo	; 8-bit stereo?
	jz	@@cok			; if yes, mix only an integral number
	and	cx,not 1		; of dwords

@@cok:
	mov	[mixBytes],cx
	mov	[mixCount],cx
	or	cx,cx
	jz	@@endmix


	test	[dsmMode],sd8bit
	jnz	@@8norm
	jmp	@@16norm


@@8norm:
	test	[dsmMode],sdStereo
	jz	@@8nmono

@@8nstereo:
	mov	ax,[mixCount]		; number of bytes to be mixed
	shl	ax,1			; number of bytes of temp buffer
	cmp	ax,[dsmTBufSize]	; needed (16-bit!)
	jb	@@8ns1			; don't mix more than there is space
	mov	ax,[dsmTBufSize]	; for in the temp mixing buffer
@@8ns1:
	shr	ax,1			; number of bytes to mix
	sub	[mixCount],ax
	shr	ax,1			; actual amount to mix (stereo)

	call	dsmMixData LANG, [dsmTempBuffer], ax, \
			offset dsm_Mix8StereoNormal	; mix the data
        test    ax,ax
        jnz     @@err

	cmp	[mixCount],0
	jnz	@@8nstereo
	jmp	@@endmix


@@8nmono:
	mov	si,[mixCount]		; number of bytes to be mixed
	shl	si,1			; number of bytes of temp buffer
	cmp	si,[dsmTBufSize]	; needed (16-bit!)
	jb	@@8nm1			; don't mix more than there is space
	mov	si,[dsmTBufSize]	; for in the temp mixing buffer
@@8nm1:
	shr	si,1

	call	dsmMixData LANG, [dsmTempBuffer], si, \
			offset dsm_Mix8MonoNormal	; mix the data
        test    ax,ax
        jnz     @@err

	sub	[mixCount],si
	jnz	@@8nmono
	jmp	@@endmix


@@16norm:
	test	[dsmMode],sdStereo
	jz	@@16nmono

	mov	ax,[mixCount]		; 16-bit stereo - convert mixCount
	shr	ax,2			; into number of dwords
	call	dsmMixData LANG, [dsmBuffer.bsegment] [dsmMixPos], ax, \
			offset dsm_Mix16StereoNormal
        test    ax,ax
        jnz     @@err
	jmp	@@endmix


@@16nmono:
	mov	ax,[mixCount]		; convert mixCount into number of
	shr	ax,1			; words
	call	dsmMixData LANG, [dsmBuffer.bsegment] [dsmMixPos], ax, \
			offset dsm_Mix16MonoNormal
        test    ax,ax
        jnz     @@err
	jmp	@@endmix


@@endmix:
	mov	ax,[mixBytes]		; mixBytes bytes were mixed

	sub	[dsmMixLeft],ax 	; is the next update due?
	jz	@@update

	jmp	@@stopmix

@@update:
	mov	ax,[dsmUpdateMix]
	mov	[dsmMixLeft],ax 	; set bytes to mix before next update

        les     bx,[callMP]
        mov     [word es:bx],1          ; music-player should be called now
        xor     ax,ax                   ; success
        jmp     @@done

@@stopmix:
@@paused:
        les     bx,[callMP]
        mov     [word es:bx],0          ; do not call music player

        xor     ax,ax                   ; success
        jmp     @@done


@@err:
        ERROR   ID_dsmPlay

@@done:
	ret
ENDP





;/***************************************************************************\
;*
;* Function:    int dsmMixData(uchar *mixBuffer, ushort mixLength,
;*				void (near mixRoutine)(void));
;*
;* Description: Mixes data from all channels
;*
;* Input:	uchar *mixBuffer	pointer to mixing buffer
;*		ushort mixLength	amount of data to be mixed
;*		void (near mixRoutine)(void)	pointer to actual data mixing
;*					function, which must be in current
;*					code segment
;*
;* Returns:     MIDAS error code
;*
;* Destroys:	eax, ebx, ecx, edx, es, gs
;*
;* Note:	DSM internal use only, do not call from outside!
;*
;\***************************************************************************/

PROC	dsmMixData	FAR	mixBuffer : dword, mixLength : word, \
				mixRoutine : word
USES	si,di
LOCAL	chan : word, mlen : word, incr : dword, mixPtr : dword, vol : byte, \
	smp : dword, panning : byte

	mov	[chan],0		; channel number to be mixed

@@chnlp:
	mov	ax,[mixLength]		; mlen = amount of data to be mixed
	mov	[mlen],ax		; for the channel
	mov	eax,[mixBuffer] 	; mixPtr = position where data will
	mov	[mixPtr],eax		; be mixed

        cmp     [dsmChOpen],0           ; are any channels open?
        je      @@cdone                 ; if not, simply clear the buffer

@@contmix:
	ChanPtr es, bx, [chan]		; point es:bx to channel struct
	cmp	[es:bx+dsmChannel.hasData],0	; data to be mixed?
	je	@@cdone

        mov     al,[es:bx+dsmChannel.panning]
	mov	[panning],al		; save panning information

        cmp     [dsmMuted],1            ; is DSM muted?
        je      @@muted
	cmp	[es:bx+dsmChannel.muted],0	; is channel muted?
	je	@@nom
@@muted:
	xor	al,al			; if is, play at zero volume
	jmp	@@vok
@@nom:
	movzx	ax,[es:bx+dsmChannel.volume]
	mul	[dsmMasterVolume]	; calculate actual playing volume
	shr	ax,6			; (volume * masterVolume) / 64
@@vok:
	mov	[vol],al

	mov	ax,[es:bx+dsmChannel.inst]
        test    ax,ax                   ; no mixing if no instrument set on
	jz	@@cdone 		; channel
	dec	ax			; instrument numbers start from 1
	InstPtr gs, si, ax		; point gs:si to instrument struct

	cmp	[gs:si+dsmInstrument.inuse],0
	je	@@cdone 		; skip if no legal instrument
        cmp     [es:bx+dsmChannel.smpType],smp8bit
	jne	@@cdone 		; or sample not of supported type

        cmp     [es:bx+dsmChannel.smpPos],sdSmpEMS      ; is sample in EMS?
	jne	@@smpconv

        push    es bx                   ; map sample into conventional memory
        call    emsMap LANG, [es:bx+dsmChannel.sample], \
                seg dsmSamplePtr offset dsmSamplePtr
        pop     bx es
        test    ax,ax
        jnz     @@err

        mov     eax,[dsmSamplePtr]      ; save sample pointer in conventional
        mov     [smp],eax               ; memory to smp
	jmp	@@smpok

@@smpconv:
        ; sample in conventional memory - point smp to sample data
        mov     eax,[es:bx+dsmChannel.sample]
	mov	[smp],eax
	jmp	@@smpok

@@smpok:
	push	bx
	mov	eax,[es:bx+dsmChannel.rate]	; playing rate
	xor	edx,edx
	shld	edx,eax,16		; eax = sample pos increment =
	shl	eax,16			; rate / dsmMixRate
	movzx	ebx,[dsmMixRate]	; (16.16 bit fixed point number)
	div	ebx
	mov	[incr],eax		; store position increment
	pop	bx

        cmp     [es:bx+dsmChannel.looping],1    ; looping instrument?
	je	@@cloop


        ; non-looping sample:

	mov	dx,[es:bx+dsmChannel.pos]
	shl	edx,16			; edx = playing position in channel
	mov	dx,[es:bx+dsmChannel.posl]	; (16.16 fixed point)
        mov     ax,[es:bx+dsmChannel.slength]
	shl	eax,16			; eax = sample length
	sub	eax,edx 		; eax = amount of data before sample
					; end
	xor	edx,edx 		; eax = number of destination bytes
	div	[incr]			; before sample end

	movzx	ecx,[mixLength] 	; amount of data to be mixed
	cmp	ecx,eax 		; will sample end be reached
	jbe	@@cnl1			; before the end of mixing?
	mov	ecx,eax 		; if so, don't mix past sample end

@@cnl1: sub	[mlen],cx		; decrease amount of data to be mixed
        test    cx,cx                   ; if zero bytes do not mix, we are at
	jz	@@cnsend		; end of sample

        push    es bx

	lgs	si,[smp]			; es = sample segment
	add	si,[es:bx+dsmChannel.pos]	; esi = sample mixing position
	shl	esi,16				; from the beginning of the
	mov	si,[es:bx+dsmChannel.posl]	; segment, 16.16 fixed point

	mov	al,[vol]		; mixing volume
	les	di,[mixPtr]		; mixing buffer
	mov	edx,[incr]		; mixing position increment
	mov	ah,[byte chan]		; channel number
	mov	bl,1			; channel has data to be mixed
	mov	bh,[panning]		; panning information
	call	[word mixRoutine]	; mix the sound!
	mov	edx,esi 		; edx = new mixing position
	mov	[word mixPtr],di

        pop     bx es

	mov	[es:bx+dsmChannel.posl],dx	; new position fraction
	shr	edx,16				; substract sample start from
	sub	dx,[word smp]			; whole part to get
	mov	[es:bx+dsmChannel.pos],dx	; mixing position whole part

        cmp     dx,[es:bx+dsmChannel.slength]   ; past sample end?
	jae	@@cnsend
	jmp	@@cdone

@@cnsend:
        ; sample end has been reached
        cmp     [ALE],1                 ; is Amiga Loop Emulation active?
        je      @@nlale

        ; no Amiga Loop emulation - no data to be mixed:
        mov     [es:bx+dsmChannel.hasData],0
	jmp	@@cdone

@@nlale:
        ; Sample end was reached and Amiga Loop Emulation is active. If
        ; instrument has been changed, set new instrument values to channel
        ; structure and check if playing should be continued with new
        ; instrument. If instrument has not been changed, stop playing
        cmp     [es:bx+dsmChannel.instChanged],1
        je      @@alenewinst
        mov     [es:bx+dsmChannel.hasData],0
	jmp	@@cdone


@@cloop:	; looping instrument
	mov	dx,[es:bx+dsmChannel.pos]
	shl	edx,16			; edx = playing position in channel
	mov	dx,[es:bx+dsmChannel.posl]	; (16.16 fixed point)
        mov     ax,[es:bx+dsmChannel.loopEnd]
	shl	eax,16			; eax = sample loop end
	sub	eax,edx 		; eax = amount of data before sample
					; loop end
	xor	edx,edx 		; eax = number of destination bytes
	div	[incr]			; before sample loop end
	or	edx,edx 		; if modulus is not zero, one more
	jz	@@cl2			; byte must be mixed in order to
	inc	eax			; actually reach loop end

@@cl2:
	movzx	ecx,[mlen]		; amount of data to be mixed
	cmp	ecx,eax 		; will sample loop end be reached
	jbe	@@cl1			; before the end of mixing?
	mov	ecx,eax 		; if so, don't mix past loop end

@@cl1:	sub	[mlen],cx		; decrease amount of data to be mixed
	or	cx,cx			; if zero bytes do mix, we are at
	jz	@@cnsend		; end of sample loop

        push    es bx

	lgs	si,[smp]			; es = sample segment
	add	si,[es:bx+dsmChannel.pos]	; esi = sample mixing position
	shl	esi,16				; from the beginning of the
	mov	si,[es:bx+dsmChannel.posl]	; segment, 16.16 fixed point

	mov	al,[vol]		; mixing volume
	les	di,[mixPtr]		; mixing buffer
	mov	edx,[incr]		; mixing position increment
	mov	ah,[byte chan]		; channel number
	mov	bl,1			; channel has data to be mixed
	mov	bh,[panning]		; panning information
	call	[word mixRoutine]	; mix the sound!
	mov	edx,esi 		; edx = new mixing position
	mov	[word mixPtr],di

        pop     bx es

	mov	[es:bx+dsmChannel.posl],dx	; new position fraction
	shr	edx,16				; substract sample start from
	sub	dx,[word smp]			; whole part to get
	mov	[es:bx+dsmChannel.pos],dx	; mixing position whole part

        mov     ax,[es:bx+dsmChannel.loopEnd]           ; have we reached
	cmp	[es:bx+dsmChannel.pos],ax		; loop end?
	jb	@@clne


        ; loop end has been reached.
        cmp     [ALE],1                 ; is Amiga Loop Emulation active?
        je      @@lale

        ; Amiga Loop Emulation not active - just substract loop length from
        ; position to get to loop start
@@loopcurrent:
        mov     ax,[es:bx+dsmChannel.loopEnd]
        sub     ax,[es:bx+dsmChannel.loopStart]
        sub     [es:bx+dsmChannel.pos],ax
        jmp     @@clne

@@lale:
        ; Sample loop end has been reached and Amiga Loop Emulation is
        ; active. If instrument has been changed, set new instrument values
        ; to channel structure and check if playing should be continued
        ; with new instrument. If instrument has not been changed, just loop
        ; as usual
        cmp     [es:bx+dsmChannel.instChanged],1
        je      @@alenewinst
        jmp     @@loopcurrent

@@clne:
	cmp	[mlen],0		; more data to be mixed?
	je	@@cdone 		; skip if not
	jmp	@@cloop


@@alenewinst:
        ; Sample loop end or sample end has been reached, Amiga Loop
        ; Emulation is active and instrument has been changed. Set new
        ; instrument values to channel structure:
        call    dsmUseInstrument

        ; if new instrument is not looping, playing should be stopped:
        cmp     [es:bx+dsmChannel.looping],1
        je      @@alelp
        mov     [es:bx+dsmChannel.hasData],0
        jmp     @@cdone

@@alelp:
        ; looping instrument - continue playing from new instrument loop
        ; start:
        mov     ax,[es:bx+dsmChannel.loopStart]
        mov     [es:bx+dsmChannel.pos],ax
        mov     [es:bx+dsmChannel.posl],0

        cmp     [mlen],0                ; more data to be mixed?
        jne     @@contmix               ; if yes, continue mixing
        jmp     @@cdone


@@cdone:
	mov	cx,[mlen]		; Mixed enough? Even if sample has
	or	cx,cx			; ended, the mixing routine must be
	jz	@@nomix 		; called to ensure that the buffer
					; is cleared properly, data moved to
					; the DMA buffer etc.

	les	di,[mixPtr]		; mixing buffer
	mov	ah,[byte chan]		; channel number
	xor	bl,bl			; channel has no data to be mixed
	xor	bh,bh
	call	[word mixRoutine]	; call the mixing routine

@@nomix:
	mov	ax,[chan]
	inc	ax			; next channel
	cmp	ax,[dsmChOpen]		; are there more channels?
	jae	@@chdn
	mov	[chan],ax
	jmp	@@chnlp

@@chdn:
        xor     ax,ax                   ; success
        jmp     @@done

@@err:
        ERROR   ID_dsmMixData

@@done:
	ret
ENDP




; 8-bit mono normal mixing, add to temporary buffer
MACRO	_m8mna		num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	add	[di+2*num],ax		; add word into destination
ENDM

MixLoop m8mna, _m8mna, 32, 0, cx



; 8-bit mono normal mixing, move to temporary buffer (first channel)
MACRO	_m8mnm		num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	add	ax,8000h
	mov	[di+2*num],ax		; move word byte into destination
ENDM

MixLoop m8mnm, _m8mnm, 32, 0, cx


; 8-bit mono normal mixing, move data to DMA buffer (final channel)
MACRO	_m8mnf		num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	add	ax,[di+2*num]		; add to word the values from previous
					; channels
	mov	[es:bp+num],ah		; store byte to DMA buffer
ENDM

MixLoop m8mnf, _m8mnf, 32, 16, cx



;/***************************************************************************\
;*
;* Function:	dsm_Mix8MonoNormal
;*
;* Description: The actual normal-quality 8-bit mono mixing routine
;*
;* Input:	gs		sample data segment
;*		esi		sample mixing position from the beginning of
;*				the segment, in 16.16 fixed point format
;*		edx		sample mixing position increment for each
;*				destination byte, 16.16 fixed point format
;*		di		pointer to (temporary) mixing buffer in
;*				volume table segment
;*		cx		number of bytes to mix
;*		al		volume to be used
;*		ah		current channel number
;*		bl		1 if data to be mixed, 0 if not (even if there
;*				is no data to be mixed, the mixing routine
;*				must be called anyway - the buffer might not
;*				be cleared etc.)
;*
;* Returns:	esi		new mixing position
;*		di		new destination position
;*
;* Destroys:	ax, ebx, cx, edx, esi, di
;*
;\***************************************************************************/

PROC	dsm_Mix8MonoNormal	NEAR
LOCAL	chan : byte, destOffs : word, destLen : word

	mov	[destOffs],di		; store destination offset
	mov	[destLen],cx		; and mixing length
	mov	[chan],ah
	or	cx,cx			; don't mix zero bytes
	jz	@@done

	or	bl,bl			; is there data to be mixed?
	jnz	@@hasdata

	or	ah,ah			; no data to be mixed - first channel?
	jnz	@@nodata

	mov	ax,8000h		; first channel - clear buffer
	rep	stosw
	jmp	@@nodata


@@hasdata:
	add	al,VOLADD		; convert volume rounding up
	shr	al,VOLSHIFT
	xor	ebx,ebx 		; bh contains volume, bl sample and
	mov	bh,al			; upper word of ebx is zero

	rol	edx,16			; reverse fractional and whole parts
	rol	esi,16			; in mixing position and increment

	mov	al,[chan]
	inc	al			; last channel to be mixed?
	cmp	al,[byte dsmChOpen]	; if is, also move data to DMA buffer
	jae	@@final

	cmp	[chan],0		; the first channel?
	jne	@@add
	mov	ax,offset m8mnm 	; yes, move to mixing buffer
	jmp	@@mix

@@add:	mov	ax,offset m8mna 	; not the first channel - add to buf

@@mix:
	push	ds
	mov	ds,[dsmVolTableSeg]	; point ds to volume table

	push	bp
	push	ax

	mov	ax,cx			; ax = number of bytes to mix
	and	ax,15			; in the first loop
	shl	ax,1
	mov	bp,32			; bp = jump table offset
	sub	bp,ax

	sub	di,bp			; undo di incrementing in loop

	shr	cx,4			; cx = number of loops to mix
	inc	cx

	pop	ax
	add	bp,ax
	call	[word cs:bp]

	pop	bp
	pop	ds

	rol	esi,16			; destore mixing position to its
	jmp	@@done			; original form



@@final:	; final channel - move data into DMA buffer

@@flp1:
	mov	ax,[dsmBuffer.blength]	; ax = number of bytes before
	sub	ax,[dsmMixPos]		; buffer end

	mov	cx,[destLen]
	cmp	cx,ax			; do not copy data over the buffer
	jbe	@@fi1			; end
	mov	cx,ax

@@fi1:	sub	[destLen],cx		; decrease number of bytes left

	push	bp

	mov	ax,cx			; ax = number of bytes to mix
	and	ax,15			; in the first loop
	shl	ax,1
	mov	bp,32			; bp = jump table offset
	sub	bp,ax

	mov	ax,[word m8mnf+bp]	; ax = call destination

	sub	di,bp			; undo di incrementing in loop
	shr	bp,1
	neg	bp			; bp = DMA buffer position - incr
	add	bp,[dsmMixPos]

	shr	cx,4			; cx = number of loops to mix
	inc	cx

	push	ds
	mov	es,[dsmBuffer.bsegment] ; point es to DMA buffer
	mov	ds,[dsmVolTableSeg]	; point ds to voltbl & mixing buffer

	call	ax

	pop	ds
	mov	[dsmMixPos],bp
	pop	bp

	mov	ax,[dsmMixPos]
	cmp	ax,[dsmBuffer.blength]	; did we reach DMA buffer end?
	jb	@@fi2
	xor	ax,ax			; if so, jump to the beginning
@@fi2:
	mov	[dsmMixPos],ax
	cmp	[destLen],0		; any more data left to move?
	jne	@@flp1

	rol	esi,16			; restore mixing position into
					; its original form
	jmp	@@done


@@nodata:	; no data to be mixed on this channel
	mov	al,[chan]
	inc	al			; is this the last channel? If is,
	cmp	al,[byte dsmChOpen]	; data must be moved to DMA buffer
        jb      @@done


	push	es di esi		; save registers that contain
					; meaningful return values

	mov	di,[destOffs]		; es:di points to temporary buffer
	mov	si,[dsmMixPos]		; point si to mixing position
					; (ds is set later)

@@mvlp:
	mov	bx,[dsmBuffer.blength]	; bx = number of bytes before
	sub	bx,si			; buffer end

	mov	cx,[destLen]
	cmp	cx,bx			; do not copy data over the buffer
	jbe	@@mv1			; end
	mov	cx,bx

@@mv1:	sub	[destLen],cx		; decrease number of bytes left

	push	ds
	mov	ds,[dsmBuffer.bsegment] ; point ds to mixing buffer

@@l1:	mov	al,[es:di+1]		; take MSB of word from temp buffer
	add	di,2			; next word in temp buffer
	mov	[ds:si],al		; and move it to DMA buffer
	inc	si			; next byte in DMA buffer
	loop	@@l1

	pop	ds

	cmp	si,[dsmBuffer.blength]	; did we reach DMA buffer end?
	jb	@@mv2
	xor	si,si			; if so, jump to the beginning
@@mv2:
	cmp	[destLen],0		; any more data left to move?
	jne	@@mvlp

	mov	[dsmMixPos],si		; store new mixing position

	pop	esi di es		; restore registers with return values


@@done:
	ret
ENDP





; 8-bit stereo normal mixing - middle, add to temporary buffer
MACRO	_m8snma        num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	add	[di+4*num],ax		; add word into dest left channel
	add	[di+4*num+2],ax 	; add word into dest right channel
ENDM

MixLoop m8snma, _m8snma, 64, 0, [cs:_mixCount]



; 8-bit stereo normal mixing - middle, move to DMA buffer (final channel)
MACRO	_m8snmf        num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	mov	cx,ax			; cx = ax = sample word
	add	ax,[di+4*num]
	mov	al,ah			; al = left channel DMA buffer data
	add	cx,[di+4*num+2]
	mov	ah,ch			; ah = right channel DMA buffer data
	mov	[es:bp+2*num],ax	; store word to DMA buffer
ENDM

MixLoop m8snmf, _m8snmf, 64, 32, [cs:_mixCount]



; 8-bit stereo normal mixing - surround, add to temporary buffer
MACRO	_m8snsa 	num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	add	[di+4*num],ax		; add word into dest left channel
	sub	[di+4*num+2],ax 	; add with 180 degrees phase shift
ENDM

MixLoop m8snsa, _m8snsa, 64, 0, [cs:_mixCount]



; 8-bit stereo normal mixing - surround, move to DMA buffer (final)
MACRO	_m8snsf 	num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	mov	cx,ax			; cx = ax = sample word
	add	ax,[di+4*num]
	mov	al,ah			; al = left channel DMA data
	neg	cx			; phase shift right chan 180 degrees
	add	cx,[di+4*num+2]
	mov	ah,ch			; ah = right channel DMA data
	mov	[es:bp+2*num],ax	; store word into DMA buffer
ENDM

MixLoop m8snsf, _m8snsf, 64, 32, [cs:_mixCount]



; 8-bit stereo normal mixing - left, add to temporary buffer
MACRO	_m8snla        num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	add	[di+4*num],ax		; add word into dest left channel
ENDM

MixLoop m8snla, _m8snla, 64, 0, [cs:_mixCount]



; 8-bit stereo normal mixing - left, move to DMA buffer (final channel)
MACRO	_m8snlf        num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	add	ax,[di+4*num]
	mov	al,ah			; al = left channel DMA data
	mov	ah,[di+4*num+3] 	; ah = right channel DMA data
	mov	[es:bp+2*num],ax	; store word into DMA buffer
ENDM

MixLoop m8snlf, _m8snlf, 64, 32, [cs:_mixCount]



; 8-bit stereo normal mixing - right, add to temporary buffer
MACRO	_m8snra 	num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	add	[di+4*num+2],ax 	; add word into dest right channel
ENDM

MixLoop m8snra, _m8snra, 64, 0, [cs:_mixCount]



; 8-bit stereo normal mixing - right, move to DMA buffer (final channel)
MACRO	_m8snrf 	num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	add	ax,[di+4*num+2] 	; ah = right channel DMA data
	mov	al,[di+4*num+1] 	; al = left channel DMA data
	mov	[es:bp+2*num],ax	; store word into DMA buffer
ENDM

MixLoop m8snrf, _m8snrf, 64, 32, [cs:_mixCount]



; 8-bit stereo normal mixing - smooth panning, add to buffer
MACRO	_m8snpa 	num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take left channel value from vol tbl
	adc	si,0			; add carry to mixing pos whole part
	add	[di+4*num],ax		; add word to destination left channel
	mov	cl,bl
	mov	ax,[ecx+ecx]		; take right ch value from volume tbl
	add	[di+4*num+2],ax 	; add word to dest right channel
ENDM

MixLoop m8snpa, _m8snpa, 64, 0, [cs:_mixCount]



; 8-bit stereo normal mixing - smooth panning, move to DMA buffer (final ch.)
MACRO	_m8snpf 	num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take left channel value from vol tbl
	adc	si,0			; add carry to mixing pos whole part

	mov	cl,bl
	mov	ax,[ebx+ebx]
	add	ax,[di+4*num]
	mov	bl,ah			; bl = left channel DMA data

	mov	ax,[ecx+ecx]
	add	ax,[di+4*num+2] 	; ah = right channel DMA data
	mov	al,bl
	mov	[es:bp+2*num],ax	; store word into DMA buffer
ENDM

MixLoop m8snpf, _m8snpf, 64, 32, [cs:_mixCount]



mix8sna 	DW	offset m8snma		; middle, add
		DW	offset m8snsa		; surround, add
		DW	offset m8snla		; left, add
		DW	offset m8snra		; right, add
		DW	offset m8snpa		; panning, add
mix8snf 	DW	offset m8snmf		; middle, add
		DW	offset m8snsf		; surround, add
		DW	offset m8snlf		; left, add
		DW	offset m8snrf		; right, add
		DW	offset m8snpf		; panning, add


;/***************************************************************************\
;*
;* Function:	dsm_Mix8StereoNormal
;*
;* Description: The actual normal-quality 8-bit stereo mixing routine
;*
;* Input:	gs		sample data segment
;*		esi		sample mixing position from the beginning of
;*				the segment, in 16.16 fixed point format
;*		edx		sample mixing position increment for each
;*				destination byte, 16.16 fixed point format
;*		di		pointer to (temporary) mixing buffer in
;*				volume table segment
;*		cx		number of bytes to mix
;*		al		volume to be used
;*		ah		current channel number
;*		bl		1 if data to be mixed, 0 if not (even if there
;*				is no data to be mixed, the mixing routine
;*				must be called anyway - the buffer might not
;*				be cleared etc.)
;*		bh		panning information
;*
;* Returns:	esi		new mixing position
;*		di		new destination position
;*
;* Destroys:	ax, ebx, cx, edx, esi, di
;*
;\***************************************************************************/


PROC	dsm_Mix8StereoNormal	NEAR
LOCAL	chan : byte,  destOffs : word, destLen : word, mixlp : word, \
	panning : byte, volume : byte, lastChan : byte

	mov	[destOffs],di		; store destination offset
	mov	[destLen],cx		; and mixing length
	mov	[chan],ah		; store channel number
	mov	[panning],bh		; store panning information
	add	al,VOLADD		; convert volume rounding up
	shr	al,VOLSHIFT
	mov	[volume],al		; store volume
	or	cx,cx			; don't mix zero bytes
	jz	@@done

        test    ah,ah                   ; first channel?
	jnz	@@notfirst

	mov	ax,8000h
	shl	cx,1			; first channel - clear temp. buffer
	rep	stosw
	mov	di,[destOffs]
	mov	cx,[destLen]

@@notfirst:
        mov     al,[chan]
        inc     al
        cmp     al,[byte dsmChOpen]     ; the last channel to be mixed?
        jae     @@lchan

        mov     [lastChan],0            ; no
	jmp	@@nlc

@@lchan:
	mov	[lastChan],1		; yes

@@nlc:
	or	bl,bl			; is there data to be mixed?
	jz	@@nodata

	push	es

	xor	ebx,ebx 		; bh contains volume, bl sample and
					; upper word of ebx is zero

	rol	edx,16			; reverse fractional and whole parts
	rol	esi,16			; in mixing position and increment

	mov	es,[dsmBuffer.bsegment] ; point es to DMA buffer


@@buflp:
	cmp	[lastChan],0		; last channel to be mixed?
	je	@@nlast 		; if not, do not check if there is
					; enough space in DMA buffer - data
					; will not end up there anyway

	mov	ax,[dsmBuffer.blength]	; ax = number of bytes of space before
	sub	ax,[dsmMixPos]		; buffer end
	shr	ax,1			; number of words (stereo)
	cmp	cx,ax			; enough space in buffer?
	jbe	@@cxok
	mov	cx,ax			; if not, don't mix past buffer end
@@cxok:
	mov	ax,[dsmMixPos]
	mov	[_bpvalue],ax		; bp points to DMA buffer position

	mov	ax,offset mix8snf	; last channel - move data to DMA
					; buffer

	jmp	@@mixok

@@nlast:
	mov	ax,offset mix8sna	; not the last channel - add data to
					; temporary buffer

@@mixok:
	sub	[destLen],cx		; decrease amount of data left

@@mix:
	mov	[_mixCount],cx

	cmp	[panning],panMiddle
	je	@@middle
	cmp	[panning],panSurround
	je	@@surround
        cmp     [panning],panLeft and 0FFh
	je	@@left
	cmp	[panning],panRight
	je	@@right
	jmp	@@smoothp		; smooth panning


@@middle:	; use middle mixing routine (the first one)
	mov	bh,[volume]		; divide volume with two - sound is
	shr	bh,1			; played from both left and right
	jmp	@@panok

@@surround:
	add	ax,2			; use surround mixing routine
	mov	bh,[volume]		; divide volume with two - sound is
	shr	bh,1			; played from both left and right
	jmp	@@panok


@@left: add	ax,4			; use left mixing routine
	mov	bh,[volume]		; don't divide volume
	jmp	@@panok

@@right:
	add	ax,6			; use right mixing routine
	mov	bh,[volume]		; don't divide volume
	jmp	@@panok

@@smoothp:	; smooth panning
	add	ax,8			; use smooth panning mixing routine
	push	ax

	xor	ecx,ecx

	mov	al,[panning]
	add	al,64
	mul	[volume]
	shr	ax,7
	mov	ch,al			; ch = right channel volume
	mov	bh,[volume]
	sub	bh,ch			; bh = left channel volume

	pop	ax

@@panok:
	push	bp
	push	ds

	mov	ds,[dsmVolTableSeg]	; point ds to volume table

	mov	bp,ax
	mov	ax,[cs:bp]		; point ax to mixing routine jump tbl
	push	ax

	mov	ax,[_mixCount]		; ax = number of words to mix
	and	ax,15			; in the first loop
	shl	ax,1
	mov	bp,32			; bp = jump table offset
	sub	bp,ax

	shl	bp,1
	sub	di,bp			; undo di incrementing in loop
	shr	bp,1
	sub	[_bpvalue],bp		; undo bp incrementing in loop

	shr	[_mixCount],4		; _mixCount = number of loops to mix
	inc	[_mixCount]

	pop	ax
	add	bp,ax
	mov	ax,[cs:bp]
	mov	bp,[_bpvalue]
	call	ax			; call mixing routine

	pop	ds
	mov	[_bpvalue],bp
	pop	bp


	cmp	[lastChan],0		; is this the last channel?
	je	@@mixdone		; if not, we are finished

	mov	ax,[_bpvalue]		; store new mixing position
	mov	[dsmMixPos],ax

	mov	ax,[dsmMixPos]
	cmp	ax,[dsmBuffer.blength]	; are we at buffer end?
	jb	@@nowrap
	mov	[dsmMixPos],0		; move to buffer beginning
@@nowrap:
	cmp	[destLen],0		; still data to mix?
	je	@@mixdone

	mov	cx,[destLen]		; mix the rest
	jmp	@@buflp


@@mixdone:
	rol	esi,16			; restore mixing position into
					; its original form
	pop	es
	jmp	@@done


@@nodata:	; no data to be mixed on this channel

	cmp	[lastChan],0		; is this the last channel?
	je	@@done			; if not, there is no need to do
					; anything

	; no data on the final channel - just move the data to DMA buffer

	push	es esi			; save registers that contain
					; meaningful return values

	mov	si,[destOffs]		; point si to temporary buffer pos
	mov	di,[dsmMixPos]		; point es:di to mixing buffer pos
	mov	es,[dsmBuffer.bsegment]


@@mvlp:
	mov	bx,[dsmBuffer.blength]	; bx = number of bytes before
	sub	bx,di			; buffer end
	shr	bx,1			; number of words (stereo)

	mov	cx,[destLen]
	cmp	cx,bx			; do not copy data over the buffer
	jbe	@@mv1			; end
	mov	cx,bx

@@mv1:	sub	[destLen],cx		; decrease number of bytes left

	push	ds
	mov	ds,[dsmVolTableSeg]	; temporary buffer is in volume table
					; segment

@@l1:	mov	al,[si+1]		; al = DMA data for left channel
	mov	ah,[si+3]		; ah = DMA data for right channel
	add	si,4
	mov	[es:di],ax		; move word to DMA buffer
	add	di,2			; next word in DMA buffer
	loop	@@l1

	pop	ds

	cmp	di,[dsmBuffer.blength]	; did we reach DMA buffer end?
	jb	@@mv2
	xor	di,di			; if so, jump to the beginning
@@mv2:
	cmp	[destLen],0		; any more data left to move?
	jne	@@mvlp

	mov	[dsmMixPos],di		; store new mixing position

	mov	di,si			; new temp. buffer position is
					; returned in di

	pop	esi es			; restore registers with return values

@@done:
	ret
ENDP







; 16-bit mono normal mixing - add to buffer
MACRO	_m16mna 	num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	add	[es:di+2*num],ax	; add byte into destination
ENDM

MixLoop m16mna, _m16mna, 32, 0, cx



; 16-bit mono normal mixing - move to buffer (first channel)
MACRO	_m16mnm 	num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	mov	[es:di+2*num],ax	; add byte into destination
ENDM

MixLoop m16mnm, _m16mnm, 32, 0, cx



;/***************************************************************************\
;*
;* Function:	dsm_Mix16MonoNormal
;*
;* Description: The actual normal-quality 16-bit mono mixing routine
;*
;* Input:	gs		sample data segment
;*		esi		sample mixing position from the beginning of
;*				the segment, in 16.16 fixed point format
;*		edx		sample mixing position increment for each
;*				destination byte, 16.16 fixed point format
;*		es:di		pointer to mixing buffer (assumed to be in
;*				dsmBuffer)
;*		cx		number of bytes to mix
;*		al		volume to be used
;*		ah		current channel number
;*		bl		1 if data to be mixed, 0 if not (even if there
;*				is no data to be mixed, the mixing routine
;*				must be called anyway - the buffer might not
;*				be cleared etc.)
;*
;* Returns:	esi		new mixing position
;*		di		new destination position
;*
;* Destroys:	ax, ebx, cx, edx, esi, di
;*
;\***************************************************************************/

PROC	dsm_Mix16MonoNormal	 NEAR
LOCAL	chan : byte,  destOffs : word, destLen : word, mixlp : word

	mov	[destOffs],di		; store destination offset
	mov	[destLen],cx		; and mixing length
	mov	[chan],ah		; store channel number
	or	cx,cx			; don't mix zero bytes
	jz	@@done

	or	bl,bl			; is there data to be mixed?
	jnz	@@hasdata

	or	ah,ah			; no data to be mixed - first channel?
	jz	@@first

	; not the first channel - just update di as if data was mixed

	shl	cx,1			; cx = number of bytes
	add	di,cx			; di = new mixing position
	cmp	di,[dsmBuffer.blength]	; past buffer end?
	jb	@@1
	sub	di,[dsmBuffer.blength]
@@1:	jmp	@@nodata

@@first:
	; this is the first channel and must therefore be cleared even if
	; there is no data to be mixed

	mov	bx,[dsmBuffer.blength]	; bx = number of bytes before buffer
	sub	bx,di			; end
	shr	bx,1			; number of words
	cmp	bx,cx			; if all data fits to the buffer,
	jae	@@clrok 		; just clear it.

	mov	cx,bx			; clear buffer to its end
	xor	ax,ax
	rep	stosw

	xor	di,di			; jump to buffer beginning
	mov	cx,[destLen]		; and clear required amount of bytes
	sub	cx,bx			; from the buffer beginning

@@clrok:
	xor	ax,ax
	rep	stosw			; clear the rest of buffer
	jmp	@@nodata



@@hasdata:
	add	al,VOLADD		; convert volume rounding up
	shr	al,VOLSHIFT
	xor	ebx,ebx 		; bh contains volume, bl sample and
	mov	bh,al			; upper word of ebx is zero

	rol	edx,16			; reverse fractional and whole parts
	rol	esi,16			; in mixing position and increment


@@buflp:
	mov	ax,[dsmBuffer.blength]	; ax = number of bytes of space before
	sub	ax,di			; buffer end
	shr	ax,1			; number of words
	cmp	cx,ax			; enough space in buffer?
	jbe	@@mixok
	mov	cx,ax			; if not, don't mix past buffer end

@@mixok:
	sub	[destLen],cx		; decrease number of words left

	cmp	[chan],0		; first channel?
	je	@@move
	mov	ax,offset m16mna	; no, add data to buffer
	jmp	@@mix

@@move: mov	ax,offset m16mnm	; yes, move data to buffer

@@mix:
	push	ds

	mov	ds,[dsmVolTableSeg]	; point ds to volume table

	push	bp
	push	ax

	mov	ax,cx			; ax = number of words to mix
	and	ax,15			; in the first loop
	shl	ax,1
	mov	bp,32			; bp = jump table offset
	sub	bp,ax

	sub	di,bp			; undo di incrementing in loop

	shr	cx,4			; cx = number of loops to mix
	inc	cx

	pop	ax
	add	bp,ax
	call	[word cs:bp]		; call mixing routine

	pop	bp
	pop	ds

	cmp	[destLen],0		; still data to mix?
	je	@@mixdone

	; there is still data to mix - apparently we are at the buffer end
	; and must continue from the beginning

	xor	di,di			; move to buffer beginning
	mov	cx,[destLen]		; mix the rest
	jmp	@@buflp

@@mixdone:
	rol	esi,16			; restore mixing position into
					; its original form
	jmp	@@done


@@nodata:	; no data to be mixed on this channel

@@done:
	mov	al,[chan]
	inc	al			; last channel to be mixed?
	cmp	al,[byte dsmChOpen]
	jb	@@nofinal

	mov	[dsmMixPos],di		; if is, record new mixing position

@@nofinal:
	ret
ENDP




; 16-bit stereo normal mixing - middle, add to buffer
MACRO	_m16snma	num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	add	[es:di+4*num],ax	; add word into dest left channel
	add	[es:di+4*num+2],ax	; add word into dest right channel
ENDM

MixLoop m16snma, _m16snma, 64, 0, cx



; 16-bit stereo normal mixing - middle, move to buffer (first channel)
MACRO	_m16snmm	num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	mov	[es:di+4*num],ax	; move word into dest left channel
	mov	[es:di+4*num+2],ax	; move word into dest right channel
ENDM

MixLoop m16snmm, _m16snmm, 64, 0, cx



; 16-bit stereo normal mixing - surround, add to buffer
MACRO	_m16snsa	num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	add	[es:di+4*num],ax	; add word into dest left channel
	sub	[es:di+4*num+2],ax	; add with 180 degrees phase shift
ENDM

MixLoop m16snsa, _m16snsa, 64, 0, cx



; 16-bit stereo normal mixing - surround, move to buffer (first channel)
MACRO	_m16snsm	num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	mov	[es:di+4*num],ax	; move word into dest left channel
	neg	ax			; 180 degrees phase shift
	mov	[es:di+4*num+2],ax	; move word into dest right channel
ENDM

MixLoop m16snsm, _m16snsm, 64, 0, cx



; 16-bit stereo normal mixing - left, add to buffer
MACRO	_m16snla	num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	add	[es:di+4*num],ax	; add word into dest left channel
ENDM

MixLoop m16snla, _m16snla, 64, 0, cx



; 16-bit stereo normal mixing - left, move to buffer (first channel)
MACRO	_m16snlm	num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	mov	[es:di+4*num],ax	; move word into dest left channel
	mov	[word es:di+4*num+2],0	; move word into dest right channel
ENDM

MixLoop m16snlm, _m16snlm, 64, 0, cx



; 16-bit stereo normal mixing - right, add to buffer
MACRO	_m16snra	num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	add	[es:di+4*num+2],ax	; add word into dest right channel
ENDM

MixLoop m16snra, _m16snra, 64, 0, cx



; 16-bit stereo normal mixing - right, move to buffer (first channel)
MACRO	_m16snrm	num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take correct value from volume tbl
	adc	si,0			; add the carry to mixing position
					; whole part
	mov	[word es:di+4*num],0	; move word into dest left channel
	mov	[es:di+4*num+2],ax	; move word into dest right channel
ENDM

MixLoop m16snrm, _m16snrm, 64, 0, cx



; 16-bit stereo normal mixing - smooth panning, add to buffer
MACRO	_m16snpa	num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take left channel value from vol tbl
	adc	si,0			; add carry to mixing pos whole part
	add	[es:di+4*num],ax	; add word to destination left channel
	mov	cl,bl
	mov	ax,[ecx+ecx]		; take right ch value from volume tbl
	add	[es:di+4*num+2],ax	; add word to dest right channel
ENDM

MixLoop m16snpa, _m16snpa, 64, 0, [cs:_mixCount]



; 16-bit stereo normal mixing - smooth panning, add to buffer
MACRO	_m16snpm	num
	mov	bl,[gs:si]		; take byte from source
	add	esi,edx 		; point to next sample byte
	mov	ax,[ebx+ebx]		; take left channel value from vol tbl
	adc	si,0			; add carry to mixing pos whole part
	mov	[es:di+4*num],ax	; move word to dest left channel
	mov	cl,bl
	mov	ax,[ecx+ecx]		; take right ch value from volume tbl
	mov	[es:di+4*num+2],ax	; move word to dest right channel
ENDM

MixLoop m16snpm, _m16snpm, 64, 0, [cs:_mixCount]




mix16sna	DW	offset m16snma		; middle, add
		DW	offset m16snsa		; surround, add
		DW	offset m16snla		; left, add
		DW	offset m16snra		; right, add
		DW	offset m16snpa		; panning, add
mix16snm	DW	offset m16snmm		; middle, move
		DW	offset m16snsm		; surround, move
		DW	offset m16snlm		; left, move
		DW	offset m16snrm		; right, move
		DW	offset m16snpm		; panning, move


;/***************************************************************************\
;*
;* Function:	dsm_Mix16StereoNormal
;*
;* Description: The actual normal-quality 16-bit stereo mixing routine
;*
;* Input:	gs		sample data segment
;*		esi		sample mixing position from the beginning of
;*				the segment, in 16.16 fixed point format
;*		edx		sample mixing position increment for each
;*				destination byte, 16.16 fixed point format
;*		es:di		pointer to mixing buffer (assumed to be in
;*				dsmBuffer)
;*		cx		number of bytes to mix
;*		al		volume to be used
;*		ah		current channel number
;*		bl		1 if data to be mixed, 0 if not (even if there
;*				is no data to be mixed, the mixing routine
;*				must be called anyway - the buffer might not
;*				be cleared etc.)
;*		bh		panning information
;*
;* Returns:	esi		new mixing position
;*		di		new destination position
;*
;* Destroys:	ax, ebx, cx, edx, esi, di
;*
;\***************************************************************************/

PROC	dsm_Mix16StereoNormal	NEAR
LOCAL	chan : byte,  destOffs : word, destLen : word, mixlp : word, \
	panning : byte, volume : byte

	mov	[destOffs],di		; store destination offset
	mov	[destLen],cx		; and mixing length
	mov	[chan],ah		; store channel number
	mov	[panning],bh		; store panning information
	add	al,VOLADD		; convert volume rounding up
	shr	al,VOLSHIFT
	mov	[volume],al		; store volume
	or	cx,cx			; don't mix zero bytes
	jz	@@done

	or	bl,bl			; is there data to be mixed?
	jnz	@@hasdata

	or	ah,ah			; no data to be mixed - first channel?
	jz	@@first

	; not the first channel - just update di as if data was mixed

	shl	cx,2			; cx = number of bytes
	add	di,cx			; di = new mixing position
	cmp	di,[dsmBuffer.blength]	; past buffer end?
	jb	@@1
	sub	di,[dsmBuffer.blength]
@@1:	jmp	@@nodata

@@first:
	; this is the first channel and must therefore be cleared even if
	; there is no data to be mixed

	mov	bx,[dsmBuffer.blength]	; bx = number of bytes before buffer
	sub	bx,di			; end
	shr	bx,2			; number of words / 2 (stereo)
	cmp	bx,cx			; if all data fits to the buffer,
	jae	@@clrok 		; just clear it.

	mov	cx,bx			; clear buffer to its end
	xor	eax,eax
	rep	stosd

	xor	di,di			; jump to buffer beginning
	mov	cx,[destLen]		; and clear required amount of bytes
	sub	cx,bx			; from the buffer beginning

@@clrok:
	xor	eax,eax
	rep	stosd			; clear the rest of buffer
	jmp	@@nodata



@@hasdata:
	xor	ebx,ebx 		; bh contains volume, bl sample and
					; upper word of ebx is zero

	rol	edx,16			; reverse fractional and whole parts
	rol	esi,16			; in mixing position and increment


@@buflp:
	mov	ax,[dsmBuffer.blength]	; ax = number of bytes of space before
	sub	ax,di			; buffer end
	shr	ax,2			; number of words / 2 (stereo)
	cmp	cx,ax			; enough space in buffer?
	jbe	@@mixok
	mov	cx,ax			; if not, don't mix past buffer end

@@mixok:
	sub	[destLen],cx		; decrease amount of data left

	cmp	[chan],0		; first channel?
	je	@@move
	mov	ax,offset mix16sna	; no, add data to buffer
	jmp	@@mix

@@move: mov	ax,offset mix16snm	; yes, move data to buffer

@@mix:
	cmp	[panning],panMiddle
	je	@@middle
	cmp	[panning],panSurround
	je	@@surround
        cmp     [panning],panLeft and 0FFh
	je	@@left
	cmp	[panning],panRight
	je	@@right
	jmp	@@smoothp		; smooth panning


@@middle:	; use middle mixing routine (the first one)
	mov	bh,[volume]		; divide volume with two - sound is
	shr	bh,1			; played from both left and right
	jmp	@@panok

@@surround:
	add	ax,2			; use surround mixing routine
	mov	bh,[volume]		; divide volume with two - sound is
	shr	bh,1			; played from both left and right
	jmp	@@panok


@@left: add	ax,4			; use left mixing routine
	mov	bh,[volume]		; don't divide volume
	jmp	@@panok

@@right:
	add	ax,6			; use right mixing routine
	mov	bh,[volume]		; don't divide volume
	jmp	@@panok

@@panok:
	push	ds

	mov	ds,[dsmVolTableSeg]	; point ds to volume table

	push	bp
	mov	bp,ax
	mov	ax,[cs:bp]		; point ax to mixing routine jump tbl

	push	ax

	mov	ax,cx			; ax = number of words to mix
	and	ax,15			; in the first loop
	shl	ax,1
	mov	bp,32			; bp = jump table offset
	sub	bp,ax

	shl	bp,1
	sub	di,bp			; undo di incrementing in loop
	shr	bp,1

	shr	cx,4			; cx = number of loops to mix
	inc	cx

	pop	ax
	add	bp,ax
	call	[word cs:bp]		; call mixing routine

	pop	bp
	pop	ds
	jmp	@@mixd


@@smoothp:	; smooth panning
	mov	[_mixCount],cx		; save mix counter

	push	ds
	push	bp

	add	ax,8			; use smooth panning mixing routine
	mov	bx,ax
	mov	ax,[cs:bx]		; point ax to mixing routine jump tbl
	push	ax			; save jump table

	xor	ecx,ecx

	mov	al,[panning]
	add	al,64
	mul	[volume]
	shr	ax,7
	mov	ch,al			; ch = right channel volume
	mov	bh,[volume]
	sub	bh,ch			; bh = left channel volume


	mov	ds,[dsmVolTableSeg]	; point ds to volume table

	mov	ax,[_mixCount]		; ax = number of words to mix
	and	ax,15			; in the first loop
	shl	ax,1
	mov	bp,32			; bp = jump table offset
	sub	bp,ax

	shl	bp,1
	sub	di,bp			; undo di incrementing in loop
	shr	bp,1

	shr	[_mixCount],4		; _mixCount = number of loops to mix
	inc	[_mixCount]

	pop	ax
	add	bp,ax
	call	[word cs:bp]		; call mixing routine

	pop	bp
	pop	ds


@@mixd:
	cmp	[destLen],0		; still data to mix?
	je	@@mixdone

	; there is still data to mix - apparently we are at the buffer end
	; and must continue from the beginning

	xor	di,di			; move to buffer beginning
	mov	cx,[destLen]		; mix the rest
	jmp	@@buflp

@@mixdone:
	rol	esi,16			; restore mixing position into
					; its original form
	jmp	@@done


@@nodata:	; no data to be mixed on this channel

@@done:
	mov	al,[chan]
	inc	al			; last channel to be mixed?
	cmp	al,[byte dsmChOpen]
	jb	@@nofinal

	mov	[dsmMixPos],di		; if is, record new mixing position

@@nofinal:
	ret
ENDP




END
