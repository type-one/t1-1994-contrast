.386p
data_1e         equ     0
data_2e         equ     2
data_3e         equ     10h
data_4e         equ     1Ch
data_5e         equ     20h
data_6e         equ     22h
data_7e         equ     26h
data_8e         equ     30h
data_9e         equ     31h
data_10e        equ     32h
data_11e        equ     33h
data_12e        equ     40h
data_13e        equ     0FFh
data_14e        equ     800h
data_15e        equ     2110h
data_16e        equ     4000h
data_17e        equ     0F804h
data_18e        equ     0
data_19e        equ     0
data_20e        equ     2
data_21e        equ     28h
PSP_cmd_size    equ     80h
data_22e        equ     82h
data_484e       equ     12h
data_485e       equ     13h
data_486e       equ     1Ah
data_487e       equ     20A9h
data_488e       equ     2382h
data_489e       equ     2Ch
data_490e       equ     2Dh
data_491e       equ     2Eh
data_492e       equ     2Fh
data_493e       equ     10h
data_494e       equ     0B0h
data_495e       equ     132h
data_496e       equ     3C4h
data_497e       equ     406h
data_498e       equ     161Ch

                IDEAL
                Model Tiny
                CODESEG

PUBLIC FrameCounter, MaxFrame, RealFrame, HBLFlag
PUBLIC HBL_Seg, HBL_Ofs, int8Handler

FrameCounter    DW      0    ; compteur de frames
MaxFrame        DW      0
RealFrame       DW      0
;LineCounter     DW      0    ; compteur de scanlines
HBLflag         DW      0    ; HBL ON/OFF
;HBL_time        EQU     38   ; 2 scanlines (300 pour 10 scanlines)
;HBL_nb          EQU     50   ; nbre HBLs (43 pour 10 scanlines)
HBL_Ofs         DW      0    ; OFFSET HBL routine
HBL_Seg         DW      0    ; SEG HBL routine


; scanlines   HBL_time   HBL_nb
;-------------------------------
;    10         300        43
;     3          74       133
;     2          38       199

ripmsg 		db ' STMIK090 ripped by DZD/RTT '
; Hey! If U think it's lame , try 2 rip it urself!

data_94         dw      0
data_96         db      0
                db      63 dup (0)
data_97         dw      0
stako           dw	0
Int8Seg		dw	0
Int8Ofs		dw	0
FadeS		dw	64h		;depending of the VGA speed

public InitSoundCard, S3M_Play_Song, S3M_Stop_Song
public S3m_FadeMusicOn,S3M_FadeMusicOff

proc int8Handler far          ; VBL timer
                cli                     ; disable interrupts
                push ax
                push dx
                push ds

                inc WORD PTR cs:[FrameCounter] ; increment frame counter

           ;    increment MaxFrame Rate for test
                add WORD PTR cs:[MaxFrame],1
                jnc no_prob
                mov WORD PTR cs:[MaxFrame],0
                mov WORD PTR cs:[RealFrame],0

no_prob:
                mov dx,16000 ; PIT value (+- 70hz)
             ;   mov dx,16000 ;16940 ;16962; 1193180/70 ;17045 ;17000 ;4ce5h
   

                cmp cs:[HBLflag],1
                jne Timer_Restart

                ; new int8 adr : HBL timer rout !!!

                mov ax,WORD PTR cs:[HBL_Seg]
                mov ds,ax
                mov dx,WORD PTR cs:[HBL_Ofs]
                mov ax,2508h
                int 21h

               ; active HBL timer
                mov dx,1200-300         ; (temps jusque 1ere scanline)
               ; mov cs:[LineCounter],0

Timer_Restart:
                mov al,00110000b        ; reset counter 0
		out 43h,al
                mov ax,dx               ; Run timer 0
                out 40h,al              ; LSB

                mov  dx,3dah            ; Wait VBL
wait2:          in  al,dx               ; resynchronise with the
                jmp $+2                 ; electron beam
                test al,8
                jz  wait2

		mov al,ah
                out 40h,al              ; MSB

; ---------- pseudo-compteur "video" -----------

                mov al,0b6h ;10111010b        ; reset counter 2
                out 43h,al
                mov ax,16000            ; Run timer 2
                out 42h,al              ; LSB
                mov al,ah
                out 42h,al              ; MSB
                mov al,0bah
                out 43h,al


                mov al,20h
                out 20h,al              ; EOI

                pop ds
                pop dx
                pop ax

                sti                      ; enable interrupts

                pushf               ; context switch !!!
                push cs             ; donner la main au player plut“t
                push OFFSET play_it ; qu'au process interrompu !!!
		iret
endp int8Handler


;proc int8HBL far              ; HBL timer
;                cli                     ; disable interrupts
;                push ax
;                push dx
;                push bx
;
;                inc WORD PTR cs:[LineCounter] ; increment line counter
;                mov bx,HBL_time               ; temps jusque HBL suivante
;
;                cmp cs:[LineCounter],1+HBL_nb ; end of HBLS ???
;                jne nog_HBL
;
;                ; turn on VBL timer rout
;                push ds
;                mov ax,cs ; SEG int8Handler
;                mov ds,ax
;                mov dx,OFFSET int8Handler
;                mov ax,2508h
;                int 21h
;                pop ds ; temps restant jusque VBL
;                mov bx,14800-(HBL_time+38)*HBL_nb
;
;nog_HBL:
;                mov al,00110000b    ; reset timer
;                out 43h,al
;                mov ax,bx
;                out 40h,al          ; new counter (LSB)
;
;                mov  dx,3dah        ; Wait HBL
;wait3b:         in  al,dx
;                test al,1
;                jnz  wait3b
;wait3:          in  al,dx           ; resynchronise with the
;                test al,1           ; electron beam
;                jz  wait3
;
;                mov al,ah
;                out 40h,al           ; new counter (MSB)
;
; ============= Code utilisateur =============
;                mov dl,0c8h
;                xor ax,ax
;                out dx,ax
;                inc dl
;                mov al,32
;                out dx,al
;                mov ax,cs:[LineCounter]
;                and al,63
;                not al
;                rol al,4
;                xor al,23
;                out dx,al
; ============================================

;                mov al,20h
;                out 20h,al         ; EOI
;
;                pop bx
;                pop dx
;                pop ax
;
;                iret
;endp int8HBL

PROC play_it FAR                    ;"suite VBL"

                pusha

;                mov dx,3c8h
;                xor ax,ax
;                out dx,ax
;                inc dl
;                mov al,63
;                out dx,al
;                out dx,al

                call far ptr sub_16 ; appeler routine player !!

;                mov dx,3c8h
;                xor ax,ax
;                out dx,ax
;                inc dl
;                out dx,al
;                out dx,al

                popa

                iret                ; retour au process interrompu !!!

ENDP play_it


proc sub_3 near
                mov     [cs:data_97],sp
                push    ds
                mov     ax,seg_c
                mov     ds,ax
                mov     [ds:data_151],400h
                xor     al,al
                mov     [ds:data_161],al
                mov     [ds:data_170],bx
                mov     [ds:data_136],cx
                pop     ds
                call   far ptr sub_13
                push    cs
                mov     ax,seg_c
                mov     ds,ax
                mov     ax,[ds:data_137]
                cmp     ax,0FFFFh
                je      short loc_15            ; Jump if equal
                mov     [ds:data_168],0D555h
                mov     ax,[ds:data_136]
                cmp     ax,5
                jne     short loc_14            ; Jump if not equal
                shl     [ds:data_170],1              ; Shift w/zeros fill
loc_14:
                cmp     [ds:data_136],0
                je      short loc_15            ; Jump if equal
                clc                             ; Clear carry flag
                pop     ds

                mov     sp,[cs:data_97]
                retn
loc_15:
                stc                             ; Set carry flag
                pop     ds
                mov     sp,[cs:data_97]
                retn
endp sub_3



proc  sub_4 near
                mov     [cs:data_97],sp
                push    si
                xor     si,si                   ; Zero register
                push    si
                call   far ptr sub_14
                push    cs
                pop     ds
                mov     sp,[cs:data_97]
                retn
endp sub_4



proc sub_5 near
                mov     [cs:data_97],sp
                call   far ptr sub_11
                xor     si,si                   ; Zero register
                push    si
                call    far ptr sub_15
                push    cs
                mov     ax,seg_c
                mov     ds,ax
                assume  ds:seg_c
		mov 	al,1
                mov     [ds:data_160],al
                pop     ds
                mov     sp,[cs:data_97]
                retn
endp sub_5



proc sub_6 near
                mov     [cs:data_97],sp
                push    cs
                mov     ax,seg_c
                mov     ds,ax
                assume  ds:seg_c
		xor	al,al
                mov     [ds:data_160],al
                pop     ds
                call   far ptr sub_12
                push    cs
                pop     ds
                mov     sp,[cs:data_97]
                retn
endp sub_6

;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
; Public routines follow here:
;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ

proc InitSoundCard   far                       ; No params req.

                mov     bx,4E20h
                mov     cx,2
                call    sub_3
                jnc     short loc_24            ; Jump if carry=0
                mov     bx,4E20h
                mov     cx,5
                call    sub_3
                jnc     short loc_24            ; Jump if carry=0
                mov     bx,4E20h
                mov     cx,1
                call    sub_3
                jnc     short loc_24            ; Jump if carry=0
                mov     ax,-1                   ; No soundcard
                retf
loc_24:         xor     ax,ax
                retf
endp InitSoundCard

proc S3M_Play_Song far
		mov [cs:stako],sp
                ;comes with si loaded with the segment where is the song
                ;offset is always 0
                call    far ptr sub_4
                call    far ptr sub_5
		cli
		mov ax,3508h
		int 21h
                mov ax,bx
		mov [cs:Int8Ofs],ax
 		mov ax,es
		mov [cs:Int8Seg],ax
		push cs
		pop ds
                mov dx,offset Int8Handler
		mov ax,2508h
		int 21h
                mov sp,[cs:stako]
		sti
                retf
endp S3M_Play_Song

proc S3M_FadeMusicOn far                ; comes w/ si=Module segment
		push ds
		mov ax,si
		mov ds,ax
dp_wait1:	nop
		mov cx,[cs:FadeS]
	        mov     dx,3dah
@dp_wait1:
    		in      al, dx
    		and     al, 8
    		jz      @dp_wait1
		loop @dp_wait1
		mov al,[ds:30h]
                inc al
		mov [ds:30h],al
		cmp al,40h
		jb dp_wait1
		pop ds
		retf
endp S3M_FadeMusicOn

proc S3M_FadeMusicOff far                ; comes w/ si=Module segment
		push ds
		mov ax,si
		mov ds,ax
dp_wait2:	nop
		mov cx,[cs:FadeS]
	        mov     dx,3dah
@dp_wait2:
    		in      al, dx
    		and     al, 8
    		jz      @dp_wait2
		loop @dp_wait2
		mov al,[ds:30h]
                dec al
		mov [ds:30h],al
		or al,al
		ja dp_wait2
		pop ds
		retf
endp S3M_FadeMusicOff

proc S3M_Stop_Song far                       ; Uhh ,  no params req.
		mov [cs:stako],sp
		cli
		mov ax,[cs:Int8Seg]
		mov ds,ax
		mov dx,[cs:Int8Ofs]
		mov ax,2508h
		int 21h
                call    far ptr sub_6
		sti
                mov     sp,[cs:stako]
                retf
endp S3M_Stop_Song

;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
; Here follows the PSI junk, don't bother 2 understand it ...
;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออ


MASM
.model tiny



.386p
;------------------------------------------------------------  seg_c   ----

seg_c           segment para public use16
                assume cs:seg_c  , ds:seg_c

                db      ' Scream Tracke'        ; Data table (indexed access)
data_107        dw      2072h
data_108        dw      3356h
                db       2Eh, 30h
data_109        dw      4D20h
                db       75h, 73h
data_110        dw      6369h
                db       20h, 49h
data_111        db      6Eh
                db       74h, 65h
data_112        db      72h
data_113        dw      6166h
                db       63h, 65h, 20h, 4Bh
data_114        dw      7469h
data_115        dw      5620h, 2E30h
                db       39h,0E1h, 20h
                db      '(STMIK) ', 0Dh, 0Ah, ' '
copyright       db      'Copyright (C) 1991,92,93 Sami Ta'
                db      'mmilehto. '
                db       0Dh, 0Ah, 1Ah, 90h
data_117        dw      0
data_118        dw      0
data_119        dw      6Eh
                db      1938 dup (0)
data_121        dd      00000h                  ; Data table (indexed access)
data_122        dd      00000h                  ; Data table (indexed access)
data_123        dd      00000h                  ; Data table (indexed access)
data_124        dd      00000h                  ; Data table (indexed access)
                db      94 dup (0)
                db       87h,0DBh
data_125        dw      0
data_126        dw      0FFFFh
data_127        dw      0
data_128        dw      0
data_129        dw      0
data_130        db      0
data_131        db      1
data_132        db      0
data_133        db      0
data_134        dw      0
data_135        dw      0
data_136        dw      5
data_137        dw      0FFFFh
data_138        dw      0FFFFh
data_139        dw      0FFFFh
data_140        dw      388h
data_141        dw      0
data_143        dw      0
data_144        dw      0
                db       00h, 00h, 3Fh, 3Fh
                db      8 dup (0)
data_146        db      0
data_147        dw      0
data_148        dw      0
data_149        db      0
                db      0
data_150        dw      0
data_151        dw      1000h
                db      0
                db      0, 0, 0
data_153        dw      0
                db      0, 0, 0, 0, 1, 1
data_154        dw      400h
data_155        db      0, 0
data_156        dw      0
data_157        dw      0
data_158        dw      0
data_159        db      0
data_160        db      0
data_161        db      0
                db      0
data_162        dw      0
data_163        dw      0
data_164        dw      0
data_165        dw      0
                db      0, 0
data_166        dw      0
data_167        dw      0
data_168        dw      0
data_169        dw      0
data_170        dw      4E20h
data_171        dw      5277h
data_172        dw      4E20h
data_173        dw      32h
data_174        dw      64h
data_175        dw      1
data_176        dw      64h
                db      0, 0
data_178        dw      0
data_179        dw      0
                db      1, 0, 0, 0, 0, 0
data_180        dw      0FFFFh
data_181        dw      0FFFFh
                db      0
                db      0
data_183        dw      0
data_184        db      0
                db      0
data_185        dw      0
data_186        dw      0
data_187        dw      0
data_188        dw      0
data_189        db      7Dh
                db      0
data_190        dw      0C0h
data_191        dw      0C0h
data_192        db      7
data_193        db      0
data_194        dw      0
data_195        db      0
data_196        db      0
                db      0Ah
loc_48:
                db      0, 0
data_198        dw      0
                db      0, 0
data_199        db      0
                db      0
data_200        dw      0, 0
                db      0, 0, 0, 0
data_202        dw      0
data_203        dw      0
data_204        dw      0
data_205        dw      0
data_206        dw      0
data_207        dw      0
data_208        db      0
data_209        db      0
data_210        db      0
data_211        db      0
data_212        dw      0
                db      0, 0
data_213        dw      0
                db      0, 0
data_214        dw      0
                db      0, 0
data_215        dw      0
                db      0, 0
data_216        dw      0
                db      0, 0
data_217        dw      0
                db      0, 0
data_218        dw      0
                db      0, 0
data_219        dw      7FFFh
data_220        dw      40h
data_221        db      0                       ; Data table (indexed access)
                db      0FFh,0FEh,0FCh,0F8h,0F0h, 00h
                db       00h, 00h, 01h, 02h, 04h, 08h
                db       10h
                db      0, 0
data_223        db      0                       ; Data table (indexed access)
                db       00h, 00h, 00h, 00h, 00h, 0Ah
                db       08h, 00h, 00h, 00h, 00h, 00h
                db       00h, 18h
                db      20h
data_224        db      0                       ; Data table (indexed access)
                db       01h, 02h, 03h, 04h, 05h, 06h
                db       07h, 00h, 05h, 0Bh, 11h
                db      1Bh, ' */8<EIQY]dkrx~'
                db       83h, 89h, 8Eh, 93h, 97h, 9Ch
                db      0A1h,0A7h,0ABh,0AFh,0B4h,0B9h
                db      0BCh,0C0h,0C4h,0C8h,0CBh,0CEh
                db      0D3h,0D6h,0D9h,0DCh,0DFh,0E2h
                db      0E4h,0E6h,0E9h,0EBh,0EDh,0EFh
                db      0F1h,0F3h,0F5h,0F6h,0F8h,0F9h
                db      0FAh,0FBh,0FCh,0FCh,0FDh,0FDh
                db      0FEh,0FFh
data_225        db      0
                db       04h, 08h, 0Ch, 10h, 14h, 18h
                db       1Ch
                db      ' $'
                db      '(,048<@DHLPUY]aeimquy}'
                db       81h, 85h, 89h, 8Dh, 91h, 95h
                db       99h, 9Dh,0A1h,0A5h,0AAh,0AEh
                db      0B2h,0B6h,0BAh,0BEh,0C2h,0C6h
                db      0CAh,0CEh,0D2h,0D6h,0DAh,0DEh
                db      0E2h,0E6h,0EAh,0EEh,0F2h,0F6h
                db      0FAh,0FFh
data_226        dw      20ABh                   ; Data table (indexed access)
                db      0DDh, 20h, 0Fh, 21h, 51h, 21h
                db       85h, 21h,0CBh
loc_49:
                and     [bp+di],dx
                and     dh,[di]
                and     dl,bh
                push    ds
                add     ax,311Fh
                pop     ds
                outsb                           ; Out [si] to port dx
                pop     ds
                stosw                           ; Store ax to es:[di]
                pop     ds
;*              jmp     loc_136                 ;*
                db      0E9h, 1Fh, 28h          ;  Fixup - byte match
                db       20h, 58h, 20h
data_227        dw      6B00h                   ; Data table (indexed access)
                db       00h, 65h, 40h, 5Fh, 00h, 5Ah
                db      0C0h, 54h, 00h, 50h, 80h, 4Bh
                db       40h, 47h, 40h, 43h, 80h, 3Fh
                db       00h
                db      3Ch
data_228        dw      38B0h
data_229        db      0                       ; Data table (indexed access)
                db       01h, 02h, 08h, 09h, 0Ah, 10h
                db       11h, 12h, 10h, 14h, 12h, 15h
                db       11h
data_230        db      3                       ; Data table (indexed access)
                db      4, 5, 6, 7, 0
data_231        dw      0                       ; Data table (indexed access)
                db       18h, 00h, 31h, 00h, 4Ah, 00h
                db       61h, 00h, 78h, 00h, 8Dh, 00h
                db      0A1h, 00h,0B4h, 00h,0C5h, 00h
                db      0D4h, 00h,0E0h, 00h,0EBh, 00h
                db      0F4h, 00h,0FAh, 00h,0FDh, 00h
                db      0FFh, 00h,0FDh, 00h,0FAh, 00h
                db      0F4h, 00h,0EBh, 00h,0E0h, 00h
                db      0D4h, 00h,0C5h, 00h,0B4h, 00h
                db      0A1h, 00h, 8Dh, 00h, 78h, 00h
                db       61h, 00h, 4Ah, 00h, 31h, 00h
                db       18h, 00h, 00h, 00h,0E8h,0FFh
                db      0CFh,0FFh,0B6h,0FFh, 9Fh,0FFh
                db       88h,0FFh, 73h,0FFh, 5Fh,0FFh
                db       4Ch,0FFh, 3Bh,0FFh, 2Ch,0FFh
                db       20h,0FFh, 15h,0FFh, 0Ch,0FFh
                db       06h,0FFh, 03h,0FFh, 01h,0FFh
                db       03h,0FFh, 06h,0FFh, 0Ch,0FFh
                db       15h,0FFh, 20h,0FFh, 2Ch,0FFh
                db       3Bh,0FFh, 4Ch,0FFh, 5Fh,0FFh
                db       73h,0FFh, 88h,0FFh, 9Fh,0FFh
                db      0B6h,0FFh,0CFh,0FFh,0E8h,0FFh
data_232        dw      0FFh                    ; Data table (indexed access)
                db      0FFh, 00h,0FFh, 00h,0FFh, 00h
                db      0FFh, 00h,0FFh, 00h,0FFh, 00h
                db      0FFh, 00h,0FFh, 00h,0FFh, 00h
                db      0FFh, 00h,0FFh, 00h,0FFh, 00h
                db      0FFh, 00h,0FFh, 00h,0FFh, 00h
                db      0FFh, 00h,0FFh, 00h,0FFh, 00h
                db      0FFh, 00h,0FFh, 00h,0FFh, 00h
                db      0FFh, 00h,0FFh, 00h,0FFh, 00h
                db      0FFh, 00h,0FFh, 00h,0FFh, 00h
                db      0FFh, 00h,0FFh, 00h,0FFh, 00h
                db      0FFh
                db      65 dup (0)
data_234        dw      0                       ; Data table (indexed access)
                db       08h,0FFh, 10h,0FFh, 18h,0FFh
                db       20h,0FFh, 28h,0FFh, 30h,0FFh
                db       38h,0FFh, 40h,0FFh, 48h,0FFh
                db       50h,0FFh, 58h,0FFh, 60h,0FFh
                db       68h,0FFh, 70h,0FFh, 78h,0FFh
                db       80h,0FFh, 88h,0FFh, 90h,0FFh
                db       98h,0FFh,0A0h,0FFh,0A8h,0FFh
                db      0B0h,0FFh,0B8h,0FFh,0C0h,0FFh
                db      0C8h,0FFh,0D0h,0FFh,0D8h,0FFh
                db      0E0h,0FFh,0E8h,0FFh,0F0h,0FFh
                db      0F8h,0FFh, 00h, 00h, 08h, 00h
                db       10h, 00h, 18h, 00h, 20h, 00h
                db       28h, 00h, 30h, 00h, 38h, 00h
                db       40h, 00h, 48h, 00h, 50h, 00h
                db       58h, 00h, 60h, 00h, 68h, 00h
                db       70h, 00h, 78h, 00h, 80h, 00h
                db       88h, 00h, 90h, 00h, 98h, 00h
                db      0A0h, 00h,0A8h, 00h,0B0h, 00h
                db      0B8h, 00h,0C0h, 00h,0C8h, 00h
                db      0D0h, 00h,0D8h, 00h,0E0h, 00h
                db      0E8h, 00h,0F0h, 00h,0F8h
                db      0
data_236        dw      0
data_237        dw      0
data_238        dw      0
data_239        dw      0
data_240        dw      0
data_241        dw      0
data_242        dw      0
data_243        dw      0
data_244        dw      0C8h
                db      0, 0
data_245        db      0, 0
data_246        dw      0
data_247        dw      0
data_248        dw      0
data_249        dw      0
                db      24 dup (0)
                db      1, 1, 1, 1, 1, 1
                db      13 dup (2)
                db      11 dup (3)
                db      13 dup (4)
                db      11 dup (5)
                db      13 dup (6)
                db      11 dup (7)
                db      13 dup (8)
                db      7 dup (9)
                db       0Ah, 0Ah, 0Ah, 0Ah, 0Bh, 0Bh
                db       0Ch, 0Ch, 0Dh, 0Eh, 0Eh, 0Fh
                db       10h, 11h, 11h, 12h, 13h, 14h
                db       15h, 16h, 17h, 18h, 1Ah, 1Bh
                db       1Ch, 1Dh, 1Eh, 1Fh
                db      '!"#$'
                db      '&', 27h, '()+,-.012345679::;<=>?'
                db      '@@ABBCCCCCCDDDDDDDDDDDDDEEEEEEEE'
                db      'EEEFFFFFFFFFFFFFGGGGGGGGGGGHHHHH'
                db      'HHHHHHHHIIIIIIIIIIIJJJJJJJJJJJJJ'
                db      'KKKKKK'
data_259        db      0                       ; Data table (indexed access)
data_260        db      0                       ; Data table (indexed access)
data_261        db      0                       ; Data table (indexed access)
                db      55 dup (0)
data_262        db      0
                db      41 dup (0)
data_263        db      0
data_264        db      1
                db      0
                db      8 dup (0)
data_266        db      0
                db      38 dup (0)
                db       87h,0DBh
data_267        dw      200 dup (0)
data_268        db      0
                db      255 dup (0)
data_269        db      0
                db      111 dup (0)
data_270        db      0
                db      767 dup (0)
data_271        db      0
                db      959 dup (0)
data_272        db      0
                db      1743 dup (0)
data_273        dw      0
                db      366 dup (0)
data_274        dw      0D90h                   ; Data table (indexed access)
                db      0F0h, 0Dh, 50h, 0Eh,0B0h, 0Eh
                db       10h, 0Fh, 70h, 0Fh,0D0h, 0Fh
                db       30h, 10h, 90h, 10h,0F0h, 10h
                db       50h, 11h,0B0h, 11h, 10h, 12h
                db       70h, 12h,0D0h, 12h, 30h, 13h
data_275        dw      1390h
                db      0F0h, 13h, 50h, 14h,0B0h, 14h
                db       10h, 15h, 70h, 15h,0D0h, 15h
                db       30h, 16h, 90h, 16h
data_276        dw      16F0h
                db       50h, 17h,0B0h, 17h, 10h, 18h
                db       70h, 18h,0D0h, 18h, 30h, 19h
data_277        dw      1990h
                db      0F0h, 19h, 50h, 1Ah,0B0h, 1Ah
                db       10h, 1Bh, 70h, 1Bh,0D0h, 1Bh
                db       30h, 1Ch, 90h, 1Ch
data_278        dw      1CF0h
                db       50h, 1Dh,0B0h, 1Dh, 10h, 1Eh
                db       70h, 1Eh,0D0h, 1Eh, 30h, 1Fh
data_279        dw      0
data_280        dw      6
data_282        dw      0
data_283        dw      0
data_284        db      0
data_285        db      0
data_286        dw      0
data_287        db      0                       ; Data table (indexed access)
                db      255 dup (0)
data_288        dd      00000h
                db      0, 0
data_289        dw      0
data_290        dw      0
                db      0, 0
data_291        dw      0
                db      0, 0
data_292        dw      0
data_293        db      0
data_294        db      0
data_295        db      0
                db      0
data_296        dw      0
data_297        dw      6                       ; Data table (indexed access)
                db      7, 0, 8, 0, 8, 0
                db      7, 0
data_298        db      0
data_299        db      10h                     ; Data table (indexed access)
                db      8, 4, 2, 1
data_300        dw      1000h
data_301        dw      1000h
data_302        dw      0EFFFh
data_303        dw      0FFh
data_304        db      0
data_305        db      0FFh
data_306        db      0
data_307        db      0FFh
data_308        db      0, 0, 0, 0
data_309        dw      0
data_310        dw      0
                db      0, 0
data_311        dw      0
data_312        dw      0
data_313        dw      0
data_314        dw      0
                db      1, 0
                db      'CODESTART3'
                db      0C0h,0C3h

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_11          proc    far
                cmp     cs:data_136,0
                jne     short loc_51            ; Jump if not equal
                retf                            ; Return far
loc_51:
                cmp     cs:data_159,1
                jne     short loc_52            ; Jump if not equal
                retf                            ; Return far
loc_52:
                push    bp
                mov     bp,sp
                push    si
                push    di
                push    ds
                mov     ax,cs
                mov     ds,ax
                cmp     cs:data_136,2
                jne     short loc_53            ; Jump if not equal
                mov     cs:data_170,4C00h
                mov     cs:data_171,4C00h
                mov     cs:data_172,4C00h
loc_53:
                mov     cs:data_163,0
                mov     cs:data_164,0
                mov     cs:data_157,4
                mov     cs:data_159,1
                call    sub_24
                call    sub_133
                call    sub_106
                call    sub_124
                mov     bx,data_136
                cmp     bx,0
                je      short loc_54            ; Jump if equal
                call    sub_34
                call    sub_129
loc_54:
                xor     ax,ax                   ; Zero register
                pop     ds
                pop     di
                pop     si
                pop     bp
                retf                            ; Return far
sub_11          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_12          proc    far
                cmp     cs:data_136,0
                jne     short loc_55            ; Jump if not equal
                retf                            ; Return far
loc_55:
                cmp     cs:data_159,0
                jne     short loc_56            ; Jump if not equal
                retf                            ; Return far
loc_56:
                push    bp
                mov     bp,sp
                push    si
                push    di
                push    ds
                mov     ax,cs
                mov     ds,ax
                call    sub_133
                mov     cs:data_209,0
                mov     cs:data_208,0
                mov     cs:data_149,0
                mov     cs:data_159,0
                mov     bx,data_136
                cmp     bx,0
                je      short loc_57            ; Jump if equal
                call    sub_35
loc_57:
                xor     ax,ax                   ; Zero register
                pop     ds
                pop     di
                pop     si
                pop     bp
                retf                            ; Return far
sub_12          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_13          proc    far
                cmp     cs:data_136,0
                jne     short loc_58            ; Jump if not equal
                retf                            ; Return far
