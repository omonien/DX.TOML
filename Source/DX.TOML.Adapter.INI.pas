{*******************************************************************************
  DX.TOML.Adapter.INI - INI File Adapter

  Description:
    Provides INI file compatibility by treating INI as a subset of TOML.
    This is an ADAPTER - INI is not part of the core TOML implementation.

    Design principle: INI as use case, not architecture.

  Usage:
    var
      LIni: TTomlIniFile;
    begin
      LIni := TTomlIniFile.Create('config.ini');
      try
        LValue := LIni.ReadString('Section', 'Key', 'Default');
        LIni.WriteString('Section', 'Key', 'NewValue');
        LIni.UpdateFile;
      finally
        LIni.Free;
      end;
    end;

  Author: DX.TOML Project
  License: MIT
*******************************************************************************}
unit DX.TOML.Adapter.INI;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  DX.TOML,
  DX.TOML.DOM;

type
  /// <summary>INI file adapter using TOML backend</summary>
  /// <remarks>
  /// This adapter treats INI files as a simplified TOML format:
  /// - [Section] becomes TOML table
  /// - Key=Value becomes TOML key-value pair
  /// - Comments are preserved (# or ;)
  /// </remarks>
  TTomlIniFile = class
  private
    FFileName: string;
    FTable: TToml;
    FModified: Boolean;

    procedure LoadFromFile;
    procedure SaveToFile;
    function GetSection(const ASection: string): TToml;
    function ConvertIniToToml(const AIniContent: string): string;
    function ConvertTomlToIni(const ATomlContent: string): string;
  public
    constructor Create(const AFileName: string);
    destructor Destroy; override;

    /// <summary>Read a string value from INI file</summary>
    function ReadString(const ASection, AKey, ADefault: string): string;

    /// <summary>Write a string value to INI file</summary>
    procedure WriteString(const ASection, AKey, AValue: string);

    /// <summary>Read an integer value from INI file</summary>
    function ReadInteger(const ASection, AKey: string; ADefault: Integer): Integer;

    /// <summary>Write an integer value to INI file</summary>
    procedure WriteInteger(const ASection, AKey: string; AValue: Integer);

    /// <summary>Read a boolean value from INI file</summary>
    function ReadBool(const ASection, AKey: string; ADefault: Boolean): Boolean;

    /// <summary>Write a boolean value to INI file</summary>
    procedure WriteBool(const ASection, AKey: string; AValue: Boolean);

    /// <summary>Read a float value from INI file</summary>
    function ReadFloat(const ASection, AKey: string; ADefault: Double): Double;

    /// <summary>Write a float value to INI file</summary>
    procedure WriteFloat(const ASection, AKey: string; AValue: Double);

    /// <summary>Check if section exists</summary>
    function SectionExists(const ASection: string): Boolean;

    /// <summary>Check if key exists in section</summary>
    function ValueExists(const ASection, AKey: string): Boolean;

    /// <summary>Read all sections</summary>
    procedure ReadSections(AStrings: TStrings);

    /// <summary>Read all keys in a section</summary>
    procedure ReadSection(const ASection: string; AStrings: TStrings);

    /// <summary>Read all key=value pairs in a section</summary>
    procedure ReadSectionValues(const ASection: string; AStrings: TStrings);

    /// <summary>Delete a key from a section</summary>
    procedure DeleteKey(const ASection, AKey: string);

    /// <summary>Erase an entire section</summary>
    procedure EraseSection(const ASection: string);

    /// <summary>Save changes to file</summary>
    procedure UpdateFile;

    property FileName: string read FFileName;
    property Modified: Boolean read FModified;
  end;

implementation

{ TTomlIniFile }

constructor TTomlIniFile.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
  FModified := False;
  FTable := TToml.Create;

  if TFile.Exists(FFileName) then
    LoadFromFile;
end;

destructor TTomlIniFile.Destroy;
begin
  FTable.Free;
  inherited;
