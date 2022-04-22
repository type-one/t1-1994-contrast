/*      MIDP.C
 *
 * MIDAS Module Player v0.42
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
#include <dir.h>
#include <conio.h>
#include <dos.h>
#include <alloc.h>
#include <string.h>
#include <process.h>
#include <ctype.h>
#include <time.h>

#include "midas.h"
#include "vgatext.h"

char            *title =
"MIDAS Module Player v0.42, Copyright 1994 Petteri Kangaslampi & "
"Jarno Paananen\n";

char            *usage =
"Usage:\tMIDP\t[options] <filename> [options]\n\n"
"Options:\n"
"\t-sx\tForce Sound Device x (1 = GUS, 2 = PAS, 3 = WSS, 4 = SB,\n"
"\t\t5 = No Sound)\n"
"\t-pxxx\tForce I/O port xxx (hex) for Sound Device\n"
"\t-ix\tForce IRQ x for Sound Device\n"
"\t-dx\tForce DMA channel x for Sound Device\n"
"\t-mxxxxx\tSet mixing rate to xxxxx Hz\n"
"\t-e\tDisable EMS usage\n"
"\t-t\tDisable ProTracker BPM tempos\n"
"\t-S\tJump immediately to DOS shell\n"
"\t-u\tEnable Surround\n"
"\t-oxxx\tForce output mode (8 = 8-bit, 1 = 16-bit, s = stereo, m = mono)\n"
"\t-v\tDisable real VU-meters\n"
"\t-c\tDisable screen synchronization\n"
"\t-C\tEnable screen synchronization also in DOS shell\n"
"\t-Lx\tNumber of song loops before next song / restart\n"
"\t-O\tScramble module order\n"
"\t-nxx\tDefault panning";

char            *scrtop =
"\xFF\x4FMIDAS Module Player v0.42, Copyright 1994 Petteri Kangaslampi and "
"Jarno Paananen"
"\xFF\x0FÞ\xFF\x7F\x7F\x4Eß\xFF\x08Ý"
"\xFF\x0FÞ\xFF\x78Ú\x7F\x4CÄ\xFF\x7F¿\xFF\x08Ý"
"\xFF\x0FÞ\xFF\x78³\xFF\x7FModule:\x7F\x1F Type:\x7F\x21 ³\xFF\x08Ý"
"\xFF\x0FÞ\xFF\x78³\xFF\x7FMixing Rate:\x7F\x0C Mixing Mode:\x7F\x1B Time:"
"\x7F\x08 ³\xFF\x08Ý"
"\xFF\x0FÞ\xFF\x78³\xFF\x7FLength:    Position:    Pattern:    Row:    Tempo:"
"     Speed:    Vol:       ³\xFF\x08Ý"
"\xFF\x0FÞ\xFF\x78À\xFF\x7F\x7F\x4CÄÙ\xFF\x08Ý";


#define MAXNAMES 256                    /* maximum number of file names */


ulong           free1, free2;
mpModule        *mod;
int             numChans;
ushort          scrSync;
int             immShell = 0;
int             sync = 1, shellSync = 0;
volatile ulong  frameCnt;
mpInformation   *info;
ushort          actch = 0;
char            masterVol = 64;
char            exitFlag = 0;
char            fadeOut;
short           loopCnt = 0;
ushort          defPanning;
int             useDefPanning = 0;
char            *fNames[MAXNAMES];
time_t          startTime, pauseTime = 0, pauseStart;
int             muted = 0, paused = 0;
int             numFNames;
int             fileNumber;
int             noNext;
int             isArchive;              /* is file archive */
int             arcType;                /* archive type */
int             decompressed;           /* 1 if already decompressed */
char            *decompName = NULL;     /* name of decompressed module file */

char            *tempDir;               /* temporary directory for
                                           decompression */
int             scrambleOrder = 0;

char            *modTypes[2] = {        /* module type strings */
    { "Scream Tracker ]I[" },
    { "Protracker" } };

char            *notes[13] = {          /* note strings */
    "C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"};

#define DECOMPMEM 350000                /* number of bytes of memory required
                                           for decompression */
#define NUMARCEXTS 3
char            *arcExtensions[NUMARCEXTS] =
    { ".ZIP", ".MDZ", ".S3Z" };

char            Channels[32];           /* channel mute flags */
uchar           oldInsts[32];           /* old instrument values for all
                                           channels */
