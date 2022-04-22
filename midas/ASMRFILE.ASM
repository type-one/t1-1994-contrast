;*      ASMRFILE.ASM
;*
;* Raw file I/O for MIDAS Sound System 16-bit C, Pascal or Assembler version
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
INCLUDE "rawfile.inc"
INCLUDE "mmem.inc"



DATASEG

fpos            DD      ?               ; temporary file position used by
                                        ; some functions


IDATASEG


;/***************************************************************************\
;*      errorCodes
;*      ----------
;* Table of error codes, with one word (16-bit) DOS error code, followed by
;* the corresponding MIDAS error code.
;\***************************************************************************/

LABEL   errorCodes      WORD
        DW      02h, errFileNotFound    ; File not found
        DW      03h, errFileNotFound    ; Path not found
        DW      04h, errTooManyFiles    ; Too many open files
        DW      05h, errAccessDenied    ; Access denied
        DW      06h, errInvalidFileHandle       ; Invalid handle
        DW      07h, errHeapCorrupted   ; Memory control blocks destroyed
        DW      08h, errOutOfMemory     ; Insufficient memory
        DW      09h, errInvalidBlock    ; Invalid memory block address
        DW      0Fh, errFileNotFound    ; Invalid drive specified
        DW      13h, errAccessDenied    ; Attempt to write on a write-prot.
        DW      14h, errFileNotFound    ; Unknown unit
        DW      1Dh, errFileWrite       ; Write fault
        DW      1Eh, errFileRead        ; Read fault
        DW      20h, errAccessDenied    ; Sharing violation
        DW      50h, errFileExists      ; File already exists
        DW      -1, -1                  ; end marker



CODESEG


;/***************************************************************************\
;*
;* Function:     int ErrorCode(void)
;*
;* Description:  Get the MIDAS error code corresponding to DOS Extended Error.
;*
;* Returns:      MIDAS error code in ax
;*
;\***************************************************************************/

PROC    ErrorCode       FAR

        push    ds si di
        mov     ax,5900h                ; DOS function 59h - get extended
        xor     bx,bx                   ; error
        int     21h
        pop     di si ds

        mov     dx,ax                   ; dx = extended error
        xor     bx,bx                   ; offset to error table

@@errloop:
        cmp     [errorCodes+bx],dx      ; Is the table error code the current
        je      @@errok                 ; one? If is, return the table value
        cmp     [errorCodes+bx],-1      ; end of table
        je      @@noerr
        add     bx,4
        jmp     @@errloop

@@errok:
        mov     ax,[errorCodes+bx+2]    ; ax = MIDAS error code
        jmp     @@done

@@noerr:
        mov     ax,errUndefined         ; undefined error

@@done:
        ret
ENDP





;/***************************************************************************\
;*
;* Function:     int rfOpen(char *fileName, int openMode, rfHandle *file);
;*
;* Description:  Opens a file for reading or writing
;*
;* Input:        char *fileName          name of file
;*               int openMode            file opening mode, see enum
;*                                       rfOpenMode
;*               rfHandle *file          pointer to file handle
;*
;* Returns:      MIDAS error code.
;*               File handle is stored in *file.
;*
;\***************************************************************************/

PROC    rfOpen          FAR     fileName : dword, openMode : word, \
                                file : dword

        ; allocate memory for file structure:
        call    memAlloc LANG, SIZE rfFile, [file]
        test    ax,ax
        jnz     @@err

        cmp     [openMode],rfOpenRead   ; open file for reading?
        jne     @@noread
        mov     al,0                    ; read only - access code
        jmp     @@open

@@noread:
        cmp     [openMode],rfOpenWrite  ; open file for writing?
        jne     @@nowrite
        mov     al,1                    ; write only - access code
        jmp     @@open

@@nowrite:
        cmp     [openMode],rfOpenReadWrite      ; open for read & write?
        jne     @@invmode
        mov     al,2                    ; read/write - access code
        jmp     @@open

@@invmode:
        mov     ax,errInvalidArguments  ; invalid function arguments
        jmp     @@err

@@open:
        mov     ah,3Dh                  ; DOS function 3Dh - open file
        push    ds
        lds     dx,[fileName]           ; ds:dx = file name
        int     21h
        pop     ds
        jc      @@doserr                ; carry set if error

        les     bx,[file]               ; point es:bx to handle
        les     bx,[es:bx]              ; point es:bx to file structure
        mov     [es:bx+rfFile.handle],ax        ; store file handle

        xor     ax,ax
        jmp     @@done

@@doserr:
        call    ErrorCode               ; get DOS error code

@@err:
        ERROR   ID_rfOpen

@@done:
        ret
ENDP





