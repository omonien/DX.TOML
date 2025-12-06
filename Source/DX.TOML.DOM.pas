{*******************************************************************************
  DX.TOML.DOM - TOML Document Object Model

  Description:
    Provides runtime representation of TOML data for easy access.
    TTomlTable acts like a dictionary, TTomlArray like a list.
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
  DX.TOML.AST;

type
  TTomlValue = class;
  TTomlTable = class;
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
    FTable: TTomlTable;
    FArray: TTomlArray;

    function GetAsString: string;
    function GetAsInteger: Int64;
    function GetAsFloat: Double;
    function GetAsBoolean: Boolean;
    function GetAsDateTime: TDateTime;
    function GetAsTable: TTomlTable;
    function GetAsArray: TTomlArray;
  public
    constructor CreateString(const AValue: string);
    constructor CreateInteger(AValue: Int64);
    constructor CreateFloat(AValue: Double);
    constructor CreateBoolean(AValue: Boolean);
    constructor CreateDateTime(AValue: TDateTime);
    constructor CreateTable(ATable: TTomlTable);
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
    property AsTable: TTomlTable read GetAsTable;
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

  /// <summary>TOML table (dictionary of key-value pairs)</summary>
  TTomlTable = class
  private
    FValues: TObjectDictionary<string, TTomlValue>;

    function GetValue(const AKey: string): TTomlValue;
    function GetKeys: TArray<string>;
  public
    constructor Create;
    destructor Destroy; override;

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

    /// <summary>Get or create a nested table</summary>
    function GetOrCreateTable(const AKey: string): TTomlTable;

    /// <summary>Get or create a nested array</summary>
    function GetOrCreateArray(const AKey: string): TTomlArray;

    property Values[const AKey: string]: TTomlValue read GetValue; default;
    property Keys: TArray<string> read GetKeys;
  end;

  /// <summary>AST to DOM converter</summary>
  TTomlDomBuilder = class
  private
    class function ConvertValue(ANode: TTomlSyntaxNode): TTomlValue;
    class function ConvertArray(ANode: TTomlArraySyntax): TTomlArray;
    class function ConvertInlineTable(ANode: TTomlInlineTableSyntax): TTomlTable;
    class procedure ApplyKeyValue(ATable: TTomlTable; AKeyValue: TTomlKeyValueSyntax);
    class function ParseInteger(const AText: string): Int64;
    class function ParseFloat(const AText: string): Double;
  public
    /// <summary>Convert AST document to DOM table</summary>
    class function BuildFromDocument(ADocument: TTomlDocumentSyntax): TTomlTable;
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

constructor TTomlValue.CreateTable(ATable: TTomlTable);
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

function TTomlValue.GetAsTable: TTomlTable;
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

{ TTomlTable }

constructor TTomlTable.Create;
begin
  inherited Create;
  FValues := TObjectDictionary<string, TTomlValue>.Create([doOwnsValues]);
end;

destructor TTomlTable.Destroy;
begin
  FValues.Free;
  inherited;
end;

function TTomlTable.ContainsKey(const AKey: string): Boolean;
begin
  Result := FValues.ContainsKey(AKey);
end;

function TTomlTable.TryGetValue(const AKey: string; out AValue: TTomlValue): Boolean;
begin
  Result := FValues.TryGetValue(AKey, AValue);
end;

function TTomlTable.GetValue(const AKey: string): TTomlValue;
begin
  if not FValues.TryGetValue(AKey, Result) then
    raise Exception.CreateFmt('Key "%s" not found', [AKey]);
end;

function TTomlTable.GetKeys: TArray<string>;
begin
  Result := FValues.Keys.ToArray;
end;

procedure TTomlTable.SetValue(const AKey: string; AValue: TTomlValue);
begin
  if FValues.ContainsKey(AKey) then
    FValues.Remove(AKey);
  FValues.Add(AKey, AValue);
end;

procedure TTomlTable.SetString(const AKey, AValue: string);
begin
  SetValue(AKey, TTomlValue.CreateString(AValue));
end;

procedure TTomlTable.SetInteger(const AKey: string; AValue: Int64);
begin
  SetValue(AKey, TTomlValue.CreateInteger(AValue));
end;

procedure TTomlTable.SetFloat(const AKey: string; AValue: Double);
begin
  SetValue(AKey, TTomlValue.CreateFloat(AValue));
end;

procedure TTomlTable.SetBoolean(const AKey: string; AValue: Boolean);
begin
  SetValue(AKey, TTomlValue.CreateBoolean(AValue));
end;

function TTomlTable.GetOrCreateTable(const AKey: string): TTomlTable;
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
    Result := TTomlTable.Create;
    SetValue(AKey, TTomlValue.CreateTable(Result));
  end;
end;

function TTomlTable.GetOrCreateArray(const AKey: string): TTomlArray;
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

class function TTomlDomBuilder.ConvertInlineTable(ANode: TTomlInlineTableSyntax): TTomlTable;
var
  LTable: TTomlTable;
  LKeyValue: TTomlSyntaxNode;
begin
  LTable := TTomlTable.Create;

  for LKeyValue in ANode.KeyValues do
  begin
    if LKeyValue is TTomlKeyValueSyntax then
      ApplyKeyValue(LTable, TTomlKeyValueSyntax(LKeyValue));
  end;

  Result := LTable;
end;

class procedure TTomlDomBuilder.ApplyKeyValue(ATable: TTomlTable; AKeyValue: TTomlKeyValueSyntax);
var
  LKey: string;
  LValue: TTomlValue;
  LCurrentTable: TTomlTable;
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

class function TTomlDomBuilder.BuildFromDocument(ADocument: TTomlDocumentSyntax): TTomlTable;
var
  LTable: TTomlTable;
  LKeyValue: TTomlSyntaxNode;
  LTableNode: TTomlSyntaxNode;
  LTableSyntax: TTomlTableSyntax;
  LCurrentTable: TTomlTable;
  LKey: string;
  i: Integer;
begin
  LTable := TTomlTable.Create;

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

end.