struct text_info  textInfo;             /* text mode information */


/****************************************************************************\
*
* Function:     void Error(char *msg)
*
* Description:  Prints an error message to stderr, uninitializes MIDAS and
*               exits to DOS
*
* Input:        char *msg               error message
*
\****************************************************************************/

void Error(char *msg)
{
    textmode(C80);
    fprintf(stderr, "Error: %s\n", msg);
    midasClose();
    exit(EXIT_FAILURE);
}




/****************************************************************************\
*
* Function:     void toggleChannel(char channel)
*
* Description:  Toggles a channel mute on/off
*
* Input:        char channel            channel number
*
\****************************************************************************/

void toggleChannel(char channel)
{
    if ( channel < numChans )
    {
        Channels[channel] ^= 1;
        SD->MuteChannel(channel, Channels[channel]);
    }
}




/****************************************************************************\
*
* Function:     void prevr(void)
*
* Description:  preVR() routine for Timer, increments frame counter
*
\****************************************************************************/

void prevr(void)
{
    frameCnt++;
}




/****************************************************************************\
*
* Function:     void showheap(void)
*
* Description:  Displays amount of free memory and amount of memory used,
*               and checks for heap corruption.
*
\****************************************************************************/

void showheap(void)
{
    struct heapinfo hinfo;


    free2 = coreleft();
    cprintf("%lu bytes memory free - %lu bytes used.\r\n",
        free2, free1-free2);

    if ( heapcheck() != _HEAPOK )
        cputs("HEAP CORRUPTED - PREPARE FOR SYSTEM CRASH!\r\n");
}




/****************************************************************************\
*
* Function:     void dumpheap(void)
*
* Description:  Lists all blocks in heap
*
\****************************************************************************/

void dumpheap(void)
{
    struct heapinfo hinfo;

    if ( heapcheck() == _HEAPOK )
        cputs("Heap OK\r\n");
    else
        cputs("HEAP CORRUPTED!\r\n");

    hinfo.ptr = NULL;

    while ( heapwalk(&hinfo) == _HEAPOK )
    {
        cprintf("%p: %06u - ", hinfo.ptr, hinfo.size);
        if ( hinfo.in_use == 1 )
            cprintf("USED\r\n");
        else
            cprintf("FREE\r\n");
    }
}




/****************************************************************************\
*
* Function:     void dumpfree(void)
*
* Description:  Lists all free blocks in heap
*
\****************************************************************************/

void dumpfree(void)
{
    struct heapinfo hinfo;

    if ( heapcheck() == _HEAPOK )
        cputs("Heap OK\r\n");
    else
        cputs("HEAP CORRUPTED!\r\n");

    hinfo.ptr = NULL;

    while ( heapwalk(&hinfo) == _HEAPOK )
    {
        if ( hinfo.in_use != 1 )
            cprintf("%p: %06u\r\n", hinfo.ptr, hinfo.size);
    }
}



/****************************************************************************\
*
* Function:     void ParseCmdLine(int argc, char *argv[])
*
* Description:  Parses command line options
*
* Input:        int argc                argc from main()
*               char *argv[]            argv from main()
*
\****************************************************************************/

void ParseCmdLine(int argc, char *argv[])
{
    int         i, error;

    numFNames = 0;

    for ( i = 1; i < argc; i++ )
    {
        if ( argv[i][0] == '-' )
        {
            switch ( argv[i][1] )
            {
                case 'S':
                    immShell = 1;
                    break;

                case 'C':
                    shellSync = 1;
                    break;

                case 'c':
                    sync = 0;
                    break;

                case 'L':
                    loopCnt = atoi(&argv[i][2]);
                    if ( loopCnt == 0 )
                        loopCnt = 1;
                    break;

                case 'O':
                    scrambleOrder = 1;
                    break;

                case 'n':
                    defPanning = atoi(&argv[i][2]);
                    useDefPanning = 1;
                    break;

                default:
                    midasParseOption(&argv[i][1]);
                    break;
            }
        }
        else
        {
            if ( numFNames >= MAXNAMES )
                Error("Too many file names");

            fNames[numFNames] = argv[i];
            numFNames++;
        }
    }
}




/****************************************************************************\
*
* Function:     void InitMIDAS(void)
*
* Description:  Initializes MIDAS Sound System
*
\****************************************************************************/

