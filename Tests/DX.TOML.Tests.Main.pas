{*******************************************************************************
  DX.TOML.Tests.Main - Main Test Suite

  Description:
    DUnitX test suite for DX.TOML library.
    Tests lexer, parser, AST, DOM and API functionality.

  Copyright (c) 2025 Olaf Monien
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
  System.Math,
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

  [TestFixture]
  TTomlLocaleTests = class
  public
    [Test]
    procedure TestFloatParsingLocaleIndependent;
  end;

  [TestFixture]
  TTomlHeterogeneousArrayTests = class
  public
    [Test]
    procedure TestMixedTypesAllowed;

    [Test]
    procedure TestNestedArraysMixedTypes;
  end;

  [TestFixture]
  TTomlArrayOfTablesTests = class
  public
    [Test]
    procedure TestSimpleArrayOfTables;

    [Test]
    procedure TestArrayOfTablesWithSubtables;
  end;

  [TestFixture]
  TTomlUnicodeEscapeTests = class
  public
    [Test]
    procedure TestBasicUnicodeEscape;

    [Test]
    procedure TestExtendedUnicodeEscape;

    [Test]
    procedure TestUnicodeSurrogatePair;
  end;

  [TestFixture]
  TTomlSpecialFloatTests = class
  public
    [Test]
    procedure TestInfinityValues;

    [Test]
    procedure TestNaNValues;
  end;

  [TestFixture]
  TTomlNumberBaseTests = class
  public
    [Test]
    procedure TestBinaryNumbers;

    [Test]
    procedure TestOctalNumbers;

    [Test]
    procedure TestHexNumbers;
  end;

  [TestFixture]
  TTomlLiteralStringTests = class
  public
    [Test]
    procedure TestLiteralStringsNoEscapes;

    [Test]
    procedure TestLiteralStringsWithQuotes;
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

{ TTomlLocaleTests }

procedure TTomlLocaleTests.TestFloatParsingLocaleIndependent;
var
  LToml: string;
  LTable: TToml;
  LValue: Double;
begin
  // Test that floats are parsed correctly regardless of system locale
  // TOML always uses dot as decimal separator
  LToml := 'pi = 3.14159' + sLineBreak +
           'e = 2.71828' + sLineBreak +
           'negative = -123.456' + sLineBreak +
           'positive = +0.5' + sLineBreak +
           'with_exp = 1.5e10' + sLineBreak +
           'with_underscore = 1_234.567_89';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('pi'), 'Should have pi key');
    LValue := LTable['pi'].AsFloat;
    Assert.AreEqual(3.14159, LValue, 0.00001, 'Pi should be parsed correctly');

    LValue := LTable['e'].AsFloat;
    Assert.AreEqual(2.71828, LValue, 0.00001, 'e should be parsed correctly');

    LValue := LTable['negative'].AsFloat;
    Assert.AreEqual(-123.456, LValue, 0.001, 'Negative float should be parsed correctly');

    LValue := LTable['positive'].AsFloat;
    Assert.AreEqual(0.5, LValue, 0.001, 'Positive float with sign should be parsed correctly');

    LValue := LTable['with_exp'].AsFloat;
    Assert.AreEqual(1.5e10, LValue, 1e6, 'Float with exponent should be parsed correctly');

    LValue := LTable['with_underscore'].AsFloat;
    Assert.AreEqual(1234.56789, LValue, 0.00001, 'Float with underscores should be parsed correctly');
  finally
    LTable.Free;
  end;
end;

{ TTomlHeterogeneousArrayTests }

procedure TTomlHeterogeneousArrayTests.TestMixedTypesAllowed;
var
  LToml: string;
  LTable: TToml;
  LArray: TTomlArray;
