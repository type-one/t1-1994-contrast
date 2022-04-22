;*	DMA.INC
;*
;* DMA handling routines, v1.10
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
;*       struct dmaBuffer
;*       ----------------
;* Description:  DMA playing buffer
;\***************************************************************************/

STRUC	dmaBuffer
	bsegment	DW	?	; segment
	address 	DD	?	; physical start address
	blength 	DW	?	; buffer length
	memBlk		DD	?	; internal, used for unallocating
	channel 	DW	?	; channel on which the buffer is
					; being played or -1
ENDS



;/***************************************************************************\
;*      struct dmaChannel
;*      -----------------
;* Description: DMA channel data used by DMA functions.
;\***************************************************************************/

STRUC	dmaChannel
	number		DB	?	; channel number
	bit		DB	?	; channel bit
	baseAddr	DW	?	; base address port
	wordCount	DW	?	; word count port
	request 	DW	?	; request port
	singleMask	DW	?	; mask port
	mode		DW	?	; mode port
	clearFF 	DW	?	; clear flip-flop port
	page		DW	?	; page port
ENDS



;/***************************************************************************\
;*
;* Function:     int dmaAllocBuffer(ushort size, dmaBuffer *buf);
;*
;* Description:  Allocates a DMA buffer (totally inside a 64K physical page)
;*
;* Input:        ushort size             size of buffer in bytes
;*               dmaBuffer *buf          ptr to buffer structure to be filled
;*
;* Returns:      MIDAS error code.
;*               DMA buffer data is strored in *buf.
;*
;\***************************************************************************/

GLOBAL  LANG dmaAllocBuffer : far



;/***************************************************************************\
;*
;* Function:     int dmaFreeBuffer(dmaBuffer *buf);
;*
;* Description:  Deallocates an allocated DMA buffer
;*
;* Input:        dmaBuffer *buf          ptr to buffer to be deallocated
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

GLOBAL  LANG dmaFreeBuffer : far



;/***************************************************************************\
;*
;* Function:     int dmaPlayBuffer(dmaBuffer *buf, ushort channel,
;*                                 ushort autoInit);
;*
;* Description:  Plays a DMA buffer
;*
;* Input:        dmaBuffer *buf          buffer to be player
;*               ushort channel          DMA channel number
;*               ushort autoInit         use autoinitialization?
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

GLOBAL  LANG dmaPlayBuffer : far




;/***************************************************************************\
;*
;* Function:     int dmaStop(ushort channel);
;*
;* Description:  Stops DMA playing
;*
;* Input:        ushort channel          DMA channel number
;*
;* Returns:      MIDAS error code
;*
;\***************************************************************************/

GLOBAL  LANG dmaStop : far



;/***************************************************************************\
;*
;* Function:     int dmaGetPos(dmaBuffer *buf, ushort *pos);
;*
;* Description:  Gets the DMA playing position
;*
;* Input:        dmaBuffer *buf          buffer that is being played
;*               ushort *pos             pointer to return value
;*
;* Returns:      MIDAS error code.
;*               DMA playing position from the beginning of the buffer,
;*               in bytes, is stored in *pos.
;*
;\***************************************************************************/

GLOBAL  LANG dmaGetPos : far



;/***************************************************************************\
;*       enum dmaFunctIDs
;*       ----------------
;* Description:  ID numbers for DMA handling functions
;\***************************************************************************/

enum    dmaFunctIDs \
        ID_dmaAllocBuffer = ID_dma, \
        ID_dmaFreeBuffer, \
        ID_dmaPlayBuffer, \
        ID_dmaStop, \
        ID_dmaGetPos
