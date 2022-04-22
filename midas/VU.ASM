;*	VU.ASM
;*
;* Real VU meter routines
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
INCLUDE "vu.inc"
INCLUDE "mmem.inc"
INCLUDE "sdevice.inc"


VUBLOCK = 128				; VU calculation block size
VUBSHIFT = 7				; shr value to convert from bytes to
					; blocks



DATASEG

vuInsts 	DD	?		; pointer to instrument info table



CODESEG


;/***************************************************************************\
;*
;* Function:     int vuInit(void);
;*
;* Description:  Initializes VU-meters, allocating room for MAXINSTS
;*               instruments.
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	vuInit		FAR
USES	di

        ; Allocate memory for instrument information structures:
        call    memAlloc LANG, MAXINSTS * SIZE vuInstrument, \
                seg vuInsts offset vuInsts
        test    ax,ax
        jnz     @@err

        les     di,[vuInsts]
        xor     al,al                            ; initialize instrument
        mov     cx,MAXINSTS * SIZE vuInstrument  ; information to all zeros
	rep	stosb

        xor     ax,ax                   ; success
        jmp     @@done

@@err:  ERROR   ID_vuInit

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:     int vuClose(void);
;*
;* Description:  Uninitializes VU-meters
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	vuClose 	FAR
USES    si,di

        les     si,[vuInsts]            ; point es:bx to first instrument
        mov     di,MAXINSTS

@@ilp:  cmp     [es:si+vuInstrument.vuInfo],0   ; allocated VU information?
	je	@@iok
        push    es
        call    memFree LANG, [es:si+vuInstrument.vuInfo]       ; deallocate
        pop     es
        test    ax,ax
        jnz     @@err

@@iok:  add     si,size vuInstrument    ; next instrument
        dec     di
        jnz     @@ilp

	call	memFree LANG, [vuInsts] 	; deallocate instrument info
        test    ax,ax
        jnz     @@err

        xor     ax,ax
        jmp     @@done

@@err:
        ERROR   ID_vuClose

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:     int vuPrepare(ushort inst, uchar *sample, ushort slength,
;*                             ushort loopStart, ushort loopEnd);
;*
;* Description:  Prepares the VU information for an instrument
;*
;* Input:        ushort inst             instrument number
;*               uchar *sample           pointer to sample data
;*               ushort slength          sample length
;*               ushort loopStart        sample loop start
;*               ushort loopEnd          sample loop end (0 if no looping)
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	vuPrepare	FAR	inst : word, sample : dword, slength : word,\
				loopStart : word, loopEnd : word
USES	di,si

	mov	ax,[inst]
        cmp     ax,MAXINSTS                    ; instrument number too large?
        jb      @@iok

        mov     ax,errNoInstHandles             ; out of instrument handles
        jmp     @@err

@@iok:
	les	si,[vuInsts]
	imul	ax,ax,size vuInstrument 	; point es:si to instrument
	add	si,ax				; information

	cmp	[es:si+vuInstrument.vuInfo],0	; is there allocated VU info?
	je	@@noi
	push	es
	call	memFree LANG, [es:si+vuInstrument.vuInfo]	; deallocate
	pop	es
        test    ax,ax
        jnz     @@err

@@noi:	mov	[es:si+vuInstrument.vuInfo],0	; no VU information
	mov	ax,[slength]
	shr	ax,VUBSHIFT
	inc	ax

        lea     bx,[es:si+vuInstrument.vuInfo]  ; point es:bx to VU info ptr

        ; allocate space for VU information:
	push	es
        call    memAlloc LANG, ax, es bx
	pop	es
        test    ax,ax
        jnz     @@err

	mov	ax,[slength]
	mov	[es:si+vuInstrument.slength],ax
	mov	ax,[loopStart]
	mov	[es:si+vuInstrument.loopStart],ax
	mov	ax,[loopEnd]
	mov	[es:si+vuInstrument.loopEnd],ax

	push	ds
	les	di,[es:si+vuInstrument.vuInfo]	; point es:di to VU info
	lds	si,[sample]			; point ds:si to sample
	mov	bx,[slength]			; sample length counter

@@vublp:
	mov	cx,bx
	cmp	cx,VUBLOCK		; is more than one block left?
	jbe	@@cok			; if yes, calculate only one block's
	mov	cx,VUBLOCK		; worth of data

@@cok:	sub	bx,cx			; decrease sample length counter
	mov	dl,128			; smallest sample value in block
	mov	dh,128			; largest sample value in block

@@blp:	lodsb				; get byte from sample
	cmp	al,dl			; is byte smaller than smallest value?
	jb	@@sm
	cmp	al,dh			; is byte larger than largest value?
	ja	@@lg
@@cblp:
	loop	@@blp			; next byte
	jmp	@@bdone

@@sm:	mov	dl,al			; new smallest value
	jmp	@@cblp

@@lg:	mov	dh,al			; new largest value
	jmp	@@cblp

@@bdone:
	mov	al,dh
	sub	al,dl			; VU value = (largest - smallest) / 4
	xor	ah,ah
	add	ax,2			; round up
	shr	ax,2			; and divide - range is 0-64
	stosb				; store VU value
        test    bx,bx                   ; sample data left?
	jnz	@@vublp 		; if is, continue

	pop	ds

        xor     ax,ax
        jmp     @@done


@@err:  ERROR   ID_vuPrepare

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:     int vuRemove(ushort inst);
;*
;* Description:  Removes and deallocates the VU information for an instrument
;*
;* Input:        ushort inst             instrument number
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC    vuRemove        FAR     inst : word

	mov	ax,[inst]
        cmp     ax,MAXINSTS                     ; instrument number too large?
        jb      @@iok

        mov     ax,errInvalidInstHandle
        jmp     @@err

@@iok:
	les	bx,[vuInsts]
	imul	ax,ax,size vuInstrument 	; point es:bx to instrument
	add	bx,ax				; information

	cmp	[es:bx+vuInstrument.vuInfo],0	; VU information?
        jne     @@ok2

        mov     ax,errInvalidInstHandle
        jmp     @@err

@@ok2:
	push	es bx
	call	memFree LANG, [es:bx+vuInstrument.vuInfo]	; deallocate
	pop	bx es
        test    ax,ax
        jnz     @@err

	mov	[es:bx+vuInstrument.vuInfo],0	; no VU information

        xor     ax,ax
        jmp     @@done

@@err:  ERROR   ID_vuRemove

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:     int vuMeter(ushort inst, ulong rate, ushort pos,
;*                           ushort volume, ushort *meter);
;*
;* Description:  Calculates the VU-meter value (0-64) for the next 1/50th of
;*               a second
;*
;* Input:        ushort inst             instrument that is played
;*               ulong rate              playing rate
;*               ushort pos              playing position
;*               ushort volume           playing volume (0-64)
;*               ushort *meter           pointer to VU-meter value
;*
;* Returns:      MIDAS error code.
;*               VU-meter value (0-64) is stored in *meter
;*
;\***************************************************************************/

