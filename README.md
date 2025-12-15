# DX.TOML [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) ![Delphi](https://img.shields.io/badge/Delphi-11.0%2B-blue) ![TOML](https://img.shields.io/badge/TOML-v1.0.0-orange)

A modern, spec-compliant TOML parser for Delphi with round-trip capability.

## What is TOML?

**TOML** (Tom's Obvious, Minimal Language) is a modern configuration file format designed to be easy to read and write for humans while remaining unambiguous for machines.

### Why TOML instead of INI?

If you're familiar with Delphi's `TIniFile`, think of TOML as "INI done right":

- **Strongly typed**: Native support for strings, integers, floats, booleans, dates, arrays, and nested tables
- **Standardized**: TOML v1.0.0 is a formal specification, unlike INI which has many incompatible variants
- **Unambiguous**: No guessing about data types or escaping rules
- **Modern**: Supports Unicode, multiline strings, comments, and complex nested structures
- **Human-friendly**: Readable syntax with clear semantics

**Example comparison:**

```ini
; Traditional INI - everything is a string
[Database]
Server=localhost
Port=5432
Enabled=true
Tags=web,api,prod
```

```toml
# TOML - proper types and structures
[database]
server = "localhost"
port = 5432
enabled = true
tags = ["web", "api", "prod"]

[database.connection]
timeout = 30
retry = true
```

### TOML Specification

- Official website: [toml.io](https://toml.io/en/)
- Current specification: [TOML v1.0.0](https://toml.io/en/v1.0.0)
- GitHub: [toml-lang/toml](https://github.com/toml-lang/toml)

DX.TOML implements the complete TOML v1.0.0 specification.

## Features

- **Single-unit library** (~4,000 lines) - just add DX.TOML.pas to your project
- **No external dependencies** - uses only Delphi RTL (System.\*, System.Generics.\*)
- **TOML 1.0.0 compliant** parser and serializer - **passes all 556 tests** of the official test suite
- **Round-trip preservation** of comments, formatting, and whitespace
- **Three-layer architecture** (AST ≠ DOM ≠ API) unified in one file
- **Type-safe** with full Delphi generics support
- **100% spec compliance** - validated against the complete [toml-test](https://github.com/BurntSushi/toml-test) suite (185 valid + 371 invalid tests)
- **INI adapter** for legacy compatibility (optional, separate unit)

## Architecture

DX.TOML follows a clean three-layer design inspired by [Tomlyn](https://github.com/xoofx/Tomlyn), unified in a single file:

### Single-Unit Structure

**All functionality in one file** (`DX.TOML.pas`, ~4,000 lines):

1. **Lexer** - Tokenization with position tracking
2. **AST** - Syntax nodes preserving all formatting details for round-trip
3. **Parser** - TOML 1.0.0 compliant parsing logic
4. **DOM** - Runtime model (`TToml`, `TTomlArray`, `TTomlValue`)

### Public API

- `TToml.FromFile()` / `TToml.FromString()` → Load TOML
- `TToml.SaveToFile()` / `TToml.ToString()` → Save TOML
- `TToml.ParseToAST()` → AST for advanced scenarios
- `TToml.Validate()` → Syntax validation

### Optional Components

- `DX.TOML.Adapter.INI.pas` - INI compatibility adapter (separate unit)

## Design Principles

1. **Single-unit simplicity** - Just add DX.TOML.pas to your project
2. **AST ≠ DOM ≠ API** - Clear separation of concerns (within single file)
3. **Round-trip first** - Preserve formatting by default
4. **INI as adapter** - Never core dependency (separate optional unit)
5. **Spec-driven** - TOML 1.0.0 compliance
6. **Test-driven** - Extensive test coverage with golden files

## Quick Start

### Parse TOML from String

```delphi
uses
  DX.TOML;

var
  LToml: TToml;
begin
  // Parse TOML string (using Delphi 12+ multiline strings)
  LToml := TToml.FromString('''
    title = "TOML Example"

    [owner]
    name = "John Doe"
    age = 42
  ''');
  try
    ShowMessage(LToml['title'].AsString);  // "TOML Example"
    ShowMessage(LToml['owner'].AsTable['name'].AsString);  // "John Doe"
    ShowMessage(LToml['owner'].AsTable['age'].AsInteger.ToString);  // "42"
  finally
    LToml.Free;
  end;
end;
```

### Parse TOML from File

```delphi
uses
  DX.TOML;

var
  LToml: TToml;
begin
  LToml := TToml.FromFile('config.toml');
  try
    if LToml.ContainsKey('database') then
    begin
      var LDb := LToml['database'].AsTable;
      var LServer := LDb['server'].AsString;
      var LPort := LDb['port'].AsInteger;
      // Use configuration...
    end;
  finally
    LToml.Free;
  end;
end;
```

### UTF-8 Encoding and BOM Handling

**TOML files MUST be UTF-8 encoded** according to the [TOML v1.0.0 specification](https://toml.io/en/v1.0.0).

**Important notes about encoding:**

1. **UTF-8 is mandatory** - TOML files must always be UTF-8 encoded. Files with UTF-16 or UTF-32 encoding (detected by BOM) will be rejected with a clear error message.

2. **BOM is optional** - The UTF-8 Byte Order Mark (EF BB BF) is permitted but not required:
   - `SaveToFile()` writes UTF-8 **without BOM** (recommended practice)
   - `FromFile()` accepts files **with or without** UTF-8 BOM
   - Non-UTF-8 BOMs (UTF-16, UTF-32) are detected and rejected

3. **Delphi file I/O considerations:**
   - When reading TOML files with Delphi's standard methods (`TFile.ReadAllText`, `TStringList.LoadFromFile`), **always specify UTF-8 encoding explicitly**
   - Many TOML files in the wild don't include a BOM, so Delphi may default to ANSI encoding if not specified
   - This can cause character corruption with special characters (ä, ö, ü, emoji, etc.)

**Example - Correct way to read TOML files in Delphi:**

```delphi
// ✅ GOOD - Explicit UTF-8 encoding
var
  LContent: string;
begin
  LContent := TFile.ReadAllText('config.toml', TEncoding.UTF8);
  // or use DX.TOML's FromFile which handles this automatically
  var LToml := TToml.FromFile('config.toml');
end;

// ❌ BAD - May use wrong encoding if no BOM present
var
  LContent: string;
begin
  LContent := TFile.ReadAllText('config.toml');  // May default to ANSI!
end;
```

**Why DX.TOML handles this correctly:**
- `TToml.FromFile()` reads files as binary (`TFile.ReadAllBytes`)
- Validates the encoding (rejects non-UTF-8 BOMs)
- Skips UTF-8 BOM if present
- Converts to string using UTF-8 encoding
- This ensures correct handling regardless of BOM presence

### Create and Save TOML

```delphi
uses
  DX.TOML;

var
  LToml: TToml;
begin
  LToml := TToml.Create;
  try
    LToml.SetString('title', 'My Application');
    LToml.SetInteger('version', 1);

    var LDb := LToml.GetOrCreateTable('database');
    LDb.SetString('server', 'localhost');
    LDb.SetInteger('port', 5432);

    LToml.SaveToFile('config.toml');
    // or: var LTomlStr := LToml.ToString;
  finally
    LToml.Free;
  end;
end;
```

### INI File Compatibility (Adapter)

DX.TOML includes an optional INI adapter that treats INI files as a subset of TOML:

```delphi
uses
  DX.TOML.Adapter.INI;

var
  LIni: TTomlIniFile;
begin
  LIni := TTomlIniFile.Create('config.ini');
  try
    // Read values (INI-style API)
    var LServer := LIni.ReadString('Database', 'Server', 'localhost');
    var LPort := LIni.ReadInteger('Database', 'Port', 5432);
    var LEnabled := LIni.ReadBool('Database', 'Enabled', True);

    // Write values
    LIni.WriteString('Database', 'Server', '192.168.1.100');
    LIni.WriteInteger('Database', 'Port', 3306);

    // Save changes
    LIni.UpdateFile;
  finally
    LIni.Free;
  end;
end;
```

**Benefits:**
- Drop-in replacement for `TIniFile` with TOML backend
- Supports types beyond strings (integers, floats, booleans)
- Preserves comments and formatting
- Full TOML syntax support in INI files

**Design principle:** INI is an adapter use case, not part of the core architecture.

## Project Structure

```
DX.TOML/
├── Docs/
│   ├── Delphi Style Guide EN.md
│   └── TEST_COVERAGE.md         # Test coverage analysis
├── Source/
│   ├── DX.TOML.pas              # Single-unit library (~2,500 lines)
│   └── DX.TOML.Adapter.INI.pas  # Optional INI adapter
├── Tests/
│   ├── DUnitX/                  # DUnitX framework (submodule)
│   ├── GoldenFiles/             # Reference TOML files
│   ├── toml-test-adapter/       # Official toml-test adapter
│   └── DX.TOML.Tests.dpr        # Test project
└── Samples/
    └── SimpleParser/            # Example usage
```

## Building

Requirements:
- Delphi 11.0 Alexandria or later (for inline variables, RTTI)
- DUnitX (included as submodule)

Note: The examples in this README use Delphi 12+ multiline strings (`'''`) for readability, but the library itself is compatible with Delphi 11.0+.

Configuration:
- Output path: `$(platform)/$(config)` (e.g., `win32\debug`)
- DCU path: `$(platform)/$(config)/dcu`

## Testing

### DUnitX Test Suite

The test suite uses DUnitX with golden files for comprehensive validation:

```bash
git submodule update --init --recursive
# Open Tests/DX.TOML.Tests.dproj and run
```

Test coverage includes:
- **Lexer tests** - Tokenization and position tracking
- **Parser tests** - AST construction and syntax validation
- **API tests** - DOM manipulation and round-trip preservation
- **DateTime tests** - RFC 3339 datetime parsing
- **Negative tests** - Invalid TOML rejection
- **Golden files** - Reference TOML documents

### toml-test Integration

DX.TOML achieves **100% compliance** with the official [toml-test](https://github.com/BurntSushi/toml-test) suite:

- ✅ **185/185 valid tests** (100%) - Correctly parses all valid TOML
- ✅ **371/371 invalid tests** (100%) - Correctly rejects all invalid TOML
- 🎉 **556/556 total tests passing**

```bash
# Build adapter
cd Tests/toml-test-adapter
dcc32 -B DX.TOML.TestAdapter.dpr

# Run toml-test
toml-test path/to/DX.TOML.TestAdapter.exe
```

The implementation validates:
- All TOML 1.0 syntax rules (strings, numbers, dates, tables, arrays)
- Unicode handling (UTF-8 validation, escape sequences, surrogate pairs)
- Edge cases (inline tables, dotted keys, table redefinition)
- Line ending semantics (LF/CRLF only, standalone CR rejection)

See [Tests/toml-test-adapter/README.md](Tests/toml-test-adapter/README.md) for details.

## Contributing

Contributions are welcome! Please see the [Issue Templates](.github/ISSUE_TEMPLATE/) for bug reports and feature requests.

For questions and discussions, use [GitHub Discussions](https://github.com/omonien/DX.TOML/discussions).

## License

MIT License - see [LICENSE](LICENSE) file for details.

Copyright (c) 2025 Olaf Monien

## References

- [TOML Specification v1.0.0](https://toml.io/en/v1.0.0)
- [Tomlyn (C# inspiration)](https://github.com/xoofx/Tomlyn)
- [Delphi Style Guide](Docs/Delphi%20Style%20Guide%20EN.md)

## Repository Setup

For maintainers: See [.github/REPOSITORY_SETUP.md](.github/REPOSITORY_SETUP.md) for GitHub repository configuration (topics, discussions, social preview).