void InitMIDAS(void)
{
    int         error;

    /* Get screen synchronization value if Timer should be synchronized to
       screen: */
    if ( sync )
    {
        if ( (error = tmrGetScrSync(&scrSync)) != OK )
            midasError(errorMsg[error]);
    }

    midasInit();

    /* Synchronize timer to screen, if synchronization is used. prevr() will
       be called before each retrace */
    if ( sync )
    {
        if ( (error = tmrSyncScr(scrSync, &prevr, NULL, NULL)) != OK )
            midasError(errorMsg[error]);
    }

    cprintf("MIDAS Sound System succesfully initialized.\r\n"
        "Playing through %s,\r\nusing port %Xh, IRQ %i and DMA %i\r\n",
        SD->ID, (unsigned) SD->port, (int) SD->IRQ, (int) SD->DMA);
    showheap();
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

    /* Remove screen synchronization if used: */
    if ( sync )
    {
        if ( (error = tmrStopScrSync()) != OK )
            midasError(errorMsg[error]);
    }

    midasClose();

    cprintf("MIDAS Sound System succesfully uninitialized\r\n");
}




/****************************************************************************\
*
* Function:     void WaitVR(void)
*
* Description:  Waits for Vertical Retrace
*
\****************************************************************************/

void WaitVR(void)
{
asm     mov     dx,03DAh
wvr:
asm {   in      al,dx
        test    al,8
        jz      wvr
}
}




/****************************************************************************\
*
* Function:     void WaitDE(void)
*
* Description:  Waits for Display Enable
*
\****************************************************************************/

void WaitDE(void)
{
asm     mov     dx,03DAh
wde:
asm {   in      al,dx
        test    al,1
        jnz     wde
}
}




/****************************************************************************\
*
* Function:     void SetBorder(uchar color)
*
* Description:  Sets display border color
*
* Input:        uchar color             new border color
*
\****************************************************************************/

void SetBorder(uchar color)
{
asm {   mov     dx,03C0h
        mov     al,31h
        out     dx,al
        mov     al,color
        out     dx,al
}
}




/****************************************************************************\
*
* Function:     void InitScreen(void)
*
* Description:  Initializes MIDAS Module Player screen
*
\****************************************************************************/

void InitScreen(void)
{
    frameCnt = 0;
    textmode(C4350);
    clrscr();
    vgaWriteText(1, 1, scrtop);
    vgaWriteText(1, 8, "\xFF\x0FÞ\xFF\x78\x7F\x4EÜ\xFF\x08Ý");
    window(1, 42, 80, 50);
    gotoxy(1, 1);
    textattr(0x07);
}




/****************************************************************************\
*
* Function:     void DrawScreen(void)
*
* Description:  Draws MIDAS Module Player screen. Used after module has
*               been loaded.
*
\****************************************************************************/

