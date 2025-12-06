{*******************************************************************************
  DX.TOML - TOML Parser for Delphi

  Description:
    High-level API for parsing and serializing TOML documents.
    Main entry point for the DX.TOML library.

  Usage:
    var
      LTable: TTomlTable;
    begin
      LTable := TToml.ToModel('title = "TOML Example"');
      try
        ShowMessage(LTable['title'].AsString);
      finally
        LTable.Free;
      end;
    end;

  Author: DX.TOML Project
  License: MIT
*******************************************************************************}
unit DX.TOML;

interface

uses
  System.SysUtils,
  System.Classes,
  DX.TOML.Lexer,
  DX.TOML.Parser,
  DX.TOML.AST,
  DX.TOML.DOM;

type
  /// <summary>Main TOML API class</summary>
  TToml = class sealed
  private
    class function InternalParse(const ASource: string): TTomlDocumentSyntax;
  public
    /// <summary>Parse TOML string to AST (Abstract Syntax Tree)</summary>
    /// <param name="ASource">TOML source string</param>
    /// <returns>Document syntax tree with full formatting preservation</returns>
    class function Parse(const ASource: string): TTomlDocumentSyntax;

    /// <summary>Parse TOML file to AST</summary>
    /// <param name="AFileName">Path to TOML file</param>
    /// <returns>Document syntax tree</returns>
    class function ParseFile(const AFileName: string): TTomlDocumentSyntax;

    /// <summary>Parse TOML string to runtime model (DOM)</summary>
    /// <param name="ASource">TOML source string</param>
    /// <returns>Root table containing all values</returns>
    class function ToModel(const ASource: string): TTomlTable;

    /// <summary>Parse TOML file to runtime model</summary>
    /// <param name="AFileName">Path to TOML file</param>
    /// <returns>Root table containing all values</returns>
    class function ToModelFromFile(const AFileName: string): TTomlTable;

    /// <summary>Serialize runtime model to TOML string</summary>
    /// <param name="ATable">Root table to serialize</param>
    /// <returns>TOML formatted string</returns>
    class function FromModel(ATable: TTomlTable): string;

    /// <summary>Serialize runtime model to TOML file</summary>
    /// <param name="ATable">Root table to serialize</param>
    /// <param name="AFileName">Path to output file</param>
    class procedure FromModelToFile(ATable: TTomlTable; const AFileName: string);

    /// <summary>Validate TOML syntax without building model</summary>
    /// <param name="ASource">TOML source string</param>
    /// <param name="AErrorMessage">Error message if validation fails</param>
    /// <returns>True if valid, False otherwise</returns>
    class function Validate(const ASource: string; out AErrorMessage: string): Boolean;
  end;

  /// <summary>TOML serializer</summary>
  TTomlSerializer = class
  private
    FIndent: Integer;
    FBuilder: TStringBuilder;

    procedure WriteValue(AValue: TTomlValue);
    procedure WriteArray(AArray: TTomlArray);
    procedure WriteTable(const APath: string; ATable: TTomlTable);
    procedure WriteInlineTable(ATable: TTomlTable);
    procedure WriteKeyValue(const AKey: string; AValue: TTomlValue);
    function EscapeString(const AValue: string): string;
    function NeedsQuotes(const AKey: string): Boolean;
    function QuoteKey(const AKey: string): string;
  public
    constructor Create;
    destructor Destroy; override;

    function Serialize(ATable: TTomlTable): string;
  end;

implementation

{ TToml }

class function TToml.InternalParse(const ASource: string): TTomlDocumentSyntax;
var
  LLexer: TTomlLexer;
  LParser: TTomlParser;
begin
  LLexer := TTomlLexer.Create(ASource);
  try
    LLexer.Tokenize;

    LParser := TTomlParser.Create(LLexer);
    try
      Result := LParser.Parse;
    finally
      LParser.Free;
    end;
  finally
    LLexer.Free;
  end;
end;

class function TToml.Parse(const ASource: string): TTomlDocumentSyntax;
begin
  Result := InternalParse(ASource);
end;

class function TToml.ParseFile(const AFileName: string): TTomlDocumentSyntax;
var
  LSource: string;
begin
  LSource := TFile.ReadAllText(AFileName, TEncoding.UTF8);
  Result := Parse(LSource);
end;

class function TToml.ToModel(const ASource: string): TTomlTable;
var
  LDocument: TTomlDocumentSyntax;
begin
  LDocument := InternalParse(ASource);
  try
    Result := TTomlDomBuilder.BuildFromDocument(LDocument);
  finally
    LDocument.Free;
  end;
end;

class function TToml.ToModelFromFile(const AFileName: string): TTomlTable;
var
  LSource: string;
begin
  LSource := TFile.ReadAllText(AFileName, TEncoding.UTF8);
  Result := ToModel(LSource);
end;

class function TToml.FromModel(ATable: TTomlTable): string;
var
  LSerializer: TTomlSerializer;
begin
  LSerializer := TTomlSerializer.Create;
  try
    Result := LSerializer.Serialize(ATable);
  finally
    LSerializer.Free;
  end;
end;