;/***************************************************************************\
;*
;* Function:     int rfClose(rfHandle file);
;*
;* Description:  Closes a file opened with rfOpen().
;*
;* Input:        rfHandle file           handle of an open file
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC    rfClose         FAR     file : dword

        les     bx,[file]               ; point es:bx to file structure
        mov     bx,[es:bx+rfFile.handle]        ; bx = file handle
        mov     ax,3E00h                ; DOS function 3Eh - close file
        int     21h
        jc      @@doserr                ; carry set if error

        ; deallocate file structure:
        call    memFree LANG, [file]
        test    ax,ax
        jnz     @@err

        xor     ax,ax
        jmp     @@done

@@doserr:
        call    ErrorCode               ; get DOS error code

@@err:
        ERROR   ID_rfClose

@@done:
        ret
ENDP




;/***************************************************************************\
;*
;* Function:     int rfGetSize(rfHandle file, long *fileSize);
;*
;* Description:  Get the size of a file
;*
;* Input:        rfHandle file           handle of an open file
;*               ulong *fileSize         pointer to file size
;*
;* Returns:      MIDAS error code.
;*               File size is stored in *fileSize.
;*
;\***************************************************************************/

PROC    rfGetSize       FAR     file : dword, fileSize : dword

        ; store current file position:
        call    rfGetPosition LANG, [file], seg fpos offset fpos
        test    ax,ax
        jnz     @@err

        ; seek to end of file:
        xor     eax,eax
        call    rfSeek LANG, [file], eax, rfSeekEnd
        test    ax,ax
        jnz     @@err


        ; read file position to *filesize:
        call    rfGetPosition LANG, [file], [fileSize]
        test    ax,ax
        jnz     @@err

        ; return original file position:
        call    rfSeek LANG, [file], [fpos], rfSeekAbsolute
        test    ax,ax
        jnz     @@err

        xor     ax,ax
        jmp     @@done

@@doserr:
        call    ErrorCode               ; get DOS error code

@@err:
        ERROR   ID_rfGetSize

@@done:
        ret
ENDP




;/***************************************************************************\
;*
;* Function:     int rfRead(rfHandle file, void *buffer, ulong numBytes);
;*
;* Description:  Reads binary data from a file
;*
;* Input:        rfHandle file           file handle
;*               void *buffer            reading buffer
;*               ulong numBytes          number of bytes to read
;*
;* Returns:      MIDAS error code.
;*               Read data is stored in *buffer, which must be large enough
;*               for it.
;*
;\***************************************************************************/

PROC    rfRead          FAR     file : dword, buffer : dword, numBytes : dword
LOCAL   readCount : dword, readBuf : dword

        mov     eax,[numBytes]          ; store number of bytes left to
        mov     [readCount],eax         ; readCount
        mov     eax,[buffer]            ; store buffer ptr in readBuf
        mov     [readBuf],eax

        les     bx,[file]               ; point es:bx to file structure
        mov     bx,[es:bx+rfFile.handle]        ; bx = file handle

        ; As the DOS read function only accepts 16 bits as number of bytes,
        ; data must be read at chunks of 49152 bytes

@@readloop:
        cmp     [readCount],0           ; any more bytes to read?
        je      @@readok

        cmp     [readCount],49152       ; more than 49152 bytes left?
        jbe     @@readrest

        ; More than 49152 bytes left to read - read 49152 bytes and advance
        ; buffer pointer

        mov     ax,3F00h                ; DOS function 3Fh - read file
        mov     cx,49152                ; read 49152 bytes
        push    ds
        lds     dx,[readBuf]            ; read to *readBuf
        int     21h
        pop     ds
        jc      @@doserr                ; carry set if error
        cmp     ax,49152                ; ax = number of bytes read. If not
        jne     @@eof                   ; 49152, end of file was reached

        sub     [readCount],49152       ; 49152 bytes read
        add     [word readBuf+2],3072   ; advance pointer 49152 bytes
                                        ; (3072 paragraphs)
        jmp     @@readloop


@@readrest:
        ; 49152 or less bytes remaining - read the rest

        mov     ax,3F00h                ; DOS function 3Fh - read file
        mov     cx,[word readCount]     ; read the rest
        push    ds
        lds     dx,[readBuf]            ; read to *readBuf
        int     21h
        pop     ds
        jc      @@doserr                ; carry set if error
        cmp     ax,[word readCount]     ; ax = number of bytes read. If not
        jne     @@eof                   ; readCount, end of file was reached

        mov     [readCount],0           ; no more to read

@@readok:
        xor     ax,ax
        jmp     @@done

@@eof:
        mov     ax,errEndOfFile         ; unexpected end of file
        jmp     @@err

@@doserr:
        call    ErrorCode               ; get DOS error code
        cmp     ax,errUndefined         ; undefined error?
        jne     @@err
@@readerr:
        mov     ax,errFileRead          ; if is, change it to file read error

@@err:
        ERROR   ID_rfRead

@@done:
        ret
ENDP




