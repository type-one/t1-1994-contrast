{*      MIDAS.PAS
 *
 * Simple MIDAS Sound System interface unit
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*}


unit MIDAS;


interface




{****************************************************************************\
*      MIDAS global variables:
\****************************************************************************}

const
    NUMSDEVICES = 5;                    { total number of Sound Devices }
    NUMMPLAYERS = 2;                    { total number of Module Players }

var
    SDptr : pointer;                    { pointer to current Sound Device }
    MPptr : pointer;                    { pointer to current Module Player }



{****************************************************************************\
*
* Function:     midasError(msg : string);
*
* Description:  Prints a MIDAS error message to stderr and exits to DOS
*
* Input:        msg : string            Pointer to error message string
*
\****************************************************************************}

procedure midasError(msg : string);




{****************************************************************************\
*
* Function:     midasUninitError(msg : string);
*
* Description:  Prints an error message to stderr and exits to DOS without
*               uninitializing MIDAS. This function should only be used
*               from midasClose();
*
* Input:        msg : string            Pointer to error message string
*
\****************************************************************************}

procedure midasUninitError(msg : string);



{****************************************************************************\
*
* Function:     midasDetectSD;
*
* Description:  Attempts to detect a Sound Device. Sets the global variable
*               SDptr to point to the detected Sound Device or NIL if no
*               Sound Device was detected
*
\****************************************************************************}

procedure midasDetectSD;



{****************************************************************************\
*
* Function:     midasInit;
*
* Description:  Initializes MIDAS Sound System
*
\****************************************************************************}

procedure midasInit;



{****************************************************************************\
*
* Function:     midasClose;
*
* Description:  Uninitializes MIDAS Sound System
*
\****************************************************************************}

procedure midasClose;



{****************************************************************************\
*
* Function:     midasSetDefaults;
*
* Description:  Initializes MIDAS Sound System variables to their default
*               states. MUST be the first MIDAS function to be called.
*
\****************************************************************************}

procedure midasSetDefaults;



{****************************************************************************\
*
* Function:     midasParseOption(option : string);
*
* Description:  Parses one MIDAS command line option.
*
* Input:        option : string         Command line option string WITHOUT
*                                       the leading '-' or '/'.
*
* Recognized options:
*       -sx     Force Sound Device x (1 = GUS, 2 = PAS, 3 = WSS, 4 = SB,
*               5 = No Sound)
*       -pxxx   Force I/O port xxx (hex) for Sound Device
*       -ix     Force IRQ x for Sound Device
*       -dx     Force DMA channel x for Sound Device
*       -mxxxx  Set mixing rate to xxxx Hz
*       -oxxx   Force output mode (8 = 8-bit, 1 = 16-bit, s = stereo,
*               m = mono)
*       -e      Disable EMS usage
*       -t      Disable ProTracker BPM tempos
*       -u      Enable Surround sound
*       -v      Disable real VU-meters
*
\****************************************************************************}

procedure midasParseOption(option : string);



{****************************************************************************\
*
* Function:     midasParseOptions(firstOpt, numOpts : integer);
*
* Description:  Parses MIDAS command line options and sets MIDAS variables
*               accordingly.
*
* Input:        firstOpt : integer      first ParamStr() to parse.
*               numOpts : integer       number of ParamStr() options to parse
*
* Also '/' is recognized as a option delimiter.
*
\****************************************************************************}

procedure midasParseOptions(firstOpt, numOpts : integer);



{****************************************************************************\
*
* Function:     void midasParseEnvironment;
*
* Description:  Parses the MIDAS environment string, which has same format
*               as the command line options.
*
\****************************************************************************}

procedure midasParseEnvironment;



{****************************************************************************\
*
* Function:     midasPlayModule(fileName : string; numEffectChns : integer) :
*                   pointer;
*
* Description:  Loads a module into memory, points MP to the correct Module
*               Player and starts playing it.
*
* Input:        fileName : string       Module file name
*               numEffectChns : integer Number of channels to open for sound
*                                       effects.
*
* Returns:      Pointer to module structure. This function can not fail,
*               as it will call midasError() to handle all error cases.
*
* Notes:        The Sound Device channels available for sound effects are the
*               _first_ numEffectChns channels. So, for example, if you use
*               midasPlayModule('TUNE.MOD', 3), you can use channels 0-2 for
*               sound effects.
*
\****************************************************************************}

