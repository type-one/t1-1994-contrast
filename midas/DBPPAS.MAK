#*      DBPPAS.MAK
#*
#* MIDAS Pascal debug module player makefile
#*
#* Copyright 1994 Petteri Kangaslampi and Jarno Paananen
#*
#* This file is part of the MIDAS Sound System, and may only be
#* used, modified and distributed under the terms of the MIDAS
#* Sound System license, LICENSE.TXT. By continuing to use,
#* modify or distribute this file you indicate that you have
#* read the license and understand and accept it fully.
#*



# Compiler directories:

BCDIR = c:\bc
LIBDIR = $(BCDIR)\lib


# Compilers and options:

CC = bcc
CCOPTS = -c -3 -G -v -ml -l-v-c -I$(BCDIR)\include -D__TP__ -DDEBUG -DREALVUMETERS
PC = tpc
PCOPTS = /$G+ /V /DREALVUMETERS /DDEBUG  # /DNOTIMER
ASM = tasm
ASMOPTS = -UT310 -ml -zi -m9 -d__TP__ -dDEBUG



dbp.exe : dbp.pas MIDAS.tpu Errors.tpu mGlobals.tpu mMem.tpu SDevice.tpu \
        MPlayer.tpu DMA.tpu DSM.tpu VU.tpu
        $(PC) $(PCOPTS) dbp.pas

MIDAS.tpu : MIDAS.pas Errors.tpu mGlobals.tpu mMem.tpu mFile.tpu EMS.tpu \
        SDevice.tpu MPlayer.tpu S3M.tpu MODP.tpu Timer.tpu VU.tpu
        $(PC) $(PCOPTS) MIDAS.pas


Errors.tpu : Errors.pas
        $(PC) $(PCOPTS) Errors.pas

mGlobals.tpu : mGlobals.pas
        $(PC) $(PCOPTS) mGlobals.pas

mMem.tpu : mMem.pas Errors.tpu
        $(PC) $(PCOPTS) mMem.pas


DMA.tpu : DMA.pas dma.obj mMem.tpu Errors.tpu
        $(PC) $(PCOPTS) DMA.pas

dma.obj : dma.asm lang.inc errors.inc dma.inc mmem.inc
	$(ASM) $(ASMOPTS) dma.asm


EMS.tpu : EMS.pas ems.obj mMem.tpu Errors.tpu
        $(PC) $(PCOPTS) EMS.pas

ems.obj : ems.asm lang.inc errors.inc ems.inc mmem.inc
	$(ASM) $(ASMOPTS) ems.asm


SDevice.tpu : SDevice.pas GUS.obj PAS.obj WSS.obj SB.obj NSND.obj \
              Errors.tpu mGlobals.tpu mMem.tpu DMA.tpu DSM.tpu
        $(PC) $(PCOPTS) SDevice.pas

GUS.obj : gus.asm lang.inc mglobals.inc sdevice.inc mmem.inc mglobals.inc
        $(ASM) $(ASMOPTS) gus.asm

PAS.obj : pas.asm pas.inc lang.inc errors.inc sdevice.inc dsm.inc dma.inc
        $(ASM) $(ASMOPTS) pas.asm

WSS.obj : wss.asm lang.inc errors.inc sdevice.inc dsm.inc dma.inc
        $(ASM) $(ASMOPTS) wss.asm

SB.obj : sb.asm lang.inc errors.inc sdevice.inc dsm.inc dma.inc
        $(ASM) $(ASMOPTS) sb.asm

NSND.obj : nsnd.asm lang.inc sdevice.inc
	$(ASM) $(ASMOPTS) nsnd.asm


DSM.tpu : DSM.pas DSM.obj Errors.tpu mGlobals.tpu mMem.tpu EMS.tpu DMA.tpu
        $(PC) $(PCOPTS) DSM.pas

DSM.obj : dsm.asm lang.inc errors.inc mglobals.inc dsm.inc dma.inc mmem.inc \
        ems.inc sdevice.inc
	$(ASM) $(ASMOPTS) dsm.asm


Timer.tpu : Timer.pas timer.obj Errors.tpu mGlobals.tpu EMS.tpu DMA.tpu \
        DSM.tpu
        $(PC) $(PCOPTS) Timer.pas

timer.obj : timer.asm errors.inc mglobals.inc lang.inc timer.inc ems.inc dma.inc dsm.inc sdevice.inc
        $(ASM) $(ASMOPTS) timer.asm


MPlayer.tpu : MPlayer.pas
        $(PC) $(PCOPTS) MPlayer.pas


S3M.tpu : S3M.pas S3M.obj S3MLoad.obj Errors.tpu mGlobals.tpu mMem.tpu \
        EMS.tpu MPlayer.tpu SDevice.tpu Timer.tpu VU.tpu mFile.tpu
        $(PC) $(PCOPTS) S3M.pas

s3m.obj : s3m.asm lang.inc errors.inc mglobals.inc s3m.inc mplayer.inc \
        sdevice.inc ems.inc timer.inc
        $(ASM) $(ASMOPTS) s3m.asm

s3mload.obj : s3mload.c mtypes.h errors.h mglobals.h mmem.h sdevice.h \
        mplayer.h s3m.h ems.h vu.h lang.h file.h
        $(CC) $(CCOPTS) s3mload.c


MODP.tpu : MODP.pas MOD.obj MODLoad.obj Errors.tpu mGlobals.tpu mMem.tpu \
        EMS.tpu MPlayer.tpu SDevice.tpu Timer.tpu VU.tpu mFile.tpu
        $(PC) $(PCOPTS) MODP.pas

mod.obj : mod.asm lang.inc errors.inc mglobals.inc mod.inc mplayer.inc \
        sdevice.inc ems.inc timer.inc mglobals.inc
        $(ASM) $(ASMOPTS) mod.asm

modload.obj : modload.c mtypes.h errors.h mglobals.h mmem.h sdevice.h \
        mplayer.h mod.h ems.h vu.h lang.h file.h
        $(CC) $(CCOPTS) modload.c


mFile.tpu : mFile.pas file.obj Errors.tpu mMem.tpu rawFile.tpu
        $(PC) $(PCOPTS) mFile.pas

file.obj : file.c lang.h mtypes.h errors.h mmem.h file.h rawfile.h
        $(CC) $(CCOPTS) file.c


rawFile.tpu : rawFile.pas asmrfile.obj Errors.tpu mMem.tpu
        $(PC) $(PCOPTS) rawFile.pas

asmrfile.obj : asmrfile.asm lang.inc errors.inc rawfile.inc mmem.inc
        $(ASM) $(ASMOPTS) asmrfile.asm


VU.tpu : VU.pas VU.obj Errors.tpu mMem.tpu
        $(PC) $(PCOPTS) VU.pas

vu.obj : vu.asm lang.inc errors.inc vu.inc mmem.inc sdevice.inc
        $(ASM) $(ASMOPTS) vu.asm
