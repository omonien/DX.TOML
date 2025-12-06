{*******************************************************************************
  DX.TOML.Tests.Main - Main Test Suite

  Description:
    DUnitX test suite for DX.TOML library.
    Tests lexer, parser, AST, DOM and API functionality.

  Author: DX.TOML Project
  License: MIT
*******************************************************************************}
unit DX.TOML.Tests.Main;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.DateUtils,
  DX.TOML;

type
  [TestFixture]
  TTomlLexerTests = class
  public
    [Test]
    procedure TestSimpleTokens;

    [Test]
    procedure TestStrings;

    [Test]
    procedure TestNumbers;

    [Test]
    procedure TestComments;
  end;

  [TestFixture]
  TTomlParserTests = class
  public
    [Test]
    procedure TestSimpleKeyValue;

    [Test]
    procedure TestTable;

    [Test]
    procedure TestNestedTables;

    [Test]
    procedure TestArray;

    [Test]
    procedure TestInlineTable;
  end;

  [TestFixture]
  TTomlApiTests = class
  public
    [Test]
    procedure TestToModel;

    [Test]
    procedure TestFromModel;

    [Test]
    procedure TestRoundTrip;

    [Test]
    procedure TestValidate;
  end;

  [TestFixture]
  TTomlGoldenFileTests = class
  private
    function GetGoldenFilesPath: string;
  public
    [Test]
    procedure TestExample01;
  end;

  [TestFixture]
  TTomlDateTimeTests = class
  public
    [Test]
    procedure TestOffsetDateTime;

    [Test]
    procedure TestLocalDateTime;

    [Test]
    procedure TestLocalDate;

    [Test]
    procedure TestLocalTime;
  end;

  [TestFixture]
  TTomlNegativeTests = class
  public
    [Test]
    procedure TestInvalidKeyValue;

    [Test]
    procedure TestDuplicateKeys;

    [Test]
    procedure TestInvalidEscapeSequence;

    [Test]
    procedure TestMalformedTable;

    [Test]
    procedure TestInvalidArrayMixedTypes;

    [Test]
    procedure TestInvalidDateTime;

    [Test]
    procedure TestUnclosedString;

    [Test]
    procedure TestInvalidNumber;

    [Test]
    procedure TestRedefineTable;

    [Test]
    procedure TestInvalidInlineTable;
  end;

implementation

{ TTomlLexerTests }

procedure TTomlLexerTests.TestSimpleTokens;
var
  LLexer: TTomlLexer;
begin
  LLexer := TTomlLexer.Create('key = "value"');
  try
    LLexer.Tokenize;

    Assert.IsTrue(LLexer.Tokens.Count > 0, 'Should have tokens');
    Assert.AreEqual(Ord(tkBareKey), Ord(LLexer.Tokens[0].Kind), 'First token should be bare key');
  finally
    LLexer.Free;
  end;
end;

procedure TTomlLexerTests.TestStrings;
var
  LLexer: TTomlLexer;
begin
  LLexer := TTomlLexer.Create('name = "John Doe"');
  try
    LLexer.Tokenize;

    Assert.IsTrue(LLexer.Tokens.Count >= 3, 'Should have at least 3 tokens');
  finally
    LLexer.Free;
  end;
end;

procedure TTomlLexerTests.TestNumbers;
var
  LLexer: TTomlLexer;
begin
  LLexer := TTomlLexer.Create('age = 42');
  try
    LLexer.Tokenize;

    Assert.IsTrue(LLexer.Tokens.Count > 0, 'Should have tokens');
  finally
    LLexer.Free;
  end;
end;

procedure TTomlLexerTests.TestComments;
var
  LLexer: TTomlLexer;
begin
  LLexer := TTomlLexer.Create('# This is a comment');
  try
    LLexer.Tokenize;

    Assert.IsTrue(LLexer.Tokens.Count > 0, 'Should have tokens');
    Assert.AreEqual(Ord(tkComment), Ord(LLexer.Tokens[0].Kind), 'Should be a comment token');
  finally
    LLexer.Free;
  end;
end;

{ TTomlParserTests }

procedure TTomlParserTests.TestSimpleKeyValue;
var
  LLexer: TTomlLexer;
  LParser: TTomlParser;
  LDocument: TTomlDocumentSyntax;