function midasPlayModule(fileName : string; numEffectChns : integer) :
    pointer;



{****************************************************************************\
*
* Function:     midasStopModule(module : pointer);
*
* Description:  Stops playing a module, deallocates it and uninitializes
*               the Module Player. Also closes _all_ Sound Device channels,
*               including those opened for effects.
*
\****************************************************************************}

procedure midasStopModule(module : pointer);



{****************************************************************************\
*
* Function:     toASCIIZ(str : string) : pointer;
*
* Description:  Converts a string to ASCIIZ format, that can be used with the
*               file functions and module loaders. Uses the buffer
*               "asczBuffer" that has to be allocated beforehand.
*
* Input:        msg : string            string to be converted
*
* Returns:      Pointer to converted ASCIIZ string
*
\****************************************************************************}

function toASCIIZ(str : string) : pointer;




implementation


uses crt, dos, Errors, mGlobals, mMem, mFile, EMS, SDevice, MPlayer, S3M,
    MODP, Timer
{$IFDEF REALVUMETERS}
    ,VU
{$ENDIF}
    ;


type
    charArray = array[0..255] of char;
    PcharArray = ^charArray;


{****************************************************************************\
*      Static variables used by midasXXXX() functions:
\****************************************************************************}

const
    { pointers to all Sound Devices: }
    midasSoundDevices : array[0..(NUMSDEVICES-1)] of PSoundDevice = (
        @GUS, @PAS, @WSS, @SB, @NSND );

    { pointers to all Module Players: }
    midasModulePlayers : array[0..(NUMMPLAYERS-1)] of PModulePlayer = (
        @mpS3M, @mpMOD );

    { Amiga Loop Emulation flags for Module Players: }
    midasMPALE : array[0..(NUMMPLAYERS-1)] of integer = (
        0, 1 );



var
    disableEMS : boolean;               { should EMS usage be disabled? }
    sdNum : word;                       { Sound Device number ($FFFF for
                                          autodetect) }
    ioPort : word;                      { I/O port number ($FFFF for
                                          autodetect/default) }
    IRQ : byte;                         { IRQ number ($FF for autodetect/
                                          default) }
    DMA : byte;                         { DMA channel number ($FF for
                                          autodetect/default) }
    mixRate : word;                     { mixing rate }
    mode : word;                        { forced output mode }

    emsInitialized : boolean;           { is EMS heap manager initialized? }
    tmrInitialized : boolean;           { is TempoTimer initialized? }
    sdInitialized : boolean;            { is Sound Device initialized? }
    sdChOpen : boolean;                 { are Sound Device channels open? }
    vuInitialized : boolean;            { are real VU-meters initialized? }
    mpInit : boolean;                   { is Module Player initialized? }
    mpPlay : boolean;                   { is Module Player playing? }
    mpInterrupt : boolean;              { is Module Player interrupt set? }

    SD : PSoundDevice;                  { current Sound Device }
    MP : PModulePlayer;                 { current Module Player }

    asczBuffer : PcharArray;            { ASCIIZ conversion buffer }





{****************************************************************************\
*
* Function:     midasError(msg : string);
*
* Description:  Prints a MIDAS error message to stderr and exits to DOS
*
* Input:        msg : string            Pointer to error message string
*
\****************************************************************************}

procedure midasError(msg : string);
begin
    TextMode(CO80);
    WriteLn('MIDAS Error: ', msg);
{$IFDEF DEBUG}
    errPrintList;                       { print error list }
{$ENDIF}
    midasClose;
    Halt;
end;




{****************************************************************************\
*
* Function:     midasUninitError(msg : string);
*
* Description:  Prints an error message to stderr and exits to DOS without
*               uninitializing MIDAS. This function should only be used
*               from midasClose();
*
* Input:        msg : string            Pointer to error message string
*
\****************************************************************************}

