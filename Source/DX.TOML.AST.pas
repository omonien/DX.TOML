{*******************************************************************************
  DX.TOML.AST - TOML Abstract Syntax Tree

  Description:
    Provides syntax node classes for exact representation of TOML documents.
    Preserves all formatting, comments, whitespace for round-trip capability.
    This is the low-level API for tooling (IDEs, formatters, validators).

  Author: DX.TOML Project
  License: MIT
*******************************************************************************}
unit DX.TOML.AST;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DX.TOML.Lexer;

type
  TTomlSyntaxNode = class;
  TTomlSyntaxNodeList = TObjectList<TTomlSyntaxNode>;

  /// <summary>Syntax node kind enumeration</summary>
  TTomlSyntaxKind = (
    skDocument,
    skKeyValue,
    skTable,
    skArrayOfTables,
    skKey,
    skValue,
    skArray,
    skInlineTable,
    skTrivia
  );

  /// <summary>Base class for all syntax nodes</summary>
  TTomlSyntaxNode = class abstract
  private
    FParent: TTomlSyntaxNode;
    FChildren: TTomlSyntaxNodeList;
    FTokens: TList<TTomlToken>;
  protected
    function GetKind: TTomlSyntaxKind; virtual; abstract;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Add a child node</summary>
    procedure AddChild(ANode: TTomlSyntaxNode);

    /// <summary>Add a token</summary>
    procedure AddToken(AToken: TTomlToken);

    /// <summary>Get text representation</summary>
    function ToText: string; virtual;

    property Kind: TTomlSyntaxKind read GetKind;
    property Parent: TTomlSyntaxNode read FParent write FParent;
    property Children: TTomlSyntaxNodeList read FChildren;
    property Tokens: TList<TTomlToken> read FTokens;
  end;

  /// <summary>Trivia node (whitespace, comments)</summary>
  TTomlTriviaSyntax = class(TTomlSyntaxNode)
  protected
    function GetKind: TTomlSyntaxKind; override;
  end;

  /// <summary>Value syntax node</summary>
  TTomlValueSyntax = class(TTomlSyntaxNode)
  private
    FValue: string;
    FValueKind: TTomlTokenKind;
  protected
    function GetKind: TTomlSyntaxKind; override;
  public
    constructor Create(AValueKind: TTomlTokenKind; const AValue: string);

    function ToText: string; override;

    property Value: string read FValue;
    property ValueKind: TTomlTokenKind read FValueKind;
  end;

  /// <summary>Key syntax node</summary>
  TTomlKeySyntax = class(TTomlSyntaxNode)
  private
    FSegments: TList<string>;
  protected
    function GetKind: TTomlSyntaxKind; override;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Add a key segment</summary>
    procedure AddSegment(const ASegment: string);

    /// <summary>Get full dotted key</summary>
    function GetFullKey: string;

    function ToText: string; override;

    property Segments: TList<string> read FSegments;
  end;

  /// <summary>Array syntax node</summary>
  TTomlArraySyntax = class(TTomlSyntaxNode)
  private
    FElements: TTomlSyntaxNodeList;
  protected
    function GetKind: TTomlSyntaxKind; override;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Add an element to the array</summary>
    procedure AddElement(AElement: TTomlSyntaxNode);

    function ToText: string; override;

    property Elements: TTomlSyntaxNodeList read FElements;
  end;

  /// <summary>Inline table syntax node</summary>
  TTomlInlineTableSyntax = class(TTomlSyntaxNode)
  private
    FKeyValues: TTomlSyntaxNodeList;
  protected
    function GetKind: TTomlSyntaxKind; override;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Add a key-value pair</summary>
    procedure AddKeyValue(AKeyValue: TTomlSyntaxNode);

    function ToText: string; override;

    property KeyValues: TTomlSyntaxNodeList read FKeyValues;
  end;

  /// <summary>Key-value pair syntax node</summary>
  TTomlKeyValueSyntax = class(TTomlSyntaxNode)
  private
    FKey: TTomlKeySyntax;
    FValue: TTomlSyntaxNode;
  protected
    function GetKind: TTomlSyntaxKind; override;
  public
    constructor Create(AKey: TTomlKeySyntax; AValue: TTomlSyntaxNode);

    function ToText: string; override;

    property Key: TTomlKeySyntax read FKey;
    property Value: TTomlSyntaxNode read FValue;
  end;

  /// <summary>Table header syntax node</summary>
  TTomlTableSyntax = class(TTomlSyntaxNode)
  private
    FKey: TTomlKeySyntax;
    FIsArrayOfTables: Boolean;
    FKeyValues: TTomlSyntaxNodeList;
  protected
    function GetKind: TTomlSyntaxKind; override;
  public
    constructor Create(AKey: TTomlKeySyntax; AIsArrayOfTables: Boolean);
    destructor Destroy; override;

    /// <summary>Add a key-value pair to this table</summary>
    procedure AddKeyValue(AKeyValue: TTomlKeyValueSyntax);

    function ToText: string; override;

    property Key: TTomlKeySyntax read FKey;
    property IsArrayOfTables: Boolean read FIsArrayOfTables;
    property KeyValues: TTomlSyntaxNodeList read FKeyValues;
  end;

  /// <summary>Document root syntax node</summary>
  TTomlDocumentSyntax = class(TTomlSyntaxNode)
  private
    FTables: TTomlSyntaxNodeList;
    FKeyValues: TTomlSyntaxNodeList;
  protected
    function GetKind: TTomlSyntaxKind; override;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Add a table to the document</summary>
    procedure AddTable(ATable: TTomlTableSyntax);

    /// <summary>Add a top-level key-value pair</summary>
    procedure AddKeyValue(AKeyValue: TTomlKeyValueSyntax);

    function ToText: string; override;

    property Tables: TTomlSyntaxNodeList read FTables;
    property KeyValues: TTomlSyntaxNodeList read FKeyValues;
  end;

