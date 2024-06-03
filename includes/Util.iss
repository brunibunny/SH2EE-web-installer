// Inno Setup - Util.iss

[Code]
var
  isCompSizesFilled  : Boolean;
  RunListLastChecked : Integer;
  GCS_sh2pcPath      : string;

function ShellExecute(hwnd: HWND; lpOperation: string; lpFile: string;
  lpParameters: string; lpDirectory: string; nShowCmd: Integer): THandle;
  external 'ShellExecuteW@shell32.dll stdcall';

procedure ExitProcess(uExitCode: Integer);
  external 'ExitProcess@kernel32.dll stdcall';

function BytesToString(size: Int64): PAnsiChar; 
  external 'BytesToString@files:BytesToString.dll cdecl';

// Used to detect if the user is using WINE or not
function LoadLibraryA(lpLibFileName: PAnsiChar): THandle;
external 'LoadLibraryA@kernel32.dll stdcall';
function GetProcAddress(Module: THandle; ProcName: PAnsiChar): Longword;
external 'GetProcAddress@kernel32.dll stdcall';
function IsWine: boolean;
var  LibHandle  : THandle;
begin
  LibHandle := LoadLibraryA('ntdll.dll');
  Result:= GetProcAddress(LibHandle, 'wine_get_version')<> 0;
end;

function Max(A, B: Integer): Integer;
begin
  if A > B then
    Result := A
  else
    Result := B;
end;

function Min(A, B: Integer): Integer;
begin
  if A < B then
    Result := A
  else
    Result := B;
end;

procedure GetComponentSizes();
var
  i: integer;
