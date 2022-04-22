;*	TIMER.INC
;*
;* TempoTimer, v1.10
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
;*
;* Function:     int tmrGetScrSync(ushort *scrSync);
;*
;* Description:  Calculates the screen synchronization value for timer
;*
;* Input:        ushort *scrSync         pointer to screen synchronization
;*                                       value
;*
;* Returns:      MIDAS error code.
;*               Screen syncronization value used with tmrSyncScr() is stored
;*               in *scrSync.
;*
;\***************************************************************************/

GLOBAL  LANG tmrGetScrSync : far




;/***************************************************************************\
;*
;* Function:     int tmrInit(void);
;*
;* Description:  Initializes TempoTimer.
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

GLOBAL  LANG tmrInit : far




;/***************************************************************************\
;*
;* Function:     int tmrClose(void);
;*
;* Description:  Uninitializes TempoTimer. MUST be called if and ONLY if
;*               tmrInit() has been called.
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

GLOBAL  LANG tmrClose : far




;/***************************************************************************\
;*
;* Function:     int tmrPlay(void (*play)(), SoundDevice *SD);
;*
;* Description:  Starts playing music with the timer. Update rate set to 50Hz.
;*
;* Input:        void (*play)()          Music playing function
;*               SoundDevice *SD         Sound Device used for playing
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

GLOBAL  LANG tmrPlay : far




;/***************************************************************************\
;*
;* Function:     int tmrStop(void);
;*
;* Description:  Stops playing music with the timer.
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

GLOBAL  LANG tmrStop : far




;/***************************************************************************\
;*
;* Function:     int tmrSyncScr(ushort sync, void (*preVR)(), void (*immVR)(),
;*               void (*inVR)());
;*
;* Description:  Synchronizes the timer to screen refresh.
;*
;* Input:        ushort sync             Screen synchronization value returned
;*                                       by tmrGetScrSync().
;*               void (*preVR)()         Pointer to the routine that will be
;*                                       called BEFORE Vertical Retrace
;*               void (*immVR)()         Pointer to the routine that will be
;*                                       called immediately after Vertical
;*                                       Retrace starts
;*               void (*inVR)()          Pointer to the routine that will be
;*                                       called some time during Vertical
;*                                       Retrace
;*
;* Returns:      MIDAS error code
;*
;* Notes:        preVR() and immVR() functions must be as short as possible
;*               and do nothing else than update counters or set some VGA
;*               registers to avoid timer synchronization problems. inVR()
;*               can take a longer time and can be used for, for example,
;*               setting the palette.
;*
;\***************************************************************************/

GLOBAL  LANG tmrSyncScr : far




;/***************************************************************************\
;*
;* Function:     int tmrStopScrSync(void);
;*
;* Description:  Stops synchronizing the timer to the screen.
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

GLOBAL  LANG tmrStopScrSync : far



;/***************************************************************************\
;*
;* Function:     int tmrSetUpdRate(ushort updRate);
;*
;* Description:  Sets the timer update rate, ie. the rate at which the music
;*               playing routine is called
;*
;* Input:        ushort updRate          updating rate, in 100*Hz (5000=50Hz)
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

GLOBAL  LANG tmrSetUpdRate : far



;/***************************************************************************\
;*       enum tmrFunctIDs
;*       ----------------
;* Description:  ID numbers for TempoTimer functions
;\***************************************************************************/

ENUM    tmrFunctIDs \
        ID_tmrGetScrSync = ID_tmr, \
        ID_tmrInit, \
        ID_tmrClose, \
        ID_tmrPlay, \
        ID_tmrStop, \
        ID_tmrSyncScr, \
        ID_tmrStopScrSync, \
        ID_tmrSetUpdRate
