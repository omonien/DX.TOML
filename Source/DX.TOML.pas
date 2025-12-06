{*******************************************************************************
  DX.TOML - TOML Parser for Delphi

  Description:
    Main unit for the DX.TOML library.
    Simply re-exports DX.TOML.DOM for convenience.

  Usage:
    uses
      DX.TOML;

    var
      LToml: TToml;
    begin
      LToml := TToml.FromFile('config.toml');
      try
        ShowMessage(LToml['title'].AsString);
      finally
        LToml.Free;
      end;
    end;

  Author: DX.TOML Project
  License: MIT
*******************************************************************************}
unit DX.TOML;

interface

uses
  DX.TOML.DOM,
  DX.TOML.AST,
  DX.TOML.Lexer,
  DX.TOML.Parser;

type
  // Re-export main types from DX.TOML.DOM
  TToml = DX.TOML.DOM.TToml;
  TTomlValue = DX.TOML.DOM.TTomlValue;
  TTomlArray = DX.TOML.DOM.TTomlArray;
  TTomlValueKind = DX.TOML.DOM.TTomlValueKind;

  // Re-export AST types for advanced scenarios
  TTomlDocumentSyntax = DX.TOML.AST.TTomlDocumentSyntax;
  TTomlSyntaxNode = DX.TOML.AST.TTomlSyntaxNode;

implementation

end.
