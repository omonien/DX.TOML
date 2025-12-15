# Changelog

All notable changes to DX.TOML will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **UTF-8 BOM Handling** ([#1](https://github.com/omonien/DX.TOML/issues/1))
  - `SaveToFile()` now writes UTF-8 without BOM to avoid parser errors
  - `FromFile()` now correctly handles files with UTF-8 BOM by skipping it
  - `FromFile()` validates encoding and rejects non-UTF-8 BOMs (UTF-16, UTF-32) with clear error messages
  - Added regression test `TestSaveAndLoadFile` to ensure save/load roundtrip works correctly

### Added
- **UTF-8 Encoding Documentation**
  - Added comprehensive UTF-8 encoding section to README
  - Documented TOML 1.0 specification requirement (UTF-8 mandatory)
  - Explained BOM handling (optional but supported)
  - Provided Delphi-specific guidance for reading TOML files with correct encoding
  - Added examples showing correct vs incorrect file reading patterns

### Changed
- Renamed `.github/README.md` to `.github/GITHUB_FILES.md` to prevent GitHub from displaying it as repository README

## [1.0.0] - 2025-12-09

### Added
- **TOML 1.0.0 Complete Specification Support**
  - Full TOML 1.0.0 parser and serializer
  - 100% compliance: passes all 556 tests of the official toml-test suite (185 valid + 371 invalid)
  - Single-unit library (~4,000 lines) with no external dependencies

- **Core Functionality**
  - `TToml.FromFile()` / `TToml.FromString()` - Parse TOML from file or string
  - `TToml.SaveToFile()` / `TToml.ToString()` - Serialize TOML back to file or string
  - `TToml.ParseToAST()` - Access abstract syntax tree for advanced scenarios
  - `TToml.Validate()` - Syntax validation without building DOM

- **Data Type Support**
  - Strings (basic, literal, multiline with proper escape sequences)
  - Integers (decimal, hexadecimal, octal, binary with underscores)
  - Floats (standard, scientific notation, special values: inf, nan)
  - Booleans (true, false)
  - DateTime (RFC 3339 with full timezone support)
  - Arrays (homogeneous, nested)
  - Tables (standard, inline, array-of-tables)

- **Advanced Features**
  - Round-trip preservation of comments, formatting, and whitespace
  - Three-layer architecture (Lexer → AST → DOM) unified in single file
  - Type-safe API with full Delphi generics support
  - Comprehensive error messages with line/column positions

- **Validation**
  - Table definition conflict detection (implicit vs explicit)
  - DateTime format validation (RFC 3339 compliance)
  - Bare key ASCII-only validation
  - Unicode escape sequence validation (surrogate pairs, out-of-range)
  - UTF-8 encoding validation
  - Multiline string quote validation
  - Standalone CR (carriage return) detection
  - Key-value pair EOL validation

- **Testing Infrastructure**
  - DUnitX unit tests with comprehensive test coverage
  - toml-test adapter for official TOML test suite
  - Universal Build-DPROJ.ps1 for any Delphi project
  - Automated build-and-test.ps1 pipeline

- **Documentation**
  - Comprehensive README with usage examples
  - Architecture documentation (three-layer design)
  - TOML vs INI comparison for Delphi developers
  - Complete API reference
  - Test suite documentation

### Technical Highlights
- **Binary file reading** to preserve all byte sequences including standalone CR
- **Incremental path tracking** for proper nested table validation
- **Case-insensitive datetime** parsing for 'T' and 'Z' separators
- **Unicode replacement character detection** (U+FFFD) for encoding errors
- **Surrogate pair validation** (U+D800-U+DFFF range rejection)
- **Out-of-range codepoint** validation (> U+10FFFF with overflow handling)

### Build System
- Universal DPROJ build script for Delphi project compilation
- Auto-detection of installed Delphi versions
- Wrapper scripts (rebuild.bat) for easy command-line builds
- MSBuild integration with proper error reporting

### Project Structure
- `Source/DX.TOML.pas` - Main library unit
- `Tests/` - DUnitX unit tests
- `Tests/toml-test-adapter/` - Official test suite adapter
- `BuildScripts/` - Build automation scripts

[1.0.0]: https://github.com/omonien/DX.TOML/releases/tag/v1.0.0
