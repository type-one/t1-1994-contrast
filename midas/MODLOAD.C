/*      MODLOAD.C
 *
 * ProTracker Module loader
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*/

#include "lang.h"
#include "mtypes.h"
#include "errors.h"
#include "mglobals.h"
#include "mmem.h"
#include "file.h"
#include "sdevice.h"
#include "mplayer.h"
#include "mod.h"
#include "ems.h"
#include "vu.h"

#define NULL 0L




/****************************************************************************\
*
* Function:     int CompMem(void *a, void *b, size_t numBytes)
*
* Description:  Compares two memory areas
*
* Input:        void *a                 memory area #1
*               void *b                 memory area #2
*               size_t numBytes         number of bytes to compare
*
* Returns:      1 if memory areas are equal, 0 if not
*
\****************************************************************************/

static int CompMem(void *a, void *b, size_t numBytes)
{
    uchar       *m1 = a, *m2 = b;
    size_t      i;

    for ( i = 0; i < numBytes; i++ )
        if ( m1[i] != m2[i] )
            return 0;

    return 1;
}




/****************************************************************************\
*
* Function:     void CopyMem(void *dest, void *source, size_t numBytes)
*
* Description:  Copies a memory area
*
* Input:        void *dest              pointer to destination
*               void *source            pointer to source
*               size_t numBytes         number of bytes to copy
*
\****************************************************************************/

static void CopyMem(void *dest, void *source, size_t numBytes)
{
    uchar       *src = source, *dst = dest;
    size_t      i;

    for ( i = 0; i < numBytes; i++ )
        dst[i] = src[i];
}




/* Macro for endianness-swap. DANGEROUS - references the argument x
   twice */
#define SWAP16(x) ( ((x << 8) & 0xFF00) | ( (x >> 8) & 0x00FF) )

/* Size of temporary memory area used for avoiding memory fragmentation
   if EMS is used */
#define TEMPSIZE 8192

/* Pass error code in variable "error" on, used in modLoadModule(). */
#define MODLOADPASSERROR { modLoadError(SD); PASSERROR(ID_modLoadModule) }


/****************************************************************************\
*       Module loader buffers and file pointer. These variables are static
*       instead of local so that a separate deallocation can be used which
*       will be called before exiting in error situations
\****************************************************************************/
static fileHandle f;
static int      fileOpened;
static mpModule *mmod;
static ulong    *pattBuf;
static ulong    *trackBuf;
static uchar    *smpBuf;
static void     *tempmem;



/****************************************************************************\
*
* Function:     int modFreeModule(mpModule *module, SoundDevice *SD);
*
* Description:  Deallocates a Protracker module
*
* Input:        mpModule *module        module to be deallocated
*               SoundDevice *SD         Sound Device that has stored the
*                                       samples
*
* Returns:      MIDAS error code
*
\****************************************************************************/

