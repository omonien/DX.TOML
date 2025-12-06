{*******************************************************************************
  DX.TOML.Parser - TOML Parser

  Description:
    Parses a stream of tokens into an Abstract Syntax Tree (AST).
    Implements TOML 1.0.0 specification grammar rules.

  Author: DX.TOML Project
  License: MIT
*******************************************************************************}
unit DX.TOML.Parser;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DX.TOML.Lexer,
  DX.TOML.AST;

type
  /// <summary>Parser exception</summary>
  ETomlParserException = class(Exception)
  private
    FPosition: TTomlPosition;
  public
    constructor Create(const AMessage: string; APosition: TTomlPosition);

    property Position: TTomlPosition read FPosition;
  end;

  /// <summary>TOML parser</summary>
  TTomlParser = class
  private
    FLexer: TTomlLexer;
    FTokens: TObjectList<TTomlToken>;
    FPosition: Integer;
    FDocument: TTomlDocumentSyntax;

    function GetCurrentToken: TTomlToken;
    function GetLookahead(AOffset: Integer): TTomlToken;
    function IsEof: Boolean;

    procedure Advance;
    function Expect(AKind: TTomlTokenKind): TTomlToken;
    function Match(AKind: TTomlTokenKind): Boolean;
    procedure SkipTrivia;

    function ParseDocument: TTomlDocumentSyntax;
    function ParseKeyValue: TTomlKeyValueSyntax;
    function ParseKey: TTomlKeySyntax;
    function ParseValue: TTomlSyntaxNode;
    function ParseArray: TTomlArraySyntax;
    function ParseInlineTable: TTomlInlineTableSyntax;
    function ParseTable: TTomlTableSyntax;
    function ParseString(const AText: string): string;

    procedure Error(const AMessage: string);
  public
    constructor Create(ALexer: TTomlLexer);
    destructor Destroy; override;

    /// <summary>Parse tokens into AST</summary>
    function Parse: TTomlDocumentSyntax;
  end;

implementation

{ ETomlParserException }

constructor ETomlParserException.Create(const AMessage: string; APosition: TTomlPosition);
begin
  inherited Create(AMessage);
  FPosition := APosition;
end;

{ TTomlParser }

constructor TTomlParser.Create(ALexer: TTomlLexer);
begin
  inherited Create;
  FLexer := ALexer;
  FTokens := ALexer.Tokens;
  FPosition := 0;
end;

destructor TTomlParser.Destroy;
begin
  if Assigned(FDocument) then
    FDocument.Free;
  inherited;
end;

function TTomlParser.GetCurrentToken: TTomlToken;
begin
  if IsEof then
    Result := FTokens[FTokens.Count - 1]  // Return EOF token
  else
    Result := FTokens[FPosition];
end;

function TTomlParser.GetLookahead(AOffset: Integer): TTomlToken;
var
  LPos: Integer;
begin
  LPos := FPosition + AOffset;
  if (LPos < 0) or (LPos >= FTokens.Count) then
    Result := FTokens[FTokens.Count - 1]  // Return EOF token
  else
    Result := FTokens[LPos];
end;

function TTomlParser.IsEof: Boolean;
begin
  Result := (FPosition >= FTokens.Count) or (GetCurrentToken.Kind = tkEof);
end;

procedure TTomlParser.Advance;
begin
  if not IsEof then
    Inc(FPosition);
end;

function TTomlParser.Expect(AKind: TTomlTokenKind): TTomlToken;
begin
  if GetCurrentToken.Kind <> AKind then
    Error('Expected ' + GetEnumName(TypeInfo(TTomlTokenKind), Ord(AKind)) +
          ' but got ' + GetEnumName(TypeInfo(TTomlTokenKind), Ord(GetCurrentToken.Kind)));

  Result := GetCurrentToken;
  Advance;
end;

function TTomlParser.Match(AKind: TTomlTokenKind): Boolean;
begin
  Result := GetCurrentToken.Kind = AKind;