implementation

{ TTomlSyntaxNode }

constructor TTomlSyntaxNode.Create;
begin
  inherited Create;
  FChildren := TTomlSyntaxNodeList.Create(True);
  FTokens := TList<TTomlToken>.Create;
end;

destructor TTomlSyntaxNode.Destroy;
begin
  FTokens.Free;
  FChildren.Free;
  inherited;
end;

procedure TTomlSyntaxNode.AddChild(ANode: TTomlSyntaxNode);
begin
  ANode.Parent := Self;
  FChildren.Add(ANode);
end;

procedure TTomlSyntaxNode.AddToken(AToken: TTomlToken);
begin
  FTokens.Add(AToken);
end;

function TTomlSyntaxNode.ToText: string;
var
  LToken: TTomlToken;
begin
  Result := '';
  for LToken in FTokens do
    Result := Result + LToken.Text;
end;

{ TTomlTriviaSyntax }

function TTomlTriviaSyntax.GetKind: TTomlSyntaxKind;
begin
  Result := skTrivia;
end;

{ TTomlValueSyntax }

constructor TTomlValueSyntax.Create(AValueKind: TTomlTokenKind; const AValue: string);
begin
  inherited Create;
  FValueKind := AValueKind;
  FValue := AValue;
end;

function TTomlValueSyntax.GetKind: TTomlSyntaxKind;
begin
  Result := skValue;
end;

function TTomlValueSyntax.ToText: string;
begin
  Result := FValue;
end;

{ TTomlKeySyntax }

constructor TTomlKeySyntax.Create;
begin
  inherited Create;
  FSegments := TList<string>.Create;
end;

destructor TTomlKeySyntax.Destroy;
begin
  FSegments.Free;
  inherited;
end;

procedure TTomlKeySyntax.AddSegment(const ASegment: string);
begin
  FSegments.Add(ASegment);
end;

function TTomlKeySyntax.GetFullKey: string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to FSegments.Count - 1 do
  begin
    if i > 0 then
      Result := Result + '.';
    Result := Result + FSegments[i];
  end;
end;

function TTomlKeySyntax.GetKind: TTomlSyntaxKind;
begin
  Result := skKey;
end;

function TTomlKeySyntax.ToText: string;
begin
  Result := GetFullKey;
end;

{ TTomlArraySyntax }

constructor TTomlArraySyntax.Create;
begin
  inherited Create;
  FElements := TTomlSyntaxNodeList.Create(False);  // Elements are owned by Children
end;

destructor TTomlArraySyntax.Destroy;
begin
  FElements.Free;
  inherited;
end;

procedure TTomlArraySyntax.AddElement(AElement: TTomlSyntaxNode);
begin
  FElements.Add(AElement);
  AddChild(AElement);
end;

function TTomlArraySyntax.GetKind: TTomlSyntaxKind;
begin
  Result := skArray;
end;

function TTomlArraySyntax.ToText: string;
var
  i: Integer;
begin
  Result := '[';
  for i := 0 to FElements.Count - 1 do
  begin
    if i > 0 then
      Result := Result + ', ';
    Result := Result + FElements[i].ToText;
  end;
  Result := Result + ']';
