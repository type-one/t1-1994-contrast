{*      MMEM.PAS
 *
 * MIDAS Sound System memory handling routines
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*}

unit mMem;


interface


type
    Ppointer = ^pointer;


{****************************************************************************\
*
* Function:     memAlloc(len : word; blk : Ppointer) : integer;
*
* Description:  Allocates a block of conventional memory
*
* Input:        len : word              Memory block length in bytes
*               blk : Ppointer          Pointer to memory block pointer
*
* Returns:      MIDAS error code.
*               Pointer to allocated block stored in blk^, NULL if error.
*
\****************************************************************************}

function memAlloc(len : word; blk : Ppointer) : integer;



{****************************************************************************\
*
* Function:     memFree(blk : pointer) : integer;
*
* Description:  Deallocates a memory block allocated with memAlloc()
*
* Input:        blk : pointer           Memory block pointer
*
* Returns:      MIDAS error code.
*
\****************************************************************************}

function memFree(blk : pointer) : integer;




implementation


uses Errors;



{****************************************************************************\
*       enum memFunctIDs
*       ----------------
* Description:  ID numbers for memory handling functions
\****************************************************************************}

const
    ID_memAlloc = ID_mem;
    ID_memFree = ID_mem + 1;



{****************************************************************************\
*
* Function:     memAlloc(len : word; blk : Ppointer) : integer;
*
* Description:  Allocates a block of conventional memory
*
* Input:        len : word              Memory block length in bytes
*               blk : Ppointer          Pointer to memory block pointer
*
* Returns:      MIDAS error code.
*               Pointer to allocated block stored in blk^, NULL if error.
*
\****************************************************************************}

function memAlloc(len : word; blk : Ppointer) : integer;
var
    wordp : ^word;

begin
    { Save the si and di registers, as all assembly routines assume that they
      are preserved: }
asm
        push    si
        push    di
end;

    { Check that there is enough free memory left for the block: }
    if MaxAvail >= len then
    begin
        { Check that the block is small enough: }
        if len < 65530 then
        begin
            { Allocate memory for the block plus one word: }
            GetMem(wordp, len+2);

            { Store block length to allocated pointer: }
            wordp^ := len;

            { Return pointer to the next byte following the stored length: }
            blk^ := ptr(seg(wordp^), ofs(wordp^)+2);
            memAlloc := OK;
        end
        else
        begin
            { block too large: }
            mError(errInvalidBlock, ID_memAlloc);
            memAlloc := errInvalidBlock;
            blk^ := NIL;
        end;
    end
    else
    begin
        { not enough memory left: }
        mError(errOutOfMemory, ID_memAlloc);
        memAlloc := errOutOfMemory;
        blk^ := NIL;
    end;

    { Restore si and di: }
asm
        pop     di
        pop     si
end;
end;




{****************************************************************************\
*
* Function:     memFree(blk : pointer) : integer;
*
* Description:  Deallocates a memory block allocated with memAlloc()
*
* Input:        blk : pointer           Memory block pointer
*
* Returns:      MIDAS error code.
*
\****************************************************************************}

function memFree(blk : pointer) : integer;
var
    wordp : ^word;

begin
    { Save the si and di registers, as all assembly routines assume that they
      are preserved: }
asm
        push    si
        push    di
end;
    { Check that block pointer is not NULL: }
    if blk <> NIL then
    begin
        { Point wordp to saved block length: }
        wordp := ptr(seg(blk^), ofs(blk^)-2);

        { Deallocate block: }
        FreeMem(wordp, wordp^ + 2);

        memFree := OK;
    end
    else
    begin
        mError(errInvalidBlock, ID_memFree);
        memFree := errInvalidBlock;
    end;

    { Restore si and di: }
asm
        pop     di
        pop     si
end;
end;



END.
