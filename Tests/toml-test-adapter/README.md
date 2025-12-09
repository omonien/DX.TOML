# DX.TOML toml-test Adapter

This is an adapter program that enables testing DX.TOML with the official [toml-test](https://github.com/BurntSushi/toml-test) suite.

## What is toml-test?

toml-test is the official language-agnostic test suite for TOML parsers, providing:
- **556 decoder tests** (185 valid + 371 invalid TOML cases)
- Both valid TOML parsing and invalid TOML rejection tests

**DX.TOML achieves 100% compliance:**
- ✅ **185/185 valid tests** (100%) - Correctly parses all valid TOML
- ✅ **371/371 invalid tests** (100%) - Correctly rejects all invalid TOML
- 🎉 **556/556 total tests passing**

## How it Works

The adapter implements the toml-test interface:
1. Reads TOML from **stdin** (character-by-character to preserve all bytes including standalone CR)
2. Parses it using DX.TOML
3. Converts to JSON with type tags
4. Outputs JSON to **stdout**
5. Returns exit code **0** for valid TOML, **1** for errors

**Note:** The adapter uses character-by-character reading (`Read(Char)`) instead of line-based reading (`ReadLn`) to preserve standalone CR characters, which are invalid in TOML and must be detected.

## JSON Format

toml-test expects values to be wrapped with type tags:

```json
{
  "title": {"type": "string", "value": "TOML Example"},
  "count": {"type": "integer", "value": "42"},
  "enabled": {"type": "bool", "value": "true"},
  "items": {
    "type": "array",
    "value": [
      {"type": "string", "value": "item1"},
      {"type": "string", "value": "item2"}
    ]
  }
}
```

## Building

### Windows

```cmd
dcc32 -B DX.TOML.TestAdapter.dpr
```

### Command-line with Delphi

```cmd
cd Tests\toml-test-adapter
dcc32 -B -E..\toml-test DX.TOML.TestAdapter.dpr
```

This will create `DX.TOML.TestAdapter.exe` in the `Tests\toml-test` directory.

## Running toml-test

### Install toml-test

```bash
go install github.com/BurntSushi/toml-test/cmd/toml-test@latest
```

### Run Decoder Tests

```cmd
toml-test path\to\DX.TOML.TestAdapter.exe
```

### Run Specific Tests

```cmd
# Run only tests matching pattern
toml-test -run datetime path\to\DX.TOML.TestAdapter.exe

# Show verbose output
toml-test -v path\to\DX.TOML.TestAdapter.exe
```

## Test Results

**DX.TOML achieves 100% TOML 1.0.0 specification compliance:**

```
toml-test v2025-04-15: using embedded tests
  valid tests: 185 passed,  0 failed
invalid tests: 371 passed,  0 failed
```

The implementation validates all TOML 1.0 requirements:
- ✅ All syntax rules (strings, numbers, dates, tables, arrays)
- ✅ Unicode handling (UTF-8 validation, escape sequences, surrogate pairs)
- ✅ Edge cases (inline tables, dotted keys, table redefinition)
- ✅ Line ending semantics (LF/CRLF only, standalone CR rejection)
- ✅ DateTime validation (RFC 3339 formats, leading zeros, range checking)
- ✅ Key validation (ASCII-only bare keys, EOL requirements)

## Manual Testing

You can test the adapter manually:

```cmd
echo title = "TOML Example" | DX.TOML.TestAdapter.exe
```

Expected output:
```json
{"title":{"type":"string","value":"TOML Example"}}
```

## Exit Codes

- **0**: Successfully parsed and converted TOML
- **1**: Parse error or invalid TOML

## References

- [toml-test repository](https://github.com/BurntSushi/toml-test)
- [TOML v1.0.0 Specification](https://toml.io/en/v1.0.0)
