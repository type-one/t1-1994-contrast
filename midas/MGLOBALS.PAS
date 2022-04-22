{*      MGLOBALS.PAS
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
*}


unit mGlobals;


interface


const
    MPHDRSIZE = 1084;                   { header size needed for
                                          ModulePlayer.Identify() }

var
    ALE : integer;                      { should Amiga loops be emulated }
    ptTempo : integer;                  { should PT modules use tempo }
    usePanning : integer;               { should PT modules use cmd 8 for
                                          panning? }
    surround : integer;                 { should Surround be enabled?}
    useEMS : integer;                   { should EMS be used? }
    forceEMS : integer;                 { should _only_ EMS be used? }
    realVU : integer;                   { use real VU meters? }

implementation



BEGIN
    ALE := 0;
    ptTempo := 1;
    usePanning := 1;
    surround := 0;
    useEMS := 0;
    forceEMS := 0;
    realVU := 0;
END.
