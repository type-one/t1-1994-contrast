#*      PAS_EXP.MAK
#*
#* Makefile for MIDAS Pascal examples
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

MIDASDIR = c:\midas


# Compilers and options:

PC = tpc
PCOPTS = /$G+ /U$(MIDASDIR)
ASM = tasm
ASMOPTS = -UT310 -ml -m9 -i$(MIDASDIR) -d__TP__


MIDASTPU = $(MIDASDIR)\midas.tpu

mplay.exe : mplay.pas $(MIDASTPU)
        $(PC) $(PCOPTS) mplay.pas
