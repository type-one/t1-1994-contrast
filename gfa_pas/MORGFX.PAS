{***********************************************************************
 *     Unit‚ Graphique MORGFX. cod‚e 100% assembleur sous TP 7.0       *
 *     Ne fonctionne qu'en mode 13h (320/200/256 couleurs)             *
 *     Impl‚mentation de l'unit‚ MODE X de Matt PritChard              *
 *     Mettre le MODEX.OBJ dans le directoire de compilation           *
 *     Programmation : Guy De Smet (Morflame), d‚cembre 1993           *
 ***********************************************************************}

{* Pour toutes les applications utilisant cette unit‚, il serait
   honnˆte d'y indiquer un remerciement … Matt PritChard & Guy De Smet *}

unit MorGfx;

interface

uses crt;

type Type_Cadre=(simple,double);
     Pinteger=^integer; { Pour le mode X }
     Pchar=^char;       { Pour le mode X }
     Type_Mode=0..8;

var i,j,k,l:integer;
    FillValue,BorderValue:integer; { Pour la routine Fill_Polygon }
    recursivite:integer;
    Graphic_Mode:Type_Mode;
    XL,YL:200..480; { longueur en x et en y }
    X_MIN,X_MAX,Y_MIN,Y_MAX:integer; { Fenˆtre graphique }
    largeur_font:integer;
    bkg_font:boolean;

const UP=-1;                       { id }
      DOWN=1;
      { Pour le mode X }
      Mode_320x200=0;
      Mode_320x400=1;
      Mode_360x200=2;
      Mode_360x400=3;
      Mode_320x240=4;
      Mode_320x480=5;
      Mode_360x240=6;
      Mode_360x480=7;
      { Pour le mode MCGA standart }
      Mode_13h=8;

function VGACardExists: boolean;
procedure InitVideo(mode:Type_Mode);
procedure Video;
procedure CloseVideo;
procedure FillScreen(color:byte);
procedure Pix(x, y: Word; color: byte);
function  GetPix(x, y: Word):byte;
procedure Old_Fill_Polygon(x,y:word; color,border:byte);
procedure Fill_Quad(x1,y1,x2,y2,x3,y3,x4,y4:word; color_fill,color_line:byte);
procedure Fill_Quad_Asm(a1,b1,a2,b2,a3,b3,a4,b4:integer; color_fill,color_line:byte);
procedure Get_Palette(color : byte; var r,g,b : byte);
          { Not from Morflame (Asphyxia Fill_Quad_asm est le + rapide) }
          Procedure DrawPoly(x1,y1,x2,y2,x3,y3,x4,y4:integer;color:byte;where:word);
{-------------------}
procedure Set_Page(page:byte);
procedure WaitVRT;
procedure WaitHRT;
procedure Line_Asm(x1, y1, x2, y2:word; colour:byte);
procedure Line_Clipping (x0,y0,x1,y1,X_MIN,X_MAX,Y_MIN,Y_MAX:real;
                         value:byte);
procedure Affiche_Char_13(c:char; x,y:word; fgd,bkgd:byte);
procedure OutText(x,y:word; str:string; fgd,bkgd:integer);
procedure Box(x1, y1, x2, y2:word; colour:byte);
procedure Cadre(x1, y1, x2, y2:word; colour:byte; cad:type_cadre);
function SET_VGA_MODEX (mode,MaxXpos,MaxYpos,pages:integer):integer;
function SET_MODEX (mode:integer):integer;
{ BASIC GRAPHICS primitives }
procedure CLEAR_VGA_SCREEN (color:integer);
procedure SET_POINT (Xpos,Ypos,color:integer);
function READ_POINT (Xpos,Ypos:integer):integer;
procedure FILL_BLOCK (Xpos1, Ypos1, Xpos2, Ypos2, color:integer);
procedure DRAW_LINE (Xpos1,Ypos1,Xpos2,Ypos2,color:integer);
{ DAC COLOR REGISTER routines }
procedure SET_DAC_REGISTER(RegNo,Red,Green,Blue:integer);
procedure GET_DAC_REGISTER(RegNO:integer; Red,Green,Blue:Pinteger);
{ PAGE FLIPPING AND SCROLLING routines }
procedure SET_ACTIVE_PAGE(PageNo:integer);
function GET_ACTIVE_PAGE:integer;
procedure SET_DISPLAY_PAGE(PageNo:integer);
function GET_DISPLAY_PAGE:integer;
procedure SET_WINDOW(DisplayPage,XOffset,YOffset:integer);
function GET_X_OFFSET:integer;
function GET_Y_OFFSET:integer;
procedure SYNC_DISPLAY;
{ TEXT DISPLAY routines }
procedure GPRINTC(CharNum,Xpos,Ypos,ColorF,colorB:integer);
procedure TGPRINTC(CharNum,Xpos,Ypos,ColorF:integer);
procedure PRINT_STR(Text:Pchar; Maxlen,Xpos,Ypos,ColorF,ColorB:integer);
procedure TPRINT_STR(Text:Pchar; Maxlen,Xpos,Ypos,ColorF:integer);
procedure SET_DISPLAY_FONT(FontDate:Pchar; FontNumber:integer);
{ BITMAP (SPRITE) DISPLAY routines }
procedure DRAW_BITMAP(Image:Pchar; Xpos,Ypos,Width,Height:integer);
procedure TDRAW_BITMAP(Image:Pchar; Xpos,Ypos,Width,Height:integer);
{ VIDEO MEMORY to VIDEO MEMORY COPY routines }
procedure COPY_PAGE(SourcePage,DestPage:integer);
procedure COPY_BITMAP(SourcePage,X1,Y1,X2,Y2,DestPage,DestX1,DestY1:integer);

implementation
{ Autorise la manipulation du mode X de Michael Abrash et Matt Pritchard }
{$L MODEX.OBJ}
{ MODE X setup routines }
function SET_VGA_MODEX (mode,MaxXpos,MaxYpos,pages:integer):integer;external;
function SET_MODEX (mode:integer):integer;external;
{ BASIC GRAPHICS primitives }
procedure CLEAR_VGA_SCREEN (color:integer);external;
procedure SET_POINT (Xpos,Ypos,color:integer);external;
function READ_POINT (Xpos,Ypos:integer):integer;external;
procedure FILL_BLOCK (Xpos1, Ypos1, Xpos2, Ypos2, color:integer);external;
procedure DRAW_LINE (Xpos1,Ypos1,Xpos2,Ypos2,color:integer);external;
{ DAC COLOR REGISTER routines }
procedure SET_DAC_REGISTER(RegNo,Red,Green,Blue:integer);external;
procedure GET_DAC_REGISTER(RegNO:integer; Red,Green,Blue:Pinteger);external;
{ PAGE FLIPPING AND SCROLLING routines }
procedure SET_ACTIVE_PAGE(PageNo:integer);external;
function GET_ACTIVE_PAGE:integer;external;
procedure SET_DISPLAY_PAGE(PageNo:integer);external;
function GET_DISPLAY_PAGE:integer;external;
procedure SET_WINDOW(DisplayPage,XOffset,YOffset:integer);external;
function GET_X_OFFSET:integer;external;
function GET_Y_OFFSET:integer;external;
procedure SYNC_DISPLAY;external;
{ TEXT DISPLAY routines }
procedure GPRINTC(CharNum,Xpos,Ypos,ColorF,colorB:integer);external;
procedure TGPRINTC(CharNum,Xpos,Ypos,ColorF:integer);external;
procedure PRINT_STR(Text:Pchar; Maxlen,Xpos,Ypos,ColorF,ColorB:integer);external;
procedure TPRINT_STR(Text:Pchar; Maxlen,Xpos,Ypos,ColorF:integer);external;
procedure SET_DISPLAY_FONT(FontDate:Pchar; FontNumber:integer);external;
{ BITMAP (SPRITE) DISPLAY routines }
procedure DRAW_BITMAP(Image:Pchar; Xpos,Ypos,Width,Height:integer);external;
procedure TDRAW_BITMAP(Image:Pchar; Xpos,Ypos,Width,Height:integer);external;
{ VIDEO MEMORY to VIDEO MEMORY COPY routines }
procedure COPY_PAGE(SourcePage,DestPage:integer);external;
procedure COPY_BITMAP(SourcePage,X1,Y1,X2,Y2,DestPage,DestX1,DestY1:integer);external;

{----------------------------------------------------------------------}
function VGACardExists: boolean;
var card: byte;
begin
	asm
	mov             ah, 12h
	xor             al, al
	mov             bl, 32h
	int             10h
	mov             card, al
    end;
    VGACardExists := (card = $12);
end;
{----------------------------------------------------------------------}
procedure Video; assembler;
asm
mov ax,13h
int 10h
end;
{----------------------------------------------------------------------}
procedure CloseVideo; assembler;
asm
mov     ax, 3h
int     10h
end;
{----------------------------------------------------------------------}
procedure FillScreen(color:byte); assembler;
{ remplit l'‚cran avec une couleur donn‚e Programmation : Guy De Smet }
{ trŠs rapide ... }
label boucle;
asm
	   push    es
	   push    cx
	   push    ax
	   mov     ax,0A000h
	   mov     es,ax
	   xor     di,di
	   mov     al,color
	   mov     ah,color
	   mov     cx,32000
	   rep     stosw
	   pop     ax
	   pop     cx
	   pop     es
end;
{----------------------------------------------------------------------}
procedure Pix(x, y: Word; color: byte); assembler;
asm
push    es
mov     ax,0A000h
mov     es,ax
mov     ax,y
mov     bx,x
xchg    ah,al
add     bx,ax
shr     ax,1
shr     ax,1
add     bx,ax
mov     al,color
mov     es:[bx],al
pop     es
end;
{----------------------------------------------------------------------}
function GetPix(x, y: Word):byte;
var i:byte;
begin
asm
push    ds
push    es
mov     ax,0A000h
mov     es,ax
mov     ax,y
mov     bx,x
xchg    ah,al
add     bx,ax
shr     ax,1
shr     ax,1
add     bx,ax
mov     al,es:[bx]
mov     byte ptr i,al
pop     es
pop     ds
end;
GetPix:=i;
end;
{----------------------------------------------------------------------}
procedure Set_Page(page:byte); assembler;
asm
push    es
mov     ah,05h
mov     al,byte ptr[page]
int     10h
mov     ax,40h
mov     es,ax
mov     ax,word ptr es:[4Eh]    { Retourne le d‚part du CRT }
mov     bl,byte ptr es:[62h]    { Retourne la page active }
mov     byte ptr[i],bl
mov     word ptr[j],ax
mov     ax,word ptr es:[63h]
mov     bx,word ptr es:[4Ch]
mov     word ptr k,ax
mov     word ptr l,bx
pop     es
end;
{----------------------------------------------------------------------}
procedure WaitVRT;assembler;
label     VRT,NOVRT;
asm
    mov     dx,3dah
VRT:
    in      al,dx
    test    al,8
    jnz     VRT         { attend que le 'vertical retrace' d‚marre }
NOVRT:
    in      al,dx
    test    al,8
    jz      NOVRT       { attend que le 'vertical retrace' s'arrˆte }
end;
{----------------------------------------------------------------------}
procedure WaitHRT;assembler;
label     HRT,NOHRT;
asm
    mov     dx,3dah
HRT:
    in      al,dx
    test    al,1
    jnz     HRT         { attend que le 'horizontal retrace' d‚marre }
NOHRT:
    in      al,dx
    test    al,1
    jz      NOHRT       { attend que le 'horizontal retrace' s'arrˆte }
end;
{----------------------------------------------------------------------}
procedure Line_Asm(x1, y1, x2, y2:word; colour:byte); assembler;
var incr1,incr2,routine:integer;

label L01,L03,L04,L31,L32,VertLine13,HorizLine13,LoSlopeLine13,HiSlopeLine13;
label L11,L12,L21,L22,L23,Lexit;

const
     BytesPerLine=320;
asm
		push    es
		push    bp
		push    si
		push    di

{ On regarde si elle est verticale }
		mov      si,BytesPerLine
		mov      cx,x2
		sub      cx,x1
		jz       VertLine13

{ Forcer x1<x2 }
		jns      L01            { saut si x2>x1 }
		neg      cx             { cx:=x1-x2 }
		mov      bx,x2          { ‚changer x1 et x2 }
		xchg     bx,x1
		mov      x2,bx
		mov      bx,y2          { ‚changer y1 et y2 }
		xchg     bx,y1
		mov      y2,bx

{ Calculer dy=ABS(y2-y1) }
L01:            mov      bx,y2
		sub      bx,y1          { bx:=y2-y1 }
		jz       HorizLine13    { saut si horizontale }
		jns      L03            { saut si la pente est positive }
		neg      bx             { bx:=y1-y2 }
		neg      si             { inverser l'ordonn‚e }

{ Choisir la routine appropri‚e pour la pente de la ligne }
L03:            push     si             { pr‚server l'ordonn‚e }
		mov      routine,offset LoSlopeLine13
		cmp      bx,cx
		jle      L04            { saut si dy<=dx (pente <=1) }
		mov      routine,offset HiSlopeLine13
		xchg     bx,cx          { ‚changer dy et dx }

{ Calculer la variable initiale de d‚cision et les incr‚ments }
L04:            shl      bx,1
		mov      incr1,bx
		sub      bx,cx
		mov      si,bx
		sub      bx,cx
		mov      incr2,bx       { incr2:=2*(dy-dx) }

{ Calculer la premiŠre adresse du pixel }
		push     cx
		mov      ax,y1
		mov      bx,x1

{ Cette fonction d‚termine l'addresse d'un pixel dans le buffer en mode 13h
  ax=ordonn‚e (0-199)
  bx=abscisse (0-319)
  retourne bx=d‚placement en octets dans le buffer
	   es=segment du buffer video }

		xchg        ah,al       { ax:=256*y }
		add         bx,ax       { bx:=256*y+x }
		shr         ax,1
		shr         ax,1        { ax:=64*y }
		add         bx,ax       { bx:=320*y+x }
		mov         ax,0A000h
		mov         es,ax       { es:bx:=adresse du pixel }

		mov      di,bx
		pop      cx
		inc      cx
		pop      bx
		jmp      routine

{ Routine pour les verticales }
VertLine13:     mov      ax,y1
		mov      bx,y2
		mov      cx,bx
		sub      cx,ax
		jge      L31            { saut si dy>=0 }
		neg      cx             { forcer dy>=0 }
		mov      ax,bx
L31:            inc      cx
		mov      bx,x1
		push     cx

{ Cette fonction d‚termine l'addresse d'un pixel dans le buffer en mode 13h
  ax=ordonn‚e (0-199)
  bx=abscisse (0-319)
  retourne bx=d‚placement en octets dans le buffer
	   es=segment du buffer video }

		xchg        ah,al       { ax:=256*y }
		add         bx,ax       { bx:=256*y+x }
		shr         ax,1
		shr         ax,1        { ax:=64*y }
		add         bx,ax       { bx:=320*y+x }
		mov         ax,0A000h
		mov         es,ax       { es:bx:=adresse du pixel }

		pop      cx
		mov      di,bx
		dec      si
		mov      al,colour

L32:            stosb
		add      di,si
		loop     L32
		jmp      Lexit

{ Routine pour les horizontales (pente=0) }
HorizLine13:    push     cx
		mov      ax,y1
		mov      bx,x1

{ Cette fonction d‚termine l'addresse d'un pixel dans le buffer en mode 13h
  ax=ordonn‚e (0-199)
  bx=abscisse (0-319)
  retourne bx=d‚placement en octets dans le buffer
	   es=segment du buffer video }

		xchg        ah,al       { ax:=256*y }
		add         bx,ax       { bx:=256*y+x }
		shr         ax,1
		shr         ax,1        { ax:=64*y }
		add         bx,ax       { bx:=320*y+x }
		mov         ax,0A000h
		mov         es,ax       { es:bx:=adresse du pixel }

		mov      di,bx
		pop      cx
		inc      cx
		mov      al,colour
		rep      stosb
		jmp      Lexit

{ Routine pour dy<=dx (pente<=1) ES:DI -> buffer video
		BX=ordonn‚e
		CX=nombre de pixels … tracer
		SI=variable de d‚cision }
LoSlopeLine13:  mov      al,colour

L11:            stosb
		or       si,si
		jns      L12
		add      si,incr1
		loop     L11
		jmp      Lexit

L12:            add      si,incr2
		add      di,bx
		loop     L11
		jmp      Lexit

{ Routine pour dy>dx (pente>1) ES:DI -> buffer video
		BX=ordonn‚e
		CX=nombre de pixels … tracer
		SI=variable de d‚cision }

HiSlopeLine13:  mov         al,colour

L21:            stosb
		add         di,bx

L22:            or          si,si
		jns         L23
		add         si,incr1
		dec         di
		loop        L21
		jmp         Lexit

L23:            add         si,incr2
		loop        L21

Lexit:          pop         di
		pop         si
		pop         bp
		pop         es
end;
{----------------------------------------------------------------------}
procedure Affiche_Char_13(c:char; x,y:word; fgd,bkgd:byte);assembler;
{ Affiche un caractŠre dans le mode graphique 13h. TrŠs rapide...
  Code du livre 'Programmation des cartes graphiques' de Microsoft
  par Richard Wilton }
label L10,L11,L12;
const BytesPerLine=320;
asm
		push    si
		push    di
		push    ds
{ Calculer l'adresse du premier pixel }
		mov     ax,word ptr y   { ax:=y }
		mov     bx,word ptr x   { bx:=x }

{ Cette fonction d‚termine l'addresse d'un pixel dans le buffer en mode 13h
  ax=ordonn‚e (0-199)
  bx=abscisse (0-319)
  retourne bx=d‚placement en octets dans le buffer
	   es=segment du buffer video }

		xchg        ah,al       { ax:=256*y }
		add         bx,ax       { bx:=256*y+x }
		shr         ax,1
		shr         ax,1        { ax:=64*y }
		add         bx,ax       { bx:=320*y+x }
		mov         ax,0A000h
		mov         es,ax       { es:bx:=adresse du pixel }

		mov     di,bx           { es:di->buffer }
{ Etablir l'adressage de la table de d‚finition des caractŠres }
		mov     ax,40h
		mov     ds,ax           { ds:=segment donn‚es du BIOS video }
		mov     cx,ds:[85h]     { cx:=points (nb de lignes de pixel }
					{ dans la matrice de caractŠres) }
		xor     ax,ax
		mov     ds,ax           { ds:=0 absolu }
		mov     ax,word ptr c   { al:=code caractŠre }
		mov     bx,43h*4        { ds:bx->vecteur d'interruption 43h }
					{ si caractŠre<80h }
		lds     si,ds:[bx]      { ds:si->d‚but table des caractŠres }
		mul     cl              { ax:=d‚pl dans table de d‚f. car. }
					{ (points*code caractŠre) }
		add     si,ax           { si:=adresse des d‚finitions de car.}
{ Ranger le caractŠre dans le buffer vid‚o }
		mov     bl,byte ptr fgd { bl:=valeur des pixels d'avant-plan }
		mov     bh,byte ptr bkgd{ bh:=valeur des pixels d'arriŠre-p. }
L10:            push    cx              { pr‚server cx dans la boucle }
		mov     cx,8            { cx:=largeur caractŠre en pixels }
		lodsb
		mov     ah,al           { ah:=motif de bits pour ligne de }
					{ caractŠres suivante }
L11:            mov     al,bl           { al:=valeur des pixels d'avant-plan }
		shl     ah,1            { carry flag:=bit de gauche }
		jc      L12             { saut si motif de bits sp‚cifie un }
					{ pixel d'avant-plan (bit=1) }
		mov     al,bh           { al:=valeur d'arriŠre-plan du pixel }
L12:            stosb                   { modifier un pixel dans le buffer }
		loop    L11
		add     di,BytesPerLine-8{ incr‚menter adresse dans buffer }
					{ -> ligne de pixels suivante }
		pop     cx
		loop    L10             { boucler pour un caractŠre }
		pop     ds              { restaurer registres et retour }
		pop     di
		pop     si
end;
{----------------------------------------------------------------------}
procedure Old_Fill_Polygon(x,y:word; color,border:byte);
{ Proc‚dure r‚cursive pour le remplissage d'un polygone. Demande
  franchement une optimisation !!! La r‚cursivit‚ demande trop de m‚moire
  et ralentit l'algorithme .... Provisoire! }
var v:integer;
begin
 v:=GetPix(x,y);
 if (v<>border) and (v<>color) then
   begin
     Pix(x,y,color);
     Old_Fill_Polygon(x-1,y,color,border);
     Old_Fill_Polygon(x+1,y,color,border);
     Old_Fill_Polygon(x,y-1,color,border);
     Old_Fill_Polygon(x,y+1,color,border);
   end
end;
{----------------------------------------------------------------------}
procedure Fill_Quad(x1,y1,x2,y2,x3,y3,x4,y4:word; color_fill,color_line:byte);
{ Remplit une r‚gion d‚finie par un quadrilatŠre. Utilise l'algorithme de
  Bresenham pour le trac‚ des lignes. Une ligne horizontale est trac‚e entre
  chaque points de ces lignes.
  Ne fonctionne qu'en modeX (puisqu'utilise Draw_Line ...)
  Les donn‚es des points doivent ˆtre introduites dans un sens horloger
  ou anti-horloger au choix.
  Remerciements … mon assistant en assembleur pour m'en avoir donn‚ l'id‚e.
}
var
    x, y, t, e, dx, dy, denom, xinc, yinc, aux: array[1..4] of integer;
    xpos,ypos,xpos2:integer;
    vertlonger: array[1..4] of boolean;

procedure Line_Dec(x1, y1, x2, y2: word; i:integer);
{ Etablit les donn‚es concernant le trac‚ d'une ligne (voir algo bresenham).
  Ces donn‚es sont plac‚es aux iŠmes ‚l‚ments.
}
begin
    xinc[i] := 1;
    yinc[i] := 1;
    vertlonger[i] := false;
    dx[i] := x2 - x1;
    dy[i] := y2 - y1;
    if (dx[i] < 0) then begin  xinc[i] := -1;  dx[i] := -dx[i];   end;
    if (dy[i] < 0) then begin  yinc[i] := -1;  dy[i] := -dy[i];   end;
    if (dy[i] > dx[i]) then
    begin
    	vertlonger[i] := TRUE;
        aux[i] := dx[i];
        dx[i] := dy[i];
        dy[i] := aux[i];
    end;
    denom[i] := dx[i] SHL 2; 				{ denom := 2 * dx }
	t[i] := dy[i] SHL 2;				{ t := 2 * dy }
    e[i] := -dx[i];
    x[i] := x1;
    y[i] := y1;
end; {Line}

procedure Line_Step(i:integer);
{ Calcule une ‚tape dans la progression du trac‚ d'une ligne de donn‚es en
  iŠme position
}
begin
      	dx[i] := dx[i] - 1;
{        SET_POINT(x[i], y[i], color_line);}
         xpos:=x[i];
         ypos:=y[i];
         e[i] := e[i] + t[i];
         if (e[i] > 0) then
         begin
         	if (vertlonger[i]) then x[i] := x[i] + xinc[i]
 		else y[i] := y[i] + yinc[i];
                e[i] := e[i] - denom[i];
         end;
         if (vertlonger[i]) then y[i] := y[i] + yinc[i]
         else x[i] := x[i] + xinc[i];
end;

procedure swap_int(int1,int2:integer);
var sw:integer;
begin
   sw:=int1;
   int1:=int2;
   int2:=sw
end;

var step1,step2:word;
    flag1,flag2,fin:boolean;
    i:1..4;
    xsave,ysave:array[1..4] of word;
begin
  { tri des points }
  if (y1<=y2) and (y1<=y3) and (y1<=y4) then
     begin
       if x2<=x4 then begin
                        xsave[1]:=x1; ysave[1]:=y1;
                        xsave[2]:=x2; ysave[2]:=y2;
                        xsave[3]:=x3; ysave[3]:=y3;
                        xsave[4]:=x4; ysave[4]:=y4;
                      end
       else           begin
                        xsave[1]:=x1; ysave[1]:=y1;
                        xsave[2]:=x4; ysave[2]:=y4;
                        xsave[3]:=x3; ysave[3]:=y3;
                        xsave[4]:=x2; ysave[4]:=y2;
                      end
     end
  else if (y2<=y1) and (y2<=y3) and (y2<=y4) then
     begin
       if x3<=x1 then begin
                        xsave[1]:=x2; ysave[1]:=y2;
                        xsave[2]:=x3; ysave[2]:=y3;
                        xsave[3]:=x4; ysave[3]:=y4;
                        xsave[4]:=x1; ysave[4]:=y1;
                      end
       else           begin
                        xsave[1]:=x2; ysave[1]:=y2;
                        xsave[2]:=x1; ysave[2]:=y1;
                        xsave[3]:=x4; ysave[3]:=y4;
                        xsave[4]:=x3; ysave[4]:=y3;
                      end
     end
  else if (y3<=y1) and (y3<=y2) and (y3<=y4) then
     begin
       if x4<=x2 then begin
                        xsave[1]:=x3; ysave[1]:=y3;
                        xsave[2]:=x4; ysave[2]:=y4;
                        xsave[3]:=x1; ysave[3]:=y1;
                        xsave[4]:=x2; ysave[4]:=y2;
                      end
       else           begin
                        xsave[1]:=x3; ysave[1]:=y3;
                        xsave[2]:=x2; ysave[2]:=y2;
                        xsave[3]:=x1; ysave[3]:=y1;
                        xsave[4]:=x4; ysave[4]:=y4;
                      end
     end
  else if (y4<=y1) and (y4<=y2) and (y4<=y3) then
     begin
       if x1<=x3 then begin
                        xsave[1]:=x4; ysave[1]:=y4;
                        xsave[2]:=x1; ysave[2]:=y1;
                        xsave[3]:=x2; ysave[3]:=y2;
                        xsave[4]:=x3; ysave[4]:=y3;
                      end
       else           begin
                        xsave[1]:=x4; ysave[1]:=y4;
                        xsave[2]:=x3; ysave[2]:=y3;
                        xsave[3]:=x2; ysave[3]:=y2;
                        xsave[4]:=x1; ysave[4]:=y1;
                      end
     end;

  x1:=xsave[1];    y1:=ysave[1];
  x2:=xsave[2];    y2:=ysave[2];
  x3:=xsave[3];    y3:=ysave[3];
  x4:=xsave[4];    y4:=ysave[4];

  { Dessin du polygone }
  Line_Dec(x1,y1,x2,y2,1);
  Line_Dec(x1,y1,x4,y4,2);
  step1:=y1;    step2:=y1;
  flag1:=false; flag2:=false;  fin:=false;
  while not fin do
   begin
     while (y[1]=step1) and (dx[1]>=0) do Line_Step(1);
     step1:=y[1];
     xpos2:=xpos;
     while (y[2]=step2) and (dx[2]>=0) do Line_Step(2);
     step2:=y[2];
     if (ypos<Y_MIN) or (ypos>Y_MAX) then
         begin dx[1]:=-1; dx[2]:=-1 end
     else
      begin
        if xpos<X_MIN then xpos:=X_MIN;
        if xpos>X_MAX then xpos:=X_MAX;
        if xpos2>X_MAX then xpos2:=X_MAX;
        if xpos2<X_MIN then xpos2:=X_MIN;

        Draw_Line(xpos,ypos,xpos2,ypos,color_fill);
      end;
     if dx[1] < 0 then
       begin
         if not flag1 then
           begin
             Line_Dec(x2,y2,x3,y3,1);
             step1:=y2;
             flag1:=true
           end
         else if (ypos<y4) and not flag2 then
           begin
             Line_Dec(x3,y3,x4,y4,1);
             step1:=y3;
             flag2:=true
           end
         else fin:=true
       end
     else if dx[2] < 0 then
       begin
         if not flag2 then
           begin
             Line_Dec(x4,y4,x3,y3,2);
             step2:=y4;
             flag2:=true
           end
         else if (ypos<y2) and not flag1 then
           begin
             Line_Dec(x3,y3,x2,y2,2);
             step2:=y3;
             flag1:=true
           end
         else fin:=true
       end
   end;
   if color_fill<>color_line then
    begin
      Line_Clipping(x1,y1,x2,y2,X_MIN,X_MAX,Y_MIN,Y_MAX,color_line);
      Line_Clipping(x2,y2,x3,y3,X_MIN,X_MAX,Y_MIN,Y_MAX,color_line);
      Line_Clipping(x4,y4,x3,y3,X_MIN,X_MAX,Y_MIN,Y_MAX,color_line);
      Line_Clipping(x1,y1,x4,y4,X_MIN,X_MAX,Y_MIN,Y_MAX,color_line)
    end
end;

{----------------------------------------------------------------------}
procedure OutText(x,y:word; str:string; fgd,bkgd:integer);
{ Affiche un string … l'‚cran dans le mode souhait‚ }
var i:integer;
begin
  if Graphic_Mode=8 then
    for i:=length(str) downto 1 do
        Affiche_Char_13(str[i],x+largeur_font*(i-1),y,fgd,bkgd)
    else
    for i:=length(str) downto 1 do
     if bkg_font then GprintC(ord(str[i]),x+largeur_font*(i-1),y,fgd,bkgd)
     else TGprintC(ord(str[i]),x+largeur_font*(i-1),y,fgd);
end;
{----------------------------------------------------------------------}
procedure Box(x1, y1, x2, y2:word; colour:byte);
{ Affiche une boite du coin sup‚rieur gauche (x1,y1) au coin inf‚rieur
  droit (x2,y2) }
var i:integer;
begin
  if Graphic_Mode=8 then
  for i:=y1 to y2 do
     Line_Asm(x1,i,x2,i,colour)
  else
  for i:=y1 to y2 do
     Draw_Line(x1,i,x2,i,colour)

end;
{----------------------------------------------------------------------}
procedure Cadre(x1, y1, x2, y2:word; colour:byte; cad:type_cadre);
begin
         Draw_Line(x1, y1, x2, y1, colour);
         Draw_Line(x1, y1, x1, y2, colour);
         Draw_Line(x1, y2, x2, y2, colour);
         Draw_Line(x2, y1, x2, y2, colour);
         if cad=double then
           begin
             Draw_Line(x1+2, y1+2, x2-2, y1+2, colour);
             Draw_Line(x1+2, y1+2, x1+2, y2-2, colour);
             Draw_Line(x1+2, y2-2, x2-2, y2-2, colour);
             Draw_Line(x2-2, y1+2, x2-2, y2-2, colour);
           end
end;
{----------------------------------------------------------------------}
procedure Line_Clipping (x0,y0,x1,y1,X_MIN,X_MAX,Y_MIN,Y_MAX:real;
                         value:byte);
{ Cohen-Sutherland clipping algorithm for line P0=(x0,y0) to P1=(x1,y1) and
  clip rectangle with diagonal from (X_MIN,Y_MIN) to (X_MAX,Y_MAX).
}

type edge=(LEFT,RIGHT,BOTTOM,TOP);
     outcode=set of edge;
var accept,done:boolean;
    outcode0,outcode1,outcodeOut:outcode;
    { Outcodes for P0, P1, and whichever point lies outside the clip
      rectangle }
    x,y:real;
procedure CompOutCode(x,y:real; var code:outcode);
{ Compute outcode for the point (x,y) }
begin
  code:=[];
  if y>Y_MAX then code:=[TOP]
  else if y<Y_MIN then code:=[BOTTOM];
  if x>X_MAX then code:=code+[RIGHT]
  else if x<X_MIN then code:=code+[LEFT]
end;

begin
  accept:=false;        done:=false;
  CompOutCode(x0,y0,outcode0);
  CompOutCode(x1,y1,outcode1);
  repeat
    if (outcode0=[]) and (outcode1=[]) then { Trivial accept and exit }
     begin accept:=true; done:=true end
    else if (outcode0*outcode1)<>[] then
     done:=true { Logical intersection is true, so trivial reject and exit }
    else
      { Failed both tests, so calculate the line segment to clip:
        from an outside point to an intersection with clip edge }
      begin
         { At least one endpoint is outside the clip rectangle; pick it }
         if outcode0<>[] then
            outcodeOut:=outcode0 else outcodeOut:=outcode1;
         { Now find the intersection point;
           use formula y=y0+slope*(x-x0),x=x0+(1/slope)*(y-y0). }
         if TOP in outcodeOut then
            begin     { Divide line at top of clip rectangle }
              x:=x0+(x1-x0)*(Y_MAX-y0)/(y1-y0);
              y:=Y_MAX
            end
         else if BOTTOM in outcodeOut then
            begin     { Divide line at bottom of clip rectangle }
              x:=x0+(x1-x0)*(Y_MIN-y0)/(y1-y0);
              y:=Y_MIN
            end
         else if RIGHT in outcodeOut then
            begin     { Divide line at right edge of clip rectangle }
              y:=y0+(y1-y0)*(X_MAX-x0)/(x1-x0);
              x:=X_MAX
            end
         else if LEFT in outcodeOut then
            begin     { Divide line at left edge of clip rectangle }
              y:=y0+(y1-y0)*(X_MIN-x0)/(x1-x0);
              x:=X_MIN
            end;
         { Now we move outside point to intersection point to clip,
           and get ready for next pass.
         }
         if (outcodeOut=outcode0) then
            begin
              x0:=x; y0:=y; CompOutCode(x0,y0,outcode0)
            end
         else
            begin
              x1:=x; y1:=y; CompOutCode(x1,y1,outcode1)
            end
      end { Subdivide }
  until done;
  if accept then
    if Graphic_Mode=8 then
    Line_Asm(round(x0),round(y0),round(x1),round(y1), value) { Non-Mode X }
    else Draw_Line(round(x0),round(y0),round(x1),round(y1), value)  { Mode X }
end;
{----------------------------------------------------------------------}
procedure InitVideo(mode:Type_Mode);
begin
  clrscr;
  if VGACardExists=false then
   begin
     writeln('Vous ne semblez pas avoir de carte VGA !');
     Halt
   end;
   Graphic_Mode:=mode;
   largeur_font:=8;
   bkg_font:=true;
   case mode of
      0: begin
           Set_ModeX(Mode_320x200);
           XL:=320;
           YL:=200
         end;
      1: begin
           Set_ModeX(Mode_320x400);
           XL:=320;
           YL:=400
         end;
      2: begin
           Set_ModeX(Mode_360x200);
           XL:=360;
           YL:=200
         end;
      3: begin
           Set_ModeX(Mode_360x400);
           XL:=360;
           YL:=400
         end;
      4: begin
           Set_ModeX(Mode_320x240);
           XL:=320;
           YL:=240
         end;
      5: begin
           Set_ModeX(Mode_320x480);
           XL:=320;
           YL:=480
         end;
      6: begin
           Set_ModeX(Mode_360x240);
           XL:=360;
           YL:=240
         end;
      7: begin
           Set_ModeX(Mode_360x480);
           XL:=360;
           YL:=480
         end;
      8: begin
           Video;
           XL:=320;
           YL:=200
         end;
     end
end;
{----------------------------------------------------------------------}
Procedure DrawPoly(x1,y1,x2,y2,x3,y3,x4,y4:integer;color:byte;where:word);
  { This draw a polygon with 4 points at x1,y1 , x2,y2 , x3,y3 , x4,y4
    in color col
  }
var
  x:integer;
  mny,mxy:integer;
  mnx,mxx,yc:integer;
  mul1,div1,
  mul2,div2,
  mul3,div3,
  mul4,div4:integer;

begin
  mny:=y1; mxy:=y1;
  if y2<mny then mny:=y2;
  if y2>mxy then mxy:=y2;
  if y3<mny then mny:=y3;
  if y3>mxy then mxy:=y3;    { Choose the min y mny and max y mxy }
  if y4<mny then mny:=y4;
  if y4>mxy then mxy:=y4;

  if mny<0 then mny:=0;
  if mxy>199 then mxy:=199;
  if mny>199 then exit;
  if mxy<0 then exit;        { Verticle range checking }

  mul1:=x1-x4; div1:=y1-y4;
  mul2:=x2-x1; div2:=y2-y1;
  mul3:=x3-x2; div3:=y3-y2;
  mul4:=x4-x3; div4:=y4-y3;  { Constansts needed for intersection calc }

  for yc:=mny to mxy do
    begin
      mnx:=320;
      mxx:=-1;
       if (y4>=yc) or (y1>=yc) then
        if (y4<=yc) or (y1<=yc) then   { Check that yc is between y1 and y4 }
          if not(y4=y1) then
            begin
              x:=(yc-y4)*mul1 div div1+x4; { Point of intersection on x axis }
              if x<mnx then
                mnx:=x;
              if x>mxx then
                mxx:=x;       { Set point as start or end of horiz line }
            end;
      if (y1>=yc) or (y2>=yc) then
        if (y1<=yc) or (y2<=yc) then   { Check that yc is between y1 and y2 }
          if not(y1=y2) then
            begin
              x:=(yc-y1)*mul2 div div2+x1; { Point of intersection on x axis }
              if x<mnx then
                mnx:=x;
              if x>mxx then
                mxx:=x;       { Set point as start or end of horiz line }
            end;
      if (y2>=yc) or (y3>=yc) then
        if (y2<=yc) or (y3<=yc) then   { Check that yc is between y2 and y3 }
          if not(y2=y3) then
            begin
              x:=(yc-y2)*mul3 div div3+x2; { Point of intersection on x axis }
              if x<mnx then
                mnx:=x;
              if x>mxx then
                mxx:=x;       { Set point as start or end of horiz line }
            end;
      if (y3>=yc) or (y4>=yc) then
        if (y3<=yc) or (y4<=yc) then   { Check that yc is between y3 and y4 }
          if not(y3=y4) then
            begin
              x:=(yc-y3)*mul4 div div4+x3; { Point of intersection on x axis }
              if x<mnx then
                mnx:=x;
              if x>mxx then
                mxx:=x;       { Set point as start or end of horiz line }
            end;
      if mnx<0 then
        mnx:=0;
      if mxx>319 then
        mxx:=319;          { Range checking on horizontal line }
      if mnx<=mxx then
        Draw_line(mnx,yc,mxx,yc,color);   { Draw the horizontal line }
    end;
  end;
{----------------------------------------------------------------------}
procedure Get_Palette(color : byte; var r,g,b : byte);assembler;
asm
      mov    dx,3c7h
      mov    al,color
      out    dx,al

      add    dx,2

      in     al,dx
      mov    byte ptr [r],al
      in     al,dx
      mov    byte ptr [g],al
      in     al,dx
      mov    byte ptr [b],al
end;
{----------------------------------------------------------------------}
procedure Fill_Quad_Asm(a1,b1,a2,b2,a3,b3,a4,b4:integer; color_fill,color_line:byte);
{ Remplit une r‚gion d‚finie par un quadrilatŠre. Utilise l'algorithme de
  Bresenham pour le trac‚ des lignes. Une ligne horizontale est trac‚e entre
  chaque points de ces lignes.
  Ne fonctionne qu'en modeX (puisqu'utilise Draw_Line ...)
  Les donn‚es des points doivent ˆtre introduites dans un sens horloger
  ou anti-horloger au choix.
  Version Assembleur, Morflame Juin 1994
}
var
    x1, y1, t1, e1, dx1, dy1, denom1, xinc1, yinc1: integer;
    x2, y2, t2, e2, dx2, dy2, denom2, xinc2, yinc2: integer;
    xpos,ypos,xpos2:integer;
    vertlonger1, vertlonger2: boolean;
    step1,step2:integer;
    flag1,flag2,fin:boolean;
    xsave,ysave:array[1..4] of integer;

label s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13,
      s14, s15, s16, s17, s18, s19, s20, s21, s22, s23, s24, s25, s26, s27,
      s28, s29, s30, s31, s32, s33, s34, s35, s36, s37, s38, s39, s40, s41,
      s42, s44, s45, whil, ex, ls1, ls2, fbcl;

begin
  { tri des points }
  if (b1<=b2) and (b1<=b3) and (b1<=b4) then
     begin
       if a2<=a4 then begin
                        xsave[1]:=a1; ysave[1]:=b1;
                        xsave[2]:=a2; ysave[2]:=b2;
                        xsave[3]:=a3; ysave[3]:=b3;
                        xsave[4]:=a4; ysave[4]:=b4;
                      end
       else           begin
                        xsave[1]:=a1; ysave[1]:=b1;
                        xsave[2]:=a4; ysave[2]:=b4;
                        xsave[3]:=a3; ysave[3]:=b3;
                        xsave[4]:=a2; ysave[4]:=b2;
                      end
     end
  else if (b2<=b1) and (b2<=b3) and (b2<=b4) then
     begin
       if a3<=a1 then begin
                        xsave[1]:=a2; ysave[1]:=b2;
                        xsave[2]:=a3; ysave[2]:=b3;
                        xsave[3]:=a4; ysave[3]:=b4;
                        xsave[4]:=a1; ysave[4]:=b1;
                      end
       else           begin
                        xsave[1]:=a2; ysave[1]:=b2;
                        xsave[2]:=a1; ysave[2]:=b1;
                        xsave[3]:=a4; ysave[3]:=b4;
                        xsave[4]:=a3; ysave[4]:=b3;
                      end
     end
  else if (b3<=b1) and (b3<=b2) and (b3<=b4) then
     begin
       if a4<=a2 then begin
                        xsave[1]:=a3; ysave[1]:=b3;
                        xsave[2]:=a4; ysave[2]:=b4;
                        xsave[3]:=a1; ysave[3]:=b1;
                        xsave[4]:=a2; ysave[4]:=b2;
                      end
       else           begin
                        xsave[1]:=a3; ysave[1]:=b3;
                        xsave[2]:=a2; ysave[2]:=b2;
                        xsave[3]:=a1; ysave[3]:=b1;
                        xsave[4]:=a4; ysave[4]:=b4;
                      end
     end
  else if (b4<=b1) and (b4<=b2) and (b4<=b3) then
     begin
       if a1<=a3 then begin
                        xsave[1]:=a4; ysave[1]:=b4;
                        xsave[2]:=a1; ysave[2]:=b1;
                        xsave[3]:=a2; ysave[3]:=b2;
                        xsave[4]:=a3; ysave[4]:=b3;
                      end
       else           begin
                        xsave[1]:=a4; ysave[1]:=b4;
                        xsave[2]:=a3; ysave[2]:=b3;
                        xsave[3]:=a2; ysave[3]:=b2;
                        xsave[4]:=a1; ysave[4]:=b1;
                      end
     end;

  a1:=xsave[1];    b1:=ysave[1];
  a2:=xsave[2];    b2:=ysave[2];
  a3:=xsave[3];    b3:=ysave[3];
  a4:=xsave[4];    b4:=ysave[4];

  { Dessin du polygone }
  asm
  { LineDec(a1, b1, a2, b2, 1) }
  { Etablit les donn‚es concernant le trac‚ d'une ligne (voir algo bresenham).
    Ces donn‚es sont plac‚es aux iŠmes ‚l‚ments.
  }
      mov   word ptr xinc1, 1
      mov   word ptr yinc1, 1
      mov   byte ptr vertlonger1, FALSE
      mov   ax, word ptr a2
      sub   ax, word ptr a1
      mov   word ptr dx1, ax
      mov   ax, word ptr b2
      sub   ax, word ptr b1
      mov   word ptr dy1, ax

      cmp   word ptr dx1, 0
      jge   s1
      mov   word ptr xinc1, -1
      not   word ptr dx1
      inc   word ptr dx1
s1:   cmp   word ptr dy1, 0
      jge   s2
      mov   word ptr yinc1, -1
      not   word ptr dy1
      inc   word ptr dy1
s2:   mov   ax, word ptr dy1
      mov   bx, word ptr dx1
      cmp   ax, bx
      jle   s3
      mov   byte ptr vertlonger1, TRUE
      mov   word ptr dy1, bx
      mov   word ptr dx1, ax
s3:   mov   bx, word ptr dx1
      mov   word ptr denom1, bx
      shl   word ptr denom1, 2
      mov   ax, word ptr dy1
      mov   word ptr t1, ax
      shl   word ptr t1, 2
      not   bx
      inc   bx
      mov   word ptr e1, bx
      mov   ax, word ptr a1
      mov   word ptr x1, ax
      mov   ax, word ptr b1
      mov   word ptr y1, ax
  { LineDec(a1, b1, a4, b4, 2) }
  { Etablit les donn‚es concernant le trac‚ d'une ligne (voir algo bresenham).
    Ces donn‚es sont plac‚es aux iŠmes ‚l‚ments.
  }
      mov   word ptr xinc2, 1
      mov   word ptr yinc2, 1
      mov   byte ptr vertlonger2, FALSE
      mov   ax, word ptr a4
      sub   ax, word ptr a1
      mov   word ptr dx2, ax
      mov   ax, word ptr b4
      sub   ax, word ptr b1
      mov   word ptr dy2, ax
      cmp   word ptr dx2, 0
      jge   s4
      mov   word ptr xinc2, -1
      not   word ptr dx2
      inc   word ptr dx2
s4:   cmp   word ptr dy2, 0
      jge   s5
      mov   word ptr yinc2, -1
      not   word ptr dy2
      inc   word ptr dy2
s5:   mov   ax, word ptr dy2
      mov   bx, word ptr dx2
      cmp   ax, bx
      jle   s6
      mov   byte ptr vertlonger2, TRUE
      mov   word ptr dy2, bx
      mov   word ptr dx2, ax
s6:   mov   bx, word ptr dx2
      mov   word ptr denom2, bx
      shl   word ptr denom2, 2
      mov   ax, word ptr dy2
      mov   word ptr t2, ax
      shl   word ptr t2, 2
      not   bx
      inc   bx
      mov   word ptr e2, bx

      mov   ax, word ptr a1
      mov   word ptr x2, ax
      mov   ax, word ptr b1
      mov   word ptr y2, ax

      {---}
      mov   ax, word ptr b1
      mov   word ptr step1, ax
      mov   word ptr step2, ax
      mov   flag1, FALSE
      mov   flag2, FALSE
      mov   fin, FALSE
{ ----------- BOUCLE PRINCIPALE (while not fin do) }
whil: cmp   fin, false
      jne   ex
   { LINE_STEP 1 }
ls1:  mov   ax, word ptr y1
      cmp   ax, word ptr step1
      jnz   s7

      cmp   word ptr dx1, 0
      jl    s7
      dec   word ptr dx1
        { dans un algo de bres pour tracer une ligne, ici on met un pixel
          en x1, y1, couleur ... }
      mov   ax, word ptr x1
      mov   word ptr xpos, ax
      mov   ax, word ptr y1
      mov   ypos, ax
      mov   ax, word ptr t1
      add   word ptr e1, ax
      cmp   word ptr e1, 0
      jle   s9
      cmp   vertlonger1, false
      jz    s10
      mov   ax, word ptr xinc1
      add   word ptr x1, ax
      jmp   s11
s10:  mov   ax, word ptr yinc1
      add   word ptr y1, ax
s11:  mov   ax, word ptr denom1
      sub   word ptr e1, ax
s9:   cmp   vertlonger1, false
      jz    s12
      mov   ax, word ptr yinc1
      add   word ptr y1, ax
      jmp   s13
s12:  mov   ax, word ptr xinc1
      add   word ptr x1, ax
s13:
      jmp   ls1
s7:   mov   ax, word ptr y1
      mov   step1, ax
      mov   ax, word ptr xpos
      mov   word ptr xpos2, ax
   { LINE_STEP 2 }
ls2:  mov   ax, word ptr y2
      cmp   ax, word ptr step2
      jnz   s8

      cmp   word ptr dx2, 0
      jl    s8
      dec   word ptr dx2
        { dans un algo de bres pour tracer une ligne, ici on met un pixel
          en x2, y2, couleur ... }
      mov   ax, word ptr x2
      mov   word ptr xpos, ax
      mov   ax, word ptr y2
      mov   ypos, ax
      mov   ax, word ptr t2
      add   word ptr e2, ax
      cmp   word ptr e2, 0
      jle   s14
      cmp   vertlonger2, false
      jz    s15
      mov   ax, word ptr xinc2
      add   word ptr x2, ax
      jmp   s16
s15:  mov   ax, word ptr yinc2
      add   word ptr y2, ax
s16:  mov   ax, word ptr denom2
      sub   word ptr e2, ax
s14:  cmp   vertlonger2, false
      jz    s17
      mov   ax, word ptr yinc2
      add   word ptr y2, ax
      jmp   s18
s17:  mov   ax, word ptr xinc2
      add   word ptr x2, ax
s18:
      jmp   ls2
s8:   mov   ax, word ptr y2
      mov   word ptr step2, ax

      { if .... else }
      mov   ax, word ptr Y_MIN
      mov   bx, word ptr Y_MAX
      mov   cx, word ptr X_MIN
      mov   dx, word ptr X_MAX
  { test du signe car prob pour les n‚gatifs (j'ai surement pas tout pig‚) }
      cmp   word ptr ypos, AX
      js    s19
      cmp   word ptr xpos, CX
      jns   s44
      cmp   word ptr xpos2, CX
      js    s19                 { si les deux pts en x sont out -> sortie }
      mov   word ptr xpos, cx
s44:  cmp   word ptr xpos2, CX
      jns   s45
      mov   word ptr xpos2, cx
s45:  { test de position }
      cmp   word ptr ypos, ax
      jl    s19
      cmp   word ptr ypos, bx
      jg    s19
      cmp   word ptr xpos2, cx
      jge   s21
      mov   word ptr xpos2, cx
s21:  cmp   word ptr xpos, dx
      jle   s26
      cmp   word ptr xpos2, dx
      jg    s19                 { id }
      mov   word ptr xpos, dx
s26:  cmp   word ptr xpos, cx
      jge   s41
      mov   word ptr xpos, cx
s41:  cmp   word ptr xpos2, dx
      jle   s42
      mov   word ptr xpos2, dx
s42:  { APPEL DE DRAWLINE! }
      push  xpos
      push  ypos
      push  xpos2
      push  ypos
      push  word ptr color_fill
      call  DRAW_LINE
{      call line_asm}
      jmp   s20
s19:{ mov   word ptr dx1, -1       { bizarre, ca marche quand on ne le fait
      mov   word ptr dx2, -1 }     { pas .... s19 repr‚sente le point de
                                   { sortie ... }

s20:  cmp   dx1, 0
      jl    s27
      cmp   dx2, 0
      jge   fbcl
      { DX2 < 0 }
      cmp   flag2, true
      jz    s22
  { LINEDEC (a4, b4, a3, b3, 2) }
  { Etablit les donn‚es concernant le trac‚ d'une ligne (voir algo bresenham).
    Ces donn‚es sont plac‚es aux iŠmes ‚l‚ments.
  }
      mov   word ptr xinc2, 1
      mov   word ptr yinc2, 1
      mov   byte ptr vertlonger2, FALSE
      mov   ax, word ptr a3
      sub   ax, word ptr a4
      mov   word ptr dx2, ax
      mov   ax, word ptr b3
      sub   ax, word ptr b4
      mov   word ptr dy2, ax
      cmp   word ptr dx2, 0
      jge   s35
      mov   word ptr xinc2, -1
      not   word ptr dx2
      inc   word ptr dx2
s35:  cmp   word ptr dy2, 0
      jge   s36
      mov   word ptr yinc2, -1
      not   word ptr dy2
      inc   word ptr dy2
s36:  mov   ax, word ptr dy2
      mov   bx, word ptr dx2
      cmp   ax, bx
      jle   s37
      mov   byte ptr vertlonger2, TRUE
      mov   word ptr dy2, bx
      mov   word ptr dx2, ax

s37:  mov   bx, word ptr dx2
      mov   word ptr denom2, bx
      shl   word ptr denom2, 2
      mov   ax, word ptr dy2
      mov   word ptr t2, ax
      shl   word ptr t2, 2
      not   bx
      inc   bx
      mov   word ptr e2, bx

      mov   ax, word ptr a4
      mov   word ptr x2, ax
      mov   ax, word ptr b4
      mov   word ptr y2, ax


{------}
      mov   ax, word ptr b4
      mov   word ptr step2, ax
      mov   byte ptr flag2, true
      jmp   fbcl
s22:  cmp   flag1, true
      jz    s23
      mov   ax, word ptr b2
      cmp   word ptr ypos, ax
      jge   s23

  { LINEDEC (a3, b3, a2, b2, 2) }
  { Etablit les donn‚es concernant le trac‚ d'une ligne (voir algo bresenham).
    Ces donn‚es sont plac‚es aux iŠmes ‚l‚ments.
  }
      mov   word ptr xinc2, 1
      mov   word ptr yinc2, 1
      mov   byte ptr vertlonger2, FALSE
      mov   ax, word ptr a2
      sub   ax, word ptr a3
      mov   word ptr dx2, ax
      mov   ax, word ptr b2
      sub   ax, word ptr b3
      mov   word ptr dy2, ax
      cmp   word ptr dx2, 0
      jge   s38
      mov   word ptr xinc2, -1
      not   word ptr dx2
      inc   word ptr dx2
s38:  cmp   word ptr dy2, 0
      jge   s39
      mov   word ptr yinc2, -1
      not   word ptr dy2
      inc   word ptr dy2
s39:  mov   ax, word ptr dy2
      mov   bx, word ptr dx2
      cmp   ax, bx
      jle   s40
      mov   byte ptr vertlonger2, TRUE
      mov   word ptr dy2, bx
      mov   word ptr dx2, ax
s40:  mov   bx, word ptr dx2
      mov   word ptr denom2, bx
      shl   word ptr denom2, 2
      mov   ax, word ptr dy2
      mov   word ptr t2, ax
      shl   word ptr t2, 2
      not   bx
      inc   bx
      mov   word ptr e2, bx

      mov   ax, word ptr a3
      mov   word ptr x2, ax
      mov   ax, word ptr b3
      mov   word ptr y2, ax

{------}
      mov   ax, word ptr b3
      mov   word ptr step2, ax
      mov   byte ptr flag1, true
      jmp   fbcl

s23:  mov   fin, true
      jmp   fbcl
s27:  { DX1 < 0 }
      cmp   flag1, true
      jz    s24

  { LINEDEC (a2, b2, a3, b3, 1) }
  { Etablit les donn‚es concernant le trac‚ d'une ligne (voir algo bresenham).
    Ces donn‚es sont plac‚es aux iŠmes ‚l‚ments.
  }
      mov   word ptr xinc1, 1
      mov   word ptr yinc1, 1
      mov   byte ptr vertlonger1, FALSE
      mov   ax, word ptr a3
      sub   ax, word ptr a2
      mov   word ptr dx1, ax
      mov   ax, word ptr b3
      sub   ax, word ptr b2
      mov   word ptr dy1, ax
      cmp   word ptr dx1, 0
      jge   s28
      mov   word ptr xinc1, -1
      not   word ptr dx1
      inc   word ptr dx1
s28:  cmp   word ptr dy1, 0
      jge   s29
      mov   word ptr yinc1, -1
      not   word ptr dy1
      inc   word ptr dy1
s29:  mov   ax, word ptr dy1
      mov   bx, word ptr dx1
      cmp   ax, bx
      jle   s30
      mov   byte ptr vertlonger1, TRUE
      mov   word ptr dy1, bx
      mov   word ptr dx1, ax
s30:  mov   bx, word ptr dx1
      mov   word ptr denom1, bx
      shl   word ptr denom1, 2
      mov   ax, word ptr dy1
      mov   word ptr t1, ax
      shl   word ptr t1, 2
      not   bx
      inc   bx
      mov   word ptr e1, bx

      mov   ax, word ptr a2
      mov   word ptr x1, ax
      mov   ax, word ptr b2
      mov   word ptr y1, ax
{------}

      mov   ax, word ptr b2
      mov   word ptr step1, ax
      mov   byte ptr flag1, true
      jmp   fbcl
s24:  cmp   flag2, true
      jz    s25
      mov   ax, word ptr b4
      cmp   word ptr ypos, ax
      jge   s25

  { LINEDEC (a3, b3, a4, b4, 1) }
  { Etablit les donn‚es concernant le trac‚ d'une ligne (voir algo bresenham).
    Ces donn‚es sont plac‚es aux iŠmes ‚l‚ments.
  }
      mov   word ptr xinc1, 1
      mov   word ptr yinc1, 1
      mov   byte ptr vertlonger1, FALSE
      mov   ax, word ptr a4
      sub   ax, word ptr a3
      mov   word ptr dx1, ax
      mov   ax, word ptr b4
      sub   ax, word ptr b3
      mov   word ptr dy1, ax
      cmp   word ptr dx1, 0
      jge   s32
      mov   word ptr xinc1, -1
      not   word ptr dx1
      inc   word ptr dx1
s32:  cmp   word ptr dy1, 0
      jge   s33
      mov   word ptr yinc1, -1
      not   word ptr dy1
      inc   word ptr dy1
s33:  mov   ax, word ptr dy1
      mov   bx, word ptr dx1
      cmp   ax, bx
      jle   s34
      mov   byte ptr vertlonger1, TRUE
      mov   word ptr dy1, bx
      mov   word ptr dx1, ax
s34:  mov   bx, word ptr dx1
      mov   word ptr denom1, bx
      shl   word ptr denom1, 2
      mov   ax, word ptr dy1
      mov   word ptr t1, ax
      shl   word ptr t1, 2
      not   bx
      inc   bx

      mov   word ptr e1, bx

      mov   ax, word ptr a3
      mov   word ptr x1, ax
      mov   ax, word ptr b3
      mov   word ptr y1, ax
{------}

      mov   ax, word ptr b3
      mov   word ptr step1, ax
      mov   byte ptr flag2, true
      jmp   fbcl
s25:  mov   fin, true
{ ----------- FIN BOUCLE PRINCIPALE }
fbcl:
      jmp     whil
ex:
      end;

end;
{-------------------------------------------------------------------------}


end.