begin
  // TOML 1.0 allows mixed types in arrays
  LToml := 'mixed = ["string", 42, true, 3.14]' + sLineBreak +
           'strings_and_ints = ["hi", 42]';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('mixed'), 'Should have mixed array');
    LArray := LTable['mixed'].AsArray;
    Assert.AreEqual(4, LArray.Count, 'Array should have 4 elements');
    Assert.AreEqual('string', LArray[0].AsString, 'First element should be string');
    Assert.AreEqual(Int64(42), LArray[1].AsInteger, 'Second element should be integer');
    Assert.IsTrue(LArray[2].AsBoolean, 'Third element should be boolean');
    Assert.AreEqual(3.14, LArray[3].AsFloat, 0.001, 'Fourth element should be float');

    LArray := LTable['strings_and_ints'].AsArray;
    Assert.AreEqual(2, LArray.Count, 'Array should have 2 elements');
    Assert.AreEqual('hi', LArray[0].AsString, 'First element should be string');
    Assert.AreEqual(Int64(42), LArray[1].AsInteger, 'Second element should be integer');
  finally
    LTable.Free;
  end;
end;

procedure TTomlHeterogeneousArrayTests.TestNestedArraysMixedTypes;
var
  LToml: string;
  LTable: TToml;
  LArray, LNested: TTomlArray;
begin
  // TOML 1.0 allows mixed nested arrays
  LToml := 'nested = [[1, 2], ["a", "b"], [1.1, 2.2]]';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('nested'), 'Should have nested array');
    LArray := LTable['nested'].AsArray;
    Assert.AreEqual(3, LArray.Count, 'Array should have 3 sub-arrays');

    // First sub-array: [1, 2]
    LNested := LArray[0].AsArray;
    Assert.AreEqual(2, LNested.Count);
    Assert.AreEqual(Int64(1), LNested[0].AsInteger);
    Assert.AreEqual(Int64(2), LNested[1].AsInteger);

    // Second sub-array: ["a", "b"]
    LNested := LArray[1].AsArray;
    Assert.AreEqual(2, LNested.Count);
    Assert.AreEqual('a', LNested[0].AsString);
    Assert.AreEqual('b', LNested[1].AsString);

    // Third sub-array: [1.1, 2.2]
    LNested := LArray[2].AsArray;
    Assert.AreEqual(2, LNested.Count);
    Assert.AreEqual(1.1, LNested[0].AsFloat, 0.001);
    Assert.AreEqual(2.2, LNested[1].AsFloat, 0.001);
  finally
    LTable.Free;
  end;
end;

{ TTomlArrayOfTablesTests }

procedure TTomlArrayOfTablesTests.TestSimpleArrayOfTables;
var
  LToml: string;
  LTable: TToml;
  LArray: TTomlArray;
  LProduct: TToml;
begin
  // Test [[array]] syntax creates an array of tables
  LToml := '[[products]]' + sLineBreak +
           'name = "Hammer"' + sLineBreak +
           'sku = 738594937' + sLineBreak +
           sLineBreak +
           '[[products]]' + sLineBreak +
           'name = "Nail"' + sLineBreak +
           'sku = 284758393';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('products'), 'Should have products array');
    LArray := LTable['products'].AsArray;
    Assert.AreEqual(2, LArray.Count, 'Should have 2 products');

    // First product
    LProduct := LArray[0].AsTable;
    Assert.AreEqual('Hammer', LProduct['name'].AsString, 'First product name');
    Assert.AreEqual(Int64(738594937), LProduct['sku'].AsInteger, 'First product SKU');

    // Second product
    LProduct := LArray[1].AsTable;
    Assert.AreEqual('Nail', LProduct['name'].AsString, 'Second product name');
    Assert.AreEqual(Int64(284758393), LProduct['sku'].AsInteger, 'Second product SKU');
  finally
    LTable.Free;
  end;
end;

procedure TTomlArrayOfTablesTests.TestArrayOfTablesWithSubtables;
var
  LToml: string;
  LTable: TToml;
  LArray: TTomlArray;
  LItem: TToml;
  LSubtab: TToml;