procedure midasUninitError(msg : string);
begin
    TextMode(CO80);
    WriteLn('FATAL: MIDAS uninitialization error: ', msg);
{$IFDEF DEBUG}
    errPrintList;                       { print error list }
{$ENDIF}
    Halt;
end;




{****************************************************************************\
*
* Function:     toASCIIZ(str : string) : pointer;
*
* Description:  Converts a string to ASCIIZ format, that can be used with the
*               file functions and module loaders. Uses the buffer
*               "asczBuffer" that has to be allocated beforehand.
*
* Input:        msg : string            string to be converted
*
* Returns:      Pointer to converted ASCIIZ string
*
\****************************************************************************}

function toASCIIZ(str : string) : pointer;
var
    spos, slen : integer;
    i : integer;

begin
    spos := 0;                          { string position = 0 }
    slen := ord(str[0]);                { string length }

    { copy string to ASCIIZ conversion buffer: }
    while spos < slen do
    begin
        asczBuffer^[spos] := str[spos+1];       { copy a character }
        spos := spos + 1;                       { next character }
    end;

    asczBuffer^[spos] := chr(0);        { put terminating 0 to end of string }

    toASCIIZ := asczBuffer;             { return pointer to string }
end;




{****************************************************************************\
*
* Function:     midasDetectSD;
*
* Description:  Attempts to detect a Sound Device. Sets the global variable
*               SDptr to point to the detected Sound Device or NIL if no
*               Sound Device was detected
*
\****************************************************************************}

procedure midasDetectSD;
var
    dsd, dResult, error : integer;
    sdev : PSoundDevice;
begin
    SD := NIL;                          { no Sound Device detected yet }
    SDptr := NIL;
    dsd := 0;                           { start from first Sound Device }

    { search through Sound Devices until a Sound Device is detected: }
    while (SD = NIL) and (dsd < NUMSDEVICES) do
    begin
        { attempt to detect current SD: }
        sdev := midasSoundDevices[dsd];
        error := sdev^.Detect(@dResult);
        if error <> OK then
            midasError(errorMsg[error]);
        if dResult = 1 then
        begin
            sdNum := dsd;               { Sound Device detected }
            SD := sdev;                 { point SD to this Sound Device }
            SDptr := sdev;
        end;
        dsd := dsd + 1;                 { try next Sound Device }
    end;
end;




{****************************************************************************\
*
* Function:     midasInit;
*
* Description:  Initializes MIDAS Sound System
*
\****************************************************************************}

procedure midasInit;
var
    error, result : integer;
begin
    { Allocate memory for ASCIIZ conversion buffer: }
    error := memAlloc(256, @asczBuffer);
    if error <> OK then
        midasError(errorMsg[error]);

    if not disableEMS then              { is EMS usage disabled? }
    begin
        { Initialize EMS Heap Manager: }
        error := emsInit(@result);
        if error <> OK then
            midasError(errorMsg[error]);

        { was EMS Heap Manager initialized? }
        if result = 1 then
        begin
            emsInitialized := True;
            useEMS := 1;                { yes, use EMS memory, but do not }
            forceEMS := 0;              { force its usage }
        end
        else
        begin
            emsInitialized := False;
            useEMS := 0;                { no, do not use EMS memory }
            forceEMS := 0;
        end;
    end
    else
    begin
        emsInitialized := False;
        useEMS := 0;                    { EMS disabled - do not use it }
        forceEMS := 0;
    end;

    if sdNum = $FFFF then               { has a Sound Device been selected? }
    begin
        midasDetectSD;                  { attempt to detect Sound Device }
        if SD = NIL then
            midasError('Unable to detect Sound Device');
    end
    else
    begin
        SDptr := midasSoundDevices[sdNum];  { use Sound Device sdNum }
        SD := SDptr;

        { Sound Device number was forced, but if no I/O port, IRQ or DMA
          number has been set, try to autodetect the values for this Sound
          Device. If detection fails, use default values }

        if (ioPort = $FFFF) and (IRQ = $FF) and (DMA = $FF) then
        begin
            error := SD^.Detect(@result);
            if error <> OK then
                midasError(errorMsg[error]);
            if result <> 1 then
                midasError('Unable to detect Sound Device values');
        end;
    end;

    if ioPort <> $FFFF then             { has an I/O port been set? }
        SD^.ioPort := ioPort;           { if yes, set it to Sound Device }
    if IRQ <> $FF then                  { what about IRQ number? }
        SD^.IRQ := IRQ;
    if DMA <> $FF then                  { or DMA channel number }
        SD^.DMA := DMA;

