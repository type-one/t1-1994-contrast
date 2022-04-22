;*	VGATEXT.ASM
;*
;* VGA text output routines for MIDAS Module Player
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

INCLUDE "lang.inc"
INCLUDE "vgatext.inc"



IDATASEG


hextable	DB	"0123456789ABCDEF"


CODESEG



;/***************************************************************************\
;*
;* Function:	 void vgaWriteText(int x, int y, char *txt);
;*
;* Description:  Writes text on the screen
;*
;* Input:	 int x			 X coordinate of string (up-left
;*					 corner is (1,1))
;*		 int y			 Y coordinate
;*		 char *txt		 pointer to null-terminated text
;*					 string, which may contain also the
;*					 following special characters:
;*					     \xFF - next char is attribute
;*					     \x7F - next char is RLE count for
;*						 the character following it
;*
;\***************************************************************************/

PROC	vgaWriteText	FAR	x : word, y : word, txt : dword
USES	ds,si,di

	mov	ax,160
	mov	bx,[y]
	dec	bx
	mul	bx
	mov	di,[x]			; point di to destination in display
	dec	di			; memory (160*y + 2*x)
	shl	di,1
	add	di,ax

	mov	ax,0B800h		; point es to display memory - es:di
	mov	es,ax			; points to destination

	lds	si,[txt]		; point ds:si to string

	mov	ah,07h			; default attribute is 07h - white
					; on black

@@lp:	mov	al,[ds:si]		; get byte from string
	inc	si
	or	al,al			; zero? (string termination)
	jz	@@done

	cmp	al,0FFh 		; is next byte attribute?
	je	@@attr

	cmp	al,07Fh 		; is next byte RLE count?
	je	@@rle

	mov	[es:di],ax		; normal character - write to screen
	add	di,2
	jmp	@@lp			; and get next character

@@attr:
	mov	ah,[ds:si]		; get next attribute
	inc	si
	jmp	@@lp			; get next character

@@rle:
	movzx	cx,[ds:si]		; get RLE count
	mov	al,[ds:si+1]		; get RLE byte
	add	si,2
	rep	stosw			; draw characters
	jmp	@@lp			; get next character

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	 void vgaWriteStr(int x, int y, char *str, char attr);
;*
;* Description:  Writes a string on the screen
;*
;* Input:	 int x			 X coordinate of the string
;*		 int y			 Y coordinate
;*		 char *str		 pointer to a ASCIIZ string
;*		 char attr		 attribute for the string
;*		 int txtlen		 number of characters to be printed on
;*					 screen - padded with spaces
;*
;\***************************************************************************/

PROC	vgaWriteStr	FAR	x : word, y : word, str : dword, attr : byte,\
				maxlen : word
USES	ds,si,di

	mov	ax,160
	mov	bx,[y]
	dec	bx
	mul	bx
	mov	di,[x]			; point di to destination in display
	dec	di			; memory (160*y + 2*x)
	shl	di,1
	add	di,ax

	mov	ax,0B800h		; point es to display memory - es:di
	mov	es,ax			; points to destination

	lds	si,[txt]		; point ds:si to string

	mov	ah,[attr]		; attribute
	mov	cx,[maxlen]		; maximum number of characters

@@lp:	lodsb				; get character
	or	al,al			; zero? (end of string)
	jz	@@send			; if is, stop
	stosw				; write character and attribute
	loop	@@lp			; and get next character
	jmp	@@done

@@send: mov	al,' '                  ; string end - pad with spaces
	rep	stosw

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:	 void vgaWriteByte(int x, int y, uchar byte, char attr);
;*
;* Description:  Writes a hex byte on the screen
;*
;* Input:	 int x			 X coordinate
;*		 int y			 Y coordinate
;*		 uchar byte		 byte to be written
;*		 char attr		 attribute for the byte
;*
;\***************************************************************************/

PROC	vgaWriteByte	FAR	x : word, y : word, b : byte, attr : byte
USES	di

	mov	ax,160
	mov	bx,[y]
	dec	bx
	mul	bx
	mov	di,[x]			; point di to destination in display
	dec	di			; memory (160*y + 2*x)
	shl	di,1
	add	di,ax

	mov	ax,0B800h		; point es to display memory - es:di
	mov	es,ax			; points to destination

	mov	ah,[attr]		; attribute
	mov	bl,[b]
	shr	bx,4			; upper nybble
	and	bx,0Fh
	mov	al,[hextable+bx]	; upper nybble character
	mov	[es:di],ax		; write upper nybble

	mov	bl,[b]
	and	bx,0Fh			; lower nybble
	mov	al,[hextable+bx]	; lower nybble character
	mov	[es:di+2],ax		; write lower nybble

	ret
ENDP



;/***************************************************************************\
;*
;* Function:	 void vgaDrawMeter(int x, int y, int val, int max, char mchr,
;*		 char hlattr, char nattr);
;*
;* Description:  Draws a meter on the screen
;*
;* Input:	 int x			 X coordinate
;*		 int y			 Y coordinate
;*		 int val		 meter value
;*		 int max		 meter max. value (length)
;*		 char mchr		 character used for meter
;*		 char hlattr		 attribute for highlighted characters
;*		 char nattr		 attribute for normal characters
;*
;\***************************************************************************/

PROC	vgaDrawMeter	FAR	x : word, y : word, val : word, max : word, \
				mchr : byte, hlattr : byte, nattr : byte
USES	di

	cld

	mov	ax,160
	mov	bx,[y]
	dec	bx
	mul	bx
	mov	di,[x]			; point di to destination in display
	dec	di			; memory (160*y + 2*x)
	shl	di,1
	add	di,ax

	mov	ax,0B800h		; point es to display memory - es:di
	mov	es,ax			; points to destination

	mov	bx,[max]		; total number of charaters to draw
	mov	cx,[val]		; number of highlighted characters
	cmp	cx,bx			; too many highlighted characters?
	jbe	@@ok
	mov	cx,bx

@@ok:	sub	bx,cx			; number of non-highlighted characters
	mov	al,[mchr]		; meter character
	mov	ah,[hlattr]		; draw highlighted characters
	rep	stosw

	mov	cx,bx			; number of non-highlighted characters
	mov	ah,[nattr]
	rep	stosw			; draw non-highlighted characters

	ret
ENDP




END
