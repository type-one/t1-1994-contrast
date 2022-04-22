/*      MIDAS.C
 *
 * Simple MIDAS Sound System programming interface
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*/

#include <stdio.h>
#include <stdlib.h>
#include <conio.h>
#include <string.h>
#include "midas.h"



/****************************************************************************\
*      Global variables:
\****************************************************************************/

SoundDevice     *SD;                    /* current Sound Device */
ModulePlayer    *MP;                    /* current Module Player */

SoundDevice     *midasSoundDevices[NUMSDEVICES] =
    { &GUS,                             /* array of pointers to all Sound */
      &PAS,                             /* Devices, in numbering and */
      &WSS,                             /* detection order - GUS is SD #1 */
      &SB,                              /* and will be detected first */
      &NSND };

    /* pointers to all Module Players: */
ModulePlayer    *midasModulePlayers[NUMMPLAYERS] =
    { &mpS3M,
      &mpMOD };

    /* Amiga Loop Emulation flags for Module Players: */
short           midasMPALE[NUMMPLAYERS] =
    { 0, 1 };






/****************************************************************************\
*      Static variables used by midasXXXX() functions:
\****************************************************************************/

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





/****************************************************************************\
*
* Function:     void midasError(char *msg)
*
* Description:  Prints an MIDAS error message to stderr, uninitializes MIDAS
*               and exits to DOS
*
* Input:        char *msg               Pointer to error message string
*
\****************************************************************************/

void midasError(char *msg)
{
    textmode(C80);
    fprintf(stderr, "MIDAS Error: %s\n", msg);
#ifdef DEBUG
    errPrintList();                     /* print error list */
#endif
    midasClose();
    exit(EXIT_FAILURE);
}




/****************************************************************************\
*
* Function:     void midasUninitError(char *msg)
*
* Description:  Prints an error message to stderr and exits to DOS without
*               uninitializing MIDAS. This function should only be used
*               from midasClose();
*
* Input:        char *msg               Pointer to error message string
*
\****************************************************************************/

void midasUninitError(char *msg)
{
    textmode(C80);
    fprintf(stderr, "FATAL: MIDAS uninitialization error: %s\n", msg);
#ifdef DEBUG
    errPrintList();                     /* print error list */
#endif
    abort();
}




/****************************************************************************\
*
* Function:     void midasDetectSD(void)
*
* Description:  Attempts to detect a Sound Device. Sets the global variable
*               SD to point to the detected Sound Device or NULL if no
*               Sound Device was detected
*
\****************************************************************************/

void midasDetectSD(void)
{
    int         dsd;
    int         dResult;
    int         error;

    SD = NULL;                          /* no Sound Device detected yet */
    dsd = 0;                            /* start from first Sound Device */

    /* search through Sound Devices until a Sound Device is detected: */
    while ( (SD == NULL) && (dsd < NUMSDEVICES) )
    {
        /* attempt to detect current SD: */
        if ( (error = (*midasSoundDevices[dsd]->Detect)(&dResult)) != OK )
            midasError(errorMsg[error]);
        if ( dResult == 1 )
        {
            sdNum = dsd;                /* Sound Device detected */
            SD = midasSoundDevices[dsd]; /* point SD to this Sound Device */
        }
        dsd++;                          /* try next Sound Device */
    }
}




/****************************************************************************\
*
* Function:     void midasInit(void);
*
* Description:  Initializes MIDAS Sound System
*
\****************************************************************************/

void midasInit(void)
{
    int         error, result;

    if ( !disableEMS )                  /* is EMS usage disabled? */
    {
        /* Initialize EMS Heap Manager: */
        if ( (error = emsInit(&emsInitialized)) != OK )
            midasError(errorMsg[error]);

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
        midasDetectSD();               /* attempt to detect Sound Device */
        if ( SD == NULL )
            midasError("Unable to detect Sound Device");
    }
    else
    {
        SD = midasSoundDevices[sdNum];  /* use Sound Device sdNum */

        /* Sound Device number was forced, but if no I/O port, IRQ or DMA
           number has been set, try to autodetect the values for this Sound
           Device. If detection fails, use default values */

        if ( (ioPort == 0xFFFF) && (IRQ == 0xFF) && (DMA == 0xFF) )
        {
            if ( (error = SD->Detect(&result)) != OK )
                midasError(errorMsg[error]);
            if ( result != 1 )
                midasError("Unable to detect Sound Device values");
        }
    }

    if ( ioPort != 0xFFFF )             /* has an I/O port been set? */
        SD->port = ioPort;              /* if yes, set it to Sound Device */
    if ( IRQ != 0xFF )                  /* what about IRQ number? */
        SD->IRQ = IRQ;
    if ( DMA != 0xFF )                  /* or DMA channel number */
        SD->DMA = DMA;

    /* initialize TempoTimer: */
    if ( (error = tmrInit()) != OK )
        midasError(errorMsg[error]);

    tmrInitialized = 1;                 /* TempoTimer initialized */

    /* initialize Sound Device: */
    if ( (error = SD->Init(mixRate, mode)) != OK )
        midasError(errorMsg[error]);

    sdInitialized = 1;                  /* Sound Device initialized */

#ifdef REALVUMETERS
    if ( realVU )
    {
        /* initialize real VU-meters: */
        if ( (error = vuInit()) != OK )
            midasError(errorMsg[error]);

        vuInitialized = 1;
    }
#endif
}



