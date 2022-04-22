;*	SB.ASM
;*
;* Sound Blaster series Sound Device, v2.00
;*
;* Copyright 1994 Petteri Kangaslampi and Jarno Paananen
;*
;* This file is part of the MIDAS Sound System, and may only be
;* used, modified and distributed under the terms of the MIDAS
;* Sound System license, LICENSE.TXT. By continuing to use,
;* modify or distribute this file you indicate that you have
;* read the license and understand and accept it fully.
;*



IDEAL
P386
JUMPS

INCLUDE "lang.inc"
INCLUDE "errors.inc"
INCLUDE "sdevice.inc"
INCLUDE "dsm.inc"
INCLUDE "dma.inc"



;/***************************************************************************\
;*       enum sbFunctIDs
;*       ----------------
;* Description:  ID numbers for SB Sound Device functions
;\***************************************************************************/

enum    sbFunctIDs \
        ID_sbDetect = ID_sb, \
        ID_sbInit, \
        ID_sbClose



DATASEG

oldIRQ		DD	?		; old IRQ vector
oldIRQmask	DB	?		; old IRQ mask
sb22C		DW	?		; SB DSP data port (2xCh)
sbTimeConstant  DB      ?               ; SB Transfer Time Constant
sbRate		DW	?		; SB actual playing rate
sbVersion       DW      ?               ; DSP version number
sbMode          DW      ?               ; actual output mode
sbInterrupt     DB      ?               ; IRQ interrupt number
sbBlockLength   DW      ?               ; DSP playing block length
sbOutputFilter  DB      ?               ; initial output filter status
sbStereoOK      DB      ?               ; flag used by sbSetStereo()




IDATASEG


GLOBAL	SB : SoundDevice

SB		SoundDevice	< \
        0, 220h, 05h, 01h, sdUnInitialized, \
        sdMono or sdStereo or sd8bit or sd16bit or sdNormalQ, \
	far ptr sbID,\
	far ptr sbDetect, \
	far ptr sbInit, \
	far ptr sbClose, \
	far ptr dsmGetMixRate, \
	far ptr dsmGetMode, \
	far ptr dsmOpenChannels, \
	far ptr dsmCloseChannels, \
	far ptr dsmClearChannels, \
	far ptr dsmMute, \
	far ptr dsmPause, \
	far ptr dsmSetMasterVolume, \
	far ptr dsmPlaySound, \
	far ptr dsmStopSound, \
	far ptr dsmSetRate, \
	far ptr dsmGetRate, \
	far ptr dsmSetVolume, \
	far ptr dsmSetInstrument, \
	far ptr dsmSetPosition, \
	far ptr dsmGetPosition, \
	far ptr dsmSetPanning, \
	far ptr dsmGetPanning, \
	far ptr dsmMuteChannel, \
	far ptr dsmAddInstrument, \
	far ptr dsmRemInstrument, \
	far ptr dsmSetUpdRate, \
	far ptr dsmPlay >

sbID            DB      "Sound Blaster series Sound Device v2.00",0


        ; "fake" one-byte DMA buffer used by sbSetStereo()
sbStereoDMABuffer dmaBuffer     < 0, 0, 1, 0, -1 >



CODESEG



PUBLIC	sbDetect
PUBLIC	sbInit
PUBLIC	sbClose




;/***************************************************************************\
;*
;* Function:    sbWait
;*
;* Description: Waits until data can be written to the DSP command/data port
;*              2xCh
;*
;* Destroys:    ax, cx, dx. dx now contains the DSP command/data port value,
;*              2xCh.
;*
;\***************************************************************************/

PROC NOLANGUAGE sbWait  NEAR

        mov     dx,[sb22C]
        mov     cx,0FFFFh

@@wait:
        in      al,dx                   ; read port 22Ch
        test    al,al                   ; is bit 7 set?
        jns     @@ok                    ; if not, DSP is ready
        loop    @@wait                  ; read maximum of 0FFFFh times


        ; The bit is still set after 0FFFFh reads, so apparently the DSP
        ; is for some reason locked up. Return error.

        mov     ax,errSDFailure         ; Sound Device hardware failure
        jmp     @@done

@@ok:
        xor     ax,ax

@@done:
        ret
ENDP




;/***************************************************************************\
;*
;* Macro:	SBCMD
;*
;* Description: Writes a command to SB's DSP. Jumps to label @@err if an
;*              error occurs, with the error code in ax
;*
;* Input:	command 	command
;*
;* Destroys:	see function sbCommand
;*
;\***************************************************************************/