loc_58:
                push    bp
                push    si
                push    di
                push    ds
                cli                             ; Disable interrupts
                mov     ax,cs
                mov     ds,ax
                mov     cs:data_158,0
                call    sub_133
                call    sub_28
                call    sub_106
                mov     ax,4000h
                mov     cs:data_238,ax
                mov     ax,cs:data_151
                mov     cs:data_300,ax
                add     ax,cs:data_237
                mov     cs:data_301,ax
                sub     ax,cs:data_237
                mov     bx,0FFFFh
                sub     bx,ax
                mov     cs:data_302,bx
                cli                             ; Disable interrupts
                mov     ax,cs:data_237
                mov     cs:data_240,ax
                mov     cs:data_241,ax
                mov     bx,cs:data_300
                shr     bx,1                    ; Shift w/zeros fill
                add     ax,bx
                mov     cs:data_239,ax
                mov     bx,data_136
                cmp     bx,0
                je      short loc_59            ; Jump if equal
                call    sub_33
                add     cs:data_158,ax
loc_59:
                sti                             ; Enable interrupts
                mov     ax,cs:data_158
                pop     ds
                pop     di
                pop     si
                pop     bp
                retf
sub_13          endp

                                                ;* No entry point to code
                push    bp
                mov     bp,sp
                push    si
                push    di
                push    ds
                mov     ax,cs
                mov     ds,ax
                push    es
                xor     ax,ax                   ; Zero register
                mov     es,ax
                mov     ax,es:data_1e
                mov     dx,es:data_2e
                mov     cs:data_202,ax
                mov     cs:data_203,dx
                mov     ax,51BFh
                cli                             ; Disable interrupts
                mov     es:data_1e,ax
                mov     es:data_2e,cs
                sti                             ; Enable interrupts
                pop     es
                pop     ds
                pop     di
                pop     si
                pop     bp
                retf
                                                ;* No entry point to code
                push    bp
                mov     bp,sp
                push    si
                push    di
                push    ds
                mov     ax,cs
                mov     ds,ax
                push    es
                xor     ax,ax                   ; Zero register
                mov     es,ax
                mov     ax,cs:data_202
                mov     dx,cs:data_203
                cli                             ; Disable interrupts
                mov     es:data_1e,ax
                mov     es:data_2e,dx
                sti                             ; Enable interrupts
                pop     es
                pop     ds
                pop     di
                pop     si
                pop     bp
                retf                            ; Return far

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_14          proc    far
                cmp     cs:data_136,0
                jne     short loc_60            ; Jump if not equal
                retf                            ; Return far
loc_60:
                push    bp
                mov     bp,sp
                push    si
                push    di
                push    ds
                mov     ax,cs
                mov     ds,ax
                mov     ax,[bp+8]
                mov     cs:data_134,ax
                mov     es,ax
                mov     ax,0FFFFh
                cmp     byte ptr es:data_489e,53h ; 'S'
                jne     short loc_61            ; Jump if not equal
                cmp     byte ptr es:data_490e,43h ; 'C'
                jne     short loc_61            ; Jump if not equal
                cmp     byte ptr es:data_491e,52h ; 'R'
                jne     short loc_61            ; Jump if not equal
                cmp     byte ptr es:data_492e,4Dh ; 'M'
                jne     short loc_61            ; Jump if not equal
                call    sub_134
                push 	cs
		call    sub_20
		push	cs
                call    sub_19
                mov     ax,0
loc_61:
                pop     ds
                pop     di
                pop     si
                pop     bp
                retf
sub_14          endp

                                                ;* No entry point to code
                cmp     cs:data_136,0
                jne     short loc_62            ; Jump if not equal
                retf                            ; Return far
loc_62:
                push    bp
                mov     bp,sp
                push    si
                push    di
                push    ds
                mov     ax,cs
                mov     ds,ax
                mov     data_208,1
                mov     bx,[bp+6]
                and     bx,1Fh
                mov     es,cs:data_134
                add     bx,cs:data_207
                mov     bl,es:[bx]
                xor     bh,bh                   ; Zero register
                test    bl,80h
                jnz     short loc_63            ; Jump if not zero
                shl     bx,1                    ; Shift w/zeros fill
                mov     si,cs:data_274[bx]
                mov     ax,[bp+8]
                mov     [si+32h],al
                mov     ax,[bp+0Ah]
                mov     [si+33h],al
                mov     ax,[bp+0Ch]
                mov     [si+34h],al
                mov     ax,[bp+0Eh]
                mov     [si+35h],al
                mov     ax,[bp+10h]
                mov     [si+36h],al
                mov     al,byte ptr data_280
                mov     [si+3Eh],al
                mov     byte ptr [si+3Ah],64h   ; 'd'
                call    sub_99
loc_63:
                pop     ds
                pop     di
                pop     si
                pop     bp
                retf
                                                ;* No entry point to code
                cmp     cs:data_136,0
                jne     short loc_64            ; Jump if not equal
                retf                            ; Return far
loc_64:
                push    bp
                mov     bp,sp
                push    si
                push    di
                push    ds
                mov     ax,cs
                mov     ds,ax
                cli                             ; Disable interrupts
                mov     ax,[bp+8]
                mov     cs:data_211,al
                mov     ax,[bp+6]
                mov     cs:data_213,ax
                mov     cs:data_210,1
                mov     ax,cs:data_280
                mov     cs:data_279,ax
                mov     cs:data_208,1
                mov     cs:data_209,2
                sti                             ; Enable interrupts
                pop     ds
                pop     di
                pop     si
                pop     bp
                retf                            ; Return far

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_15          proc    far
                cmp     cs:data_136,0
                jne     short loc_65            ; Jump if not equal
                retf                            ; Return far
loc_65:
                push    bp
                mov     bp,sp
                push    si
                push    di
                push    ds
                mov     ax,cs
                mov     ds,ax
                cli                             ; Disable interrupts
                xor     ax,ax                   ; Zero register
                mov     cs:data_214,ax
                mov     ax,[bp+6]
                mov     bx,ax
                and     ax,1FFh
                mov     cs:data_213,ax
                test    bx,8000h
                jnz     short loc_66            ; Jump if not zero
                cmp     ax,100h
                jb      short loc_67            ; Jump if below
loc_66:
                mov     cs:data_214,ax
loc_67:
                cli                             ; Disable interrupts
                call    sub_124
                call    sub_134
                mov     cs:data_209,2
                call    sub_92
                mov     cs:data_208,1
                sti                             ; Enable interrupts
                pop     ds
                pop     di
                pop     si
                pop     bp
                retf
sub_15          endp

                                                ;* No entry point to code
                cmp     cs:data_136,0
                jne     short loc_68            ; Jump if not equal
                retf                            ; Return far
loc_68:
                push    bp
                mov     bp,sp
                push    si
                push    di
                push    ds
                mov     ax,cs
                mov     ds,ax
                mov     ax,[bp+6]
                mov     cs:data_215,ax
                pop     ds
                pop     di
                pop     si
                pop     bp
                retf
                                                ;* No entry point to code
                cmp     cs:data_136,0
                jne     short loc_69            ; Jump if not equal
                retf                            ; Return far
loc_69:
                push    bp
                mov     bp,sp
                push    si
                push    di
                push    ds
                mov     ax,cs
                mov     ds,ax
                cli                             ; Disable interrupts
                mov     cs:data_209,0
                sti                             ; Enable interrupts
                pop     ds
                pop     di
                pop     si
                pop     bp
                retf
                                                ;* No entry point to code
                cmp     cs:data_136,0
                jne     short loc_70            ; Jump if not equal
                retf                            ; Return far
loc_70:
                push    bp
                mov     bp,sp
                push    si
                push    di
                push    ds
                mov     ax,cs
                mov     ds,ax
                call    sub_133
                call    sub_24
                mov     cs:data_208,0
                pop     ds
                pop     di
                pop     si
                pop     bp
                retf
                                                ;* No entry point to code
                mov     ax,cs:data_187
                mov     bx,cs:data_186
                mov     cx,cs:data_185
                mov     dx,cs:data_188
                retf                            ; Return far

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_16          proc    far
                cmp     cs:data_160,0
                je      short loc_ret_71        ; Jump if equal
                pushf                           ; Push flags
                push    ax
                call    sub_121
                pop     ax
                popf                            ; Pop flags

loc_ret_71:
                retf
sub_16          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_17          proc    near
                cmp     bx,data_13e
                je      short loc_72            ; Jump if equal
                shl     bx,1                    ; Shift w/zeros fill
                mov     ds,cs:data_134
                add     bx,cs:data_205
                mov     ax,[bx]
                cmp     ax,0
                jne     short loc_74            ; Jump if not equal
loc_72:
                xor     ax,ax                   ; Zero register
                mov     ds,ax
                xor     si,si                   ; Zero register

loc_ret_73:
                retn
loc_74:
                mov     ds,ax
                mov     si,data_2e
                jcxz    loc_ret_73              ; Jump if cx=0

locloop_75:
                lodsb                           ; String [si] to al
                or      al,al                   ; Zero ?
                jnz     short loc_76            ; Jump if not zero
                loop    locloop_75              ; Loop if cx > 0

                retn
loc_76:
                test    al,20h                  ; ' '
                jz      short loc_77            ; Jump if zero
                add     si,2
loc_77:
                test    al,40h                  ; '@'
                jz      short loc_78            ; Jump if zero
                inc     si
loc_78:
                test    al,80h
                jz      short loc_79            ; Jump if zero
                add     si,2
loc_79:
                jmp     short locloop_75
sub_17          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_18          proc    near
                mov     ax,0FFh
                mov     cx,20h

locloop_80:
                mov     es:[di],ax
                mov     es:[di+2],ax
                mov     es:[di+4],ah
                add     di,5
                loop    locloop_80              ; Loop if cx > 0

                cmp     si,0
                je      short loc_ret_82        ; Jump if equal
                sub     di,0A0h
loc_81:
                lodsb                           ; String [si] to al
                or      al,al                   ; Zero ?
                jnz     short loc_83            ; Jump if not zero

loc_ret_82:
                retn
loc_83:
                push    di
                mov     bl,al
                push    ds
                mov     ds,cs:data_134
                and     bx,1Fh
                add     bx,cs:data_207
                mov     dl,[bx]
                pop     ds
                and     dx,7Fh
                add     di,dx
                shl     dx,1                    ; Shift w/zeros fill
                shl     dx,1                    ; Shift w/zeros fill
                add     di,dx
                mov     dl,al
                test    dl,20h                  ; ' '
                jz      short loc_84            ; Jump if zero
                lodsw                           ; String [si] to ax
                mov     es:[di],ax
loc_84:
                test    dl,40h                  ; '@'
                jz      short loc_85            ; Jump if zero
                lodsb                           ; String [si] to al
                mov     es:[di+2],al
loc_85:
                test    dl,80h
                jz      short loc_86            ; Jump if zero
                lodsw                           ; String [si] to ax
                mov     es:[di+3],ax
loc_86:
                pop     di
                jmp     short loc_81
sub_18          endp

                                                ;* No entry point to code
                push    bp
                mov     bp,sp
                push    ds
                push    si
                push    di
                mov     cx,[bp+8]
                mov     bx,[bp+6]
                call    sub_17
                mov     es,[bp+0Ch]
                mov     di,[bp+0Ah]
                call    sub_18
                pop     di
                pop     si
                pop     ds
                pop     bp
                retf
                                                ;* No entry point to code
                mov     cs:data_218,0FFFFh
                retf
                                                ;* No entry point to code
                push    bp
                mov     bp,sp
                push    si
                push    di
                push    ds
                mov     ax,cs
                mov     ds,ax
                mov     fs,word ptr cs:data_245
                mov     bx,[bp+6]
                mov     ax,bx
                shl     bx,1                    ; Shift w/zeros fill
                mov     bx,cs:data_274[bx]
                mov     dx,cs:[bx+5Ah]
                mov     si,cs:[bx+44h]
                test    ax,80h
                jnz     short loc_92            ; Jump if not zero
                cmp     si,cs:[bx+48h]
                jae     short loc_92            ; Jump if above or =
                push    dx
                mov     al,cs:[bx+41h]
                xor     ah,ah                   ; Zero register
                mov     cx,0C0h
                mul     cx                      ; dx:ax = reg * ax
                mov     bh,ah
                pop     dx
                cmp     dx,0F000h
                jb      short loc_87            ; Jump if below
                push    bx
                push    bp
                call    sub_125
                pop     bp
                pop     bx
                mov     ds,dx
                jmp     short loc_88
loc_87:
                mov     ds,dx
loc_88:
                mov     es,[bp+0Ah]
                mov     di,[bp+8]
                jmp     short loc_90
                                                ;* No entry point to code
                cld                             ; Clear direction
                mov     cx,10h
                rep     movsw                   ; Rep when cx >0 Mov [si] to es:[di]
loc_89:
                pop     ds
                pop     di
                pop     si
                pop     bp
                retf                            ; Return far
loc_90:
                mov     cx,20h
                mov     al,80h
                mov     bl,80h
                sub     al,fs:[bx]

locloop_91:
                mov     bl,[si]
                mov     bl,fs:[bx]
                add     bl,al
                mov     es:[di],bl
                inc     si
                inc     di
                loop    locloop_91              ; Loop if cx > 0

                jmp     short loc_89
loc_92:
                mov     es,[bp+0Ah]
                mov     di,[bp+8]
                cld                             ; Clear direction
                mov     cx,10h
                mov     ax,8080h
                rep     stosw                   ; Rep when cx >0 Store ax to es:[di]
                jmp     short loc_89
                                                ;* No entry point to code
                push    bp
                mov     bp,sp
                push    si
                push    di
                push    ds
                mov     ax,cs
                mov     ds,ax
                call    sub_129
                pop     ds
                pop     di
                pop     si
                pop     bp
                retf                            ; Return far

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_19          proc    near
                push    bp
                mov     bp,sp
                push    si
                push    di
                push    ds
                mov     ax,cs
                mov     ds,ax
                cli                             ; Disable interrupts
                mov     es,cs:data_134
                mov     cx,es:data_6e
                xor     bl,bl                   ; Zero register

locloop_93:
                push    cx
                push    bx
                xor     bh,bh                   ; Zero register
                shl     bx,1                    ; Shift w/zeros fill
                add     bx,cs:data_206
                mov     es,cs:data_134
                mov     ax,es:[bx]
                add     ax,cs:data_134
                mov     es,ax
                cmp     byte ptr es:data_19e,1
                jne     short loc_94            ; Jump if not equal
                mov     word ptr es:data_21e,0
                call    sub_40
loc_94:
                pop     bx
                pop     cx
                inc     bx
                loop    locloop_93              ; Loop if cx > 0

                sti                             ; Enable interrupts
                pop     ds
                pop     di
                pop     si
                pop     bp
                retf                            ; Return far
sub_19          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_20          proc    near
                push    bp
                mov     bp,sp
                push    si
                push    di
                push    ds
                mov     ax,cs
                mov     ds,ax
                call    sub_36
                pop     ds
                pop     di
                pop     si
                pop     bp
                retf                            ; Return far
sub_20          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_21          proc    near
                cmp     cs:data_199,0
                je      short loc_95            ; Jump if equal
                retn
loc_95:
                push    es
                xor     ax,ax                   ; Zero register
                mov     es,ax
                cli                             ; Disable interrupts
                mov     ax,es:data_5e
                mov     dx,es:data_6e
                mov     cs:data_200,ax
                mov     word ptr cs:data_200+2,dx
                mov     ax,2753h
                mov     es:data_5e,ax
                mov     es:data_6e,cs
                mov     cs:data_199,1
                mov     dx,3DAh
loc_96:
                in      al,dx                   ; port 3DAh, CGA/EGA vid status
                test    al,8
                jz      loc_96                  ; Jump if zero
loc_97:
                in      al,dx                   ; port 3DAh, CGA/EGA vid status
                test    al,8
                jnz     loc_97                  ; Jump if not zero
                mov     cx,8

locloop_98:
                in      al,dx                   ; port 3DAh, CGA/EGA vid status
                test    al,1
                jz      locloop_98              ; Jump if zero
loc_99:
                in      al,dx                   ; port 3DAh, CGA/EGA vid status
                test    al,1
                jnz     loc_99                  ; Jump if not zero
                loop    locloop_98              ; Loop if cx > 0

                mov     al,36h                  ; '6'
                out     43h,al                  ; port 43h, 8253 timer control
                mov     ax,426Dh
                mov     cs:data_174,0
                out     40h,al                  ; port 40h, 8253 timer 0 clock
                mov     al,ah
                out     40h,al                  ; port 40h, 8253 timer 0 clock
                call    sub_31
                sti                             ; Enable interrupts
                pop     es
                retn
sub_21          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_22          proc    near
                cmp     cs:data_199,0
                jne     short loc_100           ; Jump if not equal
                retn
loc_100:
                push    es
                xor     ax,ax                   ; Zero register
                mov     es,ax
                cli                             ; Disable interrupts
                mov     ax,cs:data_200
                mov     dx,word ptr cs:data_200+2
                mov     es:data_5e,ax
                mov     es:data_6e,dx
                mov     cs:data_199,0
                mov     al,36h                  ; '6'
                out     43h,al                  ; port 43h, 8253 timer control
                xor     ax,ax                   ; Zero register
                out     40h,al                  ; port 40h, 8253 timer 0 clock
                mov     al,ah
                out     40h,al                  ; port 40h, 8253 timer 0 clock
                sti                             ; Enable interrupts
                pop     es
                retn
sub_22          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_23          proc    near
                sti                             ; Enable interrupts
                push    bx
                push    cx
                push    dx
                push    si
                push    di
                push    bp
                push    ds
                push    es
                cld                             ; Clear direction
                mov     ax,cs:data_174
                add     cs:data_179,ax
                jnc     short loc_101           ; Jump if carry=0
                pushf                           ; Push flags
                call    dword ptr cs:data_200
loc_101:
                pop     es
                pop     ds
                pop     bp
                pop     di
                pop     si
                pop     dx
                pop     cx
                pop     bx
                retn
sub_23          endp

                                                ;* No entry point to code
                push    ax
                mov     al,20h                  ; ' '
                out     20h,al                  ; port 20h, 8259-1 int command
                                                ;  al = 20h, end of interrupt
                call    sub_41
                cmp     cs:data_160,0
                je      short loc_102           ; Jump if equal
                call    sub_23
                jmp     short loc_103
loc_102:
                call    sub_121
loc_103:
                pop     ax
                iret                            ; Interrupt return

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_24          proc    near
                test    cs:data_135,1
                jnz     short loc_ret_104       ; Jump if not zero
                cli                             ; Disable interrupts
                cld                             ; Clear direction
                mov     cx,cs:data_300
                shr     cx,1                    ; Shift w/zeros fill
                xor     di,di                   ; Zero register
                mov     es,cs:data_246
                mov     ax,8080h
                rep     stosw                   ; Rep when cx >0 Store ax to es:[di]
                mov     cx,800h
                mov     di,data_16e
                mov     es,word ptr cs:data_245
                xor     ax,ax                   ; Zero register
                rep     stosw                   ; Rep when cx >0 Store ax to es:[di]
                sti                             ; Enable interrupts

loc_ret_104:
                retn
sub_24          endp

data_315        db      0

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_25          proc    near
                push    ax
                push    es
                mov     ah,49h                  ; 'I'
                mov     es,ax
                int     21h                     ; DOS Services  ah=function 49h
                                                ;  release memory block, es=seg
                pop     es
                pop     ax
                retn
sub_25          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_26          proc    near
                push    bx
                mov     ah,48h                  ; 'H'
                mov     bx,cx
                add     bx,0Fh
                shr     bx,1                    ; Shift w/zeros fill
                shr     bx,1                    ; Shift w/zeros fill
                shr     bx,1                    ; Shift w/zeros fill
                shr     bx,1                    ; Shift w/zeros fill
                int     21h                     ; DOS Services  ah=function 48h
                                                ;  allocate memory, bx=bytes/16
                pop     bx
                retn
sub_26          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_27          proc    near
                push    ax
                mov     dx,0EFFh
                and     ax,0FFFh
                cmp     ax,dx
                jb      short loc_105           ; Jump if below
                pop     ax
                stc                             ; Set carry flag
                retn
loc_105:
                pop     ax
                clc                             ; Clear carry flag
                retn
sub_27          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_28          proc    near
                test    cs:data_135,1
                jnz     short loc_ret_107       ; Jump if not zero
                mov     cx,1
                call    sub_26
                push    ax
                call    sub_25
                pop     ax
                call    sub_27
                jnc     short loc_106           ; Jump if carry=0
                call    sub_29
                call    sub_30
                retn
loc_106:
                call    sub_30
                call    sub_29

loc_ret_107:
                retn
sub_28          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_29          proc    near
                mov     cx,5000h
                call    sub_26
                mov     word ptr cs:data_245,ax
                retn
sub_29          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_30          proc    near
                cmp     cs:data_315,0
                je      short loc_108           ; Jump if equal
                retn
loc_108:
                mov     cs:data_315,1
                mov     cx,1000h
                call    sub_26
                call    sub_27
                jnc     short loc_109           ; Jump if carry=0
                push    ax
                mov     cx,1000h
                call    sub_26
                mov     bx,ax
                pop     ax
                push    bx
                call    sub_25
                pop     ax
loc_109:
                mov     cs:data_246,ax
                mov     dx,ax
                and     ax,0FFFh
                shl     ax,1                    ; Shift w/zeros fill
                shl     ax,1                    ; Shift w/zeros fill
                shl     ax,1                    ; Shift w/zeros fill
                shl     ax,1                    ; Shift w/zeros fill
                mov     cs:data_247,ax
                mov     ax,dx
                rol     ax,1                    ; Rotate
                rol     ax,1                    ; Rotate
                rol     ax,1                    ; Rotate
                rol     ax,1                    ; Rotate
                and     ax,0Fh
                mov     cs:data_248,ax
                retn
sub_30          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_31          proc    near
                cmp     cs:data_146,0
                je      short loc_ret_111       ; Jump if equal
                mov     al,36h                  ; '6'
                out     43h,al                  ; port 43h, 8253 timer control
                mov     dx,12h
                mov     ax,34DCh
                mov     cx,cs:data_173
                cmp     cx,0Dh
                jae     short loc_110           ; Jump if above or =
                mov     cx,0Dh
loc_110:
                div     cx                      ; ax,dx rem=dx:ax/reg
                out     40h,al                  ; port 40h, 8253 timer 0 clock
                mov     al,ah
                out     40h,al                  ; port 40h, 8253 timer 0 clock

loc_ret_111:
                retn
sub_31          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_32          proc    near
                cmp     cs:data_136,5
                je      short loc_114           ; Jump if equal
                cmp     cs:data_136,2
                je      short loc_112           ; Jump if equal
                retn
loc_112:
                mov     al,0
                test    cs:data_193,80h
                jz      short loc_113           ; Jump if zero
                mov     al,2
loc_113:
                call    sub_39
                retn
loc_114:
                mov     dx,cs:data_137
                add     dx,4
                mov     al,0Eh
                out     dx,al                   ; port 3, DMA-1 bas&cnt ch 1
                inc     dx
                mov     al,20h                  ; ' '
                test    cs:data_193,80h
                jz      short loc_115           ; Jump if zero
                mov     al,22h                  ; '"'
loc_115:
                out     dx,al                   ; port 4, DMA-1 bas&add ch 2
                xor     ax,ax                   ; Zero register
                retn
sub_32          endp

data_316        dw      0, 0
                db      0CBh
data_318        dw      28B8h                   ; Data table (indexed access)
                db       90h, 56h,0A0h, 5Eh,0B8h, 28h
                db      0B8h, 28h, 90h, 56h,0B8h, 28h
                db      0B8h
                db      28h
data_319        db      0                       ; Data table (indexed access)
data_320        db      0                       ; Data table (indexed access)
                db       10h, 10h, 10h, 10h, 00h, 00h
                db       00h, 00h, 22h, 22h, 00h, 00h
                db       00h, 00h

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_33          proc    near
                mov     bx,cs:data_136
                mov     cs:data_146,0
                cmp     bx,2
                jne     short loc_116           ; Jump if not equal
                mov     cs:data_146,1
loc_116:
                and     bx,7
                shl     bx,1                    ; Shift w/zeros fill
                mov     ax,cs:data_318[bx]
                mov     cs:data_316,ax
                mov     word ptr cs:data_316+2,cs
                mov     al,cs:data_319[bx]
;*              cmp     cs:data_138,0FFFFh
                db       2Eh, 83h, 3Eh, 86h, 08h,0FFh ;  Fixup - byte match
                jz      short loc_117           ; Jump if zero
;*              cmp     cs:data_137,0FFFFh
                db       2Eh, 83h, 3Eh, 84h, 08h,0FFh ;  Fixup - byte match
                jz      short loc_117           ; Jump if zero
;*              cmp     cs:data_139,0FFFFh
                db       2Eh, 83h, 3Eh, 88h, 08h,0FFh ;  Fixup - byte match
                jz      short loc_117           ; Jump if zero
                jmp     short loc_118
loc_117:
                push    bx
                mov     bx,1
                call    dword ptr cs:data_316
                pop     bx
loc_118:
                cmp     al,cs:data_319[bx]
                jb      short loc_123           ; Jump if below
                cmp     al,cs:data_320[bx]
                jbe     short loc_119           ; Jump if below or =
                mov     al,cs:data_320[bx]
loc_119:
;*              cmp     cs:data_137,0FFFFh
                db       2Eh, 83h, 3Eh, 84h, 08h,0FFh ;  Fixup - byte match
                jz      short loc_120           ; Jump if zero
                mov     dx,cs:data_137
loc_120:
;*              cmp     cs:data_138,0FFFFh
                db       2Eh, 83h, 3Eh, 86h, 08h,0FFh ;  Fixup - byte match
                jz      short loc_121           ; Jump if zero
                mov     cl,byte ptr cs:data_138
loc_121:
;*              cmp     cs:data_139,0FFFFh
                db       2Eh, 83h, 3Eh, 88h, 08h,0FFh ;  Fixup - byte match
                jz      short loc_122           ; Jump if zero
                mov     ch,byte ptr cs:data_139
loc_122:
                xor     bh,bh                   ; Zero register
                mov     bl,cl
                mov     cs:data_138,bx
                xor     bh,bh                   ; Zero register
                mov     bl,ch
                mov     cs:data_139,bx
                mov     cs:data_137,dx
                mov     bx,2
                call    dword ptr cs:data_316
                xor     ah,ah                   ; Zero register
                cmp     ax,0
                jne     short loc_124           ; Jump if not equal
                retn
loc_123:
                cmp     cs:data_136,5
                jne     short loc_124           ; Jump if not equal
                cmp     al,10h
                jb      short loc_124           ; Jump if below
                mov     cs:data_136,1
                jmp     short loc_119
loc_124:
                mov     cs:data_136,0
                retn
sub_33          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_34          proc    near
                call    sub_32
                mov     bx,4
                mov     ax,cs:data_300
                mov     dx,cs:data_246
                xor     cx,cx                   ; Zero register
                call    dword ptr cs:data_316
                mov     bx,5
                mov     al,0
                cmp     cs:data_196,0
                je      short loc_125           ; Jump if equal
                mov     al,2
loc_125:
                mov     dx,cs:data_170
                call    dword ptr cs:data_316
                call    sub_21
                retn
sub_34          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_35          proc    near
                call    sub_22
                mov     bx,6
                call    dword ptr cs:data_316
                retn
sub_35          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_36          proc    near
                mov     bx,0Eh
                call    dword ptr cs:data_316
                retn
sub_36          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_37          proc    near
                cmp     cs:data_146,1
                jne     short loc_ret_126       ; Jump if not equal
                mov     bx,0Ah
                call    dword ptr cs:data_316

loc_ret_126:
                retn
sub_37          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_38          proc    near
                mov     bx,9
                call    dword ptr cs:data_316
                retn
sub_38          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_39          proc    near
                mov     bx,0Dh
                call    dword ptr cs:data_316
                retn
sub_39          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_40          proc    near
                cmp     word ptr es:data_21e,0
                jne     short loc_ret_129       ; Jump if not equal
                cmp     cs:data_146,1
                jne     short loc_128           ; Jump if not equal
                pusha                           ; Save all regs
                push    ds
                push    es
                cmp     cs:data_131,0
                jne     short loc_127           ; Jump if not equal
                push    ax
                mov     ah,5
                mov     cs:data_133,ah
                call    sub_116
                pop     ax
loc_127:
                call    sub_126
                mov     bx,0Bh
                mov     dx,cs:data_134
                call    dword ptr cs:data_316
                call    sub_127
                pop     es
                pop     ds
                popa                            ; Restore all regs
                retn
loc_128:
                mov     word ptr es:data_21e,1

loc_ret_129:
                retn
sub_40          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_41          proc    near
                cmp     cs:data_146,1
                jne     short loc_ret_130       ; Jump if not equal
                pusha                           ; Save all regs
                push    ds
                push    es
                mov     bx,0Ch
                call    dword ptr cs:data_316
                pop     es
                pop     ds
                popa                            ; Restore all regs

