;*	EMS.ASM
;*
;* EMS heap manager, v1.00
;*
;* Copyright 1994 Petteri Kangaslampi and Jarno Paananen
;*
;* This file is part of the MIDAS Sound System, and may only be
;* used, modified and distributed under the terms of the MIDAS
;* Sound System license, LICENSE.TXT. By continuing to use,
;* modify or distribute this file you indicate that you have
;* read the license and understand and accept it fully.
;*


P386
IDEAL
JUMPS


INCLUDE "lang.inc"
INCLUDE "errors.inc"
INCLUDE "ems.inc"
INCLUDE "mmem.inc"



DATASEG

emsHandles	DD	?		; pointer to first EMS handle
emsSaveArray	DD	?		; EMS Page Map Save Array pointer
emsPageFrame	DW	?		; EMS Page Frame segment
emsIsSafe	DW	?		; emsSafe flag
emsMapped	DW	4 dup (?)	; from which handle are pages
					; mapped
emsMemPtr       DD      ?               ; temporary pointer used by EMS
                                        ; Heap Manager functions

IDATASEG
EMMname 	DB	"EMMXXXX0"      ; EMM device name
EMMNAMELEN = 8				; length of EMM device name





CODESEG


;/***************************************************************************\
;*
;* Function:     int emsInit(int *emmOK);
;*
;* Description:  Initializes EMS heap. Must be called before other EMS heap
;*               manager functions.
;*
;* Input:        int *emmOK              pointer to variable containing EMM
;*                                       status
;*
;* Returns:      MIDAS error code.
;*               *emmOK contains 1 if Expanded Memory Manager was found (EMS
;*               initialized succesfully) or 0 if not. Note that the lack
;*               of Expanded Memory Manager is _not_ an error.
;*
;\***************************************************************************/

PROC    emsInit         FAR     emmOK : dword
USES	si,di

	cld

	mov	ax,3567h		; get EMM interrupt vector
	int	21h

	mov	bx,0Ah
	mov	cx,EMMNAMELEN		; offset 0Ah of the interrupt vector
        xor     si,si                   ; si = offset to EMM driver name str

        ; offset 0Ah in the EMM interrupt vector segment should contain the
        ; driver name, or else it does not point to a valid EMM

@@cmp:
        mov     al,[EMMname+si]         ; get character from string
        inc     si

        cmp     [es:bx],al              ; compare it to EMM driver string
        jne     @@noemm                 ; if different, there is no EMM
	inc	bx
	loop	@@cmp

	mov	ah,40h			; EMS Get Status function
	int	67h
        test    ah,ah                   ; non-zero status means error
        jnz     @@emmerr

	mov	ah,41h			; EMS Get Page Frame function
	int	67h
        test    ah,ah                   ; non-zero status means error
        jnz     @@emmerr
	mov	[emsPageFrame],bx	; save Page Frame segment address

	mov	ax,4E03h		; EMS Get Size of Page Map Save Array
	int	67h
        test    ah,ah                   ; non-zero status means error
        jnz     @@emmerr

        ; allocate memory for EMS Save Array:
        call    memAlloc LANG, ax, seg emsSaveArray offset emsSaveArray
        test    ax,ax
        jnz     @@err

	mov	[emsHandles],0		; no EMS handles allocated
	mov	[emsIsSafe],0

        les     bx,[emmOK]              ; store 1 in *emmOK to mark that EMS
        mov     [word es:bx],1          ; can be used

        xor     ax,ax                   ; success
	jmp	@@done

@@noemm:
        les     bx,[emmOK]              ; store 0 in *emmOK to mark that EMS
        mov     [word es:bx],0          ; can not be used

        xor     ax,ax                   ; success
        jmp     @@done

@@emmerr:
        ; Expanded Memory Manager internal error:
        mov     ax,errEMMFailure

@@err:
        ERROR   ID_emsInit

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:     int emsClose(void);
;*
;* Description:  Uninitializes EMS heap freeing all allocated blocks. Must be
;*               called before program exits if emsInit() has been called.
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	emsClose	FAR
USES    si

@@free:
	cmp	[emsHandles],0		; any EMS handles allocated?
	je	@@empty

	les	bx,[emsHandles]
	lgs	si,[es:bx+emsHandle.block]	; point gs:si to first block

