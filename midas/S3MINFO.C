/*      S3MINFO.C
 *
 * S3M info displayer
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

ushort          *iptrs;


int main(int argc, char *argv[])
{
    FILE        *f;
    s3mHeader   s3mh;
    s3mInstHdr  s3mi;
    int         i;
    unsigned    uu;

    printf("S3MINFO v1.00, Copyright 1994 Petteri Kangaslampi &"
           " Jarno Paananen\n\n");

    if ( argc != 2 )
    {
        puts("Usage: S3MINFO <s3mname>");
        exit(EXIT_SUCCESS);
    }

    f = fopen(argv[1], "rb");
    fread(&s3mh, sizeof(s3mHeader), 1, f);
    printf("Song name: %s\n", (char*) &s3mh.name[0]);
    printf("File type: %i\n", (int) s3mh.type);
    printf("Song length: %i\n", (int) s3mh.songLength);
    printf("Number of instruments: %i\n", (int) s3mh.numInsts);
    printf("Number of patterns: %i\n", (int) s3mh.numPatts);
    printf("Flags:\n");
    printf("\tST2 vibrato: %i\n", (int) s3mh.flags.st2Vibrato & 1);
    printf("\tST2 tempo: %i\n", (int) s3mh.flags.st2Tempo & 1);
    printf("\tProTracker slides: %i\n", (int) s3mh.flags.ptSlides & 1);
    printf("\t0-vol optimizations: %i\n", (int) s3mh.flags.zeroVolOpt & 1);
    printf("\tProTracker limits: %i\n", (int) s3mh.flags.ptLimits & 1);
    printf("\tEnable filter/sfx: %i\n", (int) s3mh.flags.filter & 1);
    printf("Tracker version: 0x%X\n", (int) s3mh.trackerVer);
    printf("File format version: %i\n", (int) s3mh.formatVer);
    printf("Master volume: %i\n", (int) s3mh.masterVol);
    printf("Initial speed: %i\n", (int) s3mh.speed);
    printf("Initial tempo: %i\n", (int) s3mh.tempo);
    printf("Master multiplier: %i\n", (int) s3mh.masterMult & 15);
    printf("Stereo: %i\n", (int) (s3mh.masterMult >> 4) & 1);
    printf("Channel settings:");
    for ( i = 0; i < 32; i++ )
        printf("%X, ", s3mh.chanSettings[i]);
    printf("\n\n");

    uu = 0x60 + 2 * ((s3mh.songLength + 1) / 2);
    printf("Instrument pointers start: %u\n\n", uu);
    fseek(f, (ulong) uu, SEEK_SET);
    iptrs = malloc(2 * s3mh.numInsts);
    fread(iptrs, 2*s3mh.numInsts, 1, f);

    for ( i = 0; i < s3mh.numInsts; i++ )
    {
        fseek(f, iptrs[i] * 16L, SEEK_SET);
        fread(&s3mi, sizeof(s3mInstrument), 1, f);
        printf("Instrument %i, file pos %u\n", i, (unsigned) iptrs[i]);
        printf("\tType: %i\n", (int) s3mi.type);
        printf("\tDOS filename: %s\n", (char*) &s3mi.dosName[0]);
        printf("\tParagraph ptr to data: %u\n", (unsigned) s3mi.samplePtr);
        printf("\tSample length: %lu\n", (ulong) s3mi.length);
        printf("\tSample loop start: %lu\n", (ulong) s3mi.loopStart);
        printf("\tSample loop end: %lu\n", (ulong) s3mi.loopEnd);
        printf("\tVolume: %i\n", (int) s3mi.volume);
        printf("\tInstrument disk: %i\n", (int) s3mi.disk);
        printf("\tPacking: %i\n", (int) s3mi.pack);
        printf("\tFlags:\n");
        printf("\t\tLooping: %i\n", (int) s3mi.flags & 1);
        printf("\t\tStereo: %i\n", (int) (s3mi.flags >> 1) & 1);
        printf("\t\t16-bit: %i\n", (int) (s3mi.flags >> 2) & 1);
        printf("\tC2 sampling freq: %lu\n", (ulong) s3mi.c2Rate);
        printf("\tGUS memory position: %u\n", (unsigned) s3mi.gusPos);
        printf("\tInt:512: %i\n", (int) s3mi.int512);
        printf("\tInt:lastused: %i\n", (int) s3mi.intLastUsed);
        printf("\tName: %s\n\n", (char*) &s3mi.name[0]);
    }

    fclose(f);

    return 0;
}
