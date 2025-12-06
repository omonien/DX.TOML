{*******************************************************************************
  DX.TOML.DOM - TOML Document Object Model

  Description:
    Provides runtime representation of TOML data for easy access.
    TToml is the main class acting like a dictionary with load/save capability.
    This is the high-level API for application code.

  Author: DX.TOML Project
  License: MIT
*******************************************************************************}
unit DX.TOML.DOM;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Rtti,
  System.DateUtils,
  DX.TOML.AST,
  DX.TOML.Lexer,
  DX.TOML.Parser;

type
  TTomlValue = class;
  TToml = class;
  TTomlArray = class;

  /// <summary>TOML value type enumeration</summary>
  TTomlValueKind = (
    tvkString,
    tvkInteger,
    tvkFloat,
    tvkBoolean,
    tvkDateTime,
    tvkDate,
    tvkTime,
    tvkArray,
    tvkTable
  );

  /// <summary>TOML value wrapper</summary>
  TTomlValue = class
  private
    FKind: TTomlValueKind;
    FValue: TValue;
    FTable: TToml;
    FArray: TTomlArray;

    function GetAsString: string;
    function GetAsInteger: Int64;
    function GetAsFloat: Double;
    function GetAsBoolean: Boolean;
    function GetAsDateTime: TDateTime;
    function GetAsTable: TToml;
    function GetAsArray: TTomlArray;
  public
    constructor CreateString(const AValue: string);
    constructor CreateInteger(AValue: Int64);
    constructor CreateFloat(AValue: Double);
    constructor CreateBoolean(AValue: Boolean);
    constructor CreateDateTime(AValue: TDateTime);
    constructor CreateTable(ATable: TToml);
    constructor CreateArray(AArray: TTomlArray);
    destructor Destroy; override;

    /// <summary>Check if value is of specific kind</summary>
    function IsKind(AKind: TTomlValueKind): Boolean;

    property Kind: TTomlValueKind read FKind;
    property AsString: string read GetAsString;
    property AsInteger: Int64 read GetAsInteger;
    property AsFloat: Double read GetAsFloat;
    property AsBoolean: Boolean read GetAsBoolean;
    property AsDateTime: TDateTime read GetAsDateTime;
    property AsTable: TToml read GetAsTable;
    property AsArray: TTomlArray read GetAsArray;
  end;

  /// <summary>TOML array (list of values)</summary>
  TTomlArray = class
  private
    FItems: TObjectList<TTomlValue>;

    function GetCount: Integer;
    function GetItem(AIndex: Integer): TTomlValue;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Add a value to the array</summary>
    procedure Add(AValue: TTomlValue);

    /// <summary>Add a string value</summary>
    procedure AddString(const AValue: string);

    /// <summary>Add an integer value</summary>
    procedure AddInteger(AValue: Int64);

    /// <summary>Add a float value</summary>
    procedure AddFloat(AValue: Double);

    /// <summary>Add a boolean value</summary>
    procedure AddBoolean(AValue: Boolean);

    property Count: Integer read GetCount;
    property Items[AIndex: Integer]: TTomlValue read GetItem; default;
  end;

  /// <summary>TOML document - main class for parsing and manipulating TOML data</summary>
  TToml = class
  private
    FValues: TObjectDictionary<string, TTomlValue>;

    function GetValue(const AKey: string): TTomlValue;
    function GetKeys: TArray<string>;

    class function InternalParse(const ASource: string): TTomlDocumentSyntax;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Load TOML from file</summary>
    /// <param name="AFileName">Path to TOML file</param>
    /// <returns>New TToml instance</returns>
    class function FromFile(const AFileName: string): TToml;

    /// <summary>Load TOML from string</summary>
    /// <param name="ASource">TOML source string</param>
    /// <returns>New TToml instance</returns>
    class function FromString(const ASource: string): TToml;

    /// <summary>Parse TOML string to AST (for advanced scenarios)</summary>
    /// <param name="ASource">TOML source string</param>
    /// <returns>Document syntax tree with full formatting preservation</returns>
    class function ParseToAST(const ASource: string): TTomlDocumentSyntax;

    /// <summary>Validate TOML syntax without building model</summary>
    /// <param name="ASource">TOML source string</param>
    /// <param name="AErrorMessage">Error message if validation fails</param>
    /// <returns>True if valid, False otherwise</returns>
    class function Validate(const ASource: string; out AErrorMessage: string): Boolean;

    /// <summary>Save TOML to file</summary>
    /// <param name="AFileName">Path to output file</param>
    procedure SaveToFile(const AFileName: string);

    /// <summary>Convert to TOML string</summary>
    /// <returns>TOML formatted string</returns>
    function ToString: string; override;

    /// <summary>Check if key exists</summary>
    function ContainsKey(const AKey: string): Boolean;

    /// <summary>Try to get a value by key</summary>
    function TryGetValue(const AKey: string; out AValue: TTomlValue): Boolean;

    /// <summary>Set a value</summary>
    procedure SetValue(const AKey: string; AValue: TTomlValue);

    /// <summary>Set a string value</summary>
    procedure SetString(const AKey: string; const AValue: string);

    /// <summary>Set an integer value</summary>
    procedure SetInteger(const AKey: string; AValue: Int64);

    /// <summary>Set a float value</summary>
    procedure SetFloat(const AKey: string; AValue: Double);

    /// <summary>Set a boolean value</summary>
    procedure SetBoolean(const AKey: string; AValue: Boolean);

    /// <summary>Remove a key from the table</summary>
    /// <returns>True if key was removed, False if key didn't exist</returns>
    function RemoveKey(const AKey: string): Boolean;

    /// <summary>Clear all keys from the table</summary>
    procedure Clear;

    /// <summary>Get or create a nested table</summary>
    function GetOrCreateTable(const AKey: string): TToml;

    /// <summary>Get or create a nested array</summary>
    function GetOrCreateArray(const AKey: string): TTomlArray;

    property Values[const AKey: string]: TTomlValue read GetValue; default;
    property Keys: TArray<string> read GetKeys;
  end;

  /// <summary>AST to DOM converter (internal)</summary>
  TTomlDomBuilder = class
  private
    class function ConvertValue(ANode: TTomlSyntaxNode): TTomlValue;
    class function ConvertArray(ANode: TTomlArraySyntax): TTomlArray;
    class function ConvertInlineTable(ANode: TTomlInlineTableSyntax): TToml;
    class procedure ApplyKeyValue(ATable: TToml; AKeyValue: TTomlKeyValueSyntax);
    class function ParseInteger(const AText: string): Int64;
    class function ParseFloat(const AText: string): Double;
  public
    class function BuildFromDocument(ADocument: TTomlDocumentSyntax): TToml;
  end;

  /// <summary>TOML serializer (internal)</summary>
  TTomlSerializer = class
  private
    FBuilder: TStringBuilder;

    procedure WriteValue(AValue: TTomlValue);
    procedure WriteArray(AArray: TTomlArray);
    procedure WriteTable(const APath: string; ATable: TToml);
    procedure WriteInlineTable(ATable: TToml);
    procedure WriteKeyValue(const AKey: string; AValue: TTomlValue);
    function EscapeString(const AValue: string): string;
    function NeedsQuotes(const AKey: string): Boolean;
    function QuoteKey(const AKey: string): string;
  public
    constructor Create;
    destructor Destroy; override;

    function Serialize(ATable: TToml): string;
  end;