end;

procedure TTomlParser.SkipTrivia;
begin
  while not IsEof and (GetCurrentToken.Kind in [tkWhitespace, tkComment]) do
    Advance;
end;

procedure TTomlParser.Error(const AMessage: string);
begin
  raise ETomlParserException.Create(AMessage, GetCurrentToken.Position);
end;

function TTomlParser.ParseString(const AText: string): string;
var
  i: Integer;
  LInString: Boolean;
  LChar: Char;
begin
  Result := '';
  LInString := False;

  i := 1;
  while i <= Length(AText) do
  begin
    LChar := AText[i];

    if not LInString then
    begin
      if LChar in ['"', ''''] then
        LInString := True;
      Inc(i);
      Continue;
    end;

    if LChar = '\' then
    begin
      // Handle escape sequences
      Inc(i);
      if i <= Length(AText) then
      begin
        case AText[i] of
          'n': Result := Result + #10;
          'r': Result := Result + #13;
          't': Result := Result + #9;
          '\': Result := Result + '\';
          '"': Result := Result + '"';
          '''': Result := Result + '''';
        else
          Result := Result + AText[i];
        end;
      end;
    end
    else if LChar in ['"', ''''] then
    begin
      LInString := False;
    end
    else
    begin
      Result := Result + LChar;
    end;

    Inc(i);
  end;
end;

function TTomlParser.ParseKey: TTomlKeySyntax;
var
  LKey: TTomlKeySyntax;
  LToken: TTomlToken;
begin
  LKey := TTomlKeySyntax.Create;

  repeat
    SkipTrivia;

    LToken := GetCurrentToken;

    if LToken.Kind = tkBareKey then
    begin
      LKey.AddSegment(LToken.Text);
      Advance;
    end
    else if LToken.Kind = tkString then
    begin
      LKey.AddSegment(ParseString(LToken.Text));
      Advance;
    end
    else
      Error('Expected key');

    SkipTrivia;

    if Match(tkDot) then
    begin
      Advance;
      SkipTrivia;
    end
    else
      Break;
  until False;

  Result := LKey;
end;

function TTomlParser.ParseValue: TTomlSyntaxNode;
var
  LToken: TTomlToken;
  LValue: string;
begin
  SkipTrivia;

  LToken := GetCurrentToken;

  case LToken.Kind of
    tkString, tkMultiLineString:
      begin
        LValue := ParseString(LToken.Text);
        Result := TTomlValueSyntax.Create(LToken.Kind, LValue);
        Advance;
      end;

    tkInteger, tkFloat, tkBoolean, tkDateTime, tkDate, tkTime:
      begin
        Result := TTomlValueSyntax.Create(LToken.Kind, LToken.Text);
        Advance;
      end;

    tkLeftBracket:
      Result := ParseArray;

    tkLeftBrace:
      Result := ParseInlineTable;
  else
    Error('Expected value');
    Result := nil;  // Suppress warning
  end;
end;

function TTomlParser.ParseArray: TTomlArraySyntax;
var
  LArray: TTomlArraySyntax;
  LElement: TTomlSyntaxNode;
begin
  LArray := TTomlArraySyntax.Create;

  Expect(tkLeftBracket);
  SkipTrivia;

  // Handle newlines in arrays
  while Match(tkNewLine) do
  begin
    Advance;
    SkipTrivia;
  end;

  while not Match(tkRightBracket) do
  begin
    LElement := ParseValue;
    LArray.AddElement(LElement);

    SkipTrivia;

    // Handle newlines
    while Match(tkNewLine) do
    begin
      Advance;
      SkipTrivia;
    end;

    if Match(tkComma) then
    begin
      Advance;
      SkipTrivia;

      // Handle newlines after comma
      while Match(tkNewLine) do
      begin
        Advance;
        SkipTrivia;
      end;
    end
    else if not Match(tkRightBracket) then
      Error('Expected comma or ]');
  end;

  Expect(tkRightBracket);

  Result := LArray;
end;

function TTomlParser.ParseInlineTable: TTomlInlineTableSyntax;
var
  LTable: TTomlInlineTableSyntax;
  LKeyValue: TTomlKeyValueSyntax;
begin
  LTable := TTomlInlineTableSyntax.Create;

  Expect(tkLeftBrace);
  SkipTrivia;

  while not Match(tkRightBrace) do
  begin
    LKeyValue := ParseKeyValue;
    LTable.AddKeyValue(LKeyValue);

    SkipTrivia;

    if Match(tkComma) then
    begin
      Advance;
      SkipTrivia;
    end
    else if not Match(tkRightBrace) then
      Error('Expected comma or }');
  end;

  Expect(tkRightBrace);

  Result := LTable;
end;

function TTomlParser.ParseKeyValue: TTomlKeyValueSyntax;
var
  LKey: TTomlKeySyntax;
  LValue: TTomlSyntaxNode;
begin
  SkipTrivia;

  LKey := ParseKey;

  SkipTrivia;
  Expect(tkEquals);
  SkipTrivia;

  LValue := ParseValue;

  Result := TTomlKeyValueSyntax.Create(LKey, LValue);
end;

function TTomlParser.ParseTable: TTomlTableSyntax;
var
  LKey: TTomlKeySyntax;
  LIsArrayOfTables: Boolean;
  LTable: TTomlTableSyntax;
  LKeyValue: TTomlKeyValueSyntax;
begin
  SkipTrivia;

  Expect(tkLeftBracket);
  LIsArrayOfTables := Match(tkLeftBracket);

  if LIsArrayOfTables then
    Advance;

  SkipTrivia;

  LKey := ParseKey;

  SkipTrivia;

  Expect(tkRightBracket);

  if LIsArrayOfTables then
    Expect(tkRightBracket);

  SkipTrivia;

  // Skip newline after table header
  if Match(tkNewLine) then
    Advance;

  LTable := TTomlTableSyntax.Create(LKey, LIsArrayOfTables);

  // Parse key-value pairs in this table
  SkipTrivia;

  while not IsEof and not Match(tkLeftBracket) do
  begin
    if Match(tkNewLine) then
    begin
      Advance;
      SkipTrivia;
      Continue;
    end;

    LKeyValue := ParseKeyValue;
    LTable.AddKeyValue(LKeyValue);

    SkipTrivia;

    if Match(tkNewLine) then
      Advance;

    SkipTrivia;
  end;

  Result := LTable;
end;

function TTomlParser.ParseDocument: TTomlDocumentSyntax;
var
  LDoc: TTomlDocumentSyntax;
  LKeyValue: TTomlKeyValueSyntax;
  LTable: TTomlTableSyntax;
begin
  LDoc := TTomlDocumentSyntax.Create;

  SkipTrivia;

  // Parse top-level key-value pairs
  while not IsEof and not Match(tkLeftBracket) do
  begin
    if Match(tkNewLine) then
    begin
      Advance;
      SkipTrivia;
      Continue;
    end;

    LKeyValue := ParseKeyValue;
    LDoc.AddKeyValue(LKeyValue);

    SkipTrivia;

    if Match(tkNewLine) then
      Advance;

    SkipTrivia;
  end;

  // Parse tables
  while not IsEof do
  begin
    SkipTrivia;

    if Match(tkNewLine) then
    begin
      Advance;
      Continue;
    end;

    if Match(tkLeftBracket) then
    begin
      LTable := ParseTable;
      LDoc.AddTable(LTable);
    end
    else if not IsEof then
      Error('Expected table or end of file');

    SkipTrivia;
  end;

  Result := LDoc;
end;

function TTomlParser.Parse: TTomlDocumentSyntax;
begin
  FPosition := 0;
  FDocument := ParseDocument;
  Result := FDocument;
end;

end.