end;

function TTomlIniFile.ConvertIniToToml(const AIniContent: string): string;
var
  LLines: TStringList;
  LLine: string;
  i: Integer;
begin
  // Simple conversion: INI is already compatible with TOML for basic cases
  LLines := TStringList.Create;
  try
    LLines.Text := AIniContent;

    for i := 0 to LLines.Count - 1 do
    begin
      LLine := LLines[i].Trim;

      // Convert ; comments to # comments
      if LLine.StartsWith(';') then
        LLines[i] := '#' + LLine.Substring(1);
    end;

    Result := LLines.Text;
  finally
    LLines.Free;
  end;
end;

function TTomlIniFile.ConvertTomlToIni(const ATomlContent: string): string;
begin
  // For now, TOML format is compatible with INI
  Result := ATomlContent;
end;

procedure TTomlIniFile.LoadFromFile;
var
  LContent: string;
  LTomlContent: string;
begin
  LContent := TFile.ReadAllText(FFileName, TEncoding.UTF8);

  // Convert INI to TOML if needed
  LTomlContent := ConvertIniToToml(LContent);

  try
    FTable.Free;
    FTable := TToml.FromString(LTomlContent);
  except
    // If parsing fails, create empty table
    FTable.Free;
    FTable := TToml.Create;
  end;

  FModified := False;
end;

procedure TTomlIniFile.SaveToFile;
var
  LToml: string;
  LIni: string;
begin
  LToml := FTable.ToString;
  LIni := ConvertTomlToIni(LToml);

  TFile.WriteAllText(FFileName, LIni, TEncoding.UTF8);
  FModified := False;
end;

function TTomlIniFile.GetSection(const ASection: string): TToml;
begin
  if not FTable.ContainsKey(ASection) then
  begin
    Result := TToml.Create;
    FTable.SetValue(ASection, TTomlValue.CreateTable(Result));
  end
  else
  begin
    if FTable[ASection].Kind <> tvkTable then
      raise Exception.CreateFmt('"%s" is not a section', [ASection]);
    Result := FTable[ASection].AsTable;
  end;
end;

function TTomlIniFile.ReadString(const ASection, AKey, ADefault: string): string;
var
  LSection: TToml;
  LValue: TTomlValue;
begin
  if FTable.ContainsKey(ASection) then
  begin
    LSection := FTable[ASection].AsTable;
    if LSection.TryGetValue(AKey, LValue) and (LValue.Kind = tvkString) then
      Exit(LValue.AsString);
  end;

  Result := ADefault;
end;

procedure TTomlIniFile.WriteString(const ASection, AKey, AValue: string);
var
  LSection: TToml;
begin
  LSection := GetSection(ASection);
  LSection.SetString(AKey, AValue);
  FModified := True;
end;

function TTomlIniFile.ReadInteger(const ASection, AKey: string; ADefault: Integer): Integer;
var
  LSection: TToml;
  LValue: TTomlValue;
begin
  if FTable.ContainsKey(ASection) then
  begin
    LSection := FTable[ASection].AsTable;
    if LSection.TryGetValue(AKey, LValue) and (LValue.Kind = tvkInteger) then
      Exit(LValue.AsInteger);
  end;

  Result := ADefault;
end;

procedure TTomlIniFile.WriteInteger(const ASection, AKey: string; AValue: Integer);
var
  LSection: TToml;
begin
  LSection := GetSection(ASection);
  LSection.SetInteger(AKey, AValue);
  FModified := True;
end;

function TTomlIniFile.ReadBool(const ASection, AKey: string; ADefault: Boolean): Boolean;
var
  LSection: TToml;
  LValue: TTomlValue;
begin
  if FTable.ContainsKey(ASection) then
  begin
    LSection := FTable[ASection].AsTable;
    if LSection.TryGetValue(AKey, LValue) and (LValue.Kind = tvkBoolean) then
      Exit(LValue.AsBoolean);
  end;

  Result := ADefault;