implementation

{ TTomlValue }

constructor TTomlValue.CreateString(const AValue: string);
begin
  inherited Create;
  FKind := tvkString;
  FValue := AValue;
end;

constructor TTomlValue.CreateInteger(AValue: Int64);
begin
  inherited Create;
  FKind := tvkInteger;
  FValue := AValue;
end;

constructor TTomlValue.CreateFloat(AValue: Double);
begin
  inherited Create;
  FKind := tvkFloat;
  FValue := AValue;
end;

constructor TTomlValue.CreateBoolean(AValue: Boolean);
begin
  inherited Create;
  FKind := tvkBoolean;
  FValue := AValue;
end;

constructor TTomlValue.CreateDateTime(AValue: TDateTime);
begin
  inherited Create;
  FKind := tvkDateTime;
  FValue := AValue;
end;

constructor TTomlValue.CreateTable(ATable: TToml);
begin
  inherited Create;
  FKind := tvkTable;
  FTable := ATable;
end;

constructor TTomlValue.CreateArray(AArray: TTomlArray);
begin
  inherited Create;
  FKind := tvkArray;
  FArray := AArray;
end;

destructor TTomlValue.Destroy;
begin
  if Assigned(FTable) then
    FTable.Free;
  if Assigned(FArray) then
    FArray.Free;
  inherited;
