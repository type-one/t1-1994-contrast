/*      DBP.C
 *
 * MIDAS debug module player
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*/


/* Much of this code is simply copied from MIDAS.C, with some reorganization
   and conditional compilation for easier debugging */

#include <stdio.h>
#include <stdlib.h>
#include <conio.h>
#include <alloc.h>
#include "midas.h"


// #define USETIMER                        /* use timer for playing */
// #define HWSD                            /* hard-wired Sound Device pointer */
// #define HWMP                            /* hard-wired Module Player */


SoundDevice     *SD;                    /* current Sound Device */
ModulePlayer    *MP;                    /* current Module Player */

#ifndef HWSD
SoundDevice     *SoundDevices[NUMSDEVICES] =
    { &GUS,                             /* array of pointers to all Sound */
      &PAS,                             /* Devices, in numbering and */
      &WSS,                             /* detection order - GUS is SD #1 */
      &SB,                              /* and will be detected first */
      &NSND };
#endif

#ifndef HWMP
    /* pointers to all Module Players: */
ModulePlayer    *ModulePlayers[NUMMPLAYERS] =
    { &mpS3M,
      &mpMOD };

    /* Amiga Loop Emulation flags for Module Players: */
short           mpALE[NUMMPLAYERS] =
    { 0, 1 };

#endif


static int      disableEMS;             /* should EMS usage be disabled? */
static ushort   sdNum;                  /* Sound Device number (0xFFFF for
                                           autodetect) */
static ushort   ioPort;                 /* I/O port number (0xFFFF for
                                           autodetect/default) */
static uchar    IRQ;                    /* IRQ number (0xFF for autodetect/
                                           default) */
static uchar    DMA;                    /* DMA channel number (0xFF for
                                           autodetect/default) */
static ushort   mixRate;                /* mixing rate */
static ushort   mode;                   /* forced output mode */

static int      emsInitialized;         /* is EMS heap manager initialized? */
static int      tmrInitialized;         /* is TempoTimer initialized? */
static int      sdInitialized;          /* is Sound Device initialized? */
static int      sdChOpen;               /* are Sound Device channels open? */
static int      vuInitialized;          /* are real VU-meters initialized? */
static int      mpInit;                 /* is Module Player initialized? */
static int      mpPlay;                 /* is Module Player playing? */
static int      mpInterrupt;            /* is Module Player interrupt set? */


char *usage =
"USAGE:\tDBP\t<filename>\n";



void CloseMIDAS(void);


/****************************************************************************\
*
* Function:     void Error(char *msg)
*
* Description:  Prints an error message to stderr, uninitializes MIDAS and
*               exits to DOS
*
* Input:        char *msg               Pointer to error message string
*
\****************************************************************************/

void Error(char *msg)
{
    textmode(C80);
    fprintf(stderr, "Error: %s\n", msg);
#ifdef DEBUG
    errPrintList();                     /* print error list */
#endif
    CloseMIDAS();
    exit(EXIT_FAILURE);
}



/****************************************************************************\
*
* Function:     void UninitError(char *msg)
*
* Description:  Prints an error message to stderr and exits to DOS without
*               uninitializing MIDAS. This function should only be used
*               from CloseMIDAS();
*
* Input:        char *msg               Pointer to error message string
*
\****************************************************************************/

void UninitError(char *msg)
{
    textmode(C80);
    fprintf(stderr, "FATAL: Uninitialization error: %s\n", msg);
#ifdef DEBUG
    errPrintList();                     /* print error list */
#endif
    abort();
}


/****************************************************************************\
*
* Function:     void DetectSD(void)
*
* Description:  Attempts to detect a Sound Device. Sets the global variable
*               SD to point to the detected Sound Device or NULL if no
*               Sound Device was detected
*
\****************************************************************************/

void DetectSD(void)
{
    int         dsd;
    int         dResult;
    int         error;

#ifdef HWSD
    SD = &SB;                           /* use Pro Audio Spectrum */
    return;
#else

    SD = NULL;                          /* no Sound Device detected yet */
    dsd = 0;                            /* start from first Sound Device */

    /* search through Sound Devices until a Sound Device is detected: */
    while ( (SD == NULL) && (dsd < NUMSDEVICES) )
    {
        /* attempt to detect current SD: */
        if ( (error = (*SoundDevices[dsd]->Detect)(&dResult)) != OK )
            Error(errorMsg[error]);
        if ( dResult == 1 )
        {
            sdNum = dsd;                /* Sound Device detected */
            SD = SoundDevices[dsd];     /* point SD to this Sound Device */
        }
        dsd++;                          /* try next Sound Device */
    }
#endif
}



