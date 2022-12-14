{******************************************************************************}
{                                                                              }
{            __________.__                                                     }
{            \______   \  |_________  ____________ ____   ____                 }
{             |     ___/  |  \_  __ \/  _ \___   // __ \ /    \                }
{             |    |   |   Y  \  | \(  <_> )    /\  ___/|   |  \               }
{             |____|   |___|  /__|   \____/_____ \\___  >___|  /               }
{             \/                  \/    \/     \/                              }
{                                                                              }
{                                                                              }
{                   Author: DarkCoderSc (Jean-Pierre LESUEUR)                  }
{                   https://www.twitter.com/                                   }
{                   https://www.phrozen.io/                                    }
{                   https://github.com/darkcodersc                             }
{                   License: Apache License 2.0                                }
{                                                                              }
{                                                                              }
{******************************************************************************}

unit uFunctions;

interface

uses System.Classes,
     System.SysUtils,
     Winapi.Windows,
     VCL.Controls,
     Winapi.PsAPI,
     Winapi.ShellAPI,
     Winapi.ShlObj,
     uWorkerThread;

type
  TArchitecture = (
      archUnknown,
      arch32,
      arch64
  );

  TApplicationExif = record
    CompanyName,
    FileDescription,
    FileVersion,
    InternalName,
    LegalCopyright,
    LegalTrademarks,
    OriginalFileName,
    ProductName,
    ProductVersion,
    Comments,
    PrivateBuild,
    SpecialBuild : string;
  end;

  TLandCodepage = record
    wLanguage,
    wCodePage : word;
  end;
  PLandCodepage = ^TLandCodepage;

function GetWindowsDirectory() : string;
procedure InitializeSystemIcons(var AImages : TImageList; var AFileInfo : TSHFileInfo; ALargeIcon : Boolean = False);
function SystemFileIcon(const AFileName : string; AExtensionMode : Boolean = False) : Integer;
function IsProcessRunningSameArchitecture(const AProcessId : Cardinal) : Boolean;
function IsProcessElevated(const hProcess : THandle) : Boolean;
function IsProcessElevatedById(const AProcessId : Cardinal) : Boolean;
function IsCurrentProcessElevated() : Boolean;
function GetImagePathFromProcessId(const AProcessID : Cardinal) : String;
function FormatSize(const ASize : Int64) : string;
function DELF_GetModuleFileNameEx(const AProcessId : Cardinal; const hModule : THandle) : String; overload;
function DELF_GetModuleFileNameEx(const hProcess, hModule : THandle) : String; overload;
procedure EnumFilesInDirectory(var AFiles : TStringList; ADirectory : String; const AWildCard : String = '*.*'; const ARecursive : Boolean = False; const AThread : TWorkerThread = nil);
function FastPECheck(const AFilePath : String) : Boolean;
procedure Open(const AOpenCommand : String);
procedure FileProperties(const AFileName : String);
function ShowFileOnExplorer(const AFileName : String) : Boolean;
procedure NTSetPrivilege(const APrivilegeName: string; const AEnabled: Boolean);
function GetElevationLabel() : String;
function RunAs(const AFileName : String; const AArgument : String = ''): Boolean;
function BufferToHexView(ABuffer : PVOID; ABufferSize : Int64; pLastOffset : PNativeUINT = nil; AStartOffset : NativeUINT = 0) : String;
function Ternary(const ACondition : Boolean; const APositiveResult, ANegativeResult : String) : String;
procedure GoogleSearch(const ASearchQuery : String);
function GetFileSize(const AFileName : String) : UInt64;
function GetApplicationCompany(const AFileName : String) : String;
function GetApplicationVersion(const AFileName : String) : String;

const PROCESS_QUERY_LIMITED_INFORMATION = $1000;
      MSGFLT_ALLOW                      = 1;

var ChangeWindowMessageFilterEx : function(hwnd : THandle; message : UINT; action : DWORD; pChangeFilterStruct : Pointer) : BOOL; stdcall = nil;

implementation

uses System.Math, System.IOUtils, uExceptions, System.Masks, System.Net.URLClient;

{ _.GetApplicationExif }
function GetApplicationExif(const AFileName : String; var AExifData : TApplicationExif) : Boolean;
var ADummy    : Cardinal;
    ALen      : Cardinal;
    pBlock    : Pointer;
    pBuffer   : Pointer;
    ALanguage : String;
begin
  result := false;
  ///

  ZeroMemory(@AExifData, SizeOf(TApplicationExif));
  ///

  if not FileExists(AFileName) then
    Exit();

  ALen := GetFileVersionInfoSize(PChar(AFileName), ADummy);
  if ALen = 0 then
    Exit();

  GetMem(pBlock, ALen);
  try
    if not GetFileVersionInfo(PChar(AFileName), 0, ALen, pBlock) then
      exit();

    // pBuffer is auto freed (if I can read Win MSDN)
    if not VerQueryValue(pBlock, '\VarFileInfo\Translation\', pBuffer, ALen) then
      exit();

    ALanguage := Format('%.4x%.4x', [
      PLandCodepage(pBuffer)^.wLanguage,
      PLandCodepage(pBuffer)^.wCodePage
    ]);

    if VerQueryValue(pBlock, PWideChar('\StringFileInfo\' + ALanguage + '\CompanyName'), pBuffer, ALen) then
      AExifData.CompanyName := PWideChar(pBuffer);

    if VerQueryValue(pBlock, PWideChar('\StringFileInfo\' + ALanguage + '\FileDescription'), pBuffer, ALen) then
      AExifData.FileDescription := PWideChar(pBuffer);

    if VerQueryValue(pBlock, PWideChar('\StringFileInfo\' + ALanguage + '\FileVersion'), pBuffer, ALen) then
      AExifData.FileVersion := PWideChar(pBuffer);

    if VerQueryValue(pBlock, PWideChar('\StringFileInfo\' + ALanguage + '\InternalName'), pBuffer, ALen) then
      AExifData.InternalName := PWideChar(pBuffer);

    if VerQueryValue(pBlock, PWideChar('\StringFileInfo\' + ALanguage + '\LegalCopyright'), pBuffer, ALen) then
      AExifData.LegalCopyright := PWideChar(pBuffer);

    if VerQueryValue(pBlock, PWideChar('\StringFileInfo\' + ALanguage + '\LegalTrademarks'), pBuffer, ALen) then
      AExifData.LegalTrademarks := PWideChar(pBuffer);

    if VerQueryValue(pBlock, PWideChar('\StringFileInfo\' + ALanguage + '\OriginalFileName'), pBuffer, ALen) then
      AExifData.OriginalFileName := PWideChar(pBuffer);

    if VerQueryValue(pBlock, PWideChar('\StringFileInfo\' + ALanguage + '\ProductName'), pBuffer, ALen) then
      AExifData.ProductName := PWideChar(pBuffer);

    if VerQueryValue(pBlock, PWideChar('\StringFileInfo\' + ALanguage + '\ProductVersion'), pBuffer, ALen) then
      AExifData.ProductVersion := PWideChar(pBuffer);

    if VerQueryValue(pBlock, PWideChar('\StringFileInfo\' + ALanguage + '\Comments'), pBuffer, ALen) then
      AExifData.Comments := PWideChar(pBuffer);

    if VerQueryValue(pBlock, PWideChar('\StringFileInfo\' + ALanguage + '\PrivateBuild'), pBuffer, ALen) then
      AExifData.PrivateBuild := PWideChar(pBuffer);

    if VerQueryValue(pBlock, PWideChar('\StringFileInfo\' + ALanguage + '\SpecialBuild'), pBuffer, ALen) then
      AExifData.SpecialBuild := PWideChar(pBuffer);
  finally
    FreeMem(pBlock);
  end;

  ///
  result := True;
end;

{ _.GetApplicationCompany }
function GetApplicationCompany(const AFileName : String) : String;
var AExif : TApplicationExif;
begin
  result := '';
  ///

  if not FileExists(AFileName) then
    exit();

  if not GetApplicationExif(AFileName, AExif) then
    exit();

  ///
  result := AExif.CompanyName;
end;

{ _.GetApplicationVersion }
function GetApplicationVersion(const AFileName : String) : String;
var AExif : TApplicationExif;
begin
  result := '';
  ///

  if not FileExists(AFileName) then
    exit();

  if not GetApplicationExif(AFileName, AExif) then
    exit();

  ///
  result := AExif.FileVersion;
end;

{ _.GetFileSize }
function GetFileSize(const AFileName : String) : UInt64;
var AFileInfo : TWin32FileAttributeData;
begin
  result := 0;
  ///

  if not FileExists(AFileName) then
    Exit();

  if GetFileAttributesEx(PWideChar(AFileName), GetFileExInfoStandard, @AFileInfo) then
    result := AFileInfo.nFileSizeLow or (AFileInfo.nFileSizeHigh shl 32);
end;

{ _.NTSetPrivilege }
procedure NTSetPrivilege(const APrivilegeName: string; const AEnabled: Boolean);
var AProcessToken   : THandle;
    ATokenPrivilege : TOKEN_PRIVILEGES;
begin
  if not OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, AProcessToken) then
    raise EWindowsException.Create('OpenProcessToken');

  try
    if not LookupPrivilegeValue(nil, PChar(APrivilegeName), ATokenPrivilege.Privileges[0].Luid) then
      raise EWindowsException.Create('LookupPrivilegeValue');

    ATokenPrivilege.PrivilegeCount := 1;

    case AEnabled of
      True  : ATokenPrivilege.Privileges[0].Attributes  := SE_PRIVILEGE_ENABLED;
      False : ATokenPrivilege.Privileges[0].Attributes  := 0;
    end;

    if not AdjustTokenPrivileges(
                                  AProcessToken,
                                  False,
                                  ATokenPrivilege,
                                  SizeOf(TOKEN_PRIVILEGES),
                                  PTokenPrivileges(nil)^,
                                  PDWORD(nil)^
    ) then
      raise EWindowsException.Create('AdjustTokenPrivileges');
  finally
    CloseHandle(AProcessToken);
  end;
end;

{ _.ShowFileOnExplorer }
function ShowFileOnExplorer(const AFileName : String) : Boolean;
var AItemIDList : PItemIDList;
begin
  result := False;
  ///

  if not FileExists(AFileName) then
    Exit();
  ///


  AItemIDList := ILCreateFromPath(PWideChar(AFileName));
  if AItemIDList = nil then
    Exit();
  try
    result := (SHOpenFolderAndSelectItems(AItemIDList, 0, nil, 0) = S_OK);
  finally
    ILFree(AItemIDList);
  end;

  if not result then
    Open(ExtractFilePath(AFileName));
end;

{ _.FileProperties }
procedure FileProperties(const AFileName : String);
var AShellExecInfo : TShellExecuteInfo;
begin
  ZeroMemory(@AShellExecInfo, SizeOf(TShellExecuteInfo));
  ///

  AShellExecInfo.cbSize := SizeOf(AShellExecInfo);
  AShellExecInfo.lpFile := PWideChar(AFileName);
  AShellExecInfo.lpVerb := 'properties';
  AShellExecInfo.fMask  := SEE_MASK_INVOKEIDLIST;

  ShellExecuteEx(@AShellExecInfo);
end;

{ _.GoogleSearch }
procedure GoogleSearch(const ASearchQuery : String);
begin
  Open(Format('https://www.google.com/search?q=%s', [
    TURI.URLEncode(ASearchQuery, True)
  ]));
end;

{ _.Open }
procedure Open(const AOpenCommand : String);
begin
  ShellExecute(0, 'open', PWideChar(AOpenCommand), nil, nil, SW_SHOW);
end;

{ _.GetWindowsDirectory }
function GetWindowsDirectory() : string;
var ALen  : Cardinal;
begin
  SetLength(result, MAX_PATH);

  ALen := WinAPI.Windows.GetWindowsDirectory(@result[1], MAX_PATH);

  SetLength(result, ALen);
  if ALen > MAX_PATH then
    WinAPI.Windows.GetWindowsDirectory(@result[1], ALen);

  ///
  result := IncludeTrailingPathDelimiter(result);
end;

{ _.InitializeSystemIcons }
procedure InitializeSystemIcons(var AImages : TImageList; var AFileInfo : TSHFileInfo; ALargeIcon : Boolean = False);
var AFlags : Integer;
begin
  ZeroMemory(@AFileInfo, SizeOf(TSHFileInfo));
  ///

  if ALargeIcon then
    AFlags := SHGFI_LARGEICON
  else
    AFlags := SHGFI_SMALLICON;

  AImages.Handle := SHGetFileInfo(
                                    PChar(TPath.GetPathRoot(GetWindowsDirectory())),
                                    0,
                                    AFileInfo,
                                    SizeOf(AFileInfo),
                                    AFlags or (SHGFI_SYSICONINDEX)
  );
end;

{ _.SystemFileIcon }
function SystemFileIcon(const AFileName : string; AExtensionMode : Boolean = False) : Integer;
var AFileInfo : TSHFileInfo;
    AFlags    : Integer;
begin
  ZeroMemory(@AFileInfo, sizeof(AFileInfo));
  ///

  AExtensionMode := AFileName.IsEmpty or (not FileExists(AFileName));

  AFlags := SHGFI_SMALLICON or SHGFI_SYSICONINDEX;
  if AExtensionMode then
    AFlags := AFlags or SHGFI_USEFILEATTRIBUTES;

  SHGetFileInfo(PWideChar(AFileName), 0, AFileInfo, SizeOf(AFileInfo), AFlags);

  Result := AFileInfo.iIcon;
end;

{ _.GetProcessArchitecture }
function GetProcessArchitecture(const AProcessId : Cardinal) : TArchitecture;
var hProcess : THandle;
    AWow64Process : bool;
begin
  result := archUnknown;
  ///

  if (TOSVersion.Architecture = arIntelX86) then
    Exit(arch32);
  ///

  hProcess := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, AProcessId);
  if hProcess = 0 then
    raise EWindowsException.Create('OpenProcess');
  try
    IsWow64Process(hProcess, AWow64Process);
    ///

    if AWow64Process then
      result := arch32
    else
      result := arch64;
  finally
    CloseHandle(hProcess);
  end;
end;

{ _.IsProcessRunningSameArchitecture }
function IsProcessRunningSameArchitecture(const AProcessId : Cardinal) : Boolean;
var ACurrent64    : Boolean;
    AProcess64    : Boolean;
    AArchitecture : TArchitecture;
begin
  {$IFDEF WIN64}
    ACurrent64 := True;
  {$ELSE IF WIN32}
    ACurrent64 := False;
  {$ENDIF}

  AArchitecture := GetProcessArchitecture(AProcessId);
  if AArchitecture = archUnknown then
    raise Exception.Create('Could not resolve process architecture');

  AProcess64 := (AArchitecture = arch64);

  ///
  result := (ACurrent64 = AProcess64);
end;

{ _.IsProcessElevated }
function IsProcessElevated(const hProcess : THandle) : Boolean;
var AToken     : THandle;
    AElevation : DWORD;
    ALength    : Cardinal;

const ATokenForElevation = 20;
begin
  result := True;
  ///

  if NOT OpenProcessToken(hProcess, TOKEN_QUERY, AToken) then
    raise EWindowsException.Create('OpenProcessToken');
  try
    if NOT GetTokenInformation(AToken, TTokenInformationClass(ATokenForElevation), @AElevation, SizeOf(DWORD), ALength) then
      raise EWindowsException.Create('GetTokenInformation');

    result := (AElevation <> 0);
  finally
    CloseHandle(AToken);
  end;
end;

{ _.IsProcessElevatedById }
function IsProcessElevatedById(const AProcessId : Cardinal) : Boolean;
var hProcess : THandle;
begin
  result := True;
  ///

  if (Win32MajorVersion < 6) then
    Exit();

  hProcess := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, AProcessId);
  if hProcess = 0 then
    raise EWindowsException.Create('OpenProcess');
  try
    result := IsProcessElevated(hProcess);
  finally
    CloseHandle(hProcess);
  end;
end;

{ _.IsCurrentProcessElevated }
function IsCurrentProcessElevated() : Boolean;
begin
  result := IsProcessElevated(GetCurrentProcess());
end;

{ _.GetImagePathFromProcessId }
function GetImagePathFromProcessId(const AProcessID : Cardinal) : String;
var hProcess    : THandle;
    ACBNeeded   : Cardinal;
    hMainModule : THandle;
begin
  result := '';

  hProcess := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, AProcessId);
  if hProcess = 0 then
    raise EWindowsException.Create(Format('OpenProcess[pid: %d]', [AProcessId]));
  try
    if not EnumProcessModules(hProcess, @hMainModule, SizeOf(HMODULE), ACBNeeded) then
      raise EWindowsException.Create(Format('EnumProcessModules[pid: %d]', [AProcessId]));
    ///

    result := DELF_GetModuleFileNameEx(hProcess, hMainModule);
  finally
    CloseHandle(hProcess);
  end;
end;

{ _.DELF_GetModuleFileNameEx }
function DELF_GetModuleFileNameEx(const hProcess, hModule : THandle) : String;
var ALength         : Cardinal;
    AReturnedLength : Cardinal;
begin
  result := '';
  ///

  ALength := MAX_PATH * 2;

  SetLength(result, ALength);
  try
    AReturnedLength := GetModuleFileNameExW(hProcess, hModule, PWideChar(result), ALength);
    if AReturnedLength = 0 then
      raise EWindowsException.Create('GetModuleFileNameExW');
  finally
    SetLength(result, AReturnedLength);
  end;
end;

{ _.DELF_GetModuleFileNameEx }
function DELF_GetModuleFileNameEx(const AProcessId : Cardinal; const hModule : THandle) : String;
var hProcess : THandle;
begin
  result := '';
  ///

  hProcess := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, AProcessId);
  if hProcess = 0 then
    raise EWindowsException.Create(Format('OpenProcess[pid: %d]', [AProcessId]));
  try
    result := DELF_GetModuleFileNameEx(hProcess, hModule);
  finally
    if hProcess <> INVALID_HANDLE_VALUE then
      CloseHandle(hProcess);
  end;
end;

{ _.FormatSize }
function FormatSize(const ASize : Int64) : string;
const AByteDescription : Array[0..8] of string = ('Bytes', 'KiB', 'MB', 'GiB', 'TB', 'PB', 'EB', 'ZB', 'YB');

var ACount : Integer;
begin
  ACount := 0;

  while ASize > Power(1024, ACount +1) do
    Inc(ACount);

  result := Format('%s %s', [FormatFloat('###0.00', ASize / Power(1024, ACount)), AByteDescription[ACount]]);
end;

{ _.EnumFilesInDirectory }
procedure EnumFilesInDirectory(var AFiles : TStringList; ADirectory : String; const AWildCard : String = '*.*'; const ARecursive : Boolean = False; const AThread : TWorkerThread = nil);
var ASearch      : TSearchRec;
    AFilePath    : String;
    AIsDirectory : Boolean;
begin
  if not Assigned(AFiles) then
    Exit();
  ///

  ADirectory := IncludeTrailingPathDelimiter(ADirectory);
  ///

  if System.SysUtils.FindFirst(Format('%s*.*', [ADirectory, AWildCard]), faAnyFile, ASearch) <> 0 then
    Exit();
  try
    repeat
      if Assigned(AThread) then begin
        if AThread.IsTerminated then
          break;
      end;

      if (ASearch.Name = '.') or (ASearch.Name = '..') then
        continue;
      ///

      AFilePath := Format('%s%s', [ADirectory, ASearch.Name]);
      ///

      AIsDirectory := (ASearch.Attr and faDirectory) <> 0;

      if (not AIsDirectory) and (MatchesMask(ASearch.Name, AWildCard)) then
        AFiles.Add(AFilePath);

      if AIsDirectory and ARecursive then
        EnumFilesInDirectory(AFiles, AFilePath, AWildCard, ARecursive);
    until System.SysUtils.FindNext(ASearch) <> 0;
  finally
    System.SysUtils.FindClose(ASearch);
  end;
end;

{ _.FastPECheck }
function FastPECheck(const AFilePath : String) : Boolean;
var hFile             : THandle;

    AImageDosHeader   : TImageDosHeader;
    AImageNtSignature : DWORD;
    AImageFileHeader  : TImageFileHeader;

    ABytesRead        : Cardinal;
begin
  result := False;
  ///

  hFile := CreateFileW(
      PWideChar(AFilePath),
      GENERIC_READ,
      FILE_SHARE_READ,
      nil,
      OPEN_EXISTING,
      0,
      0
  );
  if hFile = INVALID_HANDLE_VALUE then
    Exit();
  try
    if not ReadFile(hFile, AImageDosHeader, SizeOf(TImageDosHeader), ABytesRead, nil) then
      Exit();

    if AImageDosHeader.e_magic <> IMAGE_DOS_SIGNATURE then
      Exit();

    SetFilePointerEx(hFile, AImageDosHeader._lfanew, nil, FILE_BEGIN);

    if not ReadFile(hFile, AImageNtSignature, SizeOf(DWORD), ABytesRead, nil) then
      Exit();

    if AImageNtSignature <> IMAGE_NT_SIGNATURE then
      Exit();

    if not ReadFile(hFile, AImageFileHeader, SizeOf(TImageFileHeader), ABytesRead, nil) then
      Exit();

    {$IFDEF WIN64}
      if AImageFileHeader.Machine <> IMAGE_FILE_MACHINE_AMD64 then
    {$ELSE}
      if AImageFileHeader.Machine <> IMAGE_FILE_MACHINE_I386 then
    {$ENDIF}
      Exit();

    ///
    result := True;
  finally
    CloseHandle(hFile);
  end;
end;

{ _.GetElevationLabel }
function GetElevationLabel() : String;
begin
  result := 'Unprivileged';
  ///

  if Win32MajorVersion >= 6 then begin
    if IsUserAnAdmin() then
      result := 'Administrator'
  end;
end;

{ _.RunAs }
function RunAs(const AFileName : String; const AArgument : String = ''): Boolean;
var AOperation : String;
begin
  if Win32MajorVersion >= 6 then
    AOperation := 'RunAs'
  else
    AOperation := 'open';

  ///
  result := NOT (ShellExecute(
                                0,
                                PChar(AOperation),
                                PChar(AFileName),
                                PChar(AArgument),
                                nil,
                                SW_SHOW
  ) <= 32);
end;

{ _.BufferToHexView }
function BufferToHexView(ABuffer : PVOID; ABufferSize : Int64; pLastOffset : PNativeUINT = nil; AStartOffset : NativeUINT = 0) : String;
var ARows     : DWORD;
    i, n      : integer;
    AVal      : Byte;
    sBuilder  : TStringBuilder;
    HexVal    : array[0..16-1] of TVarRec;
    AsciiVal  : array[0..16-1] of TVarRec;
    HexMask   : String; {%x}
    AsciiMask : String; {%s}

begin
  result := '';

  ///
  ARows := ceil(ABufferSize / 16);

  sBuilder := TStringBuilder.Create();
  try
    {
      Row
    }
    for I := 0 to ARows -1 do begin
      {
        Col
      }
      for n := 0 to 16-1 do begin
        AVal := PByte(NativeUInt(ABuffer) + (I * 16) + n)^;

        HexVal[n].VType    := vtInteger;
        HexVal[n].VInteger := AVal;

        AsciiVal[n].VType := vtChar;
        if AVal in [32..255] then begin
          AsciiVal[n].VChar := AnsiChar(AVal);
        end else begin
          AsciiVal[n].VChar := '.';
        end;
      end;

      HexMask   := '';
      AsciiMask := '';
      for n := 0 to 16-1 do begin
        if ((I * 16) + n) > ABufferSize then begin
          HexMask   := HexMask   + #32#32#32;
          AsciiMask := AsciiMask + #32#32;

          continue;
        end;

        HexMask   := HexMask + '%.2x' + #32;
        AsciiMask := AsciiMask + '%s';
      end;
      Delete(HexMask, length(HexMask), 1);

      {
        Draw
      }
      sBuilder.AppendLine(
          Format('%.8x', [AStartOffset + (I * 16)]) + '|' +
          Format(HexMask, HexVal) + '|' +
          Format(AsciiMask, AsciiVal)
      );
    end;
  finally
    result := sBuilder.ToString();

    if Assigned(pLastOffset) then begin
      pLastOffset^ := (ARows * 16);
    end;

    sBuilder.Free;
  end;
end;

{ _.Ternary }
function Ternary(const ACondition : Boolean; const APositiveResult, ANegativeResult : String) : String;
begin
  if ACondition then
    result := APositiveResult
  else
    result := ANegativeResult;
end;

initialization
  ChangeWindowMessageFilterEx := GetProcAddress(GetModuleHandle('user32.dll'), 'ChangeWindowMessageFilterEx');

finalization
  ChangeWindowMessageFilterEx := nil;

end.