end;

function TTomlValue.IsKind(AKind: TTomlValueKind): Boolean;
begin
  Result := FKind = AKind;
end;

function TTomlValue.GetAsString: string;
begin
  if FKind = tvkString then
    Result := FValue.AsString
  else
    raise Exception.Create('Value is not a string');
end;

function TTomlValue.GetAsInteger: Int64;
begin
  if FKind = tvkInteger then
    Result := FValue.AsInt64
  else
    raise Exception.Create('Value is not an integer');
end;

function TTomlValue.GetAsFloat: Double;
begin
  if FKind = tvkFloat then
    Result := FValue.AsExtended
  else
    raise Exception.Create('Value is not a float');
end;

function TTomlValue.GetAsBoolean: Boolean;
begin
  if FKind = tvkBoolean then
    Result := FValue.AsBoolean
  else
    raise Exception.Create('Value is not a boolean');
end;

function TTomlValue.GetAsDateTime: TDateTime;
begin
  if FKind = tvkDateTime then
    Result := FValue.AsExtended
  else
    raise Exception.Create('Value is not a datetime');
end;

function TTomlValue.GetAsTable: TToml;
begin
  if FKind = tvkTable then
    Result := FTable
  else
    raise Exception.Create('Value is not a table');
end;

function TTomlValue.GetAsArray: TTomlArray;
begin
  if FKind = tvkArray then
    Result := FArray
  else
    raise Exception.Create('Value is not an array');
end;

{ TTomlArray }

constructor TTomlArray.Create;
begin
  inherited Create;
  FItems := TObjectList<TTomlValue>.Create(True);
end;

destructor TTomlArray.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TTomlArray.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TTomlArray.GetItem(AIndex: Integer): TTomlValue;
begin
  Result := FItems[AIndex];
end;

procedure TTomlArray.Add(AValue: TTomlValue);
begin
  FItems.Add(AValue);
end;

procedure TTomlArray.AddString(const AValue: string);
begin
  Add(TTomlValue.CreateString(AValue));
end;

procedure TTomlArray.AddInteger(AValue: Int64);
begin
  Add(TTomlValue.CreateInteger(AValue));
end;

procedure TTomlArray.AddFloat(AValue: Double);
begin
  Add(TTomlValue.CreateFloat(AValue));
end;

procedure TTomlArray.AddBoolean(AValue: Boolean);
begin
  Add(TTomlValue.CreateBoolean(AValue));
end;

{ TToml }

constructor TToml.Create;
begin
  inherited Create;
  FValues := TObjectDictionary<string, TTomlValue>.Create([doOwnsValues]);
end;

destructor TToml.Destroy;
begin
  FValues.Free;
  inherited;
end;

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

class function TToml.FromFile(const AFileName: string): TToml;
var
  LSource: string;
begin
  LSource := TFile.ReadAllText(AFileName, TEncoding.UTF8);
  Result := FromString(LSource);
end;

class function TToml.FromString(const ASource: string): TToml;
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

class function TToml.ParseToAST(const ASource: string): TTomlDocumentSyntax;
begin
  Result := InternalParse(ASource);
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

procedure TToml.SaveToFile(const AFileName: string);
var
  LToml: string;
begin
  LToml := ToString;
  TFile.WriteAllText(AFileName, LToml, TEncoding.UTF8);
end;

function TToml.ToString: string;
var
  LSerializer: TTomlSerializer;
begin
  LSerializer := TTomlSerializer.Create;
  try
    Result := LSerializer.Serialize(Self);
  finally
    LSerializer.Free;
  end;
end;

function TToml.ContainsKey(const AKey: string): Boolean;
begin
  Result := FValues.ContainsKey(AKey);
end;

function TToml.TryGetValue(const AKey: string; out AValue: TTomlValue): Boolean;
begin
  Result := FValues.TryGetValue(AKey, AValue);
end;

function TToml.GetValue(const AKey: string): TTomlValue;
begin
  if not FValues.TryGetValue(AKey, Result) then
    raise Exception.CreateFmt('Key "%s" not found', [AKey]);
end;

