/*      S3MLOAD.C
 *
 * Scream Tracker 3 Module loader
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
#include "s3m.h"
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




/* Size of temporary memory area used for avoiding memory fragmentation
   if EMS is used */
#define TEMPSIZE 8192

/* Pass error code in variable "error" on, used in s3mLoadModule(). */
#define S3MLOADPASSERROR { s3mLoadError(SD); PASSERROR(ID_s3mLoadModule) }




/****************************************************************************\
*       Module loader buffers and file pointer. These variables are static
*       instead of local so that a separate deallocation can be used which
*       will be called before exiting in error situations
\****************************************************************************/
static fileHandle f;
static int      fileOpened;
static mpModule *ms3m;
static ushort   *instPtrs;
static ushort   *pattPtrs;
static uchar    *smpBuf;
static void     *tempmem;





/****************************************************************************\
*
* Function:     int s3mFreeModule(mpModule *module, SoundDevice *SD);
*
* Description:  Deallocates a Scream Tracker 3 module
*
* Input:        mpModule *module        module to be deallocated
*               SoundDevice *SD         Sound Device that has stored the
*                                       samples
*
* Returns:      MIDAS error code
*
\****************************************************************************/

int CALLING s3mFreeModule(mpModule *module, SoundDevice *SD)
{
    int         i, error;

    if ( module == NULL )               /* valid module? */
    {
        ERROR(errUndefined, ID_s3mFreeModule);
        return errUndefined;
    }


    /* deallocate pattern orders if allocated: */
    if ( module->orders != NULL )
        if ( (error = memFree(module->orders)) != OK )
            PASSERROR(ID_s3mFreeModule)

    /* deallocate sample used flags: */
    if ( module->instsUsed != NULL )
        if ( (error = memFree(module->instsUsed)) != OK )
            PASSERROR(ID_s3mFreeModule)


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
                    PASSERROR(ID_s3mFreeModule)
            }
            else
                if ( module->insts[i].sample != NULL )
                    if ( (error = memFree(module->insts[i].sample)) != OK )
                        PASSERROR(ID_s3mFreeModule)

            #ifdef REALVUMETERS
            /* remove VU meter information if used: */
            if ( realVU )
            {
                if (module->insts[i].sdInstHandle != 0)
                    if ( (error = vuRemove(module->insts[i].sdInstHandle))
                        != OK )
                        PASSERROR(ID_s3mFreeModule)
            }
            #endif

        }
        /* deallocate instrument structures: */
        if ( (error = memFree(module->insts)) != OK )
            PASSERROR(ID_s3mFreeModule)
    }

    if ( (module->patterns != NULL) && (module->pattEMS != NULL) )
    {
        for ( i = 0; i < module->numPatts; i++ )
        {
            /* if the pattern has been allocate, deallocate it - either
                from conventional memory or from EMS */
            if ( module->patterns[i] != NULL )
            {
                if ( module->pattEMS[i] == 1 )
                {
                    if ( (error = emsFree((emsBlock*) module->patterns[i]))
                        != OK )
                        PASSERROR(ID_s3mFreeModule)
                }
                else
                    if ( (error = memFree(module->patterns[i])) != OK )
                        PASSERROR(ID_s3mFreeModule)
            }
        }
        /* deallocate pattern pointers: */
        if ( (error = memFree(module->patterns)) != OK )
            PASSERROR(ID_s3mFreeModule)

        /* deallocate pattern EMS flags: */
        if ( (error = memFree(module->pattEMS)) != OK )
            PASSERROR(ID_s3mFreeModule)
    }

    /* deallocate the module: */
    if ( (error = memFree(module)) != OK)
        PASSERROR(ID_s3mFreeModule)

    return OK;
}




/****************************************************************************\
*
* Function:     void s3mLoadError(SoundDevice *SD)
*
* Description:  Stops loading the module, deallocates all buffers and closes
*               the file.
*
* Input:        SoundDevice *SD         Sound Device that has been used for
*                                       loading.
*
\****************************************************************************/

static void s3mLoadError(SoundDevice *SD)
{
    /* Close file if opened. Do not process errors. */
    if ( fileOpened )
        if ( fileClose(f) != OK )
            return;

    /* Attempt to deallocate module if allocated. Do not process errors. */
    if ( ms3m != NULL )
        if ( s3mFreeModule(ms3m, SD) != OK )
            return;

    /* Deallocate buffers if allocated. Do not process errors. */
    if ( smpBuf != NULL )
        if ( memFree(smpBuf) != OK )
            return;
    if ( tempmem != NULL )
        if ( memFree(tempmem) != OK )
            return;
    if ( instPtrs != NULL )
        if ( memFree(instPtrs) != OK )
            return;
    if ( pattPtrs != NULL )
        if ( memFree(pattPtrs) != OK )
            return;
}