@@fblk: cmp	[gs:si+emsBlock.used],1 	; is block used?
	je	@@dealloc			; if is, deallocate it
	cmp	[gs:si+emsBlock.next],0 	; is there a next block?
	je	@@err				; if not, heap is corrupted
	lgs	si,[gs:si+emsBlock.next]	; point gs:si to next block
	jmp	@@fblk

@@dealloc:
        push    gs
	call	emsFree LANG, gs si	; free this block
        pop     gs
        test    ax,ax
        jnz     @@err

	jmp	@@free			; continue deallocating blocks


@@empty:
        ; deallocate Page Map Save Array:
	call	memFree LANG, [emsSaveArray]
        test    ax,ax
        jnz     @@err

        xor     ax,ax                   ; success
        jmp     @@done

@@err:
        ERROR   ID_emsClose

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:     int emsAlloc(ushort bytes, emsBlock **ems);
;*
;* Description:  Allocates an EMS memory block
;*
;* Input:        ushort bytes            number of bytes to be allocated
;*               emsBlock **ems          Pointer to EMS Block pointer
;*
;* Returns:      MIDAS error code.
;*               EMS block pointer stored in *ems, NULL if failure
;*
;\***************************************************************************/

PROC    emsAlloc        FAR     bytes : word, ems : dword
USES	si, di
LOCAL   handle : dword

	cmp	[emsHandles],0		; are there any EMS handles allocated?
	je	@@newhandle		; if not, allocate

	mov	cx,[bytes]

	lgs	si,[emsHandles] 	; point gs:si to first handle
@@hlp:
	les	bx,[gs:si+emsHandle.block]	; point es:bx to first block
						; in handle
@@blp:
	cmp	[es:bx+emsBlock.used],0 	; is current block in use?
	je	@@unused
@@nextblk:
	cmp	[es:bx+emsBlock.next],0 	; is there a next block?
	je	@@lastblk
	les	bx,[es:bx+emsBlock.next]	; point es:bx to next block
	jmp	@@blp				; and continue searching

@@unused:
	cmp	[es:bx+emsBlock.bytes],cx	; is this unused block long
	jb	@@nextblk			; long enough?
	je	@@blksame			; if same length, don't alloc
						; a new block
        ; allocate memory for new block:
	push	cx bx es
        call    memAlloc LANG, SIZE emsBlock, seg emsMemPtr offset emsMemPtr
	pop	es bx cx
        test    ax,ax
        jnz     @@err

	push	ds

        lds     di,[emsMemPtr]                  ; point ds:di to new block

	mov	eax,[es:bx+emsBlock.next]	; add this new block after
	mov	[ds:di+emsBlock.next],eax	; the current empty block
	lgs	si,[es:bx+emsBlock.next]
	mov	[word gs:si+emsBlock.prev],di
	mov	[word gs:si+2+emsBlock.prev],ds
	mov	[word es:bx+emsBlock.next],di
	mov	[word es:bx+2+emsBlock.next],ds
	mov	[word ds:di+emsBlock.prev],bx
	mov	[word ds:di+2+emsBlock.prev],es

	mov	eax,[es:bx+emsBlock.handle]	; copy EMS handle pointer
	mov	[ds:di+emsBlock.handle],eax
	mov	[ds:di+emsBlock.used],0 	; new block is not used

	mov	ax,[es:bx+emsBlock.addr]	; address of this block is
	add	ax,cx				; address of the previous
	mov	[ds:di+emsBlock.addr],ax	; + bytes

	mov	ax,[es:bx+emsBlock.bytes]
	sub	ax,cx				; decrease number of bytes
	mov	[ds:di+emsBlock.bytes],ax

	mov	[es:bx+emsBlock.bytes],cx	; size of current block is
	mov	[es:bx+emsBlock.used],1 	; [bytes] and it is in use

	pop	ds
	jmp	@@ok				; block allocated

@@blksame:
	mov	[es:bx+emsBlock.used],1 	; block sizes are the same
	jmp	@@ok				; - only used status needs
						; to be changed.



