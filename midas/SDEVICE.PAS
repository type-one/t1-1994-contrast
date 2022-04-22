{*      SDEVICE.PAS
 *
 * Sound Device definitions
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*}

unit    SDevice;


interface


const
    SMPMAX = 65519;                     { max sample length (65536-16 - 1) }
    MAXINSTS = 256;                     { maximum number of instruments }



{****************************************************************************\
*       enum smpTypes
*       -------------
* Description:  Sample types
\****************************************************************************}

const
    smpNone = 0;                        { no sample }
    smp8bit = 1;                        { 8-bit unsigned sample }



{****************************************************************************\
*       enum sdPanning
*       --------------
* Description:  Sound Device panning values. Legal values range from
*               panLeft to panRight, in steps of 1, plus panSurround.
*               Surround sound is played from middle if surround is not
*               enabled.
\****************************************************************************}

const
    panLeft = -64;                      { left speaker }
    panMiddle = 0;                      { middle (both speakers) }
    panRight = 64;                      { right speaker }
    panSurround = $80;                  { surround sound }




{****************************************************************************\
*       enum sdSmpPos
*       -------------
* Description:  Sample positions in memory
\****************************************************************************}

const
    sdSmpNone = 0;                  { no sample }
    sdSmpConv = 1;                  { conventional memory }
    sdSmpEMS = 2;                   { EMS }



{****************************************************************************\
*       enum sdStatus
*       -------------
* Description:  SoundDevice status
\****************************************************************************}

const
    sdUnInitialized = 0;
    sdOK = 1;



{****************************************************************************\
*       enum sdMode
*       -----------
* Description:  Possible SoundDevice output modes
\****************************************************************************}

const
    sdMono = 1;                         { mono }
    sdStereo = 2;                       { stereo }

    sd8bit = 4;                         { 8-bit output }
    sd16bit = 8;                        { 16-bit output }

    sdLowQ = 16;                        { low quality mixing }
    sdNormalQ = 32;                     { normal quality mixing }
    sdHighQ = 64;                       { high quality mixing }



{****************************************************************************\
*       struct SoundDevice
*       ------------------
* Description:  SoundDevice structure. See SDEVICE.TXT for documentation
\****************************************************************************}

    { Sound Device function pointer types: }
type
    Pinteger = ^integer;
    Pword = ^word;
    Plongint = ^longint;

    sdDetect = function(result : Pinteger) : integer;
    sdInit = function(mixRate, mode : word) : integer;
    sdClose = function : integer;
    sdGetMixRate = function(mixRate : Pword) : integer;
    sdGetMode = function(mode : Pword) : integer;
    sdOpenChannels = function(channels : word) : integer;
    sdCloseChannels = function : integer;
    sdClearChannels = function : integer;
    sdMute = function(mute : integer) : integer;
    sdPause = function(pause : integer) : integer;
    sdSetMasterVolume = function(masterVolume : byte) : integer;
    sdPlaySound = function(channel : word; rate : longint) : integer;
    sdStopSound = function(channel : word) : integer;
    sdSetRate = function(channel : word; rate : longint) : integer;
    sdGetRate = function(channel : word; rate : Plongint) : integer;
    sdSetVolume = function(channel : word; volume : byte) : integer;
    sdSetInstrument = function(channel : word; inst : word) : integer;
    sdSetPosition = function(channel : word; pos : word) : integer;
    sdGetPosition = function(channel : word; pos : Pword) : integer;
    sdSetPanning = function(channel : word; panning : integer) : integer;
    sdGetPanning = function(channel : word; panning : Pinteger) : integer;
    sdMuteChannel = function(channel : word; mute : integer) : integer;
    sdAddInstrument = function(sample : pointer; smpType : integer;
        length, loopStart, loopEnd : word; volume : byte; loop : integer;
        instHandle : Pword) : integer;
    sdRemInstrument = function(inst : word) : integer;
    sdSetUpdRate = function(updRate : word) : integer;
    sdPlay = function(callMP : Pinteger) : integer;


    { actual Sound Device structure: }

    SoundDevice = Record
        tempoPoll : word;               { poll to tempo? }
        ioPort : word;                  { I/O port number }
        IRQ : byte;                     { IRQ number }
        DMA : byte;                     { DMA channel number }
        status : word;                  { Sound Device status }
        modes : word;                   { Possible output modes, bitfield.
                                          See enum sdModes. }
        ID : ^char;                     { Pointer to Sound Device ID string,
                                          ASCIIZ }

        Detect : sdDetect;
        Init : sdInit;
        Close : sdClose;
        GetMixRate : sdGetMixRate;
        GetMode : sdGetMode;
        OpenChannels : sdOpenChannels;
        CloseChannels : sdCloseChannels;
        ClearChannels : sdClearChannels;
        Mute : sdMute;
        Pause : sdPause;
        SetMasterVolume : sdSetMasterVolume;
        PlaySound : sdPlaySound;
        StopSound : sdStopSound;
        SetRate : sdSetRate;
        GetRate : sdGetRate;
        SetVolume : sdSetVolume;
        SetInstrument : sdSetInstrument;
        SetPosition : sdSetPosition;
        GetPosition : sdGetPosition;
        SetPanning : sdSetPanning;
        GetPanning : sdGetPanning;
        MuteChannel : sdMuteChannel;
        AddInstrument : sdAddInstrument;
        RemInstrument : sdRemInstrument;
        SetUpdRate : sdSetUpdRate;
        Play : sdPlay;
    end;

    PSoundDevice = ^SoundDevice;



{ Sound Device structures: }

procedure GUS;                          { Gravis UltraSound Sound Device }
procedure PAS;                          { Pro Audio Spectrum series SD }
procedure WSS;                          { Windows Sound System SD }
procedure SB;                           { Sound Blaster series SD }
procedure NSND;                         { No Sound Sound Device }



implementation


USES  Errors, mGlobals, mMem, DMA, DSM;


procedure GUS; external;
{$L GUS.OBJ}
procedure PAS; external;
{$L PAS.OBJ}
procedure WSS; external;
{$L WSS.OBJ}
procedure SB; external;
{$L SB.OBJ}
procedure NSND; external;
{$L NSND.OBJ}


END.