PROC	vuMeter 	FAR	inst : word, rate : dword, pos : word, \
                                volume : word, meter : dword
USES	si
LOCAL	bytes : word

	mov	ax,[inst]
        cmp     ax,MAXINSTS                     ; instrument number too large?
        jae     @@invinst

	les	bx,[vuInsts]
	imul	ax,ax,size vuInstrument 	; point es:bx to instrument
	add	bx,ax				; information

	cmp	[es:bx+vuInstrument.vuInfo],0	; VU information?
        je      @@invinst

	mov	eax,[rate]
	xor	edx,edx 		; eax = number of bytes in a 1/50th
	mov	ecx,50			; of a second
	div	ecx

	mov	[bytes],ax

	cmp	[es:bx+vuInstrument.loopEnd],0	; looping sample
	je	@@noloop


	; looping sample

	xor	dl,dl			; VU meter value

@@lp:
	mov	cx,[es:bx+vuInstrument.loopEnd] ; cx = number of bytes to
	sub	cx,[pos]			; loop end
	cmp	cx,[bytes]		; more bytes to loop end than would
	jbe	@@l1			; be played?
	mov	cx,[bytes]

@@l1:	sub	[bytes],cx

	lgs	si,[es:bx+vuInstrument.vuInfo]	; point gs:si to VU info
	mov	ax,[pos]
	shr	ax,VUBSHIFT		; ax = first VU block number
	add	si,ax

	add	cx,VUBLOCK-1		; number of VU blocks
	shr	cx,VUBSHIFT
        test    cx,cx
        jz      @@lpd

@@llp:	mov	al,[gs:si]		; get VU meter value for block
	cmp	al,dl			; greater than current meter value?
	jbe	@@llp1
	mov	dl,al			; if is, set current meter value
@@llp1:
	inc	si			; next VU block
        loop    @@llp

@@lpd:
	cmp	[bytes],0		; more sample data left?
        je      @@vuok

	mov	ax,[es:bx+vuInstrument.loopStart]
	mov	[pos],ax		; move to sample loop start

	mov	cx,[es:bx+vuInstrument.loopEnd]
	sub	cx,ax			; cx = loop length
	cmp	[bytes],cx
	jb	@@l2			; do not calculate the loop more than
	mov	[bytes],cx		; once

@@l2:	jmp	@@lp



@@noloop:
	mov	cx,[es:bx+vuInstrument.slength] ; cx = number of bytes to
	sub	cx,[pos]			; sample end

	cmp	cx,ax			; more bytes left than would be
	jbe	@@nl1			; played?
	mov	cx,ax

@@nl1:	lgs	si,[es:bx+vuInstrument.vuInfo]	; point gs:si to VU info
	mov	dx,[pos]		; sample playing position
	mov	ax,dx
	shr	ax,VUBSHIFT		; ax = first VU block number
	add	si,ax

	add	cx,VUBLOCK-1		; number of VU blocks before end
	shr	cx,VUBSHIFT
        test    cx,cx
        jz      @@vuok

	xor	dl,dl			; VU meter value

@@nll:	mov	al,[gs:si]		; get VU meter value for block
	cmp	al,dl			; greater than current meter value?
	jbe	@@nll1
	mov	dl,al			; if is, set current meter value
@@nll1:
	inc	si			; next VU block
	loop	@@nll


@@vuok:
        movzx   ax,dl                   ; ax = VU meter value
        cmp     ax,64
        jbe     @@vuvalok               ; make sure value is <= 64
        mov     ax,64

@@vuvalok:
        mul     [volume]                ; multiply value with volume
	shr	ax,6			; and divide with 64

        les     bx,[meter]              ; store VU meter value
        mov     [es:bx],ax

        xor     ax,ax
        jmp     @@done

@@invinst:
        mov     ax,errInvalidInstHandle

@@err:  ERROR   ID_vuMeter

@@done:
	ret
ENDP



END