int CALLING modFreeModule(mpModule *module, SoundDevice *SD)
{
    int         i, error;

    if ( module == NULL )               /* valid module? */
    {
        ERROR(errUndefined, ID_modFreeModule);
        return errUndefined;
    }


    /* deallocate pattern orders if allocated: */
    if ( module->orders != NULL )
        if ( (error = memFree(module->orders)) != OK )
            PASSERROR(ID_modFreeModule)

    /* deallocate instrument used flags is allocated: */
    if ( module->instsUsed != NULL )
        if ( (error = memFree(module->instsUsed)) != OK )
            PASSERROR(ID_modFreeModule)

    if ( module->insts != NULL )        /* instruments? */
    {
        for ( i = 0; i < module->numInsts; i++ )
        {
            /* If the instrument has been added to Sound Device, remove
               it, otherwise just deallocate the sample if allocated */

            if ( (module->insts[i].sdInstHandle != 0) && (SD != NULL) )
            {
                if ( (error = SD->RemInstrument(
                    module->insts[i].sdInstHandle)) != OK )
                    PASSERROR(ID_modFreeModule)
            }
            else
                if ( module->insts[i].sample != NULL )
                    if ( (error = memFree(module->insts[i].sample)) != OK )
                        PASSERROR(ID_modFreeModule)

            #ifdef REALVUMETERS
            /* remove VU meter information if used: */
            if ( realVU )
            {
                if (module->insts[i].sdInstHandle != 0)
                    if ( (error = vuRemove(module->insts[i].sdInstHandle))
                        != OK )
                        PASSERROR(ID_modFreeModule)
            }
            #endif

        }
        /* deallocate instrument structures: */
        if ( (error = memFree(module->insts)) != OK )
            PASSERROR(ID_modFreeModule)
    }

    if ( (module->patterns != NULL) && (module->pattEMS != NULL) )
    {
        for ( i = 0; i < module->numPatts; i++ )
        {
            if ( module->patterns[i] != NULL )
            {
                /* if the pattern has been allocate, deallocate it - either
                   from conventional memory or from EMS */

                if ( module->pattEMS[i] == 1 )
                {
                    if ( (error = emsFree((emsBlock*) module->patterns[i]))
                        != OK )
                        PASSERROR(ID_modFreeModule)
                }
                else
                    if ( (error = memFree(module->patterns[i])) != OK )
                        PASSERROR(ID_modFreeModule)
            }
        }
        /* deallocate pattern pointers: */
        if ( (error = memFree(module->patterns)) != OK )
            PASSERROR(ID_modFreeModule)

        /* deallocate pattern EMS flags: */
        if ( (error = memFree(module->pattEMS)) != OK )
            PASSERROR(ID_modFreeModule)
    }

    /* deallocate the module: */
    if ( (error = memFree(module)) != OK)
        PASSERROR(ID_modFreeModule)

    return OK;
}



/****************************************************************************\
*
* Function:     void modLoadError(SoundDevice *SD)
*
* Description:  Stops loading the module, deallocates all buffers and closes
*               the file.
*
* Input:        SoundDevice *SD         Sound Device that has been used for
*                                       loading.
*
\****************************************************************************/

static void modLoadError(SoundDevice *SD)
{
    /* Close file if opened. Do not process errors. */
    if ( fileOpened )
        if ( fileClose(f) != OK )
            return;

    /* Attempt to deallocate module if allocated. Do not process errors. */
    if ( mmod != NULL )
        if ( modFreeModule(mmod, SD) != OK )
            return;

    /* Deallocate buffers if allocated. Do not process errors. */
    if ( pattBuf != NULL )
        if ( memFree(pattBuf) != OK )
            return;
    if ( trackBuf != NULL )
        if ( memFree(trackBuf) != OK )
            return;
    if ( smpBuf != NULL )
        if ( memFree(smpBuf) != OK )
            return;
    if ( tempmem != NULL )
        if ( memFree(tempmem) != OK )
            return;
}



/****************************************************************************\
*
* Function:     int modLoadModule(char *fileName, SoundDevice *SD,
*                   mpModule **module);
*
* Description:  Loads a Protracker module into memory
*
* Input:        char *fileName          name of module file to be loaded
*               SoundDevice *SD         Sound Device which will store the
*                                       samples
*               mpModule **module       pointer to variable which will store
*                                       the module pointer.
*
* Returns:      MIDAS error code.
*               Pointer to module structure is stored in *module.
*
\****************************************************************************/

