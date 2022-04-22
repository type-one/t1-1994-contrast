;*	DMA.ASM
;*
;* DMA handling routines, v1.10
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
INCLUDE "dma.inc"
INCLUDE "mmem.inc"


DATASEG

bptr            DD      ?



IDATASEG



;/***************************************************************************\
;*     DMA channel data
;\***************************************************************************/

dmaChns dmaChannel      < 0, 1, 000h, 001h, 009h, 00Ah, 00Bh, 00Ch, 087h >
	dmaChannel	< 1, 2, 002h, 003h, 009h, 00Ah, 00Bh, 00Ch, 083h >
	dmaChannel	< 2, 4, 004h, 005h, 009h, 00Ah, 00Bh, 00Ch, 081h >
	dmaChannel	< 3, 8, 006h, 007h, 009h, 00Ah, 00Bh, 00Ch, 082h >
	dmaChannel	< 4, 1, 0C0h, 0C2h, 0D2h, 0D4h, 0D6h, 0D8h, 08Fh >
	dmaChannel	< 5, 2, 0C4h, 0C6h, 0D2h, 0D4h, 0D6h, 0D8h, 08Bh >
	dmaChannel	< 6, 4, 0C8h, 0CAh, 0D2h, 0D4h, 0D6h, 0D8h, 089h >
	dmaChannel	< 7, 8, 0CCh, 0CEh, 0D2h, 0D4h, 0D6h, 0D8h, 08Ah >



CODESEG



;/***************************************************************************\
;*
;* Function:     int dmaAllocBuffer(ushort size, dmaBuffer *buf);
;*
;* Description:  Allocates a DMA buffer (totally inside a 64K physical page)
;*
;* Input:        ushort size             size of buffer in bytes
;*               dmaBuffer *buf          ptr to buffer structure to be filled
;*
;* Returns:      MIDAS error code.
;*               DMA buffer data is strored in *buf.
;*
;\***************************************************************************/

PROC    dmaAllocBuffer  FAR     bsize : word, buf : dword

	cmp	[bsize],32000		; buffer size must not be > 32000
        jbe     @@bok                   ; bytes
        mov     [bsize],32000

@@bok:
	mov	ax,[bsize]		; ax = buffer size
	shl	ax,1			; multiply by two so that it can
        add     ax,64                   ; always be fitted inside one 64K
                                        ; page and add 64 for segment
                                        ; alignment

        ; Allocate memory for buffer:
        les     bx,[buf]
        lea     dx,[bx+dmaBuffer.memBlk]  ; point es:dx to buffer.memBlk
        push    es bx
        call    memAlloc LANG, ax, es dx  ; allocate the memory
        pop     bx es
        test    ax,ax                   ; error? (ax non-zero)
        jnz     @@err

        mov     dx,[word es:bx+2+dmaBuffer.memBlk]      ; point dx:ax to
        mov     ax,[word es:bx+dmaBuffer.memBlk]        ; buffer memory

	shr	ax,4
	add	dx,ax			; dx = buffer segment
	inc	dx			; (segment + offset / 16 + 1)

	mov	ax,dx			; ax = segment AND 0FFFh
	and	ax,0FFFh

	mov	cx,[bsize]
	add	cx,15
	shr	cx,4			; cx = 0FFFh - (size + 15) / 16
	neg	cx
        add     cx,0FFFh

        cmp     ax,cx                   ; does buffer cross a 64K page
	jb	@@ok			; boundary? (ax >= cx)

	and	dx,0F000h		; yes, move it to the beginning of
	add	dx,01000h		; next page

@@ok:	mov	[es:bx+dmaBuffer.bsegment],dx	; store buffer segment
	movzx	eax,dx
	shl	eax,4
	mov	[es:bx+dmaBuffer.address],eax	; address = segment * 16

	mov	ax,[bsize]			; store buffer length
	mov	[es:bx+dmaBuffer.blength],ax

	mov	[es:bx+dmaBuffer.channel],-1	; buffer is not being played

        xor     ax,ax                   ; allocation succesful
        jmp     @@done

@@err:
        ERROR ID_dmaAllocBuffer

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:     int dmaFreeBuffer(dmaBuffer *buf);
;*
;* Description:  Deallocates an allocated DMA buffer
;*
;* Input:        dmaBuffer *buf          ptr to buffer to be deallocated
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	dmaFreeBuffer	FAR	buf : dword

	les	bx,[buf]		; point es:bx to buffer
	call	memFree LANG, [es:bx+dmaBuffer.memBlk]	; free buffer memory
        test    ax,ax
        jz      @@done

        ERROR ID_dmaFreeBuffer

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:     int dmaPlayBuffer(dmaBuffer *buf, ushort channel,
;*                                 ushort autoInit);
;*
;* Description:  Plays a DMA buffer
;*
;* Input:        dmaBuffer *buf          buffer to be player
;*               ushort channel          DMA channel number
;*               ushort autoInit         use autoinitialization?
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	dmaPlayBuffer	FAR	buf : DWORD, channel : WORD, autoInit : WORD
USES	si,di

	les	di,[buf]		; es:di points to DMA buffer struct

        ; si is the offset to right channel structure from the
        ; beginning of dmaChns:
        imul    si,[channel],SIZE dmaChannel

        mov     al,[si+dmaChns.number]
	xor	ah,ah
	mov	[es:di+dmaBuffer.channel],ax
	and	al,3				; reset DMA request
        mov     dx,[si+dmaChns.request]
	out	dx,al

	or	al,4
        mov     dx,[si+dmaChns.singleMask]      ; mask out the channel
	out	dx,al

        mov     al,[si+dmaChns.number]
	and	al,3
	or	al,8 or 64		; read mode, single mode
	cmp	[autoInit],1		; use auto-initialization?
	jne	@@noai
	or	al,16			; enable auto-initialization