loc_ret_130:
                retn
sub_41          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_42          proc    near
                push    ds
                mov     ds,word ptr cs:data_245
                mov     es,cs:data_246
                cmp     cx,40h
                jb      short loc_131           ; Jump if below
                mov     bp,cx
                mov     cl,cs:data_193
                test    cl,80h
                jnz     short loc_132           ; Jump if not zero
                jmp     loc_134
loc_131:
                pop     ds
                retn
loc_132:
                mov     dx,cs:data_119
                mov     cx,dx
                mov     ax,400h
                sub     ax,cs:data_314
                add     dx,ax
                mov     ax,400h
                sub     ax,cs:data_313
                add     cx,ax
                mov     ax,cx
                shl     ecx,10h                 ; Shift w/zeros fill
                mov     cx,ax
                mov     ax,dx
                shl     edx,10h                 ; Shift w/zeros fill
                mov     dx,ax
                mov     ax,si
                add     ax,bp
                mov     cs:data_290,ax
                pushf                           ; Push flags
                mov     cs:data_288,esp
                cli                             ; Disable interrupts
                mov     esp,0
loc_133:
                mov     ebx,[si]
                add     ebx,ecx
                mov     [si],esp
                mov     ah,cs:[bx]
                add     si,data_14e
                mov     ebp,[si]
                add     ebp,edx
                mov     [si],esp
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ah,cs:[bx]
                shr     ebp,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                add     si,data_17e
                mov     es:[di],eax
                add     di,4
                mov     ebx,[si]
                add     ebx,ecx
                mov     [si],esp
                mov     ah,cs:[bx]
                add     si,data_14e
                mov     ebp,[si]
                add     ebp,edx
                mov     [si],esp
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ah,cs:[bx]
                shr     ebp,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                add     si,data_17e
                mov     es:[di],eax
                add     di,4
                mov     ebx,[si]
                add     ebx,ecx
                mov     [si],esp
                mov     ah,cs:[bx]
                add     si,data_14e
                mov     ebp,[si]
                add     ebp,edx
                mov     [si],esp
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ah,cs:[bx]
                shr     ebp,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                add     si,data_17e
                mov     es:[di],eax
                add     di,4
                mov     ebx,[si]
                add     ebx,ecx
                mov     [si],esp
                mov     ah,cs:[bx]
                add     si,data_14e
                mov     ebp,[si]
                add     ebp,edx
                mov     [si],esp
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ah,cs:[bx]
                shr     ebp,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                add     si,data_17e
                mov     es:[di],eax
                add     di,4
                mov     ebx,[si]
                add     ebx,ecx
                mov     [si],esp
                mov     ah,cs:[bx]
                add     si,data_14e
                mov     ebp,[si]
                add     ebp,edx
                mov     [si],esp
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ah,cs:[bx]
                shr     ebp,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                add     si,data_17e
                mov     es:[di],eax
                add     di,4
                mov     ebx,[si]
                add     ebx,ecx
                mov     [si],esp
                mov     ah,cs:[bx]
                add     si,data_14e
                mov     ebp,[si]
                add     ebp,edx
                mov     [si],esp
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ah,cs:[bx]
                shr     ebp,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                add     si,data_17e
                mov     es:[di],eax
                add     di,4
                mov     ebx,[si]
                add     ebx,ecx
                mov     [si],esp
                mov     ah,cs:[bx]
                add     si,data_14e
                mov     ebp,[si]
                add     ebp,edx
                mov     [si],esp
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ah,cs:[bx]
                shr     ebp,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                add     si,data_17e
                mov     es:[di],eax
                add     di,4
                mov     ebx,[si]
                add     ebx,ecx
                mov     [si],esp
                mov     ah,cs:[bx]
                add     si,data_14e
                mov     ebp,[si]
                add     ebp,edx
                mov     [si],esp
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ah,cs:[bx]
                shr     ebp,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                add     si,data_17e
                mov     es:[di],eax
                add     di,4
                mov     ebx,[si]
                add     ebx,ecx
                mov     [si],esp
                mov     ah,cs:[bx]
                add     si,data_14e
                mov     ebp,[si]
                add     ebp,edx
                mov     [si],esp
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ah,cs:[bx]
                shr     ebp,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                add     si,data_17e
                mov     es:[di],eax
                add     di,4
                mov     ebx,[si]
                add     ebx,ecx
                mov     [si],esp
                mov     ah,cs:[bx]
                add     si,data_14e
                mov     ebp,[si]
                add     ebp,edx
                mov     [si],esp
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ah,cs:[bx]
                shr     ebp,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                add     si,data_17e
                mov     es:[di],eax
                add     di,4
                mov     ebx,[si]
                add     ebx,ecx
                mov     [si],esp
                mov     ah,cs:[bx]
                add     si,data_14e
                mov     ebp,[si]
                add     ebp,edx
                mov     [si],esp
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ah,cs:[bx]
                shr     ebp,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                add     si,data_17e
                mov     es:[di],eax
                add     di,4
                mov     ebx,[si]
                add     ebx,ecx
                mov     [si],esp
                mov     ah,cs:[bx]
                add     si,data_14e
                mov     ebp,[si]
                add     ebp,edx
                mov     [si],esp
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ah,cs:[bx]
                shr     ebp,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                add     si,data_17e
                mov     es:[di],eax
                add     di,4
                mov     ebx,[si]
                add     ebx,ecx
                mov     [si],esp
                mov     ah,cs:[bx]
                add     si,data_14e
                mov     ebp,[si]
                add     ebp,edx
                mov     [si],esp
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ah,cs:[bx]
                shr     ebp,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                add     si,data_17e
                mov     es:[di],eax
                add     di,4
                mov     ebx,[si]
                add     ebx,ecx
                mov     [si],esp
                mov     ah,cs:[bx]
                add     si,data_14e
                mov     ebp,[si]
                add     ebp,edx
                mov     [si],esp
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ah,cs:[bx]
                shr     ebp,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                add     si,data_17e
                mov     es:[di],eax
                add     di,4
                mov     ebx,[si]
                add     ebx,ecx
                mov     [si],esp
                mov     ah,cs:[bx]
                add     si,data_14e
                mov     ebp,[si]
                add     ebp,edx
                mov     [si],esp
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ah,cs:[bx]
                shr     ebp,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                add     si,data_17e
                mov     es:[di],eax
                add     di,4
                mov     ebx,[si]
                add     ebx,ecx
                mov     [si],esp
                mov     ah,cs:[bx]
                add     si,data_14e
                mov     ebp,[si]
                add     ebp,edx
                mov     [si],esp
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ah,cs:[bx]
                shr     ebp,10h                 ; Shift w/zeros fill
                mov     al,cs:[bp]
                add     si,0F804h
                mov     es:[di],eax
                add     di,4
                cmp     si,cs:data_290
                jb      loc_133                 ; Jump if below
                mov     esp,cs:data_288
                popf                            ; Pop flags
                pop     ds
                retn
sub_42          endp

loc_134:
                mov     ax,cs:data_119
                add     ax,400h
                sub     ax,cs:data_312
                mov     dx,ax
                shl     edx,10h                 ; Shift w/zeros fill
                mov     dx,ax
                mov     ax,bp
                shl     ax,1                    ; Shift w/zeros fill
                add     ax,si
                mov     cs:data_290,ax
                mov     bp,cs:data_290
                mov     ecx,0
                sub     bp,8
                sub     si,8
                sub     di,4
loc_135:
                add     si,0Ch
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                sub     si,4
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                add     di,4
                mov     es:[di],eax
                add     si,0Ch
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                sub     si,4
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                add     di,4
                mov     es:[di],eax
                add     si,0Ch
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                sub     si,4
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                add     di,4
                mov     es:[di],eax
                add     si,0Ch
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                sub     si,4
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                add     di,4
                mov     es:[di],eax
                add     si,0Ch
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                sub     si,4
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                add     di,4
                mov     es:[di],eax
                add     si,0Ch
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                sub     si,4
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                add     di,4
                mov     es:[di],eax
                add     si,0Ch
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                sub     si,4
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                add     di,4
                mov     es:[di],eax
                add     si,0Ch
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                sub     si,4
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                add     di,4
                mov     es:[di],eax
                add     si,0Ch
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                sub     si,4
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                add     di,4
                mov     es:[di],eax
                add     si,0Ch
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                sub     si,4
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                add     di,4
                mov     es:[di],eax
                add     si,0Ch
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                sub     si,4
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                add     di,4
                mov     es:[di],eax
                add     si,0Ch
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                sub     si,4
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                add     di,4
                mov     es:[di],eax
                add     si,0Ch
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                sub     si,4
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                add     di,4
                mov     es:[di],eax
                add     si,0Ch
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                sub     si,4
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                add     di,4
                mov     es:[di],eax
                add     si,0Ch
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                sub     si,4
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                add     di,4
                mov     es:[di],eax
                add     si,0Ch
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                sub     si,4
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                mov     ebx,[si]
                add     ebx,edx
                mov     [si],ecx
                mov     ah,cs:[bx]
                shr     ebx,10h                 ; Shift w/zeros fill
                mov     al,cs:[bx]
                add     di,4
                mov     es:[di],eax
                cmp     si,bp
                jb      loc_135                 ; Jump if below
                add     di,4
                add     si,8
                pop     ds
                retn
                                                ;* No entry point to code
                shr     ax,1                    ; Shift w/zeros fill
                mov     cs:data_309,ax
                xor     ah,ah                   ; Zero register
                shr     cs:data_309,1           ; Shift w/zeros fill
                jnc     short loc_137           ; Jump if carry=0
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     [di],eax
                add     di,4
loc_137:
                shr     cs:data_309,1           ; Shift w/zeros fill
                jnc     short loc_138           ; Jump if carry=0
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     [di],eax
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     [di+4],eax
                add     di,8
loc_138:
                cmp     cs:data_309,0
                je      loc_ret_140             ; Jump if equal
                mov     ax,cs:data_309
                shl     ax,4                    ; Shift w/zeros fill
                add     ax,di
                mov     cs:data_309,ax
                xor     ah,ah                   ; Zero register
loc_139:
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     [di],eax
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     [di+4],eax
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     [di+8],eax
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     [di+0Ch],eax
                add     di,10h
                cmp     di,cs:data_309
                jb      loc_139                 ; Jump if below

loc_ret_140:
                retn
                                                ;* No entry point to code
                shr     ax,1                    ; Shift w/zeros fill
                mov     cs:data_309,ax
                xor     ah,ah                   ; Zero register
                shr     cs:data_309,1           ; Shift w/zeros fill
                jnc     short loc_141           ; Jump if carry=0
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     data_121[di],eax
                add     di,4
loc_141:
                shr     cs:data_309,1           ; Shift w/zeros fill
                jnc     short loc_142           ; Jump if carry=0
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     data_121[di],eax
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     data_122[di],eax
                add     di,8
loc_142:
                cmp     cs:data_309,0
                je      loc_ret_144             ; Jump if equal
                mov     ax,cs:data_309
                shl     ax,4                    ; Shift w/zeros fill
                add     ax,di
                mov     cs:data_309,ax
                xor     ah,ah                   ; Zero register
loc_143:
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     data_121[di],eax
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     data_122[di],eax
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     data_123[di],eax
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     data_124[di],eax
                add     di,10h
                cmp     di,cs:data_309
                jb      loc_143                 ; Jump if below

loc_ret_144:
                retn
                                                ;* No entry point to code
                shr     ax,1                    ; Shift w/zeros fill
                mov     cs:data_309,ax
                xor     ah,ah                   ; Zero register
                shr     cs:data_309,1           ; Shift w/zeros fill
                jnc     short loc_145           ; Jump if carry=0
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     [di],eax
                add     data_121[di],eax
                add     di,4
loc_145:
                shr     cs:data_309,1           ; Shift w/zeros fill
                jnc     short loc_146           ; Jump if carry=0
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     [di],eax
                add     data_121[di],eax
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     [di+4],eax
                add     data_122[di],eax
                add     di,8
loc_146:
                cmp     cs:data_309,0
                je      loc_ret_148             ; Jump if equal
                mov     ax,cs:data_309
                shl     ax,4                    ; Shift w/zeros fill
                add     ax,di
                mov     cs:data_309,ax
                xor     ah,ah                   ; Zero register
loc_147:
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     [di],eax
                add     data_121[di],eax
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     [di+4],eax
                add     data_122[di],eax
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     [di+8],eax
                add     data_123[di],eax
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                shl     eax,10h                 ; Shift w/zeros fill
                add     cx,bp
                mov     bl,es:[si]
                adc     si,dx
                mov     al,[bx]
                add     [di+0Ch],eax
                add     data_124[di],eax
                add     di,10h
                cmp     di,cs:data_309
                jb      loc_147                 ; Jump if below

loc_ret_148:
                retn

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_43          proc    near
                push    fs
                mov     ax,cs
                mov     ds,ax
                mov     data_249,bp
                mov     cx,data_243
                mov     data_310,cx
                mov     ax,ds:[bp+54h]
                mov     data_311,ax
                mov     eax,ds:[bp+50h]
                or      eax,eax                 ; Zero ?
                jz      loc_158                 ; Jump if zero
                mov     si,ds:[bp+44h]
;*              cmp     si,0FFFFh
                db       83h,0FEh,0FFh          ;  Fixup - byte match
                jz      loc_158                 ; Jump if zero
                mov     dx,ds:[bp+5Ah]
                cmp     dx,0F000h
                jb      short loc_149           ; Jump if below
                call    sub_125
loc_149:
                mov     es,dx
                mov     bh,ds:[bp+41h]
                mov     fs,word ptr cs:data_245
                push    bx
                mov     bl,80h
                mov     al,fs:[bx]
                xor     ah,ah                   ; Zero register
                mov     bx,ds:[bp+1Bh]
                and     bx,7
                cmp     bl,6
                jae     short loc_150           ; Jump if above or =
                xor     bl,data_293
loc_150:
                add     bx,data_292
                mov     cl,data_323[bx]
                push    ax
                shl     ax,cl                   ; Shift w/zeros fill
                add     data_312,ax
                add     data_313,ax
                pop     ax
                mov     cl,data_324[bx]
                shl     ax,cl                   ; Shift w/zeros fill
                add     data_314,ax
                shl     bx,1                    ; Shift w/zeros fill
                mov     ax,data_322[bx]
                mov     data_291,ax
                pop     bx
                mov     di,data_289
                mov     cx,ds:[bp+42h]
                mov     dx,ds:[bp+52h]
                mov     bp,ds:[bp+50h]
                mov     ax,fs
                mov     ds,ax
loc_151:
                mov     ax,cs:data_310
                cmp     ax,cs:data_311
                jb      short loc_152           ; Jump if below
                mov     ax,cs:data_311
loc_152:
                sub     cs:data_310,ax
                sub     cs:data_311,ax
                cmp     bh,0
                je      loc_159                 ; Jump if equal
                call    cs:data_291
loc_153:
                cmp     cs:data_311,0
                jg      short loc_157           ; Jump if >
                push    bp
                mov     bp,cs:data_249
                cmp     word ptr cs:[bp+56h],8000h
                je      short loc_155           ; Jump if equal
                mov     ax,cs:[bp+4Ch]
                cmp     ax,0FFFFh
                jne     short loc_154           ; Jump if not equal
                xor     eax,eax                 ; Zero register
                mov     cs:[bp+50h],eax
                mov     cs:data_311,8000h
                jmp     short loc_156
loc_154:
                sub     ax,cs:[bp+48h]
                add     si,ax
loc_155:
                mov     cs:[bp+42h],cx
                mov     cs:[bp+44h],si
                push    si
                push    ds
                mov     ax,cs
                mov     ds,ax
                mov     si,bp
                or      si,8000h
                call    sub_139
                mov     ax,cs:[bp+54h]
                mov     cs:data_311,ax
                pop     ds
                pop     si
loc_156:
                pop     bp
loc_157:
                cmp     cs:data_310,0
                jne     loc_151                 ; Jump if not equal
                mov     di,word ptr cs:data_308
                mov     bp,cs:data_249
                mov     ax,cs:data_311
                mov     cs:[bp+54h],ax
                mov     cs:[bp+42h],cx
                mov     cs:[bp+44h],si
                mov     cs:data_294,0
loc_158:
                pop     fs
                retn
loc_159:
                push    bx
                push    dx
                mov     bx,ax
                add     di,ax
                mov     ax,dx
                mul     bx                      ; dx:ax = reg * ax
                add     si,ax
                mov     ax,bp
                mul     bx                      ; dx:ax = reg * ax
                add     cx,ax
                adc     si,dx
                pop     dx
                pop     bx
                jmp     loc_153
sub_43          endp

data_322        dw      3245h                   ; Data table (indexed access)
                db      '83E28354545454E2E2E2E2E2E2E2E2'
data_323        db      0                       ; Data table (indexed access)
                db       10h, 01h, 10h, 01h, 00h, 00h
                db       01h, 00h, 00h, 01h, 01h, 01h
                db       01h, 00h, 01h
data_324        db      10h                     ; Data table (indexed access)
                db       00h, 10h, 01h, 00h, 01h, 00h
                db       01h, 00h, 00h, 01h, 01h, 01h
                db       01h, 00h, 01h,0C3h

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_44          proc    near
                test    cs:data_135,1
                jnz     short loc_ret_160       ; Jump if not zero
                mov     ax,cs:data_243
                cmp     ax,40h
                jae     short loc_161           ; Jump if above or =
                retn
                                                ;* No entry point to code
                mov     cs:data_153,0

loc_ret_160:
                retn
loc_161:
                push    cs:data_243
                push    cs:data_239
                mov     ax,cs:data_238
                mov     cs:data_289,ax
                add     ax,cs:data_243
                mov     cs:data_290,ax
                mov     cs:data_312,0
                mov     cs:data_313,0
                mov     cs:data_314,0
                mov     bp,offset data_267
                test    cs:data_193,80h
                jnz     short loc_162           ; Jump if not zero
                jmp     short loc_167
loc_162:
                mov     cs:data_292,0
                mov     cs:data_293,0
                shr     cs:data_243,1           ; Shift w/zeros fill
loc_163:
                mov     ax,cs:[bp+44h]
                mov     dx,cs:[bp+5Ah]
                cmp     dx,0
                je      short loc_164           ; Jump if equal
                cmp     ax,cs:[bp+48h]
                jae     short loc_164           ; Jump if above or =
                call    sub_43
loc_164:
                add     bp,60h
                cmp     bp,offset data_270
                jb      loc_163                 ; Jump if below
                mov     ax,cs:data_238
                mov     cs:data_289,ax
                mov     cs:data_293,1
                add     ax,cs:data_243
                mov     cs:data_290,ax
                mov     cs:data_312,0
loc_165:
                mov     ax,cs:[bp+44h]
                mov     dx,cs:[bp+5Ah]
                cmp     dx,0
                je      short loc_166           ; Jump if equal
                cmp     ax,cs:[bp+48h]
                jae     short loc_166           ; Jump if above or =
                call    sub_43
loc_166:
                add     bp,60h
                cmp     bp,offset data_271
                jb      loc_165                 ; Jump if below
                jmp     short loc_170
loc_167:
                mov     cs:data_293,0
                mov     cs:data_292,8
loc_168:
                mov     ax,cs:[bp+44h]
                mov     dx,cs:[bp+5Ah]
                cmp     dx,0
                je      short loc_169           ; Jump if equal
                cmp     ax,cs:[bp+48h]
                jae     short loc_169           ; Jump if above or =
                call    sub_43
loc_169:
                add     bp,60h
                cmp     bp,1390h
                jb      loc_168                 ; Jump if below
loc_170:
                pop     di
                pop     cx
                push    di
                push    cx
                cmp     cs:data_131,0
                jne     short loc_171           ; Jump if not equal
                push    ax
                mov     ah,0Ch
                mov     cs:data_133,ah
                call    sub_116
                pop     ax
loc_171:
                mov     si,cs:data_238
                mov     ds,word ptr cs:data_245
                mov     ax,di
                add     ax,cx
                cmp     ax,cs:data_301
                jbe     short loc_172           ; Jump if below or =
                push    cx
                mov     cx,cs:data_301
                sub     cx,di
                push    cx
                call    sub_42
                pop     ax
                pop     cx
                sub     cx,ax
                and     di,cs:data_302
loc_172:
                call    sub_42
                and     di,cs:data_302
                mov     cs:data_239,di
                pop     cx
                pop     di
                cmp     byte ptr ds:data_15e,0
                je      short loc_ret_174       ; Jump if equal
                cmp     cs:data_131,0
                jne     short loc_173           ; Jump if not equal
                push    ax
                mov     ah,6
                mov     cs:data_133,ah
                call    sub_116
                pop     ax
loc_173:
                call    sub_46

loc_ret_174:
                retn
sub_44          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_45          proc    near
                push    ds
                jcxz    short loc_175           ; Jump if cx=0
                mov     ds,cs:data_134
                mov     bx,cs:data_181
;*              cmp     bx,0FFFFh
                db       83h,0FBh,0FFh          ;  Fixup - byte match
                jz      short loc_175           ; Jump if zero
                xor     bh,bh                   ; Zero register
                shl     bx,1                    ; Shift w/zeros fill
                add     bx,cs:data_206
                mov     ax,[bx]
                add     ax,cs:data_134
                mov     ds,ax
                mov     ax,ds:data_1e
                cmp     ax,1
                jne     short loc_175           ; Jump if not equal
                mov     ax,ds:data_3e
                cmp     ax,0
                jne     short loc_176           ; Jump if not equal
                cmp     cs:data_279,2
                jge     short loc_176           ; Jump if > or =
loc_175:
                pop     ds
                retn
loc_176:
                add     ax,cx
                jnc     short loc_178           ; Jump if carry=0
loc_177:
                mov     cs:data_181,0FFFFh
                pop     ds
                retn
loc_178:
                cmp     ax,0FA00h
                jae     loc_177                 ; Jump if above or =
                mov     ds:data_3e,ax
                sub     ax,cx
                mov     si,di
                mov     di,ax
                mov     ax,cs:data_183
                cmp     ax,0
                je      loc_177                 ; Jump if equal
                mov     es,ax
                mov     ds,cs:data_246
                mov     dx,cs:data_302

locloop_179:
                movsb                           ; Mov [si] to es:[di]
                and     si,dx
                loop    locloop_179             ; Loop if cx > 0

                pop     ds
                retn
sub_45          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_46          proc    near
                mov     ax,cs
                mov     ds,ax
                test    data_194,20h
                jz      short loc_180           ; Jump if zero
                cmp     data_295,1
                cmp     data_295,2
                cmp     data_295,3
                cmp     data_295,4
                je      short loc_181           ; Jump if equal
                retn
loc_180:
                mov     cs:data_295,0
                retn
                                                ;* No entry point to code
                mov     ah,3
                jmp     short loc_182
                                                ;* No entry point to code
                mov     ah,2
                jmp     short loc_182
                db      0B4h, 01h,0EBh, 02h
loc_181:
                jmp     short loc_184
loc_182:
                mov     al,40h                  ; '@'
                mov     dx,data_302
                mov     si,data_296
                add     si,data_238

locloop_183:
                mov     al,[di]
                mov     bx,si
                add     bx,30h
                and     bx,77FFh
                add     al,[bx]
                mov     [di],al
                sub     al,80h
                xchg    cl,ah
                sar     al,cl                   ; Shift w/sign fill
                xchg    cl,ah
                mov     [si],al
                inc     si
                and     si,77FFh
                inc     di
                and     di,dx
                loop    locloop_183             ; Loop if cx > 0

                sub     si,data_238
                mov     data_296,si
                retn
                db      0C3h
loc_184:
                mov     cl,data_193
                test    cl,80h
                jnz     short loc_186           ; Jump if not zero
                mov     ah,[di]
                mov     dx,data_302

locloop_185:
                mov     al,[di]
                add     ah,al
                rcr     ah,1                    ; Rotate thru carry
                mov     [di],ah
                mov     ah,al
                inc     di
                and     di,dx
                loop    locloop_185             ; Loop if cx > 0

                retn
loc_186:
                mov     ah,[di]
                mov     dh,[di+1]
                mov     bx,data_302
                shr     cx,1                    ; Shift w/zeros fill

locloop_187:
                mov     al,[di]
                add     ah,al
                rcr     ah,1                    ; Rotate thru carry
                mov     [di],ah
                mov     ah,al
                inc     di
                and     di,bx
                mov     dl,[di]
                add     dh,dl
                rcr     dh,1                    ; Rotate thru carry
                mov     [di],dh
                mov     dh,dl
                inc     di
                and     di,bx
                loop    locloop_187             ; Loop if cx > 0

                retn
sub_46          endp

data_325        dw      offset sub_82           ; Data table (indexed access)
data_326        dw      offset sub_89
data_327        dw      offset sub_84
data_328        dw      offset sub_85
data_329        dw      offset sub_86
data_330        dw      offset sub_49
data_331        dw      offset sub_49
data_332        dw      offset sub_49
data_333        dw      offset sub_49
data_334        dw      offset sub_49
data_335        dw      offset sub_87
data_336        dw      offset sub_88
data_337        dw      offset sub_78
data_338        dw      offset sub_80
data_339        dw      offset sub_77
data_340        dw      offset sub_49
data_341        dw      offset sub_49           ; Data table (indexed access)
data_342        dw      offset sub_49
data_343        dw      offset sub_49
data_344        dw      offset sub_49
data_345        dw      offset sub_49
data_346        dw      offset sub_49
data_347        dw      offset sub_49
data_348        dw      offset sub_49
data_349        dw      offset sub_49
data_350        dw      offset sub_49
data_351        dw      offset sub_49
data_352        dw      offset sub_49
data_353        dw      offset sub_79
data_354        dw      offset sub_81
data_355        dw      offset sub_49
data_356        dw      offset sub_49
data_357        dw      offset sub_49           ; Data table (indexed access)
data_358        dw      offset sub_51
data_359        dw      offset sub_52
data_360        dw      offset sub_53
data_361        dw      offset sub_58
data_362        dw      offset sub_55
data_363        dw      offset sub_54
data_364        dw      offset sub_49
data_365        dw      offset sub_49
data_366        dw      offset sub_70
data_367        dw      offset sub_71
data_368        dw      offset sub_49
data_369        dw      offset sub_49
data_370        dw      offset sub_49
data_371        dw      offset sub_49
data_372        dw      offset sub_72
data_373        dw      offset sub_49
data_374        dw      offset sub_73
data_375        dw      offset sub_49
data_376        dw      offset sub_75
data_377        dw      offset sub_50
data_378        dw      offset sub_49
data_379        dw      offset sub_49
data_380        dw      offset sub_49
data_381        dw      offset sub_49
data_382        dw      offset sub_49
data_383        dw      offset sub_74
data_384        dw      offset sub_49           ; Data table (indexed access)
data_385        dw      offset sub_49
data_386        dw      offset sub_49
data_387        dw      offset sub_49
data_388        dw      offset sub_58
data_389        dw      offset sub_55
data_390        dw      offset sub_54
data_391        dw      offset sub_59
data_392        dw      offset sub_60
data_393        dw      offset sub_70
data_394        dw      offset sub_71
data_395        dw      offset sub_56
data_396        dw      offset sub_57
data_397        dw      offset sub_49
data_398        dw      offset sub_49
data_399        dw      offset sub_49
data_400        dw      offset sub_49
data_401        dw      offset sub_73
data_402        dw      offset sub_69
data_403        dw      offset sub_76
data_404        dw      offset sub_49
data_405        dw      offset sub_49
data_406        dw      offset sub_83
data_407        dw      offset sub_49
data_408        dw      offset sub_49
data_409        dw      offset sub_49
data_410        dw      offset sub_49

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_47          proc    near
                push    bp
                mov     cx,data_150
                inc     cx
                mov     si,offset data_267
loc_188:
                cmp     byte ptr [si+1],0
                je      loc_198                 ; Jump if equal
                push    si
                push    cx
                mov     al,[si+3Eh]
                cmp     al,0
                je      short loc_191           ; Jump if equal
                dec     al
                mov     [si+3Eh],al
loc_190:
                jnz     short loc_191           ; Jump if not zero
                mov     ax,0FFh
                mov     [si+32h],al
                mov     [si+33h],ah
                mov     [si+34h],al
                mov     [si+35h],ah
                mov     [si+36h],ah
loc_191:
                test    data_194,8
                jz      short loc_193           ; Jump if zero
                cmp     byte ptr [si+1Ah],0
                jne     short loc_192           ; Jump if not equal
                cmp     byte ptr [si+34h],0FFh
                jne     short loc_192           ; Jump if not equal
                cmp     byte ptr [si+33h],0
                jne     short loc_192           ; Jump if not equal
                cmp     byte ptr [si+32h],0FFh
                jne     short loc_192           ; Jump if not equal
                dec     byte ptr [si+31h]
                jnz     short loc_193           ; Jump if not zero
                mov     word ptr [si+44h],0FFFFh
                mov     byte ptr [si+1],0
                jmp     short loc_197