begin
  LLexer := TTomlLexer.Create('title = "TOML Example"');
  try
    LLexer.Tokenize;

    LParser := TTomlParser.Create(LLexer);
    try
      LDocument := LParser.Parse;
      try
        Assert.IsNotNull(LDocument, 'Document should not be nil');
        Assert.AreEqual(1, LDocument.KeyValues.Count, 'Should have one key-value pair');
      finally
        LDocument.Free;
      end;
    finally
      LParser.Free;
    end;
  finally
    LLexer.Free;
  end;
end;

procedure TTomlParserTests.TestTable;
var
  LToml: string;
  LLexer: TTomlLexer;
  LParser: TTomlParser;
  LDocument: TTomlDocumentSyntax;
begin
  LToml := '[owner]' + sLineBreak + 'name = "John"';

  LLexer := TTomlLexer.Create(LToml);
  try
    LLexer.Tokenize;

    LParser := TTomlParser.Create(LLexer);
    try
      LDocument := LParser.Parse;
      try
        Assert.IsNotNull(LDocument, 'Document should not be nil');
        Assert.AreEqual(1, LDocument.Tables.Count, 'Should have one table');
      finally
        LDocument.Free;
      end;
    finally
      LParser.Free;
    end;
  finally
    LLexer.Free;
  end;
end;

procedure TTomlParserTests.TestNestedTables;
var
  LToml: string;
  LTable: TToml;
begin
  LToml := '[database.server]' + sLineBreak + 'port = 5432';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('database'), 'Should have database table');
  finally
    LTable.Free;
  end;
end;

procedure TTomlParserTests.TestArray;
var
  LToml: string;
  LTable: TToml;
begin
  LToml := 'numbers = [1, 2, 3]';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('numbers'), 'Should have numbers array');
    Assert.AreEqual(Ord(tvkArray), Ord(LTable['numbers'].Kind), 'Should be an array');
  finally
    LTable.Free;
  end;
end;

procedure TTomlParserTests.TestInlineTable;
var
  LToml: string;
  LTable: TToml;
begin
  LToml := 'point = { x = 1, y = 2 }';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('point'), 'Should have point table');
    Assert.AreEqual(Ord(tvkTable), Ord(LTable['point'].Kind), 'Should be a table');
  finally
    LTable.Free;
  end;
end;

{ TTomlApiTests }

procedure TTomlApiTests.TestToModel;
var
  LToml: string;
  LTable: TToml;
begin
  LToml := 'title = "TOML Example"' + sLineBreak +
           'version = 1';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsNotNull(LTable, 'Table should not be nil');
    Assert.IsTrue(LTable.ContainsKey('title'), 'Should have title key');
    Assert.AreEqual('TOML Example', LTable['title'].AsString, 'Title should match');
  finally
    LTable.Free;
  end;
end;

procedure TTomlApiTests.TestFromModel;
var
  LTable: TToml;
  LToml: string;
begin
  LTable := TToml.Create;
  try
    LTable.SetString('title', 'Test');
    LTable.SetInteger('version', 1);

    LToml := LTable.ToString;

    Assert.IsTrue(LToml.Contains('title'), 'Should contain title');
    Assert.IsTrue(LToml.Contains('version'), 'Should contain version');
  finally
    LTable.Free;
  end;
end;

procedure TTomlApiTests.TestRoundTrip;
var
  LOriginal: string;
  LTable: TToml;
  LSerialized: string;
  LTable2: TToml;
begin
  LOriginal := 'title = "TOML"' + sLineBreak + 'count = 42';

  LTable := TToml.FromString(LOriginal);
  try
    LSerialized := LTable.ToString;

    LTable2 := TToml.FromString(LSerialized);
    try
      Assert.AreEqual('TOML', LTable2['title'].AsString, 'Title should survive round-trip');
      Assert.AreEqual(Int64(42), LTable2['count'].AsInteger, 'Count should survive round-trip');
    finally
      LTable2.Free;
    end;
  finally
    LTable.Free;
  end;
end;

procedure TTomlApiTests.TestValidate;
var
  LError: string;
begin
  Assert.IsTrue(TToml.Validate('title = "Valid"', LError), 'Should be valid');
  Assert.IsFalse(TToml.Validate('invalid =', LError), 'Should be invalid');
end;

{ TTomlGoldenFileTests }

function TTomlGoldenFileTests.GetGoldenFilesPath: string;
begin
  Result := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'GoldenFiles');
  if not TDirectory.Exists(Result) then
    Result := TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\GoldenFiles');
end;

procedure TTomlGoldenFileTests.TestExample01;
var
  LFilePath: string;
  LToml: string;
  LTable: TToml;
