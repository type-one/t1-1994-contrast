{*      MPLAY.PAS
 *
 * Minimal module player using MIDAS Sound System
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*}


uses MIDAS;



procedure Usage;
begin
    WriteLn('Usage:  MPLAY   <filename> [options]');
    WriteLn('');
    WriteLn('Options:');
    WriteLn('        -sx     Force Sound Device x (1 = GUS, 2 = PAS, 3 = WSS, 4 = SB,');
    WriteLn('                5 = No Sound)');
    WriteLn('        -pxxx   Force I/O port xxx (hex) for Sound Device');
    WriteLn('        -ix     Force IRQ x for Sound Device');
    WriteLn('        -mxxxxx Set mixing rate to xxxxx Hz');
    WriteLn('        -e      Disable EMS usage');
    WriteLn('        -t      Disable ProTracker BPM tempos');
    WriteLn('        -u      Enable Surround');
    WriteLn('        -oxxx   Force output mode (8 = 8-bit, 1 = 16-bit, s = stereo, m = mono)');
end;



var
    module : pointer;


BEGIN
    { ParamStr(1) should be the module file name and the rest are options
      which MIDAS should handle }

    { If there are no parameters, show usage and exit: }
    if ParamCount < 1 then
    begin
        Usage;
        exit;
    end;

    midasSetDefaults;                   { set MIDAS defaults }
    midasParseEnvironment;              { parse MIDAS environment string }
    midasParseOptions(2, ParamCount-1); { let MIDAS parse all options }
    midasInit;                          { initialize MIDAS Sound System }
    { load module and start playing: }
    module := midasPlayModule(ParamStr(1), 0);

    WriteLn('Playing, press Enter to exit');
    ReadLn;

    midasStopModule(module);            { stop playing }
    midasClose;                         { uninitialize MIDAS }
END.