loc_192:
                mov     byte ptr [si+31h],3
loc_193:
                mov     ah,[si+35h]
                mov     al,[si+36h]
                cmp     al,0
                je      short loc_194           ; Jump if equal
                mov     [si+39h],al
loc_194:
                cmp     ah,0
                je      short loc_200           ; Jump if equal
                or      byte ptr [si+1],80h
                cmp     ah,4
                je      short loc_201           ; Jump if equal
                cmp     ah,9
                je      short loc_195           ; Jump if equal
                mov     byte ptr [si+2Fh],0
                mov     byte ptr [si+2Dh],1
loc_195:
                cmp     ah,8
                je      short loc_196           ; Jump if equal
                cmp     ah,0Bh
                je      short loc_196           ; Jump if equal
                cmp     ah,12h
                je      short loc_196           ; Jump if equal
                or      byte ptr [si+26h],80h
loc_196:
                mov     bl,ah
                xor     bh,bh                   ; Zero register
                cmp     bx,1Bh
                ja      short loc_197           ; Jump if above
                shl     bx,1                    ; Shift w/zeros fill
                xor     bp,bp                   ; Zero register
                call    word ptr data_357[bx]   ;*54 entries
loc_197:
                pop     cx
                pop     si
loc_198:
                add     si,60h
                dec     cx
                jz      short loc_199           ; Jump if zero
                jmp     loc_188
loc_199:
                pop     bp
                retn
loc_200:
                xor     ax,ax                   ; Zero register
                mov     [si+2Eh],al
                mov     ax,[si+24h]
                cmp     ax,[si+12h]
                je      loc_197                 ; Jump if equal
                mov     [si+12h],ax
                call    sub_139
                jmp     short loc_197
loc_201:
                push    ax
                xor     ax,ax                   ; Zero register
                mov     [si+2Eh],al
                mov     ax,[si+24h]
                cmp     ax,[si+12h]
                je      short loc_202           ; Jump if equal
                mov     [si+12h],ax
                call    sub_139
loc_202:
                pop     ax
                jmp     short loc_196
sub_47          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_48          proc    near
                push    bp
                mov     cx,data_150
                inc     cx
                mov     si,offset data_267

locloop_203:
                cmp     byte ptr [si+1],0
                je      short loc_205           ; Jump if equal
                mov     ah,[si+35h]
                mov     al,[si+36h]
                cmp     ah,0
                je      short loc_205           ; Jump if equal
                or      byte ptr [si+1],80h
                push    si
                push    cx
                mov     bl,ah
                xor     bh,bh                   ; Zero register
                cmp     bx,1Bh
                ja      short loc_204           ; Jump if above
                shl     bx,1                    ; Shift w/zeros fill
                xor     bp,bp                   ; Zero register
                call    word ptr data_384[bx]   ;*27 entries
loc_204:
                pop     cx
                pop     si
loc_205:
                add     si,60h
                loop    locloop_203             ; Loop if cx > 0

                pop     bp
                retn
sub_48          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_49          proc    near
                retn
sub_49          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_50          proc    near
                xor     ah,ah                   ; Zero register
                cmp     ax,20h
                jbe     short loc_208           ; Jump if below or =
                push    ax
                mov     cs:data_189,al
                mov     cx,3200h
                mul     cx                      ; dx:ax = reg * ax
                mov     cx,7Dh
                div     cx                      ; ax,dx rem=dx:ax/reg
                mov     al,ah
                xor     ah,ah                   ; Zero register
                mov     cs:data_173,ax
                pop     cx
                mov     ax,32h
                mul     cx                      ; dx:ax = reg * ax
                mov     bx,ax
                mov     ax,cs:data_170
                mov     cx,7Dh
                mul     cx                      ; dx:ax = reg * ax
                div     bx                      ; ax,dx rem=dx:ax/reg
                mov     cs:data_176,ax
                mov     cs:data_175,1
                mov     cx,cs:data_173
loc_206:
                cmp     cx,18h
                ja      short loc_207           ; Jump if above
                shl     cx,1                    ; Shift w/zeros fill
                inc     cs:data_175
                jmp     short loc_206
loc_207:
                mov     dx,12h
                mov     ax,3333h
                div     cx                      ; ax,dx rem=dx:ax/reg
                mov     cs:data_174,ax
loc_208:
                call    sub_31
                retn
sub_50          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_51          proc    near
                cmp     al,0
                je      loc_208                 ; Jump if equal
                xor     ah,ah                   ; Zero register
                mov     cs:data_280,ax
                retn
sub_51          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_52          proc    near
                inc     cs:data_188
                mov     data_210,1
                cmp     al,0FFh
                je      short loc_209           ; Jump if equal
                xor     ah,ah                   ; Zero register
                mov     data_213,ax
                retn
loc_209:
                cmp     data_209,0
                je      short loc_ret_210       ; Jump if equal
                mov     data_210,0FFh

loc_ret_210:
                retn
sub_52          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_53          proc    near
                mov     ah,al
                shr     ah,4                    ; Shift w/zeros fill
                and     al,0Fh
                aad                             ; Ascii adjust
                mov     data_211,al
                mov     data_210,1
                retn
sub_53          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_54          proc    near
                cmp     word ptr [si+24h],0
                je      short loc_ret_213       ; Jump if equal
                cmp     al,0
                jne     short loc_211           ; Jump if not equal
                mov     al,[si+39h]
                mov     [si+36h],al
loc_211:
                xor     ah,ah                   ; Zero register
                cmp     data_279,0
                je      short loc_214           ; Jump if equal
                cmp     al,0E0h
                jae     short loc_ret_213       ; Jump if above or =
                shl     ax,1                    ; Shift w/zeros fill
                shl     ax,1                    ; Shift w/zeros fill
loc_212:
                sub     [si+12h],ax
                sub     [si+24h],ax
                call    sub_139

loc_ret_213:
                retn
loc_214:
                cmp     al,0E0h
                jbe     loc_ret_213             ; Jump if below or =
                cmp     al,0F0h
                jbe     short loc_215           ; Jump if below or =
                and     al,0Fh
                shl     ax,1                    ; Shift w/zeros fill
                shl     ax,1                    ; Shift w/zeros fill
                jmp     short loc_212
loc_215:
                and     al,0Fh
                jmp     short loc_212
sub_54          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_55          proc    near
                cmp     word ptr [si+24h],0
                je      loc_ret_213             ; Jump if equal
                cmp     al,0
                jne     short loc_216           ; Jump if not equal
                mov     al,[si+39h]
                mov     [si+36h],al
loc_216:
                xor     ah,ah                   ; Zero register
                cmp     data_279,0
                je      short loc_218           ; Jump if equal
                cmp     al,0E0h
                jae     loc_ret_213             ; Jump if above or =
                shl     ax,1                    ; Shift w/zeros fill
                shl     ax,1                    ; Shift w/zeros fill
loc_217:
                add     [si+12h],ax
                add     [si+24h],ax
                call    sub_139
                retn
loc_218:
                cmp     al,0E0h
                jbe     loc_ret_213             ; Jump if below or =
                cmp     al,0F0h
                jbe     short loc_219           ; Jump if below or =
                and     al,0Fh
                shl     ax,1                    ; Shift w/zeros fill
                shl     ax,1                    ; Shift w/zeros fill
                jmp     short loc_217
loc_219:
                and     al,0Fh
                jmp     short loc_217
sub_55          endp

                                                ;* No entry point to code
                sub     al,0F0h
                jmp     short loc_220
                db       2Ch,0F0h,0F6h,0D8h
loc_220:
                mov     dx,[si+20h]
                cmp     dx,[si+12h]
                jne     short loc_227           ; Jump if not equal
                mov     dl,al
                mov     al,[si+38h]
                cmp     al,0FAh
                ja      loc_ret_213             ; Jump if above
                mov     ah,al
                and     al,0F0h
                and     ah,0Fh
                add     ah,dl
loc_221:
                cmp     ah,0Ch
                jl      short loc_222           ; Jump if <
                add     al,4
                sub     ah,0Ch
                jmp     short loc_221
loc_222:
                cmp     ah,0
                jge     short loc_223           ; Jump if > or =
                sub     al,4
                add     ah,0Ch
                jmp     short loc_222
loc_223:
                add     al,dl
                call    sub_141
                call    sub_137
                mov     [si+20h],ax
                sub     ax,[si+12h]
                cmp     ax,0
                jge     short loc_224           ; Jump if > or =
                neg     ax
loc_224:
                mov     cx,data_280
                dec     cx
                cmp     cx,0
                je      short loc_225           ; Jump if equal
                xor     dx,dx                   ; Zero register
                div     cx                      ; ax,dx rem=dx:ax/reg
loc_225:
                shr     ax,1                    ; Shift w/zeros fill
                shr     ax,1                    ; Shift w/zeros fill
                cmp     ah,0
                je      short loc_226           ; Jump if equal
                mov     al,0FFh
loc_226:
                mov     [si+30h],al
loc_227:
                mov     al,[si+30h]
                jmp     loc_239
                db      0C3h

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_56          proc    near
                mov     bp,2
                jmp     short loc_228

;==== External Entry into Subroutine ======================================

sub_57:
                mov     bp,1

;==== External Entry into Subroutine ======================================

sub_58:
loc_228:
                mov     byte ptr cs:[si+3Ch],1
                cmp     al,0
                jne     short loc_229           ; Jump if not equal
                mov     al,[si+39h]
                mov     [si+36h],al
loc_229:
                mov     dl,al
                mov     dh,al
                and     dl,0Fh
                mov     cl,4
                shr     dh,cl                   ; Shift w/zeros fill
                cmp     dl,0Fh
                je      short loc_236           ; Jump if equal
                cmp     dh,0Fh
                je      short loc_237           ; Jump if equal
                cmp     dl,0
                je      short loc_233           ; Jump if equal
loc_230:
                xor     dh,dh                   ; Zero register
                sub     [si+1Ah],dl
                cmp     byte ptr [si+1Ah],0
                jge     short loc_231           ; Jump if > or =
                mov     byte ptr [si+1Ah],0
loc_231:
                call    sub_140
                cmp     bp,1
                je      short loc_238           ; Jump if equal
                cmp     bp,2
                jne     short loc_ret_232       ; Jump if not equal
                jmp     loc_250

loc_ret_232:
                retn
loc_233:
                mov     al,dh
                xor     ah,ah                   ; Zero register
                add     [si+1Ah],al
                cmp     byte ptr [si+1Ah],40h   ; '@'
                jl      short loc_234           ; Jump if <
                mov     byte ptr [si+1Ah],3Fh   ; '?'
loc_234:
                call    sub_140
                cmp     bp,1
                je      short loc_238           ; Jump if equal
                cmp     bp,2
                jne     short loc_ret_235       ; Jump if not equal
                jmp     loc_250

loc_ret_235:
                retn
loc_236:
                cmp     dh,0
                je      loc_230                 ; Jump if equal
                cmp     data_279,0
                jne     loc_ret_235             ; Jump if not equal
                jmp     short loc_233
loc_237:
                cmp     dl,0
                je      loc_233                 ; Jump if equal
                cmp     data_279,0
                jne     loc_ret_235             ; Jump if not equal
                jmp     short loc_230
loc_238:
                mov     al,[si+2Ch]
                jmp     short loc_241

;==== External Entry into Subroutine ======================================

sub_59:
loc_239:
                cmp     word ptr [si+24h],0
                je      short loc_ret_242       ; Jump if equal
                cmp     al,0
                jne     short loc_240           ; Jump if not equal
                mov     al,[si+2Ch]
loc_240:
                mov     [si+2Ch],al
                mov     [si+36h],al
loc_241:
                mov     dl,al
                mov     ax,[si+12h]
                cmp     ax,[si+20h]
                jne     short loc_243           ; Jump if not equal

loc_ret_242:
                retn
loc_243:
                ja      short loc_246           ; Jump if above
                xor     dh,dh                   ; Zero register
                shl     dx,1                    ; Shift w/zeros fill
                shl     dx,1                    ; Shift w/zeros fill
                add     ax,dx
                cmp     ax,[si+20h]
                jbe     short loc_244           ; Jump if below or =
                mov     ax,[si+20h]
loc_244:
                mov     [si+24h],ax
                cmp     cs:data_195,0
                je      short loc_245           ; Jump if equal
                call    sub_136
loc_245:
                mov     [si+12h],ax
                call    sub_139
                retn
loc_246:
                xor     dh,dh                   ; Zero register
                shl     dx,1                    ; Shift w/zeros fill
                shl     dx,1                    ; Shift w/zeros fill
                sub     ax,dx
                jc      short loc_247           ; Jump if carry Set
                cmp     ax,[si+20h]
                jae     short loc_248           ; Jump if above or =
loc_247:
                mov     ax,[si+20h]
loc_248:
                mov     [si+24h],ax
                cmp     cs:data_195,0
                je      short loc_249           ; Jump if equal
                call    sub_136
loc_249:
                mov     [si+12h],ax
                call    sub_139
                retn
loc_250:
                mov     al,[si+2Bh]
                jmp     short loc_253

;==== External Entry into Subroutine ======================================

sub_60:
                cmp     al,0
                jne     short loc_251           ; Jump if not equal
                mov     al,[si+2Bh]
loc_251:
                test    al,0F0h
                jnz     short loc_252           ; Jump if not zero
                mov     ah,[si+2Bh]
                and     al,0Fh
                and     ah,0F0h
                or      al,ah
loc_252:
                mov     [si+2Bh],al
                mov     [si+36h],al
loc_253:
                cmp     word ptr [si+24h],0
                je      short loc_ret_255       ; Jump if equal
                mov     cl,al
                mov     ch,al
                and     cl,0Fh
                mov     ax,[si+26h]
                mov     bx,[si+3Dh]
                and     bx,0Eh
                call    word ptr cs:data_411[bx] ;*8 entries
                push    cx
                xor     ch,ch                   ; Zero register
                imul    cx                      ; dx:ax = reg * ax
                pop     cx
                mov     cl,4
                cmp     cs:data_192,1
                je      short loc_254           ; Jump if equal
                mov     cl,5
loc_254:
                sar     ax,cl                   ; Shift w/sign fill
                add     ax,[si+24h]
                mov     [si+12h],ax
                call    sub_139
                mov     cl,4
                shr     ch,cl                   ; Shift w/zeros fill
                shl     ch,1                    ; Shift w/zeros fill
                add     bl,ch
                and     bl,7Eh                  ; '~'
                mov     [si+26h],bx

loc_ret_255:
                retn
sub_56          endp

                db      90h
data_411        dw      offset sub_62           ; Data table (indexed access)
data_412        dw      offset sub_64
data_413        dw      offset sub_66
data_414        dw      offset sub_68
data_415        dw      offset sub_61
data_416        dw      offset sub_63
data_417        dw      offset sub_65
data_418        dw      offset sub_67

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_61          proc    near
                and     ax,7Fh

;==== External Entry into Subroutine ======================================

sub_62:
                test    ax,80h
                jz      short loc_256           ; Jump if zero
                mov     ax,0
loc_256:
                mov     bx,ax
                mov     ax,cs:data_231[bx]
                retn
sub_61          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_63          proc    near
                and     ax,7Fh

;==== External Entry into Subroutine ======================================

sub_64:
                test    ax,80h
                jz      short loc_257           ; Jump if zero
                mov     ax,0
loc_257:
                mov     bx,ax
                mov     ax,cs:data_234[bx]
                retn
sub_63          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_65          proc    near
                and     ax,7Fh

;==== External Entry into Subroutine ======================================

sub_66:
                test    ax,80h
                jz      short loc_258           ; Jump if zero
                mov     ax,0
loc_258:
                mov     bx,ax
                mov     ax,cs:data_232[bx]
                retn
sub_65          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_67          proc    near
                and     ax,7Fh

;==== External Entry into Subroutine ======================================

sub_68:
                test    ax,80h
                jz      short loc_259           ; Jump if zero
                mov     ax,0
loc_259:
                push    dx
                mov     bx,ax
                mov     ax,cs:data_231[bx]
                mov     dx,cs:data_283
                and     dx,1Eh
                add     bx,dx
                pop     dx
                retn
sub_67          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_69          proc    near
                cmp     al,0
                jne     short loc_260           ; Jump if not equal
                mov     al,[si+39h]
                mov     [si+36h],al
loc_260:
                test    al,0F0h
                jnz     short loc_261           ; Jump if not zero
                mov     ah,[si+39h]
                and     al,0Fh
                and     ah,0F0h
                or      al,ah
loc_261:
                mov     [si+39h],al
                mov     [si+36h],al
                cmp     byte ptr [si+2Ah],0
                je      short loc_ret_264       ; Jump if equal
                mov     cl,al
                mov     ch,al
                and     cl,0Fh
                mov     ax,[si+26h]
                mov     bx,[si+3Dh]
                shr     bl,1                    ; Shift w/zeros fill
                shr     bl,1                    ; Shift w/zeros fill
                shr     bl,1                    ; Shift w/zeros fill
                shr     bl,1                    ; Shift w/zeros fill
                and     bx,0Eh
                call    word ptr cs:data_411[bx] ;*8 entries
                push    cx
                xor     ch,ch                   ; Zero register
                imul    cx                      ; dx:ax = reg * ax
                pop     cx
                mov     cl,7
                sar     ax,cl                   ; Shift w/sign fill
                mov     dl,[si+2Ah]
                xor     dh,dh                   ; Zero register
                add     ax,dx
                cmp     ax,40h
                jl      short loc_262           ; Jump if <
                mov     ax,3Fh
loc_262:
                cmp     ax,0
                jge     short loc_263           ; Jump if > or =
                mov     ax,0
loc_263:
                mov     [si+1Ah],al
                and     ch,0F0h
                mov     cl,3
                shr     ch,cl                   ; Shift w/zeros fill
                add     bl,ch
                and     bl,7Eh                  ; '~'
                mov     [si+26h],bx
                call    sub_140

loc_ret_264:
                retn
sub_69          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_70          proc    near
                mov     al,[si+2Fh]
                cmp     al,0
                je      short loc_265           ; Jump if equal
                dec     al
                mov     [si+2Fh],al
                retn
loc_265:
                mov     al,[si+2Dh]
                cmp     al,1
                je      short loc_266           ; Jump if equal
                mov     byte ptr [si+2Dh],1
                mov     al,[si+2Ah]
                mov     [si+1Ah],al
                call    sub_140
                mov     al,[si+36h]
                xor     ah,ah                   ; Zero register
                shr     al,1                    ; Shift w/zeros fill
                shr     al,1                    ; Shift w/zeros fill
                shr     al,1                    ; Shift w/zeros fill
                shr     al,1                    ; Shift w/zeros fill
                mov     [si+2Fh],al
                retn
loc_266:
                mov     byte ptr [si+2Dh],0
                mov     ax,0
                mov     [si+1Ah],al
                call    sub_140
                mov     al,[si+36h]
                and     al,0Fh
                mov     [si+2Fh],al
                retn
sub_70          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_71          proc    near
                cmp     al,0
                jne     short loc_267           ; Jump if not equal
                mov     al,[si+39h]
                mov     [si+36h],al
loc_267:
                mov     ax,data_279
                mov     cl,3
                div     cl                      ; al, ah rem = ax/reg
                xor     al,al                   ; Zero register
                cmp     ah,1
                je      short loc_268           ; Jump if equal
                cmp     ah,2
                jne     short loc_269           ; Jump if not equal
                mov     al,[si+36h]
                and     al,0Fh
                jmp     short loc_269
loc_268:
                mov     al,[si+36h]
                mov     cl,4
                shr     al,cl                   ; Shift w/zeros fill
loc_269:
                mov     bl,[si+38h]
                mov     bh,bl
                and     bl,0F0h
                and     bh,0Fh
                add     bh,al
                cmp     bh,0Ch
                jb      short loc_270           ; Jump if below
                sub     bh,0Ch
                add     bl,10h
loc_270:
                or      bl,bh
                mov     al,bl
                call    sub_141
                call    sub_137
                mov     [si+12h],ax
                call    sub_139
                retn
sub_71          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_72          proc    near
                mov     ah,al
                xor     al,al                   ; Zero register
                mov     dx,[si+48h]
                cmp     dx,0
                je      short loc_272           ; Jump if equal
loc_271:
                cmp     ax,dx
                jb      short loc_272           ; Jump if below
                sub     ax,dx
                add     ax,[si+4Ch]
                jmp     short loc_271
loc_272:
                mov     cs:[si+44h],ax
                mov     dword ptr cs:[si+5Ch],0FFFFFFFFh
                call    sub_139
                retn
sub_72          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_73          proc    near
                cmp     al,0
                jne     short loc_273           ; Jump if not equal
                mov     al,[si+39h]
                mov     [si+36h],al
loc_273:
                mov     bl,al
                mov     cl,4
                shr     bl,cl                   ; Shift w/zeros fill
                and     bx,0Fh
                and     al,0Fh
                or      al,al                   ; Zero ?
                jz      short loc_278           ; Jump if zero
                cmp     al,[si+2Eh]
                ja      short loc_278           ; Jump if above
                xor     ax,ax                   ; Zero register
                mov     [si+2Eh],al
                mov     cs:[si+44h],ax
                mov     dword ptr cs:[si+5Ch],0FFFFFFFFh
                mov     al,[si+1Ah]
                mov     ah,data_223[bx]
                cmp     ah,0
                je      short loc_274           ; Jump if equal
                mul     ah                      ; ax = reg * al
                mov     cl,4
                shr     ax,cl                   ; Shift w/zeros fill
                jmp     short loc_275
loc_274:
                add     al,data_221[bx]
loc_275:
                cmp     al,0
                jge     short loc_276           ; Jump if > or =
                mov     al,0
loc_276:
                cmp     al,3Fh                  ; '?'
                jle     short loc_277           ; Jump if < or =
                mov     al,3Fh                  ; '?'
loc_277:
                mov     [si+1Ah],al
                call    sub_140
loc_278:
                inc     byte ptr [si+2Eh]
                retn
sub_73          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_74          proc    near
                mov     data_184,al
                retn
sub_74          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_75          proc    near
                mov     ah,al
                mov     cl,4
                shr     ah,cl                   ; Shift w/zeros fill
                and     al,0Fh
                mov     bl,ah
                xor     bh,bh                   ; Zero register
                shl     bx,1                    ; Shift w/zeros fill
                call    word ptr data_325[bx]   ;*60 entries
                retn
sub_75          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_76          proc    near
                mov     ah,al
                mov     cl,4
                shr     ah,cl                   ; Shift w/zeros fill
                and     al,0Fh
                mov     bl,ah
                xor     bh,bh                   ; Zero register
                shl     bx,1                    ; Shift w/zeros fill
                call    word ptr data_341[bx]   ;*60 entries
                retn
sub_76          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_77          proc    near
                cmp     data_284,0
                jne     short loc_ret_279       ; Jump if not equal
                mov     data_284,al
                retn

;==== External Entry into Subroutine ======================================

sub_78:
                mov     [si+2Eh],al

loc_ret_279:
                retn
sub_77          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_79          proc    near
                cmp     byte ptr [si+2Eh],0
                je      loc_ret_279             ; Jump if equal
                dec     byte ptr [si+2Eh]
                jnz     loc_ret_279             ; Jump if not zero
                xor     eax,eax                 ; Zero register
                mov     [si+50h],eax
                retn
sub_79          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_80          proc    near
                mov     [si+2Eh],al
                retn
sub_80          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_81          proc    near
                cmp     byte ptr [si+2Eh],0
                je      loc_ret_279             ; Jump if equal
                dec     byte ptr [si+2Eh]
                jnz     loc_ret_279             ; Jump if not zero
                call    sub_100
                retn
sub_81          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_82          proc    near
                cmp     al,0
                je      short loc_281           ; Jump if equal
                cmp     al,0Fh
                je      short loc_280           ; Jump if equal
                test    cs:data_194,10h
                jz      short loc_281           ; Jump if zero
loc_280:
                mov     cs:data_295,4
                retn
loc_281:
                mov     cs:data_295,0
                retn
sub_82          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_83          proc    near
                cmp     al,40h                  ; '@'
                ja      short loc_ret_282       ; Jump if above
                call    sub_131

loc_ret_282:
                retn
sub_83          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_84          proc    near
                mov     bl,al
                and     bx,0Fh
                shl     bx,1                    ; Shift w/zeros fill
                mov     bx,data_226[bx]
                mov     ax,[si+12h]
                mul     word ptr [si+22h]       ; ax = data * ax
                call    sub_138
                mov     [si+24h],ax
                mov     [si+12h],ax
                mov     [si+22h],bx
                call    sub_139
                retn
sub_84          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_85          proc    near
                shl     al,1                    ; Shift w/zeros fill
                and     al,0Fh
                mov     ah,cs:[si+3Dh]
                and     ah,0F0h
                or      ah,al
                mov     cs:[si+3Dh],ah
                retn
sub_85          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_86          proc    near
                mov     cl,5
                shl     al,cl                   ; Shift w/zeros fill
                mov     ah,cs:[si+3Dh]
                and     ah,0Fh
                or      ah,al
                mov     cs:[si+3Dh],ah
                retn
sub_86          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_87          proc    near
                cmp     al,7
                ja      loc_ret_282             ; Jump if above
                mov     cs:[si+1Bh],al
                retn
sub_87          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_88          proc    near
                cmp     al,0
                je      short loc_283           ; Jump if equal
                cmp     cs:data_285,0
                jne     loc_ret_282             ; Jump if not equal
                mov     cs:data_285,al
                mov     ax,cs:data_215
                dec     ax
                mov     cs:data_286,ax
                retn
loc_283:
                cmp     cs:data_285,0
                je      loc_ret_282             ; Jump if equal
                dec     cs:data_285
                mov     ax,cs:data_286
                mov     cs:data_215,ax
                retn
sub_88          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_89          proc    near
                mov     cs:data_195,al
                retn
sub_89          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_90          proc    near
                mov     ax,cs
                mov     ds,ax
                inc     cs:data_282
                mov     ax,0CDEFh
                mul     cs:data_283             ; ax = data * ax
                add     dx,1727h
                mov     cs:data_283,dx
                cmp     data_279,0
                jne     short loc_285           ; Jump if not equal
                cmp     data_284,0
                jne     short loc_284           ; Jump if not equal
                call    sub_98
                call    sub_47
                jmp     short loc_286
loc_284:
                call    sub_47
                dec     data_215
                dec     data_284
                jmp     short loc_286
loc_285:
                call    sub_48
loc_286:
                inc     data_279
                mov     ax,cs:data_280
                mov     dx,cs:data_166
                add     cs:data_167,dx
                jnc     short loc_287           ; Jump if carry=0
                dec     ax
loc_287:
                cmp     data_279,ax
                jge     short loc_288           ; Jump if > or =
                retn
loc_288:
                mov     ax,data_215
                inc     ax
                cmp     data_210,0
                jne     short loc_289           ; Jump if not equal
                cmp     ax,40h
                jb      short loc_291           ; Jump if below
loc_289:
                mov     data_181,0FFFFh
                cmp     data_210,0FFh
                jne     short loc_290           ; Jump if not equal
                mov     data_210,0
                mov     data_209,0
                retn
loc_290:
                mov     data_210,0
                call    sub_92
loc_291:
                mov     data_215,ax
                mov     ax,data_213
                cmp     ax,0FFFFh
                je      short loc_292           ; Jump if equal
                dec     ax
loc_292:
                mov     data_187,ax
                mov     ax,data_215
                mov     data_185,ax
                mov     ax,data_216
                mov     data_186,ax
                xor     ax,ax                   ; Zero register
                mov     data_279,ax
                retn
sub_90          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_91          proc    near
                mov     ax,cs
                mov     ds,ax
                mov     data_187,0FFFFh
                cmp     data_279,0
                jne     short loc_293           ; Jump if not equal
                call    sub_47
                jmp     short loc_294
loc_293:
                call    sub_48
loc_294:
                mov     ax,data_279
                inc     ax
                cmp     ax,data_280
                jl      short loc_295           ; Jump if <
                xor     ax,ax                   ; Zero register
loc_295:
                mov     data_279,ax
                retn
sub_91          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_92          proc    near
                push    ds
                mov     ax,cs:data_213
loc_296:
                inc     ax
                mov     cs:data_213,ax
                dec     ax
                mov     ds,cs:data_134
                mov     bx,ax
                add     bx,cs:data_204
                mov     bl,[bx]
                cmp     bl,0FFh
                jne     short loc_299           ; Jump if not equal
                cmp     cs:data_209,2
                jne     short loc_298           ; Jump if not equal
                mov     cs:data_208,0
                mov     ax,0
loc_297:
                pop     ds
                retn
loc_298:
                inc     cs:data_188
                mov     ax,cs:data_214
                mov     ds,cs:data_134
                mov     bx,ax
                add     bx,cs:data_204
                cmp     byte ptr [bx],0FFh
                je      loc_297                 ; Jump if equal
                jmp     short loc_296
