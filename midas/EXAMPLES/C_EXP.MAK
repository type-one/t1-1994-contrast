#*      C_EXP.MAK
#*
#* Makefile for MIDAS C-language examples
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
MIDASDIR = c:\midas


# Compilers and options:

CC = bcc
CCOPTS = -c -3 -G -ml -I$(BCDIR)\include;$(MIDASDIR)
ASM = tasm
ASMOPTS = -UT310 -ml -m9 -i$(MIDASDIR)
LINK = tlink
LINKOPTS = -c



MIDASLIB = $(MIDASDIR)\midas.lib

c_exp : mplay.exe scrdemo.exe effects.exe
        touch c_exp


mplay.exe : mplay.obj $(MIDASLIB)
        $(LINK) $(LINKOPTS) $(LIBDIR)\c0l.obj mplay.obj, mplay, , $(LIBDIR)\cl.lib $(MIDASLIB)

mplay.obj : mplay.c
        $(CC) $(CCOPTS) mplay.c


effects.exe : effects.obj $(MIDASLIB)
        $(LINK) $(LINKOPTS) $(LIBDIR)\c0l.obj effects.obj, effects, , $(LIBDIR)\cl.lib $(MIDASLIB)

effects.obj : effects.c
        $(CC) $(CCOPTS) effects.c


scrdemo.exe : scrdemo.obj $(MIDASLIB)
        $(LINK) $(LINKOPTS) $(LIBDIR)\c0l.obj scrdemo.obj, scrdemo, , $(LIBDIR)\cl.lib $(MIDASLIB)

scrdemo.obj : scrdemo.c
        $(CC) $(CCOPTS) scrdemo.c