@@lastblk:
	mov	ax,[es:bx+emsBlock.addr]	; address in handle
	add	ax,[es:bx+emsBlock.bytes]	; plus number of bytes
	neg	ax				; negated == bytes free
	cmp	ax,cx				; enough space after this blk?
	jae	@@addblk			; if is, add new block here

	cmp	[gs:si+emsHandle.next],0	; is there a next handle?
	je	@@newhandle			; if not, allocate new

	lgs	si,[gs:si+emsHandle.next]	; continue searching for space
	jmp	@@hlp				; from next handle


@@addblk:
        ; allocate memory for new block:
	push	cx bx es
        call    memAlloc LANG, SIZE emsBlock, seg emsMemPtr offset emsMemPtr
	pop	es bx cx
        test    ax,ax
        jnz     @@err

        push    ds

        lds     di,[emsMemPtr]                  ; point ds:di to new block

	mov	ax,[es:bx+emsBlock.addr]	; address of new block
	add	ax,[es:bx+emsBlock.bytes]
	mov	[ds:di+emsBlock.addr],ax
	mov	[ds:di+emsBlock.bytes],cx	; number of bytes in new block

	mov	[ds:di+emsBlock.next],0 	; this is the last block
	mov	[word ds:di+emsBlock.prev],bx	; previous block is the
	mov	[word ds:di+2+emsBlock.prev],es ; current one
	mov	[word es:bx+emsBlock.next],di	; next block to current one is
	mov	[word es:bx+2+emsBlock.next],ds ; the new one

	mov	[ds:di+emsBlock.used],1 	; new block is in use
	mov	eax,[es:bx+emsBlock.handle]	; new block has the same
	mov	[ds:di+emsBlock.handle],eax	; handle as the current one

	mov	bx,di
	mov	ax,ds				; return block pointer in
	mov	es,ax				; es:bx

	pop	ds
	jmp	@@ok


@@newhandle:
        ; allocate EMS pages:
        call    emsAllocPages LANG, seg emsMemPtr offset emsMemPtr
        test    ax,ax
        jnz     @@err

        mov     eax,[emsMemPtr]
        mov     [handle],eax

        ; allocate memory for EMS block:
        call    memAlloc LANG, SIZE emsBlock, seg emsMemPtr offset emsMemPtr
        test    ax,ax
        jnz     @@err

        les     bx,[emsMemPtr]          ; point es:bx to new block

	mov	[es:bx+emsBlock.addr],0 ; in the beginning of handle area
	mov	ax,[bytes]
	mov	[es:bx+emsBlock.bytes],ax
	mov	[es:bx+emsBlock.next],0 	; no next block
	mov	[es:bx+emsBlock.prev],0 	; no previous block
	mov	[es:bx+emsBlock.used],1 	; block is in use
	mov	eax,[handle]
	mov	[es:bx+emsBlock.handle],eax

	lgs	si,[handle]
	mov	[word gs:si+emsHandle.block],bx 	; add block to handle
	mov	[word gs:si+2+emsHandle.block],es


@@ok:   ; es:bx points to allocated EMS block

        lgs     si,[ems]
        mov     [word gs:si],bx         ; store EMS block pointer to *ems
        mov     [word gs:si+2],es

        xor     ax,ax                   ; success
        jmp     @@done

@@err:
        les     bx,[ems]
        mov     [dword es:bx],0         ; store NULL to *ems

        ERROR   ID_emsAlloc

@@done:
	ret
ENDP