void DrawScreen(void)
{
    int         i, x, y, len;
    char        c;
    char        str[32];
    char        chstr[18];
    ushort      mode, mixRate;
    int         error;

    vgaWriteText(1, 1, scrtop);
    vgaWriteText(1, 8, "\xFF\x0FÞ\xFF\x78Ú\x7F\x4CÄ\xFF\x7F¿\xFF\x08Ý");
    for ( i = 0; i < numChans; i++ )
        vgaWriteText(1, 9+i, "\xFF\x0FÞ\xFF\x78³\xFF\x70   ³\x7F\x11 ³   ³  ³"
            "\x7F\x0E ³\x7F\x20þ\xFF\x7F³\xFF\x08Ý");
    y = 9+numChans;
    vgaWriteText(1, y, "\xFF\x0FÞ\xFF\x78À\xFF\x7F\x7F\x4CÄÙ\xFF\x08Ý");
    vgaWriteText(1, y+1, "\xFF\x0FÞ\xFF\x78Ú\x7F\x4CÄ\xFF\x7F¿\xFF\x08Ý");
    y+=2;
    for ( ; y < 40; y++ )
        vgaWriteText(1, y, "\xFF\x0FÞ\xFF\x78³\xFF\x70\x7F\x25 ³\x7F\x26 "
            "\xFF\x7F³\xFF\x08Ý");
    vgaWriteText(1, 40, "\xFF\x0FÞ\xFF\x78À\xFF\x7F\x7F\x4CÄÙ\xFF\x08Ý");
    vgaWriteText(1, 41, "\xFF\x0FÞ\xFF\x78\x7F\x4EÜ\xFF\x08Ý");

    for ( i = 0; i < numChans; i++ )
    {
        if ( i < 9 )
            c = i + '1';
        else
            c = i + 'A' - 9;
        chstr[i] = c;
    }
    chstr[numChans] = 0;

    sprintf(&str[0], "%s Module", modTypes[mod->IDnum]);
    vgaWriteStr(46, 4, str, 0x70, 33);

    vgaWriteStr(10, 4, &mod->songName[0], 0x70, 31);

    for ( i = 0; i < mod->numInsts; i++ )
    {
        x = 3;
        y = 11 + numChans + i;
        len = 33-numChans;
        if ( y >= 40 )
        {
            x += 38;
            y -= (29 - numChans);
            len++;
        }
        if ( y < 40 )
        {
            vgaWriteStr(x, y, &chstr[0], 0x70, numChans);
            x += numChans+1;
            if(mod->instsUsed[i] == 1)
            {
                vgaWriteByte(x, y, i+1, 0x70);
                vgaWriteStr(x+3, y, &mod->insts[i].iname[0], 0x70, len);
            }
            else
            {
                vgaWriteByte(x, y, i+1, 0x78);
                vgaWriteStr(x+3, y, &mod->insts[i].iname[0], 0x78, len);
            }
        }
    }

    vgaWriteByte(10, 6, mod->songLength, 0x70);

    if ( (error = SD->GetMixRate(&mixRate)) != OK )
        midasError(errorMsg[error]);
    sprintf(&str[0], "%uHz", mixRate);
    vgaWriteStr(15, 5, str, 0x70, 7);

    if ( (error = SD->GetMode(&mode)) != OK )
        midasError(errorMsg[error]);

    if ( mode & sd16bit )
        strcpy(&str[0], "16-bit ");
    else
        strcpy(&str[0], "8-bit ");

    if ( mode & sdStereo )
        strcat(&str[0], "Stereo ");
    else
        strcat(&str[0], "Mono ");

    if ( mode & sdHighQ )
        strcat(&str[0], "High");
    else
        strcat(&str[0], "Normal");

    vgaWriteStr(39, 5, str, 0x70, 26);
}




/****************************************************************************\
*
* Function:     void UpdScreen(void)
*
* Description:  Updates MIDAS Module Player screen
*
\****************************************************************************/