loc_299:
                xor     bh,bh                   ; Zero register
                mov     cs:data_216,bx
                shl     bx,1                    ; Shift w/zeros fill
                mov     ds,cs:data_134
                add     bx,cs:data_205
                mov     ax,[bx]
                add     ax,cs:data_134
                mov     cs:data_217,ax
                mov     cs:data_218,0FFFFh
                mov     al,cs:data_211
                xor     ah,ah                   ; Zero register
                mov     cs:data_211,ah
                mov     cs:data_215,ax
                cmp     cs:data_209,2
                jne     short loc_300           ; Jump if not equal
                mov     cs:data_209,1
loc_300:
                pop     ds
                mov     cs:data_282,0
                mov     cs:data_283,0
                retn
sub_92          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_93          proc    near
;*              cmp     cs:data_218,0FFFFh
                db       2Eh, 83h, 3Eh, 46h, 09h,0FFh ;  Fixup - byte match
                jz      short loc_301           ; Jump if zero
                retn
loc_301:
                push    ds
                mov     bx,cs:data_216
                shl     bx,1                    ; Shift w/zeros fill
                mov     ds,cs:data_134
                add     bx,cs:data_205
                mov     ax,[bx]
                add     ax,cs:data_134
                mov     cs:data_217,ax
                cmp     ax,0
                je      short loc_308           ; Jump if equal
                mov     ds,ax
                mov     si,data_20e
                mov     cx,cs:data_215
                jcxz    short loc_307           ; Jump if cx=0

locloop_302:
                lodsb                           ; String [si] to al
                or      al,al                   ; Zero ?
                jz      short loc_306           ; Jump if zero
                test    al,20h                  ; ' '
                jz      short loc_303           ; Jump if zero
                add     si,2
loc_303:
                test    al,40h                  ; '@'
                jz      short loc_304           ; Jump if zero
                inc     si
loc_304:
                test    al,80h
                jz      short loc_305           ; Jump if zero
                add     si,2
loc_305:
                jmp     short locloop_302
loc_306:
                loop    locloop_302             ; Loop if cx > 0

loc_307:
                mov     cs:data_218,si
loc_308:
                pop     ds
                retn
sub_93          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_94          proc    near
                mov     ax,cs:data_215
                mov     cx,0A0h
                mul     cx                      ; dx:ax = reg * ax
                mov     si,ax
                retn
sub_94          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_95          proc    near
                push    ds
                mov     es,cs:data_134
                mov     ax,cs:data_217
                cmp     ax,0
                je      short loc_310           ; Jump if equal
                mov     ds,ax
                mov     si,cs:data_218
loc_309:
                lodsb                           ; String [si] to al
                or      al,al                   ; Zero ?
                jnz     short loc_311           ; Jump if not zero
                mov     cs:data_218,si
loc_310:
                mov     di,0FFFFh
                pop     ds
                retn
loc_311:
                mov     bl,al
                and     bx,1Fh
                add     bx,cs:data_207
                mov     dl,es:[bx]
                test    dl,80h
                jz      short loc_315           ; Jump if zero
                test    al,20h                  ; ' '
                jz      short loc_312           ; Jump if zero
                inc     si
                inc     si
loc_312:
                test    al,40h                  ; '@'
                jz      short loc_313           ; Jump if zero
                inc     si
loc_313:
                test    al,80h
                jz      short loc_314           ; Jump if zero
                inc     si
                inc     si
loc_314:
                jmp     short loc_309
loc_315:
                xor     dh,dh                   ; Zero register
                mov     di,dx
                shl     di,1                    ; Shift w/zeros fill
                mov     bx,cs:data_274[di]
                shr     di,1                    ; Shift w/zeros fill
                mov     ah,al
                test    ah,20h                  ; ' '
                jz      short loc_317           ; Jump if zero
                lodsb                           ; String [si] to al
                mov     cs:[bx+32h],al
                cmp     al,0FFh
                je      short loc_316           ; Jump if equal
                mov     cs:[bx+38h],al
loc_316:
                lodsb                           ; String [si] to al
                mov     cs:[bx+33h],al
                cmp     al,0
                je      short loc_317           ; Jump if equal
                mov     cs:[bx+37h],al
loc_317:
                test    ah,40h                  ; '@'
                jz      short loc_318           ; Jump if zero
                lodsb                           ; String [si] to al
                mov     cs:[bx+34h],al
loc_318:
                test    ah,80h
                jz      short loc_319           ; Jump if zero
                lodsb                           ; String [si] to al
                mov     cs:[bx+35h],al
                lodsb                           ; String [si] to al
                mov     cs:[bx+36h],al
loc_319:
                mov     cs:data_218,si
                mov     si,bx
                pop     ds
                retn
sub_95          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_96          proc    near
                push    ds
                mov     ds,cs:data_127
                shl     di,1                    ; Shift w/zeros fill
                mov     bx,cs:data_274[di]
                shr     di,1                    ; Shift w/zeros fill
                lodsb                           ; String [si] to al
                mov     cs:[bx+32h],al
                cmp     al,0FFh
                je      short loc_320           ; Jump if equal
                mov     cs:[bx+38h],al
loc_320:
                lodsb                           ; String [si] to al
                mov     cs:[bx+33h],al
                cmp     al,0
                je      short loc_321           ; Jump if equal
                mov     cs:[bx+37h],al
loc_321:
                lodsb                           ; String [si] to al
                mov     cs:[bx+34h],al
                lodsb                           ; String [si] to al
                mov     cs:[bx+35h],al
                lodsb                           ; String [si] to al
                mov     cs:[bx+36h],al
                mov     si,bx
                pop     ds
                retn
sub_96          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_97          proc    near
                mov     ax,0FF00h
                mov     si,offset data_267
                mov     cx,30h

locloop_322:
                mov     [si+32h],ah
                mov     [si+34h],ah
                mov     [si+33h],al
                mov     [si+35h],al
                mov     [si+36h],al
                add     si,60h
                loop    locloop_322             ; Loop if cx > 0

                retn
sub_97          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_98          proc    near
                mov     ax,cs
                mov     ds,ax
                call    sub_97
                mov     ax,data_216
                cmp     data_125,0
                je      short loc_326           ; Jump if equal
                cmp     data_126,ax
                jne     short loc_326           ; Jump if not equal
                mov     data_218,0FFFFh
                call    sub_94
                mov     cx,20h
                mov     di,data_207

locloop_323:
                push    cx
                push    di
                push    si
                mov     es,data_134
                mov     al,es:[di]
                test    al,80h
                jnz     short loc_325           ; Jump if not zero
                xor     ah,ah                   ; Zero register
                mov     di,ax
                call    sub_96
                mov     cx,[si+32h]
                mov     dx,[si+34h]
                cmp     cx,0FFh
                jne     short loc_324           ; Jump if not equal
                cmp     dx,0FFh
                jne     short loc_324           ; Jump if not equal
                jmp     short loc_325
loc_324:
                call    sub_99
loc_325:
                pop     si
                pop     di
                pop     cx
                inc     di
                add     si,5
                loop    locloop_323             ; Loop if cx > 0

                jmp     short loc_328
loc_326:
                call    sub_93
loc_327:
                call    sub_95
;*              cmp     di,0FFFFh
                db       83h,0FFh,0FFh          ;  Fixup - byte match
                jz      short loc_328           ; Jump if zero
                call    sub_99
                jmp     short loc_327
loc_328:
                mov     al,1
                retn
sub_98          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_99          proc    near
                mov     ax,cs
                mov     ds,ax
                mov     al,[si+3]
                xor     ah,ah                   ; Zero register
                mov     di,ax
                cmp     di,data_150
                jbe     short loc_329           ; Jump if below or =
                inc     di
                mov     data_150,di
                dec     di
loc_329:
                mov     byte ptr [si+1],1
                mov     ax,[si+35h]
                cmp     al,13h
                jne     short loc_330           ; Jump if not equal
                and     ah,0F0h
                cmp     ah,0D0h
                jne     short loc_330           ; Jump if not equal
                retn

;==== External Entry into Subroutine ======================================

sub_100:
                mov     byte ptr [si+1],81h
loc_330:
                mov     cx,[si+32h]
                mov     dx,[si+34h]
                cmp     ch,65h                  ; 'e'
                jbe     short loc_331           ; Jump if below or =
                xor     ch,ch                   ; Zero register
                mov     ch,0
loc_331:
                cmp     dl,0FFh
                je      short loc_332           ; Jump if equal
                cmp     dl,3Fh                  ; '?'
                jbe     short loc_332           ; Jump if below or =
                mov     dl,3Fh                  ; '?'
loc_332:
                mov     [si+32h],cx
                mov     [si+34h],dx
                mov     al,[si+3]
                xor     ah,ah                   ; Zero register
                cmp     al,0Fh
                ja      short loc_334           ; Jump if above
                cmp     data_136,0
                je      short loc_ret_333       ; Jump if equal
                call    sub_101

loc_ret_333:
                retn
loc_334:
                cmp     al,19h
                ja      short loc_335           ; Jump if above
                mov     di,ax
                sub     di,10h
                mov     ax,data_140
                cmp     ax,0
                je      loc_ret_333             ; Jump if equal
                mov     data_144,0
                mov     data_143,ax
                call    sub_110
                retn
loc_335:
                cmp     al,1Eh
                ja      short loc_336           ; Jump if above
                mov     di,ax
                sub     di,19h
                mov     ax,data_140
                cmp     ax,0
                je      short loc_ret_338       ; Jump if equal
                mov     data_144,0
                mov     data_143,ax
                call    sub_111
                retn
loc_336:
                cmp     al,29h                  ; ')'
                ja      short loc_337           ; Jump if above
                mov     di,ax
                sub     di,20h
                mov     ax,data_141
                cmp     ax,0
                je      loc_ret_333             ; Jump if equal
                mov     data_144,1
                mov     data_143,ax
                call    sub_110
                retn
loc_337:
                cmp     al,2Eh                  ; '.'
                ja      short loc_ret_338       ; Jump if above
                mov     di,ax
                sub     di,29h
                mov     ax,data_141
                cmp     ax,0
                je      short loc_ret_338       ; Jump if equal
                mov     data_144,1
                mov     data_143,ax
                call    sub_111
                retn

loc_ret_338:
                retn
sub_99          endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_101         proc    near
                push    ds
                mov     ax,cs
                mov     ds,ax
                cmp     byte ptr [si+33h],0
                je      loc_346                 ; Jump if equal
                mov     bl,[si+33h]
                mov     [si+37h],bl
                xor     bh,bh                   ; Zero register
                dec     bx
                shl     bx,1                    ; Shift w/zeros fill
                add     bx,data_206
                mov     es,data_134
                mov     ax,es:[bx]
                add     ax,data_134
                mov     es,ax
                cmp     byte ptr es:[0],1       ; (' Scream Tracke')
                je      short loc_339           ; Jump if equal
                mov     byte ptr [si+37h],0
                jmp     short loc_346
                db      90h
loc_339:
                call    sub_40
                mov     ax,es:data_113
                mov     [si+22h],ax
                mov     al,es:data_111
                cmp     al,0
                jge     short loc_340           ; Jump if > or =
                mov     al,0
loc_340:
                cmp     al,3Fh                  ; '?'
                jle     short loc_341           ; Jump if < or =
                mov     al,3Fh                  ; '?'
loc_341:
                mov     [si+1Ah],al
                mov     [si+2Ah],al
                call    sub_140
                xor     ax,ax                   ; Zero register
                cmp     word ptr [si+5Ah],0
                je      short loc_342           ; Jump if equal
                cmp     byte ptr [si+35h],7
                je      short loc_342           ; Jump if equal
loc_342:
                mov     ax,es:data_107
                add     ax,data_134
                mov     [si+5Ah],ax
                mov     ax,word ptr es:data_115
                mov     [si+58h],ax
                mov     ax,es:data_110
                test    es:data_112,1
                jz      short loc_345           ; Jump if zero
                cmp     ax,0
                je      short loc_345           ; Jump if equal
                mov     dx,es:data_109
                mov     [si+4Ch],dx
                sub     dx,ax
                cmp     ax,1F4h
                ja      short loc_344           ; Jump if above
loc_343:
                sub     ax,dx
                cmp     ax,1F4h
                jb      loc_343                 ; Jump if below
                add     ax,dx
loc_344:
                mov     [si+48h],ax
                jmp     short loc_346
loc_345:
                mov     ax,es:data_108
                mov     [si+48h],ax
                mov     ax,0FFFFh
                mov     [si+4Ch],ax
loc_346:
                cmp     byte ptr [si+37h],0
                jne     short loc_347           ; Jump if not equal
                pop     ds
                retn
loc_347:
                cmp     byte ptr [si+32h],0FFh
                je      short loc_353           ; Jump if equal
                cmp     byte ptr cs:[si+32h],0FEh
                jne     short loc_348           ; Jump if not equal
                mov     ax,1
                mov     [si+44h],ax
                xor     ax,ax                   ; Zero register
                mov     [si+42h],ax
                mov     [si+1Ah],al
                call    sub_140
                mov     [si+48h],ax
                mov     ax,0FFFFh
                mov     [si+4Ch],ax
                jmp     short loc_352
loc_348:
                cmp     word ptr [si+24h],0
                je      short loc_349           ; Jump if equal
                cmp     byte ptr [si+35h],7
                je      short loc_350           ; Jump if equal
                mov     byte ptr [si+2],0FFh
loc_349:
                xor     ax,ax                   ; Zero register
                mov     dword ptr [si+5Ch],0FFFFFFFFh
                mov     [si+44h],ax
                mov     [si+42h],ax
loc_350:
                mov     al,[si+32h]
                mov     [si+38h],al
                call    sub_141
                call    sub_137
                cmp     word ptr [si+24h],0
                je      short loc_351           ; Jump if equal
                cmp     byte ptr [si+35h],7
                je      short loc_352           ; Jump if equal
loc_351:
                mov     [si+12h],ax
                call    sub_139
                mov     byte ptr [si+26h],0
loc_352:
                mov     [si+24h],ax
                mov     [si+20h],ax
loc_353:
                mov     al,[si+34h]
                cmp     al,0FFh
                je      short loc_354           ; Jump if equal
                mov     [si+1Ah],al
                call    sub_140
                mov     [si+2Ah],al
loc_354:
                cmp     byte ptr [si+2],0FFh
                jne     short loc_355           ; Jump if not equal
                mov     al,[si+1Ah]
                add     al,10h
                mov     [si+2],al
loc_355:
                pop     ds
                retn
sub_101         endp

                                                ;* No entry point to code
                push    es
                push    cx
                push    bx
                push    ax
                xchg    al,ah
                mov     bx,0B800h
                mov     es,bx
                mov     bl,al
                push    ax
                and     bx,0Fh
                shl     bx,1                    ; Shift w/zeros fill
                shl     bx,1                    ; Shift w/zeros fill
                shl     bx,1                    ; Shift w/zeros fill
                shl     bx,1                    ; Shift w/zeros fill
                push    ax
                mov     ax,bx
                shl     bx,1                    ; Shift w/zeros fill
                shl     bx,1                    ; Shift w/zeros fill
                add     bx,ax
                pop     ax
                xor     ah,ah                   ; Zero register
                shr     al,1                    ; Shift w/zeros fill
                shr     al,1                    ; Shift w/zeros fill
                shr     al,1                    ; Shift w/zeros fill
                shr     al,1                    ; Shift w/zeros fill
                add     bx,ax
                pop     ax
                add     bx,data_498e
                shl     bx,1                    ; Shift w/zeros fill
                mov     es:[bx],ah
                mov     al,9Fh
                mov     es:[bx+1],al
                mov     ax,cs:data_143
                pop     ax
                pop     bx
                pop     cx
                pop     es
                retn

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_102         proc    near
;*              cmp     cs:data_180,0FFFFh
                db       2Eh, 83h, 3Eh,0EFh, 08h,0FFh ;  Fixup - byte match
                jz      short loc_ret_356       ; Jump if zero
                push    bx
                push    ds
                push    ax
                mov     ds,cs:data_134
                mov     bx,cs:data_180
                shl     bx,1                    ; Shift w/zeros fill
                add     bx,cs:data_206
                mov     ax,[bx]
                add     ax,cs:data_134
                mov     ds,ax
                xor     bx,bx                   ; Zero register
                mov     ds:data_3e,bx
                pop     ax
                pop     ds
                pop     bx

loc_ret_356:
                retn
sub_102         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_103         proc    near
                push    bx
                push    ds
                push    ax
                mov     ds,cs:data_134
                mov     bx,cs:data_180
                shl     bx,1                    ; Shift w/zeros fill
                add     bx,cs:data_206
                mov     ax,[bx]
                add     ax,cs:data_134
                mov     ds,ax
                mov     bx,ds:data_493e
                add     bx,2
                mov     ds:data_493e,bx
                mov     ds,cs:data_183
                pop     ax
                mov     [bx-2],ax
                pop     ds
                pop     bx
                retn
sub_103         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_104         proc    near
                push    bx
                mov     bl,ah
                xor     bh,bh                   ; Zero register
                cmp     cs:data_287[bx],al
                je      short loc_358           ; Jump if equal
                mov     cs:data_287[bx],al
                pop     bx
;*              cmp     cs:data_180,0FFFFh
                db       2Eh, 83h, 3Eh,0EFh, 08h,0FFh ;  Fixup - byte match
                jz      short loc_357           ; Jump if zero
                call    sub_103
loc_357:
                push    cx
                push    dx
                push    ax
                mov     dx,cs:data_143
                xchg    al,ah
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                inc     dx
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                mov     al,ah
                out     dx,al                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                in      al,dx                   ; port 1, DMA-1 bas&cnt ch 0
                add     cs:data_147,1
                adc     cs:data_148,0
                pop     ax
                pop     dx
                pop     cx
                retn
loc_358:
                pop     bx
                retn
sub_104         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_105         proc    near
                push    ax
                push    bx
                mov     bx,di
                mov     bh,ah
                mov     ah,0A0h
                add     ah,bl
                call    sub_104
                mov     al,bh
                add     ah,10h
                call    sub_104
                pop     bx
                pop     ax
                retn
sub_105         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_106         proc    near
                cld                             ; Clear direction
                mov     ax,cs
                mov     es,ax
                mov     di,offset data_287
                mov     cx,80h
                mov     ax,0FCFCh
                rep     stosw                   ; Rep when cx >0 Store ax to es:[di]
                mov     ax,cs:data_140
                cmp     ax,0
                je      short loc_359           ; Jump if equal
                mov     cs:data_144,0
                mov     cs:data_143,ax
                call    sub_107
loc_359:
                mov     ax,cs:data_141
                cmp     ax,0
                je      short loc_360           ; Jump if equal
                mov     cs:data_144,1
                mov     cs:data_143,ax
                call    sub_107
loc_360:
                mov     cs:data_149,0
                call    sub_102
                retn
sub_106         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_107         proc    near
                mov     ax,120h
                call    sub_104
                mov     ax,800h
                call    sub_104
                mov     ax,0BD00h
                call    sub_104
                mov     ax,cs
                mov     ds,ax
                mov     cx,9
                xor     di,di                   ; Zero register

locloop_361:
                push    cx
                mov     si,892h
                call    sub_108
                xor     ax,ax                   ; Zero register
                call    sub_105
                inc     di
                pop     cx
                loop    locloop_361             ; Loop if cx > 0

                retn
sub_107         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_108         proc    near
                push    si
                jmp     short loc_362

;==== External Entry into Subroutine ======================================

sub_109:
                push    si
                mov     si,data_3e
loc_362:
                push    di
                mov     bl,cs:data_229[di]
                mov     ah,bl
                add     ah,20h                  ; ' '
                mov     cx,4

locloop_363:
                lodsb                           ; String [si] to al
                call    sub_104
                add     ah,3
                lodsb                           ; String [si] to al
                cmp     di,9
                ja      short loc_364           ; Jump if above
                call    sub_104
loc_364:
                add     ah,1Dh
                loop    locloop_363             ; Loop if cx > 0

                add     ah,40h                  ; '@'
                lodsb                           ; String [si] to al
                call    sub_104
                add     ah,3
                lodsb                           ; String [si] to al
                cmp     di,9
                ja      short loc_365           ; Jump if above
                call    sub_104
loc_365:
                pop     bx
                cmp     bl,9
                jne     short loc_366           ; Jump if not equal
                mov     bl,6
loc_366:
                mov     ah,bl
                add     ah,0C0h
                lodsb                           ; String [si] to al
                cmp     di,9
                ja      short loc_367           ; Jump if above
                call    sub_104
loc_367:
                pop     si
                retn
sub_108         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_110         proc    near
                push    ds
                mov     cs:data_149,1
                mov     bl,cs:[si+33h]
                cmp     bl,0
                je      short loc_372           ; Jump if equal
                mov     byte ptr cs:[si+3Ch],1
                xor     cl,cl                   ; Zero register
                mov     ds,cs:data_134
                cmp     bl,cs:[si+3Ah]
                je      short loc_368           ; Jump if equal
                mov     cl,1
                mov     cs:[si+3Ah],bl
loc_368:
                xor     bh,bh                   ; Zero register
                dec     bx
                shl     bx,1                    ; Shift w/zeros fill
                add     bx,cs:data_206
                mov     ax,[bx]
                add     ax,cs:data_134
                push    ds
                mov     ds,ax
                cmp     byte ptr ds:data_18e,2
                je      short loc_369           ; Jump if equal
                mov     byte ptr cs:[si+3Ah],0
                add     sp,2
                pop     ds
                retn
loc_369:
                mov     ax,ds:data_5e
                cmp     ax,3E7h
                ja      short loc_370           ; Jump if above
                mov     ax,20ABh
loc_370:
                mov     cs:[si+22h],ax
                mov     al,ds:data_4e
                xor     ah,ah                   ; Zero register
                mov     cs:[si+1Ah],al
                call    sub_140
                cmp     cl,0
                je      short loc_371           ; Jump if equal
                call    sub_109
loc_371:
                pop     ds
loc_372:
                cmp     byte ptr cs:[si+32h],0FFh
                je      short loc_375           ; Jump if equal
                mov     ax,cs
                mov     ds,ax
                cmp     byte ptr cs:[si+35h],7
                je      short loc_373           ; Jump if equal
                cmp     byte ptr cs:[si+32h],0FEh
                je      short loc_373           ; Jump if equal
                mov     byte ptr cs:[si+2],0FFh
                mov     byte ptr [si+3Bh],1
loc_373:
                mov     al,[si+32h]
                mov     [si+38h],al
                call    sub_141
                call    sub_137
                cmp     byte ptr cs:[si+35h],7
                je      short loc_374           ; Jump if equal
                mov     [si+12h],ax
                call    sub_139
loc_374:
                mov     [si+24h],ax
                mov     [si+20h],ax
loc_375:
                cmp     byte ptr cs:[si+34h],0FFh
                je      short loc_377           ; Jump if equal
                mov     al,cs:[si+34h]
                mov     cs:[si+1Ah],al
                cmp     byte ptr cs:[si+1Ah],40h ; '@'
                jb      short loc_376           ; Jump if below
                mov     byte ptr cs:[si+1Ah],3Fh ; '?'
loc_376:
                mov     al,cs:[si+1Ah]
                mov     cs:[si+2Ah],al
                mov     byte ptr cs:[si+3Ch],1
                call    sub_140
loc_377:
                cmp     byte ptr cs:[si+32h],0FFh
                je      short loc_381           ; Jump if equal
                mov     al,cs:[si+32h]
                mov     bh,al
                shr     al,1                    ; Shift w/zeros fill
                shr     al,1                    ; Shift w/zeros fill
                shr     al,1                    ; Shift w/zeros fill
                shr     al,1                    ; Shift w/zeros fill
                mov     bl,0Ch
                mul     bl                      ; ax = reg * al
                and     bh,0Fh
                add     al,bh
                mov     bl,al
                xor     bh,bh                   ; Zero register
                mov     al,cs:data_260[bx]
                add     al,3Ch                  ; '<'
                cmp     al,3Fh                  ; '?'
                jb      short loc_378           ; Jump if below
                mov     al,3Fh                  ; '?'
loc_378:
                mov     cs:data_260[bx],al
                mov     al,cs:data_259[bx]
                cmp     al,28h                  ; '('
                ja      short loc_379           ; Jump if above
                add     al,14h
                cmp     al,28h                  ; '('
                jb      short loc_379           ; Jump if below
                mov     al,28h                  ; '('
loc_379:
                mov     cs:data_259[bx],al
                mov     al,cs:data_261[bx]
                cmp     al,28h                  ; '('
                ja      short loc_380           ; Jump if above
                add     al,14h
                cmp     al,28h                  ; '('
                jb      short loc_380           ; Jump if below
                mov     al,28h                  ; '('
loc_380:
                mov     cs:data_261[bx],al
loc_381:
                cmp     byte ptr cs:[si+2],0FFh
                jne     short loc_382           ; Jump if not equal
                mov     al,cs:[si+1Ah]
                add     al,9
                mov     cs:[si+2],al
                mov     cs:data_264,1
loc_382:
                pop     ds
                retn
sub_110         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_111         proc    near
                push    ds
                cmp     byte ptr cs:[si+33h],0
                je      short loc_386           ; Jump if equal
                xor     cl,cl                   ; Zero register
                mov     ds,cs:data_134
                mov     bl,cs:[si+33h]
                cmp     bl,cs:[si+3Ah]
                je      short loc_383           ; Jump if equal
                mov     cl,1
loc_383:
                mov     cs:[si+3Ah],bl
                xor     bh,bh                   ; Zero register
                dec     bx
                shl     bx,1                    ; Shift w/zeros fill
                add     bx,cs:data_206
                mov     ax,[bx]
                add     ax,cs:data_134
                push    ds
                mov     ds,ax
                mov     al,cs:data_230[di]
                cmp     ds:data_18e,al
                je      short loc_384           ; Jump if equal
                mov     byte ptr cs:[si+3Ah],0
                pop     ds
                jmp     short loc_386
loc_384:
                mov     ax,ds:data_5e
                mov     cs:[si+22h],ax
                mov     al,ds:data_4e
                mov     cs:[si+1Ah],al
                call    sub_140
                cmp     cl,0
                je      short loc_385           ; Jump if equal

;==== External Entry into Subroutine ======================================

sub_112:
                add     di,9
                call    sub_109
                sub     di,9
loc_385:
                pop     ds
loc_386:
                cmp     byte ptr cs:[si+3Ah],0
                jne     short loc_387           ; Jump if not equal
                pop     ds
                retn
loc_387:
                cmp     byte ptr cs:[si+32h],0FFh
                je      short loc_390           ; Jump if equal
                mov     ax,cs
                mov     ds,ax
                cmp     byte ptr cs:[si+35h],7
                je      short loc_388           ; Jump if equal
                cmp     byte ptr cs:[si+32h],0FEh
                je      short loc_388           ; Jump if equal
                mov     byte ptr cs:[si+2],0FFh
                mov     byte ptr [si+3Bh],1
loc_388:
                mov     al,[si+32h]
                mov     [si+38h],al
                call    sub_141
                call    sub_137
                cmp     byte ptr cs:[si+35h],7
                je      short loc_389           ; Jump if equal
                mov     [si+12h],ax
                call    sub_139
loc_389:
                mov     [si+24h],ax
                mov     [si+20h],ax
loc_390:
                cmp     byte ptr cs:[si+2],0FFh
                jne     short loc_391           ; Jump if not equal
                mov     al,cs:[si+1Ah]
                add     al,9
                mov     cs:[si+2],al
                mov     cs:data_264,1
loc_391:
                pop     ds
                retn
sub_111         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_113         proc    near
                mov     ax,cs
                mov     ds,ax
                mov     ax,data_140
                cmp     ax,0
                je      short loc_393           ; Jump if equal
                mov     cs:data_144,0
                mov     data_143,ax
                mov     si,cs:data_275
                call    sub_114
                or      al,al                   ; Zero ?
                jz      short loc_392           ; Jump if zero
                mov     ax,0BD00h
                call    sub_104
loc_392:
                mov     si,cs:data_276
                call    sub_115
loc_393:
                mov     ax,data_141
                cmp     ax,0
                je      short loc_ret_395       ; Jump if equal
                mov     cs:data_144,1
                mov     data_143,ax
                mov     si,cs:data_277
                call    sub_114
                or      al,al                   ; Zero ?
                jz      short loc_394           ; Jump if zero
                mov     ax,0BD00h
                call    sub_104
loc_394:
                mov     si,cs:data_278
                call    sub_115

loc_ret_395:
                retn
sub_113         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_114         proc    near
                xor     di,di                   ; Zero register
                mov     cx,9
                mov     al,1
                push    ax
loc_396:
                push    cx
                test    word ptr [si+1Eh],8000h
                jnz     short loc_399           ; Jump if not zero
                mov     dx,[si+1Eh]
                mov     ax,[si+1Ch]
                shl     ax,1                    ; Shift w/zeros fill
                rcl     dx,1                    ; Rotate thru carry
                mov     bh,0
loc_397:
                cmp     dx,0
                jne     short loc_398           ; Jump if not equal
                cmp     ax,0C35h
                jb      short loc_401           ; Jump if below
