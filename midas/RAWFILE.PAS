{*      RAWFILE.H
 *
 * Raw file I/O for MIDAS Sound System
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*}


unit rawFile;


interface


{****************************************************************************\
*       struct rfFile
*       -------------
* Description:  File state structure
\****************************************************************************}

type
    rfFile = Record
        handle : word;
    end;



{****************************************************************************\
*       typedef rfHandle;
*       -----------------
* Description: Raw file I/O file handle
\****************************************************************************}

type
    rfHandle = ^rfFile;
    PrfHandle = ^rfHandle;



{****************************************************************************\
*       enum rfOpenMode
*       ---------------
* Description:  File opening mode. Used by rfOpen()
\****************************************************************************}

const
    rfOpenRead = 1;                     { open file for reading }
    rfOpenWrite = 2;                    { open file for writing }
    rfOpenReadWrite = 3;                { open file for both reading and
                                          writing }



{****************************************************************************\
*       enum rfSeekMode
*       ---------------
* Description:  File seeking mode. Used by rfSeek()
\****************************************************************************}

const
    rfSeekAbsolute = 1;                 { seek to an absolute position from
                                          the beginning of the file }
    rfSeekRelative = 2;                 { seek to a position relative to
                                          current position }
    rfSeekEnd = 3;                      { seek relative to the end of file }


type
    Pchar = ^char;
    Plongint = ^longint;


{****************************************************************************\
*
* Function:     rfOpen(fileName : Pchar; openMode : integer;
*                   fileh : PrfHandle) : integer;
*
* Description:  Opens a file for reading or writing
*
* Input:        fileName : Pchar        pointer to name of file name, ASCIIZ!
*               openMode : integer      file opening mode, see enum rfOpenMode
*               fileh : PrfHandle       pointer to file handle
*
* Returns:      MIDAS error code.
*               File handle is stored in fileh^.
*
\****************************************************************************}

function rfOpen(fileName : Pchar; openMode : integer; fileh : PrfHandle)
    : integer;



{****************************************************************************\
*
* Function:     rfClose(fileh : rfHandle) : integer;
*
* Description:  Closes a file opened with rfOpen().
*
* Input:        fileh : rfHandle        handle of an open file
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function rfClose(fileh : rfHandle) : integer;




{****************************************************************************\
*
* Function:     rfGetSize(fileh : rfHandle; fileSize : Plongint) : integer;
*
* Description:  Get the size of a file
*
* Input:        fileh : rfHandle        handle of an open file
*               fileSize : Plongint     pointer to file size
*
* Returns:      MIDAS error code.
*               File size is stored in fileSize^.
*
\****************************************************************************}

function rfGetSize(fileh : rfHandle; fileSize : Plongint) : integer;




{****************************************************************************\
*
* Function:     rfRead(fileh : rfHandle; buffer : pointer;
*                   numBytes : longint) : integer;
*
* Description:  Reads binary data from a file
*
* Input:        fileh : rfHandle        file handle
*               buffer : pointer        reading buffer
*               numBytes : longint      number of bytes to read
*
* Returns:      MIDAS error code.
*               Read data is stored in buffer^, which must be large enough
*               for it.
*
\****************************************************************************}

function rfRead(fileh : rfHandle; buffer : pointer; numBytes : longint)
    : integer;




{****************************************************************************\
*
* Function:     rfWrite(fileh : rfHandle; buffer : pointer;
*               numBytes : longint) : integer;
*
* Description:  Writes binary data to a file
*
* Input:        fileh : rfHandle        file handle
*               buffer : pointer        pointer to data to be written
*               numBytes : longint      number of bytes to write
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function rfWrite(fileh : rfHandle; buffer : pointer; numBytes : longint)
    : integer;




{****************************************************************************\
*
* Function:     rfSeek(fileh : rfHandle; newPosition : longint;
*               seekMode : integer) : integer;
*
* Description:  Seeks to a new position in file. Subsequent reads and writes
*               go to the new position.
*
* Input:        fileh : rfHandle        file handle
*               newPosition : longint   new file position
*               seekMode : integer      file seek mode, see enum rfSeekMode
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function rfSeek(fileh : rfHandle; newPosition : longint; seekMode : integer)
    : integer;




{****************************************************************************\
*
* Function:     int rfGetPosition(fileh : rfHandle; position : Plongint)
*                   : integer;
*
* Description:  Reads the current position in a file
*
* Input:        fileh : rfHandle        file handle
*               position : Plongint     pointer to file position
*
* Returns:      MIDAS error code.
*               Current file position is stored in position^.
*
\****************************************************************************}

function rfGetPosition(fileh : rfHandle; position : Plongint) : integer;



implementation


uses    Errors, mMem;



function rfOpen(fileName : Pchar; openMode : integer; fileh : PrfHandle)
    : integer; external;
function rfClose(fileh : rfHandle) : integer; external;
function rfGetSize(fileh : rfHandle; fileSize : Plongint) : integer; external;
function rfRead(fileh : rfHandle; buffer : pointer; numBytes : longint)
    : integer; external;
function rfWrite(fileh : rfHandle; buffer : pointer; numBytes : longint)
    : integer; external;
function rfSeek(fileh : rfHandle; newPosition : longint; seekMode : integer)
    : integer; external;
function rfGetPosition(fileh : rfHandle; position : Plongint) : integer;
    external;
{$L ASMRFILE.OBJ}


END.
