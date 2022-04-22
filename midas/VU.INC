;*	VU.INC
;*
;* Real VU meter routines
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
;*	 struct vuInstrument
;*	 -------------------
;* Description:  VU-meter internal instrument structure
;\***************************************************************************/

STRUC	vuInstrument
	vuInfo		DD	?	; pointer to VU information or NULL
	slength 	DW	?	; sample length
	loopStart	DW	?	; sample loop start
	loopEnd 	DW	?	; sample loop end or 0 if no looping
ENDS




;/***************************************************************************\
;*
;* Function:     int vuInit(void);
;*
;* Description:  Initializes VU-meters, allocating room for MAXINSTS
;*               instruments.
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

GLOBAL  LANG vuInit : far




;/***************************************************************************\
;*
;* Function:     int vuClose(void);
;*
;* Description:  Uninitializes VU-meters
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

GLOBAL  LANG vuClose : far




;/***************************************************************************\
;*
;* Function:     int vuPrepare(ushort inst, uchar *sample, ushort slength,
;*                             ushort loopStart, ushort loopEnd
;*
;* Description:  Prepares the VU information for an instrument
;*
;* Input:        ushort inst             instrument number
;*               uchar *sample           pointer to sample data
;*               ushort slength          sample length
;*               ushort loopStart        sample loop start
;*               ushort loopEnd          sample loop end (0 if no looping)
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

GLOBAL  LANG vuPrepare : far




;/***************************************************************************\
;*
;* Function:     int vuRemove(ushort inst);
;*
;* Description:  Removes and deallocates the VU information for an instrument
;*
;* Input:        ushort inst             instrument number
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

GLOBAL  LANG vuRemove : far




;/***************************************************************************\
;*
;* Function:     int vuMeter(ushort inst, ulong rate, ushort pos,
;*                           ushort volume, ushort *meter);
;*
;* Description:  Calculates the VU-meter value (0-64) for the next 1/50th of
;*               a second
;*
;* Input:        ushort inst             instrument that is played
;*               ushort rate             playing rate
;*               ushort volume           playing volume (0-64)
;*               ushort *meter           pointer to VU-meter value
;*
;* Returns:      MIDAS error code.
;*               VU-meter value (0-64) is stored in *meter
;*
;\***************************************************************************/

GLOBAL  LANG vuMeter : far



;/***************************************************************************\
;*       enum vuFunctIDs
;*       ---------------
;* Description:  ID numbers for real VU-meter functions
;\***************************************************************************/

ENUM    vuFunctIDs \
        ID_vuInit = ID_vu, \
        ID_vuClose, \
        ID_vuPrepare, \
        ID_vuRemove, \
        ID_vuMeter