loc_398:
                inc     bh
                shr     dx,1                    ; Shift w/zeros fill
                rcr     ax,1                    ; Rotate thru carry
                jmp     short loc_397
loc_399:
                jmp     short loc_404
loc_400:
                jmp     loc_410
loc_401:
                shl     bh,1                    ; Shift w/zeros fill
                shl     bh,1                    ; Shift w/zeros fill
                or      bh,20h                  ; ' '
                push    bx
                xor     dh,dh                   ; Zero register
                mov     dl,ah
                mov     ah,al
                xor     al,al                   ; Zero register
                shl     ax,1                    ; Shift w/zeros fill
                rcl     dx,1                    ; Rotate thru carry
                shl     ax,1                    ; Shift w/zeros fill
                rcl     dx,1                    ; Rotate thru carry
                mov     cx,0C35h
                div     cx                      ; ax,dx rem=dx:ax/reg
                add     dx,8000h
                jnc     short loc_402           ; Jump if carry=0
                inc     ax
loc_402:
                pop     bx
                or      ah,bh
                push    ax
                cmp     byte ptr [si+3Bh],0
                je      short loc_403           ; Jump if equal
                and     ah,0DFh
                call    sub_105
loc_403:
                pop     ax
                cmp     byte ptr [si+3Bh],0FEh
                je      short loc_404           ; Jump if equal
                call    sub_105
loc_404:
                or      word ptr [si+1Eh],8000h
                cmp     byte ptr cs:[si+3Ch],0
                je      loc_400                 ; Jump if equal
                int     3                       ; Debug breakpoint
                push    ds
                mov     ds,cs:data_134
                mov     bl,cs:[si+3Ah]
                xor     bh,bh                   ; Zero register
                dec     bx
                shl     bx,1                    ; Shift w/zeros fill
                add     bx,cs:data_206
                mov     ax,[bx]
                add     ax,cs:data_134
                mov     ds,ax
                mov     bh,cs:data_229[di]
                test    byte ptr ds:[1Ah],1
                jz      short loc_407           ; Jump if zero
                mov     al,byte ptr ds:[12h]
                mov     ch,al
                and     ch,0C0h
                and     al,3Fh                  ; '?'
                neg     al
                add     al,3Fh                  ; '?'
                mov     cl,cs:[si+1Ah]
                cmp     cl,3Fh                  ; '?'
                jae     short loc_406           ; Jump if above or =
                cmp     cl,0
                je      short loc_405           ; Jump if equal
                inc     cl
loc_405:
                mul     cl                      ; ax = reg * al
                mov     cl,6
                shr     ax,cl                   ; Shift w/zeros fill
loc_406:
                neg     al
                add     al,3Fh                  ; '?'
                or      al,ch
                mov     ah,40h                  ; '@'
                add     ah,bh
                call    sub_104
loc_407:
                mov     al,byte ptr ds:[13h]
                mov     ch,al
                and     ch,0C0h
                and     al,3Fh                  ; '?'
                neg     al
                add     al,3Fh                  ; '?'
                mov     cl,cs:[si+1Ah]
                cmp     cl,3Fh                  ; '?'
                jae     short loc_409           ; Jump if above or =
                cmp     cl,0
                je      short loc_408           ; Jump if equal
                inc     cl
loc_408:
                mul     cl                      ; ax = reg * al
                mov     cl,6
                shr     ax,cl                   ; Shift w/zeros fill
loc_409:
                neg     al
                add     al,3Fh                  ; '?'
                or      al,ch
                mov     ah,43h                  ; 'C'
                add     ah,bh
                call    sub_104
                pop     ds
loc_410:
                mov     byte ptr [si+3Bh],0
                pop     cx
                add     si,60h
                inc     di
                loop    short locloop_411       ; Loop if cx > 0

                pop     ax
                retn

locloop_411:
                jmp     loc_396
sub_114         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_115         proc    near
                mov     cs:data_298,0
                mov     di,0                    ; (' Scream Tracke')
                mov     cx,5
                push    si
loc_412:
                push    cx
                push    di
                test    word ptr [si+1Eh],8000h
                jnz     short loc_415           ; Jump if not zero
                mov     dx,[si+1Eh]
                mov     ax,[si+1Ch]
                shl     ax,1                    ; Shift w/zeros fill
                rcl     dx,1                    ; Rotate thru carry
                mov     bh,0
loc_413:
                cmp     dx,0
                jne     short loc_414           ; Jump if not equal
                cmp     ax,0C35h
                jb      short loc_416           ; Jump if below
loc_414:
                inc     bh
                shr     dx,1                    ; Shift w/zeros fill
                rcr     ax,1                    ; Rotate thru carry
                jmp     short loc_413
loc_415:
                jmp     short loc_419
                db      0EBh, 56h
loc_416:
                shl     bh,1                    ; Shift w/zeros fill
                shl     bh,1                    ; Shift w/zeros fill
                or      bh,20h                  ; ' '
                push    bx
                xor     dh,dh                   ; Zero register
                mov     dl,ah
                mov     ah,al
                xor     al,al                   ; Zero register
                shl     ax,1                    ; Shift w/zeros fill
                rcl     dx,1                    ; Rotate thru carry
                shl     ax,1                    ; Shift w/zeros fill
                rcl     dx,1                    ; Rotate thru carry
                mov     cx,0C35h
                div     cx                      ; ax,dx rem=dx:ax/reg
                add     dx,8000h
                jnc     short loc_417           ; Jump if carry=0
                inc     ax
loc_417:
                pop     bx
                or      ah,bh
                cmp     byte ptr [si+3Bh],0
                je      short loc_418           ; Jump if equal
                push    di
                shl     di,1                    ; Shift w/zeros fill
                mov     di,cs:data_297[di]
                and     ah,0DFh
                call    sub_105
                pop     di
                or      cs:data_298,20h         ; ' '
                cmp     byte ptr [si+3Bh],0FEh
                je      short loc_418           ; Jump if equal
                mov     al,data_299[di]
                or      cs:data_298,al
loc_418:
                or      word ptr [si+1Eh],8000h
                mov     byte ptr [si+3Bh],0
loc_419:
                pop     di
                pop     cx
                add     si,60h
                inc     di
                loop    short locloop_421       ; Loop if cx > 0

                pop     si
                test    cs:data_298,20h         ; ' '
                jz      short loc_ret_420       ; Jump if zero
                mov     ax,0BD00h
                call    sub_104
                mov     ah,0BDh
                mov     al,cs:data_298
                call    sub_104

loc_ret_420:
                retn

locloop_421:
                jmp     loc_412
sub_115         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_116         proc    near
                pushf                           ; Push flags
                cli                             ; Disable interrupts
                push    dx
                mov     dx,3DAh
                in      al,dx                   ; port 3DAh, CGA/EGA vid status
                mov     dx,3C0h
                mov     al,31h                  ; '1'
                out     dx,al                   ; port 3C0h, EGA attributes
                mov     al,ah
                out     dx,al                   ; port 3C0h, EGA attributes
                pop     dx
                popf                            ; Pop flags
                retn
sub_116         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_117         proc    near
                cli                             ; Disable interrupts
                mov     al,0B6h
                out     43h,al                  ; port 43h, 8253 timer control
                mov     al,0FFh
                out     42h,al                  ; port 42h, 8253 timer 2 spkr
                mov     al,0FFh
                out     42h,al                  ; port 42h, 8253 timer 2 spkr
                mov     ax,0FFFFh
                sti                             ; Enable interrupts
                retn
sub_117         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_118         proc    near
                cli                             ; Disable interrupts
                mov     al,0B6h
                out     43h,al                  ; port 43h, 8253 timer control
                in      al,42h                  ; port 42h, 8253 timer 2 spkr
                mov     ah,al
                in      al,42h                  ; port 42h, 8253 timer 2 spkr
                xchg    al,ah
                sti                             ; Enable interrupts
                retn
sub_118         endp

                                                ;* No entry point to code
                cli                             ; Disable interrupts
                mov     al,0
                out     43h,al                  ; port 43h, 8253 timer control
                                                ;  al = 0, latch timer0 count
                in      al,40h                  ; port 40h, 8253 timer 0 clock
                mov     ah,al
                in      al,40h                  ; port 40h, 8253 timer 0 clock
                xchg    al,ah
                sti                             ; Enable interrupts
                retn

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_119         proc    near
                cli                             ; Disable interrupts
                call    sub_142
                mov     cs:data_212,ax
                push    ax
                pop     ax
                cmp     cs:data_163,7530h
                jb      short loc_422           ; Jump if below
                cmp     cs:data_161,0
                je      short loc_425           ; Jump if equal
loc_422:
                push    ax
                sub     ax,cs:data_162
                cmp     ax,0
                jge     short loc_423           ; Jump if > or =
                add     ax,cs:data_300
loc_423:
                cmp     cs:data_163,0EA60h
                jb      short loc_424           ; Jump if below
                push    ax
                mov     ax,cs:data_163
                mov     cx,cs:data_164
                shr     cx,1                    ; Shift w/zeros fill
                mul     cx                      ; dx:ax = reg * ax
                div     cs:data_164             ; ax,dxrem=dx:ax/data
                mov     cs:data_163,ax
                mov     cs:data_164,cx
                pop     ax
loc_424:
                inc     cs:data_164
                add     cs:data_163,ax
                pop     ax
                mov     cs:data_162,ax
loc_425:
                mov     ax,cs:data_240
                mov     bx,cs:data_239
                mov     dx,cs:data_241
                mov     cs:data_241,ax
                sti                             ; Enable interrupts
                sub     ax,bx
                cmp     ax,0
                jge     short loc_426           ; Jump if > or =
                add     ax,cs:data_300
loc_426:
                cmp     ax,80h
                jl      short loc_428           ; Jump if <
                mov     dx,cs:data_300
                shr     dx,1                    ; Shift w/zeros fill
                shr     dx,1                    ; Shift w/zeros fill
                shr     dx,1                    ; Shift w/zeros fill
                shr     dx,1                    ; Shift w/zeros fill
                neg     dx
                add     dx,cs:data_300
                sub     ax,41h
                and     ax,0FFC0h
                cmp     ax,400h
                jbe     short loc_427           ; Jump if below or =
                mov     ax,400h
loc_427:
                mov     cs:data_242,ax
                mov     cs:data_117,ax
                jmp     short loc_429
loc_428:
                jmp     loc_ret_437
                                                ;* No entry point to code
                mov     cs:data_244,1
                mov     cs:data_242,1
loc_429:
                call    sub_122
                cmp     cs:data_131,0
                jne     short loc_430           ; Jump if not equal
                push    ax
                mov     ah,4
                mov     cs:data_133,ah
                call    sub_116
                pop     ax
loc_430:
                mov     ax,cs:data_242
                cmp     ax,0
                jle     loc_ret_437             ; Jump if < or =
                cmp     ax,cs:data_244
                jl      short loc_431           ; Jump if <
                mov     ax,cs:data_244
loc_431:
                add     ax,41h
                and     ax,0FFC0h
                mov     cs:data_243,ax
                sub     cs:data_242,ax
                sub     cs:data_244,ax
                push    cs:data_239
                push    cs:data_243
                cmp     cs:data_146,1
                je      short loc_432           ; Jump if equal
                call    sub_44
loc_432:
                pop     cx
                pop     di
                cmp     cs:data_131,0
                jne     short loc_433           ; Jump if not equal
                push    ax
                mov     ah,4
                mov     cs:data_133,ah
                call    sub_116
                pop     ax
loc_433:
;*              cmp     cs:data_181,0FFFFh
                db       2Eh, 83h, 3Eh,0F1h, 08h,0FFh ;  Fixup - byte match
                jz      short loc_434           ; Jump if zero
                call    sub_45
                jmp     short loc_434
loc_434:
                cmp     cs:data_244,0
                jg      short loc_ret_437       ; Jump if >
                cmp     cs:data_209,0
                je      short loc_436           ; Jump if equal
                mov     ax,cs:data_174
                add     cs:data_178,ax
                inc     cs:data_198
                call    sub_90
loc_435:
                mov     ax,cs:data_176
                add     cs:data_244,ax
                jmp     loc_430
loc_436:
                call    sub_91
                jmp     short loc_435

loc_ret_437:
                retn
sub_119         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_120         proc    near
                mov     dx,cs:data_168
                or      dx,dx                   ; Zero ?
                jz      short loc_438           ; Jump if zero
                add     cs:data_169,dx
                jc      short loc_438           ; Jump if carry Set
                retn
loc_438:
                mov     cs:data_244,1
                mov     cs:data_242,1
                call    sub_122
                cmp     cs:data_131,0
                jne     short loc_439           ; Jump if not equal
                push    ax
                mov     ah,4
                mov     cs:data_133,ah
                call    sub_116
                pop     ax
loc_439:
                cmp     cs:data_209,0
                je      short loc_441           ; Jump if equal
                mov     ax,cs:data_174
                add     cs:data_178,ax
                inc     cs:data_198
                call    sub_90
loc_440:
                mov     ax,cs:data_176
                add     cs:data_244,ax
                jmp     short loc_ret_442
loc_441:
                call    sub_91
                jmp     short loc_440

loc_ret_442:
                retn
sub_120         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_121         proc    near
                cli                             ; Disable interrupts
                cmp     cs:data_263,0
                je      short loc_443           ; Jump if equal
                retn
loc_443:
                inc     cs:data_263
                sti                             ; Enable interrupts
                push    eax
                push    ebx
                push    ecx
                push    edx
                push    esi
                push    edi
                push    ebp
                push    ds
                push    es
                push    fs
                push    gs
                cmp     cs:data_146,1
                je      short loc_444           ; Jump if equal
                cmp     cs:data_132,0
                je      short loc_444           ; Jump if equal
                call    sub_143
loc_444:
                call    sub_117
                push    ax
                in      al,21h                  ; port 21h, 8259-1 int IMR
                push    ax
                or      al,2
                out     21h,al                  ; port 21h, 8259-1 int comands
                cmp     cs:data_131,0
                jne     short loc_445           ; Jump if not equal
                push    ax
                mov     ah,1
                mov     cs:data_133,ah
                call    sub_116
                pop     ax
loc_445:
                cld                             ; Clear direction
                inc     word ptr cs:[90Eh]
                mov     cs:data_178,0
                cmp     cs:data_208,0
                je      short loc_447           ; Jump if equal
                cmp     cs:data_146,1
                je      short loc_446           ; Jump if equal
                call    sub_126
                call    sub_119
                call    sub_127
                jmp     short loc_447
loc_446:
                call    sub_120
loc_447:
                cmp     cs:data_131,0
                jne     short loc_448           ; Jump if not equal
                push    ax
                mov     ah,1
                mov     cs:data_133,ah
                call    sub_116
                pop     ax
loc_448:
                call    sub_128
                call    sub_135
;*              cmp     cs:data_180,0FFFFh
                db       2Eh, 83h, 3Eh,0EFh, 08h,0FFh ;  Fixup - byte match
                jz      short loc_449           ; Jump if zero
                xor     ax,ax                   ; Zero register
                call    sub_103
loc_449:
                cmp     cs:data_131,0
                jne     short loc_450           ; Jump if not equal
                push    ax
                mov     ah,0
                mov     cs:data_133,ah
                call    sub_116
                pop     ax
loc_450:
                cmp     cs:data_160,0
                jne     short loc_452           ; Jump if not equal
                mov     ax,cs:data_178
                add     cs:data_179,ax
                jnc     short loc_452           ; Jump if carry=0
                mov     cx,cs:data_175

locloop_451:
                pushf                           ; Push flags
                call    dword ptr cs:data_200
                loop    locloop_451             ; Loop if cx > 0

                sti                             ; Enable interrupts
                jmp     short loc_452
loc_452:
                pop     ax
                out     21h,al                  ; port 21h, 8259-1 int comands
                call    sub_118
                pop     bx
                sub     bx,ax
                mov     cs:data_165,bx
                pop     gs
                pop     fs
                pop     es
                pop     ds
                pop     ebp
                pop     edi
                pop     esi
                pop     edx
                pop     ecx
                pop     ebx
                pop     eax
                dec     cs:data_263
                retn
sub_121         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_122         proc    near
                mov     ds,cs:data_134
                mov     cs:data_196,0
                mov     al,ds:data_11e
                cmp     al,cs:data_304
                je      short loc_457           ; Jump if equal
                mov     cs:data_304,al
                test    al,80h
                jz      short loc_455           ; Jump if zero
                cmp     cs:data_136,2
                je      short loc_453           ; Jump if equal
                cmp     cs:data_136,5
                je      short loc_453           ; Jump if equal
                and     al,7Fh
                jmp     short loc_455
loc_453:
                and     ax,7Fh
                mov     bx,0Bh
                mul     bx                      ; dx:ax = reg * ax
                shr     ax,1                    ; Shift w/zeros fill
                shr     ax,1                    ; Shift w/zeros fill
                shr     ax,1                    ; Shift w/zeros fill
                sub     ax,2
                cmp     ax,7Fh
                jbe     short loc_454           ; Jump if below or =
                mov     ax,7Fh
loc_454:
                or      al,80h
                mov     cs:data_196,1
loc_455:
                mov     cs:data_193,al
                mov     dx,cs:data_170
                test    al,80h
                jz      short loc_456           ; Jump if zero
                mov     dx,cs:data_171
loc_456:
                mov     cs:data_172,dx
                push    ds
                call    sub_129
                call    sub_32
                call    sub_132
                pop     ds
loc_457:
                mov     al,ds:data_10e
                cmp     al,cs:data_306
                je      short loc_458           ; Jump if equal
                mov     cs:data_306,al
                call    sub_50
loc_458:
                mov     al,ds:data_9e
                cmp     al,cs:data_307
                je      short loc_459           ; Jump if equal
                mov     cs:data_307,al
                call    sub_51
loc_459:
                mov     al,ds:data_8e
                cmp     al,cs:data_305
                je      short loc_460           ; Jump if equal
                mov     cs:data_305,al
                call    sub_130
                call    sub_132
loc_460:
                mov     ax,data_114
                cmp     ax,cs:data_303
                je      short loc_ret_461       ; Jump if equal
                mov     cs:data_303,ax
                call    sub_123

loc_ret_461:
                retn
sub_122         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_123         proc    near
                mov     cs:data_194,ax
                mov     cx,7FFFh
                mov     bx,40h
                test    ax,10h
                jz      short loc_462           ; Jump if zero
                mov     cx,0D60h
                mov     bx,1C5h
loc_462:
                mov     cs:data_219,cx
                mov     cs:data_220,bx
                call    sub_129
                retn
sub_123         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_124         proc    near
                mov     cs:data_304,0
                mov     cs:data_305,0FFh
                mov     cs:data_306,0
                mov     cs:data_307,0FFh
                push    ds
                mov     ds,cs:data_134
                xor     al,al                   ; Zero register
                mov     cs:data_192,al
                mov     ax,ds:data_7e
                test    ax,1
                jz      short loc_463           ; Jump if zero
                mov     cs:data_192,1
loc_463:
                call    sub_122
                pop     ds
                retn
sub_124         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_125         proc    near
                cmp     dx,0F000h
                jb      short loc_ret_464       ; Jump if below
                push    ax
                push    bp
                push    cx
                and     dx,0FFFh
                mov     ah,44h                  ; 'D'
                mov     al,0
                mov     bx,0
                int     67h                     ; EMS Memory        ah=func 44h
                                                ;  map memory, dx=handle
                mov     ah,44h                  ; 'D'
                mov     al,1
                mov     bx,1
                int     67h                     ; EMS Memory        ah=func 44h
                                                ;  map memory, dx=handle
                mov     ah,44h                  ; 'D'
                mov     al,2
                mov     bx,2
                int     67h                     ; EMS Memory        ah=func 44h
                                                ;  map memory, dx=handle
                mov     ah,44h                  ; 'D'
                mov     al,3
                mov     bx,3
                int     67h                     ; EMS Memory        ah=func 44h
                                                ;  map memory, dx=handle
                mov     dx,data_128
                pop     cx
                pop     bp
                pop     ax

loc_ret_464:
                retn
sub_125         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_126         proc    near
                cmp     cs:data_130,0
                jne     short loc_ret_465       ; Jump if not equal
                cmp     cs:data_128,0
                je      short loc_ret_465       ; Jump if equal
                mov     dx,cs:data_129
                mov     ah,47h
                int     67h                     ; EMS Memory        ah=func 47h
                                                ;  save map context, dx=handle

loc_ret_465:
                retn
sub_126         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_127         proc    near
                cmp     cs:data_130,0
                jne     loc_ret_465             ; Jump if not equal
                cmp     cs:data_128,0
                je      loc_ret_465             ; Jump if equal
                mov     dx,cs:data_129
                mov     ah,48h
                int     67h                     ; EMS Memory        ah=func 48h
                                                ;  restore map context,dx=handle
                retn
sub_127         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_128         proc    near
                mov     ax,cs
                mov     ds,ax
                mov     data_264,1
                mov     bx,offset data_267
                mov     cx,30h

locloop_466:
                mov     al,[bx+2]
                cmp     al,0
                jne     short loc_467           ; Jump if not equal
                add     bx,60h
                loop    locloop_466             ; Loop if cx > 0

                retn
loc_467:
                sub     al,2
                jnc     short loc_468           ; Jump if carry=0
                xor     al,al                   ; Zero register
loc_468:
                mov     [bx+2],al
                add     bx,60h
                loop    locloop_466             ; Loop if cx > 0

                retn
sub_128         endp

                                                ;* No entry point to code
                inc     cs:data_236
                cmp     cs:data_131,0
                jne     short loc_469           ; Jump if not equal
                push    ax
                mov     ah,7
                mov     cs:data_133,ah
                call    sub_116
                pop     ax
loc_469:
                mov     cs:data_208,0
                mov     ax,1
                xor     dx,dx                   ; Zero register
                mov     cx,1
                iret                            ; Interrupt return

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_129         proc    near
                test    cs:data_135,1
                jnz     loc_ret_474             ; Jump if not zero
                mov     ax,cs
                mov     ds,ax
                mov     es,word ptr data_245
                mov     si,offset data_225
                test    cs:data_194,10h
                jz      short $+2               ; delay for I/O
                mov     cx,40h
                mov     bx,0                    ; (' Scream Tracke')
                mov     di,data_1e

locloop_470:
                push    cx
                push    bx
                mov     cx,100h
                mov     ax,0
                mov     bl,bh
                xor     bh,bh                   ; Zero register
                mov     bl,[bx+si]

locloop_471:
                push    ax
                mul     bx                      ; dx:ax = reg * ax
                mov     es:[di],ah
                inc     di
                pop     ax
                inc     ax
                loop    locloop_471             ; Loop if cx > 0

                pop     bx
                pop     cx
                add     bx,100h
                loop    locloop_470             ; Loop if cx > 0

                mov     ax,cs
                mov     es,ax
                mov     bl,data_193
                and     bx,7Fh
                cmp     bx,10h
                jae     short loc_472           ; Jump if above or =
                mov     bx,10h
loc_472:
                mov     ax,8000h
                xor     dx,dx                   ; Zero register
                div     bx                      ; ax,dx rem=dx:ax/reg
                push    ax
                mov     cx,ax
                mov     dx,1
                mov     ax,0
                div     cx                      ; ax,dx rem=dx:ax/reg
                mov     si,ax
                neg     cx
                add     cx,800h
                shr     cx,1                    ; Shift w/zeros fill
                mov     di,data_119
                mov     ax,0
                shr     cx,1                    ; Shift w/zeros fill
                rep     stosw                   ; Rep when cx >0 Store ax to es:[di]
                add     cx,cx
                rep     stosb                   ; Rep when cx >0 Store al to es:[di]
                mov     ax,0
                pop     cx

locloop_473:
                mov     [di],ah
                inc     di
                add     ax,si
                loop    locloop_473             ; Loop if cx > 0

                mov     ax,0FFFFh
                mov     cx,data_119
                add     cx,800h
                sub     cx,di
                shr     cx,1                    ; Shift w/zeros fill
                rep     stosw                   ; Rep when cx >0 Store ax to es:[di]
                add     cx,cx
                rep     stosb                   ; Rep when cx >0 Store al to es:[di]

loc_ret_474:
                retn
sub_129         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_130         proc    near
                mov     ds,cs:data_134
                mov     al,ds:data_8e

;==== External Entry into Subroutine ======================================

sub_131:
                xor     ah,ah                   ; Zero register
                mov     cs:data_190,ax
                cmp     al,40h                  ; '@'
                jbe     short loc_475           ; Jump if below or =
                mov     al,40h                  ; '@'
loc_475:
                mov     cx,400h
                mul     cx                      ; dx:ax = reg * ax
                mov     al,ah
                mov     ah,dl
                mov     cs:data_191,ax
                retn
sub_130         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_132         proc    near
                push    ds
                mov     ax,cs
                mov     ds,ax
                mov     cx,data_150
                mov     si,offset data_267

locloop_476:
                cmp     byte ptr [si+1],0
                je      short loc_477           ; Jump if equal
                call    sub_139
                call    sub_140
loc_477:
                add     si,60h
                loop    locloop_476             ; Loop if cx > 0

                pop     ds
                retn
sub_132         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_133         proc    near
                mov     ax,cs
                mov     ds,ax
                mov     cx,30h
                xor     ax,ax                   ; Zero register
                mov     si,offset data_267
                xor     bl,bl                   ; Zero register
                mov     bh,1

locloop_478:
                mov     [si+3],bl
                mov     dword ptr [si+44h],0
                mov     dword ptr [si+5Ch],0FFFFFFFFh
                mov     byte ptr [si+3Fh],0FFh
                mov     [si+58h],ax
                mov     [si+5Ah],ax
                mov     [si+50h],ax
                mov     [si+52h],ax
                mov     [si+48h],ax
                mov     [si+41h],al
                mov     byte ptr [si+1],80h
                mov     [si+33h],al
                mov     [si+32h],al
                mov     [si+34h],al
                mov     [si+35h],al
                mov     [si+36h],al
                mov     [si+38h],al
                mov     [si+1Bh],al
                mov     [si+24h],ax
                mov     [si+2Ah],al
                mov     [si+26h],ax
                mov     [si+39h],al
                mov     [si+2Bh],ax
                mov     [si+20h],ax
                mov     [si+12h],ax
                mov     [si+38h],al
                mov     [si+37h],al
                mov     byte ptr [si+3Ah],65h   ; 'e'
                add     si,60h
                inc     bl
                loop    locloop_478             ; Loop if cx > 0

                mov     data_150,1
                call    sub_106
                call    sub_135
                retn
sub_133         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_134         proc    near
                pushf                           ; Push flags
                push    ds
                cli                             ; Disable interrupts
                mov     ds,cs:data_134
                mov     ax,40h
                mov     cs:data_207,ax
                mov     ax,60h
                mov     cs:data_204,ax
                add     ax,ds:data_5e
                mov     cs:data_206,ax
                add     ax,ds:data_6e
                add     ax,ds:data_6e
                mov     cs:data_205,ax
                mov     ax,cs
                mov     ds,ax
                xor     ax,ax                   ; Zero register
                mov     data_279,0
                mov     data_284,0
                mov     data_286,0
                mov     data_285,0
                mov     data_215,ax
                mov     data_188,ax
                mov     data_216,ax
                mov     data_185,0
                mov     data_211,0
                call    sub_133
                sti                             ; Enable interrupts
                pop     ds
                popf                            ; Pop flags
                retn
sub_134         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_135         proc    near
                mov     ax,cs
                mov     ds,ax
                mov     si,offset data_267
                mov     cx,30h

locloop_479:
                test    byte ptr [si+1],80h
                jz      short loc_480           ; Jump if zero
                and     byte ptr [si+1],7Fh
                push    cx
                push    si
                call    sub_37
                pop     si
                pop     cx
loc_480:
                add     si,60h
                loop    locloop_479             ; Loop if cx > 0

                cmp     cs:data_149,0
                je      short loc_ret_481       ; Jump if equal
                call    sub_113

loc_ret_481:
                retn
sub_135         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_136         proc    near
                push    ax
                mul     word ptr cs:[si+22h]    ; ax = data * ax
                mov     bx,20ABh
                cmp     dx,bx
                jae     short loc_486           ; Jump if above or =
                div     bx                      ; ax,dx rem=dx:ax/reg
                mov     cl,0
                mov     bx,cs:data_228
loc_482:
                cmp     ax,bx
                jae     short loc_483           ; Jump if above or =
                inc     cl
                shr     bx,1                    ; Shift w/zeros fill
                jmp     short loc_482
loc_483:
                mov     bx,0                    ; (' Scream Tracke')
loc_484:
                mov     dx,cs:data_227[bx]
                shr     dx,cl                   ; Shift w/zeros fill
                cmp     ax,dx
                jae     short loc_485           ; Jump if above or =
                add     bx,2
                cmp     bx,16h
                jb      loc_484                 ; Jump if below
                mov     bx,0
                inc     cl
