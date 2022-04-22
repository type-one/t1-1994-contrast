/*      SCRDEMO.C
 *
 * Demo about using Timer screen synchronization
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
#include <process.h>
#include "midas.h"


signed char     horizPan;               /* Horizontal Pixel Panning register
                                           value */
ushort          startAddr;              /* screen start address */
ushort          scrSync;                /* screen synchronization value */
int             panDir;                 /* panning direction - 0 = left,
                                           1 = right */



/****************************************************************************\
*
* Function:     void preVR(void)
*
* Description:  Function that is called before Vertical Retrace. Sets the
*               new screen start address
*
\****************************************************************************/

void preVR(void)
{
asm {
        mov     bx,startAddr            /* bx = screen start address */

        mov     dx,03D4h                /* CRTC controller */
        mov     al,0Ch                  /* Start Address High register */
        mov     ah,bh                   /* screen start address high byte */
        out     dx,ax                   /* set register value */

        mov     al,0Dh                  /* Start Address Low register */
        mov     ah,bl                   /* screen start address low byte */
        out     dx,ax                   /* set register value */
}
}



/****************************************************************************\
*
* Function:     void immVR(void)
*
* Description:  Function that is called immediately when Vertical Retrace
*               starts. Sets the new Horizontal Pixel Panning value
*
\****************************************************************************/

void immVR(void)
{
asm {   mov     dx,03DAh                /* read Input Status #1 register to */
        in      al,dx                   /* reset the Attribute Controller */
                                        /* flip-flop */
        mov     dx,03C0h                /* attribute controller */
        mov     al,13h + 20h            /* Horizontal Pixel Panning register,
                                           enable VGA palette */
        out     dx,al                   /* select register */
        mov     al,horizPan             /* Horizontal Pixel Panning value */
        out     dx,al                   /* write panning value */
}
}




/****************************************************************************\
*
* Function:     void inVR(void)
*
* Description:  Function that is called some time during Vertical Retrace.
*               Calculates new Horizontal Pixel Panning and screen start
*               address values
*
\****************************************************************************/

void inVR(void)
{
    /* Note! Although this function does not cause timer synchronization
       errors if its execution takes too long, it may still cause errors
       to playing tempo when playing with GUS. */

    if ( panDir == 0 )
    {
        /* pan display one pixel left: */

        horizPan++;                     /* next pixel */

        if ( horizPan == 9 )            /* is panning 9? */
            horizPan = 0;               /* if yes, set it to 0 */
        if ( horizPan == 8 )            /* is panning 8? */
            startAddr++;                /* if yes, move to next character */

        if ( startAddr == 80 )          /* change direction after */
            panDir = 1;                 /* scrolling one screen */
    }
    else
    {
        /* pan display one pixel right: */

        horizPan--;

        if ( horizPan == -1 )           /* is panning -1? */
            horizPan = 8;               /* if yes, set it to 8 */
        if ( horizPan == 7 )            /* is panning 7? */
            startAddr--;                /* if yes, move to next character */

        if ( (startAddr == 0) && (horizPan == 8) )  /* change direction */
            panDir = 0;                 /* after scrolling back one screen */
    }

    /* note that charaters are actually 9 pixels wide on VGA */
}



int main(int argc, char *argv[])
{
    mpModule    *mod;
    int         error;

    /* argv[0] is the program name and argv[1] the module filename, the
       rest are options which MIDAS should handle */

    /* if there are not enough arguments, show usage and exit: */
    if  ( argc < 2 )
    {
        puts("Usage: SCRDEMO <filename> [MIDAS options]");
        exit(EXIT_SUCCESS);
    }

    /* get Timer screen synchronization value: */
    if ( (error = tmrGetScrSync(&scrSync)) != OK )
        midasError(errorMsg[error]);

    midasSetDefaults();                 /* set MIDAS defaults */
    midasParseEnvironment();            /* parse MIDAS environment string */
    midasParseOptions(argc-2, &argv[2]);    /* let MIDAS parse all options */
    midasInit();                        /* initialize MIDAS Sound System */
    mod = midasPlayModule(argv[1], 0);  /* load module and start playing */

    puts("Playing - type \"EXIT\" to stop.");

    horizPan = 8;
    startAddr = 0;
    panDir = 0;

    /* Synchronize Timer to screen. preVR() will be called before
       Vertical Retrace, immVR() just after Vertical Retrace starts and
       inVR() some time later during Vertical Retrace. */
    if ( (error = tmrSyncScr(scrSync, &preVR, &immVR, &inVR)) != OK )
        midasError(errorMsg[error]);

    /* jump to DOS shell: */
    spawnl(P_WAIT, getenv("COMSPEC"), NULL);

    /* stop timer screen synchronization: */
    tmrStopScrSync();

    /* reset panning and start address: (dirty but works) */
    horizPan = 8;
    startAddr = 0;
    preVR();
    immVR();

    midasStopModule(mod);               /* stop playing */
    midasClose();                       /* uninitialize MIDAS */

    return 0;
}
