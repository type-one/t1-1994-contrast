{*      ERRORS.PAS
 *
 * MIDAS Sound System error codes and error message strings
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*}


unit Errors;


interface


const
    MAXERRORS = 256;                    { maximum number of errors to store }



{****************************************************************************\
*       enum ErrorCodes
*       ---------------
* Description:  MIDAS Sound System error codes
\****************************************************************************}

const
    OK = 0;                             { no error }
    errUndefined = 01;                  { undefined error }
    errOutOfMemory = 02;                { out of (conventional) memory }
    errHeapCorrupted = 03;              { (conventional memory) heap
                                           corrupted }
    errInvalidBlock = 04;               { invalid memory block }
    errOutOfEMS = 05;                   { out of EMS memory }
    errEMSHeapCorrupted = 06;           { EMS heap corrupted }
    errInvalidEMSBlock = 07;            { invalid EMS memory block }
    errEMMFailure = 08;                 { Expanded Memory Manager failure }
    errOutOfCardMemory = 09;            { out of soundcard memory }
    errCardHeapCorrupted = 10;          { soundcard heap corrupted }
    errInvalidCardBlock = 11;           { invalid soundcard memory block }
    errNoInstHandles = 12;              { out of instrument handles }
    errFileOpen = 13;                   { unable to open file }
    errFileRead = 14;                   { unable to read file }
    errInvalidModule = 15;              { invalid module file }
    errInvalidInst = 16;                { invalid instrument in module }
    errInvalidPatt = 17;                { invalid pattern data in module }
    errInvalidChanNumber = 18;          { invalid channel number }
    errInvalidInstHandle = 19;          { invalid instrument handle }
    errNoChannels = 20;                 { Sound Device channels not open }
    errSDFailure = 21;                  { Sound Device hardware failure }
    errInvalidArguments = 22;           { invalid function arguments }
    errFileNotFound = 23;               { file not found }
    errInvalidFileHandle = 24;          { invalid file handle }
    errAccessDenied = 25;               { access denied }
    errFileExists = 26;                 { file exists }
    errTooManyFiles = 27;               { too many open files }
    errDiskFull = 28;                   { disk full }
    errEndOfFile = 29;                  { unexpected end of file }
    errInvalidPath = 30;                { invalid path }
    errFileWrite = 31;                  { unable to write file }





{****************************************************************************\
*       enum FunctionIDs
*       ----------------
* Description:  ID numbers for first functions in all modules
\****************************************************************************}

    ID_error = 0;                       { error handling }
    ID_dma = 100;                       { DMA handling routines }
    ID_dsm = 200;                       { Digital Sound Mixer }
    ID_ems = 300;                       { EMS heap manager }
    ID_mem = 400;                       { Conventional memory management }
    ID_mod = 500;                       { Protracker Module Player }
    ID_s3m = 600;                       { Scream Tracker 3 Module Player }
    ID_tmr = 700;                       { TempoTimer }
    ID_vu = 800;                        { Real VU meters }
    ID_rf = 900;                        { Raw file I/O }
    ID_file = 1000;                     { High-level file I/O }
    ID_gus = 2000;                      { GUS Sound Device }
    ID_pas = 2100;                      { PAS Sound Device }
    ID_wss = 2200;                      { WSS Sound Device }
    ID_sb = 2300;                       { SB Sound Device }
    ID_nsnd = 2900;                     { No Sound Sound Device }



{****************************************************************************\
*       Error message strings:
\****************************************************************************}

const
    errorMsg : array[0..31] of string = (
        'OK',
        'Undefined error',
        'Out of conventional memory',
        'Conventional memory heap corrupted',
        'Invalid conventional memory block',
        'Out of EMS memory',
        'EMS memory heap corrupted',
        'Invalid EMS memory block',
        'Expanded Memory Manager failure',
        'Out of soundcard memory',
        'Soundcard memory heap corrupted',
        'Invalid soundcard memory block',
        'Out of instrument handles',
        'Unable to open file',
        'Unable to read file',
        'Invalid module file',
        'Invalid instrument in module',
        'Invalid pattern data in module',
        'Invalid channel number',
        'Invalid instrument handle',
        'Sound Device channels not open',
        'Sound Device hardware failure',
        'Invalid function arguments',
        'File does not exist',
        'Invalid file handle',
        'Access denied',
        'File exists',
        'Too many open files',
        'Disk full',
        'Unexpected end of file',
        'Invalid path',
        'Unable to write file' );



{$IFDEF DEBUG}

{****************************************************************************\
*       struct errRecord
*       ----------------
* Description:  Error record for error list
\****************************************************************************}

type
    errRecord = Record
        errorCode : integer;            { error code number }
        functID : word;                 { ID for function that caused the
                                          error }
    end;



{****************************************************************************\
*
* Function:     errAdd(errorCode : integer; functID : word);
*
* Description:  Add an error to error list
*
* Input:        errorCode : integer     error code
*               functID : word          ID for function that caused the error
*
\****************************************************************************}

procedure errAdd(errorCode : integer; functID : word);



{****************************************************************************\
*
* Function:     errPrintList;
*
* Description:  Prints the error list to stderr
*
\****************************************************************************}

procedure errPrintList;


{$ENDIF}



{****************************************************************************\
*
* Function:     mError(errCode : integer; functID : word);
*
* Description:  Adds an error to the MIDAS error list if DEBUG is defined.
*               Does nothing otherwise
*
* Input:        errCode : integer       error code
*               functID : word          ID for function that caused the error
*
\****************************************************************************}

procedure mError(errCode : integer; functID : word);




implementation



{$IFDEF DEBUG}

var
    errorList : array[0..MAXERRORS-1] of errRecord;     { error list }
    numErrors : word;                   { number of errors in list }


{****************************************************************************\
*
* Function:     errAdd(errorCode : integer; functID : word);
*
* Description:  Add an error to error list
*
* Input:        errorCode : integer     error code
*               functID : word          ID for function that caused the error
*
\****************************************************************************}

procedure errAdd(errorCode : integer; functID : word);
begin
    { make sure that error list does not overflow }
    if numErrors <= MAXERRORS then
    begin
        { store error information to list: }
        errorList[numErrors].errorCode := errorCode;
        errorList[numErrors].functID := functID;
        numErrors := numErrors + 1;
    end;
end;



{****************************************************************************\
*
* Function:     errPrintList;
*
* Description:  Prints the error list to stderr
*
\****************************************************************************}

procedure errPrintList;
var
    i : word;
begin
    WriteLn('MIDAS error list:');

    if numErrors > 0 then
    begin
        for i := 0 to (numErrors-1) do
        begin
            WriteLn(i, ': <',errorList[i].errorCode, ', ', errorList[i].functID,
                '> - ', errorMsg[errorList[i].errorCode], ' at ',
                errorList[i].functID);
        end;
    end;
end;


{$ENDIF}



{****************************************************************************\
*
* Function:     mError(errCode : integer; functID : word);
*
* Description:  Adds an error to the MIDAS error list if DEBUG is defined.
*               Does nothing otherwise
*
* Input:        errCode : integer       error code
*               functID : word          ID for function that caused the error
*
\****************************************************************************}

procedure mError(errCode : integer; functID : word);
begin
{$IFDEF DEBUG}
    errAdd(errCode, functID);
{$ENDIF}
end;





BEGIN
{$IFDEF DEBUG}
    numErrors := 0;
{$ENDIF}
END.