/****************************************************************************\
*
* Function:     void midasClose(void)
*
* Description:  Uninitializes MIDAS Sound System
*
\****************************************************************************/

void midasClose(void)
{
    int         error;

    /* if Module Player interrupt is running, remove it: */
    if ( mpInterrupt )
    {
        if ( (error = MP->RemoveInterrupt()) != OK )
            midasUninitError(errorMsg[error]);
        mpInterrupt = 0;
    }

    /* if Module Player is playing, stop it: */
    if ( mpPlay )
    {
        if ( (error = MP->StopModule()) != OK )
            midasUninitError(errorMsg[error]);
        mpPlay = 0;
    }

    /* if Module Player has been initialized, uninitialize it: */
    if ( mpInit )
    {
        if ( (error = MP->Close()) != OK )
            midasUninitError(errorMsg[error]);
        mpInit = 0;
        MP = NULL;
    }

#ifdef REALVUMETERS
    /* if real VU-meters have been initialized, uninitialize them: */
    if ( vuInitialized )
    {
        if ( (error = vuClose()) != OK )
            midasUninitError(errorMsg[error]);
        vuInitialized = 0;
    }
#endif

    /* if Sound Device channels are open, close them: */
    if ( sdChOpen )
    {
        if ( (error = SD->CloseChannels()) != OK )
            midasUninitError(errorMsg[error]);
        sdChOpen = 0;
    }

    /* if Sound Device is initialized, uninitialize it: */
    if ( sdInitialized )
    {
        if ( (error = SD->Close()) != OK )
            midasUninitError(errorMsg[error]);
        sdInitialized = 0;
        SD = NULL;
    }

    /* if TempoTimer is initialized, uninitialize it: */
    if ( tmrInitialized )
    {
        if ( (error = tmrClose()) != OK )
            midasUninitError(errorMsg[error]);
        tmrInitialized = 0;
    }

    /* if EMS Heap Manager is initialized, uninitialize it: */
    if ( emsInitialized )
    {
        if ( (error = emsClose()) != OK )
            midasUninitError(errorMsg[error]);
        emsInitialized = 0;
    }
}




/****************************************************************************\
*
* Function:     void midasSetDefaults(void)
*
* Description:  Initializes MIDAS Sound System variables to their default
*               states. MUST be the first MIDAS function called.
*
\****************************************************************************/

void midasSetDefaults(void)
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
    realVU = 0; /*1; disabled */        /* enable real VU-meters */

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
* Function:     void midasParseOption(char *option)
*
* Description:  Parses one MIDAS command line option.
*
* Input:        char *option            Command line option string WITHOUT
*                                       the leading '-' or '/'.
*
* Recognized options:
*       -sx     Force Sound Device x (1 = GUS, 2 = PAS, 3 = WSS, 4 = SB,
*               5 = No Sound)
*       -pxxx   Force I/O port xxx (hex) for Sound Device
*       -ix     Force IRQ x for Sound Device
*       -dx     Force DMA channel x for Sound Device
*       -mxxxx  Set mixing rate to xxxx Hz
*       -oxxx   Force output mode (8 = 8-bit, 1 = 16-bit, s = stereo,
*               m = mono, h = high quality, n = normal quality, l = low quality)
*       -e      Disable EMS usage
*       -t      Disable ProTracker BPM tempos
*       -u      Enable Surround sound
*       -v      Disable real VU-meters
*
\****************************************************************************/