loc_485:
                shr     bx,1                    ; Shift w/zeros fill
                shl     cl,1                    ; Shift w/zeros fill
                shl     cl,1                    ; Shift w/zeros fill
                shl     cl,1                    ; Shift w/zeros fill
                shl     cl,1                    ; Shift w/zeros fill
                and     bl,0Fh
                or      cl,bl
                mov     al,cl
                call    sub_141
                mov     bx,20ABh
                mul     bx                      ; dx:ax = reg * ax
                cmp     dx,cs:[si+22h]
                jae     short loc_486           ; Jump if above or =
                div     word ptr cs:[si+22h]    ; ax,dxrem=dx:ax/data
                add     sp,2
                retn
loc_486:
                pop     ax
                retn
sub_136         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_137         proc    near
                mov     cx,20ABh
                mul     cx                      ; dx:ax = reg * ax

;==== External Entry into Subroutine ======================================

sub_138:
                mov     cx,[si+22h]
                cmp     dx,cx
                jb      short loc_488           ; Jump if below
loc_487:
                mov     ax,7FFFh
                retn
loc_488:
                div     cx                      ; ax,dx rem=dx:ax/reg
                cmp     ax,7FFFh
                ja      loc_487                 ; Jump if above
                retn
sub_137         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_139         proc    near
                push    eax
                push    ebx
                push    ecx
                push    edx
                or      si,si                   ; Zero ?
                js      loc_496                 ; Jump if sign=1
                mov     dx,data_194
                test    dx,10h
                jz      short loc_490           ; Jump if zero
                mov     cx,[si+24h]
                cmp     cx,data_219
                jbe     short loc_489           ; Jump if below or =
                mov     cx,data_219
                mov     [si+24h],cx
loc_489:
                cmp     cx,data_220
                jae     short loc_490           ; Jump if above or =
                mov     cx,data_220
                mov     [si+24h],cx
loc_490:
                mov     cx,[si+12h]
                cmp     cx,data_219
                jbe     short loc_491           ; Jump if below or =
                mov     cx,data_219
                test    dx,10h
                jz      short loc_491           ; Jump if zero
                mov     [si+12h],cx
loc_491:
                cmp     cx,0
                jne     short loc_492           ; Jump if not equal
                xor     ax,ax                   ; Zero register
                mov     byte ptr [si+3Bh],0FEh
                and     word ptr [si+1Eh],7FFFh
                mov     cx,ax
                mov     [si+50h],ax
                mov     [si+52h],cx
                jmp     short loc_496
loc_492:
                cmp     cx,data_220
                jae     short loc_493           ; Jump if above or =
                mov     cx,data_220
                test    dx,10h
                jz      short loc_493           ; Jump if zero
                mov     [si+12h],cx
loc_493:
                cmp     cx,0DAh
                ja      short loc_494           ; Jump if above
                xor     dx,dx                   ; Zero register
                mov     ax,0DAh
                div     cx                      ; ax,dx rem=dx:ax/reg
                push    ax
                mov     ax,7600h
                div     cx                      ; ax,dx rem=dx:ax/reg
                pop     dx
                jmp     short loc_495
loc_494:
                mov     dx,0DAh
                mov     ax,7600h
                div     cx                      ; ax,dx rem=dx:ax/reg
                xor     dx,dx                   ; Zero register
loc_495:
                mov     [si+1Ch],ax
                mov     [si+1Eh],dx
                div     data_172                ; ax,dxrem=dx:ax/data
                mov     cx,ax
                xor     ax,ax                   ; Zero register
                div     data_172                ; ax,dxrem=dx:ax/data
                mov     [si+50h],ax
                mov     [si+52h],cx
loc_496:
                and     si,7FFFh
                or      byte ptr [si+1],80h
                mov     ecx,[si+50h]
                or      ecx,ecx                 ; Zero ?
                jz      short loc_498           ; Jump if zero
                mov     ax,[si+48h]
                sub     ax,[si+44h]
                shl     eax,10h                 ; Shift w/zeros fill
                movzx   edx,word ptr [si+42h]   ; Mov w/zero extend
                sub     eax,edx
                xor     edx,edx                 ; Zero register
                div     ecx                     ; ax,dx rem=dx:ax/reg
                cmp     eax,7FFEh
                jb      short loc_497           ; Jump if below
                mov     ax,7FFEh
loc_497:
                or      ax,1
                inc     ax
                mov     [si+54h],ax
                mov     [si+56h],ax
loc_498:
                inc     byte ptr [si+40h]
                pop     edx
                pop     ecx
                pop     ebx
                pop     eax
                retn
sub_139         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_140         proc    near
                push    ax
                push    dx
                or      byte ptr [si+1],80h
                mov     al,[si+1Ah]
                xor     ah,ah                   ; Zero register
                mul     data_191                ; ax = data * ax
                mov     [si+41h],ah
                pop     dx
                pop     ax
                retn
sub_140         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_141         proc    near
                cmp     al,0FEh
                jne     short loc_499           ; Jump if not equal
                mov     ax,0
                retn
loc_499:
                xor     bh,bh                   ; Zero register
                mov     bl,al
                mov     cl,4
                shr     bl,cl                   ; Shift w/zeros fill
                mov     cl,data_224[bx]
                mov     bl,al
                and     bl,0Fh
                shl     bl,1                    ; Shift w/zeros fill
                mov     ax,data_227[bx]
                shr     ax,cl                   ; Shift w/zeros fill
                retn
sub_141         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_142         proc    near
                call    sub_38
                mov     cs:data_240,ax
                retn
sub_142         endp

                                                ;* No entry point to code
                pushf                           ; Push flags
                cli                             ; Disable interrupts
                mov     bx,cs:data_163
                mov     cx,cs:data_164
                cmp     cs:data_208,0
                je      short loc_500           ; Jump if equal
                cmp     bx,4E20h
                jb      short loc_500           ; Jump if below
                cmp     cx,8
                ja      short loc_501           ; Jump if above
                popf                            ; Pop flags
                retn
loc_500:
                shr     cs:data_154,1           ; Shift w/zeros fill
                shr     cs:data_154,1           ; Shift w/zeros fill
                popf                            ; Pop flags
                retn
loc_501:
                mov     ax,bx
                xor     dx,dx                   ; Zero register
                div     cx                      ; ax,dx rem=dx:ax/reg
                mov     cx,ax
                push    ax
                push    cs:data_240
                push    cx
                call    sub_142
                pop     cx
                mov     dx,cx
                shr     dx,1                    ; Shift w/zeros fill
                shr     dx,1                    ; Shift w/zeros fill
                shr     dx,1                    ; Shift w/zeros fill
                shr     dx,1                    ; Shift w/zeros fill
                shr     dx,1                    ; Shift w/zeros fill
                add     dx,cs:data_162
                cmp     dx,cs:data_300
                jb      short loc_502           ; Jump if below
                sub     dx,cs:data_300
loc_502:
                sub     ax,dx
                cmp     ax,0
                jge     short loc_503           ; Jump if > or =
                add     ax,cs:data_300
loc_503:
                mov     dx,cx
                shr     cx,1                    ; Shift w/zeros fill
                cmp     ax,cx
                jb      short loc_504           ; Jump if below
                sub     ax,dx
loc_504:
                mov     bx,ax
                cmp     ax,0
                jge     short loc_505           ; Jump if > or =
                neg     ax
loc_505:
                mov     word ptr cs:data_155,ax
                cmp     ax,40h
                jb      short loc_506           ; Jump if below
                mov     bx,0FFF0h
loc_506:
                pop     cs:data_240
                mov     ax,cs:data_156
                sar     bx,1                    ; Shift w/sign fill
                mov     cs:data_156,bx
                mov     cs:data_118,bx
                pop     ax
                mov     dx,bx
                sar     bx,1                    ; Shift w/sign fill
                sar     bx,1                    ; Shift w/sign fill
                cmp     bx,0
                je      short loc_509           ; Jump if equal
loc_507:
                sub     ax,bx
                mov     cs:data_154,ax
                popf                            ; Pop flags
                retn
loc_508:
                mov     bx,1
                jmp     short loc_507
loc_509:
                cmp     dx,0
                jg      loc_508                 ; Jump if >
                mov     bx,0FFFFh
                jmp     short loc_508
                db      0BAh,0DAh, 03h
loc_510:
                in      al,dx                   ; port 0, DMA-1 bas&add ch 0
                test    al,8
                jnz     loc_510                 ; Jump if not zero
loc_511:
                in      al,dx                   ; port 0, DMA-1 bas&add ch 0
                test    al,8
                jz      loc_511                 ; Jump if zero
                retn

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_143         proc    near
                mov     dx,3DAh
                mov     bx,4204h
                in      al,dx                   ; port 3DAh, CGA/EGA vid status
                test    al,1
                jnz     short loc_512           ; Jump if not zero
                mov     bx,4074h
loc_512:
                in      al,dx                   ; port 3DAh, CGA/EGA vid status
                test    al,1
                jnz     loc_512                 ; Jump if not zero
                mov     al,36h                  ; '6'
                out     43h,al                  ; port 43h, 8253 timer control
                mov     ax,bx
                out     40h,al                  ; port 40h, 8253 timer 0 clock
                mov     al,ah
                out     40h,al                  ; port 40h, 8253 timer 0 clock
                retn
sub_143         endp

                                                ;* No entry point to code
                jnc     short loc_514           ; Jump if carry=0
                jz      short loc_515           ; Jump if zero
                insw                            ; Port dx to es:[di]
;*              imul    bp,word ptr cs:[2E6Bh],0 ; reg = data * value
                db       2Eh, 69h, 2Eh, 6Bh, 2Eh, 00h ;  Fixup - byte match
                db       00h                    ;  Fixup - byte match
                shl     bx,1                    ; Shift w/zeros fill
                cmp     bx,16h
                jae     short loc_ret_513       ; Jump if above or =
                call    word ptr cs:data_424[bx] ;*11 entries

loc_ret_513:
                retf                            ; Return far
                db       00h, 00h, 00h, 53h, 6Fh
                db      'undBlaster series '
loc_514:
                inc     sp
                dec     bp
loc_515:
                db      'A driver', 0
                db      'Copyright (c) 1992,93 Sami Tammi'
                db      'lehto', 0
                db      90h
data_424        dw      offset sub_152          ; Data table (indexed access)
data_425        dw      offset sub_154
data_426        dw      offset sub_153
data_427        dw      offset sub_151
data_428        dw      offset sub_145
data_429        dw      offset sub_147
data_430        dw      offset sub_148
data_431        dw      offset sub_149
data_432        dw      offset sub_150
data_433        dw      offset sub_146
data_434        dw      offset sub_144
data_435        dw      0
data_436        db      0
data_437        db      0
data_438        db      0
                db      90h
data_439        dw      0
data_440        dw      0
data_441        dw      0                       ; segment storage
data_442        dw      0
data_443        dw      0
data_444        dw      0
data_445        dw      0
data_446        dw      0
data_447        dw      0
data_449        db      0
data_450        db      0
data_451        db      0
data_452        dw      0
data_453        dw      0
data_454        dw      0
data_455        dw      1                       ; Data table (indexed access)
                db       02h, 00h, 04h, 00h, 08h, 00h
                db       10h, 00h, 20h, 00h, 40h, 00h
                db       80h, 00h, 00h, 00h, 00h, 00h
                db       04h
                db      8
data_456        dw      20h                     ; Data table (indexed access)
                db       24h, 00h, 28h, 00h, 2Ch, 00h
                db       30h, 00h, 34h, 00h, 38h, 00h
                db       3Ch, 00h, 00h, 00h, 00h, 00h
                db      0C8h, 01h, 87h,0DBh, 87h,0DBh
                db       87h,0DBh, 90h
                db      16 dup (80h)
                db      10h
                db      'SoundBlaster'
                db       00h, 00h, 00h,0A0h, 0Fh, 08h
                db       52h,0A0h, 0Fh,0E0h
                db      2Eh
                db      8 dup (0)
                db       10h, 02h, 20h, 02h, 30h, 02h
                db       40h, 02h, 50h, 02h, 60h, 02h
                db      0FFh,0FFh, 02h, 00h, 03h, 00h
                db       05h, 00h, 07h, 00h,0FFh,0FFh
                db       01h, 00h, 00h, 00h,0FFh,0FFh
                db      0FEh,0FFh
                db      ' SoundBlaster V2.01'
                db       00h, 00h, 00h,0A0h, 0Fh, 44h
                db      0ACh,0A0h, 0Fh, 44h,0ACh
                db      8 dup (0)
                db       10h, 02h, 20h, 02h, 30h, 02h
                db       40h, 02h, 50h, 02h, 60h, 02h
                db      0FFh,0FFh, 02h, 00h, 03h, 00h
                db       05h, 00h, 07h, 00h,0FFh,0FFh
                db       01h, 00h, 00h, 00h,0FFh,0FFh
                db      0FEh,0FFh
                db      '"SoundBlaster Pro'
                db       00h, 01h, 00h, 00h, 00h,0A0h
                db       0Fh, 44h,0ACh,0A0h, 0Fh, 44h
                db      0ACh,0D0h, 07h, 54h, 56h,0D0h
                db       07h, 54h, 56h, 20h, 02h, 40h
                db       02h,0FFh,0FFh, 02h, 00h, 05h
                db       00h, 07h, 00h, 0Ah, 00h,0FFh
                db      0FFh, 01h, 00h, 03h, 00h, 00h
                db       00h,0FFh,0FFh,0FEh,0FFh, 00h

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_144         proc    near
                retn
sub_144         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_145         proc    near
                mov     cs:data_443,ax
                mov     ax,cx
                shr     ax,1                    ; Shift w/zeros fill
                shr     ax,1                    ; Shift w/zeros fill
                shr     ax,1                    ; Shift w/zeros fill
                shr     ax,1                    ; Shift w/zeros fill
                add     dx,ax
                shl     ax,1                    ; Shift w/zeros fill
                shl     ax,1                    ; Shift w/zeros fill
                shl     ax,1                    ; Shift w/zeros fill
                shl     ax,1                    ; Shift w/zeros fill
                sub     cx,ax
                mov     cs:data_441,dx
                mov     cs:data_442,cx
                retn
sub_145         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_146         proc    near
                xor     ax,ax                   ; Zero register
                cmp     cs:data_439,0
                je      short loc_ret_516       ; Jump if equal
                call    sub_156
                mov     dx,ax
                mov     ax,cs:data_443
                dec     ax
                sub     ax,dx

loc_ret_516:
                retn
sub_146         endp

data_460        db      0

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_147         proc    near
                cmp     cs:data_439,0
                je      short loc_517           ; Jump if equal
                push    ax
                push    dx
                call    sub_148
                pop     dx
                pop     ax
loc_517:
                mov     cs:data_446,0FDE8h
                mov     cs:data_444,dx
                mov     cs:data_460,al
                mov     byte ptr cs:data_440,18h
                test    cs:data_460,1
                jz      short loc_518           ; Jump if zero
                mov     byte ptr cs:data_440,14h
loc_518:
                cmp     cs:data_438,22h         ; '"'
                jne     short loc_520           ; Jump if not equal
                call    sub_168
                mov     ah,0Eh
                call    sub_149
                and     al,0FDh
                test    cs:data_460,2
                jz      short loc_519           ; Jump if zero
                or      al,2
loc_519:
                call    sub_150
loc_520:
                call    sub_167
                mov     si,5E1Fh
                call    sub_159
                mov     al,0D1h
                test    byte ptr cs:data_440,8
                jnz     short loc_521           ; Jump if not zero
                mov     al,0D3h
loc_521:
                call    sub_165
                cmp     cs:data_460,3
                jne     short loc_522           ; Jump if not equal
                mov     al,0A8h
                call    sub_165
                mov     ax,0C37h
                call    sub_150
                mov     ax,0E31h
                call    sub_150
loc_522:
                call    sub_155
                call    sub_157
                mov     cs:data_439,1
                retn
sub_147         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_148         proc    near
                cmp     cs:data_439,0
                je      short loc_ret_523       ; Jump if equal
                call    sub_160
                call    sub_158
                call    sub_167
                mov     al,0D3h
                call    sub_165

loc_ret_523:
                retn
sub_148         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_149         proc    near
                call    sub_164
                retn
sub_149         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_150         proc    near
                call    sub_163
                retn
sub_150         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_151         proc    near
                mov     dx,cs
                mov     cx,5760h
                retn
sub_151         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_152         proc    near
                mov     bx,100h
                mov     dx,cs
                mov     cx,56A0h
                retn
sub_152         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_153         proc    near
                mov     cs:data_438,al
                mov     cs:data_435,dx
                mov     cs:data_436,cl
                mov     cs:data_437,ch
                call    sub_162
                mov     ax,1
                jc      short loc_ret_524       ; Jump if carry Set
                call    sub_161
                mov     ax,2
                jc      short loc_ret_524       ; Jump if carry Set
                xor     ax,ax                   ; Zero register

loc_ret_524:
                retn
sub_153         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_154         proc    near
                mov     cs:data_435,220h
                call    sub_162
                jnc     short loc_525           ; Jump if carry=0
                mov     cs:data_435,240h
                call    sub_162
                jnc     short loc_525           ; Jump if carry=0
                mov     cs:data_435,210h
                call    sub_162
                jnc     short loc_525           ; Jump if carry=0
                mov     cs:data_435,230h
                call    sub_162
                jnc     short loc_525           ; Jump if carry=0
                mov     cs:data_435,250h
                call    sub_162
                jnc     short loc_525           ; Jump if carry=0
                mov     cs:data_435,260h
                call    sub_162
                jnc     short loc_525           ; Jump if carry=0
                xor     ax,ax                   ; Zero register
                retn
loc_525:
                mov     al,0E1h
                call    sub_165
                call    sub_166
                mov     ah,al
                call    sub_166
                cmp     ax,201h
                jae     short loc_526           ; Jump if above or =
                mov     cs:data_438,10h
                jmp     short loc_528
loc_526:
                mov     ah,2Eh                  ; '.'
                call    sub_164
                xor     al,22h                  ; '"'
                mov     bl,al
                call    sub_163
                call    sub_164
                cmp     al,bl
                jne     short loc_527           ; Jump if not equal
                mov     al,bl
                xor     al,22h                  ; '"'
                call    sub_163
                mov     cs:data_438,22h         ; '"'
                jmp     short loc_528
loc_527:
                mov     cs:data_438,20h         ; ' '
loc_528:
                mov     cx,3

locloop_529:
                push    cx
                cmp     cx,3
                jne     short loc_530           ; Jump if not equal
                mov     cs:data_437,1
loc_530:
                cmp     cx,2
                jne     short loc_531           ; Jump if not equal
                mov     cs:data_437,3
loc_531:
                cmp     cx,1
                jne     short loc_532           ; Jump if not equal
                mov     cs:data_437,0
loc_532:
                mov     cs:data_436,7
                call    sub_161
                jnc     short loc_533           ; Jump if carry=0
                mov     cs:data_436,5
                call    sub_161
                jnc     short loc_533           ; Jump if carry=0
                mov     cs:data_436,3
                call    sub_161
                jnc     short loc_533           ; Jump if carry=0
                mov     cs:data_436,2
                call    sub_161
                jnc     short loc_533           ; Jump if carry=0
                mov     cs:data_436,0Ah
                call    sub_161
                jnc     short loc_533           ; Jump if carry=0
                pop     cx
                loop    locloop_529             ; Loop if cx > 0

                xor     cx,cx                   ; Zero register
                mov     dx,cs:data_435
                mov     bx,1
                mov     ax,1
                retn
loc_533:
                pop     cx
                mov     cl,cs:data_436
                mov     ch,cs:data_437
                mov     dx,cs:data_435
                mov     al,cs:data_438
                xor     bx,bx                   ; Zero register
                xor     ah,ah                   ; Zero register
                retn
sub_154         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_155         proc    near
                mov     dx,cs:data_435
                test    byte ptr cs:data_440,4
                jnz     short loc_535           ; Jump if not zero
                mov     al,40h                  ; '@'
                call    sub_165
                mov     dx,0Fh
                mov     ax,4240h
                div     cs:data_444             ; ax,dxrem=dx:ax/data
                neg     al
                push    ax
                call    sub_165
                pop     ax
                cmp     al,0D7h
                ja      short loc_534           ; Jump if above
                mov     al,14h
                mov     byte ptr cs:data_447+1,al
                mov     byte ptr cs:data_447,0
                call    sub_165
                jmp     short loc_537
loc_534:
                mov     al,48h                  ; 'H'
                mov     byte ptr cs:data_447+1,al
                mov     byte ptr cs:data_447,91h
                call    sub_165
                jmp     short loc_537
loc_535:
                mov     al,40h                  ; '@'
                call    sub_165
                mov     dx,0Fh
                mov     ax,4240h
                div     cs:data_444             ; ax,dxrem=dx:ax/data
                neg     al
                push    ax
                call    sub_165
                pop     ax
                cmp     al,0D7h
                ja      short loc_536           ; Jump if above
                mov     al,24h                  ; '$'
                mov     byte ptr cs:data_447+1,al
                mov     byte ptr cs:data_447,0
                call    sub_165
                jmp     short loc_537
loc_536:
                mov     al,48h                  ; 'H'
                mov     byte ptr cs:data_447+1,al
                mov     byte ptr cs:data_447,99h
                call    sub_165
                jmp     short loc_537
loc_537:
                cmp     cs:data_449,0
                jne     short loc_538           ; Jump if not equal
                mov     cs:data_446,0FDE8h
loc_538:
                mov     ax,cs:data_446
                call    sub_165
                mov     al,ah
                call    sub_165
                mov     al,byte ptr cs:data_447
                cmp     al,0
                je      short loc_ret_539       ; Jump if equal
                call    sub_165

loc_ret_539:
                retn
sub_155         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_156         proc    near
                cmp     cs:data_437,1
                je      short loc_541           ; Jump if equal
                cmp     cs:data_437,0
                je      short loc_540           ; Jump if equal
                jmp     short loc_542
loc_540:
                out     0Ch,al                  ; port 0Ch, DMA-1 clr byte ptr
                in      al,1                    ; port 1, DMA-1 bas&cnt ch 0
                mov     ah,al
                in      al,1                    ; port 1, DMA-1 bas&cnt ch 0
                xchg    al,ah
                retn
loc_541:
                out     0Ch,al                  ; port 0Ch, DMA-1 clr byte ptr
                in      al,3                    ; port 3, DMA-1 bas&cnt ch 1
                mov     ah,al
                in      al,3                    ; port 3, DMA-1 bas&cnt ch 1
                xchg    al,ah
                retn
loc_542:
                out     0Ch,al                  ; port 0Ch, DMA-1 clr byte ptr
                in      al,7                    ; port 7, DMA-1 bas&cnt ch 3
                mov     ah,al
                in      al,7                    ; port 7, DMA-1 bas&cnt ch 3
                xchg    al,ah
                retn
sub_156         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_157         proc    near
                cmp     cs:data_437,1
                je      short loc_544           ; Jump if equal
                cmp     cs:data_437,0
                je      short loc_543           ; Jump if equal
                jmp     loc_545
loc_543:
                mov     al,4
                out     0Ah,al                  ; port 0Ah, DMA-1 mask reg bit
                out     0Ch,al                  ; port 0Ch, DMA-1 clr byte ptr
                mov     al,byte ptr cs:data_440
                add     al,40h                  ; '@'
                out     0Bh,al                  ; port 0Bh, DMA-1 mode reg
                mov     dx,cs:data_441
                rol     dx,1                    ; Rotate
                rol     dx,1                    ; Rotate
                rol     dx,1                    ; Rotate
                rol     dx,1                    ; Rotate
                mov     ax,dx
                and     ax,0FFF0h
                and     dx,0Fh
                add     ax,cs:data_442
                adc     dx,0
                out     0,al                    ; port 0, DMA-1 bas&add ch 0
                mov     al,ah
                out     0,al                    ; port 0, DMA-1 bas&add ch 0
                mov     al,dl
                out     87h,al                  ; port 87h, DMA page reg ch 0
                mov     ax,cs:data_443
                dec     ax
                out     1,al                    ; port 1, DMA-1 bas&cnt ch 0
                mov     al,ah
                out     1,al                    ; port 1, DMA-1 bas&cnt ch 0
                mov     al,1
                mov     al,0
                out     0Ah,al                  ; port 0Ah, DMA-1 mask reg bit
                retn
loc_544:
                mov     al,5
                out     0Ah,al                  ; port 0Ah, DMA-1 mask reg bit
                out     0Ch,al                  ; port 0Ch, DMA-1 clr byte ptr
                mov     al,byte ptr cs:data_440
                add     al,41h                  ; 'A'
                out     0Bh,al                  ; port 0Bh, DMA-1 mode reg
                mov     dx,cs:data_441
                rol     dx,1                    ; Rotate
                rol     dx,1                    ; Rotate
                rol     dx,1                    ; Rotate
                rol     dx,1                    ; Rotate
                mov     ax,dx
                and     ax,0FFF0h
                and     dx,0Fh
                add     ax,cs:data_442
                adc     dx,0
                out     2,al                    ; port 2, DMA-1 bas&add ch 1
                mov     al,ah
                out     2,al                    ; port 2, DMA-1 bas&add ch 1
                mov     al,dl
                out     83h,al                  ; port 83h, DMA page reg ch 1
                mov     ax,cs:data_443
                dec     ax
                out     3,al                    ; port 3, DMA-1 bas&cnt ch 1
                mov     al,ah
                out     3,al                    ; port 3, DMA-1 bas&cnt ch 1
                mov     al,1
                out     0Ah,al                  ; port 0Ah, DMA-1 mask reg bit
                retn
loc_545:
                mov     al,7
                out     0Ah,al                  ; port 0Ah, DMA-1 mask reg bit
                out     0Ch,al                  ; port 0Ch, DMA-1 clr byte ptr
                mov     al,byte ptr cs:data_440
                add     al,43h                  ; 'C'
                out     0Bh,al                  ; port 0Bh, DMA-1 mode reg
                mov     dx,cs:data_441
                rol     dx,1                    ; Rotate
                rol     dx,1                    ; Rotate
                rol     dx,1                    ; Rotate
                rol     dx,1                    ; Rotate
                mov     ax,dx
                and     ax,0FFF0h
                and     dx,0Fh
                add     ax,cs:data_442
                adc     dx,0
                out     6,al                    ; port 6, DMA-1 bas&add ch 3
                mov     al,ah
                out     6,al                    ; port 6, DMA-1 bas&add ch 3
                mov     al,dl
                out     82h,al                  ; port 82h, DMA page reg ch 3
                mov     ax,cs:data_443
                dec     ax
                out     7,al                    ; port 7, DMA-1 bas&cnt ch 3
                mov     al,ah
                out     7,al                    ; port 7, DMA-1 bas&cnt ch 3
                mov     al,3
                out     0Ah,al                  ; port 0Ah, DMA-1 mask reg bit
                retn
sub_157         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_158         proc    near
                cmp     cs:data_437,1
                je      short loc_547           ; Jump if equal
                cmp     cs:data_437,0
                je      short loc_546           ; Jump if equal
                jmp     short loc_548
loc_546:
                mov     al,4
                out     0Ah,al                  ; port 0Ah, DMA-1 mask reg bit
                retn
loc_547:
                mov     al,5
                out     0Ah,al                  ; port 0Ah, DMA-1 mask reg bit
                retn
loc_548:
                mov     al,7
                out     0Ah,al                  ; port 0Ah, DMA-1 mask reg bit
                retn
sub_158         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_159         proc    near
                push    es
                cli                             ; Disable interrupts
                in      al,21h                  ; port 21h, 8259-1 int IMR
                mov     cs:data_450,al
                in      al,0A1h                 ; port 0A1h, 8259-2 int IMR
                mov     cs:data_451,al
                mov     bl,cs:data_436
                xor     bh,bh                   ; Zero register
                shl     bx,1                    ; Shift w/zeros fill
                mov     dx,cs:data_456[bx]
                mov     ax,cs:data_455[bx]
                xor     ax,0FFFFh
                and     al,cs:data_450
                and     ah,cs:data_451
                out     21h,al                  ; port 21h, 8259-1 int comands
                mov     al,ah
                out     0A1h,al                 ; port 0A1h, 8259-2 int comands
                mov     bx,dx
                xor     ax,ax                   ; Zero register
                mov     es,ax
                mov     cs:data_454,bx
                mov     ax,es:[bx]
                mov     cs:data_452,ax
                mov     ax,es:[bx+2]
                mov     cs:data_453,ax
                mov     es:[bx],si
                mov     es:[bx+2],cs
                sti                             ; Enable interrupts
                pop     es
                retn
sub_159         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_160         proc    near
                push    es
                cli                             ; Disable interrupts
                mov     al,cs:data_450
                out     21h,al                  ; port 21h, 8259-1 int comands
                mov     al,cs:data_451
                out     0A1h,al                 ; port 0A1h, 8259-2 int comands
                mov     bx,cs:data_454
                xor     ax,ax                   ; Zero register
                mov     es,ax
                mov     ax,cs:data_452
                mov     es:[bx],ax
                mov     ax,cs:data_453
                mov     es:[bx+2],ax
                sti                             ; Enable interrupts
                pop     es
                retn