void UpdScreen(void)
{
    char        str[32];
    int         i, x, y;
    char        *iname;
    mpChanInfo  *chan;
    int         numInsts;
    short       pan;
    ulong       rate;
    int         error;
    ushort      meter, pos;
    time_t      currTime;
    int         hour, min, sec;

    vgaWriteByte(23, 6, info->pos, 0x70);
    vgaWriteByte(35, 6, info->pattern, 0x70);
    vgaWriteByte(43, 6, info->row, 0x70);
    sprintf(&str[0], "%3u", (unsigned) info->BPM);
    vgaWriteStr(53, 6, &str[0], 0x70, 3);
    vgaWriteByte(64, 6, info->speed, 0x70);
    sprintf(&str[0], "%2u", masterVol);
    vgaWriteStr(72, 6, &str[0], 0x70, 3);

    if ( !paused )
    {
        currTime = time(NULL) - startTime - pauseTime;
        hour = currTime / 3600;
        min = ((currTime - 3600*hour) / 60) % 60;
        sec = currTime % 60;
        sprintf(&str[0], "%2i:%02i:%02i", hour, min, sec);
        vgaWriteStr(71, 5, &str[0], 0x70, 8);
    }
    else
        vgaWriteStr(71, 5, "-PAUSED-", 0x70, 8);

    numInsts = mod->numInsts;

    for ( i = 0; i < numChans; i++ )
    {
        chan = &info->chans[i];

        if ( oldInsts[i] != 0 )
        {
            x = 3+i;
            y = 11 + numChans + (oldInsts[i]-1);
            if ( y >= 40 )
            {
                x += 38;
                y -= (29 - numChans);
            }
            if ( y < 40 )
            {
                str[1] = 0;
                if ( i < 9 )
                    str[0] = i + '1';
                else
                    str[0] = (i-9) + 'A';
                vgaWriteStr(x, y, &str[0], 0x70, 1);
            }
        }

        if ( (Channels[i] == 0) && (!muted) && (!paused) )
        {
            if ( (chan->instrument != 0) && (chan->instrument <= numInsts) )
            {
                x = 3+i;
                y = 11 + numChans + (chan->instrument-1);
                if ( y >= 40 )
                {
                    x += 38;
                    y -= (29 - numChans);
                }
                if ( y < 40 )
                {
                    str[1] = 0;
                    if ( i < 9 )
                        str[0] = i + '1';
                    else
                        str[0] = (i-9) + 'A';
                    vgaWriteStr(x, y, &str[0], 0x7E, 1);
                }

                vgaWriteByte(7, 9+i, chan->instrument, 0x70);

                iname = &mod->insts[chan->instrument-1].iname[0];

                vgaWriteStr(10, 9+i, iname, 0x70, 14);

                oldInsts[i] = chan->instrument;

                if ( realVU )
                {
                    if ( (error = SD->GetRate(i, &rate)) != OK )
                        midasError(errorMsg[error]);

                    if ( (error = SD->GetPosition(i, &pos)) != OK )
                        midasError(errorMsg[error]);

                    if ( rate != 0 )
                    {
                        error = vuMeter(
                            mod->insts[chan->instrument - 1].sdInstHandle,
                            rate, pos, (chan->volume * masterVol) / 64,
                            &meter);
                        if ( error != OK )
                            midasError(errorMsg[error]);
                    }
                    else
                        meter = 0;
                }
                else
                    meter = chan->volumebar;

                if ( (chan->note < 254) && ( (chan->note & 15) < 12) )
                {
                    strcpy(&str[0], notes[chan->note & 15]);
                    str[2] = (chan->note >> 4) + '0';
                    str[3] = 0;
                    vgaWriteStr(25, 9+i, &str[0], 0x70, 3);
                }
                else
                    vgaWriteStr(25, 9+i, "", 0x70, 3);
            }
            else
                meter = 0;

            vgaWriteByte(29, 9+i, chan->volume, 0x70);
            if ( chan->commandname[0] != 0 )
            {
                sprintf(&str[0], "%s %02X", chan->commandname,
                    (int) chan->infobyte);
                vgaWriteStr(32, 9+i, &str[0], 0x70, 14);
            }
            else
                vgaWriteStr(32, 9+i, "", 0x70, 14);

            vgaDrawMeter(47, 9+i, meter >> 1, 32, 'þ', 0x7A, 0x70);
        }
        else
            vgaWriteText(7, 9+i,
                "\xFF\x70\x7F\x11 ³   ³  ³\x7F\x0E ³\x7F\x20þ");

        if ( (error = SD->GetPanning(i, &pan)) != OK )
            midasError(errorMsg[error]);

        switch ( pan )
        {
            case panLeft:
                strcpy(&str[0], "LFT");
                break;

            case panRight:
                strcpy(&str[0], "RGT");
                break;

            case panMiddle:
                strcpy(&str[0], "MID");
                break;

            case panSurround:
                strcpy(&str[0], "SUR");
                break;

            default:
                sprintf(&str[0], "%3i", pan);
        }
        if ( i != actch )
            vgaWriteStr(3, i+9, &str[0], 0x70, 3);
        else
            vgaWriteStr(3, i+9, &str[0], 0x07, 3);
    }
}



/****************************************************************************\
*
* Function:     void WaitFrame(void)
*
* Description:  Waits for next frame, either by using VGA hardware or by
*               waiting for the frame counter to change, depending on
*               whether screen synchronization is used or not
*
\****************************************************************************/

void WaitFrame(void)
{
    ulong       oldcnt = frameCnt;

    if ( sync )
        while ( frameCnt == oldcnt );
    else
    {
        WaitDE();
        WaitVR();
    }
}



/****************************************************************************\
*
* Function:     void DOSshell(void)
*
* Description:  Jumps to DOS shell
*
\****************************************************************************/

void DOSshell(void)
{
    char        *comspec;
    char        *dir;
    int         disk, error;

    if ( (!shellSync) && sync )
        tmrStopScrSync();

    /* restore old text mode: */
    textmode(textInfo.currmode);

    if ( (error = memAlloc(MAXDIR, (void**) &dir)) != OK )
        Error(errorMsg[error]);

    disk = getdisk();
    getcurdir(0, dir);

    comspec=getenv("COMSPEC");
    spawnl(P_WAIT, comspec, NULL);

    /* save text mode information, including mode: */
    gettextinfo(&textInfo);

    InitScreen();
    DrawScreen();

    setdisk(disk);
    chdir("\\");
    chdir(dir);

    if ( (error = memFree(dir)) != OK )
        Error(errorMsg[error]);

    if ( (!shellSync) && sync )
        tmrSyncScr(scrSync, &prevr, NULL, NULL);
    showheap();

}