/****************************************************************************\
*
* Function:     void InitMIDAS(void);
*
* Description:  Initializes MIDAS Sound System
*
\****************************************************************************/

void InitMIDAS(void)
{
    int         error, result;

    emsInitialized = 0;                 /* EMS heap manager is not
                                           initialized yet */
    tmrInitialized = 0;                 /* TempoTimer is not initialized */
    sdInitialized = 0;                  /* Sound Device is not initialized */
    sdChOpen = 0;                       /* Sound Device channels are not
                                           open */
    vuInitialized = 0;                  /* VU meter are not initialized */
    mpInit = 0;                         /* Module Player is not initialized */
    mpPlay = 0;                         /* Module Player is not playing */
    mpInterrupt = 0;                    /* No Module Player interrupt */

    if ( !disableEMS )                  /* is EMS usage disabled? */
    {
        /* Initialize EMS Heap Manager: */
        if ( (error = emsInit(&emsInitialized)) != OK )
            Error(errorMsg[error]);

        /* was EMS Heap Manager initialized? */
        if ( emsInitialized == 1 )
        {
            useEMS = 1;                 /* yes, use EMS memory, but do not */
            forceEMS = 0;               /* force its usage */
        }
        else
        {
            useEMS = 0;                 /* no, do not use EMS memory */
            forceEMS = 0;
        }
    }
    else
    {
        useEMS = 0;                     /* EMS disabled - do not use it */
        forceEMS = 0;
    }


    if ( sdNum == 0xFFFF )             /* has a Sound Device been selected? */
    {
        DetectSD();                     /* attempt to detect Sound Device */
        if ( SD == NULL )
            Error("Unable to detect Sound Device");
    }
    else
    {
        #ifdef HWSD
        SD = &PAS;
        #else
        SD = SoundDevices[sdNum];       /* use Sound Device sdNum */
        #endif

        /* Sound Device number was forced, but if no I/O port, IRQ or DMA
           number has been set, try to autodetect the values for this Sound
           Device. If detection fails, use default values */

        if ( (ioPort == 0xFFFF) && (IRQ == 0xFF) && (DMA == 0xFF) )
            if ( (error = SD->Detect(&result)) != OK )
                Error(errorMsg[error]);
            if ( result != 1 )
                Error("Unable to detect Sound Device values");
    }

    if ( ioPort != 0xFFFF )             /* has an I/O port been set? */
        SD->port = ioPort;              /* if yes, set it to Sound Device */
    if ( IRQ != 0xFF )                  /* what about IRQ number? */
        SD->IRQ = IRQ;
    if ( DMA != 0xFF )                  /* or DMA channel number */
        SD->DMA = DMA;

#ifdef USETIMER
    /* initialize TempoTimer: */
    if ( (error = tmrInit()) != OK )    /* initialize TempoTimer */
        Error(errorMsg[error]);

    tmrInitialized = 1;                 /* TempoTimer initialized */
#endif

    /* initialize Sound Device: */
    if ( (error = SD->Init(mixRate, mode)) != OK )
        Error(errorMsg[error]);

    sdInitialized = 1;                  /* Sound Device initialized */

#ifdef REALVUMETERS
    if ( realVU )
    {
        /* initialize real VU-meters: */
        if ( (error = vuInit()) != OK )
            Error(errorMsg[error]);

        vuInitialized = 1;
    }
#endif
}



/****************************************************************************\
*
* Function:     void CloseMIDAS(void)
*
* Description:  Uninitializes MIDAS Sound System
*
\****************************************************************************/