begin
  if isCompSizesFilled then
  begin
    Log('GetComponentSizes: Sizes already filled, returning');
    Exit;
  end;

  if selfUpdateMode then
  begin
    Log('GetComponentSizes: selfUpdateMode, no need to get sizes, returning');
    Exit;
  end;

  if not localInstallMode then
  begin
    // Get file sizes from host, exit if we fail for some reason
    SetArrayLength(FileSizeArray, GetArrayLength(WebCompsArray) - 1);
    for i := 0 to GetArrayLength(WebCompsArray) - 1 do
    begin
      if not (WebCompsArray[i].id = 'setup_tool') then
      begin
        if not idpGetFileSize(WebCompsArray[i].URL, FileSizeArray[i - 1].Bytes) then
          begin
            MsgBox(CustomMessage('FailedToQueryComponents'), mbCriticalError, MB_OK);
            ExitProcess(1);
          end;
        FileSizeArray[i - 1].String := BytesToString(FileSizeArray[i - 1].Bytes);
        if {#DEBUG} then Log('# ' + WebCompsArray[i].ID + ' size = ' + FileSizeArray[i - 1].String);
      end;
    end;
  end else
  begin
    // Get sizes from local files, exit if we fail for some reason
    SetArrayLength(FileSizeArray, GetArrayLength(LocalCompsArray));
    for i := 0 to GetArrayLength(LocalCompsArray) - 1 do
    begin
      if not (LocalCompsArray[i].id = 'setup_tool') then
      begin
        if not (LocalCompsArray[i].fileName = 'notDownloaded') and not FileSize64(ExpandConstant('{src}\') + LocalCompsArray[i].fileName, FileSizeArray[i - 1].Bytes) then
          begin
            MsgBox(CustomMessage('FailedToQueryComponents2'), mbCriticalError, MB_OK);
            ExitProcess(1);
          end;
        FileSizeArray[i - 1].String := BytesToString(FileSizeArray[i - 1].Bytes);
        if {#DEBUG} then Log('# ' + LocalCompsArray[i].ID + ' size = ' + FileSizeArray[i - 1].String);
      end;
    end;
  end;

  isCompSizesFilled := True;
end;

// Determines if there is enough free space on a drive of a specific folder
function IsEnoughFreeSpace(const Path: string; MinSpace: Int64): Boolean;
var
  FreeSpace, TotalSpace: Int64;
begin
  if GetSpaceOnDisk64(ExtractFileDrive(Path), FreeSpace, TotalSpace) then
  begin
    Log('# FreeSpace = ' + BytesToString(FreeSpace));
    Log('# MinSpace = ' + BytesToString(MinSpace));
    Result := FreeSpace >= MinSpace;
  end
  else
    RaiseException('Failed to check free space.');
end;

// Returns true if the setup was started with a specific parameter
function CmdLineParamExists(const Value: string): Boolean;
var
  I: Integer;  
begin
  Result := False;
  for I := 1 to ParamCount do
    if CompareText(ParamStr(I), Value) = 0 then
    begin
      Result := True;
      Exit;
    end;
end;

// String to boolean -- ** Already defined in idp.iss. UNCOMMENT IF NOT USING IDP
// function StrToBool(value: String): Boolean;
// var s: String;
// begin
//     s := LowerCase(value);
// 
//     if      s = 'true'  then result := true
//     else if s = 't'     then result := true
//     else if s = 'yes'   then result := true
//     else if s = 'y'     then result := true
//     else if s = 'false' then result := false
//     else if s = 'f'     then result := false
//     else if s = 'no'    then result := false
//     else if s = 'n'     then result := false
//     else                     result := StrToInt(value) > 0;
// end;

// Given a text filename, replace a string with another
function FileReplaceString(const FileName, SearchString, ReplaceString: string): Boolean;
var
  MyFile : TStrings;
  MyText : string;
begin
  MyFile := TStringList.Create;

  try
    result := true;

    try
      MyFile.LoadFromFile(FileName);
      MyText := MyFile.Text;

      { Only save if text has been changed. }
      if StringChangeEx(MyText, SearchString, ReplaceString, True) > 0 then
      begin;
        MyFile.Text := MyText;
        MyFile.SaveToFile(FileName);
      end;
    except
      result := false;
    end;
  finally
    MyFile.Free;
  end;
end;

// BoolToStr Helper function
function BoolToStr(Value: Boolean): String; 
begin
  if Value then Result := 'true'
  else Result := 'false';
end;

// Wrapper function for returning a path relative to {tmp}
function tmp(Path: String): String;
begin
  Result := ExpandConstant('{tmp}\') + Path;
end;

// Wrapper function for returning a path to files based on weather or no the user wants to backup the files
function localDataDir(Path: String): String;
begin
  if (Length(userPackageDataDir) = 0) then Result := ExpandConstant('{tmp}\') + Path
  else Result := userPackageDataDir + '\' + Path; 

  Log(Result);
end;

// When one checkbox is checked, all others get unchecked
procedure RunListClickCheck(Sender: TObject);
var
  I: Integer;
  Checked: Integer;
begin
  { Find if some other checkbox got checked }
  Checked := -1;
  for I := 0 to WizardForm.RunList.Items.Count - 1 do
  begin
    if WizardForm.RunList.Checked[I] and (I <> RunListLastChecked) then
    begin
      Checked := I;
    end;
  end;

  { If it was, uncheck the previously checked box and remember the new one }
  if Checked >= 0 then
  begin
    if RunListLastChecked >= 0 then
    begin
      WizardForm.RunList.Checked[RunListLastChecked] := False;
    end;

    RunListLastChecked := Checked;
  end;

  { Or if the previously checked box got unchecked, forget it. }
  { (This is not really necessary, it's just to clean the things up) }
  if (RunListLastChecked >= 0) and
     (not WizardForm.RunList.Checked[RunListLastChecked]) then
  begin
    RunListLastChecked := -1;
  end;
end;

// Search for sh2pc.exe in "\HKEY_CURRENT_USER\System\GameConfigStore\Children\"
procedure RegSearch(RootKey: Integer; KeyName: string);
var
  I: Integer;
  Names: TArrayOfString;
  Name: string;
  FoundPaths: String;
begin
  if RegGetSubkeyNames(RootKey, KeyName, Names) then
  begin
    for I := 0 to GetArrayLength(Names) - 1 do
    begin
      Name := KeyName + '\' + Names[I];

      //if {#DEBUG} then Log(Format('Found key %s', [Name]));

      RegSearch(RootKey, Name);
    end;
  end;

  if RegGetValueNames(RootKey, KeyName, Names) then
  begin
    for I := 0 to GetArrayLength(Names) - 1 do
    begin
      Name := KeyName + '\' + Names[I];

      if Pos('MatchedExeFullPath', Name) > 0 then
      begin
        //if {#DEBUG} then Log(Format('Found value %s', [Name]));

        if RegQueryStringValue(HKEY_CURRENT_USER, KeyName, 'MatchedExeFullPath', FoundPaths) then
        begin
          //if {#DEBUG} then Log(Format('Found Path %s', [FoundPaths]));

          if Pos('sh2pc.exe', FoundPaths) > 0 then
          begin
            if FileExists(ExtractFilePath(FoundPaths) + '\sh2pc.exe') then
            begin
              if {#DEBUG} then Log(Format('sh2pc.exe found at: %s', [FoundPaths]));
              GCS_sh2pcPath := ExtractFilePath(FoundPaths);
            end;
          end;
        end;
      end;
    end;
  end;
end;

// Return a DefaultDirName based on conditions
function GetDefaultDirName(Param: string): string;
var 
  InstallationPath : String;
  RetailInstallDir : String;
begin
  if InstallationPath = '' then
  begin
    // Search registry if we're not in maintenance mode
    if not maintenanceMode then 
      RegSearch(HKEY_CURRENT_USER, 'System\GameConfigStore');

    // Actually choose a path
    if maintenanceMode or FileExists(ExpandConstant('{src}\') + 'data\pic\etc\konami.tex') then
      InstallationPath := ExpandConstant('{src}\')
    else
    if RegQueryStringValue(HKLM32, 'Software\Konami\Silent Hill 2', 'INSTALLDIR', RetailInstallDir) and FileExists(RetailInstallDir + '\sh2pc.exe') then 
      InstallationPath := RetailInstallDir
    else
    if not (GCS_sh2pcPath = '') then
      InstallationPath := GCS_sh2pcPath
    else
      InstallationPath := ExpandConstant('{autopf}\') + 'Konami\Silent Hill 2\'; 
  end;
  Result := InstallationPath;
end;

// Recursive function called by SplitString
function SplitStringRec(Str: String; Delim: String; StrList: TStringList): TStringList;
var
  StrHead: String;
  StrTail: String;
  DelimPos: Integer;
begin
  DelimPos := Pos(Delim, Str);
  if DelimPos = 0 then begin
    StrList.Add(Str);
    Result := StrList;
  end else begin
    StrHead := Str;
    StrTail := Str;
    Delete(StrHead, DelimPos, Length(StrTail));
    Delete(StrTail, 1, DelimPos);
    StrList.Add(StrHead);
    Result := SplitStringRec(StrTail, Delim, StrList);
  end;
end;
// Given a string and a delimiter, returns the strings separated by the delimiter
// as a TStringList object
function SplitString(Str: String; Delim: String): TStringList;
begin
  Result := SplitStringRec(Str, Delim, TStringList.Create);
end;

// Given a .ini file, return an array of settings corresponding to
// the data in the ini file.
function IniToSettingsArray(Filename: string): array of TIniArray;
var
  Rows: TArrayOfString;
  IniSection: string;
  i: Integer;
begin
  if LoadStringsFromFile(Filename, Rows) then
  begin
    SetArrayLength(Result, 0);
    for i := 0 to GetArrayLength(Rows) - 1 do
    begin
      if (Rows[i] <> '') and (Rows[i][1] = '[') then
      begin
        IniSection := Copy(Rows[i], 2, Length(Rows[i]) - 2);
      end
      else if (Pos('=', Rows[i]) > 0) and (IniSection <> '') and (Rows[i][1] <> ';') then
      begin
        SetArrayLength(Result, GetArrayLength(Result) + 1);
        Result[GetArrayLength(Result) - 1].Section := IniSection;
        Result[GetArrayLength(Result) - 1].Key := Trim(Copy(Rows[i], 1, Pos('=', Rows[i]) - 1));
        Result[GetArrayLength(Result) - 1].Value := Trim(Copy(Rows[i], Pos('=', Rows[i]) + 1, MaxInt));
      end;
    end;
  end;
end;

// Recursive function called by GetURLFilePart
function GetURLFilePartRec(URL: String): String;
var
  SlashPos: Integer;
begin
  SlashPos := Pos('/', URL);
  if SlashPos = 0 then begin
    Result := URL;
  end else begin;
    Delete(URL, 1, SlashPos);
    Result := GetURLFilePartRec(URL);
  end;
end;

// Given a URL to a file, returns the filename portion of the URL
function GetURLFilePart(URL: String): String;
begin
  Delete(URL, 1, Pos('://', URL) + 2);
  Result := GetURLFilePartRec(URL);
end;