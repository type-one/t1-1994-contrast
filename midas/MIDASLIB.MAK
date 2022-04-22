#*      MIDASLIB.MAK
#*
#* MIDAS Sound System library makefile
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
CCOPTS = -c -3 -G -ml -I$(BCDIR)\include
ASM = tasm
ASMOPTS = -UT310 -ml -m9 -dNOBORDERCOLOR
LIB = tlib
LIBOPTS = /C


# MIDAS Sound System object files:

MIDASOBJS = midas.obj mglobals.obj asmrfile.obj file.obj errors.obj mmem.obj ems.obj mod.obj modload.obj s3m.obj s3mload.obj timer.obj gus.obj pas.obj wss.obj sb.obj nsnd.obj dsm.obj dma.obj vu.obj


midas.lib : $(MIDASOBJS) midas.h midas.inc
        $(LIB) midas.lib $(LIBOPTS) @mlibobjs


mglobals.obj : mglobals.c
        $(CC) $(CCOPTS) mglobals.c

errors.obj : errors.c lang.h errors.h
        $(CC) $(CCOPTS) errors.c

midas.obj : midas.c midas.h
        $(CC) $(CCOPTS) midas.c

s3mload.obj : s3mload.c mtypes.h errors.h mglobals.h mmem.h sdevice.h \
        mplayer.h s3m.h ems.h vu.h lang.h file.h
        $(CC) $(CCOPTS) s3mload.c

modload.obj : modload.c mtypes.h errors.h mglobals.h mmem.h sdevice.h \
        mplayer.h mod.h ems.h vu.h lang.h file.h
        $(CC) $(CCOPTS) modload.c

mmem.obj : mmem.c lang.h mmem.h errors.h
        $(CC) $(CCOPTS) mmem.c

#rawfile.obj : rawfile.c lang.h mtypes.h errors.h mmem.h rawfile.h
#        $(CC) $(CCOPTS) rawfile.c

asmrfile.obj : asmrfile.asm lang.inc errors.inc rawfile.inc mmem.inc
        $(ASM) $(ASMOPTS) asmrfile.asm

file.obj : file.c lang.h mtypes.h errors.h mmem.h file.h rawfile.h
        $(CC) $(CCOPTS) file.c


s3m.obj : s3m.asm lang.inc errors.inc mglobals.inc s3m.inc mplayer.inc sdevice.inc ems.inc timer.inc
        $(ASM) $(ASMOPTS) s3m.asm

mod.obj : mod.asm lang.inc errors.inc mglobals.inc mod.inc mplayer.inc sdevice.inc ems.inc timer.inc mglobals.inc
        $(ASM) $(ASMOPTS) mod.asm

gus.obj : gus.asm lang.inc mglobals.inc sdevice.inc mmem.inc mglobals.inc
        $(ASM) $(ASMOPTS) gus.asm

sb.obj : sb.asm lang.inc errors.inc sdevice.inc dsm.inc dma.inc
        $(ASM) $(ASMOPTS) sb.asm

wss.obj : wss.asm lang.inc errors.inc sdevice.inc dsm.inc dma.inc
        $(ASM) $(ASMOPTS) wss.asm

pas.obj : pas.asm pas.inc lang.inc errors.inc sdevice.inc dsm.inc dma.inc
        $(ASM) $(ASMOPTS) pas.asm

nsnd.obj : nsnd.asm lang.inc sdevice.inc
	$(ASM) $(ASMOPTS) nsnd.asm

dma.obj : dma.asm lang.inc errors.inc dma.inc mmem.inc
	$(ASM) $(ASMOPTS) dma.asm

dsm.obj : dsm.asm lang.inc errors.inc mglobals.inc dsm.inc dma.inc mmem.inc ems.inc sdevice.inc
	$(ASM) $(ASMOPTS) dsm.asm

timer.obj : timer.asm errors.inc mglobals.inc lang.inc timer.inc ems.inc dma.inc dsm.inc sdevice.inc
        $(ASM) $(ASMOPTS) timer.asm

ems.obj : ems.asm lang.inc errors.inc ems.inc mmem.inc
	$(ASM) $(ASMOPTS) ems.asm

vu.obj : vu.asm lang.inc errors.inc vu.inc mmem.inc sdevice.inc
        $(ASM) $(ASMOPTS) vu.asm



midas.h : lang.h mtypes.h errors.h mglobals.h mmem.h file.h sdevice.h \
          mplayer.h s3m.h mod.h timer.h ems.h dma.h dsm.h vu.h
        touch midas.h

midas.inc : lang.inc errors.inc mglobals.inc mmem.inc sdevice.inc \
            lang.inc errors.inc mglobals.inc mmem.inc rawfile.inc file.inc \
            sdevice.inc mplayer.inc timer.inc mod.inc s3m.inc dma.inc \
            dsm.inc ems.inc vu.inc
        touch midas.inc

file.h : rawfile.h
        touch file.h
