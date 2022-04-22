PROGRAM buildstrechh;
uses crt;
const haut : byte =100;
      long : byte =140;
type stretchtyp = array [0..17860] of word;
     shadetyp= array [0..17860] of byte;
var source : ^stretchtyp;
    dest : ^stretchtyp;
    shade : ^shadetyp;
    fich2 : file of shadetyp;
    fich : file of stretchtyp;
    taille : word;
    x,y,i : word;
    incr : word;
    r,xx : real;
    ch : char;
    table : array [0..152] of byte;

BEGIN
  new(source);
  new(dest);
  new(shade);
  textmode(CO80);
  textcolor(red);
  textbackground(0);
  clrscr;
  r:=5;
  xx:=0;
  for i:=0 to haut-1 do
  begin
    r:=r-4.25/152;
    xx:=xx+r;
    table[i]:=round(xx/3/145*169)-2;
    writeln(table[i]);
  end;
  writeln('bonjour');
  taille:=0;
  incr:=0;
  
  for y:=0 to haut-1 do
  begin
    for x:=0 to round(320-(2*(haut-y)/(haut)*long))-1 do
    begin
      inc(incr);
      source^[incr]:=round((table[y]+x/(320-(2*(haut-y)*long/haut)))*320);
    end;
  end;
  writeln(incr);
  incr:=0;
  
  for y:=0 to haut-1 do
  begin
    for x:=0 to round(320-(2*(haut-y)/haut*long))-1 do
    begin
      inc(incr);
      dest^[incr]:=y*80+16000*(round((x+(haut-y)/haut*long)) mod 4)+(round((x+(haut-y)/haut*long)) div 4);
    end;
  end;
  incr:=0;
  
  for y:=0 to haut-1 do
  begin
    for x:=0 to round(320-(2*(haut-y)/haut*long))-1 do
     begin
      inc(incr);
      shade^[incr]:=trunc(y/haut*17)*13;
    end;
  end;

  assign(fich,'source.cal');
  rewrite(fich);
  write(fich,source^);
  close(fich);

  assign(fich,'dest.cal');
  rewrite(fich);
  write(fich,dest^);
  close(fich);

  assign(fich2,'shade.cal');
  rewrite(fich2);
  write(fich2,shade^);
  close(fich2);

  dispose(source);
  dispose(dest);
  dispose(shade);
END.