end;

procedure TTomlIniFile.WriteBool(const ASection, AKey: string; AValue: Boolean);
var
  LSection: TToml;
begin
  LSection := GetSection(ASection);
  LSection.SetBoolean(AKey, AValue);
  FModified := True;
end;

function TTomlIniFile.ReadFloat(const ASection, AKey: string; ADefault: Double): Double;
var
  LSection: TToml;
  LValue: TTomlValue;
begin
  if FTable.ContainsKey(ASection) then
  begin
    LSection := FTable[ASection].AsTable;
    if LSection.TryGetValue(AKey, LValue) and (LValue.Kind = tvkFloat) then
      Exit(LValue.AsFloat);
  end;

  Result := ADefault;
end;

procedure TTomlIniFile.WriteFloat(const ASection, AKey: string; AValue: Double);
var
  LSection: TToml;
begin
  LSection := GetSection(ASection);
  LSection.SetFloat(AKey, AValue);
  FModified := True;
end;

function TTomlIniFile.SectionExists(const ASection: string): Boolean;
begin
  Result := FTable.ContainsKey(ASection);
end;

function TTomlIniFile.ValueExists(const ASection, AKey: string): Boolean;
var
  LSection: TToml;
  LValue: TTomlValue;
begin
  Result := False;
  if FTable.ContainsKey(ASection) then
  begin
    LSection := FTable[ASection].AsTable;
    Result := LSection.TryGetValue(AKey, LValue);
  end;
end;

procedure TTomlIniFile.ReadSections(AStrings: TStrings);
var
  LKeys: TArray<string>;
  LKey: string;
begin
  AStrings.Clear;
  LKeys := FTable.Keys;

  for LKey in LKeys do
  begin
    if FTable[LKey].Kind = tvkTable then
      AStrings.Add(LKey);
  end;
end;

procedure TTomlIniFile.ReadSection(const ASection: string; AStrings: TStrings);
var
  LSection: TToml;
  LKeys: TArray<string>;
begin
  AStrings.Clear;

  if FTable.ContainsKey(ASection) then
  begin
    LSection := FTable[ASection].AsTable;
    LKeys := LSection.Keys;
    AStrings.AddStrings(LKeys);
  end;
end;

procedure TTomlIniFile.ReadSectionValues(const ASection: string; AStrings: TStrings);
var
  LSection: TToml;
  LKeys: TArray<string>;
  LKey: string;
  LValue: TTomlValue;
begin
  AStrings.Clear;

  if FTable.ContainsKey(ASection) then
  begin
    LSection := FTable[ASection].AsTable;
    LKeys := LSection.Keys;

    for LKey in LKeys do
    begin
      if LSection.TryGetValue(LKey, LValue) then
      begin
        case LValue.Kind of
          tvkString:
            AStrings.Add(LKey + '=' + LValue.AsString);
          tvkInteger:
            AStrings.Add(LKey + '=' + LValue.AsInteger.ToString);
          tvkFloat:
            AStrings.Add(LKey + '=' + FloatToStr(LValue.AsFloat));
          tvkBoolean:
            if LValue.AsBoolean then
              AStrings.Add(LKey + '=true')
            else
              AStrings.Add(LKey + '=false');
        else
          AStrings.Add(LKey + '=' + LValue.AsString);
        end;
      end;
    end;
  end;
end;

procedure TTomlIniFile.DeleteKey(const ASection, AKey: string);
var
  LSection: TToml;
begin
  if FTable.ContainsKey(ASection) then
  begin
    LSection := FTable[ASection].AsTable;
    if LSection.RemoveKey(AKey) then
      FModified := True;
  end;
end;

procedure TTomlIniFile.EraseSection(const ASection: string);
begin
  if FTable.RemoveKey(ASection) then
    FModified := True;
end;

procedure TTomlIniFile.UpdateFile;
begin
  if FModified then
    SaveToFile;
end;

end.
