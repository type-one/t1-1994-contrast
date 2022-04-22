{*      VU.PAS
 *
 * Real VU meter routines
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*}


unit VU;


interface



{****************************************************************************\
*       struct vuInstrument
*       -------------------
* Description:  VU-meter internal instrument structure
\****************************************************************************}

type
    vuInstrument = Record
        vuInfo : ^byte;                 { pointer to VU information or NULL }
        slength : word;                 { sample length }
        loopStart : word;               { sample loop start }
        loopEnd : word;                 { sample loop end or 0 if no looping }
    end;

    Pword = ^word;




{****************************************************************************\
*
* Function:     vuInit : integer;
*
* Description:  Initializes VU-meters, allocating room for MAXINSTS
*               instruments.
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function vuInit : integer;



{****************************************************************************\
*
* Function:     vuClose : integer;
*
* Description:  Uninitializes VU-meters
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function vuClose : integer;



{****************************************************************************\
*
* Function:     vuPrepare(inst : word; sample : pointer; slength, loopStart,
*                   loopEnd : word): integer;
*
* Description:  Prepares the VU information for an instrument
*
* Input:        inst : word             instrument number
*               sample : pointer        pointer to sample data
*               slength : word          sample length
*               loopStart : word        sample loop start
*               loopEnd : word          sample loop end (0 if no looping)
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function vuPrepare(inst : word; sample : pointer; slength, loopStart,
    loopEnd : word): integer;



{****************************************************************************\
*
* Function:     vuRemove(inst : word) : integer;
*
* Description:  Removes and deallocates the VU information for an instrument
*
* Input:        inst : word             instrument number
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function vuRemove(inst : word) : integer;




{****************************************************************************\
*
* Function:     function vuMeter(inst : word; rate : longint; pos, volume : word,
*                   meter : Pword) : integer;
*
* Description:  Calculates the VU-meter value (0-64) for the next 1/50th of
*               a second
*
* Input:        inst : word             instrument that is played
*               rate : longint          playing rate
*               pos : word              sample playing position
*               volume : word           playing volume (0-64)
*               meter : Pword           pointer to VU-meter value
*
* Returns:      MIDAS error code.
*               VU-meter value (0-64) is stored in meter^
*
\****************************************************************************}

function vuMeter(inst : word; rate : longint; pos, volume : word;
    meter : Pword) : integer;



implementation


USES Errors, mMem;


function vuInit : integer; external;
function vuClose : integer; external;
function vuPrepare(inst : word; sample : pointer; slength, loopStart,
    loopEnd : word): integer; external;
function vuRemove(inst : word) : integer; external;
function vuMeter(inst : word; rate : longint; pos, volume : word;
    meter : Pword) : integer; external;
{$L VU.OBJ}



END.
