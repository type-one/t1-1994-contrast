#*
#* Makefile for Contrast, derived from MIDAS C-language examples
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

BCDIR = .\BCC
LIBDIR = $(BCDIR)\lib
MIDASDIR = .\MIDAS

# Compilers and options:

CC = bcc
CCOPTS = -c -3 -G -ml -I$(BCDIR)\include;$(MIDASDIR)
LINK = tlink
LINKOPTS = -c -3 -s  

MIDASLIB = $(MIDASDIR)\midas.lib

c_exp : contrast.exe
        touch c_exp


contrast.exe : contrast.obj $(MIDASLIB)
        $(LINK) $(LINKOPTS) $(LIBDIR)\c0l.obj contrast.obj @tflobjs, contrast, , $(LIBDIR)\cl.lib $(MIDASLIB)

contrast.obj : contrast.c
        $(CC) $(CCOPTS) contrast.c

