;*	S3M.INC
;*
;* Scream Tracker 3 Module Player, v1.10
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
;*	 struct s3mHeader
;*	 ----------------
;* Description:  Scream Tracker 3 module file header
;\***************************************************************************/

STRUC	s3mHeader
	sname		DB	28 DUP (?)	; song name
	num1A		DB	?		; 1Ah
	ftype		DB	?		; file type
	unused1 	DW	?
	songLength	DW	?		; number of orders
	numInsts	DW	?		; number of instruments
	numPatts	DW	?		; number of patterns
	flags		DW	?		; flags
	trackerVer	DW	?		; tracker version
	formatVer	DW	?		; file format version
	SCRM		DB	4 DUP (?)	; "SCRM"
	masterVol	DB	?		; master volume
	speed		DB	?		; initial speed
	tempo		DB	?		; initial tempo
	masterMult	DB	?		; master multiplier
	unused2 	DB	12 DUP (?)
	chanSettings	DB	32 DUP (?)	; channel settings
ENDS




;/***************************************************************************\
;*	 struct s3mInstHdr
;*	 -----------------
;* Description:  Scream Tracker 3 module instrument file header
;\***************************************************************************/

STRUC	s3mInstHdr
	itype		DB	?		; instrument type
	dosName 	DB	12 DUP (?)	; DOS filename (8+3)
	zero		DB	?		; 0
	samplePtr	DW	?		; paragraph ptr to sample data
	slength 	DD	?		; sample length
	loopStart	DD	?		; sample loop start
	loopEnd 	DD	?		; sample loop end
	volume		DB	?		; volume
	disk		DB	?		; instrument disk
	pack		DB	?		; sample packing info
	flags		DB	?		; bit0 = loop
						; bit1 = stereo
						; bit2 = 16-bit
	c2Rate		DD	?		; C2 sampling rate
	unused		DD	?
	gusPos		DW	?		; position in GUS memory / 32
	int512		DW	?
	intLastUsed	DD	?
	iname		DB	28 DUP (?)	; instrument name
	SCRS		DB	4 DUP (?)	; "SCRS" if sample
ENDS




;/***************************************************************************\
;*	 struct s3mChannel
;*	 -----------------
;* Description:  Scream Tracker 3 module player internal channel structure
;\***************************************************************************/

STRUC	s3mChannel
	note		DB	?
	inst		DB	?
	vol		DB	?
	cmd		DB	?
	info		DB	?
	flags		DB	?

	sample		DB	?
	volume		DB	?

	period		DW	?
	snote		DB	?
	preinfo 	DB	?
	toperi		DW	?
	notepsp 	DB	?
	retrigc 	DB	?

	status		DB	?

	vibcmd		DB	?
	vibpos		DB	?

	volbar		DB	?
	trefl		DB	?
	trecnt		DB	?
ENDS




GLOBAL	LANG s3mLoadModule : far
GLOBAL	LANG s3mFreeModule : far
GLOBAL	LANG s3mIdentify : far
GLOBAL	LANG s3mInit : far
GLOBAL	LANG s3mClose : far
GLOBAL	LANG s3mPlayModule : far
GLOBAL	LANG s3mStopModule : far
GLOBAL	LANG s3mSetInterrupt : far
GLOBAL	LANG s3mRemoveInterrupt : far
GLOBAL	LANG s3mPlay : far
GLOBAL	LANG s3mSetPosition : far
GLOBAL	LANG s3mGetInformation : far
GLOBAL	LANG s3mDetectChannels : far
GLOBAL	LANG s3mFindUsedInsts : far


GLOBAL	LANG mpS3M : ModulePlayer



;/***************************************************************************\
;*	 enum s3mFunctIDs
;*	 ----------------
;* Description:  ID numbers for Scream Tracker 3 Module Player functions
;\***************************************************************************/

ENUM	s3mFunctIDs \
	ID_s3mIdentify = ID_s3m, \
	ID_s3mInit, \
	ID_s3mClose, \
	ID_s3mLoadModule, \
	ID_s3mFreeModule, \
	ID_s3mPlayModule, \
	ID_s3mStopModule, \
	ID_s3mSetInterrupt, \
	ID_s3mRemoveInterrupt, \
	ID_s3mPlay, \
	ID_s3mSetPosition, \
	ID_s3mGetInformation, \
	ID_s3mDetectChannels, \
	ID_s3mFindUsedInsts