begin
  // Test [[array]] followed by [array.subtable]
  LToml := '[[arr]]' + sLineBreak +
           '[arr.subtab]' + sLineBreak +
           'val = 1' + sLineBreak +
           sLineBreak +
           '[[arr]]' + sLineBreak +
           '[arr.subtab]' + sLineBreak +
           'val = 2';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('arr'), 'Should have arr array');
    LArray := LTable['arr'].AsArray;
    Assert.AreEqual(2, LArray.Count, 'Should have 2 array elements');

    // First array element
    LItem := LArray[0].AsTable;
    Assert.IsTrue(LItem.ContainsKey('subtab'), 'First element should have subtab');
    LSubtab := LItem['subtab'].AsTable;
    Assert.AreEqual(Int64(1), LSubtab['val'].AsInteger, 'First subtab val should be 1');

    // Second array element
    LItem := LArray[1].AsTable;
    Assert.IsTrue(LItem.ContainsKey('subtab'), 'Second element should have subtab');
    LSubtab := LItem['subtab'].AsTable;
    Assert.AreEqual(Int64(2), LSubtab['val'].AsInteger, 'Second subtab val should be 2');
  finally
    LTable.Free;
  end;
end;

{ TTomlUnicodeEscapeTests }

procedure TTomlUnicodeEscapeTests.TestBasicUnicodeEscape;
var
  LToml: string;
  LTable: TToml;
begin
  // Test \uXXXX escape sequences (4 hex digits)
  LToml := 'basic = "\u0041\u0042\u0043"' + sLineBreak +
           'special = "\u00E9\u00E8\u00EA"' + sLineBreak +  // éèê
           'symbol = "\u2603"';  // ☃ snowman

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('basic'), 'Should have basic key');
    Assert.AreEqual('ABC', LTable['basic'].AsString, 'Should decode \u0041\u0042\u0043 to ABC');

    Assert.IsTrue(LTable.ContainsKey('special'), 'Should have special key');
    Assert.AreEqual(#$00E9#$00E8#$00EA, LTable['special'].AsString, 'Should decode French accents');

    Assert.IsTrue(LTable.ContainsKey('symbol'), 'Should have symbol key');
    Assert.AreEqual(#$2603, LTable['symbol'].AsString, 'Should decode snowman symbol');
  finally
    LTable.Free;
  end;
end;

procedure TTomlUnicodeEscapeTests.TestExtendedUnicodeEscape;
var
  LToml: string;
  LTable: TToml;
begin
  // Test \UXXXXXXXX escape sequences (8 hex digits)
  LToml := 'basic = "\U00000041\U00000042\U00000043"' + sLineBreak +
           'emoji = "\U0001F914"';  // 🤔 thinking face

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('basic'), 'Should have basic key');
    Assert.AreEqual('ABC', LTable['basic'].AsString, 'Should decode \U00000041-43 to ABC');

    Assert.IsTrue(LTable.ContainsKey('emoji'), 'Should have emoji key');
    // Emoji is encoded as UTF-16 surrogate pair
    var LExpected := Char($D83E) + Char($DD14);  // UTF-16 encoding of U+1F914
    Assert.AreEqual(LExpected, LTable['emoji'].AsString, 'Should decode thinking face emoji');
  finally
    LTable.Free;
  end;
end;

procedure TTomlUnicodeEscapeTests.TestUnicodeSurrogatePair;
var
  LToml: string;
  LTable: TToml;
begin
  // Test Unicode characters that require surrogate pairs (> U+FFFF)
  LToml := 'rocket = "\U0001F680"' + sLineBreak +  // 🚀
           'smile = "\U0001F600"' + sLineBreak +    // 😀
           'heart = "\U00002764"';                   // ❤ (doesn't need surrogate)

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('rocket'), 'Should have rocket key');
    var LRocket := LTable['rocket'].AsString;
    Assert.AreEqual(2, Length(LRocket), 'Rocket emoji should be 2 chars (surrogate pair)');

    Assert.IsTrue(LTable.ContainsKey('smile'), 'Should have smile key');
    var LSmile := LTable['smile'].AsString;
    Assert.AreEqual(2, Length(LSmile), 'Smile emoji should be 2 chars (surrogate pair)');

    Assert.IsTrue(LTable.ContainsKey('heart'), 'Should have heart key');
    var LHeart := LTable['heart'].AsString;
    Assert.AreEqual(1, Length(LHeart), 'Heart should be 1 char (BMP)');
    Assert.AreEqual(#$2764, LHeart, 'Should decode heart symbol correctly');
  finally
    LTable.Free;
  end;
end;

{ TTomlSpecialFloatTests }

procedure TTomlSpecialFloatTests.TestInfinityValues;
var
  LToml: string;
  LTable: TToml;
begin
  // Test infinity float literals
  LToml := 'inf1 = inf' + sLineBreak +
           'inf2 = +inf' + sLineBreak +
           'inf3 = -inf';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('inf1'), 'Should have inf1 key');
    Assert.IsTrue(IsInfinite(LTable['inf1'].AsFloat), 'inf should be parsed as Infinity');
    Assert.IsTrue(LTable['inf1'].AsFloat > 0, 'inf should be positive infinity');

    Assert.IsTrue(LTable.ContainsKey('inf2'), 'Should have inf2 key');
    Assert.IsTrue(IsInfinite(LTable['inf2'].AsFloat), '+inf should be parsed as Infinity');
    Assert.IsTrue(LTable['inf2'].AsFloat > 0, '+inf should be positive infinity');

    Assert.IsTrue(LTable.ContainsKey('inf3'), 'Should have inf3 key');
    Assert.IsTrue(IsInfinite(LTable['inf3'].AsFloat), '-inf should be parsed as -Infinity');
    Assert.IsTrue(LTable['inf3'].AsFloat < 0, '-inf should be negative infinity');
  finally
    LTable.Free;
  end;