{$IFNDEF NOTIMER}
    { initialize TempoTimer: }
    error := tmrInit;
    if error <> OK then
        midasError(errorMsg[error]);
    tmrInitialized := True;             { TempoTimer initialized }
{$ENDIF}

    { initialize Sound Device: }
    error := SD^.Init(mixRate, mode);
    if error <> OK then
        midasError(errorMsg[error]);
    sdInitialized := True;              { Sound Device initialized }

{$IFDEF REALVUMETERS}
    if realVU = 1 then
    begin
        { initialize real VU-meters: }
        error := vuInit;
        if error <> OK then
            midasError(errorMsg[error]);
        vuInitialized := True;
    end;
{$ENDIF}
end;



{****************************************************************************\
*
* Function:     midasClose;
*
* Description:  Uninitializes MIDAS Sound System
*
\****************************************************************************}

procedure midasClose;
var
    error : integer;
begin
    { Deallocate ASCIIZ convesion buffer if allocated: }
    if asczBuffer <> NIL then
    begin
        error := memFree(asczBuffer);
        if error <> OK then
            midasError(errorMsg[error]);
    end;
    asczBuffer := NIL;

{$IFNDEF NOTIMER}
    { if Module Player interrupt is running, remove it: }
    if mpInterrupt then
    begin
        error := MP^.RemoveInterrupt;
        if error <> OK then
            midasUninitError(errorMsg[error]);
        mpInterrupt := False;
    end;
{$ENDIF}

    { if Module Player is playing, stop it: }
    if mpPlay then
    begin
        error := MP^.StopModule;
        if error <> OK then
            midasUninitError(errorMsg[error]);
        mpPlay := False;
    end;

    { if Module Player has been initialized, uninitialize it: }
    if mpInit then
    begin
        error := MP^.Close;
        if error <> OK then
            midasUninitError(errorMsg[error]);
        mpInit := False;
        MP := NIL;
        MPptr := NIL;
    end;

{$IFDEF REALVUMETERS}
    { if real VU-meters have been initialized, uninitialize them: }
    if vuInitialized then
    begin
        error := vuClose;
        if error <> OK then
            midasUninitError(errorMsg[error]);
        vuInitialized := False;
    end;
{$ENDIF}

    { if Sound Device channels are open, close them: }
    if sdChOpen then
    begin
        error := SD^.CloseChannels;
        if error <> OK then
            midasUninitError(errorMsg[error]);
        sdChOpen := False;
    end;

    { if Sound Device is initialized, uninitialize it: }
    if sdInitialized then
    begin
        error := SD^.Close;
        if error <> OK then
            midasUninitError(errorMsg[error]);
        sdInitialized := False;
        SD := NIL;
        SDptr := NIL;
    end;

{$IFNDEF NOTIMER}
    { if TempoTimer is initialized, uninitialize it: }
    if tmrInitialized then
    begin
        error := tmrClose;
        if error <> OK then
            midasUninitError(errorMsg[error]);
        tmrInitialized := False;
    end;
{$ENDIF}

    { if EMS Heap Manager is initialized, uninitialize it: }
    if emsInitialized then
    begin
        error := emsClose;
        if error <> OK then
            midasUninitError(errorMsg[error]);
        emsInitialized := False;
    end;
end;




{****************************************************************************\
*
* Function:     midasSetDefaults;
*
* Description:  Initializes MIDAS Sound System variables to their default
*               states. MUST be the first MIDAS function to be called.
*
\****************************************************************************}