void midasParseOption(char *option)
{
    int         c;
    char        *opt;

    opt = &option[1];
    switch ( option[0] )
    {
        /* -sx     Force Sound Device x */
        case 's':
            sdNum = atoi(opt) - 1;
            if ( sdNum >= NUMSDEVICES )
                midasError("Illegal Sound Device number");
            break;

        /* -pxxx   Force I/O port xxx (hex) for Sound Device */
        case 'p':
            sscanf(opt, "%X", &ioPort);
            break;

        /* -ix     Force IRQ x for Sound Device */
        case 'i':
            IRQ = atoi(opt);
            break;

        /* -dx     Force DMA channel x for Sound Device */
        case 'd':
            DMA = atoi(opt);
            break;

        /* -mxxxx  Set mixing rate to xxxx Hz */
        case 'm':
            mixRate = atol(opt);
            if ( mixRate < 1 )
                midasError("Invalid mixing rate");
            break;

        /* -e      Disable EMS usage */
        case 'e':
            disableEMS = 1;
            break;

        /* -t      Disable ProTracker BPM tempos */
        case 't':
            ptTempo = 0;
            break;

        /* -u      Enable Surround sound */
        case 'u':
            surround = 1;
            break;

        /* -oxxx   Force output mode */
        case 'o':
            for ( c = 0; c < strlen(opt); c++ )
            {
                switch( opt[c] )
                {
                    /* Output mode '8' - 8-bit */
                    case '8':
                        mode |= sd8bit;
                        mode &= 0xFFFF ^ sd16bit;
                        break;

                    /* Output mode '1' - 16-bit */
                    case '1':
                        mode |= sd16bit;
                        mode &= 0xFFFF ^ sd8bit;
                        break;

                    /* Output mode 'm' - mono */
                    case 'm':
                        mode |= sdMono;
                        mode &= 0xFFFF ^ sdStereo;
                        break;

                    /* Output mode 's' - stereo */
                    case 's':
                        mode |= sdStereo;
                        mode &= 0xFFFF ^ sdMono;
                        break;

                    /* bonus by Type One */
                    /* Output mode 'h' - high quality */
                    case 'h':
                        mode |= sdHighQ;
                        mode &= 0xFFFF ^ (sdLowQ | sdNormalQ);
                        break;

                    /* Output mode 'n' - normal quality */
                    case 'n' :
                        mode |= sdNormalQ;
                        mode &= 0xFFFF ^ (sdHighQ | sdLowQ);
                        break;

                    /* Output mode 'l' - low quality */
                    case 'l' :
                        mode |= sdLowQ;
                        mode &= 0xFFFF ^ (sdHighQ | sdNormalQ);
                        break;

                    default:
                        midasError("Invalid output mode character");
                        break;
                }
            }
            break;

        /* -v      Disable real VU-meters */
        case 'v':
            realVU = 0;
            break;

        case 'w':
        case 'g':
            break; /* used in CONTRAST demo :-) */

        default:
            midasError("Unknown option character");
            break;
    }
}




/****************************************************************************\
*
* Function:     void midasParseOptions(int optCount, char **options)
*
* Description:  Parses MIDAS command line options and sets MIDAS variables
*               accordingly.
*
* Input:        int optCount            Number of options
*               char **options          Pointer to an array of pointers to
*                                       option strings.
*
* Also '/' is recognized as a option delimiter.
*
\****************************************************************************/

void midasParseOptions(int optCount, char **options)
{
    int         i;

    for ( i = 0; i < optCount; i++ )
    {
        if ( ( options[i][0] == '-' ) || ( options[i][0] == '/' )  )
            midasParseOption(&options[i][1]);
        else
            midasError("Invalid command line option");
    }
}




/****************************************************************************\
*
* Function:     void midasParseEnvironment(void)
*
* Description:  Parses the MIDAS environment string, which has same format
*               as the command line options.
*
\****************************************************************************/

void midasParseEnvironment(void)
{
    char        *envs, *midasenv, *opt;
    int         spos, slen, stopparse, error;

    /* try to get pointer to MIDAS environment string: */
    envs = getenv("MIDAS");

    if ( envs != NULL )
    {
        slen = strlen(envs);
        /* allocate memory for a copy of the environment string: */
        if ( (error = memAlloc(slen+1, (void**) &midasenv)) != OK )
            midasError(errorMsg[error]);

        /* copy environment string to midasenv: */
        strcpy(midasenv, envs);

        spos = 0;                       /* search position = 0 */
        opt = NULL;                     /* current option string = NULL */
        stopparse = 0;

        /* parse the whole environment string: */
        while ( !stopparse )
        {
            switch ( midasenv[spos] )
            {
                case ' ':
                    /* current character is space - change it to '\0' and
                       parse this option string if it exists*/
                    midasenv[spos] = 0;
                    if ( opt != NULL )
                        midasParseOption(opt);

                    opt = NULL;         /* no option string */
                    spos++;             /* next character */
                    break;

                case 0:
                    /* Current character is '\0' - end. Parse option string
                       if it exists and stop parsing. */
                    if ( (opt != NULL) && (*opt != 0) )
                        midasParseOption(opt);
                    stopparse = 1;
                    break;

                case '-':
                case '/':
                    /* Current character is '-' or '/' - option string starts
                       from next character */
                    spos++;
                    opt = &midasenv[spos];
                    break;

                default:
                    /* some normal character - continue parsing from next
                       character */
                    spos++;
            }
        }

        if ( (error = memFree(midasenv)) != OK )
            midasError(errorMsg[error]);
    }
}