int CALLING modLoadModule(char *fileName, SoundDevice *SD, mpModule **module)
{
    int             error;              /* MIDAS error code */
    modHeader       modh;
    modInstHdr      *modi;
    mpInstrument    *inst;
    mpPattern       *pattData;

    ushort          trackLen;

    int             i, c, r;
    ushort          chans;
    ushort          numPatts;
    ulong           foffset;

    ushort          slength;            /* sample length */
    ushort          loopStart;          /* sample loop start */
    ushort          loopLength;         /* sample loop length */

    ulong           maxSmpLength;
    uchar           instx;
    char            temp[4];

    void            *p;


    /* point buffers to NULL and set fileOpened to 0 so that modLoadError()
       can be called at any point: */
    fileOpened = 0;
    mmod = NULL;
    pattBuf = NULL;
    trackBuf = NULL;
    smpBuf = NULL;
    tempmem = NULL;


    /* Open module file: */
    if ( (error = fileOpen(fileName, fileOpenRead, &f)) != OK )
        MODLOADPASSERROR

    /* Allocate memory for the module structure: */
    if ( (error = memAlloc(sizeof(mpModule), (void**) &mmod)) != OK )
        MODLOADPASSERROR

    mmod->orders = NULL;                 /* clear module structure so that */
    mmod->insts = NULL;                  /* it can be deallocated with */
    mmod->patterns = NULL;               /* modFree() at any point */
    mmod->pattEMS = NULL;
    mmod->instsUsed = NULL;

    /* read Protracker module header: */
    if ( (error = fileRead(f, &modh, sizeof(modHeader))) != OK )
        MODLOADPASSERROR

    chans = 0;

    /* Check the module signature to determine number of channels: */

    if ( CompMem(&modh.sign[0], "M.K.", 4) ) chans = 4;
    if ( CompMem(&modh.sign[0], "M!K!", 4) ) chans = 4;
    if ( CompMem(&modh.sign[0], "FLT4", 4) ) chans = 4;
    if ( CompMem(&modh.sign[0], "OCTA", 4) ) chans = 8;

    if ( CompMem(&modh.sign[1], "CHN", 3) )
    {
        /* xCHN, where x is the number of channels */
        chans = modh.sign[0] - '0';
    }

    if ( CompMem(&modh.sign[2], "CH", 2) )
    {
        /* xxCHN, where xx is the number of channels */
        chans = (modh.sign[0] - '0') * 10 + (modh.sign[1] - '0');
    }

    if ( CompMem(&modh.sign[0], "TDZ", 3) )
    {
        /* TDZx, where x is the number of channels */
        chans = modh.sign[3] - '0';
    }


    /* If number of channels is undetermined, the signature is invalid. */
    if ( chans == 0 )
    {
        ERROR(errInvalidModule, ID_modLoadModule);
        modLoadError(SD);
        return errInvalidModule;
    }

    mmod->numChans = chans;              /* store number of channels */

    CopyMem(&mmod->songName[0], &modh.songName[0], 20); /* copy song name */
    mmod->songName[20] = 0;                 /* force terminating '\0' */
    mmod->songLength = modh.songLength;     /* copy song length */
    mmod->numInsts = 31;                    /* set number of instruments */

    CopyMem(&mmod->ID, &modh.sign[0], 4);   /* copy module signature */
    mmod->IDnum = idMOD;                    /* Protracker module */


    for( i = 0; i < mmod->numChans; i++)
    {
        if( ((i & 3) == 0) || ((i & 3) == 3) )
            mmod->chanSettings[i] = -64;
        else
            mmod->chanSettings[i] = 64;
    }

    /* find number of patterns in file: */
    numPatts = 0;
    for ( i = 0; i < 128; i++ )         /* search all song data */
        if ( modh.orders[i] >= numPatts )
            numPatts = modh.orders[i] + 1;

    mmod->numPatts = numPatts * chans;   /* store number of tracks */

    /* allocate memory for pattern orders: */
    if ( (error = memAlloc(mmod->songLength, (void**) &mmod->orders)) != OK )
        MODLOADPASSERROR

    /* copy pattern orders */
    CopyMem(mmod->orders, &modh.orders[0], mmod->songLength);

    /* allocate memory for pattern (actually track) pointers */
    if ( (error = memAlloc((mmod->numPatts) * sizeof(mpPattern*),
        (void**) &mmod->patterns)) != OK )
        MODLOADPASSERROR

    /* allocate memory for pattern EMS flags */
    if ( (error = memAlloc(mmod->numPatts, (void**) &mmod->pattEMS)) != OK )
        MODLOADPASSERROR

    for ( i = 0; i < mmod->numPatts; i++ ) /* point all unallocated patterns */
        mmod->patterns[i] = NULL;          /* to NULL for safety */

    foffset = sizeof(modHeader);        /* point foffset to first pattern */


    /* allocate memory for instrument used flags: */
    if ( (error = memAlloc(mmod->numInsts, (void**) &mmod->instsUsed)) != OK )
        MODLOADPASSERROR

    /* Mark all instruments unused */
    for ( i = 0; i < mmod->numInsts; i++ )
        mmod->instsUsed[i] = 0;

    /* allocate memory for instrument structures: */
    if ( (error = memAlloc(mmod->numInsts * sizeof(mpInstrument),
        (void**) &mmod->insts)) != OK )
        MODLOADPASSERROR

    /* clear all instruments and find maximum instrument length: */
    maxSmpLength = 0;
    for ( i = 0; i < mmod->numInsts; i++ )
    {
        mmod->insts[i].sample = NULL;
        mmod->insts[i].sdInstHandle = 0;
        if ( maxSmpLength < ( 2 * SWAP16(modh.instruments[i].slength) ) )
            maxSmpLength = 2 * SWAP16(modh.instruments[i].slength);
    }

    /* check that none of the instruments is too long: */
    if ( maxSmpLength > SMPMAX )
    {
        ERROR(errInvalidInst, ID_modLoadModule);
        modLoadError(SD);
        return errInvalidInst;
    }

    /* allocate memory for pattern loading buffer */
    if ( (error = memAlloc(chans * 256, (void**) &pattBuf)) != OK )
        MODLOADPASSERROR

    /* allocate memory for track conversion buffer */
    if ( (error = memAlloc(256, (void**) &trackBuf)) != OK )
        MODLOADPASSERROR

    /* convert all patterns: */

    for ( i = 0; i < numPatts; i++ )
    {
        /* seek to pattern beginning */
        if ( (error = fileSeek(f, foffset, fileSeekAbsolute)) != OK )
            MODLOADPASSERROR

        /* read pattern data */
        if ( (error = fileRead(f, pattBuf, 256 * chans)) != OK )
            MODLOADPASSERROR

        /* convert all tracks of the pattern */
        for ( c = 0; c < chans; c++ )
        {
            /* copy track data to track buffer: */
            for ( r = 0; r < 64; r++)
                trackBuf[r] = pattBuf[r * chans + c];

            /* check used instruments */
            for ( r = 0; r < 64; r++)
            {
                instx = ((trackBuf[r] & 0x10) | ((trackBuf[r] >> 20) & 0xF));
                if ((instx > 0) && (instx < 32))
                    mmod->instsUsed[instx-1] = 1;
            }

            /* convert track to internal format: */
            if ( (error = modConvertTrack(trackBuf, 0, &trackLen)) != OK )
                MODLOADPASSERROR

            if ( useEMS == 1 )          /* is EMS memory used? */
            {
                /* try to allocate EMS memory for track */
                if ( (error = emsAlloc(trackLen, (emsBlock**) &p)) != OK )
                {
                    /* failed - if only EMS memory should be used, or the
                       error is other than out of EMS memory, pass the error
                       on */
                    if ( (forceEMS == 1) || (error != errOutOfEMS) )
                        MODLOADPASSERROR
                    else
                    {
                        /* track not in EMS */
                        mmod->pattEMS[i * chans + c] = 0;

                        /* try to allocate conventional memory instead */
                        if ( (error = memAlloc(trackLen, &p)) != OK )
                            MODLOADPASSERROR
                        pattData = p;
                    }
                }
                else
                {
                    /* EMS memory allocated succesfully - track in EMS */
                    mmod->pattEMS[i * chans + c] = 1;

                    /* map EMS block to conventional memory and point pattData
                       to the memory area: */
                    if ( (error = emsMap((emsBlock*) p, (void**) &pattData))
                        != OK )
                        MODLOADPASSERROR
                }
            }
            else
            {
                /* EMS memory not in use - allocate conventional memory */
                mmod->pattEMS[i * chans + c] = 0;

                if ( (error = memAlloc(trackLen, &p)) != OK )
                    MODLOADPASSERROR

                pattData = p;
            }

            mmod->patterns[i * chans + c] = p;

            /* copy track data from buffer to the correct memory area */
            CopyMem(pattData, trackBuf, trackLen);
        }

        foffset += chans * 256;         /* point foffset to next pattern */
    }

    /* deallocate pattern loading buffers: */
    if ( (error = memFree(trackBuf)) != OK )
        MODLOADPASSERROR
    trackBuf = NULL;

    if ( (error = memFree(pattBuf)) != OK )
        MODLOADPASSERROR
    pattBuf = NULL;


    /* If EMS is used, allocate TEMPSIZE bytes of memory before the sample
       buffer and deallocate it after allocating the sample buffer to
       minimize memory fragmentation */
    if ( useEMS )
    {
        if ( (error = memAlloc(TEMPSIZE, &tempmem)) != OK )
            MODLOADPASSERROR
    }

    /* allocate memory for sample loading buffer: */
    if ( (error = memAlloc(maxSmpLength, (void**) &smpBuf)) != OK )
        MODLOADPASSERROR

    if ( useEMS )
    {
        if ( (error = memFree(tempmem)) != OK )
            MODLOADPASSERROR
        tempmem = NULL;
    }


    /* point file offset to start of samples */
    foffset = (ulong) (chans * 256) * (ulong) numPatts + sizeof(modHeader);

    for ( i = 0; i < mmod->numInsts; i++ )
    {
        inst = &mmod->insts[i];          /* point inst to current instrument
                                            structure */

        modi = &modh.instruments[i];    /* point modi to current Protracker
                                            module instrument */

        /* Convert sample length, loop start and loop end. They are stored
           as big-endian words, and refer to number of words instead of
           bytes */
        slength = 2 * SWAP16(modi->slength);
        loopStart = 2 * SWAP16(modi->loopStart);
        loopLength = 2 * SWAP16(modi->loopLength);

        CopyMem(&inst->iname[0], &modi->iname[0], 22);  /* copy inst name */
        inst->iname[22] = 0;            /* force terminating '\0' */
        inst->loopStart = loopStart;    /* copy sample loop start */
        inst->loopEnd = loopStart + loopLength; /* sample loop end */

        /* If sample loop end is past byte 2, the sample is looping
           (Protracker uses loop start = 0, length = 2 for no loop,
           Fasttracker start = 0, end = 0 */
        if (inst->loopEnd > 2)
        {
            inst->looping = 1;
            inst->length = inst->loopEnd;  /* use loop end as sample length */
        }                               /* if looping to avoid loading */
        else                            /* unnecessary sample data */
        {
            inst->looping = 0;
            inst->loopEnd = 0;          /* set loop end to 0 if no loop */
            inst->length = slength;     /* use sample length */
        }

        inst->volume = modi->volume;        /* copy default volume */
        inst->finetune = modi->finetune;    /* copy finetune */

        if (mmod->instsUsed[i] == 1)        /* if not used, don't load */
        {
            if ( inst->length != 0 )        /* is there a sample for this inst? */
            {
                /* seek to sample start position: */
                if ( (error = fileSeek(f, foffset, fileSeekAbsolute)) != OK )
                    MODLOADPASSERROR

                /* read sample to buffer: */
                if ( (error = fileRead(f, smpBuf, inst->length)) != OK )
                    MODLOADPASSERROR
            }

            /* Point inst->sample to NULL, as the instrument is not available
               - only the Sound Device has it */
            inst->sample = NULL;

            /* convert sample from signed to unsigned: */
            if ( (error = modConvertSample(smpBuf, inst->length)) != OK )
                MODLOADPASSERROR

            /* add the instrument to Sound Device: */
            error = SD->AddInstrument(smpBuf, smp8bit, inst->length,
                inst->loopStart, inst->loopEnd, inst->volume, inst->looping,
                &inst->sdInstHandle);
            if ( error != OK )
                MODLOADPASSERROR

            #ifdef REALVUMETERS
            /* if real VU meters are used, prepare VU meter information
                for this instrument */
            if ( realVU )
            {
                if ( (error = vuPrepare(inst->sdInstHandle, smpBuf, inst->length,
                    inst->loopStart, inst->loopEnd)) != OK )
                    MODLOADPASSERROR
            }
            #endif
        }
        foffset += slength;             /* point foffset to next sample */
    }

    /* deallocate sample loading buffer: */
    if ( (error = memFree(smpBuf)) != OK )
        MODLOADPASSERROR
    smpBuf = NULL;


    if ( (error = fileClose(f)) != OK )
        MODLOADPASSERROR
    fileOpened = 0;

    *module = mmod;                     /* return module ptr in *module */
    return OK;
}