;/***************************************************************************\
;*
;* Function:     int emsFree(emsBlock *ems);
;*
;* Description:  Deallocates an EMS block allocated with emsAlloc
;*
;* Input:        emsBlock *ems           pointer to block to be deallocated
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	emsFree 	FAR	ems : dword
LOCAL	handle : dword
USES	si,di

	les	bx,[ems]
	mov	eax,[es:bx+emsBlock.handle]	; save handle pointer
	mov	[handle],eax
	cmp	[es:bx+emsBlock.next],0 	; the last block of handle?
	je	@@last

	mov	[es:bx+emsBlock.used],0 	; current block is not in use

	; now combine all unused blocks that are after another

@@combfree:
	lgs	si,[handle]			; point gs:si to handle
	les	bx,[gs:si+emsHandle.block]	; point es:bx to first block

@@cunused:
	cmp	[es:bx+emsBlock.used],0 	; is block unused?
	jne	@@nextb

	lgs	si,[es:bx+emsBlock.next]	; point gs:si to next block
	cmp	[gs:si+emsBlock.used],0 	; is next block unused?
	jne	@@nextb 			; if not, move on

@@comb:
	; block pointed by es:bx is free and so is the next one, gs:si

	mov	ax,[gs:si+emsBlock.bytes]	; increase the length of
	add	[es:bx+emsBlock.bytes],ax	; current block

	mov	eax,[gs:si+emsBlock.next]
	mov	[es:bx+emsBlock.next],eax
	or	eax,eax
	jz	@@nonext
	push	ds				; remove block pointed by
	lds	di,[gs:si+emsBlock.next]	; gs:si from list
	mov	[word ds:di+emsBlock.prev],bx
	mov	[word ds:di+2+emsBlock.prev],es
	pop	ds

@@nonext:
        push    gs es bx
	call	memFree LANG, gs si		; deallocate block
        pop     bx es gs
        test    ax,ax
        jnz     @@err

	cmp	[es:bx+emsBlock.next],0 	; is there a next block?
	je	@@chkfree
	lgs	si,[es:bx+emsBlock.next]	; point gs:si to next block
	cmp	[gs:si+emsBlock.used],0 	; is next block used?
	je	@@comb				; if not, combine to this one

@@nextb:
	cmp	[es:bx+emsBlock.next],0 	; is there a next block?
	je	@@chkfree			; if not, we are finished
	les	bx,[es:bx+emsBlock.next]	; point es:bx to next block
	jmp	@@cunused			; and continue


@@chkfree:
	; all free blocks combined. Now check if there is only one free
	; block in the handle
	lgs	si,[handle]			; point gs:si to handle
	les	bx,[gs:si+emsHandle.block]	; point es:bx to first block
	cmp	[es:bx+emsBlock.next],0 	; is this the last block?
	jne	@@ok
	cmp	[es:bx+emsBlock.used],0 	; is this block unused?
	jne	@@ok

	; only one unused block in the handle - deallocate it.

	push	es bx
	call	emsFreePages LANG, gs si	; deallocate handle
	pop	bx es
        test    ax,ax
        jnz     @@err

	call	memFree LANG, es bx		; deallocate block structure
        test    ax,ax
        jnz     @@err

	jmp	@@ok


@@last:
	cmp	[es:bx+emsBlock.prev],0 	; the only block of handle?
	je	@@only

	les	bx,[es:bx+emsBlock.prev]	; point es:bx to prev block
	mov	[es:bx+emsBlock.next],0 	; no next block
	call	memFree LANG, [ems]		; deallocate block
        test    ax,ax
        jnz     @@err

	jmp	@@chkfree			; check if handle should be
						; deallocated


@@only:
        call    emsFreePages LANG, [es:bx+emsBlock.handle]      ; free handle
        test    ax,ax
        jnz     @@err

	call	memFree LANG, [ems]		; free current block
        test    ax,ax
        jnz     @@err

@@ok:
        xor     ax,ax                   ; success
	jmp	@@done

@@err:
        ERROR   ID_emsFree

@@done:
	ret
ENDP





;/***************************************************************************\
;*
;* Function:     int emsMap(emsBlock *ems, void **memPtr);
;*
;* Description:  Maps an EMS block to conventional memory.
;*
;* Input:        emsBlock *ems           pointer to block to be mapped
;*               void **memPtr           pointer to conventional memory ptr
;*
;* Returns:      MIDAS error code.
;*               Pointer to the conventional memory area where the block
;*               was mapped is stored in **memPtr, NULL if failure.
;*
;\***************************************************************************/

PROC    emsMap          FAR     ems : dword, memPtr : dword
USES	si,di

	les	di,[ems]			; point es:di to EMS block
	lgs	si,[es:di+emsBlock.handle]	; point gs:si to EMS handle
	mov	dx,[gs:si+emsHandle.handle]	; handle number

	mov	cx,[es:di+emsBlock.addr]	; cx = first page to map
	shr	cx,14

	mov	si,[es:di+emsBlock.addr]
	add	si,[es:di+emsBlock.bytes]	; si = last page to map
	shr	si,14

@@mlp:	cmp	[emsIsSafe],1			; is safety-flag on?
	jne	@@map				; if not, always map the page

	mov	bx,cx				; if is, check if this page
	shl	bx,1				; is already mapped
	cmp	[emsMapped+bx],dx
	je	@@mapped

	mov	[emsMapped+bx],dx		; if not, map it normally and
						; mark mapped
