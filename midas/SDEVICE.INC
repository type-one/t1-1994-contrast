;*	SDEVICE.INC
;*
;* Sound Device definitions
;*
;* Copyright 1994 Petteri Kangaslampi and Jarno Paananen
;*
;* This file is part of the MIDAS Sound System, and may only be
;* used, modified and distributed under the terms of the MIDAS
;* Sound System license, LICENSE.TXT. By continuing to use,
;* modify or distribute this file you indicate that you have
;* read the license and understand and accept it fully.
;*

SMPMAX = 65519				; max sample length (65536-16 - 1)
MAXINSTS = 256                          ; maximum number of instruments


ENUM	smpTypes \
	smpNone = 0, \
	smp8bit


ENUM	sdPanning \
	panLeft = -64, \
	panMiddle = 0, \
	panMono = 0, \
	panRight = 64,\
	panSurround = 80h


ENUM	sdSmpPos \
	sdSmpNone = 0, \
	sdSmpConv, \
	sdSmpEMS


;/***************************************************************************\
;*	 enum sdMode
;*	 -----------
;* Description:  Possible SoundDevice output modes
;\***************************************************************************/

ENUM	sdMode \
	sdMono = 1, \
	sdStereo = 2, \
	sd8bit = 4, \
	sd16bit = 8, \
	sdLowQ = 16, \
	sdNormalQ = 32, \
	sdHighQ = 64



;/****************************************************************************
;*	 enum sdStatus
;*	 -------------
;* Description:  SoundDevice status
;\****************************************************************************

ENUM	sdStatus \
	sdUnInitialized = 0, \
	sdOK


;/****************************************************************************
;*	 struct SoundDevice
;*	 ------------------
;* Description:  SoundDevice structure
;\****************************************************************************

STRUC	SoundDevice

	tempoPoll	DW	?	; 1 if Play() should be called
					; according to the tempo, 0 if
					; not (mixing SoundDevice)
	port		DW	?	; base I/O port address
	IRQ		DB	?	; IRQ number
	DMA		DB	?	; DMA channel number
	status		DW	?	; status (see enum above)
	modes		DW	?	; possible SD modes (see enum)
	ID		DD	?	; ID string (ASCIIZ)

	Detect		DD	?
	Init		DD	?
	Close		DD	?

	GetMixRate	DD	?
	GetMode 	DD	?

	OpenChannels	DD	?
	CloseChannels	DD	?
	ClearChannels	DD	?

	Mute		DD	?
	Pause		DD	?

	SetMasterVolume DD	?

	PlaySound	DD	?
	StopSound	DD	?
	SetRate 	DD	?
	GetRate 	DD	?
	SetVolume	DD	?
	SetInstrument	DD	?
	SetPosition	DD	?
	GetPosition	DD	?

	SetPanning	DD	?
	GetPanning	DD	?
	MuteChannel	DD	?

	AddInstrument	DD	?
	RemInstrument	DD	?

	SetUpdRate	DD	?

	Play		DD	?
ENDS