/****************************************************************************\
*
* Function:     void prepare(int fNum)
*
* Description:  Prepares for playing a module file, setting variables
*               isArchive and decompressed as necessary.
*
* Input:        int fNum                number of file name
*
\****************************************************************************/

void prepare(int fNum)
{
    int         i;
    char        ext[_MAX_EXT];

    /* get file name extension: */
    fnsplit(fNames[fNum], NULL, NULL, NULL, &ext[0]);

    isArchive = 0;

    /* Search through known archive extensions. If a match is found, the file
       is an archive. */
    for ( i = 0; i < NUMARCEXTS; i++ )
        if ( stricmp(&ext[0], arcExtensions[i]) == 0 )
            isArchive = 1;

    decompressed = 0;
}




/****************************************************************************\
*
* Function:     void decompress(char *fileName)
*
* Description:  Decompresses a file and sets decompName to decompressed file
*               name. The archive is assumed to contain a single file, with
*               the same name as the archive and any extension.
*
* Input:        char *fileName          pointer to archive file name
*
\****************************************************************************/

void decompress(char *fileName)
{
    int         error;
    char        name[_MAX_FNAME];
    struct ffblk ffb;

    fnsplit(fileName, NULL, NULL, &name[0], NULL);

    if ( decompName == NULL )
    {
        if ( (error = memAlloc(_MAX_PATH, (void**) &decompName)) != OK )
            Error(errorMsg[error]);
    }

    if ( spawnlp(P_WAIT, "PKUNZIP", "", fileName, tempDir, NULL) != OK )
        Error("PKUNZIP failed");

    strcpy(decompName, tempDir);
    strcat(decompName, &name[0]);
    strcat(decompName, ".*");

    if ( findfirst(decompName, &ffb, 0) != 0 )
        Error("Unable to find decompressed file");

    strcpy(decompName, tempDir);
    strcat(decompName, &ffb.ff_name[0]);
    decompressed = 1;
}




/****************************************************************************\
*
* Function:     void HandleKeys(void)
*
* Description:  Handles the keypresses
*
\****************************************************************************/

void HandleKeys(void)
{
    char        key;
    short       panning;
    int         error;
    FILE        *sf;

    key = getch();

    if ( !key )
    {
        switch ( getch() )
        {
            case 45:            /* Alt-X */
                exitFlag = 1;
                break;

            case 77:            /* Right arrow */
                MP->SetPosition(info->pos + 1);
                break;

            case 75:            /* Left arrow */
                MP->SetPosition(info->pos - 1);
                break;

            case 72:            /* Up arrow */
                if ( actch > 0 )
                    actch--;
                break;

            case 80:            /* Down arrow */
                if ( actch < (numChans-1) )
                    actch++;
                break;
        }
    }
    else
    {
        switch ( toupper(key) )
        {
            case 27:
                fadeOut = 1;
                noNext = 1;
                break;

            case '+':
                if ( masterVol != 64 )
                {
                    masterVol++;
                    MP->SetMasterVolume(masterVol);
                }
                break;

            case '-':
                if ( masterVol != 0 )
                {
                    masterVol--;
                    MP->SetMasterVolume(masterVol);
                }
                break;

            case 'D':
                DOSshell();
                break;

            case '0': toggleChannel(9); break;
            case '1': toggleChannel(0); break;
            case '2': toggleChannel(1); break;
            case '3': toggleChannel(2); break;
            case '4': toggleChannel(3); break;
            case '5': toggleChannel(4); break;
            case '6': toggleChannel(5); break;
            case '7': toggleChannel(6); break;
            case '8': toggleChannel(7); break;
            case '9': toggleChannel(8); break;

            case 'T': toggleChannel(actch); break;

            case ',':
                if ( (error = SD->GetPanning(actch, &panning)) != OK )
                    midasError(errorMsg[error]);
                if ( (panning > -64) && (panning <= 64) )
                    if ( (error = SD->SetPanning(actch, panning-1)) != OK )
                        midasError(errorMsg[error]);
                break;

            case '.':
                if ( (error = SD->GetPanning(actch, &panning)) != OK )
                    midasError(errorMsg[error]);
                if ( (panning < 64) && (panning >= -64) )
                    if ( (error = SD->SetPanning(actch, panning+1)) != OK )
                        midasError(errorMsg[error]);
                break;

            case 'M':
                if ( (error = SD->SetPanning(actch, panMiddle)) != OK )
                    midasError(errorMsg[error]);
                break;

            case 'U':
                if ( (error = SD->SetPanning(actch, panSurround)) != OK )
                    midasError(errorMsg[error]);
                break;

            case 'L':
                if ( (error = SD->SetPanning(actch, panLeft)) != OK )
                    midasError(errorMsg[error]);
                break;

            case 'R':
                if ( (error = SD->SetPanning(actch, panRight)) != OK )
                    midasError(errorMsg[error]);
                break;

            case 'F':
                dumpfree();
                break;

            case 'H':
                dumpheap();
                break;

            case 'N':
                fadeOut = 1;
                break;

#ifdef DEBUG
/*
            case 'B':
                sf = fopen("MIDPSCR.BIN", "wb");
                fwrite(MK_FP(0xB800, 0), 8000, 1, sf);
                fclose(sf);
                break;
*/
#endif
            case 'P':
                paused ^= 1;
                SD->Pause(paused);
                if ( paused == 1 )
                    pauseStart = time(NULL);
                else
                    pauseTime += time(NULL) - pauseStart;
                break;

            case ' ':
                muted ^= 1;
                SD->Mute(muted);
                break;
        }
    }
}




