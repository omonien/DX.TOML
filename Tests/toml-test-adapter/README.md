# DX.TOML toml-test Adapter

This is an adapter program that enables testing DX.TOML with the official [toml-test](https://github.com/BurntSushi/toml-test) suite.

## What is toml-test?

toml-test is the official language-agnostic test suite for TOML parsers, providing:
- 278 decoder tests (valid TOML → JSON)
- 94 encoder tests (JSON → TOML)
- Both valid and invalid TOML test cases

## How it Works

The adapter implements the toml-test interface:
1. Reads TOML from **stdin**
2. Parses it using DX.TOML
3. Converts to JSON with type tags
4. Outputs JSON to **stdout**
5. Returns exit code **0** for valid TOML, **1** for errors

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

## Expected Results

A fully TOML 1.0.0 compliant parser should pass all 278 decoder tests. As DX.TOML development progresses, we expect:

- **Phase 1**: Basic parsing (strings, integers, booleans, tables)
- **Phase 2**: Arrays, inline tables, nested structures
- **Phase 3**: DateTime, float precision, edge cases
- **Phase 4**: Full specification compliance

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