end;

procedure TTomlSpecialFloatTests.TestNaNValues;
var
  LToml: string;
  LTable: TToml;
begin
  // Test NaN float literals
  LToml := 'nan1 = nan' + sLineBreak +
           'nan2 = +nan' + sLineBreak +
           'nan3 = -nan';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('nan1'), 'Should have nan1 key');
    Assert.IsTrue(IsNaN(LTable['nan1'].AsFloat), 'nan should be parsed as NaN');

    Assert.IsTrue(LTable.ContainsKey('nan2'), 'Should have nan2 key');
    Assert.IsTrue(IsNaN(LTable['nan2'].AsFloat), '+nan should be parsed as NaN');

    Assert.IsTrue(LTable.ContainsKey('nan3'), 'Should have nan3 key');
    Assert.IsTrue(IsNaN(LTable['nan3'].AsFloat), '-nan should be parsed as NaN');
  finally
    LTable.Free;
  end;
end;

{ TTomlNumberBaseTests }

procedure TTomlNumberBaseTests.TestBinaryNumbers;
var
  LToml: string;
  LTable: TToml;
begin
  // Test binary number literals
  LToml := 'bin1 = 0b11010110' + sLineBreak +
           'bin2 = 0b1010' + sLineBreak +
           'bin3 = 0b1111_0000';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('bin1'), 'Should have bin1 key');
    Assert.AreEqual(Int64(214), LTable['bin1'].AsInteger, '0b11010110 should be 214');

    Assert.IsTrue(LTable.ContainsKey('bin2'), 'Should have bin2 key');
    Assert.AreEqual(Int64(10), LTable['bin2'].AsInteger, '0b1010 should be 10');

    Assert.IsTrue(LTable.ContainsKey('bin3'), 'Should have bin3 key');
    Assert.AreEqual(Int64(240), LTable['bin3'].AsInteger, '0b1111_0000 should be 240');
  finally
    LTable.Free;
  end;
end;

