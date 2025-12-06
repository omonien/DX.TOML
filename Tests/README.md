# DX.TOML Test Suite

Umfassende Test-Suite für die DX.TOML Bibliothek mit DUnitX Framework.

## Projekt öffnen

```
Tests/DX.TOML.Tests.dproj
```

Öffnen Sie die Projektdatei in Delphi 11.0 Alexandria oder neuer.

## Tests ausführen

### In der IDE

1. Öffnen Sie `DX.TOML.Tests.dproj` in Delphi
2. Drücken Sie `F9` (Run) oder `Shift+Ctrl+F9` (Run without debugging)
3. Die Tests werden in der Konsole ausgeführt

### Mit TestInsight

TestInsight bietet eine grafische Oberfläche für DUnitX Tests:

1. Installieren Sie [TestInsight](https://github.com/project-jedi/testinsight)
2. Öffnen Sie das Projekt in Delphi
3. Die TestInsight-Integration wird automatisch aktiviert

### Kommandozeile

```cmd
cd Tests
dcc32 -B DX.TOML.Tests.dpr
..\Win32\Debug\DX.TOML.Tests.exe
```

## Test-Kategorien

### TTomlLexerTests (4 Tests)
- Tokenisierung
- String-Parsing
- Zahlen-Parsing
- Kommentare

### TTomlParserTests (5 Tests)
- Key-Value Paare
- Tabellen
- Verschachtelte Tabellen
- Arrays
- Inline-Tabellen

### TTomlApiTests (4 Tests)
- TOML → DOM Konvertierung
- DOM → TOML Serialisierung
- Round-Trip Tests
- Validierung

### TTomlDateTimeTests (4 Tests)
- Offset DateTime (RFC 3339)
- Local DateTime
- Local Date
- Local Time

### TTomlNegativeTests (10 Tests)
- Ungültige Syntax
- Doppelte Keys
- Ungültige Escape-Sequenzen
- Fehlerhafte Tabellen
- Gemischte Array-Typen
- Ungültige DateTime-Werte
- Nicht geschlossene Strings
- Ungültige Zahlen
- Tabellen-Redefinition
- Ungültige Inline-Tabellen

### TTomlGoldenFileTests (1+ Tests)
- Referenz-TOML-Dateien
- Komplexe Strukturen
- Real-world Beispiele

## Golden Files

Die Golden Files befinden sich in `Tests/GoldenFiles/`:

- `example01.toml`, `example02.toml` - Basis-Beispiele
- `datetime.toml` - DateTime-Formate
- `strings.toml` - String-Typen
- `numbers.toml` - Zahlen-Formate
- `arrays.toml` - Arrays
- `tables.toml` - Tabellen
- `unicode.toml` - Unicode-Zeichen
- `escapes.toml` - Escape-Sequenzen
- `edge-cases.toml` - Grenzfälle
- `comments.toml` - Kommentare
- `app-config.toml` - App-Konfiguration
- `database-config.toml` - Datenbank-Config
- `web-server.toml` - Webserver-Config
- `package-meta.toml` - Paket-Metadaten

## toml-test Adapter

Für die Integration mit der offiziellen [toml-test](https://github.com/BurntSushi/toml-test) Suite:

```cmd
cd toml-test-adapter
build.bat
toml-test ..\..\Win32\Release\DX.TOML.TestAdapter.exe
```

Siehe [toml-test-adapter/README.md](toml-test-adapter/README.md) für Details.

## Konfiguration

### Output-Pfade

- **Executable**: `../$(Platform)/$(Config)/DX.TOML.Tests.exe`
- **DCU-Dateien**: `./$(Platform)/$(Config)/dcu`

### Kommandozeilen-Optionen

```cmd
DX.TOML.Tests.exe --help
```

Zeigt alle verfügbaren Optionen:
- `--xml:<filename>` - Erstellt NUnit-XML-Report
- `--console:quiet` - Reduzierte Konsolenausgabe
- `--exitbehavior:pause` - Wartet auf Enter-Taste

## DUnitX Framework

Das Projekt verwendet DUnitX als Submodule:

```bash
git submodule update --init --recursive
```

## Test-Abdeckung

Siehe [../Docs/TEST_COVERAGE.md](../Docs/TEST_COVERAGE.md) für detaillierte Analyse der Test-Abdeckung und Vergleich mit anderen TOML-Implementierungen.

## Anforderungen

- Delphi 11.0 Alexandria oder neuer
- DUnitX (als Submodule enthalten)
- Windows (Win32/Win64)

## Lizenz

MIT License - siehe [../LICENSE](../LICENSE) für Details