@@map:
	mov	al,cl				; al = physical page number
	mov	bx,cx				; bx = logical page number
	mov	ah,44h				; EMS Map Handle Pages funct
	int	67h
	or	ah,ah
        jnz     @@emmerr

@@mapped:
	inc	cx				; map next page
	cmp	cx,si				; should next page still be
	jbe	@@mlp				; mapped?

        mov     ax,[es:di+emsBlock.addr]
        les     bx,[memPtr]             ; store pointer to the conventional
        mov     [es:bx],ax              ; memory area to *memPtr
        mov     ax,[emsPageFrame]
        mov     [es:bx+2],ax

        xor     ax,ax                   ; success
        jmp     @@done

@@emmerr:
        ; EMM mapping function failed
        mov     ax,errEMMFailure

@@err:
        ERROR   ID_emsMap

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:     int emsSave(void);
;*
;* Description:  Saves the EMS status. To be used by TempoTimer. Can only be
;*               called once.
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	emsSave 	FAR
USES	di

	mov	ax,4E00h		; EMS Get Page Map subfunction
	les	di,[emsSaveArray]	; pointer to Page Map Save Array
	int	67h
	or	ah,ah			; nonzero status means error
        jnz     @@emmerr

        xor     ax,ax                   ; success
        jmp     @@done

@@emmerr:
        ; EMM Save function failed
        mov     ax,errEMMFailure

@@err:
        ERROR   ID_emsSave

@@done:
	ret
ENDP





;/***************************************************************************\
;*
;* Function:     int emsRestore(void);
;*
;* Description:  Restores EMS status saved with emsSave(). To be used by
;*               TempoTimer. Can only be called once.
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	emsRestore	FAR
USES	ds, si

	mov	ax,4E01h		; EMS Set Page Map subfunction
	lds	si,[emsSaveArray]	; point ds:si to Page Map Save Array
	int	67h
	or	ah,ah			; nonzero status means error
        jnz     @@emmerr

        xor     ax,ax                   ; success
	jmp	@@done

@@emmerr:
        ; EMM Restore function failed
        mov     ax,errEMMFailure

@@err:
        ERROR   ID_emsRestore

@@done:
	ret
ENDP





;/***************************************************************************\
;*
;* Function:     int emsAllocPages(emsHandle **emsh);
;*
;* Description:  Allocate 4 pages of EMS memory to a handle. Used internally
;*               by EMS heap manager.
;*
;* Returns:      MIDAS error code.
;*               Pointer to a emsHandle structure for the pages stored in
;*               *emsh, NULL if failure.
;*
;\***************************************************************************/

PROC    emsAllocPages   FAR     emsh : dword
USES	si
LOCAL	handle : dword

        ; allocate memory for handle structure:
        call    memAlloc LANG, size emsHandle, seg emsMemPtr offset emsMemPtr
        test    ax,ax
        jnz     @@err

        les     bx,[emsMemPtr]          ; point es:bx to handle structure
        mov     [word handle],bx        ; store handle pointer in handle
        mov     [word handle+2],es


	mov	[es:bx+emsHandle.handle],0
	mov	[es:bx+emsHandle.block],0
	mov	[es:bx+emsHandle.next],0

	push	bx
	mov	ah,43h			; EMS Allocate Pages function
	mov	bx,4			; allocate 4 pages (64k)
	int	67h
        pop     bx
        or      ah,ah                   ; successful if status is zero
        jz      @@allocok

        ; check if the cause of the error was lack of EMS. If so, return
        ; errOutOfEMS, otherwise errEMMFailure
        cmp     ah,85h                  ; out of EMS handles?
        je      @@outofems
        cmp     ah,87h                  ; not enough EMS pages?
        je      @@outofems
        cmp     ah,88h                  ; not enough unallocated pages?
        je      @@outofems
        jmp     @@emmerr

@@outofems:
        mov     ax,errOutOfEMS          ; out of EMS memory
        jmp     @@err


@@allocok:
	mov	[es:bx+emsHandle.handle],dx	; store EMS handle number

	cmp	[emsHandles],0		; first EMS handle?
	jne	@@notfirst

	mov	[word emsHandles],bx	; point emsHandles to this page as
	mov	[word emsHandles+2],es	; it is the first
	mov	[es:bx+emsHandle.prev],0	; no previous handle (first)
	jmp	@@prevset

