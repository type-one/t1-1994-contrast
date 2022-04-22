;*      FILE.INC
;*
;* High-level file I/O for MIDAS Sound System
;*
;* Copyright 1994 Petteri Kangaslampi and Jarno Paananen
;*
;* This file is part of the MIDAS Sound System, and may only be
;* used, modified and distributed under the terms of the MIDAS
;* Sound System license, LICENSE.TXT. By continuing to use,
;* modify or distribute this file you indicate that you have
;* read the license and understand and accept it fully.
;*



;/***************************************************************************\
;*       struct fileFile
;*       ---------------
;* Description:  File state structure
;\***************************************************************************/

STRUC   fileFile
        rf              rfHandle        ?
ENDS



;/***************************************************************************\
;*       typedef fileHandle
;*       ------------------
;* Description: High-level file I/O file handle
;\***************************************************************************/

TYPEDEF fileHandle dword



;/***************************************************************************\
;*       enum fileOpenMode
;*       -----------------
;* Description:  File opening mode. Used by fileOpen()
;\***************************************************************************/

ENUM    fileOpenMode \
        fileOpenRead = 1, \             ; open file for reading
        fileOpenWrite = 2, \            ; open file for writing
        fileOpenReadWrite = 3           ; open file for both reading and
                                        ; writing



;/***************************************************************************\
;*       enum fileSeekMode
;*       -----------------
;* Description:  File seeking mode. Used by fileSeek()
;\***************************************************************************/

ENUM    fileSeekMode \
        fileSeekAbsolute = 1, \         ; seek to an absolute position from
                              \         ; the beginning of the file
        fileSeekRelative = 2, \         ; seek to a position relative to
                                        ; current position
        fileSeekEnd = 3                 ; seek relative to the end of file




;/***************************************************************************\
;*
;* Function:     int fileOpen(char *fileName, int openMode, fileHandle *file);
;*
;* Description:  Opens a file for reading or writing
;*
;* Input:        char *fileName          name of file
;*               int openMode            file opening mode, see enum
;*                                       rfOpenMode
;*               fileHandle *file        pointer to file handle
;*
;* Returns:      MIDAS error code.
;*               File handle is stored in *file.
;*
;\***************************************************************************/

GLOBAL  LANG fileOpen : far




;/***************************************************************************\
;*
;* Function:     int fileClose(fileHandle file);
;*
;* Description:  Closes a file opened with fileOpen().
;*
;* Input:        fileHandle file         handle of an open file
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

GLOBAL  LANG fileClose : far




;/***************************************************************************\
;*
;* Function:     int fileGetSize(fileHandle file, long *fileSize);
;*
;* Description:  Get the size of a file
;*
;* Input:        fileHandle file         handle of an open file
;*               ulong *fileSize         pointer to file size
;*
;* Returns:      MIDAS error code.
;*               File size is stored in *fileSize.
;*
;\***************************************************************************/

GLOBAL  LANG fileGetSize : far




;/***************************************************************************\
;*
;* Function:     int fileRead(fileHandle file, void *buffer, ulong numBytes);
;*
;* Description:  Reads binary data from a file
;*
;* Input:        fileHandle file         file handle
;*               void *buffer            reading buffer
;*               ulong numBytes          number of bytes to read
;*
;* Returns:      MIDAS error code.
;*               Read data is stored in *buffer, which must be large enough
;*               for it.
;*
;\***************************************************************************/

GLOBAL  LANG fileRead : far




;/***************************************************************************\
;*
;* Function:     int fileWrite(fileHandle file, void *buffer, ulong numBytes);
;*
;* Description:  Writes binary data to a file
;*
;* Input:        fileHandle file         file handle
;*               void *buffer            pointer to data to be written
;*               ulong numBytes          number of bytes to write
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

GLOBAL  LANG fileWrite : far




;/***************************************************************************\
;*
;* Function:     int fileSeek(fileHandle file, long newPosition,
;*                       int seekMode);
;*
;* Description:  Seeks to a new position in file. Subsequent reads and writes
;*               go to the new position.
;*
;* Input:        fileHandle file         file handle
;*               long newPosition        new file position
;*               int seekMode            file seek mode, see enum rfSeekMode
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

GLOBAL  LANG fileSeek : far




;/***************************************************************************\
;*
;* Function:     int fileGetPosition(fileHandle file, long *position);
;*
;* Description:  Reads the current position in a file
;*
;* Input:        fileHandle file         file handle
;*               long *position          pointer to file position
;*
;* Returns:      MIDAS error code.
;*               Current file position is stored in *position.
;*
;\***************************************************************************/

GLOBAL  LANG fileGetPosition : far
