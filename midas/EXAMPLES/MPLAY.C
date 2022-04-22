/*      MPLAY.C
 *
 * Minimal module player using MIDAS Sound System
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

char            *usage =
"Usage:\tMPLAY\t<filename> [options]\n\n"
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



int main(int argc, char *argv[])
{
    mpModule    *mod;

    /* argv[0] is the program name and argv[1] the module filename, the
       rest are options which MIDAS should handle */

    if  ( argc < 2 )                    /* enough arguments? (at least 2 - */
    {                                   /* program name and module filename */
        puts(usage);                    /* nope, show usage */
        exit(EXIT_SUCCESS);             /* and exit */
    }

    midasSetDefaults();                 /* set MIDAS defaults */
    midasParseEnvironment();            /* parse MIDAS environment string */
    midasParseOptions(argc-2, &argv[2]);    /* let MIDAS parse all options */
    midasInit();                        /* initialize MIDAS Sound System */
    mod = midasPlayModule(argv[1], 0);  /* load module and start playing */

    puts("Playing - press any key...");
    getch();                            /* wait for a keypress */

    midasStopModule(mod);               /* stop playing */
    midasClose();                       /* uninitialize MIDAS */

    return 0;
}