@@notfirst:
	push	ds

	lds	si,[emsHandles] 	; start searching for last handle
@@flast:
	cmp	[ds:si+emsHandle.next],0	; is this the last handle?
	je	@@last
	lds	si,[ds:si+emsHandle.next]	; next handle
	jmp	@@flast

@@last:
	mov	[word ds:si+emsHandle.next],bx		; ds:si now points to
	mov	[word ds:si+2+emsHandle.next],es	; last handle which
	mov	[word es:bx+emsHandle.prev],si		; is the previous for
	mov	[word es:bx+2+emsHandle.prev],ds	; this one
	pop	ds

@@prevset:
        les     bx,[emsh]
        mov     eax,[handle]            ; store handle pointer in *emsh
        mov     [es:bx],eax

        xor     ax,ax                   ; success
        jmp     @@done


@@emmerr:
        mov     ax,errEMMFailure        ; Expanded Memory Manager failure

@@err:
        ERROR   ID_emsAllocPages

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:     int emsFreePages(emsHandle *handle);
;*
;* Description:  Deallocates an EMS handle allocated by emsAllocPages(). Used
;*               internally by EMS heap manager.
;*
;* Input:        emsHandle *handle       pointer to handle to be deallocated.
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC	emsFreePages	FAR	handle : dword
USES	si

	les	bx,[handle]		; point es:bx to handle structure
	cmp	[es:bx+emsHandle.prev],0	; first handle?
	je	@@first

	push	ds
	mov	eax,[es:bx+emsHandle.next]	; eax = pointer to next handle
	lds	si,[es:bx+emsHandle.prev]	; point ds:si to prev handle
	mov	[ds:si+emsHandle.next],eax	; prev->next = this->next
	pop	ds

	or	eax,eax 		; is this the last handle?
	jz	@@dealloc

	push	ds
	mov	eax,[es:bx+emsHandle.prev]	; eax = pointer to prev handle
	lds	si,[es:bx+emsHandle.next]	; point ds:si to next handle
	mov	[ds:si+emsHandle.prev],eax	; next->prev = this->prev
	pop	ds
	jmp	@@dealloc

@@first:
	mov	eax,[es:bx+emsHandle.next]	; set emsHandles to next
	mov	[emsHandles],eax		; handle (might be 0)
	or	eax,eax 			; is there a next handle?
	jz	@@fnn
	lgs	si,[es:bx+emsHandle.next]	; if is, its previous handle
	mov	[gs:si+emsHandle.prev],0	; is now zero (it's the first)
@@fnn:

@@dealloc:
	mov	ah,45h			; EMS Deallocate Pages function
	mov	dx,[es:bx+emsHandle.handle]	; EMS handle number
	int	67h
        test    ah,ah                   ; failure if nonzero status
        jnz     @@emmerr

	call	memFree LANG, es bx	; deallocate handle structure memory
        test    ax,ax
        jnz     @@err

        xor     ax,ax                   ; success
        jmp     @@done

@@emmerr:
        mov     ax,errEMMFailure        ; Expanded Memory Manager failure

@@err:
        ERROR   ID_emsFreePages

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:     int emsSafe(void);
;*
;* Description:  Sets the EMS safety flag on so that the EMS heap manager
;*               can optimize page mappings. Until emsStopSafe() is restored,
;*               no other routine than emsMap() must touch the EMS page
;*               mappings
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC    emsSafe         FAR

	mov	[emsIsSafe],1		; it is now safe to assume that EMS
	xor	bx,bx			; mappings remain untouched by other
	mov	cx,4			; routines.
	mov	ax,-1

@@lp:	mov	[emsMapped+bx],ax	; clear mapping status table to
	add	bx,2			; indicate that no pages are mapped
	loop	@@lp

        xor     ax,ax                   ; always successful

	ret
ENDP




;/***************************************************************************\
;*
;* Function:     int emsStopSafe(void);
;*
;* Description:  Sets the EMS safety flag off.
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC    emsStopSafe     FAR

	mov	[emsIsSafe],0		; it is no longer safe to assume that
					; EMS mappings remain untouched
        xor     ax,ax                   ; always successful

	ret
ENDP





END