MACRO	SBCMD	command
        mov     bl,command
	call	sbCommand
        test    ax,ax
        jnz     @@err
ENDM




;/***************************************************************************\
;*
;* Function:	sbCommand
;*
;* Description: Writes a command to SB's DSP
;*
;* Input:       bl      command
;*
;* Returns:     MIDAS error code in ax
;*
;* Destroys:	ax, dx, cx
;*
;\***************************************************************************/

PROC NOLANGUAGE sbCommand	NEAR

        call    sbWait                  ; wait until data or command can be
        test    ax,ax                   ; written to the DSP
        jnz     @@done

        mov     al,bl                   ; write the command
	out	dx,al

        xor     ax,ax

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:    sbRead
;*
;* Description: Reads a byte from the DSP data port
;*
;* Returns:     bl              byte read
;*              ax              MIDAS error copde
;*
;* Destroys:    ax, cx, dx
;*
;\***************************************************************************/

PROC NOLANGUAGE sbRead          NEAR

        mov     dx,[SB.port]
        add     dx,0Eh                  ; dx = 2xEh = SB DSP Data Available
        mov     cx,0FFFFh               ; port
@@wait:
        in      al,dx
        test    al,al                   ; wait until bit 7 is set
        js      @@dok
        loop    @@wait

        ; Read port 2xEh 65535 time and bit 7 is still zero - failure
        mov     ax,errSDFailure
        jmp     @@done

@@dok:  add     dx,0Ah-0Eh              ; dx = 2xAh = SB DSP Data port
        in      al,dx                   ; read data from port
        mov     bl,al                   ; and store it in bl

        xor     ax,ax                   ; success

@@done:
        ret
ENDP




;/***************************************************************************\
;*
;* Function:    int sbDetect(int *result);
;*
;* Description: Detects Sound Blaster soundcard
;*
;* Returns:     MIDAS error code.
;*              1 stored to *result if SB was detected, 0 if not.
;*
;\***************************************************************************/

PROC    sbDetect        FAR     result : dword
USES	si,di
LOCAL	old21 : byte, oldA1 : byte, oldIRQ2 : dword, oldIRQ3 : dword, \
	oldIRQ5 : dword, oldIRQ7 : dword, oldIRQ10 : dword

	mov	bx,210h 		; port to try first

@@tryport:
	mov	dx,bx
	add	dx,6
	mov	al,1
	out	dx,al

	in	al,dx
	in	al,dx
	in	al,dx			; try to reset SB
	in	al,dx
	in	al,dx

	mov	al,0
	out	dx,al


	add	dx,0Eh-6
	mov	cx,1000

@@pwait:
	in	al,dx
	or	al,al			; wait until bit 7 in port 2xE is 1
	js	@@pok1			;  or until port has been read 1000
	loop	@@pwait 		;  times

	jmp	@@pnot			; port was read 1000 times, SB is NOT
					;  in this port address

@@pok1: sub	dx,4
	mov	cx,1000

@@pw2:	in	al,dx			; wait until port 2xAh has a value
	cmp	al,0AAh 		; 0AAh or 1000 times
	je	@@pok
	loop	@@pw2

	jmp	@@pnot			; port 2xAh was not 0AAh, SB is NOT
					;  in this port address
@@pnot:
	add	bx,10h
	cmp	bx,260h
	jna	@@tryport

        jmp     @@nosb


@@pok:	mov	[SB.port],bx
	add	bx,0Ch			; store detected port value
	mov	[sb22C],bx

	mov	[SB.DMA],1		; !!! assume DMA channel 1


	mov	ax,350Ah
	int	21h			; save IRQ 2 interrupt vector
	mov	[word oldIRQ2],bx
	mov	[word oldIRQ2+2],es

	mov	ax,350Bh
	int	21h			; save IRQ 3 interrupt vector
	mov	[word oldIRQ3],bx
	mov	[word oldIRQ3+2],es

	mov	ax,350Dh
	int	21h			; save IRQ 5 interrupt vector
	mov	[word oldIRQ5],bx
	mov	[word oldIRQ5+2],es

	mov	ax,350Fh
	int	21h			; save IRQ 7 interrupt vector
	mov	[word oldIRQ7],bx
	mov	[word oldIRQ7+2],es

	mov	ax,3572h
	int	21h			; save IRQ 10 interrupt vector
	mov	[word oldIRQ10],bx
	mov	[word oldIRQ10+2],es


	push	ds

	mov	ax,cs
	mov	ds,ax

	mov	ax,250Ah		; set IRQ2 interrupt vector to
	mov	dx,offset @@IRQ2	;  @@IRQ2
	int	21h

	mov	ax,250Bh		; set IRQ3 interrupt vector to
	mov	dx,offset @@IRQ3	;  @@IRQ3
	int	21h

	mov	ax,250Dh		; IRQ5
	mov	dx,offset @@IRQ5
	int	21h

	mov	ax,250Fh		; IRQ 7
	mov	dx,offset @@IRQ7
	int	21h

	mov	ax,2572h
	mov	dx,offset @@IRQ10	; IRQ 10
	int	21h

	pop	ds


	in	al,21h
	mov	[old21],al		; save old IRQ mask
	and	al,01010011b		; enable IRQ 2, 3, 5, 7
	out	21h,al

	in	al,0A1h
	mov	[oldA1],al		; save old IRQ mask
	and	al,11111011b		; enable IRQ 10
	out	0A1h,al


