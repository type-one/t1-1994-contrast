{ lit un fichier ?.dat et crŠe trois fichiers
      ?.asm   ; code g‚n‚r‚ sprite ( CH doit etre mis a zero )
      ?.fsm   ; code g‚n‚r‚ fond   ( CH … 0 )
      ?.nda   ; sauve en dc.b les datas non nuls du sprite
}

program make_generate_code;

 Uses Dos,Crt;

var
   zero,i,j,n,x,y,c:      integer;
   name,sauve:            string;
   nulcpt,cycle:          integer;
   handle:                integer;
   regs:                  registers;
   M:                     array [0..79*79] of byte;
   nulM:                  array [0..79*79] of byte;
   res:                   text;
   buf:                   string[20];

(* ******************************************************* *)

Procedure Open(op:char;name:string;Var handle:integer);
 Begin
  If (op='I') Or (op='i') Then
   Begin

     regs.ah:=$3d;
     regs.al:=0;
     regs.ds:=Seg(name);
     regs.dx:=Ofs(name)+1;
     MsDos(regs);
     handle:=regs.ax;

   End

  Else If (op='O') Or (op='o') Then
    Begin

     regs.ah:=$3c;
     regs.cx:=0;
     regs.ds:=Seg(name);
     regs.dx:=Ofs(name)+1;
     MsDos(regs);
     handle:=regs.ax;

    End;

 End;

Procedure Bget(handle,segment,offset,length:longint);
 Begin
  regs.ah:=$3f;
  regs.bx:=handle;
  regs.cx:=length;
  regs.ds:=segment;
  regs.dx:=offset;
  MsDos(regs);
 End;

Procedure Bput(handle,segment,offset,length:longint);
 Begin
  regs.ah:=$40;
  regs.bx:=handle;
  regs.cx:=length;
  regs.ds:=segment;
  regs.dx:=offset;
  MsDos(regs);
 End;

Procedure Closef(handle:integer);
 Begin
  regs.ah:=$3e;
  regs.bx:=handle;
  MsDos(regs);
 End;

(* ******************************************************* *)




procedure  lire;

var
   fichier:     text;
   newname:     string;

begin
     writeln('Filename  .dat ?');
     read(name);
     newname:=name+'.dat'+#0;
     writeln('X size ?');
     read(x);
     writeln('Y size ?');
     read(y);

     Open('I',newname,handle);
     i:=0;
     while i<x*y do begin
          Bget(handle,Seg(buf),Ofs(buf)+1,1);
          M[i]:=Mem[Seg(buf):Ofs(buf)+1];
          i:=i+1;
     end;
     Closef(handle);



end;

(* ******************************************************* *)



(* ******************************************************* *)

procedure sauve_data(nbdata:integer);

var
   datares:     text;
   sdat:        string;

begin
        sdat:=name+'.nda';
        assign(datares,sdat);
        rewrite(datares);
        i:=0;
        write(datares,'    db    ');
        while j<nbdata do begin
          n:=0;
          while (i<>nbdata) and (n<30) do begin
            If n<29 Then
              write(datares,nulM[i],',')
            Else
              write(datares,nulM[i]);

            i:=i+1;
            n:=n+1;
          end;
          j:=j+30;
          if j<nbdata then begin
             writeln(datares,' ');
             write(datares,'    db    ');
          end;
        end;
        close(datares);

end;



(* ******************************************************* *)
(* ******************************************************* *)
(*                MAIN PROGRAM                             *)
(* ******************************************************* *)
(* ******************************************************* *)


begin

(***************************************)
(* Calcul code g‚n‚re Affichage Sprite *)
(***************************************)

     lire;

(* routine qui va g‚n‚rer du code a partir des donn‚es de la matrice *)

   cycle:=0;
   zero:=0;
   nulcpt:=0;
   i:=0;
   j:=0;
   sauve:=name+'.asm';
   assign(res,sauve);
   rewrite(res);


   write      (res,'  db   ');
   c:=0;
   while i<x*y do begin
      zero:=0;
      c:=0;

      if M[i]=0 Then
       Begin
        while (M[i]=0) and (i<x*y) do begin
            if ((i mod x)=0) and (i>0) Then
             zero:=zero+160-x+1
            Else
             zero:=zero+1;

             i:=i+1;
        end;
       End

      Else

       Begin
        If (i mod x)=0 Then Begin
          nulM[nulcpt]:=M[i];
          nulcpt:=nulcpt+1;
          c:=1;
          i:=i+1;
          if i>0 Then
            zero:=160-x;
        End;

        while (M[i]<>0) and ((i mod x)<>0) do begin
          nulM[nulcpt]:=M[i];
          nulcpt:=nulcpt+1;
          c:=c+1;
          i:=i+1;
        end;


       End;


       if  zero>0 then begin
                    if zero<128 then begin
                                     write(res,'83h,0C7h,',zero,','); {code correspondant a ADD DI,byte }
                                     cycle:=cycle+3;
                                     end
                                else begin
                                     writeln(res,'81h,0C7h');        {code correspondant a ADD DI,word }
                                     writeln(res,'  dw  ',zero);
                                     if i<x*y then
                                      write(res,'  db  ');
                                     cycle:=cycle+3;
                                     end;

               end;

       if  c>0 then begin
         case c of 1 : begin
                        write(res,'0AAh,');      { AA = code de STOSB }
                        cycle:=cycle+5;
                       end;
                   2 : begin
                        write(res,'0ABh,');      { AB = code de STOSW }
                        cycle:=cycle+5;
                       end;
                   3 : begin
                        write(res,'0ABh,0AAh,'); { 3 Octets }
                        cycle:=cycle+10;
                       end;
                   4 : begin
                        write(res,'066h,0ABh,'); { 4 Octets = code de STOSD }
                        cycle:=cycle+10;
                       end;
                   5 : begin
                        write(res,'066h,0ABh,0AAh,'); { 5 Octets }
                        cycle:=cycle+15;
                       end;
                   6 : begin
                        write(res,'066h,0ABh,0ABh,'); { 6 Octets }
                        cycle:=cycle+15;
                       end;
                   7 : begin
                        write(res,'066h,0ABh,0ABh,0AAh,'); { 7 octets }
                       end;
                   8 : begin
                        write(res,'066h,0ABh,066h,0ABh,'); { 8 octets }
                       end;
                   9 : begin
                        write(res,'066h,0ABh,066h,0ABh,0AAh,'); { 9 octets }
                       end;
                   10 : begin
                         write(res,'066h,0ABh,066h,0ABh,0ABh,'); { 10 octets }
                        end;
                   11 : begin
                         write(res,'066h,0ABh,066h,0ABh,0ABh,0AAh,'); { 11 octets }
                        end;                                                       

                   else begin
                         write(res,'0B1h,',c Shr 2,',0F3h,066h,0ABh,');   { MOV CL,x  REP STOSD }
                         cycle:=cycle+5+5+2+(c Shr 1);
                         if (c and 2)=1 Then
                          begin
                           write(res,'0ABh,');      { STOSW ...}
                          end;  
                         if (c and 1)=1 Then
                          begin
                           write(res,'0AAh,');      { STOSB si Impaire }
                           cycle:=cycle+5;
                          end;
                        end;
         end;

       end;


   end;

   close(res);
   writeln('File ',sauve,' has been created ');
   
   sauve_data(nulcpt);     {sauve les data non nulles}

   writeln('1) 20 MHz 286 time : ',cycle,' cycles soit ',Trunc(1000/20*cycle),' ns ');

   Repeat
   Until KeyPressed;

end.