@@noai: mov     dx,[si+dmaChns.mode]
	out	dx,al

	mov	ebx,[es:di+dmaBuffer.address]	; physical start addr
        mov     dx,[si+dmaChns.page]
	mov	eax,ebx
	shr	eax,16			; al = DMA page
	out	dx,al

        mov     dx,[si+dmaChns.clearFF] ; clear byte pointer flip-flop
	xor	al,al			; so that next write to a 16-bit reg
	out	dx,al			; will go to the low byte

        mov     dx,[si+dmaChns.baseAddr]
        cmp     [si+dmaChns.number],3   ; 16-bit channel?
	jbe	@@no16
	shr	ebx,1			; starting word instead of byte

@@no16:
	mov	al,bl
	out	dx,al			; set base address low byte
	mov	al,bh
	out	dx,al			; set base address high byte

@@based:
	mov	bx,[es:di+dmaBuffer.blength]	; buffer length
        cmp     [si+dmaChns.number],3           ; 16-bit channel?
	jbe	@@no16_2
	shr	bx,1			; convert to _word_ (16-bit) count

@@no16_2:
	dec	bx			; word count = length - 1
        mov     dx,[si+dmaChns.wordCount]
	mov	al,bl
	out	dx,al			; set word count low byte
	mov	al,bh
	out	dx,al			; set word count high byte

@@countd:
        mov     al,[si+dmaChns.number]
	and	al,3
        mov     dx,[si+dmaChns.singleMask]      ; enable channel
	out	dx,al

        xor     ax,ax                   ; success

	ret
ENDP




;/***************************************************************************\
;*
;* Function:     int dmaStop(ushort channel);
;*
;* Description:  Stops DMA playing
;*
;* Input:        ushort channel          DMA channel number
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	dmaStop 	FAR	channel : WORD
USES	si

        ; si is the offset to right channel structure from the
        ; beginning of dmaChns:
        imul    si,[channel],SIZE dmaChannel

        mov     dx,[si+dmaChns.singleMask]
        mov     al,[si+dmaChns.number]
	and	al,3			; mask out (disable) DMA channel
	or	al,4
	out	dx,al

        mov     dx,[si+dmaChns.clearFF]
	xor	al,al			; clear byte pointer flip-flop
	out	dx,al

	ret
ENDP



;/***************************************************************************\
;*
;* Function:     int dmaGetPos(dmaBuffer *buf, ushort *pos);
;*
;* Description:  Gets the DMA playing position
;*
;* Input:        dmaBuffer *buf          buffer that is being played
;*               ushort *pos             pointer to return value
;*
;* Returns:      MIDAS error code.
;*               DMA playing position from the beginning of the buffer,
;*               in bytes, is stored in *pos.
;*
;\***************************************************************************/

PROC    dmaGetPos       FAR     buf : dword, pos : dword
USES	si,di


        les     di,[buf]                ; point es:di to buffer structure
	mov	bx,[es:di+dmaBuffer.channel]

        ; si is the offset to right channel structure from the
        ; beginning of dmaChns:
        imul    si,bx,SIZE dmaChannel

        mov     dx,[si+dmaChns.clearFF] ; clear Flip-Flop port
	xor	al,al			; clear byte-pointer flip-flop
	out	dx,al

        mov     dx,[si+dmaChns.wordCount]       ; word count port
	cli				; disable interrupts for more
@@read: 				; accurate results.
	in	al,dx
	mov	ah,al
	in	al,dx			; bx = first word count
	xchg	al,ah
	mov	bx,ax

	in	al,dx
	mov	ah,al			; ax = second word count
	in	al,dx
	xchg	al,ah

@@countd:
	sub	bx,ax			; now compare the two results
	cmp	bx,4			; if the difference is over 4, read
	jg	@@read			; again - there might be an EMM
					; disturbing...
	cmp	bx,-4
	jl	@@read

	cmp	ax,[es:di+dmaBuffer.blength]	; check for bogus values
	jae	@@read

	sti

        cmp     [si+dmaChns.number],3   ; is the DMA channel 16-bit?
	jbe	@@no16
	shl	ax,1			; convert to bytes if a 16-bit chan
@@no16:
	neg	ax			; position = buffer size - count
	add	ax,[es:di+dmaBuffer.blength]

        les     di,[pos]                ; store position in *pos
        mov     [es:di],ax

        xor     ax,ax                   ; success

	ret
ENDP





END
