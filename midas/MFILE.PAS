{*      MFILE.PAS
 *
 * High-level file I/O for MIDAS Sound System
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*}


unit    mFile;



interface


{****************************************************************************\
*       struct fileFile
*       ---------------
* Description:  File state structure
\****************************************************************************}

type
    fileFile = Record
        rf : pointer;                   { raw file handle }
    end;



{****************************************************************************\
*       typedef fileHandle
*       ------------------
* Description: High-level file I/O file handle
\****************************************************************************}

type
    fileHandle = ^fileFile;
    PfileHandle = ^fileHandle;



{****************************************************************************\
*       enum fileOpenMode
*       -----------------
* Description:  File opening mode. Used by fileOpen()
\****************************************************************************}

const
    fileOpenRead = 1;                   { open file for reading }
    fileOpenWrite = 2;                  { open file for writing }
    fileOpenReadWrite = 3;              { open file for both reading and
                                          writing }


{****************************************************************************\
*       enum fileSeekMode
*       -----------------
* Description:  File seeking mode. Used by fileSeek()
\****************************************************************************}

    fileSeekAbsolute = 1;               { seek to an absolute position from
                                          the beginning of the file }
    fileSeekRelative = 2;               { seek to a position relative to
                                          current position }
    fileSeekEnd = 3;                    { seek relative to the end of file }



type
    Pchar = ^char;
    Plongint = ^longint;


{****************************************************************************\
*
* Function:     fileOpen(fileName : Pchar; openMode : integer;
*                   fileh : PfileHandle) : integer;
*
* Description:  Opens a file for reading or writing
*
* Input:        fileName : Pchar        pointer to file name ASCIIZ string
*               openMode : integer      file opening mode, see enum
*                                       fileOpenMode
*               fileh : PfileHandle     pointer to file handle
*
* Returns:      MIDAS error code.
*               File handle is stored in fileh^.
*
\****************************************************************************}

function fileOpen(fileName : Pchar; openMode : integer; fileh : PfileHandle)
    : integer;



{****************************************************************************\
*
* Function:     fileClose(fileh : fileHandle) : integer;
*
* Description:  Closes a file opened with fileOpen().
*
* Input:        fileh : fileHandle      handle of an open file
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function fileClose(fileh : fileHandle) : integer;




{****************************************************************************\
*
* Function:     fileGetSize(fileh : fileHandle; fileSize : Plongint)
*                   : integer;
*
* Description:  Get the size of a file
*
* Input:        fileh : fileHandle      handle of an open file
*               fileSize : Plongint     pointer to file size
*
* Returns:      MIDAS error code.
*               File size is stored in fileSize^.
*
\****************************************************************************}

function fileGetSize(fileh : fileHandle; fileSize : Plongint) : integer;




{****************************************************************************\
*
* Function:     fileRead(fileh : fileHandle; buffer : pointer;
*                   numBytes : longint) : integer;
*
* Description:  Reads binary data from a file
*
* Input:        fileh : fileHandle      file handle
*               buffer : pointer        reading buffer
*               numBytes : longint      number of bytes to read
*
* Returns:      MIDAS error code.
*               Read data is stored in buffer^, which must be large enough
*               for it.
*
\****************************************************************************}

function fileRead(fileh : fileHandle; buffer : pointer; numBytes : longint)
    : integer;




{****************************************************************************\
*
* Function:     fileWrite(fileh : fileHandle; buffer : pointer;
*               numBytes : longint) : integer;
*
* Description:  Writes binary data to a file
*
* Input:        fileh : fileHandle      file handle
*               buffer : pointer        pointer to data to be written
*               numBytes : longint      number of bytes to write
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function fileWrite(fileh : fileHandle; buffer : pointer; numBytes : longint)
    : integer;




{****************************************************************************\
*
* Function:     fileSeek(fileh : fileHandle; newPosition : longint;
*                   seekMode : integer) : integer;
*
* Description:  Seeks to a new position in file. Subsequent reads and writes
*               go to the new position.
*
* Input:        fileh : fileHandle      file handle
*               newPosition : longint   new file position
*               seekMode : integer      file seek mode, see enum fileSeekMode
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function fileSeek(fileh : fileHandle; newPosition : longint;
    seekMode : integer) : integer;




{****************************************************************************\
*
* Function:     int fileGetPosition(fileh : fileHandle; position : Plongint)
*                   : integer;
*
* Description:  Reads the current position in a file
*
* Input:        fileh : fileHandle      file handle
*               position : Plongint     pointer to file position
*
* Returns:      MIDAS error code.
*               Current file position is stored in position^.
*
\****************************************************************************}

function fileGetPosition(fileh : fileHandle; position : Plongint) : integer;




implementation


uses    Errors, mMem, rawFile;



function fileOpen(fileName : Pchar; openMode : integer; fileh : PfileHandle)
    : integer; external;
function fileClose(fileh : fileHandle) : integer; external;
function fileGetSize(fileh : fileHandle; fileSize : Plongint) : integer;
    external;
function fileRead(fileh : fileHandle; buffer : pointer; numBytes : longint)
    : integer; external;
function fileWrite(fileh : fileHandle; buffer : pointer; numBytes : longint)
    : integer; external;
function fileSeek(fileh : fileHandle; newPosition : longint;
    seekMode : integer) : integer; external;
function fileGetPosition(fileh : fileHandle; position : Plongint) : integer;
    external;
{$L FILE.OBJ}


END.