/****************************************************************************\
*
* Function:     int s3mLoadModule(char *fileName, SoundDevice *SD,
*                   mpModule **module);
*
* Description:  Loads a Scream Tracker 3 module into memory
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

int CALLING s3mLoadModule(char *fileName, SoundDevice *SD, mpModule **module)
{
    s3mHeader   s3mh;
    s3mInstHdr  s3mi;
    int         i;
    mpInstrument   *inst;
    ushort      pattSize;
    mpPattern   *pattData;
    ushort      lend;
    ulong       maxSmpLength;
    int         error;
    unsigned    ordersize;
    void        *p;

    /* point buffers to NULL and set fileOpened to 0 so that modLoadError()
       can be called at any point: */
    fileOpened = 0;
    ms3m = NULL;
    instPtrs = NULL;
    pattPtrs = NULL;
    smpBuf = NULL;
    tempmem = NULL;


    /* Open module file: */
    if ( (error = fileOpen(fileName, fileOpenRead, &f)) != OK )
        S3MLOADPASSERROR

    /* Allocate memory for the module structure: */
    if ( (error = memAlloc(sizeof(mpModule), (void**) &ms3m)) != OK )
        S3MLOADPASSERROR

    ms3m->orders = NULL;                 /* clear module structure so that */
    ms3m->insts = NULL;                  /* it can be deallocated with */
    ms3m->patterns = NULL;               /* s3mFree() at any point */
    ms3m->pattEMS = NULL;
    ms3m->instsUsed = NULL;

    /* Read .S3M file header: */
    if ( (error = fileRead(f, &s3mh, sizeof(s3mHeader))) != OK )
        S3MLOADPASSERROR

    /* Check the "SCRM" signature in header: */
    if ( !CompMem(&s3mh.SCRM[0], "SCRM", 4) )
    {
        ERROR(errInvalidModule, ID_s3mLoadModule);
        s3mLoadError(SD);
        return errInvalidModule;
    }

    CopyMem(&ms3m->ID[0], &s3mh.SCRM[0], 4);    /* copy ID */
    ms3m->IDnum = idS3M;                 /* S3M module ID */

    CopyMem(&ms3m->songName[0], &s3mh.name[0], 28); /* copy song name */
    ms3m->songLength = s3mh.songLength;         /* copy song length */
    ms3m->numInsts = s3mh.numInsts;      /* copy number of instruments */
    ms3m->numPatts = s3mh.numPatts;      /* copy number of patterns */
    CopyMem(&ms3m->flags, &s3mh.flags, sizeof s3mh.flags);/* copy S3M flags */
    ms3m->masterVol = s3mh.masterVol;    /* copy master volume */
    ms3m->speed = s3mh.speed;            /* copy initial speed */
    ms3m->tempo = s3mh.tempo;            /* copy initial BPM tempo */
    ms3m->masterMult = s3mh.masterMult & 15;     /* copy master multiplier */
    ms3m->stereo = (s3mh.masterMult >> 4) & 1;   /* copy stereo flag */
    /* copy channel settings: */

    for (i = 0; i < 32; i++)
    {
        if (s3mh.chanSettings[i] > 16)
            ms3m->chanSettings[i] = 0;
        else
            if (s3mh.chanSettings[i] < 8)
                ms3m->chanSettings[i] = -64;
            else
                ms3m->chanSettings[i] = 64;
    }


    /* Allocate memory for pattern orders: (length of pattern orders must be
       even) */
    ordersize = 2 * ((ms3m->songLength+1) / 2);
    if ( (error = memAlloc(ordersize, (void**) &ms3m->orders)) != OK )
        S3MLOADPASSERROR

    /* Read pattern orders from file: */
    if ( (error = fileRead(f, ms3m->orders, ordersize)) != OK )
        S3MLOADPASSERROR

    /* Calculate real song length: (exclude 0xFF bytes from end) */
    for ( i = (ms3m->songLength - 1); ms3m->orders[i] == 0xFF; i-- );
    ms3m->songLength = i + 1;

    if (!ms3m->songLength)
    {
        ERROR(errInvalidModule, ID_s3mLoadModule);
        s3mLoadError(SD);
        return errInvalidModule;
    }

    /* Allocate memory for instrument structures: */
    if ( (error = memAlloc(ms3m->numInsts * sizeof(mpInstrument),
        (void**) &ms3m->insts)) != OK )
        S3MLOADPASSERROR

    /* Clear all instruments: */
    for ( i = 0; i < ms3m->numInsts; i++ )
    {
        ms3m->insts[i].sample = NULL;
        ms3m->insts[i].sdInstHandle = 0;
    }


    /* Allocate memory for instrument paragraph pointers: */
    if ( (error = memAlloc(2 * ms3m->numInsts, (void**) &instPtrs)) != OK )
        S3MLOADPASSERROR

    /* Read instrument pointers: */
    if ( (error = fileRead(f, instPtrs, 2 * ms3m->numInsts)) != OK )
        S3MLOADPASSERROR

    /* Allocate memory for S3M file pattern pointers: */
    if ( (error = memAlloc(2 * ms3m->numPatts, (void**) &pattPtrs)) != OK )
        S3MLOADPASSERROR

    /* Read pattern pointers: */
    if ( (error = fileRead(f, pattPtrs, 2 * ms3m->numPatts)) != OK )
        S3MLOADPASSERROR

    /* Allocate memory for pattern pointers: */
    if ( (error = memAlloc(ms3m->numPatts * sizeof(mpPattern*), (void**)
        &ms3m->patterns)) != OK )
        S3MLOADPASSERROR

    /* Allocate memory for pattern EMS flags: */
    if ( (error = memAlloc(ms3m->numPatts, (void**) &ms3m->pattEMS)) != OK )
        S3MLOADPASSERROR

    for ( i = 0; i < ms3m->numPatts; i++ ) /* point all unallocated patterns */
        ms3m->patterns[i] = NULL;          /* to NULL for safety */

    /* Read all patterns to memory: */
    for ( i = 0; i < ms3m->numPatts; i++ )
    {
        if(pattPtrs[i] != NULL)
        {
            /* Seek to pattern beginning in file: */
            if ( (error = fileSeek(f, 16L * pattPtrs[i], fileSeekAbsolute))
                != OK )
                S3MLOADPASSERROR

            /* Read pattern length from file: */
            if ( (error = fileRead(f, &pattSize, 2)) != OK )
                S3MLOADPASSERROR

            if ( useEMS == 1 )
            {
                /* Try to allocate EMS memory for pattern: */
                if ( (error = emsAlloc(pattSize+2, (emsBlock**) &p)) != OK )
                {
                    /* failed - if only EMS memory should be used, or the
                       error is other than out of EMS memory, pass the error
                       on */
                    if ( (forceEMS == 1) || (error != errOutOfEMS) )
                        S3MLOADPASSERROR
                    else
                    {
                        /* pattern not in EMS: */
                        ms3m->pattEMS[i] = 0;

                        /* try to allocate conventional memory instead: */
                        if ( (error = memAlloc(pattSize+2, (void**) &p)) != OK )
                            S3MLOADPASSERROR
                    }
                }
                else
                {
                    /* Pattern is in EMS - map pattern EMS block to conventional
                        memory and point pattData to it */
                    ms3m->pattEMS[i] = 1;

                    /* map EMS block to conventional memory and point pattData
                        to the memory area: */
                    if ( (error = emsMap((emsBlock*) p, (void**) &pattData))
                        != OK )
                        S3MLOADPASSERROR
                }
            }
            else
            {
                /* No EMS memory used - allocate conventional memory for
                    pattern: */
                ms3m->pattEMS[i] = 0;

                if ( (error = memAlloc(pattSize+2, (void**) &p)) != OK )
                    S3MLOADPASSERROR

                pattData = p;
            }


            ms3m->patterns[i] = p;

            pattData->length = pattSize;    /* save pattern length */

            /* Read pattern data from file: */
            if ( (error = fileRead(f, &pattData->data[0], pattSize)) != OK )
                S3MLOADPASSERROR
        }
    }

    /* deallocate pattern file pointers: */
    if ( (error = memFree(pattPtrs)) != OK )
        S3MLOADPASSERROR
    pattPtrs = NULL;

    /* detect number of channels: */
    if ( (error = s3mDetectChannels(ms3m, &ms3m->numChans)) != OK )
        S3MLOADPASSERROR

    /* allocate memory for instrument used flags: */
    if ( (error = memAlloc(ms3m->numInsts, (void **) &ms3m->instsUsed))
        != OK )
        S3MLOADPASSERROR

    /* find which instruments are used: */
    if ( (error = s3mFindUsedInsts(ms3m, ms3m->instsUsed)) != OK )
        S3MLOADPASSERROR

    /* Find maximum sample length: */
    maxSmpLength = 0;
    for ( i = 0; i < ms3m->numInsts; i++ )
    {
        /* Seek to instrument header in file: */
        if ( (error = fileSeek(f, 16L * instPtrs[i], fileSeekAbsolute))
            != OK )
            S3MLOADPASSERROR

        /* Read instrument header from file: */
        if ( (error = fileRead(f, &s3mi, sizeof(s3mInstHdr))) != OK )
            S3MLOADPASSERROR

        if ( maxSmpLength < s3mi.length )
            maxSmpLength = s3mi.length;
    }

    /* Check that no instrument is too long: */
    if ( maxSmpLength > SMPMAX )
    {
        ERROR(errInvalidInst, ID_s3mLoadModule);
        s3mLoadError(SD);
        return errInvalidInst;
    }

    /* If EMS is used, allocate TEMPSIZE bytes of memory before the sample
       buffer and deallocate it after allocating all temporary loading
       buffers to minimize memory fragmentation */
    if ( useEMS )
    {
        if ( (error = memAlloc(TEMPSIZE, &tempmem)) != OK )
            S3MLOADPASSERROR
    }


    /* allocate memory for sample loading buffer: */
    if ( (error = memAlloc(maxSmpLength, (void**) &smpBuf)) != OK )
        S3MLOADPASSERROR

    if ( useEMS )
    {
        if ( (error = memFree(tempmem)) != OK )
            S3MLOADPASSERROR
        tempmem = NULL;
    }

    for ( i = 0; i < ms3m->numInsts; i++ )
    {

        /* point inst to current instrument structure */
        inst = &ms3m->insts[i];

        /* Seek to instrument header in file: */
        if ( (error = fileSeek(f, 16 * instPtrs[i], fileSeekAbsolute))
            != OK )
            S3MLOADPASSERROR

        /* Read instrument header from file: */
        if ( (error = fileRead(f, &s3mi, sizeof(s3mInstHdr))) != OK )
            S3MLOADPASSERROR

        /* Check if the instrument is valid - not too long, not stereo,
           16-bit or packed */
        if ( (s3mi.length > SMPMAX) || ((s3mi.flags & 6) != 0) ||
            (s3mi.pack != 0) )
        {
            ERROR(errInvalidInst, ID_s3mLoadModule);
            s3mLoadError(SD);
            return errFileRead;
        }

        CopyMem(&inst->fileName[0], &s3mi.dosName[0], 13); /* copy filename */
        CopyMem(&inst->iname[0], &s3mi.iname[0], 28);  /* copy inst name */
        inst->length = s3mi.length;         /* copy sample length */
        inst->loopStart = s3mi.loopStart;   /* copy sample loop start */
        inst->loopEnd = s3mi.loopEnd;       /* copy sample loop end */
        inst->looping = s3mi.flags & 1;     /* copy looping status */
        inst->volume = s3mi.volume;         /* copy default volume */
        inst->c2Rate = s3mi.c2Rate;         /* copy C2 playing rate */

        /* Make sure that instrument volume is < 63 */
        if ( inst->volume > 63 )
            inst->volume = 63;

        /* Check if instrument is used: */
        if ( ms3m->instsUsed[i] == 1 )
        {
            /* Instrument is used - check if there is a sample for this
               instrument - type = 1, signature "SCRS" and length != 0 */
            if ( (s3mi.type == 1) && CompMem(&s3mi.SCRS[0], "SCRS", 4)
                && (inst->length != 0) )
            {
                /* Seek to sample position in file: */
                if ( (error = fileSeek(f, 16L * s3mi.samplePtr,
                    fileSeekAbsolute)) != OK )
                    S3MLOADPASSERROR

                /* Read sample to loading buffer: */
                if ( (error = fileRead(f, smpBuf, inst->length)) != OK )
                    S3MLOADPASSERROR
            }

            /* Point inst->sample to NULL, as the instrument is not available
            - only the Sound Device has it */
            inst->sample = NULL;

            /* Add instrument to Sound Device: */
            error = SD->AddInstrument(smpBuf, smp8bit, inst->length,
                inst->loopStart, inst->loopEnd, inst->volume, inst->looping,
                &inst->sdInstHandle);
            if ( error != OK )
                S3MLOADPASSERROR

            #ifdef REALVUMETERS
            /* if real VU meters are used, prepare VU meter information
                for this instrument */
            if ( realVU )
            {
                if ( inst->looping )
                    lend = inst->loopEnd;
                else
                    lend = 0;           /* no looping - set VU loop end to
                                           zero */

                if ( (error = vuPrepare(inst->sdInstHandle, smpBuf, inst->length,
                    inst->loopStart, lend)) != OK )
                    S3MLOADPASSERROR
            }
            #endif
        }
    }

    /* deallocate instrument pointers: */
    if ( (error = memFree(instPtrs)) != OK )
        S3MLOADPASSERROR
    instPtrs = NULL;

    /* deallocate sample loading buffer: */
    if ( (error = memFree(smpBuf)) != OK )
        S3MLOADPASSERROR
    smpBuf = NULL;

    if ( (error = fileClose(f)) != OK )
        S3MLOADPASSERROR
    fileOpened = 0;

    *module = ms3m;                     /* return module pointer in *module */

    return OK;
}
