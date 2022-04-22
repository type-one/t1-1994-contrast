{*      EMS.PAS
 *
 * EMS heap manager, v1.10
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*}


unit EMS;


interface


{****************************************************************************\
*       struct emsBlock
*       ---------------
* Description:  Allocated EMS block structure
\****************************************************************************}

type
    emsBlock = Record
        addr : word;                        { address of block inside handle
                                              memory area }
        bytes : word;                       { size of block }
        next : pointer;                     { pointer to next block in same
                                              handle }
        prev : pointer;                     { pointer to previous block }
        used : word;                        { 1 if used, 0 if not }
        handle : pointer;                   { handle of the block }
    end;



{****************************************************************************\
*       struct emsHandle
*       ----------------
* Description:  One EMS handle consisting of four pages. Used internally by
*               heap manager.
\****************************************************************************}

type
    emsHandle = Record
        handle : word;                      { EMM handle number }
        block : pointer;                    { pointer to first block }
        next : pointer;                     { pointer to next handle }
        prev : pointer;                     { pointer to previous handle }
    end;

    PemsBlock = ^emsBlock;
    PemsHandle = ^emsHandle;

    Pinteger = ^integer;
    Ppointer = ^pointer;



{****************************************************************************\
*
* Function:     emsInit(emmOK : Pinteger) : integer;
*
* Description:  Initializes EMS heap. Must be called before other EMS heap
*               manager functions.
*
* Input:        emmOK : Pinteger        pointer to variable containing EMM
*                                       status
*
* Returns:      MIDAS error code.
*               emmOK^ contains 1 if Expanded Memory Manager was found (EMS
*               initialized succesfully) or 0 if not. Note that the lack
*               of Expanded Memory Manager is _not_ an error.
*
\****************************************************************************}

function emsInit(emmOK : Pinteger) : integer;



{****************************************************************************\
*
* Function:     emsClose : integer;
*
* Description:  Uninitializes EMS heap freeing all allocated blocks. Must be
*               called before program exits if emsInit() has been called.
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function emsClose : integer;



{****************************************************************************\
*
* Function:     emsAlloc(bytes : word; emsb : Ppointer) : integer;
*
* Description:  Allocates an EMS memory block
*
* Input:        bytes : word            number of bytes to be allocated
*               emsb : Ppointer         pointer to EMS Block pointer
*
* Returns:      MIDAS error code.
*               EMS block pointer stored in ems^, NULL if failure
*
\****************************************************************************}

function emsAlloc(bytes : word; ems : Ppointer) : integer;



{****************************************************************************\
*
* Function:     emsFree(ems : pointer) : integer;
*
* Description:  Deallocates an EMS block allocated with emsAlloc
*
* Input:        ems : pointer           pointer to block to be deallocated
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function emsFree(ems : pointer) : integer;



{****************************************************************************\
*
* Function:     int emsMap(emsBlock *ems, void **memPtr);
*
* Description:  Maps an EMS block to conventional memory.
*
* Input:        ems : pointer           pointer to block to be mapped
*               memPtr : Ppointer       pointer to conventional memory ptr
*
* Returns:      MIDAS error code.
*               Pointer to the conventional memory area where the block
*               was mapped is stored in memPtr^, NULL if failure.
*
\****************************************************************************}

function emsMap(ems : pointer; memPtr : Ppointer) : integer;



{****************************************************************************\
*
* Function:     emsSave : integer;
*
* Description:  Saves the EMS status. To be used by TempoTimer. Can only be
*               called once.
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function emsSave : integer;



{****************************************************************************\
*
* Function:     emsRestore : integer;
*
* Description:  Restores EMS status saved with emsSave(). To be used by
*               TempoTimer. Can only be called once.
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function emsRestore : integer;




{****************************************************************************\
*
* Function:     emsAllocPages(emsh : PemsHandle) : integer;
*
* Description:  Allocates 4 pages of EMS memory to a handle. Used internally
*               by EMS heap manager.
*
* Returns:      MIDAS error code.
*               Pointer to a emsHandle structure for the pages stored in
*               emsh^, NULL if failure.
*
\****************************************************************************}

function emsAllocPages(emsh : PemsHandle) : integer;



{****************************************************************************\
*
* Function:     emsFreePages(handle : PemsHandle) : integer;
*
* Description:  Deallocates an EMS handle allocated by emsAllocPages(). Used
*               internally by EMS heap manager.
*
* Input:        handle : PemsHandle     pointer to handle to be deallocated.
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function emsFreePages(handle : PemsHandle) : integer;




{****************************************************************************\
*
* Function:     emsSafe : integer;
*
* Description:  Sets the EMS safety flag on so that the EMS heap manager
*               can optimize page mappings. Until emsStopSafe() is restored,
*               no other routine than emsMap() must touch the EMS page
*               mappings
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function emsSafe : integer;



{****************************************************************************\
*
* Function:     emsStopSafe : integer;
*
* Description:  Sets the EMS safety flag off.
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function emsStopSafe : integer;




implementation

uses mMem, Errors;


function emsInit(emmOK : Pinteger) : integer; external;
function emsClose : integer; external;
function emsAlloc(bytes : word; ems : Ppointer) : integer; external;
function emsFree(ems : pointer) : integer; external;
function emsMap(ems : pointer; memPtr : Ppointer) : integer; external;
function emsSave : integer; external;
function emsRestore : integer; external;
function emsAllocPages(emsh : PemsHandle) : integer; external;
function emsFreePages(handle : PemsHandle) : integer; external;
function emsSafe : integer; external;
function emsStopSafe : integer; external;
{$L EMS.OBJ}


END.
