{*      MPLAYER.PAS
 *
 * Module Player definitions
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*}


unit MPlayer;


interface


const
    MPHDRSIZE = 1084;                   { header size needed for
                                          ModulePlayer.Identify() }

{****************************************************************************\
*       enum mpStatus
*       -------------
* Description:  Module Player status
\****************************************************************************}

const
    mpUnInitialized = 0;
    mpInitialized = 1;
    mpPlaying = 2;
    mpStopped = 3;



{****************************************************************************\
*       enum modIDNumbers
*       -----------------
* Description:  mpModule ID numbers
\****************************************************************************}

const
    idS3M = 0;                          { Scream Tracker 3 module }
    idMOD = 1;                          { Protracker module }



{****************************************************************************\
*       struct mpChanInfo
*       -----------------
* Description:  Module Player data structure for dump.
\****************************************************************************}

type
    mpChanInfo = Record
        flags : byte;                   { bits 0-4 - UNDEFINED
                                          bit 5 - new note and/or instrument
                                          bit 6 - new volume (S3M)
                                          bit 7 - command }
        note : byte;                    { note number }
        instrument : byte;              { instrument number }
        volume : byte;                  { playing volume }
        command : char;                 { command number }
        infobyte : byte;                { command infobyte }
        volumebar : byte;               { "fake" volume bar }
        commandname : pointer;          { Pointer to command name string,
                                          ASCIIZ }
    end;

    PmpChanInfo = ^mpChanInfo;
    mpChanInfoArray = array[0..31] of mpChanInfo;
    PmpChanInfoArray = ^mpChanInfoArray;




{****************************************************************************\
*       struct mpInformation
*       --------------------
* Description:  Module Player information structure.
\****************************************************************************}

type
    mpInformation = Record
        numChannels : word;             { number of channels. MUST be set by
                                          the routine calling
                                          MP^.GetInformation() }
        setFrame : word;                { 1 if "set frame", 0 if not }
        speed : word;                   { playing speed }
        BPM : word;                     { playing BPM tempo }
        pos : word;                     { current playing position }
        pattern : word;                 { current pattern number }
        row : word;                     { current row number }
        loopCnt : word;                 { song loop counter }
        chans : PmpChanInfoArray;       { pointer to channel data structures.
                                          MUST be allocated by the routine
                                          calling MP->GetInformation() }
    end;

    PmpInformation = ^mpInformation;




{****************************************************************************\
*       struct mpInstrument
*       -------------------
* Description:  Module Player instrument structure in memory
\****************************************************************************}

type
    mpInstrument = Record
        fileName : array[0..12] of char; { DOS file name, ASCIIZ }
        iname : array[0..31] of char;   { instrument name, ASCIIZ }
        sample : pointer;               { pointer to sample data or NULL
                                          if not available (no sample /
                                          deallocated) }
        length : word;                  { sample length }
        loopStart : word;               { sample loop start }
        loopEnd : word;                 { sample loop end }
        looping : byte;                 { 1 if looping sample, 0 if not }
        volume : byte;                  { sample default playing volume }
        c2Rate : longint;               { C2 sampling rate }
        finetune : byte;                { Sample default finetune value }
        sdInstHandle : word;            { Sound Device instrument handle for
                                          this instrument or 0 if not added
                                          to Sound Device instrument list }
    end;

    PmpInstrument = ^mpInstrument;




{****************************************************************************\
*       struct mpPattern
*       ----------------
* Description:  Module Player pattern structure in memory
\****************************************************************************}

type
    mpPattern = Record
        length : word;                  { pattern data length in bytes }
        data : array [0..0] of byte;    { actual pattern data }
    end;

    PmpPattern = ^mpPattern;




type
    byteArray = array [0..8192] of byte;
    PmpPatternArray = array [0..8192] of PmpPattern;
    mpInstrumentArray = array [0..256] of mpInstrument;


{****************************************************************************\
*       struct mpModule
*       ---------------
* Description:  General Module structure. See MPLAYER.TXT for documentation
\****************************************************************************}

type
    mpModule = Record
        ID : array [0..3] of char;      { Module identifier }
        IDnum : word;                   { ID number (0=S3M, 1=MOD) }
        songName : array [0..31] of char; { song name, ASCIIZ }
        songLength : word;              { number of orders }
        numInsts : word;                { number of instruments }
        numPatts : word;                { number of patterns }
        numChans : word;                { number of channels }
        flags : word;                   { S3M player flags }
        masterVol : byte;               { master volume }
        speed : byte;                   { initial speed }
        tempo : byte;                   { initial BPM tempo }
        masterMult : byte;              { master multiplier }
        stereo : byte;                  { 1 = stereo, 0 = mono }
        chanSettings : array [0..31] of byte; { channel settings for 32 chns }
        orders : ^byteArray;            { pointer to pattern orders }
        insts : ^mpInstrumentArray;     { pointer to instrument datas }
        patterns : ^PmpPatternArray;    { pointer to array of pattern
                                          pointers }
        pattEMS : ^byteArray;           { one byte for each pattern - 1 if
                                          pattern in EMS, 0 if not }
        instsUsed : ^byteArray;         { one byte for each instrument - 1 if
                                          instrument is used, 0 if not }
    end;

    PmpModule = ^mpModule;




{****************************************************************************\
*       struct ModulePlayer
*       -------------------
* Description:  Module Player structure. See MPLAYER.TXT for documentation
\****************************************************************************}

type
    Pinteger = ^integer;
    Pword = ^word;
    Pchar = ^char;
    PPmpModule = ^PmpModule;

    mpIdentify = function(header : pointer; recognized : Pinteger) : integer;
    mpInit = function(SD : pointer) : integer;
    mpClose = function : integer;
    mpLoadModule = function(fileName : Pchar; SD : pointer;
        module : PPmpModule) : integer;
    mpFreeModule = function(module : PmpModule; SD : pointer) : integer;
    mpPlayModule = function(module : PmpModule; firstSDChannel, numChannels,
        loopStart, loopEnd : word) : integer;
    mpStopModule = function : integer;
    mpSetInterrupt = function : integer;
    mpRemoveInterrupt = function : integer;
    mpPlay = function : integer;
    mpSetPosition = function(pos : word) : integer;
    mpGetInformation = function(info : PmpInformation) : integer;
    mpSetMasterVolume = function(volume : byte) : integer;

    ModulePlayer = Record
        Status : word;
        UpdRate : word;

        Identify : mpIdentify;
        Init : mpInit;
        Close : mpClose;
        LoadModule : mpLoadModule;
        FreeModule : mpFreeModule;
        PlayModule : mpPlayModule;
        StopModule : mpStopModule;
        SetInterrupt : mpSetInterrupt;
        RemoveInterrupt : mpRemoveInterrupt;
        Play : mpPlay;
        SetPosition : mpSetPosition;
        GetInformation : mpGetInformation;
        SetMasterVolume : mpSetMasterVolume;
    end;

    PModulePlayer = ^ModulePlayer;


implementation


END.