; Initialize DMA-controller:

	mov	al,5			; mask out channel 1
	out	0Ah,al

	mov	al,0			; reset counter
	out	0Ch,al

	mov	al,49h			; transfer from memory to DSP
	out	0Bh,al

	mov	al,0
	out	02h,al			; start pointer low & high
	out	02h,al
	out	83h,al			; start page address

	mov	al,1			; transfer length low
	out	03h,al

	mov	al,0			; transfer length high
	out	03h,al

	mov	al,1			; enable channel 1
	out	0Ah,al


; Initialize DSP

	SBCMD	40h			; set speed
	SBCMD	200			; speed
	SBCMD	14h			; set length
	SBCMD	1			; length low
	SBCMD	0			; length high

	xor	bl,bl			; IRQ number
	mov	cx,65535
	mov	dx,[sb22C]

@@w:	test	bl,bl			; wait until an IRQ comes and sets
	jnz	@@irqok 		; the IRQ number or 65535 times
	in	al,dx			; delay...
	loop	@@w

        jmp     @@nosb                  ; waited 65535 times without an IRQ
                                        ; - no SB

@@irqok:
	mov	[SB.IRQ],bl		; store IRQ number

	mov	al,[old21]
	out	21h,al			; restore old IRQ masks
	mov	al,[oldA1]
	out	0A1h,al

	push	ds

	mov	ax,250Ah
	lds	dx,[oldIRQ2]		; restore IRQ 2 interrupt vector
	int	21h

	mov	ax,250Bh
	lds	dx,[oldIRQ3]		; restore IRQ 3 interrupt vector
	int	21h

	mov	ax,250Dh
	lds	dx,[oldIRQ5]		; restore IRQ 5 interrupt vector
	int	21h

	mov	ax,250Fh
	lds	dx,[oldIRQ7]		; restore IRQ 7 interrupt vector
	int	21h

	mov	ax,2572h
	lds	dx,[oldIRQ10]		; restore IRQ 10 interrupt vector
	int	21h

	pop	ds


        les     bx,[result]             ; SB succesfully detected
        mov     [word es:bx],1
        xor     ax,ax
        jmp     @@done



@@IRQ2: mov	bl,2
	jmp	@@id1

@@IRQ3: mov	bl,3
	jmp	@@id1

@@IRQ5: mov	bl,5
	jmp	@@id1

@@IRQ7: mov	bl,7
	jmp	@@id1

@@IRQ10:
	mov	bl,10
	jmp	@@id2


@@id1:	mov	al,20h			; send EOI to Interrupt controller 1
	out	20h,al
	mov	dx,[SB.port]
	add	dx,0Eh			; and to SB
	in	al,dx
	iret

@@id2:	mov	al,20h
	out	0A0h,al
	mov	dx,[SB.port]
	add	dx,0Eh
	in	al,dx
	iret

@@nosb:
        les     bx,[result]
        mov     [word es:bx],0          ; Sound Blaster not detected
        xor     ax,ax
        jmp     @@done

@@err:
        ERROR   ID_sbDetect


@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:    int sbInit(ushort mixRate, ushort mode);
;*
;* Description: Initializes Sound Blaster
;*
;* Input:	mixRate 	mixing rate
;*		mode		output mode (see enum sdMode)
;*
;* Returns:     MIDAS error code
;*
;\***************************************************************************/

PROC	sbInit		FAR	mixRate : word, mode : word

        mov     ax,[SB.port]
	add	ax,0Ch			; set sb22C variable to real SB DSP
	mov	[sb22C],ax		; command port


	mov	dx,[SB.port]
	add	dx,6
        mov     al,1                    ; reset SB DSP by first writing 1 to
	out	dx,al			; port 2x6h
        mov     cx,8
