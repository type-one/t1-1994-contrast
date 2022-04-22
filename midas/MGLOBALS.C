/*      MGLOBALS.C
 *
 * MIDAS Sound System global variables
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*/

short           useEMS;                 /* should EMS be used? */
short           forceEMS;               /* should _only_ EMS be used? */
short           ALE;                    /* should Amiga loops be emulated */
short           ptTempo;                /* should PT modules use tempo */
short           usePanning;             /* should PT modules use cmd 8 for
                                           panning? */
short           surround;               /* should Surround be enabled?
                                           (mainly for GUS)*/
short           realVU;                 /* use real VU meters? */