procedure midasSetDefaults;
begin
    asczBuffer := NIL;                  { ASCIIZ conversion buffer not
                                          allocated }
    emsInitialized := False;            { EMS heap manager is not
                                          initialized yet }
    tmrInitialized := False;            { TempoTimer is not initialized }
    sdInitialized := False;             { Sound Device is not initialized }
    sdChOpen := False;                  { Sound Device channels are not
                                          open }
    vuInitialized := False;             { VU meter are not initialized }
    mpInit := False;                    { Module Player is not initialized }
    mpPlay := False;                    { Module Player is not playing }
    mpInterrupt := False;               { No Module Player interrupt }

    ptTempo := 1;                       { enable ProTracker BPM tempos }
    usePanning := 1;                    { enable ProTracker panning cmds }
    surround := 0;                      { disable surround to save GUS mem }
    realVU := 1;                        { enable real VU-meters }

    disableEMS := False;                { do not disable EMS usage }
    sdNum := $FFFF;                     { no Sound Device forced }
    ioPort := $FFFF;                    { no I/O port forced }
    IRQ := $FF;                         { no IRQ number forced }
    DMA := $FF;                         { no DMA channel number forced }
    mode := 0;                          { no output mode forced }
    mixRate := 44100;                   { attempt to use 44100Hz mixing
                                          rate }

    SD := NIL;                          { point SD and MP to NULL for }
    SDptr := NIL;                       { safety }
    MP := NIL;
    MPptr := NIL;
end;



{****************************************************************************\
*
* Function:     midasParseOption(option : string);
*
* Description:  Parses one MIDAS command line option.
*
* Input:        option : string         Command line option string WITHOUT
*                                       the leading '-' or '/'.
*
* Recognized options:
*       -sx     Force Sound Device x (1 = GUS, 2 = PAS, 3 = WSS, 4 = SB,
*               5 = No Sound)
*       -pxxx   Force I/O port xxx (hex) for Sound Device
*       -ix     Force IRQ x for Sound Device
*       -dx     Force DMA channel x for Sound Device
*       -mxxxx  Set mixing rate to xxxx Hz
*       -oxxx   Force output mode (8 = 8-bit, 1 = 16-bit, s = stereo,
*               m = mono)
*       -e      Disable EMS usage
*       -t      Disable ProTracker BPM tempos
*       -u      Enable Surround sound
*       -v      Disable real VU-meters
*
\****************************************************************************}

procedure midasParseOption(option : string);
var
    c : integer;
    opt : string;

    { hex2word - converts a hexadecimal string to a word }
    function hex2word(hstr : string) : word;
    var
        c : char;
        digit : integer;
        res, w, mult : word;

    begin
        mult := 1;
        res := 0;

        for digit := ord(hstr[0]) downto 1 do
        begin
            c := UpCase(hstr[digit]);
            if (c >= '0') and (c <= '9') then
                w := (ord(c) - ord('0')) * mult
            else
                w := (ord(c) - ord('A')) * mult;
            res := res + w;
            mult := mult shl 4;
        end;
        hex2word := res;
    end;

    { atol - converts a string into a longint, returns 0 if conversion
      failure, like the C atol() function }
    function atol(s : string) : longint;
    var
        i : longint;
        code : integer;
    begin
        val(s, i, code);
        if code <> 0 then
            atol := 0
        else
            atol := i;
    end;