/****************************************************************************\
*
* Function:     void PlayModule(char *fName)
*
* Description:  Plays a module file
*
* Input:        char *fName
*
\****************************************************************************/

void PlayModule(char *fName)
{
    int         stop, i, error, nextf;

    cprintf("Loading \"%s\"\r\n", fName);

    /* load module: */
    mod = midasPlayModule(fName, 0);
    startTime = time(NULL);

    numChans = mod->numChans;

    if ( (useDefPanning) && ((defPanning < 64) || (defPanning == 100))  )
    {
        for ( i = 0; i < numChans; i++ )
        {
            /* Default panning is used. If 100, set channel to surround: */
            if ( defPanning == 100 )
            {
                if ( (error = SD->SetPanning(i, panSurround)) != OK )
                    midasError(errorMsg[error]);
            }
            else
            {
                /* If channel is panned to left, set it to -defPanning,
                   otherwise set it to right */
                if ( mod->chanSettings[i] < 0 )
                {
                    if ( (error = SD->SetPanning(i, -defPanning)) != OK )
                        midasError(errorMsg[error]);
                }
                else
                {
                    if ( (error = SD->SetPanning(i, defPanning)) != OK )
                        midasError(errorMsg[error]);
                }
            }
        }
    }

    /* Prepare screen display: */
    DrawScreen();
    showheap();

    for ( i = 0; i < 32; i++ )
    {
        oldInsts[i] = 0;
        Channels[i] = 0;
    }

    /* Allocate memory for Module Player information structure and prepare
       it for use: */
    if ( (error = memAlloc(sizeof(mpInformation), (void**) &info)) != OK )
        Error(errorMsg[error]);
    info->numChannels = numChans;
    if ( (error = memAlloc(numChans * sizeof(mpChanInfo), (void**)
        &info->chans)) != OK )
        Error(errorMsg[error]);

    stop = 0;
    fadeOut = 0;
    masterVol = 64;
    if ( (error = MP->SetMasterVolume(64)) != OK )
        midasError(errorMsg[error]);

    if ( (loopCnt == 0) && (numFNames != 1) )
        loopCnt = 1;

    if ( isArchive )
    {
        if ( remove(fName) != 0 )
            Error("Unable to delete file");
        decompressed = 0;
    }

    if ( numFNames != 1 )
    {
        if ( fileNumber < (numFNames-1) )
            nextf = fileNumber + 1;
        else
            nextf = 0;

        prepare(nextf);

        if ( isArchive )
        {
            if ( coreleft() >= DECOMPMEM )
            {
                decompress(fNames[nextf]);
                InitScreen();
                DrawScreen();
                cprintf("Next module file decompressed\r\n");
            }
            else
                cprintf("Not enough free memory to decompress next module "
                        "file while playing\r\n");
        }
    }

    cprintf ("Playing %d-channel %s Module \"%s\"\r\n", numChans,
        modTypes[mod->IDnum], &mod->songName[0]);
    showheap();

    while ( (!stop) && (!exitFlag) )
    {
        WaitFrame();                    /* wait for next frame */

        /* Read Module Player information: */
        if ( (error = MP->GetInformation(info)) != OK )
            midasError(errorMsg[error]);

        if ( loopCnt != 0 )
        {
            if ( info->loopCnt >= loopCnt )
                fadeOut = 1;
        }

        UpdScreen();                    /* update screen */

        if ( fadeOut )
        {
            if ( masterVol > 0 )
            {
                masterVol--;
                if ( (error = MP->SetMasterVolume(masterVol)) != OK )
                    midasError(errorMsg[error]);
            }
            else
            {
                stop = 1;
                if ( (error = MP->SetMasterVolume(0)) != OK )
                    midasError(errorMsg[error]);
            }
        }

        if( kbhit() )
            HandleKeys();
    }

    /* stop playing: */
    midasStopModule(mod);

    /* deallocate info structure: */
    if ( (error = memFree(info->chans)) != OK )
        Error(errorMsg[error]);
    if ( (error = memFree(info)) != OK )
        Error(errorMsg[error]);

    showheap();

    if ( noNext )
        exitFlag = 1;
}





