/*      MMEM.C
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
*/

#include <stdlib.h>
#include <alloc.h>
#include "lang.h"
#include "errors.h"
#include "mmem.h"


/****************************************************************************\
*
* Function:     int memAlloc(unsigned short len, void **blk);
*
* Description:  Allocates a block of conventional memory
*
* Input:        unsigned short len      Memory block length in bytes
*               void **blk              Pointer to memory block pointer
*
* Returns:      MIDAS error code.
*               Pointer to allocated block stored in *blk, NULL if error.
*
\****************************************************************************/

int CALLING memAlloc(unsigned short len, void **blk)
{
    /* check that block length is not zero: */
    if ( len == 0 )
    {
        ERROR(errInvalidBlock, ID_memAlloc);
        return errInvalidBlock;
    }

    /* allocate memory: */
    *blk = malloc(len);

    if ( *blk == NULL )
    {
        /* Memory allocation failed - check if heap is corrupted. If not,
           assume out of memory: */
        if ( heapcheck() == _HEAPCORRUPT )
        {
            ERROR(errHeapCorrupted, ID_memAlloc);
            return errHeapCorrupted;
        }
        else
        {
            ERROR(errOutOfMemory, ID_memAlloc);
            return errOutOfMemory;
        }
    }

    /* memory allocated successfully */
    return OK;
}



/****************************************************************************\
*
* Function:     int memFree(void *blk);
*
* Description:  Deallocates a memory block allocated with memAlloc()
*
* Input:        void *blk               Memory block pointer
*
* Returns:      MIDAS error code.
*
\****************************************************************************/

int CALLING memFree(void *blk)
{
    /* Check that block pointer is not NULL: */
    if ( blk == NULL )
    {
        ERROR(errInvalidBlock, ID_memFree);
        return errInvalidBlock;
    }

    /* deallocate block: */
    free(blk);

    /* deallocation successful */
    return OK;
}
