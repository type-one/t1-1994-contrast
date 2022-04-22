{*      DBP.PAS
 *
 * MIDAS debug module player
 *
 * Copyright 1994 Petteri Kangaslampi and Jarno Paananen
 *
 * This file is part of the MIDAS Sound System, and may only be
 * used, modified and distributed under the terms of the MIDAS
 * Sound System license, LICENSE.TXT. By continuing to use,
 * modify or distribute this file you indicate that you have
 * read the license and understand and accept it fully.
*}


uses crt, MIDAS, Errors, mGlobals, mMem, SDevice, MPlayer, DMA, DSM
{$IFDEF REALVUMETERS}
    , VU
{$ENDIF}
    ;


procedure WaitVR; assembler;
asm
        mov     dx,03DAh
@wvr:   in      al,dx
        test    al,8
        jz      @wvr
end;


procedure WaitDE; assembler;
asm
        mov     dx,03DAh
@wde:   in      al,dx
        test    al,1
        jnz     @wde
end;



procedure SetBorder(color : byte); assembler;
asm
        mov     dx,03C0h
        mov     al,31h
        out     dx,al
        mov     al,color
        out     dx,al
end;



var
    free1, free2 : longint;


procedure showheap;
begin
    free2 := MaxAvail;
    WriteLn(free2, ' bytes memory free - ', free1-free2, ' bytes used.');
end;



var
    error, plMusic : integer;
    module : PmpModule;
    SD : PSoundDevice;
    MP : PModulePlayer;
    key : char;
    meter : word;
    info : PmpInformation;


procedure DrawMeters;
var
    i, error : integer;
    meter, pos : word;
    rate : longint;
    chan : PmpChanInfo;

begin
    { do all channels: }
    for i := 0 to (info^.numChannels-1) do
    begin
        { point chan to current channel information: }
        chan := @info^.chans^[i];

        { check that the channel has a valid instrument set }
        if (chan^.instrument > 0) and
            (chan^.instrument <= module^.numInsts) then
        begin
{$IFDEF REALVUMETERS}
            if realVU = 1 then
            begin
                { read channel playing rate: }
                error := SD^.GetRate(i, @rate);
                if error <> OK then
                    midasError(errorMsg[error]);

                { read channel playing position: }
                error := SD^.GetPosition(i, @pos);
                if error <> OK then
                    midasError(errorMsg[error]);

                { if there is sound being player, calculate VU-meter value: }
                if rate <> 0 then
                begin
                    error := vuMeter(
                        module^.insts^[chan^.instrument-1].sdInstHandle,
                        rate, pos, chan^.volume, @meter);
                    if error <> OK then
                        midasError(errorMsg[error]);
                end
                else
                    { no sound - meter = 0; }
                    meter := 0;
            end
            else
{$ENDIF}
                meter := chan^.volumebar;
        end
        else
        begin
            { no valid instrument - set meter to zero }
            meter := 0;
        end;

        { Draw the VU-meter: }
asm
        cld
        mov     ax,$B800                { point es to screen segment }
        mov     es,ax

        mov     ax,160
        mul     i                       { i = channel number = y-coordinate }
        mov     di,ax                   { address = 160 * i }
        mov     bx,64                   { bx = total amount to draw }
        mov     cx,meter                { cx = vu meter }
        sub     bx,cx                   { bx = amount left after meter }
        test    cx,cx
        jz      @nometer
        mov     ax,$0BFE                { draw first 'meter' boxes with }
        rep     stosw                   { attribute $0B }

@nometer:
        mov     cx,bx                   { cx = amount to draw after meter }
        test    cx,cx
        jz      @done
        mov     ax,$08FE                { draw the rest of the 64 boxes with }
        rep     stosw                   { attribute $0B }
@done:
end;

    end;
end;



BEGIN
    if ParamCount < 1 then
    begin
        WriteLn('Usage:  DBP     <filename> [MIDAS options]');
        halt;
    end;

    free1 := MaxAvail;
    WriteLn(free1, ' bytes free');

    midasSetDefaults;                       { set MIDAS defaults }
    midasParseEnvironment;                  { parse "MIDAS" environment }
    midasParseOptions(2, ParamCount-1);     { parse MIDAS options }
    midasInit;                              { initialize MIDAS }
    SD := SDptr;
    showheap;
    module := midasPlayModule(ParamStr(1), 0); { load and play module }
    MP := MPptr;
    WriteLn('Playing - press any key to stop');

    { allocate memory for Module Player information structure: }
    error := memAlloc(SizeOf(mpInformation), @info);
    if error <> OK then
        midasError(errorMsg[error]);

    { allocate memory for mpInformation channel structures: }
    error := memAlloc(module^.numChans * SizeOf(mpChanInfo), @info^.chans);
    if error <> OK then
        midasError(errorMsg[error]);

    { set number of channels in structure: }
    info^.numChannels := module^.numChans;

    showheap;

    while not KeyPressed do
    begin
        WaitVR;                         { wait for Vertical Retrace }
        WaitDE;                         { wait for Display Enable }
{$IFDEF NOTIMER}

        { If timer is not being used, poll the player manually. Note that this
          should not normally be done, as it changes the tempo when playing
          with GUS, but is here to help debugging. }

        SetBorder(15);
        if SD^.tempoPoll = 1 then
        begin
            error := SD^.Play(@plMusic);
            if error <> OK then
                midasError(errorMsg[error]);
            SetBorder(14);
            error := MP^.Play;
            if error <> OK then
                midasError(errorMsg[error]);
        end
        else
        begin
            error := dmaGetPos(@dsmBuffer, @dsmDMAPos);
            if error <> OK then
                midasError(errorMsg[error]);
            error := SD^.Play(@plMusic);
            if error <> OK then
                midasError(errorMsg[error]);

            while plMusic = 1 do
            begin
                SetBorder(14);
                error := MP^.Play;
                if error <> OK then
                    midasError(errorMsg[error]);
                SetBorder(15);
                error := SD^.Play(@plMusic);
                if error <> OK then
                    midasError(errorMsg[error]);
            end;
        end;
{$ENDIF}
        SetBorder(4);

        { read Module Player information to info^: }
        error := MP^.GetInformation(info);
        if error <> OK then
            midasError(errorMsg[error]);

        { draw VU-meters to top of display: }
        DrawMeters;

        SetBorder(0);
    end;

    key := ReadKey;

    { deallocate channel information structures: }
    error := memFree(info^.chans);
    if error <> OK then
        midasError(errorMsg[error]);

    { deallocate Module Player information structure: }
    error := memFree(info);
    if error <> OK then
        midasError(errorMsg[error]);

    midasStopModule(module);            { stop playing module }
    showheap;
    midasClose;                         { uninitialize MIDAS Sound System }
    showHeap;

{$IFDEF DEBUG}
    errPrintList;
{$ENDIF}
END.
