;*	MIDAS.INC
;*
;* MIDAS Sound System main assembler include file.
;*
;* Copyright 1994 Petteri Kangaslampi and Jarno Paananen
;*
;* This file is part of the MIDAS Sound System, and may only be
;* used, modified and distributed under the terms of the MIDAS
;* Sound System license, LICENSE.TXT. By continuing to use,
;* modify or distribute this file you indicate that you have
;* read the license and understand and accept it fully.
;*

INCLUDE "lang.inc"
INCLUDE "errors.inc"
INCLUDE "mglobals.inc"
INCLUDE "mmem.inc"
INCLUDE "rawfile.inc"
INCLUDE "file.inc"
INCLUDE "sdevice.inc"
INCLUDE "mplayer.inc"
INCLUDE "timer.inc"
INCLUDE "mod.inc"
INCLUDE "s3m.inc"
INCLUDE "dma.inc"
INCLUDE "dsm.inc"
INCLUDE "ems.inc"
INCLUDE "vu.inc"




;/***************************************************************************\
;*     MIDAS Sound System global variables:
;\***************************************************************************/

GLOBAL  LANG GUS : SoundDevice          ; Gravis UltraSound Sound Device
GLOBAL	LANG SB : SoundDevice		; Sound Blaster Sound Device
GLOBAL	LANG WSS : SoundDevice		; Windows Sound System Sound Device
GLOBAL	LANG PAS : SoundDevice		; Pro Audio Spectrum Sound Device
GLOBAL	LANG NSND : SoundDevice 	; No Sound Sound Device

NUMSDEVICES = 5 			; total number of Sound Devices
NUMMPLAYERS = 2

GLOBAL	LANG mpS3M : ModulePlayer	; Scream Tracker 3 Module Player
GLOBAL	LANG mpMOD : ModulePlayer	; Pro Tracker Module Player

GLOBAL	LANG SD : dword 		; far pointer to current Sound Device
GLOBAL	LANG MP : dword 		; far pointer to current Module Player

GLOBAL	LANG midasSoundDevices : dword	; pointers to all Sound Devices
GLOBAL  LANG midasModulePlayers : dword ; pointers to all Module Players
GLOBAL  LANG midasMPALE : word          ; Module Player ALE flags



;/***************************************************************************\
;*	MIDAS global functions from MIDAS.C:
;\***************************************************************************/


;/***************************************************************************\
;*
;* Function:     void midasError(char *msg)
;*
;* Description:  Prints a MIDAS error message to stderr and exits to DOS
;*
;* Input:        char *msg               Pointer to error message string
;*
;\***************************************************************************/

GLOBAL  LANG midasError : far




;/***************************************************************************\
;*
;* Function:     void midasUninitError(char *msg)
;*
;* Description:  Prints an error message to stderr and exits to DOS without
;*               uninitializing MIDAS. This function should only be used
;*               from midasClose();
;*
;* Input:        char *msg               Pointer to error message string
;*
;\***************************************************************************/

GLOBAL  LANG midasUninitError : far



;/***************************************************************************\
;*
;* Function:     void midasDetectSD(void)
;*
;* Description:  Attempts to detect a Sound Device. Sets the global variable
;*               SD to point to the detected Sound Device or NULL if no
;*               Sound Device was detected
;*
;\***************************************************************************/

GLOBAL  LANG midasDetectSD : far



;/***************************************************************************\
;*
;* Function:     void midasInit(void)
;*
;* Description:  Initializes MIDAS Sound System
;*
;\***************************************************************************/

GLOBAL  LANG midasInit : far



;/***************************************************************************\
;*
;* Function:     void midasClose(void)
;*
;* Description:  Uninitializes MIDAS Sound System
;*
;\***************************************************************************/

GLOBAL  LANG midasClose : far



;/***************************************************************************\
;*
;* Function:     void midasSetDefaults(void)
;*
;* Description:  Initializes MIDAS Sound System variables to their default
;*               states. MUST be the first MIDAS function to be called.
;*
;\***************************************************************************/

GLOBAL  LANG midasSetDefaults : far



;/***************************************************************************\
;*
;* Function:     void midasParseOption(char *option)
;*
;* Description:  Parses one MIDAS command line option.
;*
;* Input:        char *option            Command line option string WITHOUT
;*                                       the leading '-' or '/'.
;*
;* Recognized options:
;*       -sx     Force Sound Device x (1 = GUS, 2 = PAS, 3 = WSS, 4 = SB,
;*               5 = No Sound)
;*       -pxxx   Force I/O port xxx (hex) for Sound Device
;*       -ix     Force IRQ x for Sound Device
;*       -dx     Force DMA channel x for Sound Device
;*       -mxxxx  Set mixing rate to xxxx Hz
;*       -oxxx   Force output mode (8 = 8-bit, 1 = 16-bit, s = stereo,
;*               m = mono)
;*       -e      Disable EMS usage
;*       -t      Disable ProTracker BPM tempos
;*       -u      Enable Surround sound
;*       -v      Disable real VU-meters
;*
;\***************************************************************************/

GLOBAL  LANG midasParseOption : far



;/***************************************************************************\
;*
;* Function:     void midasParseOptions(int optCount, char **options)
;*
;* Description:  Parses MIDAS command line options and sets MIDAS variables
;*               accordingly.
;*
;* Input:        int optCount            Number of options
;*               char **options          Pointer to an array of pointers to
;*                                       option strings.
;*
;* Also '/' is recognized as a option delimiter.
;*
;\***************************************************************************/

GLOBAL  LANG midasParseOptions : far



;/***************************************************************************\
;*
;* Function:     void midasParseEnvironment(void)
;*
;* Description:  Parses the MIDAS environment string, which has same format
;*               as the command line options.
;*
;\***************************************************************************/

GLOBAL  LANG midasParseEnvironment : far



;/***************************************************************************\
;*
;* Function:     mpModule *midasPlayModule(char *fileName, int numEffectChns)
;*
;* Description:  Loads a module into memory, points MP to the correct Module
;*               Player and starts playing it.
;*
;* Input:        char *fileName          Pointer to module file name
;*               int numEffectChns       Number of channels to open for sound
;*                                       effects.
;*
;* Returns:      Pointer to module structure. This function can not fail,
;*               as it will call midasError() to handle all error cases.
;*
;* Notes:        The Sound Device channels available for sound effects are the
;*               _first_ numEffectChns channels. So, for example, if you use
;*               midasPlayModule("TUNE.MOD", 3), you can use channels 0-2 for
;*               sound effects.
;*
;\***************************************************************************/

GLOBAL  LANG midasPlayModule : far



;/***************************************************************************\
;*
;* Function:     void midasStopModule(mpModule *module)
;*
;* Description:  Stops playing a module, deallocates it and uninitializes
;*               the Module Player. Also closes _all_ Sound Device channels,
;*               including those opened for effects.
;*
;\***************************************************************************/

GLOBAL  LANG midasStopModule : far





;/***************************************************************************\
;*     MIDAS global macros
;\***************************************************************************/


;/***************************************************************************\
;*
;* Macro:	SetBorder
;*
;* Description: Sets the border color. Will be disabled if NOBORDERCOLOR
;*		is defined
;*
;* Input:	color			new border color
;*
;\***************************************************************************/

MACRO	SetBorder	color
IFNDEF NOBORDERCOLOR
	push	dx ax
	mov	dx,03DAh
	in	al,dx
	mov	dx,03C0h
	mov	al,31h
	out	dx,al
	mov	al,color
	out	dx,al
	pop	ax dx
ENDIF
ENDM