sub_160         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_161         proc    near
                mov     cs:data_449,1
                mov     cs:data_445,0
                mov     byte ptr cs:data_440,18h
                mov     cs:data_441,cs
                mov     cs:data_442,5750h
                mov     cs:data_443,16h
                mov     cs:data_444,1F40h
                mov     cs:data_446,4
                call    sub_167
                mov     si,5E1Fh
                call    sub_159
                call    sub_157
                call    sub_155
                call    sub_156
                mov     dx,ax
                mov     dx,cs:data_435
                add     dx,0Ch
                mov     cx,4000h

locloop_549:
                cmp     cs:data_445,2
                jae     short loc_551           ; Jump if above or =
                in      al,dx                   ; port 0Ch ??I/O Non-standard
                loop    locloop_549             ; Loop if cx > 0

loc_550:
                call    sub_160
                call    sub_158
                mov     cs:data_449,0
                stc                             ; Set carry flag
                retn
loc_551:
                call    sub_156
                cmp     dx,ax
                je      loc_550                 ; Jump if equal
                call    sub_160
                call    sub_158
                mov     cs:data_449,0
                clc                             ; Clear carry flag
                retn
sub_161         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_162         proc    near
                push    dx
                call    sub_167
                pop     dx
                jc      short loc_552           ; Jump if carry Set
                clc                             ; Clear carry flag
                retn
loc_552:
                stc                             ; Set carry flag
                retn
sub_162         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_163         proc    near
                push    dx
                push    ax
                mov     dx,cs:data_435
                add     dx,4
                xchg    al,ah
                out     dx,al                   ; port 4, DMA-1 bas&add ch 2
                jmp     short $+2               ; delay for I/O
                jmp     short $+2               ; delay for I/O
                xchg    al,ah
                inc     dx
                out     dx,al                   ; port 5, DMA-1 bas&cnt ch 2
                pop     ax
                pop     dx
                retn
sub_163         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_164         proc    near
                push    dx
                mov     dx,cs:data_435
                add     dx,4
                xchg    al,ah
                out     dx,al                   ; port 4, DMA-1 bas&add ch 2
                jmp     short $+2               ; delay for I/O
                jmp     short $+2               ; delay for I/O
                xchg    al,ah
                inc     dx
                in      al,dx                   ; port 5, DMA-1 bas&cnt ch 2
                pop     dx
                retn
sub_164         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_165         proc    near
                push    dx
                push    ax
                push    cx
                mov     dx,cs:data_435
                add     dx,0Ch
                xor     cx,cx                   ; Zero register

locloop_553:
                in      al,dx                   ; port 0Ch ??I/O Non-standard
                or      al,al                   ; Zero ?
                jns     short loc_554           ; Jump if not sign
                loop    locloop_553             ; Loop if cx > 0

                pop     cx
                pop     ax
                pop     dx
                retn
loc_554:
                pop     cx
                pop     ax
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                pop     dx
                retn
sub_165         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_166         proc    near
                push    dx
                push    ax
                push    cx
                mov     dx,cs:data_435
                add     dx,0Eh
                xor     cx,cx                   ; Zero register

locloop_555:
                in      al,dx                   ; port 0Eh ??I/O Non-standard
                or      al,al                   ; Zero ?
                js      short loc_556           ; Jump if sign=1
                loop    locloop_555             ; Loop if cx > 0

                pop     cx
                pop     ax
                xor     al,al                   ; Zero register
                pop     dx
                retn
loc_556:
                pop     cx
                pop     ax
;*              add     dx,0FFFCh
                db       83h,0C2h,0FCh          ;  Fixup - byte match
                in      al,dx                   ; port 0FFFCh ??I/O Non-standard
                pop     dx
                retn
sub_166         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_167         proc    near
                mov     dx,cs:data_435
                add     dx,6
                mov     al,1
                out     dx,al                   ; port 6, DMA-1 bas&add ch 3
                mov     ah,0
loc_557:
                in      al,21h                  ; port 21h, 8259-1 int IMR
                dec     ah
                jnz     loc_557                 ; Jump if not zero
                xor     al,al                   ; Zero register
                out     dx,al                   ; port 6, DMA-1 bas&add ch 3
                call    sub_166
                cmp     al,0AAh
                jne     short loc_558           ; Jump if not equal
                clc                             ; Clear carry flag
                retn
loc_558:
                stc                             ; Set carry flag
                retn
sub_167         endp

data_461        dw      12 dup (0)

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_168         proc    near
                mov     si,5DDEh
                mov     cx,18h
                xor     ah,ah                   ; Zero register

locloop_559:
                call    sub_164
                mov     cs:[si],al
                add     ah,2
                inc     si
                loop    locloop_559             ; Loop if cx > 0

                mov     si,offset data_461
                mov     cx,18h
                xor     ah,ah                   ; Zero register

locloop_560:
                mov     al,cs:[si]
                call    sub_163
                add     ah,2
                inc     si
                loop    locloop_560             ; Loop if cx > 0

                retn
sub_168         endp

                                                ;* No entry point to code
                push    ax
                push    cx
                push    dx
                mov     dx,cs:data_435
                add     dx,0Eh
                in      al,dx                   ; port 0Eh ??I/O Non-standard
                mov     cx,1000h
                mov     dx,cs:data_435
                add     dx,0Ch
                mov     ax,cs:data_447
                cmp     al,0
                je      short locloop_569       ; Jump if equal
                push    ax

locloop_561:
                in      al,dx                   ; port 0Ch ??I/O Non-standard
                or      al,al                   ; Zero ?
                jns     short loc_562           ; Jump if not sign
                loop    locloop_561             ; Loop if cx > 0

loc_562:
                mov     al,ah
                out     dx,al                   ; port 0Ch, DMA-1 clr byte ptr

locloop_563:
                in      al,dx                   ; port 0Ch ??I/O Non-standard
                or      al,al                   ; Zero ?
                jns     short loc_564           ; Jump if not sign
                loop    locloop_563             ; Loop if cx > 0

loc_564:
                mov     ax,cs:data_446
                out     dx,al                   ; port 0Ch, DMA-1 clr byte ptr

locloop_565:
                in      al,dx                   ; port 0Ch ??I/O Non-standard
                or      al,al                   ; Zero ?
                jns     short loc_566           ; Jump if not sign
                loop    locloop_565             ; Loop if cx > 0

loc_566:
                mov     al,ah
                out     dx,al                   ; port 0Ch, DMA-1 clr byte ptr

locloop_567:
                in      al,dx                   ; port 0Ch ??I/O Non-standard
                or      al,al                   ; Zero ?
                jns     short loc_568           ; Jump if not sign
                loop    locloop_567             ; Loop if cx > 0

loc_568:
                pop     ax
                out     dx,al                   ; port 0Ch, DMA-1 clr byte ptr
                jmp     short loc_575

locloop_569:
                in      al,dx                   ; port 0Ch ??I/O Non-standard
                or      al,al                   ; Zero ?
                jns     short loc_570           ; Jump if not sign
                loop    locloop_569             ; Loop if cx > 0

loc_570:
                mov     al,ah
                out     dx,al                   ; port 0Ch, DMA-1 clr byte ptr

locloop_571:
                in      al,dx                   ; port 0Ch ??I/O Non-standard
                or      al,al                   ; Zero ?
                jns     short loc_572           ; Jump if not sign
                loop    locloop_571             ; Loop if cx > 0

loc_572:
                mov     ax,cs:data_446
                out     dx,al                   ; port 0Ch, DMA-1 clr byte ptr

locloop_573:
                in      al,dx                   ; port 0Ch ??I/O Non-standard
                or      al,al                   ; Zero ?
                jns     short loc_574           ; Jump if not sign
                loop    locloop_573             ; Loop if cx > 0

loc_574:
                mov     al,ah
                out     dx,al                   ; port 0Ch, DMA-1 clr byte ptr
loc_575:
                inc     cs:data_445
                mov     al,20h                  ; ' '
                out     20h,al                  ; port 20h, 8259-1 int command
                                                ;  al = 20h, end of interrupt
                pop     dx
                pop     cx
                pop     ax
                iret                            ; Interrupt return
                db      9 dup (0)
                db      0D1h,0E3h, 83h,0FBh, 1Eh, 73h
                db       05h, 2Eh,0FFh, 97h,0F9h, 5Eh
                db      0CBh, 00h, 00h, 00h
                db       47h, 72h
                db      'avis Ultrasound driver', 0
                db      'Copyright (c) 1992,93 Sami Tammi'
                db      'lehto'
                db      0
data_465        dw      0
data_466        dw      0
data_467        dw      0
data_468        dw      0
data_469        dw      0
                db       17h, 5Fh, 20h, 5Fh, 7Bh, 5Fh
                db       17h, 5Fh, 04h, 61h, 09h, 61h
                db       31h, 61h, 17h, 5Fh, 17h, 5Fh
                db       42h, 61h,0FEh, 61h, 3Ch, 64h
                db       47h, 61h, 70h, 61h,0E1h, 5Fh
                db      0BBh, 00h, 01h, 8Ch,0CAh,0B9h
                db      0B0h, 5Eh,0C3h, 2Eh,0C7h, 06h
                db      0EFh, 5Eh, 20h, 02h,0E8h,0BEh
                db       05h, 73h, 3Fh, 2Eh,0C7h, 06h
                db      0EFh, 5Eh, 40h, 02h,0E8h,0B2h
                db       05h, 73h, 33h, 2Eh,0C7h, 06h
                db      0EFh, 5Eh, 60h, 02h,0E8h,0A6h
                db       05h, 73h, 27h, 2Eh,0C7h, 06h
                db      0EFh, 5Eh, 10h, 02h,0E8h, 9Ah
                db       05h, 73h, 1Bh, 2Eh,0C7h, 06h
                db      0EFh, 5Eh, 30h, 02h,0E8h, 8Eh
                db       05h, 73h, 0Fh, 2Eh,0C7h, 06h
                db      0EFh, 5Eh, 50h, 02h,0E8h, 82h
                db       05h, 73h, 03h, 33h,0C0h,0C3h
                db       33h,0C0h, 33h,0DBh, 33h,0C9h
                db       33h,0D2h,0B0h, 10h, 2Eh, 8Bh
                db       16h,0EFh, 5Eh,0C3h, 2Eh, 89h
                db       16h,0EFh, 5Eh,0E8h, 65h, 05h
                db       73h, 04h,0B8h, 01h, 00h,0C3h
loc_576:
                mov     dx,cs:data_465
                mov     ax,dx
                add     ax,103h
                mov     cs:data_467,ax
                mov     ax,dx
                add     ax,104h
                mov     cs:data_468,ax
                mov     ax,dx
                add     ax,105h
                mov     cs:data_469,ax
                mov     ax,dx
                add     ax,102h
                mov     cs:data_466,ax
                mov     dx,cs:data_465
                mov     al,1
                call    sub_169
                call    sub_172
                call    sub_173
                mov     al,0
                call    sub_169
                xor     al,al                   ; Zero register
                call    sub_174
                xor     ax,ax                   ; Zero register
                retn

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_169         proc    near
                mov     bx,ax
                mov     al,3
                test    bl,0FFh
                jz      short loc_577           ; Jump if zero
                mov     al,1
loc_577:
                mov     dx,cs:data_465
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                retn
sub_169         endp

                db      0E8h, 3Bh, 04h,0C3h

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_170         proc    near
                mov     cx,bx
                shr     ebx,10h                 ; Shift w/zeros fill
                push    dx
                mov     dx,cs:data_465
                add     dx,103h
                mov     al,43h                  ; 'C'
                out     dx,al                   ; port 103h, POS-3 option selct
                inc     dx
                mov     ax,cx
                out     dx,ax                   ; port 104h, POS-4 option selct
                dec     dx
                mov     al,44h                  ; 'D'
                out     dx,al                   ; port 103h, POS-3 option selct
                add     dx,2
                mov     al,bl
                out     dx,al                   ; port 105h, POS-5 option selct
                add     dx,2
                in      al,dx                   ; port 107h, POS-7 sub-addr ext
                pop     dx
                retn
sub_170         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_171         proc    near
                mov     cx,bx
                shr     ebx,10h                 ; Shift w/zeros fill
                push    dx
                push    ax
                mov     dx,cs:data_465
                add     dx,103h
                mov     al,43h                  ; 'C'
                out     dx,al                   ; port 103h, POS-3 option selct
                inc     dx
                mov     ax,cx
                out     dx,ax                   ; port 104h, POS-4 option selct
                dec     dx
                mov     al,44h                  ; 'D'
                out     dx,al                   ; port 103h, POS-3 option selct
                add     dx,2
                mov     al,bl
                out     dx,al                   ; port 105h, POS-5 option selct
                add     dx,2
                pop     ax
                out     dx,al                   ; port 107h, POS-7 sub-addr ext
                pop     dx
                retn
sub_171         endp

                                                ;* No entry point to code
                mov     dx,cs:data_467
                mov     al,4Ch                  ; 'L'
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_469
                mov     al,0
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                retn

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_172         proc    near
                mov     dx,cs:data_465
                add     dx,103h
                mov     al,4Ch                  ; 'L'
                out     dx,al                   ; port 103h, POS-3 option selct
                add     dx,2
                mov     al,1
                out     dx,al                   ; port 105h, POS-5 option selct
                push    dx
                mov     dx,300h
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                pop     dx
                push    dx
                mov     dx,300h
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                pop     dx
                sub     dx,2
                mov     al,4Ch                  ; 'L'
                out     dx,al                   ; port 103h, POS-3 option selct
                add     dx,2
                mov     al,7
                out     dx,al                   ; port 105h, POS-5 option selct
                sub     dx,2
                mov     al,0Eh
                out     dx,al                   ; port 103h, POS-3 option selct
                add     dx,2
                mov     al,1Fh
                or      al,0C0h
                out     dx,al                   ; port 105h, POS-5 option selct
                mov     cx,0
loc_578:
                mov     dx,cs:data_465
                add     dx,102h
                mov     al,cl
                out     dx,al                   ; port 102h, POS-2 option selct
                inc     dx
                mov     al,0
                out     dx,al                   ; port 103h, POS-3 option selct
                add     dx,2
                mov     al,3
                out     dx,al                   ; port 105h, POS-5 option selct
                sub     dx,2
                mov     al,0Dh
                out     dx,al                   ; port 103h, POS-3 option selct
                add     dx,2
                mov     al,3
                out     dx,al                   ; port 105h, POS-5 option selct
                inc     cx
                cmp     cx,20h
                jne     loc_578                 ; Jump if not equal
                retn
sub_172         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_173         proc    near
                mov     cx,20h
                xor     al,al                   ; Zero register

locloop_579:
                push    cx
                push    ax
                mov     dx,cs:data_466
                mov     al,al
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_467
                mov     al,0
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_469
                mov     al,3
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_467
                mov     al,0Ch
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_469
                mov     al,7
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_467
                mov     al,0Dh
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_469
                mov     al,3
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                pop     ax
                pop     cx
                inc     al
                loop    locloop_579             ; Loop if cx > 0

                retn
sub_173         endp

data_472        db      0, 0
data_473        dw      0
data_474        dw      0
data_475        dw      0
                db       2Eh,0A3h,0FCh, 60h,0C3h, 50h
                db       2Eh, 89h, 16h,0FEh, 60h, 8Bh
                db      0C2h, 33h,0D2h,0B9h, 46h, 00h
                db      0F7h,0F1h, 2Eh,0A3h, 02h, 61h
                db      0B0h, 00h,0E8h,0AEh,0FEh,0E8h
                db       22h,0FFh,0E8h, 8Fh,0FFh,0B0h
                db       01h,0E8h,0A3h,0FEh, 58h,0E8h
                db       40h, 00h,0C3h,0B0h, 00h,0E8h
                db       99h,0FEh,0E8h, 7Dh,0FFh,0E8h
                db      0F9h,0FEh,0B0h, 01h,0E8h, 8Eh
                db      0FEh,0C3h, 2Eh,0A1h, 00h, 61h
                db      0C3h

locloop_580:
                mov     ax,cs:data_473
loc_581:
                xor     dx,dx                   ; Zero register
                mov     cx,46h
                div     cx                      ; ax,dx rem=dx:ax/reg
                mov     cs:data_475,ax
                mov     ax,cs:data_474
                add     ax,cs:data_475
                cmp     ax,word ptr cs:data_472
                jb      short loc_582           ; Jump if below
                sub     ax,word ptr cs:data_472
loc_582:
                mov     cs:data_474,ax
                retn
                                                ;* No entry point to code
                mov     bx,707h
                test    al,2
                jz      short loc_583           ; Jump if zero
                mov     bx,0E00h
loc_583:
                call    sub_177
                retn
data_476        dw      8000h                   ; Data table (indexed access)
                db       00h, 98h, 00h,0A0h, 00h,0A8h
                db       00h,0B0h, 00h,0B4h, 00h,0B8h
                db       00h,0BCh, 00h,0C0h, 00h,0C2h
                db       00h,0C4h, 00h,0C6h, 00h,0C8h
                db       00h,0CAh, 00h,0CCh, 00h,0CEh
                db       00h,0D0h, 00h,0D1h, 00h,0D2h
                db       00h,0D3h, 00h,0D4h, 00h,0D5h
                db       00h,0D6h, 00h,0D7h, 00h,0D8h
                db       00h,0D9h, 00h,0DAh, 00h,0DBh
                db       00h,0DCh, 00h,0DDh, 00h,0DEh
                db       00h,0DFh, 80h,0E0h, 00h,0E1h
                db       80h,0E1h, 00h,0E2h, 80h,0E2h
                db       00h

locloop_584:
                jcxz    loc_581                 ; Jump if cx=0
                jcxz    short $+2               ; delay for I/O
                in      al,80h                  ; port 80h, POST checkpoint
                in      al,0                    ; port 0, DMA-1 bas&add ch 0
                in      ax,80h                  ; port 80h, POST checkpoint
                in      ax,0                    ; port 0, DMA-1 bas&add ch 0
                out     80h,al                  ; port 80h, POST checkpoint
                out     0,al                    ; port 0, DMA-1 bas&add ch 0
                out     80h,ax                  ; port 80h, POST checkpoint
                out     0,ax                    ; port 0, DMA-1 bas&add ch 0
                call    sub_112
;*              add     cl,ch
                db       00h,0E9h               ;  Fixup - byte match
                sub     cl,0
;*              jmp     far ptr loc_599         ;*
                db      0EAh
                dw      0EA80h, 0EB00h          ;  Fixup - byte match
                                                ;* No entry point to code
                sub     bl,0
                in      al,dx                   ; port 0, DMA-1 bas&add ch 0
                sub     ah,0
                in      ax,dx                   ; port 0, DMA-1 bas&add ch 0
                sub     ch,0
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                sub     dh,0
                out     dx,ax                   ; port 0, DMA-1 bas&add ch 0
                sub     bh,0FFh
                out     dx,ax                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_466
                mov     al,[si+3]
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     eax,[si+5Ch]
                mov     ebx,[si+44h]
                cmp     ebx,eax
                je      loc_588                 ; Jump if equal
                mov     [si+5Ch],ebx
                movzx   ecx,word ptr [si+58h]   ; Mov w/zero extend
                shl     ecx,0Eh                 ; Shift w/zeros fill
;*              cmp     eax,0FFFFFFFFh
                db       66h, 83h,0F8h,0FFh     ;  Fixup - byte match
                jnz     loc_586                 ; Jump if not zero
                mov     dx,cs:data_467
                mov     al,0
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_469
                mov     al,3
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_467
                mov     al,0Dh
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_469
                mov     al,3
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     ebx,[si+48h]
                shl     ebx,9                   ; Shift w/zeros fill
                add     ebx,ecx
                mov     dx,cs:data_467
                mov     al,4
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_468
                mov     eax,ebx
                shr     eax,10h                 ; Shift w/zeros fill
                out     dx,ax                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_467
                mov     al,5
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_468
                mov     ax,bx
                out     dx,ax                   ; port 0, DMA-1 bas&add ch 0
                mov     ebx,[si+4Ch]
;*              cmp     bx,0FFFFh
                db       83h,0FBh,0FFh          ;  Fixup - byte match
                jnz     short loc_585           ; Jump if not zero
                xor     ebx,ebx                 ; Zero register
loc_585:
                shl     ebx,9                   ; Shift w/zeros fill
                add     ebx,ecx
                mov     dx,cs:data_467
                mov     al,2
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_468
                mov     eax,ebx
                shr     eax,10h                 ; Shift w/zeros fill
                out     dx,ax                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_467
                mov     al,3
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_468
                mov     ax,bx
                out     dx,ax                   ; port 0, DMA-1 bas&add ch 0
loc_586:
                mov     ebx,[si+44h]
                shl     ebx,9                   ; Shift w/zeros fill
                add     ebx,ecx
                mov     dx,cs:data_467
                mov     al,0Ah
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_468
                mov     eax,ebx
                shr     eax,10h                 ; Shift w/zeros fill
                out     dx,ax                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_467
                mov     al,0Bh
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_468
                mov     ax,bx
                out     dx,ax                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_467
                mov     al,1
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     eax,[si+50h]
                shr     eax,6                   ; Shift w/zeros fill
                mov     dx,cs:data_468
                mov     ax,ax
                out     dx,ax                   ; port 0, DMA-1 bas&add ch 0
                mov     bl,[si+41h]
                xor     bh,bh                   ; Zero register
                shl     bx,1                    ; Shift w/zeros fill
                mov     dx,cs:data_467
                mov     al,9
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     ax,cs:data_476[bx]
                mov     dx,cs:data_468
                mov     ax,ax
                out     dx,ax                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_467
                mov     al,0
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
;*              cmp     word ptr [si+4Ch],0FFFFh
                db       83h, 7Ch, 4Ch,0FFh     ;  Fixup - byte match
                jz      short loc_587           ; Jump if zero
                mov     dx,cs:data_469
                mov     al,8
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                jmp     short loc_589
loc_587:
                mov     dx,cs:data_469
                mov     al,0
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                jmp     short loc_589
loc_588:
                mov     dx,cs:data_467
                mov     al,1
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     eax,[si+50h]
                shr     eax,6                   ; Shift w/zeros fill
                mov     dx,cs:data_468
                mov     ax,ax
                out     dx,ax                   ; port 0, DMA-1 bas&add ch 0
loc_589:
                mov     bl,[si+41h]
                mov     al,[si+3Fh]
                cmp     bl,al
                je      loc_ret_591             ; Jump if equal
                push    ax
                push    bx
                movzx   bx,al                   ; Mov w/zero extend
                shl     bx,1                    ; Shift w/zeros fill
                mov     dx,cs:data_467
                mov     al,9
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     ax,cs:data_476[bx]
                mov     dx,cs:data_468
                mov     ax,ax
                out     dx,ax                   ; port 0, DMA-1 bas&add ch 0
                pop     bx
                pop     ax
                mov     [si+3Fh],bl
                cmp     al,bl
                jb      short loc_590           ; Jump if below
                mov     dx,cs:data_467
                mov     al,7
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                xor     bh,bh                   ; Zero register
                shl     bx,1                    ; Shift w/zeros fill
                mov     ax,cs:data_476[bx]
                mov     dx,cs:data_469
                mov     al,ah
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     ax,0FFFFh
                mov     dx,cs:data_467
                mov     al,8
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_469
                mov     al,ah
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_467
                mov     al,6
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_469
                mov     al,0Fh
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_467
                mov     al,0Dh
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_469
                mov     al,40h                  ; '@'
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                jmp     short loc_ret_591
loc_590:
                mov     dx,cs:data_467
                mov     al,8
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                xor     bh,bh                   ; Zero register
                shl     bx,1                    ; Shift w/zeros fill
                mov     ax,cs:data_476[bx]
                mov     dx,cs:data_469
                mov     al,ah
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_467
                mov     al,7
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     ax,8000h
                mov     dx,cs:data_469
                mov     al,ah
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_467
                mov     al,6
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_469
                mov     al,0Fh
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_467
                mov     al,0Dh
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_469
                mov     al,0
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0

loc_ret_591:
                retn
data_477        dw      0

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_174         proc    near
                mov     cs:data_477,1
                retn
sub_174         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_175         proc    near
                mov     ax,cs:data_477
                push    ax
                add     cx,1Fh
                shr     cx,5                    ; Shift w/zeros fill
                add     ax,cx
                mov     cs:data_477,ax
                pop     ax
                retn
sub_175         endp

data_478        dw      0
                db       56h, 57h, 1Eh, 06h, 2Eh, 89h
                db       16h, 3Ah, 64h, 26h, 8Bh, 0Eh
                db       10h, 00h, 81h,0F9h, 00h, 02h
                db       73h, 03h,0B9h, 00h, 02h, 83h
                db      0C1h, 10h, 51h,0E8h,0CDh,0FFh
                db       59h, 66h, 0Fh,0B7h,0D8h, 66h
                db      0C1h,0E3h, 05h, 66h, 53h, 26h
                db      0A3h, 28h, 00h, 26h, 8Bh, 16h
                db       0Eh, 00h, 2Eh, 03h, 16h, 3Ah
                db       64h, 81h,0FAh, 00h,0F0h, 72h
                db       03h,0E8h,0ABh,0ECh
loc_592:
                mov     ds,dx
                xor     si,si                   ; Zero register
                pop     ebx
                call    sub_176
                pop     es
                pop     ds
                pop     di
                pop     si
                retn

;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_176         proc    near
                mov     bp,bx
                shr     ebx,10h                 ; Shift w/zeros fill
loc_593:
                mov     dx,cs:data_467
                mov     al,44h                  ; 'D'
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                add     dx,2
                mov     al,bl
                out     dx,al                   ; port 2, DMA-1 bas&add ch 1
                sub     dx,2
                mov     al,43h                  ; 'C'
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                inc     dx
loc_594:
                mov     ax,bp
                out     dx,ax                   ; port 1, DMA-1 bas&cnt ch 0
                lodsb                           ; String [si] to al
                xor     al,80h
                add     dx,3
                out     dx,al                   ; port 4, DMA-1 bas&add ch 2
                sub     dx,3
                dec     cx
                jz      short loc_ret_595       ; Jump if zero
                inc     bp
                jnz     loc_594                 ; Jump if not zero
                inc     bx
                jmp     short loc_593

loc_ret_595:
                retn
sub_176         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_177         proc    near
                mov     cx,10h
                xor     ax,ax                   ; Zero register

locloop_596:
                push    ax
                push    cx
                mov     dx,cs:data_466
                mov     al,al
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_467
                mov     al,0Ch
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                mov     dx,cs:data_469
                mov     al,bl
                out     dx,al                   ; port 0, DMA-1 bas&add ch 0
                pop     cx
                pop     ax
                inc     ax
                cmp     ax,8
                jne     short loc_597           ; Jump if not equal
                mov     bl,bh
loc_597:
                loop    locloop_596             ; Loop if cx > 0

                retn
sub_177         endp


;==========================================================================
;                              SUBROUTINE
;==========================================================================

sub_178         proc    near
                mov     dx,cs:data_465
                add     dx,103h
                mov     al,1
                out     dx,al                   ; port 103h, POS-3 option selct
                in      al,dx                   ; port 103h, POS-3 option selct
                test    al,1
                jz      loc_598                 ; Jump if zero
                mov     al,0
                out     dx,al                   ; port 103h, POS-3 option selct
                in      al,dx                   ; port 103h, POS-3 option selct
                test    al,1
                jnz     loc_598                 ; Jump if not zero
                mov     al,4Ch                  ; 'L'
                out     dx,al                   ; port 103h, POS-3 option selct
                add     dx,2
                mov     al,0
                out     dx,al                   ; port 105h, POS-5 option selct
                push    dx
                mov     dx,300h
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                pop     dx
                push    dx
                mov     dx,300h
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                pop     dx
                sub     dx,2
                mov     al,4Ch                  ; 'L'
                out     dx,al                   ; port 103h, POS-3 option selct
                add     dx,2
                mov     al,1
                out     dx,al                   ; port 105h, POS-5 option selct
                push    dx
                mov     dx,300h
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                pop     dx
                push    dx
                mov     dx,300h
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                in      al,dx                   ; port 300h, POST checkpoint
                pop     dx
                mov     ax,0AAh
                mov     ebx,0
                push    dx
                call    sub_171
                pop     dx
                mov     ax,55h
                mov     ebx,1
                push    dx
                call    sub_171
                pop     dx
                mov     ebx,0
                push    dx
                call    sub_170
                pop     dx
                cmp     al,0AAh
                jne     short loc_598           ; Jump if not equal
                mov     ebx,1
                push    dx
                call    sub_170
                pop     dx
                cmp     al,55h                  ; 'U'
                jne     short loc_598           ; Jump if not equal
                clc                             ; Clear carry flag
                retn
loc_598:
                stc                             ; Set carry flag
                retn
sub_178         endp

                db      8 dup (0)

seg_c           ends


END

