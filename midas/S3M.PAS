{*      S3M.PAS
 *
 * Scream Tracker 3 Module Player, v1.10
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*}

unit S3M;


interface



{****************************************************************************\
*       struct s3mChannel
*       -----------------
* Description:  S3M player internal channel structure
\****************************************************************************}

type
    s3mChannel = Record
        note : byte;
        int : byte;
        vol : byte;
        cmd : byte;
        info : byte;
        flags : byte;

        sample : byte;
        volume : byte;

        period : word;
        snote : byte;
        preinfo : byte;
        toperi : word;
        notepsp : byte;
        retrigc : byte;

        status : byte;

        vibcmd : byte;
        vibpos : byte;

        volbar : byte;

        trefl : byte;
        trecnt : byte;
    end;




type
    Ppointer = ^pointer;
    Pword = ^word;
    Pinteger = ^integer;
    Pchar = ^char;







{****************************************************************************\
*
* Function:     s3mDetectChannels(module : pointer; numChns : Pword) :
*                   integer;
*
* Description:  Detects the number of channels in a Scream Tracker 3 module
*
* Input:        module : pointer        pointer to module structure
*               numChns : Pword         pointer to channel number variable
*
* Returns:      MIDAS error code.
*               Number of channels in module stored in numChns^.
*
\****************************************************************************}

function s3mDetectChannels(module : pointer; numChns : Pword) : integer;




{***************************************************************************\
*
* Function:     s3mFindUsedInsts(module : pointer; used : pointer) : integer;
*
* Description:  Finds which instruments are used in a Scream Tracker 3 module.
*
* Input:        module : pointer        Pointer to module structure. At least
*                                       the patterns must have been loaded
*               used : pointer          Pointer to instruments used array -
*                                       one byte per instrument. Set to 1 if
*                                       instrument is used, 0 if not.
*
* Returns:      MIDAS error code.
*
\***************************************************************************}

function s3mFindUsedInsts(module : pointer; used : pointer) : integer;


function s3mIdentify(header : pointer; recognized : Pinteger) : integer;
function s3mInit(SD : pointer) : integer;
function s3mClose : integer;
function s3mPlayModule(module : pointer; firstSDChannel, numSDChannels,
    loopStart, loopEnd : word) : integer;
function s3mStopModule : integer;
function s3mSetInterrupt : integer;
function s3mRemoveInterrupt : integer;
function s3mPlay : integer;
function s3mSetPosition(npos : word) : integer;
function s3mGetInformation(info : pointer) : integer;



procedure mpS3M;                        { S3M Module Player structure. }



implementation


USES  Errors, mGlobals, mMem, EMS, MPlayer, SDevice, Timer, mFile
{$IFDEF REALVUMETERS}
    ,VU
{$ENDIF}
    ;


function s3mLoadModule(fileName : Pchar; SD : pointer; module : Ppointer) :
    integer; external;
function s3mFreeModule(module : pointer; SD : pointer) : integer; external;
{$L S3MLOAD.OBJ}


function s3mDetectChannels(module : pointer; numChns : Pword) : integer;
    external;
function s3mFindUsedInsts(module : pointer; used : pointer) : integer;
    external;
function s3mIdentify(header : pointer; recognized : Pinteger) : integer;
    external;
function s3mInit(SD : pointer) : integer; external;
function s3mClose : integer; external;
function s3mPlayModule(module : pointer; firstSDChannel, numSDChannels,
    loopStart, loopEnd : word) : integer; external;
function s3mStopModule : integer; external;
function s3mSetInterrupt : integer; external;
function s3mRemoveInterrupt : integer; external;
function s3mPlay : integer; external;
function s3mSetPosition(npos : word) : integer; external;
function s3mGetInformation(info : pointer) : integer; external;
procedure mpS3M; external;
{$L S3M.OBJ}


{****************************************************************************\
*       enum s3mFunctIDs
*       ----------------
* Description:  ID numbers for Scream Tracker 3 Module Player functions
\****************************************************************************}

const
    ID_s3mIdentify = ID_s3m;
    ID_s3mInit = ID_s3m + 1;
    ID_s3mClose = ID_s3m + 2;
    ID_s3mLoadModule = ID_s3m + 3;
    ID_s3mFreeModule = ID_s3m + 4;
    ID_s3mPlayModule = ID_s3m + 5;
    ID_s3mStopModule = ID_s3m + 6;
    ID_s3mSetInterrupt = ID_s3m + 7;
    ID_s3mRemoveInterrupt = ID_s3m + 8;
    ID_s3mPlay = ID_s3m + 9;
    ID_s3mSetPosition = ID_s3m + 10;
    ID_s3mGetInformation = ID_s3m + 11;
    ID_s3mDetectChannels = ID_s3m + 12;
    ID_s3mFindUsedInsts = ID_s3m + 13;


END.
