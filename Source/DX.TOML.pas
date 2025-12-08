{*******************************************************************************
  DX.TOML - TOML Parser for Delphi

  Description:
    A modern, spec-compliant TOML 1.0.0 parser for Delphi with round-trip
    capability. This is a single-unit library combining lexer, parser, AST,
    and DOM components.

    Architecture (within single unit):
    1. Lexer - Tokenization with position tracking
    2. AST - Abstract Syntax Tree for round-trip preservation
    3. Parser - TOML 1.0.0 compliant parser
    4. DOM - Document Object Model for runtime access

  Usage:
    uses
      DX.TOML;

    var
      LToml: TToml;
    begin
      LToml := TToml.FromFile('config.toml');
      try
        ShowMessage(LToml['title'].AsString);
      finally
        LToml.Free;
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
  System.Generics.Collections,
  System.Character,
  System.Rtti,
  System.DateUtils,
  System.IOUtils,
  System.TypInfo,
  System.Math;

const
  {$REGION 'Character Constants'}
  // ASCII Control Characters
  CH_NULL = #0;
  CH_BACKSPACE = #8;
  CH_TAB = #9;
  CH_LF = #10;
  CH_FF = #12;
  CH_CR = #13;
  CH_DELETE = #127;

  // Line ending sequences
  CRLF = #13#10;
  {$ENDREGION}

  {$REGION 'Unicode Constants'}
  // Unicode limits
  MAX_BMP_CODEPOINT = $FFFF;
  MAX_UNICODE_CODEPOINT = $10FFFF;
  SURROGATE_OFFSET = $10000;

  // Surrogate pair ranges
  HIGH_SURROGATE_BASE = $D800;
  LOW_SURROGATE_BASE = $DC00;
  {$ENDREGION}

  {$REGION 'Number Format Constants'}
  // Number base prefixes
  PREFIX_HEX = '0x';
  PREFIX_OCTAL = '0o';
  PREFIX_BINARY = '0b';

  // Number bases
  BASE_BINARY = 2;
  BASE_OCTAL = 8;
  BASE_DECIMAL = 10;
  BASE_HEX = 16;
  {$ENDREGION}

type
  {$REGION 'Forward Declarations'}
  TTomlToken = class;
  TTomlLexer = class;
  TTomlSyntaxNode = class;
  TTomlDocumentSyntax = class;
  TTomlParser = class;
  TTomlValue = class;
  TToml = class;
  TTomlArray = class;
  {$ENDREGION}

  {$REGION 'Lexer Types'}
  /// <summary>TOML token type enumeration</summary>
  TTomlTokenKind = (
    // End of file
    tkEof,

    // Literals
    tkString,                  // "string" or 'literal string'
    tkMultiLineString,         // """multi-line""" or '''literal'''
    tkInteger,                 // 42, 0x1A, 0o755, 0b1010
    tkFloat,                   // 3.14, 6.02e23
    tkBoolean,                 // true, false
    tkDateTime,                // 1979-05-27T07:32:00Z
    tkDate,                    // 1979-05-27
    tkTime,                    // 07:32:00

    // Identifiers
    tkBareKey,                 // bare_key

    // Structural
    tkDot,                     // .
    tkComma,                   // ,
    tkEquals,                  // =
    tkLeftBracket,             // [
    tkRightBracket,            // ]
    tkLeftBrace,               // {
    tkRightBrace,              // }
    tkNewLine,                 // \n or \r\n

    // Trivia
    tkWhitespace,              // spaces, tabs
    tkComment                  // # comment
  );

  /// <summary>Token position in source</summary>
  TTomlPosition = record
    Line: Integer;
    Column: Integer;
    Offset: Integer;

    constructor Create(ALine, AColumn, AOffset: Integer);
  end;

  /// <summary>Scanner state for save/restore lookahead operations</summary>
  TScannerState = record
    Position: Integer;
    Line: Integer;
    Column: Integer;
  end;

  /// <summary>Individual token</summary>
  TTomlToken = class
  private
    FKind: TTomlTokenKind;
    FText: string;
    FPosition: TTomlPosition;
  public
    constructor Create(AKind: TTomlTokenKind; const AText: string; APosition: TTomlPosition);

    property Kind: TTomlTokenKind read FKind;
    property Text: string read FText;
    property Position: TTomlPosition read FPosition;
  end;

  /// <summary>TOML lexer/tokenizer</summary>
  TTomlLexer = class
  private
    FSource: string;
    FPosition: Integer;
    FLine: Integer;
    FColumn: Integer;
    FTokens: TObjectList<TTomlToken>;

    function GetCurrentChar: Char;
    function GetLookahead(AOffset: Integer): Char;
    function IsEof: Boolean;

    procedure Advance(ACount: Integer = 1);
    function CreatePosition: TTomlPosition;

    /// <summary>Save current scanner state for lookahead operations</summary>
    function SaveState: TScannerState;
    /// <summary>Restore previously saved scanner state</summary>
    procedure RestoreState(const AState: TScannerState);

    procedure ScanWhitespace;
    procedure ScanComment;
    procedure ScanNewLine;
    procedure ScanString(ADelimiter: Char);
    procedure ScanMultiLineString(ADelimiter: Char);
    procedure ScanNumber;
    procedure ScanBareKeyOrKeyword;
    procedure ValidateDateTimeFormat(const AText: string; AKind: TTomlTokenKind; const APos: TTomlPosition);

    function IsWhitespace(AChar: Char): Boolean;
    function IsBareKeyChar(AChar: Char): Boolean;
    function IsDigit(AChar: Char): Boolean;
    /// <summary>Check if current position looks like start of a number (not bare key)</summary>
    function LooksLikeNumber: Boolean;
    /// <summary>Check if we're in dotted key context (after dot, bracket, or comma)</summary>
    function InDottedKeyContext: Boolean;
  public
    constructor Create(const ASource: string);
    destructor Destroy; override;

    /// <summary>Tokenize the entire source</summary>
    procedure Tokenize;

    /// <summary>Get all tokens</summary>
    property Tokens: TObjectList<TTomlToken> read FTokens;
  end;
  {$ENDREGION}

  {$REGION 'AST Types'}
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
  {$ENDREGION}

  {$REGION 'Parser Types'}
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

    /// <summary>Skip CRLF or LF sequence, advancing the index appropriately</summary>
    /// <returns>True if a line ending was skipped</returns>
    class function SkipCRLF(var AIndex: Integer; const AText: string): Boolean;

    /// <summary>Process a single escape sequence starting at AIndex</summary>
    /// <param name="AText">The input text</param>
    /// <param name="AIndex">Current position (will be advanced past the escape sequence)</param>
    /// <param name="AIsMultiline">True if processing a multiline string</param>
    /// <returns>The unescaped character(s)</returns>
    function ProcessEscapeSequence(const AText: string; var AIndex: Integer; AIsMultiline: Boolean): string;

    procedure Error(const AMessage: string);
  public
    constructor Create(ALexer: TTomlLexer);
    destructor Destroy; override;

    /// <summary>Parse tokens into AST</summary>
    function Parse: TTomlDocumentSyntax;
  end;
  {$ENDREGION}

  {$REGION 'DOM Types'}
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
    FRawText: string;  // For DateTime: preserve original RFC 3339 format

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
    constructor CreateDateTime(AValue: TDateTime; const ARawText: string = '');
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
    property RawText: string read FRawText;  // Original text (for DateTime RFC 3339 format)
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
    FIsInline: Boolean;

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
    property IsInline: Boolean read FIsInline write FIsInline;
  end;

  /// <summary>AST to DOM converter (internal)</summary>
  TTomlDomBuilder = class
  private
    class function ConvertValue(ANode: TTomlSyntaxNode): TTomlValue;
    class function ConvertArray(ANode: TTomlArraySyntax): TTomlArray;
    class function ConvertInlineTable(ANode: TTomlInlineTableSyntax): TToml;
    class procedure ApplyKeyValue(ATable: TToml; AKeyValue: TTomlKeyValueSyntax;
      const AContextPath: string = ''; AExplicitTables: TList<string> = nil;
      AImplicitTables: TList<string> = nil);
    class function ParseInteger(const AText: string): Int64;
    class function ParseFloat(const AText: string): Double;
    class function ParseDateTime(const AText: string): TDateTime;
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
  {$ENDREGION}

implementation

{$REGION 'Lexer Implementation'}

{ TTomlPosition }

constructor TTomlPosition.Create(ALine, AColumn, AOffset: Integer);
begin
  Line := ALine;
  Column := AColumn;
  Offset := AOffset;
end;

{ TTomlToken }

constructor TTomlToken.Create(AKind: TTomlTokenKind; const AText: string; APosition: TTomlPosition);
begin
  inherited Create;
  FKind := AKind;
  FText := AText;
  FPosition := APosition;
end;

{ TTomlLexer }

constructor TTomlLexer.Create(const ASource: string);
begin
  inherited Create;
  FSource := ASource;
  FPosition := 1;  // Delphi strings are 1-based
  FLine := 1;
  FColumn := 1;
  FTokens := TObjectList<TTomlToken>.Create(True);
end;

destructor TTomlLexer.Destroy;
begin
  FTokens.Free;
  inherited;
end;

function TTomlLexer.GetCurrentChar: Char;
begin
  if IsEof then
    Result := #0
  else
    Result := FSource[FPosition];
end;

function TTomlLexer.GetLookahead(AOffset: Integer): Char;
var
  LPos: Integer;
begin
  LPos := FPosition + AOffset;
  if (LPos < 1) or (LPos > Length(FSource)) then
    Result := #0
  else
    Result := FSource[LPos];
end;

function TTomlLexer.IsEof: Boolean;
begin
  Result := FPosition > Length(FSource);
end;

procedure TTomlLexer.Advance(ACount: Integer);
var
  i: Integer;
begin
  for i := 1 to ACount do
  begin
    if not IsEof then
    begin
      Inc(FPosition);
      Inc(FColumn);
    end;
  end;
end;

function TTomlLexer.CreatePosition: TTomlPosition;
begin
  Result := TTomlPosition.Create(FLine, FColumn, FPosition);
end;

function TTomlLexer.SaveState: TScannerState;
begin
  Result.Position := FPosition;
  Result.Line := FLine;
  Result.Column := FColumn;
end;

procedure TTomlLexer.RestoreState(const AState: TScannerState);
begin
  FPosition := AState.Position;
  FLine := AState.Line;
  FColumn := AState.Column;
end;

function TTomlLexer.IsWhitespace(AChar: Char): Boolean;
begin
  Result := (AChar = ' ') or (AChar = #9);  // Space or Tab
end;

function TTomlLexer.IsBareKeyChar(AChar: Char): Boolean;
begin
  Result := AChar.IsLetterOrDigit or (AChar = '_') or (AChar = '-');
end;

function TTomlLexer.IsDigit(AChar: Char): Boolean;
begin
  Result := AChar.IsDigit;
end;

function TTomlLexer.LooksLikeNumber: Boolean;
var
  LChar: Char;
  LNext: Char;
begin
  // Check if current position looks like a number vs a bare key
  // Conservative approach: only say it's a number if we're sure
  // Numbers can start with: +, -, 0-9
  // But bare keys can also start with these, so we need to check context

  LChar := GetCurrentChar;

  // If it starts with a digit, it's a number UNLESS followed by a letter
  // (except for hex/octal/binary prefixes)
  if IsDigit(LChar) then
  begin
    LNext := GetLookahead(1);
    // If it's "0x", "0o", "0b", it's definitely a number
    if (LChar = '0') and CharInSet(LNext, ['x', 'X', 'o', 'O', 'b', 'B']) then
      Exit(True);
    // If next is a letter (not part of number), it's a bare key like "1key"
    if LNext.IsLetter and not CharInSet(LNext, ['x', 'X', 'o', 'O', 'b', 'B', 'e', 'E']) then
      Exit(False);
    // Otherwise it's likely a number (digit, underscore, colon for datetime, etc.)
    Result := True;
  end
  // If it starts with +/-, check next character
  else if CharInSet(LChar, ['+', '-']) then
  begin
    LNext := GetLookahead(1);
    // If followed by digit, it's a number
    // If followed by 'i' (inf) or 'n' (nan), it's a number
    // If followed by '.', it might be an invalid number like "+.5" - treat as number to get proper error
    if IsDigit(LNext) or (LNext = 'i') or (LNext = 'n') or (LNext = '.') then
      Result := True
    // If followed by another sign, check if it's an invalid number like "++99" (sign sign digit)
    // vs a valid bare key like "--" or "+-" (just signs)
    else if CharInSet(LNext, ['+', '-']) then
    begin
      // Look at the character after the second sign
      var LThird := GetLookahead(2);
      // If followed by digit or dot, it's an invalid number like "++99" or "+-5"
      Result := IsDigit(LThird) or (LThird = '.');
    end
    else
      Result := False;  // It's a bare key like "-key" or just "-"
  end
  else
    Result := False;
end;

function TTomlLexer.InDottedKeyContext: Boolean;
var
  i: Integer;
  LBracketDepth: Integer;
  LBraceDepth: Integer;
begin
  // Check if we're in a context where dots separate keys (not decimal points)
  // We need to distinguish:
  //   - Array context [1, 2.5] - dots are decimals
  //   - Table header [x.1.2] - dots separate keys
  //   - Inline table {a=1, b.2=3} - dots separate keys
  Result := False;
  LBracketDepth := 0;
  LBraceDepth := 0;

  // Look back from current position
  for i := FTokens.Count - 1 downto 0 do
  begin
    case FTokens[i].Kind of
      tkWhitespace, tkComment:
        Continue;  // Skip whitespace/trivia (but not newlines!)

      tkNewLine:
        begin
          // If we hit a newline and we're not inside brackets/braces, stop
          if (LBracketDepth = 0) and (LBraceDepth = 0) then
            Exit(False);
        end;

      tkRightBracket:
        Inc(LBracketDepth);  // Count backwards

      tkLeftBracket:
        begin
          Dec(LBracketDepth);
          // If this is the opening bracket and we're at depth 0, check context
          if LBracketDepth < 0 then
          begin
            // Check if this is a table header (at start of line) or array
            // Table headers are at start of line (after newline/start)
            // Arrays are after = or , or [
            if i = 0 then
              Exit(True);  // First token - must be table header

            // Look back one more token
            var j := i - 1;
            while (j >= 0) and (FTokens[j].Kind in [tkWhitespace, tkComment]) do
              Dec(j);

            if j >= 0 then
            begin
              case FTokens[j].Kind of
                tkNewLine:
                  Exit(True);  // After newline = table header
                tkEquals, tkComma, tkLeftBracket:
                  Exit(False);  // Array context
              end;
            end;

            Exit(True);  // Default to table header if unclear
          end;
        end;

      tkRightBrace:
        Inc(LBraceDepth);

      tkLeftBrace:
        begin
          Dec(LBraceDepth);
          if LBraceDepth < 0 then
            Exit(True);  // Inside inline table = dotted key context
        end;

      tkDot:
        begin
          // After a dot, only in key context if not inside array
          if LBracketDepth = 0 then
            Exit(True);
        end;

      tkComma:
        begin
          // After comma, only in key context if inside inline table (braces)
          if (LBracketDepth = 0) and (LBraceDepth > 0) then
            Exit(True);
        end;

      tkEquals:
        // After equals, we're in value context (not key context)
        Exit(False);

      else
        // Any other token - if we're inside braces, we're in key context
        if LBraceDepth > 0 then
          Exit(True)
        else
          Exit(False);
    end;
  end;
end;

procedure TTomlLexer.ScanWhitespace;
var
  LStart: TTomlPosition;
  LText: string;
begin
  LStart := CreatePosition;
  LText := '';

  while not IsEof and IsWhitespace(GetCurrentChar) do
  begin
    LText := LText + GetCurrentChar;
    Advance;
  end;

  FTokens.Add(TTomlToken.Create(tkWhitespace, LText, LStart));
end;

procedure TTomlLexer.ScanComment;
var
  LStart: TTomlPosition;
  LText: string;
begin
  LStart := CreatePosition;
  LText := '';

  // Skip '#'
  LText := LText + GetCurrentChar;
  Advance;

  // Read until end of line
  while not IsEof do
  begin
    var LChar := GetCurrentChar;

    // Stop at end of line (LF or CRLF)
    if CharInSet(LChar, [CH_LF, CH_CR]) then
    begin
      // Validate that CR is part of CRLF, not standalone
      if LChar = CH_CR then
      begin
        // Standalone CR is not allowed in comments
        if not ((FPosition < Length(FSource)) and (FSource[FPosition + 1] = CH_LF)) then
          raise ETomlParserException.Create(
            'Standalone carriage return (CR) is not allowed in comments',
            LStart);
      end;
      Break;  // End of line reached
    end;

    // Validate control characters in comments
    // TAB (0x09) is allowed, but other control chars (0x00-0x1F except TAB, and 0x7F) are not
    var LOrd := Ord(LChar);
    if ((LOrd <= 31) or (LOrd = 127)) and (LChar <> CH_TAB) then
      raise ETomlParserException.Create(
        Format('Control character 0x%2.2X is not allowed in comments', [LOrd]),
        LStart);

    LText := LText + LChar;
    Advance;
  end;

  FTokens.Add(TTomlToken.Create(tkComment, LText, LStart));
end;

procedure TTomlLexer.ScanNewLine;
var
  LStart: TTomlPosition;
  LText: string;
begin
  LStart := CreatePosition;
  LText := '';

  // Handle \r\n or \n
  // Standalone CR (not followed by LF) is not allowed
  if GetCurrentChar = #13 then
  begin
    LText := LText + GetCurrentChar;
    Advance;

    // CR must be followed by LF
    if GetCurrentChar <> #10 then
      raise ETomlParserException.Create(
        'Standalone carriage return (CR) is not allowed',
        LStart);
  end;

  if GetCurrentChar = #10 then
  begin
    LText := LText + GetCurrentChar;
    Advance;
  end;

  Inc(FLine);
  FColumn := 1;

  FTokens.Add(TTomlToken.Create(tkNewLine, LText, LStart));
end;

procedure TTomlLexer.ScanString(ADelimiter: Char);
var
  LStart: TTomlPosition;
  LText: string;
  LEscaped: Boolean;
  LClosed: Boolean;
  LIsLiteral: Boolean;
begin
  LStart := CreatePosition;
  LText := '';
  LClosed := False;

  // Literal strings (single quotes) don't process escape sequences
  LIsLiteral := (ADelimiter = '''');

  // Skip opening delimiter
  LText := LText + GetCurrentChar;
  Advance;

  LEscaped := False;
  while not IsEof do
  begin
    if LEscaped then
    begin
      LText := LText + GetCurrentChar;
      Advance;
      LEscaped := False;
    end
    else if (not LIsLiteral) and (GetCurrentChar = '\') then
    begin
      // Only treat backslash as escape in double-quoted strings
      LText := LText + GetCurrentChar;
      Advance;
      LEscaped := True;
    end
    else if GetCurrentChar = ADelimiter then
    begin
      LText := LText + GetCurrentChar;
      Advance;
      LClosed := True;
      Break;
    end
    else
    begin
      var LChar := GetCurrentChar;

      // Validate: single-line strings cannot contain unescaped newlines or CR
      if LChar = CH_CR then
        raise ETomlParserException.Create(
          'Carriage return (CR) is not allowed in single-line strings',
          LStart);
      if LChar = CH_LF then
        raise ETomlParserException.Create(
          'Line feed (LF) is not allowed in single-line strings',
          LStart);

      LText := LText + LChar;
      Advance;
    end;
  end;

  // Check if string was properly closed
  if not LClosed then
    raise Exception.Create('Unclosed string');

  FTokens.Add(TTomlToken.Create(tkString, LText, LStart));
end;

procedure TTomlLexer.ScanMultiLineString(ADelimiter: Char);
var
  LStart: TTomlPosition;
  LText: string;
  LQuoteCount: Integer;
  LClosed: Boolean;
begin
  LStart := CreatePosition;
  LText := '';
  LClosed := False;

  // Add opening triple delimiter to text
  LText := LText + GetCurrentChar;
  Advance;
  LText := LText + GetCurrentChar;
  Advance;
  LText := LText + GetCurrentChar;
  Advance;

  while not IsEof do
  begin
    if GetCurrentChar = ADelimiter then
    begin
      // Look ahead to count consecutive quotes
      LQuoteCount := 0;
      var LSavedState := SaveState;

      while (not IsEof) and (GetCurrentChar = ADelimiter) do
      begin
        Inc(LQuoteCount);
        Advance;
      end;

      // Restore position
      RestoreState(LSavedState);

      // If we found 3+ quotes, handle based on count:
      // - Exactly 3: closing delimiter
      // - 4+: extra quotes are content, last 3 are closing delimiter
      if LQuoteCount >= 3 then
      begin
        // Add any extra quotes (beyond the closing 3) as content
        for var i := 1 to LQuoteCount - 3 do
        begin
          LText := LText + ADelimiter;
          Advance;
        end;

        // Add the 3 closing quotes to text (parser expects delimiters in token)
        LText := LText + ADelimiter;
        Advance;
        LText := LText + ADelimiter;
        Advance;
        LText := LText + ADelimiter;
        Advance;
        LClosed := True;
        Break;
      end
      else
      begin
        // Less than 3 quotes - they're part of the string content
        for var i := 1 to LQuoteCount do
        begin
          LText := LText + ADelimiter;
          Advance;
        end;
      end;
    end
    else
    begin
      // Handle escape sequences (only in basic strings, not literal strings)
      if (GetCurrentChar = '\') and (ADelimiter = '"') then
      begin
        // Add backslash
        LText := LText + GetCurrentChar;
        Advance;

        // Add escaped character (don't interpret it)
        if not IsEof then
        begin
          if GetCurrentChar = #10 then
          begin
            Inc(FLine);
            FColumn := 0;
          end;
          LText := LText + GetCurrentChar;
          Advance;
        end;
      end
      else
      begin
        var LChar := GetCurrentChar;

        // In multiline strings, validate that CR is only part of CRLF
        if LChar = CH_CR then
        begin
          // Check if CR is followed by LF
          if not ((FPosition < Length(FSource)) and (FSource[FPosition + 1] = CH_LF)) then
            raise ETomlParserException.Create(
              'Standalone carriage return (CR) is not allowed in multiline strings',
              LStart);
        end;

        if LChar = CH_LF then
        begin
          Inc(FLine);
          FColumn := 0;  // Will be incremented by Advance
        end;

        LText := LText + LChar;
        Advance;
      end;
    end;
  end;

  // Check if string was properly closed
  if not LClosed then
    raise ETomlParserException.Create('Unclosed multiline string', LStart);

  FTokens.Add(TTomlToken.Create(tkMultiLineString, LText, LStart));
end;

procedure TTomlLexer.ScanNumber;
var
  LStart: TTomlPosition;
  LText: string;
  LCheckText: string;
  LKind: TTomlTokenKind;
  LPrefix: Char;
  i: Integer;
begin
  LStart := CreatePosition;
  LText := '';
  LKind := tkInteger;

  // Handle sign
  if CharInSet(GetCurrentChar, ['+', '-']) then
  begin
    LText := LText + GetCurrentChar;
    Advance;

    // Check for special float values (inf, nan) after sign
    if (GetCurrentChar = 'i') and (GetLookahead(1) = 'n') and (GetLookahead(2) = 'f') then
    begin
      LText := LText + 'inf';
      Advance;
      Advance;
      Advance;
      LKind := tkFloat;
      FTokens.Add(TTomlToken.Create(LKind, LText, LStart));
      Exit;
    end
    else if (GetCurrentChar = 'n') and (GetLookahead(1) = 'a') and (GetLookahead(2) = 'n') then
    begin
      LText := LText + 'nan';
      Advance;
      Advance;
      Advance;
      LKind := tkFloat;
      FTokens.Add(TTomlToken.Create(LKind, LText, LStart));
      Exit;
    end
    else
    begin
      // After sign, must have a digit (not a dot or other character)
      if not IsDigit(GetCurrentChar) then
        raise ETomlParserException.Create(
          'Number with sign must be followed by digit, not: ' + GetCurrentChar,
          LStart);
    end;
  end;

  // Handle special prefixes (0x, 0o, 0b)
  if (GetCurrentChar = '0') and CharInSet(GetLookahead(1), ['x', 'o', 'b']) then
  begin
    LPrefix := GetLookahead(1);
    LText := LText + GetCurrentChar;
    Advance;
    LText := LText + GetCurrentChar;
    Advance;

    // Read hex/octal/binary digits
    while not IsEof and (IsBareKeyChar(GetCurrentChar) or IsDigit(GetCurrentChar)) do
    begin
      LText := LText + GetCurrentChar;
      Advance;
    end;

    // Validate hex/octal/binary format and digits
    // Check for incomplete number (just "0x", "0o", "0b" with no digits)
    if Length(LText) < 3 then
    begin
      var LNumberType: string;
      case LPrefix of
        'x': LNumberType := 'hex';
        'o': LNumberType := 'octal';
        'b': LNumberType := 'binary';
      end;
      raise ETomlParserException.Create(
        Format('Incomplete %s number: must have at least one digit after prefix', [LNumberType]),
        LStart);
    end;

    // Check for leading underscore after prefix (e.g., 0x_123)
    if LText[3] = '_' then
      raise ETomlParserException.Create('Underscore cannot immediately follow number prefix', LStart);

    // Check for trailing underscore
    if LText[Length(LText)] = '_' then
      raise ETomlParserException.Create('Number cannot end with underscore', LStart);

    // Validate each character
    var LHasDigit := False;
    for i := 3 to Length(LText) do
    begin
      if LText[i] = '_' then
      begin
        // Check for consecutive underscores
        if (i < Length(LText)) and (LText[i + 1] = '_') then
          raise ETomlParserException.Create('Numbers cannot have consecutive underscores', LStart);
        Continue;
      end;

      LHasDigit := True;
      case LPrefix of
        'x': // Hex: 0-9, A-F, a-f
          if not CharInSet(LText[i], ['0'..'9', 'A'..'F', 'a'..'f']) then
            raise ETomlParserException.Create(Format('Invalid hex digit: %s', [LText[i]]), LStart);
        'o': // Octal: 0-7
          if not CharInSet(LText[i], ['0'..'7']) then
            raise ETomlParserException.Create(Format('Invalid octal digit: %s', [LText[i]]), LStart);
        'b': // Binary: 0-1
          if not CharInSet(LText[i], ['0'..'1']) then
            raise ETomlParserException.Create(Format('Invalid binary digit: %s', [LText[i]]), LStart);
      end;
    end;

    // Ensure we have at least one valid digit (not just underscores)
    if not LHasDigit then
      raise ETomlParserException.Create('Number must contain at least one digit', LStart);
  end
  else
  begin
    // Read digits
    while not IsEof and (IsDigit(GetCurrentChar) or (GetCurrentChar = '_')) do
    begin
      LText := LText + GetCurrentChar;
      Advance;
    end;

    // Check for float
    // But don't consume dot if this looks like a dotted key (e.g., "1.2 = 3" or "[x.1.2]")
    if GetCurrentChar = '.' then
    begin
      // Look ahead to see if this is a dotted key or a float
      // Dotted key pattern: digit+ '.' digit+ whitespace* '=' OR inside brackets/after comma
      // Float pattern: digit+ '.' digit+ (in value context)
      var LSavedState := SaveState;
      var LIsDottedKey := False;

      // First check: are we in a dotted key context (brackets, after dot, after comma)?
      if InDottedKeyContext then
        LIsDottedKey := True
      else
      begin
        // Second check: look ahead for '=' pattern
        // Tentatively consume the dot and digits
        Advance; // skip dot
        while not IsEof and (IsDigit(GetCurrentChar) or (GetCurrentChar = '_')) do
          Advance;

        // Skip whitespace
        while not IsEof and CharInSet(GetCurrentChar, [' ', #9]) do
          Advance;

        // Check if we see '=' (dotted key) or something else (float)
        if GetCurrentChar = '=' then
          LIsDottedKey := True;
      end;

      // Restore position
      RestoreState(LSavedState);

      // If not a dotted key, consume as float
      if not LIsDottedKey then
      begin
        LKind := tkFloat;
        LText := LText + GetCurrentChar;
        Advance;

        while not IsEof and (IsDigit(GetCurrentChar) or (GetCurrentChar = '_')) do
        begin
          LText := LText + GetCurrentChar;
          Advance;
        end;
      end;
    end;

    // Check for exponent
    if CharInSet(GetCurrentChar, ['e', 'E']) then
    begin
      LKind := tkFloat;
      LText := LText + GetCurrentChar;
      Advance;

      if CharInSet(GetCurrentChar, ['+', '-']) then
      begin
        LText := LText + GetCurrentChar;
        Advance;
      end;

      while not IsEof and (IsDigit(GetCurrentChar) or (GetCurrentChar = '_')) do
      begin
        LText := LText + GetCurrentChar;
        Advance;
      end;
    end;

    // Check for date/time formats (YYYY-MM-DD or HH:MM:SS)
    // Only treat as date if next char after '-' is a digit (not a letter like in "2000-datetime")
    if (GetCurrentChar = '-') and IsDigit(GetLookahead(1)) then
    begin
      // Might be a date (1979-05-27) or datetime (1979-05-27T07:32:00)
      LText := LText + GetCurrentChar;
      Advance;

      // Read MM
      while not IsEof and IsDigit(GetCurrentChar) do
      begin
        LText := LText + GetCurrentChar;
        Advance;
      end;

      if GetCurrentChar = '-' then
      begin
        LText := LText + GetCurrentChar;
        Advance;

        // Read DD
        while not IsEof and IsDigit(GetCurrentChar) do
        begin
          LText := LText + GetCurrentChar;
          Advance;
        end;

        // Check for time part (T07:32:00 or space separator: 1987-07-05 17:45:00)
        // For space separator, verify next char is a digit
        if CharInSet(GetCurrentChar, ['T', 't']) or
           ((GetCurrentChar = ' ') and IsDigit(GetLookahead(1))) then
        begin
          LKind := tkDateTime;
          LText := LText + GetCurrentChar;
          Advance;

          // Read time part (HH:MM:SS)
          while not IsEof and (IsDigit(GetCurrentChar) or CharInSet(GetCurrentChar, [':', '.'])) do
          begin
            LText := LText + GetCurrentChar;
            Advance;
          end;

          // Check for timezone (Z/z or +/-HH:MM)
          if CharInSet(GetCurrentChar, ['Z', 'z']) then
          begin
            LText := LText + GetCurrentChar;
            Advance;
          end
          else if CharInSet(GetCurrentChar, ['+', '-']) then
          begin
            LText := LText + GetCurrentChar;
            Advance;

            // Read timezone offset (HH:MM)
            while not IsEof and (IsDigit(GetCurrentChar) or (GetCurrentChar = ':')) do
            begin
              LText := LText + GetCurrentChar;
              Advance;
            end;
          end;
        end
        else
        begin
          LKind := tkDate;
        end;
      end;
    end
    else if GetCurrentChar = ':' then
    begin
      // Time format (07:32:00)
      LKind := tkTime;
      LText := LText + GetCurrentChar;
      Advance;

      // Read rest of time
      while not IsEof and (IsDigit(GetCurrentChar) or CharInSet(GetCurrentChar, [':', '.'])) do
      begin
        LText := LText + GetCurrentChar;
        Advance;
      end;
    end;

    // Check if this is actually part of a bareword key (e.g., "2000-datetime")
    // If we see "-" followed by a letter or underscore, treat as bareword
    if (LKind in [tkInteger, tkFloat]) and (GetCurrentChar = '-') and
       (not IsEof) and CharInSet(GetLookahead(1), ['a'..'z', 'A'..'Z', '_']) then
    begin
      // Continue reading as bareword
      while not IsEof and IsBareKeyChar(GetCurrentChar) do
      begin
        LText := LText + GetCurrentChar;
        Advance;
      end;
      LKind := tkBareKey;
    end
    else
    begin
      // Check for leading zeros (not allowed in TOML integer values)
      // Only check for integer/float types, not for date/time
      // If has leading zeros, treat as bareword key instead of number
      if (LKind in [tkInteger, tkFloat]) then
      begin
        // Remove sign for checking
        LCheckText := LText;
        if (Length(LCheckText) > 0) and CharInSet(LCheckText[1], ['+', '-']) then
          Delete(LCheckText, 1, 1);

        // Check for leading zero (but allow 0.x and 0ex for floats)
        // Numbers with leading zeros like 000111 are treated as bareword keys
        if (Length(LCheckText) > 1) and (LCheckText[1] = '0') and
           not CharInSet(LCheckText[2], ['.', 'e', 'E']) then
          LKind := tkBareKey;  // Treat as bareword key, not error
      end;
    end;
  end;

  // Validate number format (only for integers and floats, not dates or special bases)
  if (LKind = tkInteger) or (LKind = tkFloat) then
  begin
    var LValidationText := LText;
    // Remove sign for validation
    if (Length(LValidationText) > 0) and CharInSet(LValidationText[1], ['+', '-']) then
      Delete(LValidationText, 1, 1);

    // Skip validation for hex/octal/binary numbers (they have different rules)
    if (Length(LValidationText) >= 2) and (LValidationText[1] = '0') and
       CharInSet(LValidationText[2], ['x', 'o', 'b']) then
    begin
      // Hex/octal/binary - these are validated separately in the scanning code
      // Don't apply decimal/exponent rules to them
    end
    else
    begin
      // Check for various invalid patterns in decimal numbers
      for i := 1 to Length(LValidationText) do
      begin
        var LChar := LValidationText[i];

      // Check for leading underscore (e.g., _123, 1e_23)
      if (LChar = '_') and (i = 1) then
        raise ETomlParserException.Create('Numbers cannot start with underscore', LStart);

      // Check for trailing underscore (e.g., 123_, 1e23_)
      if (LChar = '_') and (i = Length(LValidationText)) then
        raise ETomlParserException.Create('Numbers cannot end with underscore', LStart);

      // Check for double underscore (e.g., 1__000)
      if (LChar = '_') and (i < Length(LValidationText)) and (LValidationText[i + 1] = '_') then
        raise ETomlParserException.Create('Numbers cannot have consecutive underscores', LStart);

      // Check for underscore after prefix (e.g., 0x_123, 0b_101)
      if (LChar = '_') and (i = 3) and (Length(LValidationText) >= 2) and
         (LValidationText[1] = '0') and CharInSet(LValidationText[2], ['x', 'o', 'b']) then
        raise ETomlParserException.Create('Underscore cannot follow number prefix', LStart);

      // Check for decimal point without following digits (e.g., 1.)
      // Also check for decimal point without preceding digits (e.g., .5)
      if (LChar = '.') then
      begin
        // Must have at least one digit before decimal point
        if i = 1 then
          raise ETomlParserException.Create('Decimal point must be preceded by at least one digit', LStart);
        // Must have digit after decimal point
        if (i = Length(LValidationText)) or not CharInSet(LValidationText[i + 1], ['0'..'9']) then
          raise ETomlParserException.Create('Decimal point must be followed by digits', LStart);
      end;

      // Check for exponent without following digits (e.g., 1e, 1e+)
      if CharInSet(LChar, ['e', 'E']) then
      begin
        var LNextIdx := i + 1;
        // Skip optional sign
        if (LNextIdx <= Length(LValidationText)) and CharInSet(LValidationText[LNextIdx], ['+', '-']) then
          Inc(LNextIdx);
        // Check for digit
        if (LNextIdx > Length(LValidationText)) or not CharInSet(LValidationText[LNextIdx], ['0'..'9']) then
          raise ETomlParserException.Create('Exponent must be followed by digits', LStart);
      end;

      // Check for underscore before/after decimal point (e.g., 1_.0, 1._0)
      if (LChar = '.') then
      begin
        if (i > 1) and (LValidationText[i - 1] = '_') then
          raise ETomlParserException.Create('Underscore cannot precede decimal point', LStart);
        if (i < Length(LValidationText)) and (LValidationText[i + 1] = '_') then
          raise ETomlParserException.Create('Underscore cannot follow decimal point', LStart);
      end;

      // Check for underscore before/after exponent (e.g., 1_e2, 1e_2)
      if CharInSet(LChar, ['e', 'E']) then
      begin
        if (i > 1) and (LValidationText[i - 1] = '_') then
          raise ETomlParserException.Create('Underscore cannot precede exponent', LStart);
        var LNextIdx := i + 1;
        // Skip optional sign
        if (LNextIdx <= Length(LValidationText)) and CharInSet(LValidationText[LNextIdx], ['+', '-']) then
          Inc(LNextIdx);
        if (LNextIdx <= Length(LValidationText)) and (LValidationText[LNextIdx] = '_') then
          raise ETomlParserException.Create('Underscore cannot follow exponent', LStart);
      end;
      end;  // end for loop
    end;  // end else (decimal validation)
  end;  // end if (tkInteger or tkFloat)

  // Validate DateTime/Date/Time formats
  if LKind in [tkDateTime, tkDate, tkTime] then
  begin
    ValidateDateTimeFormat(LText, LKind, LStart);
  end;

  FTokens.Add(TTomlToken.Create(LKind, LText, LStart));
end;

procedure TTomlLexer.ValidateDateTimeFormat(const AText: string; AKind: TTomlTokenKind; const APos: TTomlPosition);
var
  LParts: TArray<string>;
  LDatePart, LTimePart, LOffsetPart: string;
  LValue: Integer;

  function ValidateComponent(const AComponent, AName: string; AMinDigits, AMaxDigits, AMinValue, AMaxValue: Integer): Boolean;
  begin
    Result := False;

    // Check digit count
    if (Length(AComponent) < AMinDigits) or (Length(AComponent) > AMaxDigits) then
      raise ETomlParserException.Create(
        Format('%s must be exactly %d digits (got %d)', [AName, AMinDigits, Length(AComponent)]),
        APos);

    // Check all characters are digits
    for var I := 1 to Length(AComponent) do
      if not CharInSet(AComponent[I], ['0'..'9']) then
        raise ETomlParserException.Create(
          Format('%s contains non-digit character', [AName]),
          APos);

    // Check numeric range
    if not TryStrToInt(AComponent, LValue) or (LValue < AMinValue) or (LValue > AMaxValue) then
      raise ETomlParserException.Create(
        Format('%s must be between %d and %d (got %d)', [AName, AMinValue, AMaxValue, LValue]),
        APos);

    Result := True;
  end;

begin
  case AKind of
    tkDate:
      begin
        // Format: YYYY-MM-DD
        LParts := AText.Split(['-']);
        if Length(LParts) <> 3 then
          raise ETomlParserException.Create('Invalid date format', APos);

        ValidateComponent(LParts[0], 'Year', 4, 4, 0, 9999);
        ValidateComponent(LParts[1], 'Month', 2, 2, 1, 12);
        ValidateComponent(LParts[2], 'Day', 2, 2, 1, 31);
      end;

    tkTime:
      begin
        // Format: HH:MM:SS or HH:MM:SS.ffffff
        var LDotPos := Pos('.', AText);
        if LDotPos > 0 then
          LTimePart := Copy(AText, 1, LDotPos - 1)
        else
          LTimePart := AText;

        LParts := LTimePart.Split([':']);
        if Length(LParts) <> 3 then
          raise ETomlParserException.Create('Invalid time format', APos);

        ValidateComponent(LParts[0], 'Hour', 2, 2, 0, 23);
        ValidateComponent(LParts[1], 'Minute', 2, 2, 0, 59);
        ValidateComponent(LParts[2], 'Second', 2, 2, 0, 60);  // Allow 60 for leap seconds
      end;

    tkDateTime:
      begin
        // Format: YYYY-MM-DD[T| ]HH:MM:SS[.ffffff][Z|+HH:MM|-HH:MM]
        // Split date and time parts
        var LUpperText := UpperCase(AText);
        var LSepPos := Pos('T', LUpperText);
        if LSepPos = 0 then
          LSepPos := Pos(' ', AText);

        if LSepPos = 0 then
          raise ETomlParserException.Create('Invalid datetime format', APos);

        LDatePart := Copy(AText, 1, LSepPos - 1);
        LTimePart := Copy(AText, LSepPos + 1, Length(AText) - LSepPos);

        // Validate date part
        LParts := LDatePart.Split(['-']);
        if Length(LParts) <> 3 then
          raise ETomlParserException.Create('Invalid date part in datetime', APos);

        ValidateComponent(LParts[0], 'Year', 4, 4, 0, 9999);
        ValidateComponent(LParts[1], 'Month', 2, 2, 1, 12);
        ValidateComponent(LParts[2], 'Day', 2, 2, 1, 31);

        // Extract time and offset parts
        LOffsetPart := '';
        var LUpperTime := UpperCase(LTimePart);
        if Pos('Z', LUpperTime) > 0 then
        begin
          LOffsetPart := 'Z';
          LTimePart := Copy(LTimePart, 1, Pos('Z', LUpperTime) - 1);
        end
        else if Pos('+', LTimePart) > 0 then
        begin
          var LPlusPos := Pos('+', LTimePart);
          LOffsetPart := Copy(LTimePart, LPlusPos, Length(LTimePart) - LPlusPos + 1);
          LTimePart := Copy(LTimePart, 1, LPlusPos - 1);
        end
        else if LastDelimiter('-', LTimePart) > Pos('-', LDatePart) then
        begin
          var LMinusPos := LastDelimiter('-', LTimePart);
          LOffsetPart := Copy(LTimePart, LMinusPos, Length(LTimePart) - LMinusPos + 1);
          LTimePart := Copy(LTimePart, 1, LMinusPos - 1);
        end;

        // Validate time part (without fractional seconds)
        var LDotPos := Pos('.', LTimePart);
        if LDotPos > 0 then
          LTimePart := Copy(LTimePart, 1, LDotPos - 1);

        LParts := LTimePart.Split([':']);
        if Length(LParts) <> 3 then
          raise ETomlParserException.Create('Invalid time part in datetime', APos);

        ValidateComponent(LParts[0], 'Hour', 2, 2, 0, 23);
        ValidateComponent(LParts[1], 'Minute', 2, 2, 0, 59);
        ValidateComponent(LParts[2], 'Second', 2, 2, 0, 60);

        // Validate offset if present
        if (LOffsetPart <> '') and (LOffsetPart <> 'Z') then
        begin
          // Remove leading +/-
          LOffsetPart := Copy(LOffsetPart, 2, Length(LOffsetPart) - 1);
          LParts := LOffsetPart.Split([':']);
          if Length(LParts) <> 2 then
            raise ETomlParserException.Create('Invalid timezone offset format', APos);

          ValidateComponent(LParts[0], 'Offset hour', 2, 2, 0, 24);
          ValidateComponent(LParts[1], 'Offset minute', 2, 2, 0, 59);
        end;
      end;
  end;
end;

procedure TTomlLexer.ScanBareKeyOrKeyword;
var
  LStart: TTomlPosition;
  LText: string;
  LKind: TTomlTokenKind;
begin
  LStart := CreatePosition;
  LText := '';
  LKind := tkBareKey;

  while not IsEof and IsBareKeyChar(GetCurrentChar) do
  begin
    var LChar := GetCurrentChar;

    // Validate control characters in bare keys
    // Control characters (0x00-0x1F and 0x7F) are not allowed in bare keys
    var LOrd := Ord(LChar);
    if (LOrd <= 31) or (LOrd = 127) then
      raise ETomlParserException.Create(
        Format('Control character 0x%2.2X is not allowed in bare keys', [LOrd]),
        LStart);

    LText := LText + LChar;
    Advance;
  end;

  // Check for keywords
  if LText = 'true' then
    LKind := tkBoolean
  else if LText = 'false' then
    LKind := tkBoolean
  else if LText = 'inf' then
    LKind := tkFloat
  else if LText = 'nan' then
    LKind := tkFloat;

  FTokens.Add(TTomlToken.Create(LKind, LText, LStart));
end;

procedure TTomlLexer.Tokenize;
var
  LChar: Char;
begin
  while not IsEof do
  begin
    LChar := GetCurrentChar;

    case LChar of
      ' ', #9:
        ScanWhitespace;

      '#':
        ScanComment;

      #13, #10:
        ScanNewLine;

      '"':
        if (GetLookahead(1) = '"') and (GetLookahead(2) = '"') then
          ScanMultiLineString('"')
        else
          ScanString('"');

      '''':
        if (GetLookahead(1) = '''') and (GetLookahead(2) = '''') then
          ScanMultiLineString('''')
        else
          ScanString('''');

      '.':
        begin
          FTokens.Add(TTomlToken.Create(tkDot, '.', CreatePosition));
          Advance;
        end;

      ',':
        begin
          FTokens.Add(TTomlToken.Create(tkComma, ',', CreatePosition));
          Advance;
        end;

      '=':
        begin
          FTokens.Add(TTomlToken.Create(tkEquals, '=', CreatePosition));
          Advance;
        end;

      '[':
        begin
          FTokens.Add(TTomlToken.Create(tkLeftBracket, '[', CreatePosition));
          Advance;
        end;

      ']':
        begin
          FTokens.Add(TTomlToken.Create(tkRightBracket, ']', CreatePosition));
          Advance;
        end;

      '{':
        begin
          FTokens.Add(TTomlToken.Create(tkLeftBrace, '{', CreatePosition));
          Advance;
        end;

      '}':
        begin
          FTokens.Add(TTomlToken.Create(tkRightBrace, '}', CreatePosition));
          Advance;
        end;

      '0'..'9', '+', '-':
        if LooksLikeNumber then
          ScanNumber
        else
          ScanBareKeyOrKeyword;
    else
      if IsBareKeyChar(LChar) then
        ScanBareKeyOrKeyword
      else
        Advance;  // Skip unknown character
    end;
  end;

  // Add EOF token
  FTokens.Add(TTomlToken.Create(tkEof, '', CreatePosition));
end;

{$ENDREGION}

{$REGION 'AST Implementation'}

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
  LSegment: string;
  LNeedsQuoting: Boolean;
  j: Integer;
begin
  Result := '';
  for i := 0 to FSegments.Count - 1 do
  begin
    if i > 0 then
      Result := Result + '.';

    LSegment := FSegments[i];

    // Check if segment needs quoting (contains dot, space, or other special chars)
    LNeedsQuoting := False;
    for j := 1 to Length(LSegment) do
    begin
      if CharInSet(LSegment[j], ['.', ' ', #9, '"', '''', '[', ']', '{', '}', '=', '#']) then
      begin
        LNeedsQuoting := True;
        Break;
      end;
    end;

    // Quote segment if needed to distinguish a."b.c" from a.b.c
    if LNeedsQuoting then
      Result := Result + '"' + StringReplace(LSegment, '"', '\"', [rfReplaceAll]) + '"'
    else
      Result := Result + LSegment;
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

{$ENDREGION}

{$REGION 'Parser Implementation'}

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
  // Note: FDocument is not freed here because ownership is transferred to caller
  inherited;
end;

function TTomlParser.GetCurrentToken: TTomlToken;
begin
  if IsEof then
    Result := FTokens[FTokens.Count - 1]  // Return EOF token
  else
    Result := FTokens[FPosition];
end;

function TTomlParser.IsEof: Boolean;
begin
  Result := (FPosition >= FTokens.Count) or
            ((FPosition < FTokens.Count) and (FTokens[FPosition].Kind = tkEof));
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
var
  LPos: TTomlPosition;
begin
  if not IsEof and (FPosition < FTokens.Count) then
    LPos := FTokens[FPosition].Position
  else if FTokens.Count > 0 then
    LPos := FTokens[FTokens.Count - 1].Position
  else
    LPos := TTomlPosition.Create(1, 1, 0);

  raise ETomlParserException.Create(AMessage, LPos);
end;

class function TTomlParser.SkipCRLF(var AIndex: Integer; const AText: string): Boolean;
begin
  Result := False;

  // Check if we're at a CR followed by LF (CRLF)
  if (AIndex <= Length(AText)) and (AText[AIndex] = CH_CR) then
  begin
    if (AIndex + 1 <= Length(AText)) and (AText[AIndex + 1] = CH_LF) then
    begin
      Inc(AIndex); // Skip the LF after CR
      Result := True;
    end;
  end
  // Check if we're at a standalone LF
  else if (AIndex <= Length(AText)) and (AText[AIndex] = CH_LF) then
  begin
    Result := True;
  end;
end;

function TTomlParser.ProcessEscapeSequence(const AText: string; var AIndex: Integer; AIsMultiline: Boolean): string;
var
  LHex: string;
  LCodePoint: Integer;
  LHigh, LLow: Integer;
  j: Integer;
begin
  Result := '';

  // AIndex points to the character after the backslash
  if AIndex > Length(AText) then
    Exit;

  case AText[AIndex] of
    'n': Result := CH_LF;
    'r': Result := CH_CR;
    't': Result := CH_TAB;
    'b': Result := CH_BACKSPACE;
    'f': Result := CH_FF;
    '\': Result := '\';
    '"': Result := '"';
    '''': Result := '''';

    'u':
      begin
        // \uXXXX - 4 hex digits for Unicode code point
        if AIndex + 4 <= Length(AText) then
        begin
          LHex := Copy(AText, AIndex + 1, 4);
          if TryStrToInt('$' + LHex, LCodePoint) then
          begin
            Result := Char(LCodePoint);
            Inc(AIndex, 4);  // Skip the 4 hex digits
          end
          else
            raise ETomlParserException.Create(
              Format('Invalid Unicode escape sequence: \u%s', [LHex]),
              TTomlPosition.Create(1, 1, 0));
        end
        else
          raise ETomlParserException.Create(
            'Incomplete Unicode escape sequence: \u requires 4 hex digits',
            TTomlPosition.Create(1, 1, 0));
      end;

    'U':
      begin
        // \UXXXXXXXX - 8 hex digits for Unicode code point
        if AIndex + 8 <= Length(AText) then
        begin
          LHex := Copy(AText, AIndex + 1, 8);
          if TryStrToInt('$' + LHex, LCodePoint) then
          begin
            // Convert code point to UTF-16 surrogate pair if needed
            if LCodePoint <= MAX_BMP_CODEPOINT then
              Result := Char(LCodePoint)
            else if LCodePoint <= MAX_UNICODE_CODEPOINT then
            begin
              // Convert to UTF-16 surrogate pair
              LCodePoint := LCodePoint - SURROGATE_OFFSET;
              LHigh := HIGH_SURROGATE_BASE + (LCodePoint shr 10);
              LLow := LOW_SURROGATE_BASE + (LCodePoint and $3FF);
              Result := Char(LHigh) + Char(LLow);
            end
            else
              raise ETomlParserException.Create(
                Format('Invalid Unicode code point: \U%s', [LHex]),
                TTomlPosition.Create(1, 1, 0));
            Inc(AIndex, 8);  // Skip the 8 hex digits
          end
          else
            raise ETomlParserException.Create(
              Format('Invalid Unicode escape sequence: \U%s', [LHex]),
              TTomlPosition.Create(1, 1, 0));
        end
        else
          raise ETomlParserException.Create(
            'Incomplete Unicode escape sequence: \U requires 8 hex digits',
            TTomlPosition.Create(1, 1, 0));
      end;

    ' ', #9:
      begin
        // Whitespace after backslash - check if line-ending backslash
        if AIsMultiline then
        begin
          // Skip trailing whitespace on the current line
          j := AIndex;
          while (j <= Length(AText)) and CharInSet(AText[j], [' ', #9]) do
            Inc(j);

          // Check if followed by newline
          if (j <= Length(AText)) and CharInSet(AText[j], [#10, #13]) then
          begin
            // Line-ending backslash - skip whitespace and newline
            AIndex := j;  // Move to newline character

            // Skip CRLF or LF
            SkipCRLF(AIndex, AText);

            // Skip any whitespace at the beginning of the next line
            while (AIndex + 1 <= Length(AText)) and CharInSet(AText[AIndex + 1], [' ', #9, #10, #13]) do
              Inc(AIndex);
          end
          else
            // Not a line-ending backslash
            raise ETomlParserException.Create(
              Format('Invalid escape sequence: \%s', [AText[AIndex]]),
              TTomlPosition.Create(1, 1, 0));
        end
        else
          raise ETomlParserException.Create(
            Format('Invalid escape sequence: \%s', [AText[AIndex]]),
            TTomlPosition.Create(1, 1, 0));
      end;

    #10, #13:
      begin
        // Line-ending backslash in multiline strings (no trailing whitespace)
        // Skip the newline and any following whitespace
        if AIsMultiline then
        begin
          // Skip CRLF or LF
          SkipCRLF(AIndex, AText);

          // Skip any whitespace at the beginning of the next line
          while (AIndex + 1 <= Length(AText)) and CharInSet(AText[AIndex + 1], [' ', #9, #10, #13]) do
            Inc(AIndex);
        end
        else
          raise ETomlParserException.Create(
            'Line-ending backslash only allowed in multiline strings',
            TTomlPosition.Create(1, 1, 0));
      end;
  else
    raise ETomlParserException.Create(
      Format('Invalid escape sequence: \%s', [AText[AIndex]]),
      TTomlPosition.Create(1, 1, 0));
  end;
end;

function TTomlParser.ParseString(const AText: string): string;
var
  i: Integer;
  LInString: Boolean;
  LChar: Char;
  LIsLiteral: Boolean;  // True for single-quoted strings (literal)
  LDelimiter: Char;
  LIsMultiline: Boolean;  // True for triple-quoted strings
begin
  Result := '';
  LInString := False;
  LIsLiteral := False;
  LIsMultiline := False;

  i := 1;
  while i <= Length(AText) do
  begin
    LChar := AText[i];

    if not LInString then
    begin
      if CharInSet(LChar, ['"', '''']) then
      begin
        LInString := True;
        LDelimiter := LChar;
        LIsLiteral := (LChar = '''');  // Single quote = literal string

        // Check if it's a multiline string (triple quotes)
        if (i + 2 <= Length(AText)) and
           (AText[i + 1] = LDelimiter) and
           (AText[i + 2] = LDelimiter) then
        begin
          LIsMultiline := True;
          Inc(i, 2);  // Skip the extra two quotes

          // Skip the first newline immediately after opening triple quotes
          // Could be LF (\n) or CRLF (\r\n)
          if (i + 1 <= Length(AText)) then
          begin
            var j := i + 1;
            if SkipCRLF(j, AText) then
              i := j;
          end;
        end;
      end;
      Inc(i);
      Continue;
    end;

    // In literal strings (single quotes), backslashes are not escape characters
    if (LChar = '\') and (not LIsLiteral) then
    begin
      // Handle escape sequences
      Inc(i);
      Result := Result + ProcessEscapeSequence(AText, i, LIsMultiline);
    end
    else if (LChar = LDelimiter) then
    begin
      // Check if this is the closing delimiter
      if LIsMultiline then
      begin
        // For multiline strings, need 3 consecutive delimiters
        // But if there are 4+, the extras are content
        var LQuoteCount := 0;
        var j := i;
        while (j <= Length(AText)) and (AText[j] = LDelimiter) do
        begin
          Inc(LQuoteCount);
          Inc(j);
        end;

        if LQuoteCount >= 3 then
        begin
          // Found closing delimiter (possibly with extra quotes as content)
          // Add any extra quotes (beyond the closing 3) to result
          for var k := 1 to LQuoteCount - 3 do
            Result := Result + LDelimiter;

          // Stop - the last 3 quotes are the closing delimiter
          LInString := False;
          Inc(i, LQuoteCount - 1);  // Skip all quotes (will be incremented by 1 more at end of loop)
        end
        else
        begin
          // Less than 3 consecutive quotes - include them as content
          for var k := 1 to LQuoteCount do
            Result := Result + LDelimiter;
          Inc(i, LQuoteCount - 1);  // Skip processed quotes (will be incremented by 1 more)
        end;
      end
      else
      begin
        // Single-line string - one delimiter closes it
        LInString := False;
      end;
    end
    else
    begin
      // Validate control characters
      // Control characters (U+0000-U+001F except tab, and U+007F) are not allowed
      // TAB (0x09) is allowed in all strings (literal and basic, single and multiline)
      var LOrd := Ord(LChar);
      if (LOrd <= 31) or (LOrd = 127) then
      begin
        // TAB is always allowed
        if LChar = CH_TAB then
        begin
          // Allowed everywhere
        end
        // In multiline strings, allow LF and CRLF
        else if LIsMultiline then
        begin
          if LChar = CH_LF then
          begin
            // Allowed in multiline strings
          end
          else if LChar = CH_CR then
          begin
            // CR only allowed as part of CRLF
            var j := i;
            if SkipCRLF(j, AText) then
            begin
              // Skip the CR, the LF will be added in the next iteration
              i := j;
              Continue;
            end
            else
            begin
              // Standalone CR is not allowed
              raise ETomlParserException.Create(
                Format('Control character 0x%2.2X is not allowed in strings', [LOrd]),
                TTomlPosition.Create(1, 1, 0));
            end;
          end
          else
          begin
            // Other control characters not allowed in multiline strings
            raise ETomlParserException.Create(
              Format('Control character 0x%2.2X is not allowed in strings', [LOrd]),
              TTomlPosition.Create(1, 1, 0));
          end;
        end
        else
        begin
          // In single-line strings, only TAB is allowed (already handled above)
          // All other control characters are forbidden
          raise ETomlParserException.Create(
            Format('Control character 0x%2.2X is not allowed in strings', [LOrd]),
            TTomlPosition.Create(1, 1, 0));
        end;
      end;

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
    else if LToken.Kind in [tkInteger, tkFloat, tkBoolean] then
    begin
      // TOML allows numeric and special word keys (numbers, inf, nan, true, false)
      LKey.AddSegment(LToken.Text);
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

      // TOML spec: "Inline tables do not allow trailing commas"
      if Match(tkRightBrace) then
        Error('Trailing comma not allowed in inline table');
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

{$ENDREGION}

{$REGION 'DOM Implementation'}

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

constructor TTomlValue.CreateDateTime(AValue: TDateTime; const ARawText: string = '');
begin
  inherited Create;
  FKind := tvkDateTime;
  FValue := AValue;
  FRawText := ARawText;  // Preserve original RFC 3339 format
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
  LTable: TToml;
begin
  try
    LDocument := InternalParse(ASource);
    try
      // Build DOM to trigger validation checks (duplicate keys, mixed arrays, etc.)
      LTable := TTomlDomBuilder.BuildFromDocument(LDocument);
      try
        Result := True;
        AErrorMessage := '';
      finally
        LTable.Free;
      end;
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
  LDigits: string;
  i: Integer;
  LDigit: Integer;
begin
  // Remove underscores
  LClean := AText.Replace('_', '', [rfReplaceAll]);

  // Handle special bases
  if LClean.StartsWith('0x') then
  begin
    // Hexadecimal - use $ prefix for Delphi
    Result := StrToInt64('$' + LClean.Substring(2));
  end
  else if LClean.StartsWith('0o') then
  begin
    // Octal - manual conversion
    LDigits := LClean.Substring(2);
    Result := 0;
    for i := 1 to Length(LDigits) do
    begin
      LDigit := Ord(LDigits[i]) - Ord('0');
      if (LDigit < 0) or (LDigit > 7) then
        raise ETomlParserException.Create(
          Format('Invalid octal digit: %s', [LDigits[i]]),
          TTomlPosition.Create(1, 1, 0));
      Result := Result * 8 + LDigit;
    end;
  end
  else if LClean.StartsWith('0b') then
  begin
    // Binary - manual conversion
    LDigits := LClean.Substring(2);
    Result := 0;
    for i := 1 to Length(LDigits) do
    begin
      LDigit := Ord(LDigits[i]) - Ord('0');
      if (LDigit < 0) or (LDigit > 1) then
        raise ETomlParserException.Create(
          Format('Invalid binary digit: %s', [LDigits[i]]),
          TTomlPosition.Create(1, 1, 0));
      Result := Result * 2 + LDigit;
    end;
  end
  else
    Result := StrToInt64(LClean);
end;

class function TTomlDomBuilder.ParseFloat(const AText: string): Double;
var
  LClean: string;
  LFormatSettings: TFormatSettings;
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
  begin
    // Use invariant culture settings (dot as decimal separator)
    LFormatSettings := TFormatSettings.Create('en-US');
    LFormatSettings.DecimalSeparator := '.';
    Result := StrToFloat(LClean, LFormatSettings);
  end;
end;

class function TTomlDomBuilder.ParseDateTime(const AText: string): TDateTime;
var
  LDatePart, LTimePart: string;
  LYear, LMonth, LDay: Word;
  LHour, LMin, LSec: Word;
  LPos, LTPos, LDotPos: Integer;
  LDate, LTime: TDateTime;
begin
  // RFC 3339 DateTime formats:
  // - Offset DateTime: 1979-05-27T07:32:00-08:00 or 1979-05-27T07:32:00Z
  // - Local DateTime: 1979-05-27T07:32:00
  // - Local Date: 1979-05-27
  // - Local Time: 07:32:00

  // Check if it's a time-only value (no date part)
  if (Pos('-', AText) = 0) and (Pos('T', AText) = 0) then
  begin
    // Local time: 07:32:00 or 07:32:00.999999
    LTimePart := AText;
    LDotPos := Pos('.', LTimePart);
    if LDotPos > 0 then
      LTimePart := Copy(LTimePart, 1, LDotPos - 1);

    LHour := StrToInt(Copy(LTimePart, 1, 2));
    LMin := StrToInt(Copy(LTimePart, 4, 2));
    LSec := StrToInt(Copy(LTimePart, 7, 2));

    // Validate time values
    if (LHour > 23) or (LMin > 59) or (LSec > 59) then
      raise ETomlParserException.Create(
        'Invalid time value',
        TTomlPosition.Create(1, 1, 0));

    Result := EncodeTime(LHour, LMin, LSec, 0);
    Exit;
  end;

  // Find T separator (if exists)
  LTPos := Pos('T', UpperCase(AText));

  if LTPos = 0 then
  begin
    // Local date only: 1979-05-27
    LDatePart := AText;
    LYear := StrToInt(Copy(LDatePart, 1, 4));
    LMonth := StrToInt(Copy(LDatePart, 6, 2));
    LDay := StrToInt(Copy(LDatePart, 9, 2));

    // Validate date values
    if (LMonth < 1) or (LMonth > 12) or (LDay < 1) or (LDay > 31) then
      raise ETomlParserException.Create(
        'Invalid date value',
        TTomlPosition.Create(1, 1, 0));

    Result := EncodeDate(LYear, LMonth, LDay);
    Exit;
  end;

  // Has both date and time
  LDatePart := Copy(AText, 1, LTPos - 1);
  LTimePart := Copy(AText, LTPos + 1, Length(AText));

  // Parse date part
  LYear := StrToInt(Copy(LDatePart, 1, 4));
  LMonth := StrToInt(Copy(LDatePart, 6, 2));
  LDay := StrToInt(Copy(LDatePart, 9, 2));

  // Validate date values
  if (LMonth < 1) or (LMonth > 12) or (LDay < 1) or (LDay > 31) then
    raise ETomlParserException.Create(
      'Invalid date value',
      TTomlPosition.Create(1, 1, 0));

  LDate := EncodeDate(LYear, LMonth, LDay);

  // Check for timezone offset
  LPos := Pos('Z', UpperCase(LTimePart));
  if LPos = 0 then
    LPos := Pos('+', LTimePart);
  if LPos = 0 then
    LPos := Pos('-', LTimePart);

  if LPos > 0 then
  begin
    // Strip timezone offset (Z, +HH:MM, or -HH:MM)
    LTimePart := Copy(LTimePart, 1, LPos - 1);
    // Note: For simplicity, we store as local time without applying offset
    // Full implementation would convert to UTC or local timezone
  end;

  // Parse time part (handle fractional seconds)
  LDotPos := Pos('.', LTimePart);
  if LDotPos > 0 then
    LTimePart := Copy(LTimePart, 1, LDotPos - 1);

  LHour := StrToInt(Copy(LTimePart, 1, 2));
  LMin := StrToInt(Copy(LTimePart, 4, 2));
  LSec := StrToInt(Copy(LTimePart, 7, 2));
  LTime := EncodeTime(LHour, LMin, LSec, 0);

  Result := LDate + LTime;
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
        Result := TTomlValue.CreateDateTime(
          ParseDateTime(LValueNode.Value),
          LValueNode.Value  // Preserve original RFC 3339 format
        )
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
  LValue: TTomlValue;
begin
  LArray := TTomlArray.Create;

  // TOML 1.0 allows heterogeneous arrays
  // Arrays can contain mixed types
  for LElement in ANode.Elements do
  begin
    LValue := ConvertValue(LElement);
    LArray.Add(LValue);
  end;

  Result := LArray;
end;

class function TTomlDomBuilder.ConvertInlineTable(ANode: TTomlInlineTableSyntax): TToml;
var
  LTable: TToml;
  LKeyValue: TTomlSyntaxNode;
  LUsedPaths: TStringList;
  LPath: string;
  i: Integer;
begin
  LTable := TToml.Create;
  LTable.IsInline := True;  // Mark as inline table for immutability
  LUsedPaths := TStringList.Create;
  try
    LUsedPaths.Sorted := True;
    LUsedPaths.Duplicates := dupError;

    for LKeyValue in ANode.KeyValues do
    begin
      if LKeyValue is TTomlKeyValueSyntax then
      begin
        var LKV := TTomlKeyValueSyntax(LKeyValue);

        // Build all intermediate paths for this key-value
        // For "a.b.c = value", we need to check paths: "a", "a.b", "a.b.c"
        LPath := '';
        for i := 0 to LKV.Key.Segments.Count - 1 do
        begin
          if i > 0 then
            LPath := LPath + '.';
          LPath := LPath + LKV.Key.Segments[i];

          // Check if this path was already used
          if LUsedPaths.IndexOf(LPath) >= 0 then
            raise ETomlParserException.Create(
              Format('Duplicate key "%s" in inline table', [LPath]),
              TTomlPosition.Create(1, 1, 0));
        end;

        // Record this path as used
        LUsedPaths.Add(LPath);

        ApplyKeyValue(LTable, LKV);
      end;
    end;

    Result := LTable;
  finally
    LUsedPaths.Free;
  end;
end;

class procedure TTomlDomBuilder.ApplyKeyValue(
  ATable: TToml;
  AKeyValue: TTomlKeyValueSyntax;
  const AContextPath: string = '';
  AExplicitTables: TList<string> = nil;
  AImplicitTables: TList<string> = nil);
var
  LKey: string;
  LValue: TTomlValue;
  LCurrentTable: TToml;
  LFullPath: string;
  i: Integer;
begin
  LCurrentTable := ATable;
  LFullPath := AContextPath;  // Start with context path

  // Navigate to the correct table using dotted key
  for i := 0 to AKeyValue.Key.Segments.Count - 2 do
  begin
    LKey := AKeyValue.Key.Segments[i];

    // Build full path for this segment
    if LFullPath <> '' then
      LFullPath := LFullPath + '.' + LKey
    else
      LFullPath := LKey;

    // Check if this path was explicitly defined as a table header
    if (AExplicitTables <> nil) and AExplicitTables.Contains(LFullPath) then
      raise ETomlParserException.Create(
        Format('Cannot extend table [%s] using dotted keys after it was explicitly defined', [LFullPath]),
        TTomlPosition.Create(1, 1, 0));

    // Check if trying to extend an inline table
    if LCurrentTable.ContainsKey(LKey) then
    begin
      if LCurrentTable[LKey].Kind = tvkTable then
      begin
        var LSubTable := LCurrentTable[LKey].AsTable;
        if LSubTable.IsInline then
          raise ETomlParserException.Create(
            Format('Cannot extend inline table "%s"', [LKey]),
            TTomlPosition.Create(1, 1, 0));
        LCurrentTable := LSubTable;
      end
      else
        raise ETomlParserException.Create(
          Format('Key "%s" is already defined as non-table value', [LKey]),
          TTomlPosition.Create(1, 1, 0));
    end
    else
    begin
      // Create the table and track it as implicitly defined
      LCurrentTable := LCurrentTable.GetOrCreateTable(LKey);
      if (AImplicitTables <> nil) and (AImplicitTables.IndexOf(LFullPath) < 0) then
        AImplicitTables.Add(LFullPath);
    end;
  end;

  // Set the final value
  LKey := AKeyValue.Key.Segments[AKeyValue.Key.Segments.Count - 1];

  // Check for duplicate key
  if LCurrentTable.ContainsKey(LKey) then
    raise ETomlParserException.Create(
      Format('Duplicate key "%s"', [LKey]),
      TTomlPosition.Create(1, 1, 0));

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
  LFullTableName: string;
  i: Integer;
  LDefinedTables: TList<string>;       // Explicitly defined tables via [table]
  LImplicitTables: TList<string>;      // Implicitly defined tables via dotted keys
  LLastArrayTable: TToml;              // Track last table added to an array of tables
  LLastArrayPath: string;              // Track the path of the last array
begin
  LTable := TToml.Create;
  LDefinedTables := TList<string>.Create;
  LImplicitTables := TList<string>.Create;
  LLastArrayTable := nil;
  LLastArrayPath := '';
  try
    // Process top-level key-values
    for LKeyValue in ADocument.KeyValues do
    begin
      if LKeyValue is TTomlKeyValueSyntax then
        ApplyKeyValue(LTable, TTomlKeyValueSyntax(LKeyValue), '', LDefinedTables, LImplicitTables);
    end;

    // Process tables
    for LTableNode in ADocument.Tables do
    begin
      if LTableNode is TTomlTableSyntax then
      begin
        LTableSyntax := TTomlTableSyntax(LTableNode);
        LFullTableName := LTableSyntax.Key.GetFullKey;

        if LTableSyntax.IsArrayOfTables then
        begin
          // [[array]] - Array of Tables
          // Create a new table and add it to an array
          LCurrentTable := LTable;

          // Navigate to parent tables, creating them if needed
          // Special case: if a parent is an array (from prior [[parent]]),
          // navigate to the last element of that array
          for i := 0 to LTableSyntax.Key.Segments.Count - 2 do
          begin
            LKey := LTableSyntax.Key.Segments[i];

            // Check if this key is an array (from a previous [[key]])
            var LValue: TTomlValue;
            if LCurrentTable.TryGetValue(LKey, LValue) and (LValue.Kind = tvkArray) then
            begin
              // Navigate to the last table in the array
              var LArray := LValue.AsArray;
              if (LArray.Count = 0) or (LArray[LArray.Count - 1].Kind <> tvkTable) then
                raise ETomlParserException.Create(
                  Format('Cannot navigate through array "%s" - last element is not a table', [LKey]),
                  TTomlPosition.Create(1, 1, 0));
              LCurrentTable := LArray[LArray.Count - 1].AsTable;
            end
            else if LCurrentTable.ContainsKey(LKey) then
            begin
              // Check if trying to extend an inline table
              if LCurrentTable[LKey].Kind = tvkTable then
              begin
                var LSubTable := LCurrentTable[LKey].AsTable;
                if LSubTable.IsInline then
                  raise ETomlParserException.Create(
                    Format('Cannot extend inline table "%s"', [LKey]),
                    TTomlPosition.Create(1, 1, 0));
                LCurrentTable := LSubTable;
              end
              else
                raise ETomlParserException.Create(
                  Format('Key "%s" is already defined as non-table value', [LKey]),
                  TTomlPosition.Create(1, 1, 0));
            end
            else
            begin
              // Regular table navigation
              LCurrentTable := LCurrentTable.GetOrCreateTable(LKey);
            end;
          end;

          // Get or create the array for the final segment
          LKey := LTableSyntax.Key.Segments[LTableSyntax.Key.Segments.Count - 1];

          // Check if key exists and validate it's compatible with array-of-tables
          if LCurrentTable.ContainsKey(LKey) then
          begin
            var LExisting: TTomlValue;
            if LCurrentTable.TryGetValue(LKey, LExisting) then
            begin
              if LExisting.Kind <> tvkArray then
                raise ETomlParserException.Create(
                  Format('Cannot define [[%s]] - key "%s" is already defined as non-array', [LFullTableName, LKey]),
                  TTomlPosition.Create(1, 1, 0));

              // If it IS an array, check if it's compatible with array-of-tables
              // Arrays created via direct assignment (fruit = [] or fruit = [1,2,3])
              // cannot be used with [[array]] syntax
              var LExistingArray := LExisting.AsArray;
              if LExistingArray.Count = 0 then
                // Empty array was created via direct assignment (fruit = [])
                raise ETomlParserException.Create(
                  Format('Cannot convert array "%s" to array-of-tables - it was defined via direct assignment', [LKey]),
                  TTomlPosition.Create(1, 1, 0))
              else if LExistingArray[0].Kind <> tvkTable then
                // Array contains non-table values
                raise ETomlParserException.Create(
                  Format('Cannot convert array "%s" to array-of-tables - it contains non-table values', [LKey]),
                  TTomlPosition.Create(1, 1, 0));
            end;
          end;

          var LArray: TTomlArray := LCurrentTable.GetOrCreateArray(LKey);

          // Create a new table for this array element
          var LNewTable: TToml := TToml.Create;
          LArray.Add(TTomlValue.CreateTable(LNewTable));

          // Track this as the last array table for subsequent [array.subtable] references
          LLastArrayTable := LNewTable;
          LLastArrayPath := LFullTableName;

          // Add key-values to the new table
          for LKeyValue in LTableSyntax.KeyValues do
          begin
            if LKeyValue is TTomlKeyValueSyntax then
              ApplyKeyValue(LNewTable, TTomlKeyValueSyntax(LKeyValue), LFullTableName, LDefinedTables, LImplicitTables);
          end;
        end
        else
        begin
          // [table] - Regular Table
          // Check if this is a subtable of the last array element
          // e.g., [[arr]] followed by [arr.subtab]
          if (LLastArrayPath <> '') and LFullTableName.StartsWith(LLastArrayPath + '.') then
          begin
            // This is a subtable of the last array element
            // Navigate from the last array table
            LCurrentTable := LLastArrayTable;
            var LSubPath := LFullTableName.Substring(LLastArrayPath.Length + 1);
            var LSubSegments := LSubPath.Split(['.']);

            for var LSegment in LSubSegments do
            begin
              // Check if trying to redefine an inline table
              if LCurrentTable.ContainsKey(LSegment) then
              begin
                if LCurrentTable[LSegment].Kind = tvkTable then
                begin
                  var LSubTable := LCurrentTable[LSegment].AsTable;
                  if LSubTable.IsInline then
                    raise ETomlParserException.Create(
                      Format('Cannot redefine inline table [%s]', [LFullTableName]),
                      TTomlPosition.Create(1, 1, 0));
                  LCurrentTable := LSubTable;
                end
                else
                  raise ETomlParserException.Create(
                    Format('Key "%s" is already defined as non-table value', [LSegment]),
                    TTomlPosition.Create(1, 1, 0));
              end
              else
                LCurrentTable := LCurrentTable.GetOrCreateTable(LSegment);
            end;
          end
          else
          begin
            // Regular table definition
            // Check if table was already explicitly defined
            if LDefinedTables.Contains(LFullTableName) then
              raise ETomlParserException.Create(
                Format('Table [%s] is already defined', [LFullTableName]),
                TTomlPosition.Create(1, 1, 0));

            // Check if table was implicitly defined via dotted keys
            if LImplicitTables.Contains(LFullTableName) then
              raise ETomlParserException.Create(
                Format('Cannot define table [%s] explicitly - it was already implicitly defined via dotted keys', [LFullTableName]),
                TTomlPosition.Create(1, 1, 0));

            LDefinedTables.Add(LFullTableName);
            LCurrentTable := LTable;

            // Navigate to the correct nested table
            for i := 0 to LTableSyntax.Key.Segments.Count - 1 do
            begin
              LKey := LTableSyntax.Key.Segments[i];

              // Check if trying to redefine an inline table
              if LCurrentTable.ContainsKey(LKey) then
              begin
                if LCurrentTable[LKey].Kind = tvkTable then
                begin
                  var LSubTable := LCurrentTable[LKey].AsTable;
                  if LSubTable.IsInline then
                    raise ETomlParserException.Create(
                      Format('Cannot redefine inline table [%s]', [LFullTableName]),
                      TTomlPosition.Create(1, 1, 0));
                  LCurrentTable := LSubTable;
                end
                else
                  raise ETomlParserException.Create(
                    Format('Key "%s" is already defined as non-table value', [LKey]),
                    TTomlPosition.Create(1, 1, 0));
              end
              else
                LCurrentTable := LCurrentTable.GetOrCreateTable(LKey);
            end;

            // Clear last array tracking since we're in a different context
            LLastArrayTable := nil;
            LLastArrayPath := '';
          end;

          // Add key-values to this table
          for LKeyValue in LTableSyntax.KeyValues do
          begin
            if LKeyValue is TTomlKeyValueSyntax then
              ApplyKeyValue(LCurrentTable, TTomlKeyValueSyntax(LKeyValue), LFullTableName, LDefinedTables, LImplicitTables);
          end;
        end;
      end;
    end;

    Result := LTable;
  finally
    LDefinedTables.Free;
    LImplicitTables.Free;
  end;
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
      CH_BACKSPACE: Result := Result + '\b';
      CH_TAB: Result := Result + '\t';
      CH_LF: Result := Result + '\n';
      CH_FF: Result := Result + '\f';
      CH_CR: Result := Result + '\r';
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

{$ENDREGION}

end.
