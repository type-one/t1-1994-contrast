{*      MODP.PAS
 *
 * ProTracker Module Player, v1.10
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*}


unit MODP;


interface



{****************************************************************************\
*       struct modChannel
*       -----------------
* Description:  Protracker module player channel data structure
\****************************************************************************}

type
    modChannel = Record
        note : byte;
        inst : byte;
        cmd : byte;
        info : byte;
        comp : byte;

        sample : byte;
        volume : byte;

        period : word;
        snote : word;
        loff : byte;
        coff : byte;
        toperi : word;
        notepsp : byte;
        retrigc : byte;

        status : byte;

        vibcmd : byte;
        vibpos : byte;

        trecmd : byte;
        trepos : byte;

        volbar : byte;
        playoff : word;
    end;



    Pinteger = ^integer;
    Pword = ^word;
    Ppointer = ^pointer;
    Pchar = ^char;




{****************************************************************************\
*
* Function:     modLoadModule(fileName : Pchar; SD : pointer;
*                   module : Ppointer) : integer;
*
* Description:  Loads a Protracker module into memory
*
* Input:        fileName : Pchar        pointer to module file name string,
*                                       ASCIIZ!
*               SD : pointer            pointer to the Sound Device which will
*                                       store the samples
*               module : Ppointer       pointer to variable which will store
*                                       the module pointer.
*
* Returns:      MIDAS error code.
*               Pointer to module structure is stored in module^.
*
\****************************************************************************}

function modLoadModule(fileName : Pchar; SD : pointer; module : Ppointer) :
    integer;



{****************************************************************************\
*
* Function:     modFreeModule(module : pointer; SD : pointer) : integer;
*
* Description:  Deallocates a Protracker module
*
* Input:        module : pointer        pointer to module to be deallocated
*               SD : pointer            Sound Device that has stored the
*                                       samples
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function modFreeModule(module : pointer; SD : pointer) : integer;




function modConvertSample(sample : pointer; length : word) : integer;
function modConvertTrack(track : pointer; ttype : word; trackLen : Pword)
    : integer;

function modIdentify(header : pointer; recognized : Pinteger) : integer;
function modInit(SD : pointer) : integer;
function modClose : integer;
function modPlayModule(module : pointer; firstSDChannel, numSDChannels,
    loopStart, loopEnd : word) : integer;
function modStopModule : integer;
function modSetInterrupt : integer;
function modRemoveInterrupt : integer;
function modPlay : integer;
function modSetPosition(pos : word) : integer;
function modGetInformation(info : pointer) : integer;


procedure mpMOD;                        { Protracker Module Player structure }



implementation


USES  Errors, mGlobals, mMem, EMS, MPlayer, SDevice, Timer, mFile
{$IFDEF REALVUMETERS}
    ,VU
{$ENDIF}
    ;



function modLoadModule(fileName : Pchar; SD : pointer; module : Ppointer) :
    integer; external;
function modFreeModule(module : pointer; SD : pointer) : integer; external;
{$L MODLOAD.OBJ}


function modConvertSample(sample : pointer; length : word) : integer;
    external;
function modConvertTrack(track : pointer; ttype : word; trackLen : Pword)
    : integer; external;

function modIdentify(header : pointer; recognized : Pinteger) : integer;
    external;
function modInit(SD : pointer) : integer; external;
function modClose : integer; external;
function modPlayModule(module : pointer; firstSDChannel, numSDChannels,
    loopStart, loopEnd : word) : integer; external;
function modStopModule : integer; external;
function modSetInterrupt : integer; external;
function modRemoveInterrupt : integer; external;
function modPlay : integer; external;
function modSetPosition(pos : word) : integer; external;
function modGetInformation(info : pointer) : integer; external;
procedure mpMOD; external;
{$L MOD.OBJ}


END.