void CloseMIDAS(void)
{
    int         error;

    /* Note that as this function has been added to atexit() chain, it may
       not cause the program to exit by, for example, calling midasError() */

#ifdef USETIMER
    /* if Module Player interrupt is running, remove it: */
    if ( mpInterrupt )
    {
        if ( (error = MP->RemoveInterrupt()) != OK )
            UninitError(errorMsg[error]);
        mpInterrupt = 0;
    }
#endif

    /* if Module Player is playing, stop it: */
    if ( mpPlay )
    {
        if ( (error = MP->StopModule()) != OK )
            UninitError(errorMsg[error]);
        mpPlay = 0;
    }

    /* if Module Player has been initialized, uninitialize it: */
    if ( mpInit )
    {
        if ( (error = MP->Close()) != OK )
            UninitError(errorMsg[error]);
        mpInit = 0;
        MP = NULL;
    }

#ifdef REALVUMETERS
    /* if real VU-meters have been initialized, uninitialize them: */
    if ( vuInitialized )
    {
        if ( (error = vuClose()) != OK )
            UninitError(errorMsg[error]);
        vuInitialized = 0;
    }
#endif

    /* if Sound Device channels are open, close them: */
    if ( sdChOpen )
    {
        if ( (error = SD->CloseChannels()) != OK )
            UninitError(errorMsg[error]);
        sdChOpen = 0;
    }

    /* if Sound Device is initialized, uninitialize it: */
    if ( sdInitialized )
    {
        if ( (error = SD->Close()) != OK )
            UninitError(errorMsg[error]);
        sdInitialized = 0;
        SD = NULL;
    }

    /* if TempoTimer is initialized, uninitialize it: */
    if ( tmrInitialized )
    {
        if ( (error = tmrClose()) != OK )
            UninitError(errorMsg[error]);
        tmrInitialized = 0;
    }

    /* if EMS Heap Manager is initialized, uninitialize it: */
    if ( emsInitialized )
    {
        if ( (error = emsClose()) != OK )
            UninitError(errorMsg[error]);
        emsInitialized = 0;
    }
}



/****************************************************************************\
*
* Function:     void SetDefaults(void)
*
* Description:  Initializes MIDAS Sound System variables to their default
*               states. MUST be the first MIDAS function called.
*
\****************************************************************************/

void SetDefaults(void)
{
    emsInitialized = 0;                 /* EMS heap manager is not
                                           initialized yet */
    tmrInitialized = 0;                 /* TempoTimer is not initialized */
    sdInitialized = 0;                  /* Sound Device is not initialized */
    sdChOpen = 0;                       /* Sound Device channels are not
                                           open */
    vuInitialized = 0;                  /* VU meter are not initialized */
    mpInit = 0;                         /* Module Player is not initialized */
    mpPlay = 0;                         /* Module Player is not playing */
    mpInterrupt = 0;                    /* No Module Player interrupt */


    ptTempo = 1;                        /* enable ProTracker BPM tempos */
    usePanning = 1;                     /* enable ProTracker panning cmds */
    surround = 0;                       /* disable surround to save GUS mem */
    realVU = 1;                         /* disable real VU-meters */

    disableEMS = 0;                     /* do not disable EMS usage */
    sdNum = 0x0FFFF;                    /* no Sound Device forced */
    ioPort = 0xFFFF;                    /* no I/O port forced */
    IRQ = 0xFF;                         /* no IRQ number forced */
    DMA = 0xFF;                         /* no DMA channel number forced */
    mode = 0;                           /* no output mode forced */
    mixRate = 44100;                    /* attempt to use 44100Hz mixing
                                           rate */

    SD = NULL;                          /* point SD and MP to NULL for */
    MP = NULL;                          /* safety */
}



/****************************************************************************\
*
* Function:     mpModule *PlayModule(char *fileName)
*
* Description:  Loads a module into memory, points MP to the correct Module
*               Player and starts playing it.
*
* Input:        char *fileName          Pointer to module file name
*
* Returns:      Pointer to module structure. This function can not fail,
*               as it will call Error() to handle all error situations.
*
\****************************************************************************/

mpModule *PlayModule(char *fileName)
{
    uchar       *header;
    FILE        *f;
    mpModule    *module;
    short       numChans;
    int         error, mpNum, recognized;

    if ( (error = memAlloc(MPHDRSIZE, (void**) &header)) != OK )
        Error(errorMsg[error]);

    if ( (f = fopen(fileName, "rb")) == NULL )
        Error("Unable to open module file");

    if ( fread(header, MPHDRSIZE, 1, f) != 1 )      /* read MPHDRSIZE bytes */
        Error("Unable to read module header");      /* of module header */

#ifdef HWMP
    MP = &mpS3M;
    ALE = 0;
#else

    /* Search through all Module Players to find one that recognizes
       file header: */
    mpNum = 0; MP = NULL;
    while ( (mpNum < NUMMPLAYERS) && (MP == NULL) )
    {
        if ( (error = ModulePlayers[mpNum]->Identify(header, &recognized))
            != OK )
            Error(errorMsg[error]);
        if ( recognized )
        {
            MP = ModulePlayers[mpNum];
            ALE = mpALE[mpNum];
        }
        mpNum++;
    }

    if ( MP == NULL )
        Error("Unknown module format");
#endif

    /* deallocate module header: */
    if ( (error = memFree(header)) != OK )
        Error(errorMsg[error]);
    fclose(f);

    /* initialize module player: */
    if ( (error = MP->Init(SD)) != OK )
        Error(errorMsg[error]);
    mpInit = 1;

    /* load module: */
    if ( (error = MP->LoadModule(fileName, SD, (mpModule**) &module)) != OK )
        Error(errorMsg[error]);

    numChans = module->numChans;

    /* open Sound Device channels: */
    if ( (error = SD->OpenChannels(numChans)) != OK )
        Error(errorMsg[error]);
    sdChOpen = 1;

    /* start playing module using first numChans channels and looping the
       whole song */
    if ( (error = MP->PlayModule(module, 0, numChans, 0, 32767)) != OK )
        Error(errorMsg[error]);
    mpPlay = 1;

#ifdef USETIMER
    /* start playing using the timer: */
    if ( (error = MP->SetInterrupt()) != OK )
        Error(errorMsg[error]);
#endif

    return module;
}


