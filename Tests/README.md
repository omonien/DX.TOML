# DX.TOML Test Suite

Comprehensive test suite for the DX.TOML library using the DUnitX framework.

## Opening the Project

```
Tests/DX.TOML.Tests.dproj
```

Open the project file in Delphi 11.0 Alexandria or newer.

## Running Tests

### In the IDE

1. Open `DX.TOML.Tests.dproj` in Delphi
2. Press `F9` (Run) or `Shift+Ctrl+F9` (Run without debugging)
3. Tests will run in the console

### With TestInsight

TestInsight provides a graphical interface for DUnitX tests:

1. Install [TestInsight](https://github.com/project-jedi/testinsight)
2. Open the project in Delphi
3. TestInsight integration will be activated automatically

### Command Line

```cmd
cd Tests
dcc32 -B DX.TOML.Tests.dpr
..\Win32\Debug\DX.TOML.Tests.exe
```

## Test Categories

### TTomlLexerTests (4 Tests)
- Tokenization
- String parsing
- Number parsing
- Comments

### TTomlParserTests (5 Tests)
- Key-value pairs
- Tables
- Nested tables
- Arrays
- Inline tables

### TTomlApiTests (4 Tests)
- TOML → DOM conversion
- DOM → TOML serialization
- Round-trip tests
- Validation

### TTomlDateTimeTests (4 Tests)
- Offset DateTime (RFC 3339)
- Local DateTime
- Local Date
- Local Time

### TTomlNegativeTests (10 Tests)
- Invalid syntax
- Duplicate keys
- Invalid escape sequences
- Malformed tables
- Mixed array types
- Invalid DateTime values
- Unclosed strings
- Invalid numbers
- Table redefinition
- Invalid inline tables

### TTomlGoldenFileTests (1+ Tests)
- Reference TOML files
- Complex structures
- Real-world examples

## Golden Files

Golden files are located in `Tests/GoldenFiles/`:

- `example01.toml`, `example02.toml` - Basic examples
- `datetime.toml` - DateTime formats
- `strings.toml` - String types
- `numbers.toml` - Number formats
- `arrays.toml` - Arrays
- `tables.toml` - Tables
- `unicode.toml` - Unicode characters
- `escapes.toml` - Escape sequences
- `edge-cases.toml` - Edge cases
- `comments.toml` - Comments
- `app-config.toml` - Application configuration
- `database-config.toml` - Database configuration
- `web-server.toml` - Web server configuration
- `package-meta.toml` - Package metadata

## toml-test Integration

For integration with the official [toml-test](https://github.com/BurntSushi/toml-test) suite:

**DX.TOML achieves 100% compliance:**
- ✅ **185/185 valid tests** (100%) - Correctly parses all valid TOML
- ✅ **371/371 invalid tests** (100%) - Correctly rejects all invalid TOML
- 🎉 **556/556 total tests passing**

```cmd
cd toml-test-adapter
build.bat
toml-test ..\..\Win32\Release\DX.TOML.TestAdapter.exe
```

See [toml-test-adapter/README.md](toml-test-adapter/README.md) for details.

## Configuration

### Output Paths

- **Executable**: `../$(Platform)/$(Config)/DX.TOML.Tests.exe`
- **DCU files**: `./$(Platform)/$(Config)/dcu`

### Command Line Options

```cmd
DX.TOML.Tests.exe --help
```

Shows all available options:
- `--xml:<filename>` - Creates NUnit XML report
- `--console:quiet` - Reduced console output
- `--exitbehavior:pause` - Waits for Enter key

## DUnitX Framework

The project uses DUnitX as a submodule:

```bash
git submodule update --init --recursive
```

## Test Coverage

See [../Docs/TEST_COVERAGE.md](../Docs/TEST_COVERAGE.md) for detailed test coverage analysis and comparison with other TOML implementations.

## Requirements

- Delphi 11.0 Alexandria or newer
- DUnitX (included as submodule)
- Windows (Win32/Win64)

## License

MIT License - see [../LICENSE](../LICENSE) for details