begin
  LFilePath := TPath.Combine(GetGoldenFilesPath, 'example01.toml');

  if TFile.Exists(LFilePath) then
  begin
    LToml := TFile.ReadAllText(LFilePath);
    LTable := TToml.FromString(LToml);
    try
      Assert.IsNotNull(LTable, 'Table should not be nil');
    finally
      LTable.Free;
    end;
  end
  else
    Assert.Pass('Golden file not found, skipping test');
end;

{ TTomlDateTimeTests }

procedure TTomlDateTimeTests.TestOffsetDateTime;
var
  LToml: string;
  LTable: TToml;
  LDateTime: TDateTime;
begin
  // Test offset datetime with Z (UTC)
  LToml := 'utc_time = 1979-05-27T07:32:00Z';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('utc_time'), 'Should have utc_time key');
    LDateTime := LTable['utc_time'].AsDateTime;

    Assert.AreEqual(1979, YearOf(LDateTime), 'Year should be 1979');
    Assert.AreEqual(5, MonthOf(LDateTime), 'Month should be 5');
    Assert.AreEqual(27, DayOf(LDateTime), 'Day should be 27');
    Assert.AreEqual(7, HourOf(LDateTime), 'Hour should be 7');
    Assert.AreEqual(32, MinuteOf(LDateTime), 'Minute should be 32');
    Assert.AreEqual(0, SecondOf(LDateTime), 'Second should be 0');
  finally
    LTable.Free;
  end;

  // Test offset datetime with timezone offset
  LToml := 'offset_time = 1979-05-27T00:32:00-07:00';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('offset_time'), 'Should have offset_time key');
    LDateTime := LTable['offset_time'].AsDateTime;

    Assert.AreEqual(1979, YearOf(LDateTime), 'Year should be 1979');
    Assert.AreEqual(5, MonthOf(LDateTime), 'Month should be 5');
    Assert.AreEqual(27, DayOf(LDateTime), 'Day should be 27');
  finally
    LTable.Free;
  end;
end;

procedure TTomlDateTimeTests.TestLocalDateTime;
var
  LToml: string;
  LTable: TToml;
  LDateTime: TDateTime;
begin
  LToml := 'local_time = 1979-05-27T07:32:00';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('local_time'), 'Should have local_time key');
    LDateTime := LTable['local_time'].AsDateTime;

    Assert.AreEqual(1979, YearOf(LDateTime), 'Year should be 1979');
    Assert.AreEqual(5, MonthOf(LDateTime), 'Month should be 5');
    Assert.AreEqual(27, DayOf(LDateTime), 'Day should be 27');
    Assert.AreEqual(7, HourOf(LDateTime), 'Hour should be 7');
    Assert.AreEqual(32, MinuteOf(LDateTime), 'Minute should be 32');
    Assert.AreEqual(0, SecondOf(LDateTime), 'Second should be 0');
  finally
    LTable.Free;
  end;
end;

procedure TTomlDateTimeTests.TestLocalDate;
var
  LToml: string;
  LTable: TToml;
  LDateTime: TDateTime;
begin
  LToml := 'birth_date = 1979-05-27';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('birth_date'), 'Should have birth_date key');
    LDateTime := LTable['birth_date'].AsDateTime;

    Assert.AreEqual(1979, YearOf(LDateTime), 'Year should be 1979');
    Assert.AreEqual(5, MonthOf(LDateTime), 'Month should be 5');
    Assert.AreEqual(27, DayOf(LDateTime), 'Day should be 27');
    Assert.AreEqual(0, HourOf(LDateTime), 'Hour should be 0 for date-only');
    Assert.AreEqual(0, MinuteOf(LDateTime), 'Minute should be 0 for date-only');
  finally
    LTable.Free;
  end;
end;

procedure TTomlDateTimeTests.TestLocalTime;
var
  LToml: string;
  LTable: TToml;
  LDateTime: TDateTime;
begin
  LToml := 'wake_time = 07:32:00';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('wake_time'), 'Should have wake_time key');
    LDateTime := LTable['wake_time'].AsDateTime;

    Assert.AreEqual(7, HourOf(LDateTime), 'Hour should be 7');
    Assert.AreEqual(32, MinuteOf(LDateTime), 'Minute should be 32');
    Assert.AreEqual(0, SecondOf(LDateTime), 'Second should be 0');
  finally
    LTable.Free;
  end;
end;

{ TTomlNegativeTests }

procedure TTomlNegativeTests.TestInvalidKeyValue;
var
  LError: string;
