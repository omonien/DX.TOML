program DX.TOML.TestAdapter;

{$APPTYPE CONSOLE}

{*******************************************************************************
  DX.TOML.TestAdapter - toml-test adapter for DX.TOML

  Description:
    Console application that implements the toml-test interface:
    - Reads TOML from stdin
    - Outputs JSON with type tags to stdout
    - Returns exit code 0 for valid TOML, 1 for invalid

  Usage:
    toml-test DX.TOML.TestAdapter.exe

  Reference:
    https://github.com/BurntSushi/toml-test
*******************************************************************************}

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  DX.TOML in '..\..\Source\DX.TOML.pas';

type
  TTomlTestAdapter = class
  private
    class function TomlValueToJson(AValue: TTomlValue): TJSONObject;
    class function TomlValueToJsonValue(AValue: TTomlValue): TJSONValue;
    class function TomlArrayToJson(AArray: TTomlArray): TJSONArray;
    class function TomlTableToJson(ATable: TToml): TJSONObject;
  public
    class function ConvertTomlToJson(const AToml: string): string;
  end;

{ TTomlTestAdapter }

class function TTomlTestAdapter.TomlValueToJson(AValue: TTomlValue): TJSONObject;
var
  LResult: TJSONObject;
  LValue: string;
begin
  LResult := TJSONObject.Create;
  try
    case AValue.Kind of
      tvkString:
        begin
          LResult.AddPair('type', 'string');
          LResult.AddPair('value', AValue.AsString);
        end;

      tvkInteger:
        begin
          LResult.AddPair('type', 'integer');
          LResult.AddPair('value', AValue.AsInteger.ToString);
        end;

      tvkFloat:
        begin
          LResult.AddPair('type', 'float');
          // Use invariant culture (dot as decimal separator)
          var LFormatSettings := TFormatSettings.Create('en-US');
          LFormatSettings.DecimalSeparator := '.';
          LValue := FloatToStr(AValue.AsFloat, LFormatSettings);
          // Handle special float values
          if SameText(LValue, 'INF') or SameText(LValue, 'Infinity') then
            LValue := 'inf'
          else if SameText(LValue, '-INF') or SameText(LValue, '-Infinity') then
            LValue := '-inf'
          else if SameText(LValue, 'NAN') then
            LValue := 'nan';
          LResult.AddPair('value', LValue);
        end;

      tvkBoolean:
        begin
          LResult.AddPair('type', 'bool');
          if AValue.AsBoolean then
            LResult.AddPair('value', 'true')
          else
            LResult.AddPair('value', 'false');
        end;

      tvkDateTime:
        begin
          // toml-test expects different types based on RFC 3339 format:
          // - datetime: with timezone (Z or +/-HH:MM)
          // - datetime-local: date and time without timezone
          // - date-local: date only
          // - time-local: time only
          LValue := AValue.RawText;

          // Determine type based on format
          if (Pos('-', LValue) = 0) and (Pos('T', UpperCase(LValue)) = 0) then
          begin
            // Time only: 07:32:00
            LResult.AddPair('type', 'time-local');
          end
          else if Pos('T', UpperCase(LValue)) = 0 then
          begin
            // Date only: 1979-05-27
            LResult.AddPair('type', 'date-local');
          end
          else if (Pos('Z', UpperCase(LValue)) > 0) or
                  (Pos('+', Copy(LValue, 11, Length(LValue))) > 0) or
                  (Pos('-', Copy(LValue, 11, Length(LValue))) > 0) then
          begin
            // DateTime with timezone
            LResult.AddPair('type', 'datetime');
          end
          else
          begin
            // DateTime without timezone
            LResult.AddPair('type', 'datetime-local');
          end;

          LResult.AddPair('value', LValue);
        end;

      tvkArray:
        begin
          LResult.AddPair('type', 'array');
          LResult.AddPair('value', TomlArrayToJson(AValue.AsArray));
        end;

      tvkTable:
        begin
          // Inline table
          Result := TomlTableToJson(AValue.AsTable);
          Exit;
        end;
    end;

    Result := LResult;
  except
    LResult.Free;
    raise;
  end;
end;

class function TTomlTestAdapter.TomlValueToJsonValue(AValue: TTomlValue): TJSONValue;
begin
  // Convert TOML value to JSON value
  // Arrays and Tables are returned as JSON arrays/objects directly
  // Other types are wrapped in {"type": "...", "value": "..."}
  case AValue.Kind of
    tvkArray:
      Result := TomlArrayToJson(AValue.AsArray);
    tvkTable:
      Result := TomlTableToJson(AValue.AsTable);
  else
    Result := TomlValueToJson(AValue);
  end;
end;

class function TTomlTestAdapter.TomlArrayToJson(AArray: TTomlArray): TJSONArray;
var
  LResult: TJSONArray;
  I: Integer;
begin
  LResult := TJSONArray.Create;
  try
    for I := 0 to AArray.Count - 1 do
    begin
      // Use TomlValueToJsonValue so nested arrays are also unwrapped
      LResult.AddElement(TomlValueToJsonValue(AArray[I]));
    end;

    Result := LResult;
  except
    LResult.Free;
    raise;
  end;
end;

class function TTomlTestAdapter.TomlTableToJson(ATable: TToml): TJSONObject;
var
  LResult: TJSONObject;
  LKey: string;
  LValue: TTomlValue;
begin
  LResult := TJSONObject.Create;
  try
    for LKey in ATable.Keys do
    begin
      LValue := ATable[LKey];
      // Use TomlValueToJsonValue which handles arrays and tables specially
      LResult.AddPair(LKey, TomlValueToJsonValue(LValue));
    end;

    Result := LResult;
  except
    LResult.Free;
    raise;
  end;
end;

class function TTomlTestAdapter.ConvertTomlToJson(const AToml: string): string;
var
  LTable: TToml;
  LJson: TJSONObject;
begin
  LTable := TToml.FromString(AToml);
  try
    LJson := TomlTableToJson(LTable);
    try
      Result := LJson.ToString;
    finally
      LJson.Free;
    end;
  finally
    LTable.Free;
  end;
end;

{ Main Program }

var
  LInput: TStringList;
  LToml: string;
  LJson: string;
begin
  try
    // Read TOML from stdin
    LInput := TStringList.Create;
    try
      while not Eof do
      begin
        var LLine: string;
        ReadLn(LLine);
        LInput.Add(LLine);
      end;

      LToml := LInput.Text;
    finally
      LInput.Free;
    end;

    // Convert to JSON
    LJson := TTomlTestAdapter.ConvertTomlToJson(LToml);

    // Output to stdout
    WriteLn(LJson);

    // Exit with success
    ExitCode := 0;
  except
    on E: Exception do
    begin
      // toml-test expects non-zero exit code for invalid TOML
      // Don't write error to stdout (would corrupt JSON output)
      WriteLn(ErrOutput, 'Error: ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