@@delay:
        in      al,dx                   ; wait for a while (3 usecs)
        loop    @@delay
	xor	al,al			; and write 0 to port 2x6h
	out	dx,al


	mov	dx,[SB.port]
	add	dx,0Eh			; SB data available port 2xEh
	mov	cx,1000

@@wd1:	in	al,dx
	test	al,al
	js	@@ok1			; wait until bit 7 (data available)
	loop	@@wd1			; is 1 or 1000 times
        jmp     @@sberr                 ; no data - no SB

@@ok1:	add	dx,0Ah-0Eh		; read data port (2xAh)
	mov	cx,1000

@@wd2:	in	al,dx
	cmp	al,0AAh 		; wait until data is 0AAh or 1000
	je	@@sbok			; times
	loop	@@wd2
        jmp     @@sberr                 ; no 0AAh - no SB

@@sbok:                                 ; SB resetted succesfully


        SBCMD   0E1h                    ; Get DSP version number
        call    sbRead                  ; read version high byte
        test    ax,ax
        jnz     @@err
        mov     bh,bl
        call    sbRead                  ; read version low byte
        test    ax,ax
        jnz     @@err
;        mov     bx,100h ;!!!
        mov     [sbVersion],bx          ; store version number

        cmp     bx,0400h                ; DSP version >= 4.00?
        jae     @@modeall               ; if yes, all modes supported
        cmp     bx,0300h                ; DSP version >= 3.00?
        jae     @@modestereo            ; if yes, stereo is supported

        ; DSP version < 3.00 - only 8-bit mono
        mov     [sbMode],sd8bit or sdMono
        jmp     @@moded

@@modestereo:
        ; DSP version < 4.00 - only 8-bit mono or stereo
        mov     ax,sd8bit               ; 8-bit output
        test    [mode],sdMono           ; is mono mode forced?
        jnz     @@smono
        or      ax,sdStereo             ; no, use stereo
        jmp     @@sok
@@smono:
        or      ax,sdMono               ; yes, use mono
@@sok:
        mov     [sbMode],ax             ; store output mode
        jmp     @@moded


@@modeall:
        ; DSP version >= 4.00 - all output modes