/****************************************************************************\
*
* Function:     void StopModule(mpModule *module)
*
* Description:  Stops playing a module, deallocates it and uninitializes
*               the Module Player.
*
\****************************************************************************/

void StopModule(mpModule *module)
{
    int         error;

#ifdef USETIMER
    /* remove Module Player interrupt: */
    if ( (error = MP->RemoveInterrupt()) != OK )
        Error(errorMsg[error]);
    mpInterrupt = 0;
#endif

    /* stop playing the module: */
    if ( (error = MP->StopModule()) != OK )
        Error(errorMsg[error]);
    mpPlay = 0;

    /* deallocate module: */
    if ( (error = MP->FreeModule(module, SD)) != OK )
        Error(errorMsg[error]);

    /* uninitialize Module Player: */
    if ( (error = MP->Close()) != OK )
        Error(errorMsg[error]);
    mpInit = 0;
    MP = NULL;                          /* point MP to NULL for safety */

    /* close Sound Device channels: */
    if ( (error = SD->CloseChannels()) != OK )
        Error(errorMsg[error]);
    sdChOpen = 0;
}



void WaitVR(void)
{
asm     mov     dx,03DAh
wvr:
asm {   in      al,dx
        test    al,8
        jz      wvr
}
}



void WaitDE(void)
{
asm     mov     dx,03DAh
wde:
asm {   in      al,dx
        test    al,1
        jnz     wde
}
}



void SetBorder(uchar color)
{
asm {   mov     dx,03C0h
        mov     al,31h
        out     dx,al
        mov     al,color
        out     dx,al
}
}


ulong           free1, free2;


void showheap(void)
{
    free2 = coreleft();
    cprintf("%lu bytes memory free - %lu bytes used.\r\n",
        free2, free1-free2);

    if ( heapcheck() != _HEAPOK )
        cputs("HEAP CORRUPTED - PREPARE FOR SYSTEM CRASH!\r\n");
}



int main(int argc, char *argv[])
{
    int         error;
    int         plMusic;
    mpModule    *module;


    if ( argc != 2 )
    {
        puts(usage);
        exit(EXIT_SUCCESS);
    }

    printf("%lu bytes free\n", free1 = coreleft());
    SetDefaults();
    InitMIDAS();
    showheap();
    module = PlayModule(argv[1]);
    puts("Playing - press any key to stop");
    showheap();

    while ( !kbhit() )
    {
#ifndef USETIMER
        WaitVR();
        WaitDE();
        SetBorder(15);
        if ( SD->tempoPoll == 1 )
        {
            if ( (error = SD->Play(&plMusic)) != OK )
                Error(errorMsg[error]);
            SetBorder(14);
            if ( (error = MP->Play()) != OK )
                Error(errorMsg[error]);
        }
        else
        {
            dmaGetPos(&dsmBuffer, &dsmDMAPos);
            if ( (error = SD->Play(&plMusic)) != OK )
                Error(errorMsg[error]);

            while ( plMusic )
            {
                SetBorder(14);
                if ( (error = MP->Play()) != OK )
                    Error(errorMsg[error]);
                SetBorder(15);
                if ( (error = SD->Play(&plMusic)) != OK )
                    Error(errorMsg[error]);
            }
        }
        SetBorder(0);
#endif
    }

    getch();
    StopModule(module);
    showheap();
    CloseMIDAS();
    showheap();

    return 0;
}
