{*      TIMER.PAS
 *
 * TempoTimer, v1.10
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*}

unit Timer;


interface


type
    Pword = ^word;



{****************************************************************************\
*
* Function:     tmrGetScrSync(scrSync : Pword) : integer;
*
* Description:  Calculates the screen synchronization value for timer
*
* Input:        scrSync : Pword         pointer to screen synchronization
*                                       value
*
* Returns:      MIDAS error code.
*               Screen syncronization value used with tmrSyncScr() is stored
*               in scrSync^.
*
\****************************************************************************}

function tmrGetScrSync(scrSync : Pword) : integer;




{****************************************************************************\
*
* Function:     tmrInit : integer;
*
* Description:  Initializes TempoTimer.
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function tmrInit : integer;




{****************************************************************************\
*
* Function:     tmrClose : integer
*
* Description:  Uninitializes TempoTimer. MUST be called if and ONLY if
*               tmrInit() has been called.
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function tmrClose : integer;




{****************************************************************************\
*
* Function:     tmrPlay(play : pointer; SD : pointer) : integer;
*
* Description:  Starts playing music with the timer. Update rate set to 50Hz.
*
* Input:        play : pointer      Music playing function
*               SD : pointer        Sound Device used for playing
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function tmrPlay(play : pointer; SD : pointer) : integer;




{****************************************************************************\
*
* Function:     tmrStop : integer
*
* Description:  Stops playing a module.
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function tmrStop : integer;




{****************************************************************************\
*
* Function:     tmrSyncScr(sync : word; preVR, immVR, inVR : pointer) :
*                   integer;
*
* Description:  Synchronizes the timer to screen refresh.
*
* Input:        sync : word             Screen synchronization value returned
*                                       by tmrGetScrSync().
*               preVR : pointer         Pointer to the routine that will be
*                                       called BEFORE Vertical Retrace
*               immVR : pointer         Pointer to the routine that will be
*                                       called immediately after Vertical
*                                       Retrace starts
*               inVR : pointer          Pointer to the routine that will be
*                                       called some time during Vertical
*                                       Retrace
*
* Returns:      MIDAS error code
*
* Notes:        preVR() and immVR() functions must be as short as possible
*               and do nothing else than update counters or set some VGA
*               registers to avoid timer synchronization problems. inVR()
*               can take a longer time and can be used for, for example,
*               setting the palette.
*
\****************************************************************************}

function tmrSyncScr(sync : word; preVR, immVR, inVR : pointer) : integer;




{****************************************************************************\
*
* Function:     tmrStopScrSync : integer;
*
* Description:  Stops synchronizing the timer to the screen.
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function tmrStopScrSync : integer;



{****************************************************************************\
*
* Function:     tmrSetUpdRate(updRate : word) : integer;
*
* Description:  Sets the timer update rate, ie. the rate at which the module
*               playing routine is called
*
* Input:        updRate : word          updating rate, in 100*Hz (5000=50Hz)
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function tmrSetUpdRate(updRate : word) : integer;



implementation

uses  Errors, mGlobals, EMS, DMA, DSM;



function tmrGetScrSync(scrSync : Pword) : integer; external;
function tmrInit : integer; external;
function tmrClose : integer; external;
function tmrPlay(play : pointer; SD : pointer) : integer; external;
function tmrStop : integer; external;
function tmrSyncScr(sync : word; preVR, immVR, inVR : pointer) : integer;
    external;
function tmrStopScrSync : integer; external;
function tmrSetUpdRate(updRate : word) : integer; external;
{$L TIMER.OBJ}


END.