begin
    opt := copy(option, 2, ord(option[0]) - 1);

    case option[1] of
        { -sx     Force Sound Device x }
        's':
            begin
                sdNum := atol(opt) - 1;
                if (sdNum >= NUMSDEVICES) or (sdNum < 0) then
                    midasError('Illegal Sound Device');
            end;

        { -pxxx   Force I/O port xxx (hex) for Sound Device }
        'p':
            ioPort := hex2word(opt);

        { -ix     Force IRQ x for Sound Device }
        'i':
            IRQ := atol(opt);

        { -dx     Force DMA channel x for Sound Device }
        'd':
            DMA := atol(opt);

        { -mxxxx  Set mixing rate to xxxx Hz }
        'm':
            mixRate := atol(opt);

        { -e      Disable EMS usage }
        'e':
            disableEMS := True;

        { -t      Disable ProTracker BPM tempos }
        't':
            ptTempo := 0;

        { -u      Enable Surround sound }
        'u':
            surround := 1;

        { -oxxx   Force output mode }
        'o':
            begin
                for c:= 1 to ord(opt[0]) do
                begin
                    case opt[c] of
                        { Output mode '8' - 8-bit }
                        '8':
                            mode := (mode or sd8bit) and (not sd16bit);

                        { Output mode '1' - 16-bit }
                        '1':
                            mode := (mode or sd16bit) and (not sd8bit);

                        { Output mode 'm' - mono }
                        'm':
                            mode := (mode or sdMono) and (not sdStereo);

                        { Output mode 's' - stereo }
                        's':
                            mode := (mode or sdStereo) and (not sdMono);

                        else
                            midasError('Invalid output mode character');
                    end;
                end;
            end;

        { -v      Disable real VU-meters }
        'v':
            realVU := 0;

        else
            midasError('Unknown option character');
    end;
end;




{****************************************************************************\
*
* Function:     midasParseOptions(firstOpt, numOpts : integer);
*
* Description:  Parses MIDAS command line options and sets MIDAS variables
*               accordingly.
*
* Input:        firstOpt : integer      first ParamStr() to parse.
*               numOpts : integer       number of ParamStr() options to parse
*
* Also '/' is recognized as a option delimiter.
*
\****************************************************************************}

procedure midasParseOptions(firstOpt, numOpts : integer);
var
    i : word;
    s : string;
begin
    if numOpts > 0 then
    begin
        for i := firstOpt to (firstOpt+numOpts-1) do
        begin
            s := ParamStr(i);
            if (s[1] = '-') or (s[1] = '/') then
                midasParseOption(copy(s, 2, ord(s[0])-1))
            else
                midasError('Invalid command line option');
        end;
    end;
end;




{***************************************************************************\
*
* Function:     midasParseEnvironment;
*
* Description:  Parses the MIDAS environment string, which has same format
*               as the command line options.
\***************************************************************************}

procedure midasParseEnvironment;
var
    midasEnv, opt : string;
    spos, slen : integer;
    stopParse : boolean;
    ch : char;

begin
    { try to get MIDAS environment string: }
    midasEnv := GetEnv('MIDAS');

    if midasEnv <> '' then
    begin
        spos := 1;                      { search position = 0 }
        slen := ord(midasEnv[0]);
        opt := '';                      { current option string is empty }
        stopParse := False;

        { parse the whole environment string: }
        while not stopParse do
        begin
            ch := midasEnv[spos];

            if spos > slen then
            begin
                { Current character is past the last character of environment
                  string. Parse option string if it exists and stop
                  parsing. }
                if opt <> '' then
                    midasParseOption(opt);
                stopParse := True;
            end
            else
            begin
                if ch = ' ' then
                begin
                    { current character is space - parse current option
                      string if it exists }
                    if opt <> '' then
                        midasParseOption(opt);

                    opt := '';          { no option string }
                    spos := spos + 1;   { next character }
                end
                else
                begin
                    if (ch = '-') or (ch = '/') then
                    begin
                        { Current character is '-' or '/' - option string
                          starts from next character }
                        spos := spos + 1;
                        opt := midasEnv[spos];
                        spos := spos + 1;
                    end
                    else
                    begin
                        { some normal charater - add to the end of option
                          string if it exists, otherwise just continue
                          parsing }
                        if opt <> '' then
                            opt := opt + ch;
                        spos := spos + 1;
                    end;
                end;
            end;
        end;
    end;
end;




{****************************************************************************\
*
* Function:     midasPlayModule(fileName : string; numEffectChns : integer) :
*                   pointer;
*
* Description:  Loads a module into memory, points MP to the correct Module
*               Player and starts playing it.
*
* Input:        fileName : string       Module file name
*               numEffectChns : integer Number of channels to open for sound
*                                       effects.
*
* Returns:      Pointer to module structure. This function can not fail,
*               as it will call midasError() to handle all error cases.
*
* Notes:        The Sound Device channels available for sound effects are the
*               _first_ numEffectChns channels. So, for example, if you use
*               midasPlayModule('TUNE.MOD', 3), you can use channels 0-2 for
*               sound effects.
*
\****************************************************************************}

