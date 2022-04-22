;*      RAWFILE.INC
;*
;* Raw file I/O for MIDAS Sound System
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
;*       struct rfFile
;*       -------------
;* Description:  File state structure
;\***************************************************************************/

STRUC   rfFile
        handle          DW      ?
ENDS



;/***************************************************************************\
;*       typedef rfHandle
;*       ----------------
;* Description: Raw file I/O file handle
;\***************************************************************************/

TYPEDEF rfHandle dword




;/***************************************************************************\
;*       enum rfOpenMode
;*       ---------------
;* Description:  File opening mode. Used by rfOpen()
;\***************************************************************************/

ENUM    rfOpenMode \
        rfOpenRead = 1, \               ; open file for reading
        rfOpenWrite = 2, \              ; open file for writing
        rfOpenReadWrite = 3             ; open file for both reading and
                                        ; writing



;/***************************************************************************\
;*       enum rfSeekMode
;*       ---------------
;* Description:  File seeking mode. Used by rfSeek()
;\***************************************************************************/

ENUM    rfSeekMode \
        rfSeekAbsolute = 1, \           ; seek to an absolute position from
                            \           ; the beginning of the file
        rfSeekRelative = 2, \           ; seek to a position relative to
                            \           ; current position
        rfSeekEnd = 3                   ; seek relative to the end of file



;/***************************************************************************\
;*
;* Function:     int rfOpen(char *fileName, int openMode, rfHandle *file);
;*
;* Description:  Opens a file for reading or writing
;*
;* Input:        char *fileName          name of file
;*               int openMode            file opening mode, see enum rfOpenMode
;*               rfHandle *file          pointer to file handle
;*
;* Returns:      MIDAS error code.
;*               File handle is stored in *file.
;*
;\***************************************************************************/

GLOBAL  LANG rfOpen : far




;/***************************************************************************\
;*
;* Function:     int rfClose(rfHandle file);
;*
;* Description:  Closes a file opened with rfOpen().
;*
;* Input:        rfHandle file           handle of an open file
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

GLOBAL  LANG rfClose : far




;/***************************************************************************\
;*
;* Function:     int rfGetSize(rfHandle file, long *fileSize);
;*
;* Description:  Get the size of a file
;*
;* Input:        rfHandle file           handle of an open file
;*               ulong *fileSize         pointer to file size
;*
;* Returns:      MIDAS error code.
;*               File size is stored in *fileSize.
;*
;\***************************************************************************/

GLOBAL  LANG rfGetSize : far




;/***************************************************************************\
;*
;* Function:     int rfRead(rfHandle file, void *buffer, ulong numBytes);
;*
;* Description:  Reads binary data from a file
;*
;* Input:        rfHandle file           file handle
;*               void *buffer            reading buffer
;*               ulong numBytes          number of bytes to read
;*
;* Returns:      MIDAS error code.
;*               Read data is stored in *buffer, which must be large enough
;*               for it.
;*
;\***************************************************************************/

GLOBAL  LANG rfRead : far




;/***************************************************************************\
;*
;* Function:     int rfWrite(rfHandle file, void *buffer, ulong numBytes);
;*
;* Description:  Writes binary data to a file
;*
;* Input:        rfHandle file           file handle
;*               void *buffer            pointer to data to be written
;*               ulong numBytes          number of bytes to write
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

GLOBAL  LANG rfWrite : far




;/***************************************************************************\
;*
;* Function:     int rfSeek(rfHandle file, long newPosition, int seekMode);
;*
;* Description:  Seeks to a new position in file. Subsequent reads and writes
;*               go to the new position.
;*
;* Input:        rfHandle file           file handle
;*               long newPosition        new file position
;*               int seekMode            file seek mode, see enum rfSeekMode
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

GLOBAL  LANG rfSeek : far




;/***************************************************************************\
;*
;* Function:     int rfGetPosition(rfHandle file, long *position);
;*
;* Description:  Reads the current position in a file
;*
;* Input:        rfHandle file           file handle
;*               long *position          pointer to file position
;*
;* Returns:      MIDAS error code.
;*               Current file position is stored in *position.
;*
;\***************************************************************************/

GLOBAL  LANG rfGetPosition : far




;/***************************************************************************\
;*       enum rfFunctIDs
;*       ---------------
;* Description:  ID numbers for raw file I/O functions
;\***************************************************************************/

ENUM    rfFunctIDs \
        ID_rfOpen = ID_rf, \
        ID_rfClose, \
        ID_rfGetSize, \
        ID_rfRead, \
        ID_rfWrite, \
        ID_rfSeek, \
        ID_rfGetPosition