end;

{ TTomlInlineTableSyntax }

constructor TTomlInlineTableSyntax.Create;
begin
  inherited Create;
  FKeyValues := TTomlSyntaxNodeList.Create(False);  // Owned by Children
end;

destructor TTomlInlineTableSyntax.Destroy;
begin
  FKeyValues.Free;
  inherited;
end;

procedure TTomlInlineTableSyntax.AddKeyValue(AKeyValue: TTomlSyntaxNode);
begin
  FKeyValues.Add(AKeyValue);
  AddChild(AKeyValue);
end;

function TTomlInlineTableSyntax.GetKind: TTomlSyntaxKind;
begin
  Result := skInlineTable;
end;

function TTomlInlineTableSyntax.ToText: string;
var
  i: Integer;
begin
  Result := '{ ';
  for i := 0 to FKeyValues.Count - 1 do
  begin
    if i > 0 then
      Result := Result + ', ';
    Result := Result + FKeyValues[i].ToText;
  end;
  Result := Result + ' }';
end;

{ TTomlKeyValueSyntax }

constructor TTomlKeyValueSyntax.Create(AKey: TTomlKeySyntax; AValue: TTomlSyntaxNode);
begin
  inherited Create;
  FKey := AKey;
  FValue := AValue;
  AddChild(AKey);
  AddChild(AValue);
end;

function TTomlKeyValueSyntax.GetKind: TTomlSyntaxKind;
begin
  Result := skKeyValue;
end;

function TTomlKeyValueSyntax.ToText: string;
begin
  Result := FKey.ToText + ' = ' + FValue.ToText;
end;

{ TTomlTableSyntax }

constructor TTomlTableSyntax.Create(AKey: TTomlKeySyntax; AIsArrayOfTables: Boolean);
begin
  inherited Create;
  FKey := AKey;
  FIsArrayOfTables := AIsArrayOfTables;
  FKeyValues := TTomlSyntaxNodeList.Create(False);  // Owned by Children
  AddChild(AKey);
end;

destructor TTomlTableSyntax.Destroy;
begin
  FKeyValues.Free;
  inherited;
end;

procedure TTomlTableSyntax.AddKeyValue(AKeyValue: TTomlKeyValueSyntax);
begin
  FKeyValues.Add(AKeyValue);
  AddChild(AKeyValue);
end;

function TTomlTableSyntax.GetKind: TTomlSyntaxKind;
begin
  if FIsArrayOfTables then
    Result := skArrayOfTables
  else
    Result := skTable;
end;

function TTomlTableSyntax.ToText: string;
var
  i: Integer;
begin
  if FIsArrayOfTables then
    Result := '[[' + FKey.ToText + ']]'
  else
    Result := '[' + FKey.ToText + ']';

  Result := Result + sLineBreak;

  for i := 0 to FKeyValues.Count - 1 do
    Result := Result + FKeyValues[i].ToText + sLineBreak;
end;

{ TTomlDocumentSyntax }

constructor TTomlDocumentSyntax.Create;
begin
  inherited Create;
  FTables := TTomlSyntaxNodeList.Create(False);  // Owned by Children
  FKeyValues := TTomlSyntaxNodeList.Create(False);  // Owned by Children
end;

destructor TTomlDocumentSyntax.Destroy;
begin
  FKeyValues.Free;
  FTables.Free;
  inherited;
end;

procedure TTomlDocumentSyntax.AddTable(ATable: TTomlTableSyntax);
begin
  FTables.Add(ATable);
  AddChild(ATable);
end;

procedure TTomlDocumentSyntax.AddKeyValue(AKeyValue: TTomlKeyValueSyntax);
begin
  FKeyValues.Add(AKeyValue);
  AddChild(AKeyValue);
end;

function TTomlDocumentSyntax.GetKind: TTomlSyntaxKind;
begin
  Result := skDocument;
end;

function TTomlDocumentSyntax.ToText: string;
var
  i: Integer;
begin
  Result := '';

  // Top-level key-values
  for i := 0 to FKeyValues.Count - 1 do
    Result := Result + FKeyValues[i].ToText + sLineBreak;

  if FKeyValues.Count > 0 then
    Result := Result + sLineBreak;

  // Tables
  for i := 0 to FTables.Count - 1 do
  begin
    if i > 0 then
      Result := Result + sLineBreak;
    Result := Result + FTables[i].ToText;
  end;
end;

end.
