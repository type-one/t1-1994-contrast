;*	DSM.INC
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

VOLLEVELS = 33				; total number of volume levels
VOLSHIFT = 1				; amount to shift volume right
VOLADD = 1				; amount to add to volume before
					; shifting - used to round up
SMPMAX = 65519				; max sample length


;/***************************************************************************\
;*	 struct dsmChannel
;*	 -----------------
;* Description:  DSM channel data
;\***************************************************************************/

STRUC	dsmChannel

	pos		DW	?	; mixing position
	posl		DW	?	; mixing position fraction
	rate		DD	?	; playing rate in Hz
	inst		DW	?	; instrument number
        sample          DD      ?       ; current sample pointer
        smpType         DB      ?       ; current sample type
        smpPos          DB      ?       ; current sample position
        slength         DW      ?       ; current sample length
        loopStart       DW      ?       ; current sample loop start
        loopEnd         DW      ?       ; current sample loop end
        looping         DB      ?       ; 1 if current sample is looping
        instChanged     DB      ?       ; 1 if instrument has been changed
                                        ; (Amiga Loop Emulation)
        panning         DB      ?       ; panning information
	volume		DB	?	; playing volume (0-64)
	muted		DB	?	; 1 if channel muted, 0 if not
	hasData 	DB	?	; 1 if channel has data to be played,
					; 0 if not
ENDS



;/***************************************************************************\
;*	 struct dsmInstrument
;*	 --------------------
;* Description:  DSM internal instrument structure
;\***************************************************************************/

STRUC	dsmInstrument

	sample		DD	?	; pointer to sample data
	smpType 	DB	?	; sample type
	smpPos		DB	?	; sample position. see enum dsmSmpPos
	slength 	DW	?	; sample length
	loopStart	DW	?	; sample loop start
	loopEnd 	DW	?	; sample loop end
	volume		DB	?	; default playing volume
	looping 	DB	?	; 1 if looping sample, 0 if not
	inuse		DB	?	; 1 if sample is in use, 0 if not
					; (removed using dsmRemInstrument())
ENDS




GLOBAL	LANG dsmInit : far
GLOBAL	LANG dsmClose : far
GLOBAL	LANG dsmGetMixRate : far
GLOBAL	LANG dsmGetMode : far
GLOBAL	LANG dsmOpenChannels : far
GLOBAL	LANG dsmCloseChannels : far
GLOBAL	LANG dsmClearChannels : far
GLOBAL	LANG dsmMute : far
GLOBAL	LANG dsmPause : far
GLOBAL	LANG dsmSetMasterVolume : far
GLOBAL	LANG dsmPlaySound : far
GLOBAL	LANG dsmStopSound : far
GLOBAL	LANG dsmSetRate : far
GLOBAL	LANG dsmGetRate : far
GLOBAL	LANG dsmSetVolume : far
GLOBAL	LANG dsmSetInstrument : far
GLOBAL	LANG dsmSetPosition : far
GLOBAL	LANG dsmGetPosition : far
GLOBAL	LANG dsmSetPanning : far
GLOBAL	LANG dsmGetPanning : far
GLOBAL	LANG dsmMuteChannel : far
GLOBAL	LANG dsmAddInstrument : far
GLOBAL	LANG dsmRemInstrument : far
GLOBAL	LANG dsmSetUpdRate : far
GLOBAL	LANG dsmPlay : far



GLOBAL	LANG dsmBuffer : dmaBuffer	; DMA buffer
GLOBAL	LANG dsmDMAPos : word		; buffer playing position



;/***************************************************************************\
;*       enum dsmFunctIDs
;*       ----------------
;* Description:  ID numbers for DSM functions
;\***************************************************************************/

ENUM    dsmFunctIDs \
        ID_dsmInit = ID_dsm, \
        ID_dsmClose, \
        ID_dsmOpenChannels, \
        ID_dsmCloseChannels, \
        ID_dsmGetMixRate, \
        ID_dsmGetMode, \
        ID_dsmClearChannels, \
        ID_dsmMute, \
        ID_dsmPause, \
        ID_dsmSetMasterVolume, \
        ID_dsmPlaySound, \
        ID_dsmStopSound, \
        ID_dsmSetRate, \
        ID_dsmGetRate, \
        ID_dsmSetVolume, \
        ID_dsmSetInstrument, \
        ID_dsmSetPosition, \
        ID_dsmGetPosition, \
        ID_dsmSetPanning, \
        ID_dsmGetPanning, \
        ID_dsmMuteChannel, \
        ID_dsmAddInstrument, \
        ID_dsmRemInstrument, \
        ID_dsmSetUpdRate, \
        ID_dsmPlay, \
        ID_dsmMixData