function TToml.GetKeys: TArray<string>;
begin
  Result := FValues.Keys.ToArray;
end;

procedure TToml.SetValue(const AKey: string; AValue: TTomlValue);
begin
  if FValues.ContainsKey(AKey) then
    FValues.Remove(AKey);
  FValues.Add(AKey, AValue);
end;

procedure TToml.SetString(const AKey, AValue: string);
begin
  SetValue(AKey, TTomlValue.CreateString(AValue));
end;

procedure TToml.SetInteger(const AKey: string; AValue: Int64);
begin
  SetValue(AKey, TTomlValue.CreateInteger(AValue));
end;

procedure TToml.SetFloat(const AKey: string; AValue: Double);
begin
  SetValue(AKey, TTomlValue.CreateFloat(AValue));
end;

procedure TToml.SetBoolean(const AKey: string; AValue: Boolean);
begin
  SetValue(AKey, TTomlValue.CreateBoolean(AValue));
end;

function TToml.RemoveKey(const AKey: string): Boolean;
begin
  Result := FValues.ContainsKey(AKey);
  if Result then
    FValues.Remove(AKey);
end;

procedure TToml.Clear;
begin
  FValues.Clear;
end;

function TToml.GetOrCreateTable(const AKey: string): TToml;
var
  LValue: TTomlValue;
begin
  if TryGetValue(AKey, LValue) then
  begin
    if LValue.Kind <> tvkTable then
      raise Exception.CreateFmt('Key "%s" is not a table', [AKey]);
    Result := LValue.AsTable;
  end
  else
  begin
    Result := TToml.Create;
    SetValue(AKey, TTomlValue.CreateTable(Result));
  end;
end;

function TToml.GetOrCreateArray(const AKey: string): TTomlArray;
var
  LValue: TTomlValue;
begin
  if TryGetValue(AKey, LValue) then
  begin
    if LValue.Kind <> tvkArray then
      raise Exception.CreateFmt('Key "%s" is not an array', [AKey]);
    Result := LValue.AsArray;
  end
  else
  begin
    Result := TTomlArray.Create;
    SetValue(AKey, TTomlValue.CreateArray(Result));
  end;
end;

{ TTomlDomBuilder }

class function TTomlDomBuilder.ParseInteger(const AText: string): Int64;
var
  LClean: string;
begin
  // Remove underscores
  LClean := AText.Replace('_', '', [rfReplaceAll]);

  // Handle special bases
  if LClean.StartsWith('0x') then
    Result := StrToInt64('$' + LClean.Substring(2))
  else if LClean.StartsWith('0o') then
    Result := StrToInt64(LClean.Substring(2))  // Simplified
  else if LClean.StartsWith('0b') then
    Result := StrToInt64(LClean.Substring(2))  // Simplified
  else
    Result := StrToInt64(LClean);
end;

class function TTomlDomBuilder.ParseFloat(const AText: string): Double;
var
  LClean: string;
begin
  LClean := AText.Replace('_', '', [rfReplaceAll]);

  if LClean = 'inf' then
    Result := Infinity
  else if LClean = '+inf' then
    Result := Infinity
  else if LClean = '-inf' then
    Result := NegInfinity
  else if LClean = 'nan' then
    Result := NaN
  else if LClean = '+nan' then
    Result := NaN
  else if LClean = '-nan' then
    Result := NaN
  else
    Result := StrToFloat(LClean);
end;

class function TTomlDomBuilder.ConvertValue(ANode: TTomlSyntaxNode): TTomlValue;
var
  LValueNode: TTomlValueSyntax;
  LArrayNode: TTomlArraySyntax;
  LTableNode: TTomlInlineTableSyntax;
