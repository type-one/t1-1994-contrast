What
----

Contrast MS-DOS demo presented by TFL-TDV at Wired 94 Demo Party

Released 30 October 1994
2nd in the Wired 1994 PC Demo competition
MS-Dos

https://demozoo.org/productions/27285/

https://www.youtube.com/watch?v=tV-Lr9DyjNU

https://files.scene.org/view/mirrors/hornet/demos/1994/c/contrast.zip

https://hornet.org/code/demosrc/demos/contrsrc.zip


It was the first demo we did as TFL-TDV group, presented at Wired Party 94 in Mons (Belgium).
TFL-TDV was the union of two smaller belgian groups whose most "coders" members were studying Computer Sciences 
in the same belgian University in Brussels.  I was 20 years old and was starting my 3rd year in Computer Sciences.
We had a lot of self-mockery in the group and didn't take too seriously this first joint production. 

It was developped mainly in x86 16-bit assembly language with a main file written in C that is linked to the MIDAS Sound 
System v0.32 revision C library, a third party library that we used to play the music on several popular sound cards 
(Sound Blaster, Gravis Ultra Sound).

It is running on standard VGA 256 colors graphics cards that were used in the 90s and is working fine with DOSBox emulator.
It uses several graphics mode/tricks to speed up the computation (160x100, 320x200, Mode X for double/quad buffering).

In 16-bit MS-DOS we could only access segments of 64 kb in memory, so the video framebuffer could only be accessed per slice
and the VGA tricks above allowed to friendly address up to 256 kb of video frame buffer to store several 320x200 256 colors
frames (each frame consuming less than 64 kb).  Horizontal and vertical hardware pixel doubling was also a nice trick to 
reduce bandwidth and allow fullscreen distorsions. 

The target platform was the 386 DX 33 Mhz computers with a minimum of 4 Mb of RAM.  It was still even running on a
386 SX 16 Mhz.

Some of us in the group had still Intel 386 CPUs while others had Intel 486 CPUs, but the code was optimized
to have a smooth rendering on the lowest machines.  Computation uses fixed point arithmetic and doesn't require any
FPU.

The demo itself is a 16-bit executable using Intel 386 instructions.

Tricks like "per frame" self-modifying code were used to spare 386 registers usage and avoid the use of variables in the 
tiny inner loops of some effects (distorsions, rotazooms, voxel waves). Sprites were displayed using generated code to
spare bandwidth.

My favorite "IDE" at that time was just working in MS-DOS with Norton Commander with shortcuts to launch QEdit, MASM and 
a TSR called "HelpPC" that was providing me all the contextual information on assembly language mnemonics and their cycles 
on 386 and 486.  Borland C++ was just used to compile the main file to link with MIDAS sound library.

The released demo executable was compressed using PKLITE.

http://fileformats.archiveteam.org/wiki/PKLITE

The binary assets are grouped into a PDFIK data archive, a kind of virtual simple filesystem callable
from assembly language routines. 

The music (4 channels mod) was composed by Magic Fred on Atari ST with ProTracker.  The 16 colors pictures were also 
drawn on Atari ST with Deluxe Paint.  The 256 colors pictures were drawn by Zoltan on PC with Deluxe Paint and Fractal 
Paint (if I remember well)


Build
-----

To build the executable you will need MASM assembler 6.x and Borland C++ 3.1 16-bit compiler and linker.

Instructions to use MASM 6.14:

https://service.scs.carleton.ca/sivarama/asm_book_web/free_MASM.html

http://www.masm32.com

Microsoft's MASM 6.14 is included in the masm32 package.

To get MASM 6.14, download masm32V8.zip from:

http://www.masm32.com/ (2.98 MB)

Unzip and run install.exe. It creates masm32 directory. 
The MASM files (ml.exe and ml.err) are in the masm32/bin directory.

You can just drop these 2 files in the src folder.

Borland C++ is also a legacy product of the 90s that can be found on some 
abandonware internet archives:

https://archive.org/details/bcpp31

Download BCC31.ZIP and unzip in src/BCC folder

To compile the executable:
- In Windows, launch BUILDOBJ.BAT in an MS-DOS shell.  This will build the
  x86 asm files using MASM
- In DOSBox, relying on the previously assembled files, run DODEMO.BAT. 
  This will run the Borland C++ makefile and link with the assembled file to
  produce a 16-bit 386 executable.
- Use pklite to compress the executable.

To compile the assets:
- In DOSBox, go to DATA and type DODAT.BAT.  This will build the .dat file 

The midas folder contains the source code of MIDAS Sound System v0.32 revision C,
the one that is used in the demo.  This folder is an unzipped version I found of 
my old HDD backup.  This version is still supporting MS-DOS 16-bit.  An older 
version is available at https://demozoo.org/productions/145174/


Run
---

On **DosBox** you have to use machine=vgaonly in the emulator settings

The standard settings of DOSBox for realmode applications doesn't work well with this old demo.
Runs perfectly in DOSBox with some settings changed:
- core = dynamic
- cycles = 6000
- machine = vgaonly


On real MS-DOS PC with MS-DOS 6.2+, an AdLib compatible card (SoundBlaster, SoundBlaster Pro, SoundBlaster 16, AWE32/64,
Gravis UltraSound) and an ISA/VESA VGA card or some older PCI VGA cards (like S3 Trio, S3 Virge).

I still achieve to run it on my old (preserved) 486 DX2-66/S3 (1995) and a K6-2 500/S3 Virge DX (1999), that are still working 
today in 2022.

In src/CONFIG folder there are some .bat files with settings for 486 (VESA LOCAL BUS/PCI), 486 (ISA), 386 DX and 386 SX

Use the +/- key on numeric pad to display the CPU time consumed in scanlines.
Use ESC to exit
Use space bar to skip a part