/****************************************************************************\
*
* Function:     mpModule *midasPlayModule(char *fileName, int numEffectChns)
*
* Description:  Loads a module into memory, points MP to the correct Module
*               Player and starts playing it.
*
* Input:        char *fileName          Pointer to module file name
*               int numEffectChns       Number of channels to open for sound
*                                       effects.
*
* Returns:      Pointer to module structure. This function can not fail,
*               as it will call midasError() to handle all error cases.
*
* Notes:        The Sound Device channels available for sound effects are the
*               _first_ numEffectChns channels. So, for example, if you use
*               midasPlayModule("TUNE.MOD", 3), you can use channels 0-2 for
*               sound effects.
*
\****************************************************************************/

mpModule *midasPlayModule(char *fileName, int numEffectChns)
{
    uchar       *header;
    fileHandle  f;
    mpModule    *module;
    short       numChans;
    int         error, mpNum, recognized;

    if ( (error = memAlloc(MPHDRSIZE, (void**) &header)) != OK )
        midasError(errorMsg[error]);

    if ( (error = fileOpen(fileName, fileOpenRead, &f)) != OK )
        midasError(errorMsg[error]);

    /* read MPHDRSIZE bytes of module header: */
    if ( (error = fileRead(f, header, MPHDRSIZE)) != OK )
        midasError(errorMsg[error]);

    if ( (error = fileClose(f)) != OK )
        midasError(errorMsg[error]);

    /* Search through all Module Players to find one that recognizes
       file header: */
    mpNum = 0; MP = NULL;
    while ( (mpNum < NUMMPLAYERS) && (MP == NULL) )
    {
        if ( (error = midasModulePlayers[mpNum]->Identify(header,
            &recognized)) != OK )
            midasError(errorMsg[error]);
        if ( recognized )
        {
            MP = midasModulePlayers[mpNum];
            ALE = midasMPALE[mpNum];
        }
        mpNum++;
    }

    if ( MP == NULL )
        midasError("Unknown module format");

    /* deallocate module header: */
    if ( (error = memFree(header)) != OK )
        midasError(errorMsg[error]);

    /* initialize module player: */
    if ( (error = MP->Init(SD)) != OK )
        midasError(errorMsg[error]);
    mpInit = 1;

    /* load module: */
    if ( (error = MP->LoadModule(fileName, SD, (mpModule**) &module)) != OK )
        midasError(errorMsg[error]);

    numChans = module->numChans;

    /* open Sound Device channels: */
    if ( (error = SD->OpenChannels(numChans + numEffectChns)) != OK )
        midasError(errorMsg[error]);
    sdChOpen = 1;

    /* Start playing the module using Sound Device channels (numEffectChns) -
       (numEffectChns+numChans-1) and looping the whole song: */
    if ( (error = MP->PlayModule(module, numEffectChns, numChans, 0, 32767))
        != OK )
        midasError(errorMsg[error]);
    mpPlay = 1;

    /* start playing using the timer: */
    if ( (error = MP->SetInterrupt()) != OK )
        midasError(errorMsg[error]);

    return module;
}




/****************************************************************************\
*
* Function:     void midasStopModule(mpModule *module)
*
* Description:  Stops playing a module, deallocates it and uninitializes
*               the Module Player. Also closes _all_ Sound Device channels,
*               including those opened for effects.
*
\****************************************************************************/

void midasStopModule(mpModule *module)
{
    int         error;

    /* remove Module Player interrupt: */
    if ( (error = MP->RemoveInterrupt()) != OK )
        midasError(errorMsg[error]);
    mpInterrupt = 0;

    /* stop playing the module: */
    if ( (error = MP->StopModule()) != OK )
        midasError(errorMsg[error]);
    mpPlay = 0;

    /* deallocate module: */
    if ( (error = MP->FreeModule(module, SD)) != OK )
        midasError(errorMsg[error]);

    /* uninitialize Module Player: */
    if ( (error = MP->Close()) != OK )
        midasError(errorMsg[error]);
    mpInit = 0;
    MP = NULL;                          /* point MP to NULL for safety */

    /* close Sound Device channels: */
    if ( (error = SD->CloseChannels()) != OK )
        midasError(errorMsg[error]);
    sdChOpen = 0;
}
