{*      DMA.PAS
 *
 * DMA handling routines, v1.10
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*}


unit DMA;


interface




{****************************************************************************\
*       struct dmaBuffer
*       ----------------
* Description:  DMA playing buffer
\****************************************************************************}

type
    dmaBuffer = record
        segment : word;                 { segment of the buffer (offset
                                          must be zero) }
        address : longint;              { buffer physical start address }
        length : word;                  { length of buffer, MULTIPLE OF 16 }
        memBlk : pointer;               { internal, used for unallocating }
        channel : integer;              { channel on which the buffer is
                                          being played or -1 }
    end;

    PdmaBuffer = ^dmaBuffer;

    Pword = ^word;




{****************************************************************************\
*
* Function:     dmaAllocBuffer(size : word; buf : PdmaBuffer) : integer
*
* Description:  Allocates a DMA buffer (totally inside a 64K physical page)
*
* Input:        size : word             size of buffer in bytes
*               buf : PdmaBuffer        ptr to buffer strucure to be filled
*
* Returns:      MIDAS error code.
*               DMA buffer data is strored in buf^.
*
\****************************************************************************}

function dmaAllocBuffer(size : word; buf : PdmaBuffer) : integer;



{****************************************************************************\
*
* Function:     dmaFreeBuffer(buf : PdmaBuffer) : integer;
*
* Description:  Deallocates an allocated DMA buffer
*
* Input:        buf : PdmaBuffer        pointer to buffer to be deallocated
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function dmaFreeBuffer(buf : PdmaBuffer) : integer;



{****************************************************************************\
*
* Function:     dmaPlayBuffer(buf : PdmaBuffer; channel, autoInit : word) :
*                   integer;
*
* Description:  Plays a DMA buffer
*
* Input:        buf : PdmaBuffer        pointer to buffer to be player
*               channel : word          DMA channel number
*               autoInit : word         use autoinitialization?
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function dmaPlayBuffer(buf : PdmaBuffer; channel, autoInit : word) : integer;




{****************************************************************************\
*
* Function:     dmaStop(channel : word) : integer;
*
* Description:  Stops DMA playing
*
* Input:        channel : word          DMA channel number
*
* Returns:      MIDAS error code
*
\****************************************************************************}

function dmaStop(channel : word) : integer;




{****************************************************************************\
*
* Function:     dmaGetPos(buf : PdmaBuffer; pos : Pword) : integer;
*
* Description:  Gets the DMA playing position
*
* Input:        buf : PdmaBuffer        buffer that is being played
*               pos : Pword             pointer to return value
*
* Returns:      MIDAS error code.
*               DMA playing position from the beginning of the buffer,
*               in bytes, is stored in pos^.
*
\****************************************************************************}

function dmaGetPos(buf : PdmaBuffer; pos : Pword) : integer;




implementation


uses mMem, Errors;



function dmaAllocBuffer(size : word; buf : PdmaBuffer) : integer; external;
function dmaFreeBuffer(buf : PdmaBuffer) : integer; external;
function dmaPlayBuffer(buf : PdmaBuffer; channel, autoInit : word) : integer;
    external;
function dmaStop(channel : word) : integer; external;
function dmaGetPos(buf : PdmaBuffer; pos : Pword) : integer; external;
{$L DMA.OBJ}



END.
