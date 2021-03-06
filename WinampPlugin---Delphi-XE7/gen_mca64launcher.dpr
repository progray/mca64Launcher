library gen_mca64launcher;
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$WEAKLINKRTTI ON}

uses
  System.Classes, Messages, SySUtils, Windows, System.IOUtils;

type

  TWinampGeneralPurposePlugin = record
    wersja: integer;
    opis: PAnsiChar;
    InitFunkcja: function: integer; cdecl;
    KonfiguracjaProcedura: procedure; cdecl;
    WyjscieProcedura: procedure; cdecl;
    uchwyt: HWND;
    hDll: THandle;
  end;

  PWinampGeneralPurposePlugin = ^TWinampGeneralPurposePlugin;

  THookNaKomunikaty = class
  private
    fWndProc: TFNWndProc;
    fWndProcInst: Pointer;
    fUruchomWatek: boolean;
    procedure WndProcSubClassed(var komunikat: TMessage);
    procedure CofniecieHooka;
  public
    fUchwyt: HWND;
    property pUruchomWatek: boolean read fUruchomWatek write fUruchomWatek;
    constructor Create;
  end;

  TZapiszListe = class(TThread)
  protected
    procedure Execute; override;
  end;

function Init: integer; cdecl; forward;
procedure Konfiguracja; cdecl; forward;
procedure Wyjscie; cdecl; forward;

var
  n: integer;
  hookNaKomunikaty: THookNaKomunikaty;

const
  WM_WA_IPC = WM_USER;
  IPC_GETPLAYLISTFILE = 211;
  IPC_GETPLAYLISTTITLE = 212;
  IPC_GETPLAYLISTTITLEW = 213;
  IPC_GETLISTPOS = 125;
  IPC_SETVOLUME = 122;
  IPC_GETLISTLENGTH = 124;
  IPC_PLAYLIST_MODIFIED = 3002;
  IPC_PLAYING_FILE = 3003;
  winampPlugin: TWinampGeneralPurposePlugin = (wersja: $10; opis: 'mca64Launcher'; InitFunkcja: Init; KonfiguracjaProcedura: Konfiguracja;
    WyjscieProcedura: Wyjscie; uchwyt: 0; hDll: 0;);

procedure THookNaKomunikaty.WndProcSubClassed(var komunikat: TMessage);
begin
  if komunikat.lParam = IPC_PLAYLIST_MODIFIED then
  begin
    if not fUruchomWatek then
    begin
      fUruchomWatek := true;
      TZapiszListe.Create;
    end;
    n := n + 1;
  end;
  komunikat.Result := CallWindowProc(fWndProc, fUchwyt, komunikat.Msg, komunikat.WParam, komunikat.lParam);
end;

procedure THookNaKomunikaty.CofniecieHooka;
begin
  SetWindowlong(fUchwyt, GWL_WNDPROC, NativeInt(fWndProc));
  FreeObjectInstance(fWndProcInst);
  fWndProc := nil;
  fWndProcInst := nil;
end;

constructor THookNaKomunikaty.Create;
begin
  fUchwyt := FindWindow('Winamp v1.x', nil); // winampPlugin.uchwyt;
  fWndProc := TFNWndProc(GetWindowLong(fUchwyt, GWL_WNDPROC));
  fWndProcInst := MakeObjectInstance(WndProcSubClassed);
  SetWindowlong(fUchwyt, GWL_WNDPROC, NativeInt(fWndProcInst));
end;

function Init: integer; cdecl;
begin
  Init := 0;
end;

procedure Konfiguracja; cdecl;
begin
  MessageBox(0, PWideChar('Licznik zmian listy odtwarzania: ' + IntToStr(n) + #13#10 + TPath.GetTempPath + 'mca64Launcher_Winamp.txt'),
    'mca64Launcher', MB_ICONINFORMATION);
end;

procedure Wyjscie; cdecl;
begin
  hookNaKomunikaty.CofniecieHooka;
end;

procedure TZapiszListe.Execute;
var
  i: integer;
  wpis: PAnsiChar;
  lista: AnsiString;
  dlugoscListy: integer;
  plik: TStringList;
  plikUchwyt: TStringList;
  mca64Launcher: HWND;
  doWyslania: TCopyDataStruct;
  tekst: AnsiString;
begin
  sleep(3000);
  hookNaKomunikaty.pUruchomWatek := false;
  dlugoscListy := SendMessage(hookNaKomunikaty.fUchwyt, WM_WA_IPC, 0, IPC_GETLISTLENGTH); // winampPlugin.uchwyt
  for i := 0 to dlugoscListy - 1 do
  begin
    wpis := Pointer(SendMessage(hookNaKomunikaty.fUchwyt, WM_WA_IPC, i, IPC_GETPLAYLISTTITLE));
    lista := lista + wpis + #13#10;
  end;
  plik := TStringList.Create;
  try
    plik.Add(String(lista));
    try
      plik.SaveToFile(TPath.GetTempPath + 'mca64Launcher_Winamp.txt');
      plikUchwyt := TStringList.Create;
      try
        plikUchwyt.LoadFromFile(TPath.GetTempPath + 'mca64Launcher_uchwyt.txt');
        mca64Launcher := StrToInt(plikUchwyt.Strings[0]);
        tekst := 'gen_mca64Launcher';
        doWyslania.dwData := hookNaKomunikaty.fUchwyt;
        doWyslania.cbData := Length(tekst) + 1;
        doWyslania.lpData := PAnsiChar(tekst);
        SendMessage(mca64Launcher, WM_COPYDATA, NativeInt(Handle), NativeInt(@doWyslania));
      finally
        plikUchwyt.Free;
      end;
    except

    end;
  finally
    plik.Free;
  end;
end;

function winampGetGeneralPurposePlugin: PWinampGeneralPurposePlugin; cdecl;
begin
  winampGetGeneralPurposePlugin := @winampPlugin;
  TZapiszListe.Create;
  hookNaKomunikaty := THookNaKomunikaty.Create;
end;

exports
  winampGetGeneralPurposePlugin;

end.
