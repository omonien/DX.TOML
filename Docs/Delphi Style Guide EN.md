# Delphi Style Guide

**Version:** 2.1
**Last Updated:** 2025-10-08
**License:** MIT License https://opensource.org/license/mit

This style guide establishes conventions for modern Delphi development, focusing on readability, maintainability, and consistency.

## Key Formatting Rules

- **Indentation**: 2 spaces per logical block
- **Line length**: Maximum 120 characters
- **Statement syntax**: `begin..end` blocks on separate lines; single statements (raise, exit) may omit blocks
- **Comments**: Use `//` for single-line, `{}` for multi-line, `(* *)` for disabled code, `///` for XML documentation

## Naming Conventions

### Variables and Fields

- **Local variables**: `L` prefix (e.g., `LCustomerList`)
- **Class fields**: `F` prefix (e.g., `FConnectionString`)
- **Global variables** (implementation section): `G` prefix; avoid public globals
- **Loop counters**: Lowercase single letters without prefix (exception to the rule)

### Parameters & Methods

- **Parameters**: `A` prefix with PascalCase (e.g., `const AFileName: string`)
- **Methods**: Descriptive verbs in PascalCase (GetUserName, SaveDocument)

### Types & Constants

- **Classes**: `T` prefix (TCustomer)
- **Interfaces**: `I` prefix (ILogger)
- **Records**: `T` prefix; fields don't use `F` prefix
- **Exceptions**: `E` prefix (EInvalidOperation)
- **Technical constants**: `c` prefix (cMaxRetries)
- **String constants**: `sc` prefix (scErrorMessage)
- **Build/system constants**: ALL_CAPS (APP_VERSION)

## Unit Structure & Naming

Modern Delphi projects employ hierarchical namespace structures:

- **Forms**: Unit name ends with `.Form.pas` (e.g., `unit Main.Form;` creates `TFormMain`)
- **Data modules**: End with `.DM.pas` (e.g., `unit Customer.Details.DM;` creates `TDMCustomerDetails`)
- File names match unit names with dot notation preserved

Example hierarchy: `Customer.Details.Form.pas` for nested organization.

## Collections & Modern Features

- **Fixed-size arrays**: Use `TArray<T>`
- **Dynamic lists**: Use `TList<T>`
- **Objects with ownership**: Use `TObjectList<T>`

Modern Delphi supports:
- Inline variables (10.3+)
- Multiline strings (12+)
- Generics
- Anonymous methods
- Attributes

## Error Handling

- Always use `try..finally` with `FreeAndNil()` for resource cleanup
- Ensure proper initialization of all variables before use in try blocks
- Avoid empty `except` blocks except in critical scenarios

## Documentation

Use XML documentation comments for all public APIs:

```delphi
/// <summary>Brief description</summary>
/// <param name="AValue">Parameter description</param>
/// <returns>Description of return value</returns>
```

This enables IntelliSense and automated documentation generation.

## References

Full style guide: https://github.com/omonien/DelphiStandards/blob/master/Delphi%20Style%20Guide%20EN.md