int main(int argc, char *argv[])
{
    int         error, i, n;
    char        *temp;

    /* save text mode information, including mode: */
    gettextinfo(&textInfo);

    puts(title);
    if  ( argc < 2 )
    {
        puts(usage);
        exit(EXIT_SUCCESS);
    }

    printf("Free memory: %lu\n", free1 = coreleft());
    startTime = time(NULL);

    midasSetDefaults();
    midasParseEnvironment();
    ParseCmdLine(argc, argv);
    if ( numFNames == 0 )
    {
        puts(usage);
        exit(EXIT_SUCCESS);
    }

    if ( scrambleOrder )
    {
        randomize();
        for ( i = 0; i < numFNames; i++ )
        {
            n = random(numFNames);
            temp = fNames[i];
            fNames[i] = fNames[n];
            fNames[n] = temp;
        }
    }

    /* allocate memory for decompression directory name string: */
    if ( (error = memAlloc(MAXPATH, (void*) &tempDir)) != OK )
        Error(errorMsg[error]);

    /* if environment variable "TEMP" is set, use it, otherwise use "C:\" */
    temp = getenv("TEMP");
    if ( temp != NULL )
    {
        /* "TEMP" environment string found. Copy it to tempDir, and if the
           last character is not '\', append one to the end. */
        strcpy(tempDir, temp);
        if ( tempDir[strlen(tempDir)-1] != '\\' )
            strcat(tempDir, "\\");
    }
    else
    {
        /* No "TEMP" environment string found - use "C:\" */
        strcpy(tempDir, "C:\\");
    }


    if ( !immShell )
        InitScreen();
    InitMIDAS();

    if ( immShell )
    {
        mod = midasPlayModule(fNames[0], 0);
        DOSshell();
        midasStopModule(mod);
        exitFlag = 1;
    }

    if ( numFNames == 1 )
        noNext = 1;

    fileNumber = 0;
    prepare(fileNumber);

    while( !exitFlag )
    {
        pauseTime = 0;
        paused = 0;
        muted = 0;

        if ( isArchive )
        {
            if ( decompressed )
                PlayModule(decompName);
            else
            {
                decompress(fNames[fileNumber]);
                InitScreen();
                cprintf("Module file decompressed.\r\n");
                showheap();
                PlayModule(decompName);
            }
        }
        else
            PlayModule(fNames[fileNumber]);

        fileNumber++;
        if ( fileNumber >= numFNames )
            fileNumber = 0;
    }

    if ( (decompressed) && (decompName != NULL) )
        if ( remove(decompName) != 0 )
            Error("Unable to delete file");

    if ( decompName != NULL )
        if ( (error = memFree(decompName)) != OK )
            Error(errorMsg[error]);

    midasClose();

    if ( (error = memFree(tempDir)) != OK )
        Error(errorMsg[error]);

    /* restore old text mode: */
    textmode(textInfo.currmode);

    showheap();

#ifdef DEBUG
    errPrintList();
#endif

    return 0;
}
