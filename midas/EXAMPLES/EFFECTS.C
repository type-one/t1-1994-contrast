/*      EFFECTS.C
 *
 * Example on how to play simultaneous music and sound effects
 * using MIDAS Sound System
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
#include "midas.h"


/* number of sound effect channels: */
#define FXCHANNELS 2

/* sound effect playing rate: */
#define FXRATE 11050



char            *usage =
"Usage:\tEFFECTS\t<module> <effect #1> <effect #2> [options]\n\n"
"Options:\n"
"\t-sx\tForce Sound Device x (1 = GUS, 2 = PAS, 3 = WSS, 4 = SB,\n"
"\t\t5 = No Sound)\n"
"\t-pxxx\tForce I/O port xxx (hex) for Sound Device\n"
"\t-ix\tForce IRQ x for Sound Device\n"
"\t-dx\tForce DMA channel x for Sound Device\n"
"\t-mxxxxx\tSet mixing rate to xxxxx Hz\n"
"\t-e\tDisable EMS usage\n"
"\t-t\tDisable ProTracker BPM tempos\n"
"\t-u\tEnable Surround\n"
"\t-oxxx\tForce output mode (8 = 8-bit, 1 = 16-bit, s = stereo, m = mono)\n";


unsigned        fxChannel = 0;

extern ushort masterVolume;



/****************************************************************************\
*
* Function:     unsigned LoadEffect(char *fileName)
*
* Description:  Loads a raw effect sample that can be used with PlayEffect().
*
* Input:        char *fileName          name of sample file
*
* Returns:      Instrument handle that can be used with PlayEffect() and
*               FreeEffect().
*
\****************************************************************************/

unsigned LoadEffect(char *fileName)
{
    ushort      instHandle;             /* sound device instrument handle */
    int         error;
    fileHandle  f;
    long        smpLength;              /* sample length */
    uchar       *smpBuf;                /* sample loading buffer */

    /* open sound effect file: */
    if ( (error = fileOpen(fileName, fileOpenRead, &f)) != OK )
        midasError(errorMsg[error]);

    /* get file length: */
    if ( (error = fileGetSize(f, &smpLength)) != OK )
        midasError(errorMsg[error]);

    /* check that sample length is not too long: */
    if ( smpLength > SMPMAX )
        midasError("Effect sample too long");

    /* allocate memory for sample loading buffer: */
    if ( (error = memAlloc(smpLength, (void**) &smpBuf)) != OK )
        midasError(errorMsg[error]);

    /* load sample: */
    if ( (error = fileRead(f, smpBuf, smpLength)) != OK )
        midasError(errorMsg[error]);

    /* close sample file: */
    if ( (error = fileClose(f)) != OK )
        midasError(errorMsg[error]);

    /* Add sample to Sound Device list and get instrument handle to
       instHandle: */
    error = SD->AddInstrument(smpBuf, smp8bit, smpLength, 0, 0, 64, 0,
        &instHandle);
    if ( error != OK )
        midasError(errorMsg[error]);

    /* deallocate sample allocation buffer: */
    if ( (error = memFree(smpBuf)) != OK )
        midasError(errorMsg[error]);

    /* return instrument handle: */
    return instHandle;
}




/****************************************************************************\
*
* Function:     void FreeEffect(unsigned instHandle)
*
* Description:  Deallocates a sound effect
*
* Input:        unsigned instHandle     effect instrument handle returned by
*                                       LoadEffect()
*
\****************************************************************************/

void FreeEffect(unsigned instHandle)
{
    int         error;

    /* remove instrument from Sound Device list: */
    if ( (error = SD->RemInstrument(instHandle)) != OK )
        midasError(errorMsg[error]);
}




/****************************************************************************\
*
* Function:     void PlayEffect(ushort instHandle, ulong rate, ushort volume,
*                   short panning)
*
* Description:  Plays a sound effect
*
* Input:        ushort instHandle       effect instrument handle, returned by
*                                           LoadEffect().
*               ulong rate              effect sampling rate, in Hz
*               ushort volume           effect playing volume, 0-64
*               short panning           effect panning (see enum sdPanning in
*                                           SDEVICE.H)
*
\****************************************************************************/

void PlayEffect(ushort instHandle, ulong rate, ushort volume,
    short panning)
{
    int         error;

    /* set effect instrument to current effect channel: */
    if ( (error = SD->SetInstrument(fxChannel, instHandle)) != OK )
        midasError(errorMsg[error]);

    /* set effect volume: */
    if ( (error = SD->SetVolume(fxChannel, volume)) != OK )
        midasError(errorMsg[error]);

    /* set effect panning: */
    if ( (error = SD->SetPanning(fxChannel, panning)) != OK )
        midasError(errorMsg[error]);

    /* start playing effect: */
    if ( (error = SD->PlaySound(fxChannel, rate)) != OK )
        midasError(errorMsg[error]);

    fxChannel++;                        /* channel for next effect */
    if ( fxChannel >= FXCHANNELS )
        fxChannel = 0;
}



int main(int argc, char *argv[])
{
    mpModule    *mod;                   /* pointer to current module struct */
    unsigned    effect1, effect2;       /* sound effect instrument handles */
    int         quit = 0;
    int         error;
    unsigned    masterVolume = 64;      /* music master volume */

    /* argv[0] is the program name, argv[1] the module filename, argv[2]
       and argv[3] are the effect file names. Rest are options which
       MIDAS should handle */

    /* if there aren't enough arguments, show usage and exit */
    if  ( argc < 4 )
    {
        puts(usage);
        exit(EXIT_SUCCESS);
    }

    midasSetDefaults();                 /* set MIDAS defaults */
    midasParseEnvironment();            /* parse MIDAS environment string */
    midasParseOptions(argc-4, &argv[4]);    /* let MIDAS parse all options */
    midasInit();                        /* initialize MIDAS Sound System */
    /* Load module and start playing, leaving FXCHANNELS first channels for
       sound effects: */
    mod = midasPlayModule(argv[1], FXCHANNELS);

    /* Load sound effect samples and store the instrument handles to the
       table effects[]: */
    effect1 = LoadEffect(argv[2]);
    effect2 = LoadEffect(argv[3]);
    if ( (error = MP->SetMasterVolume(masterVolume)) != OK )
        midasError(errorMsg[error]);

    puts("Press 1 & 2 to play effects, +/- to adjust music volume or Esc to "
         "quit.");

    while ( !quit )
    {
        switch ( getch() )
        {
            case 27:    /* Escape - quit */
                quit = 1;
                break;

            case '1':   /* '1' - play first effect */
                PlayEffect(effect1, FXRATE, 64, -40);
                break;

            case '2':   /* '2' - play second effect */
                PlayEffect(effect2, FXRATE, 64, 40);
                break;

            case '+':
                if ( masterVolume < 64 )
                {
                    masterVolume++;
                    if ( (error = MP->SetMasterVolume(masterVolume)) != OK )
                        midasError(errorMsg[error]);
                }
                printf("Music volume: %02i\r", masterVolume);
                break;

            case '-':
                if ( masterVolume > 0 )
                {
                    masterVolume--;
                    if ( (error = MP->SetMasterVolume(masterVolume)) != OK )
                        midasError(errorMsg[error]);
                }
                printf("Music volume: %02i\r", masterVolume);
                break;
        }
    }
    midasStopModule(mod);               /* stop playing */
    FreeEffect(effect1);                /* deallocate effect #1 */
    FreeEffect(effect2);                /* deallocate effect #2 */
    midasClose();                       /* uninitialize MIDAS */

    return 0;
}