function midasPlayModule(fileName : string; numEffectChns : integer) :
    pointer;
var
    header : ^byte;
    f : fileHandle;
    module : PmpModule;
    numChans, numRead : word;
    error, mpNum, recognized : integer;
    mpl : PModulePlayer;

begin
    error := memAlloc(MPHDRSIZE, @header);
    if error <> OK then
        midasError(errorMsg[error]);

    { open module file: }
    error := fileOpen(toASCIIZ(fileName), fileOpenRead, @f);
    if error <> OK then
        midasError(errorMsg[error]);

    { read MPHDRSIZE bytes of module header: }
    error := fileRead(f, header, MPHDRSIZE);
    if error <> OK then
        midasError(errorMsg[error]);

    { close module file: }
    error := fileClose(f);
    if error <> OK then
        midasError(errorMsg[error]);


    { Search through all Module Players to find one that recognizes
      file header: }
    mpNum := 0;
    MP := NIL;
    MPptr := NIL;

    while (mpNum < NUMMPLAYERS) and (MP = NIL) do
    begin
        mpl := midasModulePlayers[mpNum];
        error := mpl^.Identify(header, @recognized);
        if error <> OK then
            midasError(errorMsg[error]);
        if recognized = 1 then
        begin
            MP := mpl;
            MPptr := mpl;
            ALE := midasMPAle[mpNum];
        end;
        mpNum := mpNum + 1;
    end;

    if MP = NIL then
        midasError('Unknown module format');

    { deallocate module header: }
    error := memFree(header);
    if error <> OK then
        midasError(errorMsg[error]);

    { initialize module player: }
    error := MP^.Init(SD);
    if error <> OK then
        midasError(errorMsg[error]);
    mpInit := True;

    { load module: }
    error := MP^.LoadModule(toASCIIZ(fileName), SD, @module);
    if error <> OK then
        midasError(errorMsg[error]);

    numChans := module^.numChans;

    { open Sound Device channels: }
    error := SD^.OpenChannels(numChans + numEffectChns);
    if error <> OK then
        midasError(errorMsg[error]);
    sdChOpen := True;

    { Start playing the module using Sound Device channels (numEffectChns) -
      (numEffectChns+numChans-1) and looping the whole song: }
    error := MP^.PlayModule(module, numEffectChns, numChans, 0, 32767);
    if error <> OK then
        midasError(errorMsg[error]);
    mpPlay := True;

{$IFNDEF NOTIMER}
    { start playing using the timer: }
    error := MP^.SetInterrupt;
    if error <> OK then
        midasError(errorMsg[error]);
{$ENDIF}

    midasPlayModule := module;
end;




{****************************************************************************\
*
* Function:     midasStopModule(module : pointer);
*
* Description:  Stops playing a module, deallocates it and uninitializes
*               the Module Player. Also closes _all_ Sound Device channels,
*               including those opened for effects.
*
\****************************************************************************}

procedure midasStopModule(module : pointer);
var
    error : integer;
begin
{$IFNDEF NOTIMER}
    { remove Module Player interrupt: }
    error := MP^.RemoveInterrupt;
    if error <> OK then
        midasError(errorMsg[error]);
    mpInterrupt := False;
{$ENDIF}

    { stop playing the module: }
    error := MP^.StopModule;
    if error <> OK then
        midasError(errorMsg[error]);
    mpPlay := False;

    { deallocate module: }
    error := MP^.FreeModule(module, SD);
    if error <> OK then
        midasError(errorMsg[error]);

    { uninitialize Module Player: }
    error := MP^.Close;
    if error <> OK then
        midasError(errorMsg[error]);
    mpInit := False;
    MP := NIL;                          { point MP to NIL for safety }
    MPptr := NIL;

    { close Sound Device channels: }
    error := SD^.CloseChannels;
    if error <> OK then
        midasError(errorMsg[error]);
    sdChOpen := False;
end;



END.