;/***************************************************************************\
;*
;* Function:     int rfWrite(rfHandle file, void *buffer, ulong numBytes);
;*
;* Description:  Writes binary data to a file
;*
;* Input:        rfHandle file           file handle
;*               void *buffer            pointer to data to be written
;*               ulong numBytes          number of bytes to write
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC    rfWrite         FAR     file : dword, buffer : dword, numBytes : dword
LOCAL   writeCount : dword, writeBuf : dword

        mov     eax,[numBytes]          ; store number of bytes left to
        mov     [writeCount],eax        ; writeCount
        mov     eax,[buffer]            ; store buffer ptr in writeBuf
        mov     [writeBuf],eax

        les     bx,[file]               ; point es:bx to file structure
        mov     bx,[es:bx+rfFile.handle]        ; bx = file handle

        ; As the DOS write function only accepts 16 bits as number of bytes,
        ; data must be written at chunks of 49152 bytes

@@writeloop:
        cmp     [writeCount],0          ; any more bytes to write?
        je      @@writeok

        cmp     [writeCount],49152      ; more than 49152 bytes left?
        jbe     @@writerest

        ; More than 49152 bytes left to write - write 49152 bytes and advance
        ; buffer pointer

        mov     ax,4000h                ; DOS function 40h - write file
        mov     cx,49152                ; write 49152 bytes
        push    ds
        lds     dx,[writeBuf]           ; write from *writeBuf
        int     21h
        pop     ds
        jc      @@doserr                ; carry set if error
        cmp     ax,49152                ; ax = number of bytes to written. If
        jne     @@diskfull              ; not 49152, disk is full

        sub     [writeCount],49152      ; 49152 bytes written
        add     [word writeBuf+2],3072  ; advance pointer 49152 bytes
                                        ; (3072 paragraphs)
        jmp     @@writeloop


@@writerest:
        ; 49152 or less bytes remaining - write the rest

        mov     ax,4000h                ; DOS function 40h - read file
        mov     cx,[word writeCount]    ; write the rest
        push    ds
        lds     dx,[writeBuf]           ; write from *readBuf
        int     21h
        pop     ds
        jc      @@doserr                ; carry set if error
        cmp     ax,49152                ; ax = number of bytes to written. If
        jne     @@diskfull              ; not writeCount, disk is full

@@writeok:
        xor     ax,ax
        jmp     @@done

@@diskfull:
        mov     ax,errDiskFull          ; unexpected end of file
        jmp     @@err

@@doserr:
        call    ErrorCode               ; get DOS error code
        cmp     ax,errUndefined         ; undefined error?
        jne     @@err
        mov     ax,errFileWrite         ; if is, change to file write error

@@err:
        ERROR   ID_rfWrite

@@done:
        ret
ENDP




;/***************************************************************************\
;*
;* Function:     int rfSeek(rfHandle file, long newPosition, int seekMode);
;*
;* Description:  Seeks to a new position in file. Subsequent reads and writes
;*               go to the new position.
;*
;* Input:        rfHandle file           file handle
;*               long newPosition        new file position
;*               int seekMode            file seek mode, see enum rfSeekMode
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

PROC    rfSeek          FAR     file : dword, newPosition : dword, \
                                seekMode : word

        ; select DOS seek mode corresponding to seekMode:

        cmp     [seekMode],rfSeekAbsolute       ; absolute seek?
        jne     @@noabs
        mov     al,0
        jmp     @@seek

@@noabs:
        cmp     [seekMode],rfSeekRelative       ; relative seek?
        jne     @@norel
        mov     al,1
        jmp     @@seek

@@norel:
        cmp     [seekMode],rfSeekEnd            ; seek from end of file?
        jne     @@invarg
        mov     al,2
        jmp     @@seek

@@invarg:
        mov     ax,errInvalidArguments  ; invalid seeking mode
        jmp     @@err

@@seek:
        les     bx,[file]
        mov     bx,[es:bx+rfFile.handle]        ; bx = file handle
        mov     ah,42h                  ; DOS function 42h - move file pointer
        mov     cx,[word newPosition+2]
        mov     dx,[word newPosition]
        int     21h
        jc      @@doserr

        xor     ax,ax
        jmp     @@done

@@doserr:
        call    ErrorCode               ; get DOS error code

@@err:
        ERROR   ID_rfSeek

@@done:
        ret
ENDP




;/***************************************************************************\
;*
;* Function:     int rfGetPosition(rfHandle file, long *position);
;*
;* Description:  Reads the current position in a file
;*
;* Input:        rfHandle file           file handle
;*               long *position          pointer to file position
;*
;* Returns:      MIDAS error code.
;*               Current file position is stored in *position.
;*
;\***************************************************************************/

PROC    rfGetPosition   FAR     file : dword, position : dword

        les     bx,[file]
        mov     bx,[es:bx+rfFile.handle]        ; bx = file handle

        mov     ah,42h                  ; DOS function 42h - move file pointer
        mov     al,1                    ; move relative to current position
        xor     cx,cx                   ; new position = 0 (current)
        xor     dx,dx
        int     21h
        jc      @@doserr                ; carry set if error

        ; dx:ax contains current file position - store it in *position:
        les     bx,[position]
        mov     [es:bx],ax
        mov     [es:bx+2],dx

        xor     ax,ax
        jmp     @@done

@@doserr:
        call    ErrorCode               ; get DOS error code

@@err:
        ERROR   ID_rfGetPosition

@@done:
        ret
ENDP




END