procedure TTomlNumberBaseTests.TestOctalNumbers;
var
  LToml: string;
  LTable: TToml;
begin
  // Test octal number literals
  LToml := 'oct1 = 0o755' + sLineBreak +
           'oct2 = 0o644' + sLineBreak +
           'oct3 = 0o01234567';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('oct1'), 'Should have oct1 key');
    Assert.AreEqual(Int64(493), LTable['oct1'].AsInteger, '0o755 should be 493');

    Assert.IsTrue(LTable.ContainsKey('oct2'), 'Should have oct2 key');
    Assert.AreEqual(Int64(420), LTable['oct2'].AsInteger, '0o644 should be 420');

    Assert.IsTrue(LTable.ContainsKey('oct3'), 'Should have oct3 key');
    Assert.AreEqual(Int64(342391), LTable['oct3'].AsInteger, '0o01234567 should be 342391');
  finally
    LTable.Free;
  end;
end;

procedure TTomlNumberBaseTests.TestHexNumbers;
var
  LToml: string;
  LTable: TToml;
begin
  // Test hexadecimal number literals
  LToml := 'hex1 = 0xDEADBEEF' + sLineBreak +
           'hex2 = 0xdeadbeef' + sLineBreak +
           'hex3 = 0x00FF';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('hex1'), 'Should have hex1 key');
    Assert.AreEqual(Int64(3735928559), LTable['hex1'].AsInteger, '0xDEADBEEF should be 3735928559');

    Assert.IsTrue(LTable.ContainsKey('hex2'), 'Should have hex2 key');
    Assert.AreEqual(Int64(3735928559), LTable['hex2'].AsInteger, '0xdeadbeef should be 3735928559');

    Assert.IsTrue(LTable.ContainsKey('hex3'), 'Should have hex3 key');
    Assert.AreEqual(Int64(255), LTable['hex3'].AsInteger, '0x00FF should be 255');
  finally
    LTable.Free;
  end;
end;

{ TTomlLiteralStringTests }

procedure TTomlLiteralStringTests.TestLiteralStringsNoEscapes;
var
  LToml: string;
  LTable: TToml;
begin
  // Literal strings (single quotes) should not process escape sequences
  LToml := 'path = ''C:\Users\nodejs\templates''' + sLineBreak +
           'backslash = ''\\ServerX\admin$\system32\''' + sLineBreak +
           'regex = ''<\i\c*\s*>''';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('path'), 'Should have path key');
    Assert.AreEqual('C:\Users\nodejs\templates', LTable['path'].AsString,
      'Backslashes should be literal');

    Assert.IsTrue(LTable.ContainsKey('backslash'), 'Should have backslash key');
    Assert.AreEqual('\\ServerX\admin$\system32\', LTable['backslash'].AsString,
      'Backslashes should be preserved');

    Assert.IsTrue(LTable.ContainsKey('regex'), 'Should have regex key');
    Assert.AreEqual('<\i\c*\s*>', LTable['regex'].AsString,
      'Regex backslashes should be literal');
  finally
    LTable.Free;
  end;
end;

procedure TTomlLiteralStringTests.TestLiteralStringsWithQuotes;
var
  LToml: string;
  LTable: TToml;
begin
  // Literal strings can contain double quotes
  LToml := 'quoted = ''Tom "Dubs" Preston-Werner''' + sLineBreak +
           'mixed = ''She said "hello" to me''';

  LTable := TToml.FromString(LToml);
  try
    Assert.IsTrue(LTable.ContainsKey('quoted'), 'Should have quoted key');
    Assert.AreEqual('Tom "Dubs" Preston-Werner', LTable['quoted'].AsString,
      'Double quotes should be preserved in literal strings');

    Assert.IsTrue(LTable.ContainsKey('mixed'), 'Should have mixed key');
    Assert.AreEqual('She said "hello" to me', LTable['mixed'].AsString,
      'Double quotes should work in literal strings');
  finally
    LTable.Free;
  end;
end;

end.