begin
  // Missing value
  Assert.IsFalse(TToml.Validate('key =', LError), 'Should reject key without value');

  // Missing equals
  Assert.IsFalse(TToml.Validate('key "value"', LError), 'Should reject key without equals');

  // Invalid key syntax
  Assert.IsFalse(TToml.Validate('= "value"', LError), 'Should reject value without key');
end;

procedure TTomlNegativeTests.TestDuplicateKeys;
var
  LToml: string;
  LError: string;
begin
  LToml := 'name = "First"' + sLineBreak + 'name = "Second"';

  Assert.IsFalse(TToml.Validate(LToml, LError), 'Should reject duplicate keys');
end;

procedure TTomlNegativeTests.TestInvalidEscapeSequence;
var
  LError: string;
begin
  // Invalid escape character
  Assert.IsFalse(TToml.Validate('text = "invalid \x escape"', LError),
    'Should reject invalid escape sequence');
end;

procedure TTomlNegativeTests.TestMalformedTable;
var
  LError: string;
begin
  // Missing closing bracket
  Assert.IsFalse(TToml.Validate('[table', LError), 'Should reject unclosed table header');

  // Missing opening bracket
  Assert.IsFalse(TToml.Validate('table]', LError), 'Should reject table without opening bracket');

  // Empty table name
  Assert.IsFalse(TToml.Validate('[]', LError), 'Should reject empty table name');
end;

procedure TTomlNegativeTests.TestInvalidArrayMixedTypes;
var
  LError: string;
begin
  // Mixed types in array (string and integer)
  Assert.IsFalse(TToml.Validate('mixed = ["string", 123]', LError),
    'Should reject mixed type arrays');

  // Mixed types in array (array of integers and array of strings)
  Assert.IsFalse(TToml.Validate('mixed = [[1, 2], ["a", "b"]]', LError),
    'Should reject arrays with mixed element types');
end;

procedure TTomlNegativeTests.TestInvalidDateTime;
var
  LError: string;
begin
  // Invalid month
  Assert.IsFalse(TToml.Validate('date = 1979-13-27', LError), 'Should reject invalid month');

  // Invalid day
  Assert.IsFalse(TToml.Validate('date = 1979-05-32', LError), 'Should reject invalid day');

  // Invalid hour
  Assert.IsFalse(TToml.Validate('time = 25:00:00', LError), 'Should reject invalid hour');

  // Malformed datetime
  Assert.IsFalse(TToml.Validate('dt = 1979-05-27T', LError),
    'Should reject malformed datetime');
end;

procedure TTomlNegativeTests.TestUnclosedString;
var
  LError: string;
begin
  // Unclosed basic string
  Assert.IsFalse(TToml.Validate('text = "unclosed', LError),
    'Should reject unclosed string');

  // Unclosed literal string
  Assert.IsFalse(TToml.Validate('text = ''unclosed', LError),
    'Should reject unclosed literal string');
end;

procedure TTomlNegativeTests.TestInvalidNumber;
var
  LError: string;
begin
  // Leading zeros (not allowed in TOML)
  Assert.IsFalse(TToml.Validate('num = 007', LError), 'Should reject leading zeros');

  // Invalid float format
  Assert.IsFalse(TToml.Validate('num = 1.2.3', LError), 'Should reject multiple decimal points');

  // Invalid hex format
  Assert.IsFalse(TToml.Validate('num = 0xGHI', LError), 'Should reject invalid hex digits');
end;

procedure TTomlNegativeTests.TestRedefineTable;
var
  LToml: string;
  LError: string;
begin
  // Redefining same table
  LToml := '[table]' + sLineBreak +
           'key = "value"' + sLineBreak +
           '[table]' + sLineBreak +
           'key2 = "value2"';

  Assert.IsFalse(TToml.Validate(LToml, LError), 'Should reject redefined table');
end;

procedure TTomlNegativeTests.TestInvalidInlineTable;
var
  LError: string;
begin
  // Missing closing brace
  Assert.IsFalse(TToml.Validate('point = { x = 1, y = 2', LError),
    'Should reject unclosed inline table');

  // Missing key
  Assert.IsFalse(TToml.Validate('point = { = 1 }', LError),
    'Should reject inline table with missing key');

  // Newline in inline table (not allowed)
  Assert.IsFalse(TToml.Validate('point = { x = 1,' + sLineBreak + 'y = 2 }', LError),
    'Should reject inline table with newline');
end;

end.
