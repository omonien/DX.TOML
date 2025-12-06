# Test Coverage Analysis

## Current Status

DX.TOML has basic test coverage but is missing comprehensive TOML 1.0.0 specification compliance testing.

### Existing Tests (DX.TOML.Tests.Main.pas)

| Test Category | Tests | Status |
|--------------|-------|--------|
| Lexer Tests | 4 | ✅ Basic coverage |
| Parser Tests | 5 | ✅ Basic coverage |
| API Tests | 4 | ✅ Round-trip, validation |
| Golden Files | 1 | ⚠️ Only 2 files |
| **Total** | **~14** | **Basic** |

### Missing Test Coverage

Compared to [Tomlyn](https://github.com/xoofx/Tomlyn) and the official [toml-test](https://github.com/BurntSushi/toml-test) suite:

#### 1. DateTime Tests ❌
**Priority: HIGH**
- Currently using `Now` placeholder
- Need proper RFC 3339 datetime parsing
- Test cases:
  - Offset datetime: `1979-05-27T07:32:00-08:00`
  - Local datetime: `1979-05-27T07:32:00`
  - Local date: `1979-05-27`
  - Local time: `07:32:00`

#### 2. Floating-Point Precision Tests ❌
**Priority: MEDIUM**
- No tests for float round-trip accuracy
- Need to test:
  - Scientific notation: `6.02e23`
  - Special values: `inf`, `-inf`, `nan`
  - Precision preservation
  - Underscores in numbers: `1_000.000_001`

#### 3. Official toml-test Suite Integration ❌
**Priority: CRITICAL**
- toml-test provides 278 decoder tests + 94 encoder tests
- Language-agnostic, spec-compliant test suite
- Tests both valid and invalid TOML
- Required for TOML 1.0.0 compliance claim

**Implementation approach:**
```pascal
// Create test adapter that:
// 1. Reads TOML from stdin
// 2. Outputs JSON to stdout (with type tags)
// 3. Returns exit code 0 for valid, non-zero for invalid
```

#### 4. Negative Tests (Invalid TOML) ❌
**Priority: HIGH**
- No tests for malformed TOML
- Need to verify proper error messages
- Test cases:
  - Invalid syntax
  - Type mismatches
  - Duplicate keys
  - Invalid escape sequences
  - Malformed dates

#### 5. Comprehensive Serialization Tests ❌
**Priority: MEDIUM**
- Limited TOML → DOM → TOML testing
- Need to test:
  - Key ordering preservation
  - Comment preservation
  - Whitespace handling
  - Special characters in keys
  - Array formatting

#### 6. Extended Golden Files ❌
**Priority: MEDIUM**
- Currently: 2 golden files
- Recommended: 50+ covering:
  - All TOML data types
  - Complex nested structures
  - Edge cases
  - Real-world config files

### Recommended Test Additions

#### Phase 1: Critical (Spec Compliance)
1. Integrate toml-test suite (278 tests)
2. Add negative test cases (50+ invalid TOML files)
3. Implement proper DateTime parsing and tests

#### Phase 2: Important (Robustness)
4. Add floating-point precision tests
5. Expand golden files to 50+ files
6. Add comprehensive serialization tests

#### Phase 3: Nice-to-Have (Quality)
7. Performance benchmarks
8. Memory leak tests
9. Fuzzing tests
10. Unicode edge case tests

### Test Coverage Goals

| Category | Current | Goal | Priority |
|----------|---------|------|----------|
| Spec Compliance | ~5% | 100% | CRITICAL |
| DateTime Support | 0% | 100% | HIGH |
| Float Precision | ~20% | 100% | MEDIUM |
| Negative Tests | 0% | 100% | HIGH |
| Golden Files | 2 | 50+ | MEDIUM |
| Total Tests | ~14 | 400+ | - |

### References

- [toml-test](https://github.com/BurntSushi/toml-test) - Official TOML test suite
- [Tomlyn Tests](https://github.com/xoofx/Tomlyn/tree/main/src/Tomlyn.Tests) - Reference C# implementation
- [TOML v1.0.0 Spec](https://toml.io/en/v1.0.0) - Complete specification

### Next Steps

1. **Immediate**: Create GitHub issue for toml-test integration
2. **Week 1**: Implement DateTime parsing (currently stubbed with `Now`)
3. **Week 2**: Add 50+ invalid TOML test cases
4. **Week 3**: Integrate toml-test suite adapter
5. **Week 4**: Expand golden files with real-world examples

---

**Note**: Until toml-test integration is complete, DX.TOML should be considered **"TOML 1.0.0 compatible"** rather than **"fully compliant"**.
