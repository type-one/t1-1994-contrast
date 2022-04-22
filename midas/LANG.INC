;*	LANG.INC
;*
;* Language-dependent macros and conditional assembly
;*
;* Copyright 1994 Petteri Kangaslampi and Jarno Paananen
;*
;* This file is part of the MIDAS Sound System, and may only be
;* used, modified and distributed under the terms of the MIDAS
;* Sound System license, LICENSE.TXT. By continuing to use,
;* modify or distribute this file you indicate that you have
;* read the license and understand and accept it fully.
;*


IFDEF __TP__
	LANG EQU PASCAL
	MODEL	TPASCAL
	MACRO IDATASEG
		CODESEG
	ENDM
        LOCALSEG EQU ss                 ; segment of local variables
ELSE
	MODEL	LARGE,C
	LANG EQU C
	MACRO IDATASEG
		DATASEG
	ENDM
        LOCALSEG EQU ss                 ; segment of local variables
ENDIF
