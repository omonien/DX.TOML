# DX.TOML

A modern, spec-compliant TOML parser for Delphi with round-trip capability.

## Features

- **TOML 1.0.0 compliant** parser and serializer
- **Round-trip preservation** of comments, formatting, and whitespace
- **Three-layer architecture** (AST ≠ DOM ≠ API)
- **Type-safe** with full Delphi generics support
- **Extensively tested** with DUnitX and golden files
- **INI adapter** for legacy compatibility (optional)

## Architecture

DX.TOML follows a clean three-layer design inspired by [Tomlyn](https://github.com/xoofx/Tomlyn):

### 1. AST Layer (Syntax Tree)
**Purpose**: Exact representation for tooling and round-trip scenarios

- `DX.TOML.AST.pas` - Syntax nodes preserving all formatting details
- Maintains comments, whitespace, and even invalid tokens
- Required for IDEs, validators, and format-preserving edits

### 2. DOM Layer (Runtime Model)
**Purpose**: Convenient runtime access to TOML data

- `DX.TOML.DOM.pas` - `TToml`, `TTomlArray`, `TTomlValue` classes
- Dictionary/List-based for intuitive navigation
- Type-safe value access with Delphi RTTI
- Integrated load/save methods

### 3. API Layer (Public Interface)
**Purpose**: Simple, unified interface

- `DX.TOML.pas` - Re-exports types from DOM layer
- `TToml.FromFile()` / `TToml.FromString()` → Load TOML
- `TToml.SaveToFile()` / `TToml.ToString()` → Save TOML
- `TToml.ParseToAST()` → AST for advanced scenarios

### Supporting Components

- `DX.TOML.Lexer.pas` - Tokenization
- `DX.TOML.Parser.pas` - Parsing logic
- `DX.TOML.Model.pas` - Custom type mapping
- `DX.TOML.Adapter.INI.pas` - INI compatibility layer (adapter pattern)

## Design Principles

1. **AST ≠ DOM ≠ API** - Clear separation of concerns
2. **Round-trip first** - Preserve formatting by default
3. **INI as adapter** - Never core dependency
4. **Spec-driven** - TOML 1.0.0 compliance
5. **Test-driven** - Extensive test coverage with golden files

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
│   └── Delphi Style Guide EN.md
├── Source/
│   ├── DX.TOML.pas              # Main API
│   ├── DX.TOML.AST.pas          # AST/Syntax nodes
│   ├── DX.TOML.DOM.pas          # Runtime model
│   ├── DX.TOML.Lexer.pas        # Tokenizer
│   ├── DX.TOML.Parser.pas       # Parser
│   ├── DX.TOML.Model.pas        # Type mapping
│   └── DX.TOML.Adapter.INI.pas  # INI adapter
├── Tests/
│   ├── DUnitX/                  # DUnitX framework (submodule)
│   ├── GoldenFiles/             # Reference TOML files
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

The test suite uses DUnitX with golden files for comprehensive validation:

```bash
git submodule update --init --recursive
# Open Tests/DX.TOML.Tests.dproj and run
```

## License

MIT License - see LICENSE file for details

## References

- [TOML Specification v1.0.0](https://toml.io/en/v1.0.0)
- [Tomlyn (C# inspiration)](https://github.com/xoofx/Tomlyn)
- [Delphi Style Guide](Docs/Delphi%20Style%20Guide%20EN.md)
