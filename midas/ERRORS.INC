;*	ERRORS.INC
;*
;* MIDAS Sound System error codes and error message strings
;*
;* Copyright 1994 Petteri Kangaslampi and Jarno Paananen
;*
;* This file is part of the MIDAS Sound System, and may only be
;* used, modified and distributed under the terms of the MIDAS
;* Sound System license, LICENSE.TXT. By continuing to use,
;* modify or distribute this file you indicate that you have
;* read the license and understand and accept it fully.
;*


;/***************************************************************************\
;*	 enum ErrorCodes
;*	 ---------------
;* Description:  MIDAS Sound System error codes
;\***************************************************************************/

ENUM	ErrorCodes \
	OK = 0, \			; no error
	errUndefined, \ 		; undefined error
	errOutOfMemory, \		; out of (conventional) memory
	errHeapCorrupted, \		; (conventional memory) heap corrupted
	errInvalidBlock, \		; invalid memory block
	errOutOfEMS, \			; out of EMS memory
	errEMSHeapCorrupted, \		; EMS heap corrupted
	errInvalidEMSBlock, \		; invalid EMS memory block
	errEMMFailure, \		; Expanded Memory Manager failure
	errOutOfCardMemory, \		; out of soundcard memory
	errCardHeapCorrupted, \ 	; soundcard heap corrupted
	errInvalidCardBlock, \		; invalid soundcard memory block
	errNoInstHandles, \		; out of instrument handles
	errFileOpen, \			; unable to open file
	errFileRead, \			; unable to read file
	errInvalidModule, \		; invalid module file
	errInvalidInst, \		; invalid instrument in module
	errInvalidPatt, \		; invalid pattern data in module
	errInvalidChanNumber, \ 	; invalid channel number
	errInvalidInstHandle, \ 	; invalid instrument handle
	errNoChannels, \		; Sound Device channels not open
        errSDFailure, \                 ; Sound Device hardware failure
        errInvalidArguments, \          ; invalid function arguments
        errFileNotFound, \              ; file does not exist
        errInvalidFileHandle, \         ; invalid file handle
        errAccessDenied, \              ; access denied
        errFileExists, \                ; file exists
        errTooManyFiles, \              ; too many open files
        errDiskFull, \                  ; disk full
        errEndOfFile, \                 ; unexpected end of file
        errFileWrite                    ; unable to write file



GLOBAL	LANG errorMsg : dword		; error message strings


;/***************************************************************************\
;*	 enum FunctionIDs
;*	 ----------------
;* Description:  ID numbers for first functions in all modules
;\***************************************************************************/

ENUM	FunctionIDs \
	ID_error = 0, \ 		; error handling
	ID_dma = 100, \ 		; DMA handling routines
	ID_dsm = 200, \ 		; Digital Sound Mixer
	ID_ems = 300, \ 		; EMS heap manager
	ID_mem = 400, \ 		; Conventional memory management
	ID_mod = 500, \ 		; Protracker Module Player
	ID_s3m = 600, \ 		; Scream Tracker 3 Module Player
	ID_tmr = 700, \ 		; TempoTimer
	ID_vu = 800, \			; Real VU meters
        ID_rf = 900, \                  ; Raw file I/O
        ID_file = 1000, \               ; High-level file I/O
        ID_gus = 2000, \                ; GUS Sound Device
	ID_pas = 2100, \		; PAS Sound Device
	ID_wss = 2200, \		; WSS Sound Device
	ID_sb = 2300, \ 		; SB Sound Device
	ID_nsnd = 2900			; No Sound Sound Device



IFDEF DEBUG

;/***************************************************************************\
;*	 struct errRecord
;*	 ----------------
;* Description:  Error record for error list
;\***************************************************************************/

STRUC	errRecord
	errorCode	DW	?	; error code number
	functID 	DW	?	; ID for function that caused the
					; error
ENDS

GLOBAL	LANG errorList : errRecord	; error list
GLOBAL	LANG numErrors : word		; number of errors in list



;/***************************************************************************\
;*
;* Function:	 void errAdd(int errorCode, unsigned functID);
;*
;* Description:  Add an error to error list
;*
;* Input:	 int errorCode		 error code
;*		 unsigned functID	 ID for function that caused the error
;*
;\***************************************************************************/

GLOBAL	LANG errAdd : far




;/***************************************************************************\
;*
;* Function:	 void errPrintList(void);
;*
;* Description:  Prints the error list to stderr
;*
;\***************************************************************************/

GLOBAL	LANG errPrintList : far


ENDIF



;/***************************************************************************\
;*
;* Macro:	ERROR	functID
;*
;* Description: Adds an error to the MIDAS error list if DEBUG is defined.
;*		Does nothing otherwise.
;*
;* Input:	ax		error code
;*		functID 	function ID
;*
;* Destroys:	all except ds, si, di
;*
;\***************************************************************************/

MACRO	ERROR	functID
IFDEF	DEBUG
	push	ax
	call	errAdd LANG, ax, functID
	pop	ax
ENDIF
ENDM