; SB 16 bug even with MIDAS 3.2c :-(

;        test    [mode],sd8bit           ; force 8-bit?
;	jnz	@@8b
        
;        mov     ax,sd16bit              ; if not, use 16 bits
; 	jmp	@@bit
@@8b:   mov     ax,sd8bit

@@bit:	test	[mode],sdMono		; force mono?
	jnz	@@mono
        or      ax,sdStereo             ; if not, use stereo
	jmp	@@mst
@@mono: or      ax,sdMono

@@mst:  mov     [sbMode],ax


@@moded:
        test    [mode],sdLowQ           ; force low or high quality?
	jnz	@@lowq
	test	[mode],sdHighQ
	jnz	@@highq
        or      [sbMode],sdNormalQ      ; if not, use normal quality
	jmp	@@mode
@@lowq: or      [sbMode],sdLowQ
	jmp	@@mode
@@highq:
        or      [sbMode],sdHighQ

@@mode: ; output mode set up


	mov	al,[SB.IRQ]
        cmp     al,7                    ; IRQ number > 7 ?
	ja	@@i8

	add	al,8			; no, interrupt number is IRQ+8
	jmp	@@ivect

@@i8:	add	al,70h-8		; yes, interrupt number is IRQ+68h

@@ivect:
        mov     [sbInterrupt],al        ; save interrupt number

	mov	ah,35h
	int	21h			; save old IRQ vector
	mov	[word oldIRQ],bx
	mov	[word oldIRQ+2],es

	mov	al,[SB.IRQ]
	cmp	al,7			; is IRQ > 7 ?
	ja	@@i82

	mov	cl,al			; no
	in	al,21h
	mov	[oldIRQmask],al 	; save old IRQ mask
	mov	bl,not 1
	rol	bl,cl			; enable SB's IRQ
	and	al,bl
	out	21h,al
	jmp	@@idone

@@i82:	mov	cl,al
	sub	cl,8
	in	al,0A1h
	mov	[oldIRQmask],al 	; save old IRQ mask
	mov	bl,not 1
	rol	bl,cl			; enable SB's IRQ
	and	al,bl
	out	0A1h,al

@@idone:

        cmp     [sbVersion],0400h       ; DSP version >= 4.00 ?
        jae     @@userate               ; if so, the sampling rate is directly
                                        ; used

        cmp     [sbVersion],0201h       ; DSP version < 2.01?
        jb      @@limit1                ; if yes, rate limit is 21739Hz

        ; DSP >= 2.01 - sampling rate limit is 43478Hz, so the maximum
        ; Time Constant is 233
        mov     ecx,233
        jmp     @@timeconstant

@@limit1:
        ; DSP < 2.01 - sampling rate limit is 21739Hz, making the maximum
        ; Time Constant 210
        mov     ecx,210

@@timeconstant:
        ; Calculate the Transfer Time Constant for DSP < 4.00.

	movzx	ebx,[mixRate]
        test    [sbMode],sdStereo       ; use stereo?
        jz      @@nostt                 ; if yes, multiply rate with 2 when
        shl     ebx,1                   ; calculating Time Constant

@@nostt:
        mov     eax,1000000             ; eax = Time Constant =
        cdq                             ; 256 - (1000000 / rate)
        div     ebx
	neg	eax
	add	eax,256

        test    eax,eax
        jns     @@non1                  ; Time Constant must be nonnegative
        xor     eax,eax

@@non1: cmp     eax,ecx                 ; ecx is the maximum Time Constant
        jbe     @@noa1
        mov     eax,ecx                 ; limit Time Constant to ecx value

@@noa1: mov     [sbTimeConstant],al     ; store Transfer Time Constant

	mov	ebx,256
	sub	ebx,eax
	mov	eax,1000000		; calculate actual playing rate
        cdq                             ; (= 1000000 / (256 - TimeConstant))
	div	ebx

        test    [sbMode],sdStereo       ; using stereo?
        jz      @@nostt2
        shr     eax,1                   ; divide with 2 to get rate

@@nostt2:
	mov	[sbRate],ax
        jmp     @@initdsm


@@userate:
        ; DSP >= 4.00 - output uses the sampling rate directly
        mov     ax,[mixRate]
        mov     [sbRate],ax


@@initdsm:
        ; Initialize DSM:
        call    dsmInit LANG, [sbRate], [sbMode]
        test    ax,ax
        jnz     @@err

        cmp     [sbVersion],0400h       ; if playing stereo on a DSP < 4.00,
        jae     @@dmaok                 ; set stereo mode and output one
        test    [sbMode],sdStereo       ; silent byte before starting the
        jz      @@dmaok                 ; actual transfer

        call    sbSetStereo
        test    ax,ax
        jnz     @@err

@@dmaok:
        ; start playing the DSM DMA buffer:
        movzx   ax,[SB.DMA]
	call	dmaPlayBuffer LANG, seg dsmBuffer offset dsmBuffer, \
                ax, 1
        test    ax,ax
        jnz     @@err

        mov     [sbBlockLength],07FF0h  ; set DSP block length to 0FFF0h
                                        ; samples - autoinit DMA mode takes
                                        ; care of wrapping

        cmp     [sbVersion],0200h       ; is DSP version < 2.00 ?
        jb      @@v100                  ; if is, auto-initialize mode is not
                                        ; available

        ; set up interrupt service routine for auto-initialize mode:
        push    ds
        mov     ah,25h
        mov     al,[sbInterrupt]
        mov     dx,seg sbAutoinitIRQ
        mov     ds,dx
        mov     dx,offset sbAutoinitIRQ
        int     21h
        pop     ds

        cmp     [sbVersion],0400h       ; is DSP version >= 4.00 ?
        jae     @@v400                  ; if is, use DSP 4.00 playing mode
                                        ; for all output modes

        cmp     [sbVersion],0201h       ; is DSP version >= 2.01 ?
        jae     @@v201                  ; if is, high-speed output is
                                        ; available

        jmp     @@v200


@@v100:
        ; DSP version < 2.00 - play using mono single-cycle mode

        ; set up interrupt service routine for single-cycle mode:
        push    ds
        mov     ah,25h
        mov     al,[sbInterrupt]
        mov     dx,seg sbSingleCycleIRQ
        mov     ds,dx
        mov     dx,offset sbSingleCycleIRQ
        int     21h
        pop     ds

        ; start playing:
        call    sbPlayMonoSingleCycle
        jmp     @@playing

@@v200:
        ; DSP version 2.00 - play using mono auto-initialize mode
        call    sbPlayMonoAutoinit
        jmp     @@playing

@@v201:
        ; DSP version >= 2.01 - high-speed output is available
        test    [sbMode],sdStereo       ; use stereo?
        jnz     @@plstereo              ; if yes, play using stereo mode

        cmp     [sbRate],22000          ; is sampling rate over 22000Hz?
        ja      @@highspeed             ; if is, use high-speed mode

        ; DSP >= 2.01, mono, rate <= 22000Hz - play using mono
        ; auto-initialize mode
        call    sbPlayMonoAutoinit
        jmp     @@playing

@@highspeed:
        ; DSP >= 2.01, mono, rate > 22000Hz - play using mono high-speed
        ; (auto-initialize) mode
        call    sbPlayMonoHighSpeed
        jmp     @@playing

@@plstereo:
        ; DSP >= 2.01 (actually >= 3.00), stereo - play using stereo
        ; high-speed auto-initialize mode
        call    sbPlayStereo
        jmp     @@playing

@@v400:
        ; DSP >= 4.00 - use DSP v4.00 auto-initialize mode for all output
        ; modes
        call    sbPlay400

@@playing:
        test    ax,ax
        jnz     @@err

	mov	[SB.status],sdOK
        xor     ax,ax                   ; SB succesfully initialized
	jmp	@@done

@@sberr:
        mov     ax,errSDFailure         ; Hardware failure

@@err:  ERROR   ID_sbInit

@@done:
	ret
ENDP




;/***************************************************************************\
;*
;* Function:    sbPlayMonoSingleCycle
;*
;* Description: Starts playing the buffer using 8-bit mono Single-Cycle mode
;*
;\***************************************************************************/

PROC NOLANGUAGE sbPlayMonoSingleCycle   NEAR

        SBCMD   0D1h                    ; turn on DAC speaker
        SBCMD   40h                     ; set Transfer Time Constant
        SBCMD   [sbTimeConstant]        ; Time Constant
        SBCMD   14h                     ; 8-bit PCM output
        SBCMD   <[byte sbBlockLength]>    ; block length low byte
        SBCMD   <[byte sbBlockLength+1]>  ; block length high byte

        xor     ax,ax

@@err:
        ret
ENDP




;/***************************************************************************\
;*
;* Function:    sbSingleCycleIRQ
;*
;* Description: SB DSP interrupt service routine for 8-bit Single-Cycle mode
;*
;\***************************************************************************/

PROC NOLANGUAGE sbSingleCycleIRQ

        sti
	push	ax
	push	cx
	push	dx			; save all registers that will be
	push	ds			; changed

	mov	ax,@data
	mov	ds,ax

        SBCMD   14h                     ; 8-bit PCM output
        SBCMD   <[byte sbBlockLength]>    ; block length low byte
        SBCMD   <[byte sbBlockLength+1]>  ; block length high byte

@@err:  ; no error handling can be done here

        mov     dx,[SB.port]
        add     dx,0Eh                  ; acknowledge DSP interrupt
	in	al,dx

        cmp     [SB.IRQ],7
	ja	@@upirq

	mov	al,20h			; send End Of Interrupt command to
	out	20h,al			; PIC
	jmp	@@done

@@upirq:
	mov	al,20h			; send EOI to PIC #2 (IRQ > 7)
	out	0A0h,al

@@done:
	pop	ds
	pop	dx
	pop	cx
	pop	ax

	iret
ENDP




;/***************************************************************************\
;*
;* Function:    sbPlayMonoAutoinit
;*
;* Description: Starts playing the buffer using 8-bit Auto-initialize mode
;*
;\***************************************************************************/

PROC NOLANGUAGE sbPlayMonoAutoinit      NEAR

        SBCMD   0D1h                    ; turn on DAC speaker
        SBCMD   40h                     ; set DSP Transfer Time Constant
        SBCMD   [sbTimeConstant]        ; Transfer Time Constant
        SBCMD   48h                     ; set DSP transfer block size
        SBCMD   <[byte sbBlockLength]>    ; block length low byte
        SBCMD   <[byte sbBlockLength+1]>  ; block length high byte
        SBCMD   1Ch                     ; start 8-bit PCM output

        xor     ax,ax

@@err:
        ret
ENDP




;/***************************************************************************\
;*
;* Function:    sbAutoinitIRQ
;*
;* Description: SB DSP interrupt service routine for 8-bit Auto-initialize
;*              mode
;*
;\***************************************************************************/

PROC NOLANGUAGE sbAutoinitIRQ

        sti
	push	ax
	push	cx
	push	dx			; save all registers that will be
	push	ds			; changed

	mov	ax,@data
	mov	ds,ax

        test    [sbMode],sd16bit        ; 16-bit output mode?
        jnz     @@16

        mov     dx,[SB.port]
        add     dx,0Eh                  ; acknowledge DSP interrupt
        in      al,dx
        jmp     @@ackdone

@@16:
        mov     dx,[SB.port]
        add     dx,0Fh                  ; acknowledge DSP interrupt
        in      al,dx

@@ackdone:
        cmp     [SB.IRQ],7
	ja	@@upirq

	mov	al,20h			; send End Of Interrupt command to
	out	20h,al			; PIC
	jmp	@@done

@@upirq:
	mov	al,20h			; send EOI to PIC #2 (IRQ > 7)
	out	0A0h,al

@@done:
	pop	ds
	pop	dx
	pop	cx
	pop	ax

	iret
ENDP




;/***************************************************************************\
;*
;* Function:    sbPlayMonoHighSpeed
;*
;* Description: Starts playing the buffer using 8-bit mono High-Speed
;*              Auto-initialize mode
;*
;\***************************************************************************/

PROC NOLANGUAGE sbPlayMonoHighSpeed     NEAR

        SBCMD   0D1h                    ; turn on DAC speaker
        SBCMD   40h                     ; set DSP transfer Time Constant
        SBCMD   [sbTimeConstant]        ; transfer Time Constant
        SBCMD   48h                     ; set DSP transfer block size
        SBCMD   <[byte sbBlockLength]>    ; block length low byte
        SBCMD   <[byte sbBlockLength+1]>  ; block length high byte
        SBCMD   90h                     ; 8-bit PCM high-speed output

        xor     ax,ax

@@err:
        ret
ENDP




;/***************************************************************************\
;*
;* Function:    sbSetStereo
;*
;* Description: Sets the SB hardware to stereo mode and plays a single
;*              silent byte. Called before starting stereo transfer on
;*              DSP < 4.00 to make sure that the channels are the right
;*              way and not reversed (left comes from left and right from
;*              right).
;*
;\***************************************************************************/

PROC NOLANGUAGE sbSetStereo     NEAR

        SBCMD   0D1h

        ; set up the IRQ handler for transfer:
        mov     dx,[SB.port]
        add     dx,04h
        mov     al,0Eh
        out     dx,al                   ; set the mixer to stereo mode
        inc     dx
        in      al,dx
        or      al,2
        out     dx,al

;        xor ax,ax ;!!!
;        ret ;!!!

        push    ds
        mov     ah,25h
        mov     al,[sbInterrupt]
        mov     dx,seg @@irqhandler
        mov     ds,dx
        mov     dx,offset @@irqhandler
        int     21h
        pop     ds

        ; program the DMA controller for single-cycle output:
        movzx   ax,[SB.DMA]
        call    dmaPlayBuffer LANG, \
                seg sbStereoDMABuffer offset sbStereoDMABuffer, ax, 0
        test    ax,ax
        jnz     @@err

        mov     [sbStereoOK],0

        SBCMD   14h
        SBCMD   0                       ; program the DSP to output one
        SBCMD   0                       ; silent byte (80h)

        ; wait until the IRQ occurs:
@@w:
        cmp     [sbStereoOK],1
        jne     @@w

        xor     ax,ax

@@err:
        ret


@@irqhandler:
        ; IRQ handler routine:

        push    ax
	push	cx
	push	dx			; save all registers that will be
	push	ds			; changed

	mov	ax,@data
	mov	ds,ax

        mov     [sbStereoOK],1          ; set interrupt flag

        mov     dx,[SB.port]
        add     dx,0Eh                  ; acknowledge DSP interrupt
	in	al,dx

        cmp     [SB.IRQ],7
	ja	@@upirq

	mov	al,20h			; send End Of Interrupt command to
	out	20h,al			; PIC
	jmp	@@done

@@upirq:
	mov	al,20h			; send EOI to PIC #2 (IRQ > 7)
	out	0A0h,al

@@done:
	pop	ds
	pop	dx
	pop	cx
	pop	ax

        iret
ENDP




;/***************************************************************************\
;*
;* Function:    sbPlayStereo
;*
;* Description: Starts playing the buffer using 8-bit stereo High-Speed
;*              Auto-initialize mode
;*
;\***************************************************************************/

PROC NOLANGUAGE sbPlayStereo    FAR

        SBCMD   0D1h                    ; turn on DAC speaker
        SBCMD   40h                     ; set DSP transfer Time Constant
        SBCMD   [sbTimeConstant]        ; transfer Time Constant

        ; save output filter status and turn it off:
        mov     dx,[SB.port]
        add     dx,04h
        mov     al,0Ch
        out     dx,al
        inc     dx
        in      al,dx
        mov     [sbOutputFilter],al
        or      al,20h
        out     dx,al

        SBCMD   48h                     ; set DSP transfer block size
        SBCMD   <[byte sbBlockLength]>    ; block length low byte
        SBCMD   <[byte sbBlockLength+1]>  ; block length high byte
        SBCMD   90h                     ; 8-bit PCM high-speed output

        xor     ax,ax

@@err:
        ret
ENDP




;/***************************************************************************\
;*
;* Function:    sbPlay400
;*
;* Description: Starts playing the buffer using the DSP 4.00 Auto-initialize
;*              transfer
;*
;\***************************************************************************/

PROC NOLANGUAGE sbPlay400       NEAR

        SBCMD   41h                     ; set DSP output sampling rate
        SBCMD   <[byte sbRate+1]>       ; sampling rate high byte
        SBCMD   <[byte sbRate]>         ; sampling rate low byte

        test    [sbMode],sd8bit         ; 8-bit mode?
        jnz     @@8bit

        SBCMD   0B4h                    ; 16-bit output
        test    [sbMode],sdMono         ; mono?
        jnz     @@mono16
        SBCMD   30h                     ; 16-bit stereo signed PCM
        jmp     @@setlen
@@mono16:
        SBCMD   10h                     ; 16-bit mono signed PCM
        jmp     @@setlen

@@8bit:
        SBCMD   0C6h                    ; 8-bit output
        test    [sbMode],sdMono         ; mono?
        jnz     @@mono8
        SBCMD   20h                     ; 8-bit stereo unsigned PCM
        jmp     @@setlen
@@mono8:
        SBCMD   00h                     ; 8-bit mono unsigned PCM

@@setlen:
        SBCMD   <[byte sbBlockLength]>    ; transfer length low byte
        SBCMD   <[byte sbBlockLength+1]>  ; transfer length high byte

@@err:
        ret
ENDP




;/***************************************************************************\
;*
;* Function:    int sbClose(void)
;*
;* Description: Uninitializes Sound Blaster
;*
;* Returns:     MIDAS error code
;*
;\***************************************************************************/

PROC	sbClose 	FAR

	cmp	[SB.status],sdOK
        je      @@sok

        mov     ax,errSDFailure
        jmp     @@err

@@sok:
        ; Reset DSP _twice_ to stop playing and reset it: (In High-Speed mode
        ; the first DSP reset just stops the playing. Besides, this should
        ; not hurt anyone anyway.)
        mov     bx,2
        mov     dx,[SB.port]
        add     dx,06h

@@reset:
        mov     al,1                    ; reset SB DSP by first writing 1 to
	out	dx,al			; port 2x6h
        mov     cx,8
@@delay:
        in      al,dx                   ; wait for a while (3 usecs)
        loop    @@delay
	xor	al,al			; and write 0 to port 2x6h
	out	dx,al

        mov     cx,8
@@delay2:                               ; another delay
        in      al,dx
        loop    @@delay2

        dec     bx                      ; and reset again
        jnz     @@reset


        ; stop DMA playing:
	movzx	ax,[SB.DMA]
        call    dmaStop LANG, ax
        test    ax,ax
        jnz     @@err

	mov	bl,[SB.IRQ]
	cmp	bl,7			; is IRQ number > 7 ?
	ja	@@i8

	mov	al,[oldIRQmask]
        out     21h,al                  ; restore old IRQ mask, IRQ <= 7
	jmp	@@ivect

@@i8:   mov     al,[oldIRQmask]         ; restore old IRQ mask, IRQ > 7
	out	0A1h,al

@@ivect:
	push	ds
        mov     al,[sbInterrupt]
	mov	ah,25h			; restore old IRQ vector
	lds	dx,[oldIRQ]
	int	21h
	pop	ds

        ; uninitialize DSM:
        call    dsmClose LANG
        test    ax,ax
        jnz     @@err

        SBCMD   0D3h                    ; turn off the DAC speaker

        cmp     [sbVersion],0400h
        jae     @@stok                  ; using stereo mode on DSP < 4.00 ?
        test    [sbMode],sdStereo
        jz      @@stok

        ; stereo on DSP < 4.00 - restore the output filter status and set
        ; hardware to mono mode:

        mov     dx,[SB.port]
        add     dx,04h                  ; write 04h to port 2x4h
        mov     al,0Ch
        out     dx,al
        inc     dx
        mov     al,[sbOutputFilter]     ; write output filter value to 2x5h
        out     dx,al

        dec     dx
        mov     al,0Eh
        out     dx,al
        inc     dx                      ; turn off stereo mode
        in      al,dx
        and     al,not 02h
        out     dx,al

@@stok:
        mov     [SB.status],sdUnInitialized
        xor     ax,ax
        jmp     @@done

@@err:  ERROR   ID_sbClose

@@done:
	ret
ENDP



END
