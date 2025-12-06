{*******************************************************************************
  DX.TOML.Lexer - TOML Tokenizer

  Description:
    Tokenizes TOML input into a stream of tokens with position tracking.
    Handles all TOML token types including strings, numbers, dates, booleans,
    and structural elements. Preserves whitespace and comments for round-trip.

  Author: DX.TOML Project
  License: MIT
*******************************************************************************}
unit DX.TOML.Lexer;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Character;

type
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

    procedure ScanWhitespace;
    procedure ScanComment;
    procedure ScanNewLine;
    procedure ScanString(ADelimiter: Char);
    procedure ScanMultiLineString(ADelimiter: Char);
    procedure ScanNumber;
    procedure ScanBareKeyOrKeyword;

    function IsWhitespace(AChar: Char): Boolean;
    function IsBareKeyChar(AChar: Char): Boolean;
    function IsDigit(AChar: Char): Boolean;
    function IsHexDigit(AChar: Char): Boolean;
  public
    constructor Create(const ASource: string);
    destructor Destroy; override;

    /// <summary>Tokenize the entire source</summary>
    procedure Tokenize;

    /// <summary>Get all tokens</summary>
    property Tokens: TObjectList<TTomlToken> read FTokens;
  end;

implementation

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

function TTomlLexer.IsHexDigit(AChar: Char): Boolean;
begin
  Result := AChar.IsDigit or (AChar in ['a'..'f', 'A'..'F']);
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
  while not IsEof and not (GetCurrentChar in [#10, #13]) do
  begin
    LText := LText + GetCurrentChar;
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
  if GetCurrentChar = #13 then
  begin
    LText := LText + GetCurrentChar;
    Advance;
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
begin
  LStart := CreatePosition;
  LText := '';

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
    else if GetCurrentChar = '\' then
    begin
      LText := LText + GetCurrentChar;
      Advance;
      LEscaped := True;
    end
    else if GetCurrentChar = ADelimiter then
    begin
      LText := LText + GetCurrentChar;
      Advance;
      Break;
    end
    else
    begin
      LText := LText + GetCurrentChar;
      Advance;
    end;
  end;

  FTokens.Add(TTomlToken.Create(tkString, LText, LStart));
end;

procedure TTomlLexer.ScanMultiLineString(ADelimiter: Char);
var
  LStart: TTomlPosition;
  LText: string;
  LQuoteCount: Integer;
begin
  LStart := CreatePosition;
  LText := '';

  // Skip opening triple delimiter
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
      // Count consecutive quotes
      LQuoteCount := 0;
      while (not IsEof) and (GetCurrentChar = ADelimiter) and (LQuoteCount < 3) do
      begin
        LText := LText + GetCurrentChar;
        Advance;
        Inc(LQuoteCount);
      end;

      if LQuoteCount = 3 then
        Break;
    end
    else
    begin
      if GetCurrentChar = #10 then
      begin
        Inc(FLine);
        FColumn := 0;  // Will be incremented by Advance
      end;
      LText := LText + GetCurrentChar;
      Advance;
    end;
  end;

  FTokens.Add(TTomlToken.Create(tkMultiLineString, LText, LStart));
end;

procedure TTomlLexer.ScanNumber;
var
  LStart: TTomlPosition;
  LText: string;
  LKind: TTomlTokenKind;
begin
  LStart := CreatePosition;
  LText := '';
  LKind := tkInteger;

  // Handle sign
  if GetCurrentChar in ['+', '-'] then
  begin
    LText := LText + GetCurrentChar;
    Advance;
  end;

  // Handle special prefixes (0x, 0o, 0b)
  if (GetCurrentChar = '0') and (GetLookahead(1) in ['x', 'o', 'b']) then
  begin
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
    if GetCurrentChar = '.' then
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

    // Check for exponent
    if GetCurrentChar in ['e', 'E'] then
    begin
      LKind := tkFloat;
      LText := LText + GetCurrentChar;
      Advance;

      if GetCurrentChar in ['+', '-'] then
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
  end;

  FTokens.Add(TTomlToken.Create(LKind, LText, LStart));
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
    LText := LText + GetCurrentChar;
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
        ScanNumber;
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

end.