class procedure TToml.FromModelToFile(ATable: TTomlTable; const AFileName: string);
var
  LToml: string;
begin
  LToml := FromModel(ATable);
  TFile.WriteAllText(AFileName, LToml, TEncoding.UTF8);
end;

class function TToml.Validate(const ASource: string; out AErrorMessage: string): Boolean;
var
  LDocument: TTomlDocumentSyntax;
begin
  try
    LDocument := InternalParse(ASource);
    try
      Result := True;
      AErrorMessage := '';
    finally
      LDocument.Free;
    end;
  except
    on E: Exception do
    begin
      Result := False;
      AErrorMessage := E.Message;
    end;
  end;
end;

{ TTomlSerializer }

constructor TTomlSerializer.Create;
begin
  inherited Create;
  FIndent := 0;
  FBuilder := TStringBuilder.Create;
end;

destructor TTomlSerializer.Destroy;
begin
  FBuilder.Free;
  inherited;
end;

function TTomlSerializer.EscapeString(const AValue: string): string;
var
  i: Integer;
  LChar: Char;
begin
  Result := '';
  for i := 1 to Length(AValue) do
  begin
    LChar := AValue[i];
    case LChar of
      '\': Result := Result + '\\';
      '"': Result := Result + '\"';
      #8: Result := Result + '\b';
      #9: Result := Result + '\t';
      #10: Result := Result + '\n';
      #12: Result := Result + '\f';
      #13: Result := Result + '\r';
    else
      Result := Result + LChar;
    end;
  end;
end;

function TTomlSerializer.NeedsQuotes(const AKey: string): Boolean;
var
  i: Integer;
  LChar: Char;
begin
  if AKey = '' then
    Exit(True);

  for i := 1 to Length(AKey) do
  begin
    LChar := AKey[i];
    if not (LChar.IsLetterOrDigit or (LChar = '_') or (LChar = '-')) then
      Exit(True);
  end;

  Result := False;
end;

function TTomlSerializer.QuoteKey(const AKey: string): string;
begin
  if NeedsQuotes(AKey) then
    Result := '"' + EscapeString(AKey) + '"'
  else
    Result := AKey;
end;

procedure TTomlSerializer.WriteValue(AValue: TTomlValue);
begin
  case AValue.Kind of
    tvkString:
      FBuilder.Append('"').Append(EscapeString(AValue.AsString)).Append('"');

    tvkInteger:
      FBuilder.Append(AValue.AsInteger);

    tvkFloat:
      FBuilder.Append(FloatToStr(AValue.AsFloat));

    tvkBoolean:
      if AValue.AsBoolean then
        FBuilder.Append('true')
      else
        FBuilder.Append('false');

    tvkDateTime:
      FBuilder.Append(DateTimeToStr(AValue.AsDateTime));  // Simplified

    tvkArray:
      WriteArray(AValue.AsArray);

    tvkTable:
      WriteInlineTable(AValue.AsTable);
  end;
end;

procedure TTomlSerializer.WriteArray(AArray: TTomlArray);
var
  i: Integer;
begin
  FBuilder.Append('[');

  for i := 0 to AArray.Count - 1 do
  begin
    if i > 0 then
      FBuilder.Append(', ');
    WriteValue(AArray[i]);
  end;

  FBuilder.Append(']');
end;

procedure TTomlSerializer.WriteInlineTable(ATable: TTomlTable);
var
  LKeys: TArray<string>;
  i: Integer;
begin
  FBuilder.Append('{ ');

  LKeys := ATable.Keys;
  for i := 0 to Length(LKeys) - 1 do
  begin
    if i > 0 then
      FBuilder.Append(', ');

    FBuilder.Append(QuoteKey(LKeys[i])).Append(' = ');
    WriteValue(ATable[LKeys[i]]);
  end;

  FBuilder.Append(' }');
end;

procedure TTomlSerializer.WriteKeyValue(const AKey: string; AValue: TTomlValue);
begin
  FBuilder.Append(QuoteKey(AKey)).Append(' = ');
  WriteValue(AValue);
  FBuilder.AppendLine;
end;

procedure TTomlSerializer.WriteTable(const APath: string; ATable: TTomlTable);
var
  LKeys: TArray<string>;
  LKey: string;
  LValue: TTomlValue;
  LFullPath: string;
begin
  // Write simple key-values first
  LKeys := ATable.Keys;
  for LKey in LKeys do
  begin
    LValue := ATable[LKey];
    if not (LValue.Kind in [tvkTable]) then
      WriteKeyValue(LKey, LValue);
  end;

  // Write nested tables
  for LKey in LKeys do
  begin
    LValue := ATable[LKey];
    if LValue.Kind = tvkTable then
    begin
      if APath <> '' then
        LFullPath := APath + '.' + LKey
      else
        LFullPath := LKey;

      FBuilder.AppendLine;
      FBuilder.Append('[').Append(LFullPath).Append(']').AppendLine;
      WriteTable(LFullPath, LValue.AsTable);
    end;
  end;
end;

function TTomlSerializer.Serialize(ATable: TTomlTable): string;
begin
  FBuilder.Clear;
  WriteTable('', ATable);
  Result := FBuilder.ToString;
end;

end.