begin
  if ANode is TTomlValueSyntax then
  begin
    LValueNode := TTomlValueSyntax(ANode);

    case LValueNode.ValueKind of
      tkString, tkMultiLineString:
        Result := TTomlValue.CreateString(LValueNode.Value);

      tkInteger:
        Result := TTomlValue.CreateInteger(ParseInteger(LValueNode.Value));

      tkFloat:
        Result := TTomlValue.CreateFloat(ParseFloat(LValueNode.Value));

      tkBoolean:
        Result := TTomlValue.CreateBoolean(LValueNode.Value = 'true');

      tkDateTime, tkDate, tkTime:
        Result := TTomlValue.CreateDateTime(Now);  // Simplified
    else
      Result := TTomlValue.CreateString(LValueNode.Value);
    end;
  end
  else if ANode is TTomlArraySyntax then
  begin
    LArrayNode := TTomlArraySyntax(ANode);
    Result := TTomlValue.CreateArray(ConvertArray(LArrayNode));
  end
  else if ANode is TTomlInlineTableSyntax then
  begin
    LTableNode := TTomlInlineTableSyntax(ANode);
    Result := TTomlValue.CreateTable(ConvertInlineTable(LTableNode));
  end
  else
    Result := TTomlValue.CreateString('');
end;

class function TTomlDomBuilder.ConvertArray(ANode: TTomlArraySyntax): TTomlArray;
var
  LArray: TTomlArray;
  LElement: TTomlSyntaxNode;
begin
  LArray := TTomlArray.Create;

  for LElement in ANode.Elements do
    LArray.Add(ConvertValue(LElement));

  Result := LArray;
end;

class function TTomlDomBuilder.ConvertInlineTable(ANode: TTomlInlineTableSyntax): TToml;
var
  LTable: TToml;
  LKeyValue: TTomlSyntaxNode;
begin
  LTable := TToml.Create;

  for LKeyValue in ANode.KeyValues do
  begin
    if LKeyValue is TTomlKeyValueSyntax then
      ApplyKeyValue(LTable, TTomlKeyValueSyntax(LKeyValue));
  end;

  Result := LTable;
end;

class procedure TTomlDomBuilder.ApplyKeyValue(ATable: TToml; AKeyValue: TTomlKeyValueSyntax);
var
  LKey: string;
  LValue: TTomlValue;
  LCurrentTable: TToml;
  i: Integer;
begin
  LCurrentTable := ATable;

  // Navigate to the correct table using dotted key
  for i := 0 to AKeyValue.Key.Segments.Count - 2 do
  begin
    LKey := AKeyValue.Key.Segments[i];
    LCurrentTable := LCurrentTable.GetOrCreateTable(LKey);
  end;

  // Set the final value
  LKey := AKeyValue.Key.Segments[AKeyValue.Key.Segments.Count - 1];
  LValue := ConvertValue(AKeyValue.Value);
  LCurrentTable.SetValue(LKey, LValue);
end;

class function TTomlDomBuilder.BuildFromDocument(ADocument: TTomlDocumentSyntax): TToml;
var
  LTable: TToml;
  LKeyValue: TTomlSyntaxNode;
  LTableNode: TTomlSyntaxNode;
  LTableSyntax: TTomlTableSyntax;
  LCurrentTable: TToml;
  LKey: string;
  i: Integer;
begin
  LTable := TToml.Create;

  // Process top-level key-values
  for LKeyValue in ADocument.KeyValues do
  begin
    if LKeyValue is TTomlKeyValueSyntax then
      ApplyKeyValue(LTable, TTomlKeyValueSyntax(LKeyValue));
  end;

  // Process tables
  for LTableNode in ADocument.Tables do
  begin
    if LTableNode is TTomlTableSyntax then
    begin
      LTableSyntax := TTomlTableSyntax(LTableNode);
      LCurrentTable := LTable;

      // Navigate to the correct nested table
      for i := 0 to LTableSyntax.Key.Segments.Count - 1 do
      begin
        LKey := LTableSyntax.Key.Segments[i];
        LCurrentTable := LCurrentTable.GetOrCreateTable(LKey);
      end;

      // Add key-values to this table
      for LKeyValue in LTableSyntax.KeyValues do
      begin
        if LKeyValue is TTomlKeyValueSyntax then
          ApplyKeyValue(LCurrentTable, TTomlKeyValueSyntax(LKeyValue));
      end;
    end;
  end;

  Result := LTable;
end;

{ TTomlSerializer }

constructor TTomlSerializer.Create;
begin
  inherited Create;
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

procedure TTomlSerializer.WriteInlineTable(ATable: TToml);
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

procedure TTomlSerializer.WriteTable(const APath: string; ATable: TToml);
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

function TTomlSerializer.Serialize(ATable: TToml): string;
begin
  FBuilder.Clear;
  WriteTable('', ATable);
  Result := FBuilder.ToString;
end;

end.
