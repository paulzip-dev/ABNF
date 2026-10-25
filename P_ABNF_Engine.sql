--------------------------------------------------------------------------------
-- Augmented Backus Naur Form Engine Package and Utilities
-- Copyright (c) 2026 Paul Scott
--
-- Core of the ABNF implementation (RFC 5234, RFC 7405): the RFC 5234 core rules, ParseGrammar (ABNF text to rule set),
-- ValidateInput / ExplainMismatch (match input and say why it fails), Tokenise / ParseTree (pipelined breakdown of
-- input) and GeneratePLSQLFromABNF / GeneratePLSQLFromRules (rule set to PL/SQL source, so the grammar need not be
-- re-parsed on every call). Works on the TY_ABNF_* types in ABNF_Types.sql; P_ABNF_Network and P_ABNF_CSV build on it.
--------------------------------------------------------------------------------

create or replace package P_ABNF_Engine is

------------------------------------------------------------------------------
-- RFC 5234 Appendix B core rules
------------------------------------------------------------------------------
function CoreAlpha return TY_ABNF_Alternative;
function CoreBit return TY_ABNF_Alternative;
function CoreChar return TY_ABNF_Range;
function CoreCr return TY_ABNF_Literal;
function CoreCrlf return TY_ABNF_Literal;
function CoreCtl return TY_ABNF_Alternative;
function CoreDigit return TY_ABNF_Range;
function CoreDquote return TY_ABNF_Literal;
function CoreHexDig return TY_ABNF_Alternative;
function CoreHtab return TY_ABNF_Literal;
function CoreLf return TY_ABNF_Literal;
function CoreLwsp return TY_ABNF_Repetition;
function CoreOctet return TY_ABNF_Range;
function CoreSp return TY_ABNF_Literal;
function CoreVchar return TY_ABNF_Range;
function CoreWsp return TY_ABNF_Alternative;

-- All core rules as a rule set. They are always available to TY_ABNF_RuleRef nodes.
function CoreRules return TY_ABNF_RuleSet;

------------------------------------------------------------------------------
-- Validation. A node tree (or rule set + start rule) either matches the whole
-- input or it does not. Matching is full ABNF: every alternative is explored.
------------------------------------------------------------------------------
function ValidateInput(
           pNode  TY_ABNF_Node
         , pInput varchar2
         ) return boolean;

procedure ValidateInput(
            pNode             in  TY_ABNF_Node
          , pInput            in  varchar2
          , pIsValid          out boolean
          , pErrorPosition    out integer
          , pFailedNodeName   out varchar2
          , pErrorMessage     out varchar2
          );

-- pStartRule null means the first rule in pRules
function ValidateInput(
           pRules     TY_ABNF_RuleSet
         , pStartRule varchar2
         , pInput     varchar2
         ) return boolean;

procedure ValidateInput(
            pRules            in  TY_ABNF_RuleSet
          , pStartRule        in  varchar2
          , pInput            in  varchar2
          , pIsValid          out boolean
          , pErrorPosition    out integer
          , pFailedNodeName   out varchar2
          , pErrorMessage     out varchar2
          );

------------------------------------------------------------------------------
-- Explain why input does not match. The function forms return null when the
-- input is valid, otherwise a message such as:
--   Line 1, column 6: found "@", expected one of: ALPHA, DIGIT, "." (while matching rule: local-part)
-- The procedure forms return the details separately.
------------------------------------------------------------------------------
function ExplainMismatch(
           pNode  TY_ABNF_Node
         , pInput varchar2
         ) return varchar2;

function ExplainMismatch(
           pRules     TY_ABNF_RuleSet
         , pStartRule varchar2
         , pInput     varchar2
         ) return varchar2;

procedure ExplainMismatch(
            pNode      in  TY_ABNF_Node
          , pInput     in  varchar2
          , pIsValid   out boolean
          , pPosition  out integer
          , pLine      out integer
          , pColumn    out integer
          , pFound     out varchar2
          , pExpected  out TY_ABNF_StrList
          , pMessage   out varchar2
          );

procedure ExplainMismatch(
            pRules     in  TY_ABNF_RuleSet
          , pStartRule in  varchar2
          , pInput     in  varchar2
          , pIsValid   out boolean
          , pPosition  out integer
          , pLine      out integer
          , pColumn    out integer
          , pFound     out varchar2
          , pExpected  out TY_ABNF_StrList
          , pMessage   out varchar2
          );

------------------------------------------------------------------------------
-- Grammar handling
------------------------------------------------------------------------------
-- Parses ABNF text (RFC 5234 + RFC 7405) into a rule set. Comments are kept in
-- TY_ABNF_Rule.COMMENT_TEXT. Raises ORA-20110 with line/column on a syntax error.
function ParseGrammar(pGrammar varchar2) return TY_ABNF_RuleSet;

-- Generates PL/SQL source of a function GetRuleSet return TY_ABNF_RuleSet which rebuilds the grammar
function GeneratePLSQLFromABNF(pGrammar varchar2) return clob;

-- The same from a rule set, e.g. P_ABNF_Network.GetUriRuleSet (a separate name, as a null argument would be ambiguous)
function GeneratePLSQLFromRules(pRules TY_ABNF_RuleSet) return clob;

------------------------------------------------------------------------------
-- Tokenising. Splits pInput into consecutive tokens, each a match of one of the
-- rules named in pTokenRules (comma separated; null = every rule in the grammar).
-- At each position the longest match wins; a tie goes to the rule listed first.
-- Rules that can match nothing (zero length) never produce a token.
-- Raises ORA-20120 (with line/column and the rules tried) if no rule matches somewhere.
--
--   select * from table(P_ABNF_Engine.Tokenise(
--     'int = 1*DIGIT  op = "+" / "-"  ws = 1*SP', 'int,op,ws', '12 + 3'))
------------------------------------------------------------------------------
function Tokenise(
           pRules       TY_ABNF_RuleSet
         , pTokenRules  varchar2
         , pInput       varchar2
         ) return TY_ABNF_TokenList pipelined;

-- Same, from ABNF text
function Tokenise(
           pGrammar     varchar2
         , pTokenRules  varchar2
         , pInput       varchar2
         ) return TY_ABNF_TokenList pipelined;

------------------------------------------------------------------------------
-- Parse tree. Matches the whole of pInput against pStartRule (null = first rule) and returns one row for
-- every match of a rule defined in the grammar, parents before children, so structure is available:
--
--   select t.NODE_ID, t.PARENT_ID, t.DEPTH, t.RULE_NAME, t.START_POS, t.NODE_LENGTH, t.TEXT
--   from table(P_ABNF_Engine.ParseTree('file = 1*(1*ALPHA [","])', 'file', 'ab,c')) t order by t.NODE_ID
--
-- Unlike Tokenise, rules that matched nothing appear (NODE_LENGTH 0), so an empty CSV field is a row. The
-- core rules (DIGIT, ALPHA ...) are not listed unless the grammar defines them itself. If the grammar can
-- match the input in more than one way, the way that tries longer matches first is returned.
-- Raises ORA-20121, with the ExplainMismatch message, if the input does not match.
------------------------------------------------------------------------------
function ParseTree(
           pRules       TY_ABNF_RuleSet
         , pStartRule   varchar2
         , pInput       varchar2
         ) return TY_ABNF_ParseNodeList pipelined;

-- Same, from ABNF text
function ParseTree(
           pGrammar     varchar2
         , pStartRule   varchar2
         , pInput       varchar2
         ) return TY_ABNF_ParseNodeList pipelined;

end P_ABNF_Engine;
/

create or replace package body P_ABNF_Engine is

LF constant varchar2(1) := chr(10);

-- State of the grammar parser
type TParser is record (
  Str      varchar2(32767)
, Pos      integer
, Len      integer
, Cmt      varchar2(4000)  -- comments belonging to the rule being parsed
, Tail     varchar2(4000)  -- comments on their own line(s) not yet attached to a rule
, LineTok  boolean         -- a token has been read on the current line
, LineUsed boolean         -- the current line holds a token or a comment (i.e. is not blank)
, LineStart integer        -- position of the first character of the current line
, RuleIndent integer       -- how far the name of the rule being parsed is indented
);

------------------------------------------------------------------------------
-- ALPHA = %x41-5A / %x61-7A (A-Z / a-z)
------------------------------------------------------------------------------
function CoreAlpha return TY_ABNF_Alternative is
  vResult TY_ABNF_Alternative;
begin
  vResult := TY_ABNF_Alternative(
               NODE_NAME   => 'ALPHA'
             , CHILD_NODES => TY_ABNF_NodeList(
                                TY_ABNF_Range(NODE_NAME => 'ALPHA_UPPER', MIN_CODE => 65, MAX_CODE => 90)
                              , TY_ABNF_Range(NODE_NAME => 'ALPHA_LOWER', MIN_CODE => 97, MAX_CODE => 122)
                              )
             );
  return vResult;
end CoreAlpha;

------------------------------------------------------------------------------
-- BIT = "0" / "1"
------------------------------------------------------------------------------
function CoreBit return TY_ABNF_Alternative is
  vResult TY_ABNF_Alternative;
begin
  vResult := TY_ABNF_Alternative(
               NODE_NAME   => 'BIT'
             , CHILD_NODES => TY_ABNF_NodeList(
                                TY_ABNF_Literal(NODE_NAME => 'BIT_0', VALUE => '0')
                              , TY_ABNF_Literal(NODE_NAME => 'BIT_1', VALUE => '1')
                              )
             );
  return vResult;
end CoreBit;

------------------------------------------------------------------------------
-- CHAR = %x01-7F (any 7-bit US-ASCII character, excluding NUL)
------------------------------------------------------------------------------
function CoreChar return TY_ABNF_Range is
begin
  return TY_ABNF_Range(NODE_NAME => 'CHAR', MIN_CODE => 1, MAX_CODE => 127);
end CoreChar;

------------------------------------------------------------------------------
-- CR = %x0D
------------------------------------------------------------------------------
function CoreCr return TY_ABNF_Literal is
begin
  return TY_ABNF_Literal(NODE_NAME => 'CR', VALUE => chr(13), CASE_SENSITIVE => 'Y');
end CoreCr;

------------------------------------------------------------------------------
-- CRLF = CR LF (%x0D.0A)
------------------------------------------------------------------------------
function CoreCrlf return TY_ABNF_Literal is
  vResult TY_ABNF_Literal;
begin
  vResult := TY_ABNF_Literal(
               NODE_NAME      => 'CRLF'
             , VALUE          => chr(13) || chr(10)
             , CASE_SENSITIVE => 'Y'
             );
  return vResult;
end CoreCrlf;

------------------------------------------------------------------------------
-- CTL = %x00-1F / %x7F
------------------------------------------------------------------------------
function CoreCtl return TY_ABNF_Alternative is
  vResult TY_ABNF_Alternative;
begin
  vResult := TY_ABNF_Alternative(
               NODE_NAME   => 'CTL'
             , CHILD_NODES => TY_ABNF_NodeList(
                                TY_ABNF_Range(NODE_NAME => 'CTL_LOW', MIN_CODE => 0, MAX_CODE => 31)
                              , TY_ABNF_Range(NODE_NAME => 'CTL_DEL', MIN_CODE => 127, MAX_CODE => 127)
                              )
             );
  return vResult;
end CoreCtl;

------------------------------------------------------------------------------
-- DIGIT = %x30-39 (0-9)
------------------------------------------------------------------------------
function CoreDigit return TY_ABNF_Range is
  vResult TY_ABNF_Range;
begin
  vResult := TY_ABNF_Range(
               NODE_NAME => 'DIGIT'
             , MIN_CODE  => 48
             , MAX_CODE  => 57
             );
  return vResult;
end CoreDigit;

------------------------------------------------------------------------------
-- DQUOTE = %x22 (")
------------------------------------------------------------------------------
function CoreDquote return TY_ABNF_Literal is
begin
  return TY_ABNF_Literal(NODE_NAME => 'DQUOTE', VALUE => '"', CASE_SENSITIVE => 'Y');
end CoreDquote;

------------------------------------------------------------------------------
-- HEXDIG = DIGIT / "A" / "B" / "C" / "D" / "E" / "F" (case-insensitive)
------------------------------------------------------------------------------
function CoreHexDig return TY_ABNF_Alternative is
  vResult TY_ABNF_Alternative;
begin
  vResult := TY_ABNF_Alternative(
               NODE_NAME   => 'HEXDIG'
             , CHILD_NODES => TY_ABNF_NodeList(
                                CoreDigit()
                              , TY_ABNF_Range(NODE_NAME => 'HEX_UPPER', MIN_CODE => 65, MAX_CODE => 70)
                              , TY_ABNF_Range(NODE_NAME => 'HEX_LOWER', MIN_CODE => 97, MAX_CODE => 102)
                              )
             );
  return vResult;
end CoreHexDig;

------------------------------------------------------------------------------
-- HTAB = %x09
------------------------------------------------------------------------------
function CoreHtab return TY_ABNF_Literal is
begin
  return TY_ABNF_Literal(NODE_NAME => 'HTAB', VALUE => chr(9), CASE_SENSITIVE => 'Y');
end CoreHtab;

------------------------------------------------------------------------------
-- LF = %x0A
------------------------------------------------------------------------------
function CoreLf return TY_ABNF_Literal is
begin
  return TY_ABNF_Literal(NODE_NAME => 'LF', VALUE => chr(10), CASE_SENSITIVE => 'Y');
end CoreLf;

------------------------------------------------------------------------------
-- LWSP = *(WSP / CRLF WSP) (linear white space: newlines must be followed by white space)
------------------------------------------------------------------------------
function CoreLwsp return TY_ABNF_Repetition is
  vResult TY_ABNF_Repetition;
begin
  vResult := TY_ABNF_Repetition(
               NODE_NAME  => 'LWSP'
             , MIN_OCCURS => 0
             , MAX_OCCURS => null
             , CHILD_NODE => TY_ABNF_Alternative(
                               NODE_NAME   => null
                             , CHILD_NODES => TY_ABNF_NodeList(
                                                CoreWsp()
                                              , TY_ABNF_Sequence(
                                                  NODE_NAME   => null
                                                , CHILD_NODES => TY_ABNF_NodeList(CoreCrlf(), CoreWsp())
                                                )
                                              )
                             )
             );
  return vResult;
end CoreLwsp;

------------------------------------------------------------------------------
-- OCTET = %x00-FF
------------------------------------------------------------------------------
function CoreOctet return TY_ABNF_Range is
begin
  return TY_ABNF_Range(NODE_NAME => 'OCTET', MIN_CODE => 0, MAX_CODE => 255);
end CoreOctet;

------------------------------------------------------------------------------
-- SP = %x20
------------------------------------------------------------------------------
function CoreSp return TY_ABNF_Literal is
begin
  return TY_ABNF_Literal(NODE_NAME => 'SP', VALUE => ' ', CASE_SENSITIVE => 'Y');
end CoreSp;

------------------------------------------------------------------------------
-- VCHAR = %x21-7E (Visible ASCII characters)
------------------------------------------------------------------------------
function CoreVchar return TY_ABNF_Range is
  vResult TY_ABNF_Range;
begin
  vResult := TY_ABNF_Range(
               NODE_NAME => 'VCHAR'
             , MIN_CODE  => 33
             , MAX_CODE  => 126
             );
  return vResult;
end CoreVchar;

------------------------------------------------------------------------------
-- WSP = SP / HTAB (%x20 / %x09)
------------------------------------------------------------------------------
function CoreWsp return TY_ABNF_Alternative is
  vResult TY_ABNF_Alternative;
begin
  vResult := TY_ABNF_Alternative(
               NODE_NAME   => 'WSP'
             , CHILD_NODES => TY_ABNF_NodeList(CoreSp(), CoreHtab())
             );
  return vResult;
end CoreWsp;

function CoreRules return TY_ABNF_RuleSet is
  vResult TY_ABNF_RuleSet := TY_ABNF_RuleSet();

  procedure Add(pName varchar2, pNode TY_ABNF_Node) is
  begin
    vResult.extend;
    vResult(vResult.count) := TY_ABNF_Rule(pName, 'RFC 5234 core rule', pNode);
  end Add;
begin
  Add('ALPHA',  CoreAlpha());
  Add('BIT',    CoreBit());
  Add('CHAR',   CoreChar());
  Add('CR',     CoreCr());
  Add('CRLF',   CoreCrlf());
  Add('CTL',    CoreCtl());
  Add('DIGIT',  CoreDigit());
  Add('DQUOTE', CoreDquote());
  Add('HEXDIG', CoreHexDig());
  Add('HTAB',   CoreHtab());
  Add('LF',     CoreLf());
  Add('LWSP',   CoreLwsp());
  Add('OCTET',  CoreOctet());
  Add('SP',     CoreSp());
  Add('VCHAR',  CoreVchar());
  Add('WSP',    CoreWsp());
  return vResult;
end CoreRules;

------------------------------------------------------------------------------
-- Text position helpers
------------------------------------------------------------------------------
procedure LineAndColumn(
            pText   in  varchar2
          , pPos    in  integer
          , pLine   out integer
          , pColumn out integer
          ) is
  vBefore varchar2(32767) := substr(pText, 1, greatest(pPos - 1, 0));
begin
  pLine   := 1 + nvl(length(vBefore), 0) - nvl(length(replace(vBefore, LF)), 0);
  pColumn := pPos - nvl(instr(vBefore, LF, -1), 0);
end LineAndColumn;

------------------------------------------------------------------------------
-- Matching
------------------------------------------------------------------------------
-- Core rules go last so a grammar's own rules take precedence
function WithCore(pRules TY_ABNF_RuleSet) return TY_ABNF_RuleSet is
  vResult TY_ABNF_RuleSet := nvl(pRules, TY_ABNF_RuleSet());
  vCore   TY_ABNF_RuleSet := CoreRules();
begin
  for i in 1..vCore.count
  loop
    vResult.extend;
    vResult(vResult.count) := vCore(i);
  end loop;
  return vResult;
end WithCore;

function StartNode(pRules TY_ABNF_RuleSet, pStartRule varchar2) return TY_ABNF_Node is
  vName   varchar2(128) := pStartRule;
  vResult TY_ABNF_Node;
begin
  if vName is null and pRules is not null and pRules.count > 0 then
    vName := pRules(1).RULE_NAME;
  end if;
  if vName is not null then
    vResult := TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => vName);
  end if;
  return vResult;
end StartNode;

function JoinExpected(pExpected TY_ABNF_StrList, pExtra varchar2 default null) return varchar2 is
  vResult varchar2(32767);
begin
  for i in 1..least(pExpected.count, 10)
  loop
    vResult := vResult || case when i > 1 then ', ' end || pExpected(i);
  end loop;
  if pExpected.count > 10 then
    vResult := vResult || ', ...';
  end if;
  if pExtra is not null then
    vResult := vResult || case when vResult is not null then ', ' end || pExtra;
  end if;
  return substr(vResult, 1, 4000);
end JoinExpected;

-- Evaluates the whole input. pErrorPosition is the 1-based position of the problem (null when valid).
procedure EvaluateInput(
            pNode           in  TY_ABNF_Node
          , pRules          in  TY_ABNF_RuleSet
          , pInput          in  varchar2
          , pIsValid        out boolean
          , pErrorPosition  out integer
          , pFailedNodeName out varchar2
          , pExpected       out TY_ABNF_StrList
          , pPath           out varchar2
          , pTrailing       out boolean
          ) is
  vCtx     TY_ABNF_Context;
  vEnds    TY_ABNF_PosList;
  vLen     integer := nvl(length(pInput), 0);
  vLongest integer := 0;
begin
  pIsValid        := False;
  pErrorPosition  := 0;
  pFailedNodeName := null;
  pExpected       := TY_ABNF_StrList();
  pPath           := null;
  pTrailing       := False;

  if pNode is not null then
    vCtx  := TY_ABNF_RuleContext.NewContext(WithCore(pRules));
    vEnds := pNode.MatchInput(pInput => pInput, pOffset => 1, pCtx => vCtx);

    if (vLen + 1) member of vEnds then
      pIsValid       := True;
      pErrorPosition := null;
    else
      for i in 1..vEnds.count
      loop
        vLongest := greatest(vLongest, vEnds(i));
      end loop;

      if vLongest > 0 and vCtx.FAIL_POS <= vLongest then
        -- The start of the input is a complete match, but more input follows it
        pTrailing       := True;
        pErrorPosition  := vLongest;
        pFailedNodeName := 'UNEXPECTED_TRAILING_INPUT';
        if vCtx.FAIL_POS = vLongest then
          pExpected := vCtx.EXPECTED;
          pPath     := vCtx.FAIL_PATH;
        end if;
      else
        pErrorPosition := greatest(vCtx.FAIL_POS, 1);
        pExpected      := vCtx.EXPECTED;
        pPath          := vCtx.FAIL_PATH;
        if pExpected.count > 0 then
          pFailedNodeName := pExpected(1);
        end if;
      end if;
    end if;
  end if;
end EvaluateInput;

function BuildMessage(
           pInput    varchar2
         , pPosition integer
         , pExpected TY_ABNF_StrList
         , pPath     varchar2
         , pTrailing boolean
         ) return varchar2 is
  vLen    integer := nvl(length(pInput), 0);
  vLine   integer;
  vColumn integer;
  vCount  integer := pExpected.count;
  vList   varchar2(4000);
  vResult varchar2(32767);
begin
  LineAndColumn(pInput, pPosition, vLine, vColumn);
  vResult := 'Line ' || to_char(vLine) || ', column ' || to_char(vColumn) || ': ';

  if pTrailing then
    vResult := vResult || 'unexpected input "' || TY_ABNF_Context.Escape(substr(pInput, pPosition, 1))
               || '" after a complete match of ' || to_char(pPosition - 1) || ' character(s)';
    vList   := JoinExpected(pExpected, 'end of input');
    vCount  := vCount + 1;
  else
    if pPosition > vLen then
      vResult := vResult || 'unexpected end of input';
    else
      vResult := vResult || 'found "' || TY_ABNF_Context.Escape(substr(pInput, pPosition, 1)) || '"';
    end if;
    vList := JoinExpected(pExpected);
  end if;

  if vCount > 0 then
    vResult := vResult || ', expected ' || case when vCount > 1 then 'one of: ' end || vList;
  end if;
  if pPath is not null then
    vResult := vResult || ' (while matching rule: ' || pPath || ')';
  end if;

  return substr(vResult, 1, 4000);
end BuildMessage;

------------------------------------------------------------------------------
-- ValidateInput
------------------------------------------------------------------------------
procedure ValidateInputImpl(
            pNode           in  TY_ABNF_Node
          , pRules          in  TY_ABNF_RuleSet
          , pInput          in  varchar2
          , pIsValid        out boolean
          , pErrorPosition  out integer
          , pFailedNodeName out varchar2
          , pErrorMessage   out varchar2
          ) is
  vExpected TY_ABNF_StrList;
  vPath     varchar2(4000);
  vTrailing boolean;
begin
  EvaluateInput(pNode, pRules, pInput, pIsValid, pErrorPosition, pFailedNodeName, vExpected, vPath, vTrailing);

  if pIsValid then
    pErrorMessage := null;
  elsif pNode is null then
    pErrorMessage := 'Root rule node is null.';
  else
    pErrorMessage := BuildMessage(pInput, pErrorPosition, vExpected, vPath, vTrailing);
  end if;
end ValidateInputImpl;

function ValidateInput(
           pNode  TY_ABNF_Node
         , pInput varchar2
         ) return boolean is
  vIsValid        boolean;
  vErrorPosition  integer;
  vFailedNodeName varchar2(4000);
  vErrorMessage   varchar2(4000);
begin
  ValidateInputImpl(pNode, null, pInput, vIsValid, vErrorPosition, vFailedNodeName, vErrorMessage);
  return vIsValid;
end ValidateInput;

procedure ValidateInput(
            pNode           in  TY_ABNF_Node
          , pInput          in  varchar2
          , pIsValid        out boolean
          , pErrorPosition  out integer
          , pFailedNodeName out varchar2
          , pErrorMessage   out varchar2
          ) is
begin
  ValidateInputImpl(pNode, null, pInput, pIsValid, pErrorPosition, pFailedNodeName, pErrorMessage);
end ValidateInput;

function ValidateInput(
           pRules     TY_ABNF_RuleSet
         , pStartRule varchar2
         , pInput     varchar2
         ) return boolean is
  vIsValid        boolean;
  vErrorPosition  integer;
  vFailedNodeName varchar2(4000);
  vErrorMessage   varchar2(4000);
begin
  ValidateInputImpl(StartNode(pRules, pStartRule), pRules, pInput, vIsValid, vErrorPosition, vFailedNodeName, vErrorMessage);
  return vIsValid;
end ValidateInput;

procedure ValidateInput(
            pRules          in  TY_ABNF_RuleSet
          , pStartRule      in  varchar2
          , pInput          in  varchar2
          , pIsValid        out boolean
          , pErrorPosition  out integer
          , pFailedNodeName out varchar2
          , pErrorMessage   out varchar2
          ) is
begin
  ValidateInputImpl(
    StartNode(pRules, pStartRule), pRules, pInput, pIsValid, pErrorPosition, pFailedNodeName, pErrorMessage
  );
end ValidateInput;

------------------------------------------------------------------------------
-- ExplainMismatch
------------------------------------------------------------------------------
procedure ExplainImpl(
            pNode      in  TY_ABNF_Node
          , pRules     in  TY_ABNF_RuleSet
          , pInput     in  varchar2
          , pIsValid   out boolean
          , pPosition  out integer
          , pLine      out integer
          , pColumn    out integer
          , pFound     out varchar2
          , pExpected  out TY_ABNF_StrList
          , pMessage   out varchar2
          ) is
  vFailedNodeName varchar2(4000);
  vPath           varchar2(4000);
  vTrailing       boolean;
begin
  pLine   := null;
  pColumn := null;
  pFound  := null;
  EvaluateInput(pNode, pRules, pInput, pIsValid, pPosition, vFailedNodeName, pExpected, vPath, vTrailing);

  if pIsValid then
    pMessage := null;
  elsif pNode is null then
    pMessage := 'Root rule node is null.';
  else
    LineAndColumn(pInput, pPosition, pLine, pColumn);
    if pPosition <= nvl(length(pInput), 0) then
      pFound := substr(pInput, pPosition, 1);
    end if;
    pMessage := BuildMessage(pInput, pPosition, pExpected, vPath, vTrailing);
    if vTrailing then
      -- BuildMessage names "end of input" itself; the structured result lists it as an expected item too
      pExpected.extend;
      pExpected(pExpected.count) := 'end of input';
    end if;
  end if;
end ExplainImpl;

function ExplainMismatch(
           pNode  TY_ABNF_Node
         , pInput varchar2
         ) return varchar2 is
  vIsValid   boolean;
  vPosition  integer;
  vLine      integer;
  vColumn    integer;
  vFound     varchar2(10);
  vExpected  TY_ABNF_StrList;
  vMessage   varchar2(4000);
begin
  ExplainImpl(pNode, null, pInput, vIsValid, vPosition, vLine, vColumn, vFound, vExpected, vMessage);
  return vMessage;
end ExplainMismatch;

function ExplainMismatch(
           pRules     TY_ABNF_RuleSet
         , pStartRule varchar2
         , pInput     varchar2
         ) return varchar2 is
  vIsValid   boolean;
  vPosition  integer;
  vLine      integer;
  vColumn    integer;
  vFound     varchar2(10);
  vExpected  TY_ABNF_StrList;
  vMessage   varchar2(4000);
begin
  ExplainImpl(StartNode(pRules, pStartRule), pRules, pInput, vIsValid, vPosition, vLine, vColumn, vFound, vExpected, vMessage);
  return vMessage;
end ExplainMismatch;

procedure ExplainMismatch(
            pNode      in  TY_ABNF_Node
          , pInput     in  varchar2
          , pIsValid   out boolean
          , pPosition  out integer
          , pLine      out integer
          , pColumn    out integer
          , pFound     out varchar2
          , pExpected  out TY_ABNF_StrList
          , pMessage   out varchar2
          ) is
begin
  ExplainImpl(pNode, null, pInput, pIsValid, pPosition, pLine, pColumn, pFound, pExpected, pMessage);
end ExplainMismatch;

procedure ExplainMismatch(
            pRules     in  TY_ABNF_RuleSet
          , pStartRule in  varchar2
          , pInput     in  varchar2
          , pIsValid   out boolean
          , pPosition  out integer
          , pLine      out integer
          , pColumn    out integer
          , pFound     out varchar2
          , pExpected  out TY_ABNF_StrList
          , pMessage   out varchar2
          ) is
begin
  ExplainImpl(StartNode(pRules, pStartRule), pRules, pInput, pIsValid, pPosition, pLine, pColumn, pFound, pExpected, pMessage);
end ExplainMismatch;

------------------------------------------------------------------------------
-- Grammar parser (RFC 5234 section 4 + RFC 7405)
--
--   rulelist       = 1*( rule / (*c-wsp c-nl) )
--   rule           = rulename defined-as elements c-nl
--   alternation    = concatenation *(*c-wsp "/" *c-wsp concatenation)
--   concatenation  = repetition *(1*c-wsp repetition)
--   repetition     = [repeat] element
--   element        = rulename / group / option / char-val / num-val / prose-val
--
-- The parser is lenient about layout: any mix of spaces, tabs, LF, CRLF and CR is
-- accepted between tokens, rules may be indented, and a new rule starts wherever
-- a rule name is followed by "=" or "=/".
------------------------------------------------------------------------------
function IsAlpha(pCh varchar2) return boolean is
  vCode   integer := ascii(pCh);
  vResult boolean := False;
begin
  if vCode between 65 and 90 or vCode between 97 and 122 then
    vResult := True;
  end if;
  return vResult;
end IsAlpha;

function IsDigit(pCh varchar2) return boolean is
  vResult boolean := False;
begin
  if ascii(pCh) between 48 and 57 then
    vResult := True;
  end if;
  return vResult;
end IsDigit;

function IsNameChar(pCh varchar2) return boolean is
  vResult boolean := False;
begin
  if IsAlpha(pCh) or IsDigit(pCh) or pCh in ('-', '_') then
    vResult := True;
  end if;
  return vResult;
end IsNameChar;

procedure SyntaxError(pStr varchar2, pPos integer, pMessage varchar2) is
  vLine   integer;
  vColumn integer;
begin
  LineAndColumn(pStr, pPos, vLine, vColumn);
  raise_application_error(
    -20110
  , 'ABNF syntax error at line ' || to_char(vLine) || ', column ' || to_char(vColumn) || ': ' || pMessage
  );
end SyntaxError;

function AppendText(pText varchar2, pAdd varchar2) return varchar2 is
  vResult varchar2(4000) := pText;
begin
  if pAdd is not null then
    vResult := substr(case when pText is null then pAdd else pText || LF || pAdd end, 1, 4000);
  end if;
  return vResult;
end AppendText;

function Cur(pP in TParser) return varchar2 is
begin
  return substr(pP.Str, pP.Pos, 1);
end Cur;

-- A token is being read: comments seen since the last token now belong to the current rule
procedure Mark(pP in out nocopy TParser) is
begin
  pP.Cmt      := AppendText(pP.Cmt, pP.Tail);
  pP.Tail     := null;
  pP.LineTok  := True;
  pP.LineUsed := True;
end Mark;

procedure Take(pP in out nocopy TParser, pCount integer) is
begin
  Mark(pP);
  pP.Pos := pP.Pos + pCount;
end Take;

-- Skips white space and comments. A comment after a token on the same line is a trailing comment of the
-- current rule; a comment on its own line is held until the next token (or, after a blank line, dropped).
procedure SkipWs(pP in out nocopy TParser) is
  vCh   varchar2(1);
  vEnd  integer;
  vText varchar2(4000);
begin
  while pP.Pos <= pP.Len
  loop
    vCh := substr(pP.Str, pP.Pos, 1);
    if vCh in (' ', chr(9)) then
      pP.Pos := pP.Pos + 1;
    elsif vCh = LF then
      if not pP.LineUsed then
        pP.Tail := null;
      end if;
      pP.LineUsed  := False;
      pP.LineTok   := False;
      pP.Pos       := pP.Pos + 1;
      pP.LineStart := pP.Pos;
    elsif vCh = ';' then
      vEnd := instr(pP.Str, LF, pP.Pos);
      if vEnd = 0 then
        vEnd := pP.Len + 1;
      end if;
      vText := trim(substr(pP.Str, pP.Pos + 1, vEnd - pP.Pos - 1));
      pP.LineUsed := True;
      -- A comment indented deeper than the rule name (as RFC 5234 itself lays them out) goes with that rule
      if pP.LineTok or pP.Pos - pP.LineStart > pP.RuleIndent then
        pP.Cmt := AppendText(pP.Cmt, vText);
      else
        pP.Tail := AppendText(pP.Tail, vText);
      end if;
      pP.Pos := vEnd;
    else
      exit;
    end if;
  end loop;
end SkipWs;

-- Is the rule name starting at pPos followed by "=" (or "=/")? Looks ahead only.
function PeekIsDefinedAs(pStr varchar2, pPos integer, pLen integer) return boolean is
  vPos    integer := pPos;
  vCh     varchar2(1);
  vResult boolean := False;
begin
  while vPos <= pLen and IsNameChar(substr(pStr, vPos, 1))
  loop
    vPos := vPos + 1;
  end loop;

  while vPos <= pLen
  loop
    vCh := substr(pStr, vPos, 1);
    if vCh in (' ', chr(9), LF) then
      vPos := vPos + 1;
    elsif vCh = ';' then
      vPos := instr(pStr, LF, vPos);
      if vPos = 0 then
        vPos := pLen + 1;
      end if;
    else
      exit;
    end if;
  end loop;

  if vPos <= pLen and substr(pStr, vPos, 1) = '=' then
    vResult := True;
  end if;
  return vResult;
end PeekIsDefinedAs;

function MakeAlternative(pBranches TY_ABNF_NodeList) return TY_ABNF_Node is
  vResult TY_ABNF_Node;
begin
  if pBranches.count = 1 then
    vResult := pBranches(1);
  else
    vResult := TY_ABNF_Alternative(NODE_NAME => null, CHILD_NODES => pBranches);
  end if;
  return vResult;
end MakeAlternative;

-- Reads a run of valid digits for the numeric base (x, d or b) of a %x/%d/%b value
function ReadDigits(pP in out nocopy TParser, pBase varchar2) return varchar2 is
  vValid  varchar2(30) := case pBase
                            when 'x' then '0123456789ABCDEFabcdef'
                            when 'd' then '0123456789'
                            else '01'
                          end;
  vResult varchar2(100);
begin
  while pP.Pos <= pP.Len and instr(vValid, substr(pP.Str, pP.Pos, 1)) > 0
  loop
    vResult := vResult || substr(pP.Str, pP.Pos, 1);
    pP.Pos  := pP.Pos + 1;
  end loop;
  if vResult is null then
    SyntaxError(pP.Str, pP.Pos, 'expected ' || case pBase when 'x' then 'hexadecimal' when 'd' then 'decimal' else 'binary' end
                                 || ' digits in %' || pBase || ' value');
  end if;
  return vResult;
end ReadDigits;

function ToCode(pP in TParser, pPos integer, pDigits varchar2, pBase varchar2) return integer is
  vResult integer := 0;
begin
  if length(pDigits) > 8 then
    SyntaxError(pP.Str, pPos, 'numeric value %' || pBase || pDigits || ' is too large');
  end if;
  if pBase = 'x' then
    vResult := to_number(pDigits, 'XXXXXXXX');
  elsif pBase = 'd' then
    vResult := to_number(pDigits);
  else
    for i in 1..length(pDigits)
    loop
      vResult := vResult * 2 + to_number(substr(pDigits, i, 1));
    end loop;
  end if;
  if vResult > 255 then
    SyntaxError(pP.Str, pPos, 'value ' || to_char(vResult) || ' is above %xFF, which is not supported');
  end if;
  return vResult;
end ToCode;

-- "text" / %s"text" / %i"text": positioned on the opening quote
function ParseCharVal(pP in out nocopy TParser, pCaseSensitive varchar2) return TY_ABNF_Node is
  vEnd  integer := instr(pP.Str, '"', pP.Pos + 1);
  vNl   integer := instr(pP.Str, LF, pP.Pos + 1);
  vText varchar2(32767);
begin
  if vEnd = 0 or (vNl > 0 and vNl < vEnd) then
    SyntaxError(pP.Str, pP.Pos, 'unterminated string, expected a closing double quote');
  end if;
  vText := substr(pP.Str, pP.Pos + 1, vEnd - pP.Pos - 1);
  Take(pP, vEnd - pP.Pos + 1);
  return TY_ABNF_Literal(NODE_NAME => null, VALUE => vText, CASE_SENSITIVE => pCaseSensitive);
end ParseCharVal;

-- %x41 / %x41-5A / %x0D.0A, also %d and %b: positioned on the "%"
function ParseNumVal(pP in out nocopy TParser) return TY_ABNF_Node is
  vStart  integer := pP.Pos;
  vBase   varchar2(1) := lower(substr(pP.Str, pP.Pos + 1, 1));
  vDigits varchar2(100);
  vFirst  integer;
  vLast   integer;
  vValue  varchar2(4000);
  vResult TY_ABNF_Node;
begin
  Take(pP, 2);
  vDigits := ReadDigits(pP, vBase);
  vFirst  := ToCode(pP, vStart, vDigits, vBase);

  if Cur(pP) = '-' then
    Take(pP, 1);
    vDigits := ReadDigits(pP, vBase);
    vLast   := ToCode(pP, vStart, vDigits, vBase);
    if vLast < vFirst then
      SyntaxError(pP.Str, vStart, 'range end is lower than range start');
    end if;
    vResult := TY_ABNF_Range(NODE_NAME => null, MIN_CODE => vFirst, MAX_CODE => vLast);
  else
    vValue := chr(vFirst);
    while Cur(pP) = '.'
    loop
      Take(pP, 1);
      vDigits := ReadDigits(pP, vBase);
      vValue  := vValue || chr(ToCode(pP, vStart, vDigits, vBase));
    end loop;
    vResult := TY_ABNF_Literal(NODE_NAME => null, VALUE => vValue, CASE_SENSITIVE => 'Y');
  end if;

  return vResult;
end ParseNumVal;

function ParseAlternation(pP in out nocopy TParser) return TY_ABNF_NodeList;

-- Positioned on the first character of an element
function ParseElement(pP in out nocopy TParser) return TY_ABNF_Node is
  vCh       varchar2(1) := Cur(pP);
  vStart    integer := pP.Pos;
  vNext     varchar2(1);
  vEnd      integer;
  vName     varchar2(128);
  vBranches TY_ABNF_NodeList;
  vResult   TY_ABNF_Node;
begin
  if vCh = '(' or vCh = '[' then
    Take(pP, 1);
    vBranches := ParseAlternation(pP);
    SkipWs(pP);
    if Cur(pP) is null or Cur(pP) <> case vCh when '(' then ')' else ']' end then
      SyntaxError(pP.Str, vStart, 'expected "' || case vCh when '(' then ')' else ']' end
                                  || '" to close the "' || vCh || '" opened here');
    end if;
    Take(pP, 1);
    vResult := MakeAlternative(vBranches);
    if vCh = '[' then
      vResult := TY_ABNF_Repetition(NODE_NAME => null, MIN_OCCURS => 0, MAX_OCCURS => 1, CHILD_NODE => vResult);
    end if;

  elsif vCh = '"' then
    vResult := ParseCharVal(pP, 'N');

  elsif vCh = '%' then
    vNext := lower(substr(pP.Str, pP.Pos + 1, 1));
    if vNext in ('s', 'i') and substr(pP.Str, pP.Pos + 2, 1) = '"' then
      Take(pP, 2);
      vResult := ParseCharVal(pP, case vNext when 's' then 'Y' else 'N' end);
    elsif vNext in ('x', 'd', 'b') then
      vResult := ParseNumVal(pP);
    else
      SyntaxError(pP.Str, vStart, 'expected x, d, b, s or i after "%"');
    end if;

  elsif vCh = '<' then
    vEnd := instr(pP.Str, '>', pP.Pos + 1);
    if vEnd = 0 or instr(substr(pP.Str, pP.Pos, vEnd - pP.Pos), LF) > 0 then
      SyntaxError(pP.Str, vStart, 'unterminated prose value, expected ">"');
    end if;
    vResult := TY_ABNF_Prose(NODE_NAME => null, TEXT => substr(pP.Str, pP.Pos + 1, vEnd - pP.Pos - 1));
    Take(pP, vEnd - pP.Pos + 1);

  elsif IsAlpha(vCh) then
    Mark(pP);
    while pP.Pos <= pP.Len and IsNameChar(substr(pP.Str, pP.Pos, 1))
    loop
      vName  := vName || substr(pP.Str, pP.Pos, 1);
      pP.Pos := pP.Pos + 1;
    end loop;
    vResult := TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => vName);

  else
    SyntaxError(pP.Str, vStart, 'unexpected ' || case when vCh is null then 'end of grammar' else '"' || vCh || '"' end);
  end if;

  return vResult;
end ParseElement;

-- Reads the digits of a repeat count (null if none)
function ReadCount(pP in out nocopy TParser) return integer is
  vDigits varchar2(20);
begin
  while pP.Pos <= pP.Len and IsDigit(substr(pP.Str, pP.Pos, 1))
  loop
    vDigits := vDigits || substr(pP.Str, pP.Pos, 1);
    pP.Pos  := pP.Pos + 1;
  end loop;
  return to_number(vDigits);
end ReadCount;

-- [repeat] element, where repeat is n, n*m, *, n*, *m
function ParseRepetition(pP in out nocopy TParser) return TY_ABNF_Node is
  vStart     integer := pP.Pos;
  vHasPrefix boolean := False;
  vMin       integer;
  vMax       integer;
  vElement   TY_ABNF_Node;
  vResult    TY_ABNF_Node;
begin
  if IsDigit(Cur(pP)) or Cur(pP) = '*' then
    vHasPrefix := True;
    Mark(pP);
    vMin := ReadCount(pP);
    if Cur(pP) = '*' then
      pP.Pos := pP.Pos + 1;
      vMax   := ReadCount(pP);
      vMin   := nvl(vMin, 0);
    else
      vMax := vMin;
    end if;
    if vMax is not null and vMin > vMax then
      SyntaxError(pP.Str, vStart, 'repeat minimum ' || to_char(vMin) || ' is greater than maximum ' || to_char(vMax));
    end if;
    if Cur(pP) is null or Cur(pP) in (' ', chr(9), LF, ';') then
      SyntaxError(pP.Str, pP.Pos, 'a repeat must be followed immediately by an element');
    end if;
  end if;

  vElement := ParseElement(pP);
  if vHasPrefix then
    vResult := TY_ABNF_Repetition(NODE_NAME => null, MIN_OCCURS => vMin, MAX_OCCURS => vMax, CHILD_NODE => vElement);
  else
    vResult := vElement;
  end if;
  return vResult;
end ParseRepetition;

function ParseConcatenation(pP in out nocopy TParser) return TY_ABNF_Node is
  vItems  TY_ABNF_NodeList := TY_ABNF_NodeList();
  vCh     varchar2(1);
  vResult TY_ABNF_Node;
begin
  SkipWs(pP);
  loop
    vCh := Cur(pP);
    exit when vCh is null or vCh in ('/', ')', ']');
    -- the start of the next rule ends this one
    exit when IsAlpha(vCh) and PeekIsDefinedAs(pP.Str, pP.Pos, pP.Len);
    vItems.extend;
    vItems(vItems.count) := ParseRepetition(pP);
    SkipWs(pP);
  end loop;

  if vItems.count = 0 then
    SyntaxError(pP.Str, pP.Pos, 'expected an element');
  elsif vItems.count = 1 then
    vResult := vItems(1);
  else
    vResult := TY_ABNF_Sequence(NODE_NAME => null, CHILD_NODES => vItems);
  end if;
  return vResult;
end ParseConcatenation;

function ParseAlternation(pP in out nocopy TParser) return TY_ABNF_NodeList is
  vBranches TY_ABNF_NodeList := TY_ABNF_NodeList();
begin
  loop
    vBranches.extend;
    vBranches(vBranches.count) := ParseConcatenation(pP);
    SkipWs(pP);
    if Cur(pP) = '/' then
      Take(pP, 1);
      SkipWs(pP);
    else
      exit;
    end if;
  end loop;
  return vBranches;
end ParseAlternation;

------------------------------------------------------------------------------
-- ParseGrammar
------------------------------------------------------------------------------
function ParseGrammar(pGrammar varchar2) return TY_ABNF_RuleSet is
  type TRuleDef is record (
    RuleName varchar2(128)
  , Branches TY_ABNF_NodeList
  , Cmt      varchar2(4000)
  );
  type TRuleDefTab is table of TRuleDef index by pls_integer;
  type TIndexTab is table of pls_integer index by varchar2(128);

  vP           TParser;
  vDefs        TRuleDefTab;
  vIndex       TIndexTab;
  vResult      TY_ABNF_RuleSet := TY_ABNF_RuleSet();
  vName        varchar2(128);
  vNamePos     integer;
  vKey         varchar2(128);
  vIdx         pls_integer;
  vIncremental boolean;
  vBranches    TY_ABNF_NodeList;
  vNode        TY_ABNF_Node;
begin
  -- Normalise line endings so CR, LF and CRLF all work and positions give correct line numbers
  vP.Str      := replace(replace(pGrammar, chr(13) || chr(10), LF), chr(13), LF);
  vP.Len      := nvl(length(vP.Str), 0);
  vP.Pos      := 1;
  vP.LineTok    := False;
  vP.LineUsed   := False;
  vP.LineStart  := 1;
  vP.RuleIndent := 1000000;  -- no rule yet, so no comment can belong to one

  loop
    SkipWs(vP);
    exit when vP.Pos > vP.Len;

    -- Comments on the lines directly above the rule are its leading comments
    vP.Cmt := null;
    Mark(vP);

    if not IsAlpha(Cur(vP)) then
      SyntaxError(vP.Str, vP.Pos, 'expected a rule name, found "' || Cur(vP) || '"');
    end if;
    vNamePos      := vP.Pos;
    vP.RuleIndent := vP.Pos - vP.LineStart;
    vName         := null;
    while vP.Pos <= vP.Len and IsNameChar(substr(vP.Str, vP.Pos, 1))
    loop
      vName  := vName || substr(vP.Str, vP.Pos, 1);
      vP.Pos := vP.Pos + 1;
    end loop;

    SkipWs(vP);
    if Cur(vP) is null or Cur(vP) <> '=' then
      SyntaxError(vP.Str, vP.Pos, 'expected "=" or "=/" after rule name "' || vName || '"');
    end if;
    Take(vP, 1);
    vIncremental := False;
    if Cur(vP) = '/' then
      Take(vP, 1);
      vIncremental := True;
    end if;

    SkipWs(vP);
    vBranches := ParseAlternation(vP);
    SkipWs(vP);
    if vP.Pos <= vP.Len and not (IsAlpha(Cur(vP)) and PeekIsDefinedAs(vP.Str, vP.Pos, vP.Len)) then
      SyntaxError(vP.Str, vP.Pos, 'unexpected "' || Cur(vP) || '"');
    end if;

    vKey := upper(vName);
    if vIndex.exists(vKey) then
      if not vIncremental then
        SyntaxError(vP.Str, vNamePos, 'rule "' || vName || '" is already defined (use "=/" to add alternatives)');
      end if;
      vIdx := vIndex(vKey);
      for i in 1..vBranches.count
      loop
        vDefs(vIdx).Branches.extend;
        vDefs(vIdx).Branches(vDefs(vIdx).Branches.count) := vBranches(i);
      end loop;
      vDefs(vIdx).Cmt := AppendText(vDefs(vIdx).Cmt, vP.Cmt);
    else
      if vIncremental then
        SyntaxError(vP.Str, vNamePos, 'rule "' || vName || '" cannot be extended with "=/" before it is defined');
      end if;
      vIdx := vDefs.count + 1;
      vDefs(vIdx).RuleName := vName;
      vDefs(vIdx).Branches := vBranches;
      vDefs(vIdx).Cmt      := vP.Cmt;
      vIndex(vKey)         := vIdx;
    end if;
  end loop;

  for i in 1..vDefs.count
  loop
    vNode           := MakeAlternative(vDefs(i).Branches);
    vNode.NODE_NAME := vDefs(i).RuleName;
    vResult.extend;
    vResult(vResult.count) := TY_ABNF_Rule(vDefs(i).RuleName, vDefs(i).Cmt, vNode);
  end loop;

  return vResult;
end ParseGrammar;

------------------------------------------------------------------------------
-- PL/SQL code generation
------------------------------------------------------------------------------
-- A PL/SQL expression for pText; control characters become chr() calls
function PlsqlString(pText varchar2) return varchar2 is
  vResult varchar2(32767);
  vChunk  varchar2(32767);
  vCh     varchar2(1);

  procedure Flush is
  begin
    if vChunk is not null then
      vResult := vResult || case when vResult is not null then ' || ' end
                 || '''' || replace(vChunk, '''', '''''') || '''';
      vChunk  := null;
    end if;
  end Flush;
begin
  if pText is null then
    vResult := 'null';
  else
    for i in 1..length(pText)
    loop
      vCh := substr(pText, i, 1);
      if ascii(vCh) < 32 then
        Flush;
        vResult := vResult || case when vResult is not null then ' || ' end || 'chr(' || to_char(ascii(vCh)) || ')';
      else
        vChunk := vChunk || vCh;
      end if;
    end loop;
    Flush;
  end if;
  return vResult;
end PlsqlString;

function NodeToCode(pNode TY_ABNF_Node, pIndent integer) return varchar2;

function NodeListToCode(pList TY_ABNF_NodeList, pIndent integer) return varchar2 is
  vInd    varchar2(200) := rpad(' ', pIndent);
  vResult varchar2(32767) := 'TY_ABNF_NodeList(';
begin
  for i in 1..pList.count
  loop
    vResult := vResult || LF || vInd || case when i = 1 then '  ' else ', ' end || NodeToCode(pList(i), pIndent + 2);
  end loop;
  return vResult || LF || vInd || ')';
end NodeListToCode;

function NodeToCode(pNode TY_ABNF_Node, pIndent integer) return varchar2 is
  vInd    varchar2(200) := rpad(' ', pIndent);
  vLit    TY_ABNF_Literal;
  vRange  TY_ABNF_Range;
  vProse  TY_ABNF_Prose;
  vRef    TY_ABNF_RuleRef;
  vSeq    TY_ABNF_Sequence;
  vAlt    TY_ABNF_Alternative;
  vRep    TY_ABNF_Repetition;
  vResult varchar2(32767);
begin
  if pNode is null then
    vResult := 'null';
  elsif pNode is of (TY_ABNF_Literal) then
    vLit := treat(pNode as TY_ABNF_Literal);
    vResult := 'TY_ABNF_Literal(NODE_NAME => ' || PlsqlString(vLit.NODE_NAME)
               || ', VALUE => ' || PlsqlString(vLit.VALUE)
               || ', CASE_SENSITIVE => ' || PlsqlString(nvl(vLit.CASE_SENSITIVE, 'N')) || ')';
  elsif pNode is of (TY_ABNF_Range) then
    vRange := treat(pNode as TY_ABNF_Range);
    vResult := 'TY_ABNF_Range(NODE_NAME => ' || PlsqlString(vRange.NODE_NAME)
               || ', MIN_CODE => ' || to_char(vRange.MIN_CODE)
               || ', MAX_CODE => ' || to_char(vRange.MAX_CODE) || ')';
  elsif pNode is of (TY_ABNF_Prose) then
    vProse := treat(pNode as TY_ABNF_Prose);
    vResult := 'TY_ABNF_Prose(NODE_NAME => ' || PlsqlString(vProse.NODE_NAME)
               || ', TEXT => ' || PlsqlString(vProse.TEXT) || ')';
  elsif pNode is of (TY_ABNF_RuleRef) then
    vRef := treat(pNode as TY_ABNF_RuleRef);
    vResult := 'TY_ABNF_RuleRef(NODE_NAME => ' || PlsqlString(vRef.NODE_NAME)
               || ', RULE_NAME => ' || PlsqlString(vRef.RULE_NAME) || ')';
  elsif pNode is of (TY_ABNF_Sequence) then
    vSeq := treat(pNode as TY_ABNF_Sequence);
    vResult := 'TY_ABNF_Sequence(' || LF
               || vInd || '  NODE_NAME   => ' || PlsqlString(vSeq.NODE_NAME) || LF
               || vInd || ', CHILD_NODES => ' || NodeListToCode(vSeq.CHILD_NODES, pIndent + 2) || LF
               || vInd || ')';
  elsif pNode is of (TY_ABNF_Alternative) then
    vAlt := treat(pNode as TY_ABNF_Alternative);
    vResult := 'TY_ABNF_Alternative(' || LF
               || vInd || '  NODE_NAME   => ' || PlsqlString(vAlt.NODE_NAME) || LF
               || vInd || ', CHILD_NODES => ' || NodeListToCode(vAlt.CHILD_NODES, pIndent + 2) || LF
               || vInd || ')';
  elsif pNode is of (TY_ABNF_Repetition) then
    vRep := treat(pNode as TY_ABNF_Repetition);
    vResult := 'TY_ABNF_Repetition(' || LF
               || vInd || '  NODE_NAME  => ' || PlsqlString(vRep.NODE_NAME) || LF
               || vInd || ', MIN_OCCURS => ' || nvl(to_char(vRep.MIN_OCCURS), 'null') || LF
               || vInd || ', MAX_OCCURS => ' || nvl(to_char(vRep.MAX_OCCURS), 'null') || LF
               || vInd || ', CHILD_NODE => ' || NodeToCode(vRep.CHILD_NODE, pIndent + 2) || LF
               || vInd || ')';
  else
    raise_application_error(-20111, 'Cannot generate code for a node of an unsupported type');
  end if;
  return vResult;
end NodeToCode;

procedure AppendClob(pClob in out nocopy clob, pText varchar2) is
begin
  if pText is not null then
    DBMS_LOB.WRITEAPPEND(pClob, length(pText), pText);
  end if;
end AppendClob;

------------------------------------------------------------------------------
-- GeneratePLSQLFromABNF
------------------------------------------------------------------------------
function GeneratePLSQLFromRules(pRules TY_ABNF_RuleSet) return clob is
  vClob     clob;
  vRules    TY_ABNF_RuleSet := pRules;
  vComment  varchar2(4000);
  vLineEnd  integer;
  vLineFrom integer;
begin
  DBMS_LOB.CREATETEMPORARY(vClob, True);
  if vRules is not null and vRules.count > 0 then
    AppendClob(vClob, '-- Generated by P_ABNF_Engine.GeneratePLSQLFromRules' || LF);
    AppendClob(vClob, 'function GetRuleSet return TY_ABNF_RuleSet is' || LF);
    AppendClob(vClob, 'begin' || LF);
    AppendClob(vClob, '  return TY_ABNF_RuleSet(' || LF);

    for i in 1..vRules.count
    loop
      -- Grammar comments become PL/SQL comments
      vComment  := vRules(i).COMMENT_TEXT;
      vLineFrom := 1;
      while vComment is not null and vLineFrom <= length(vComment)
      loop
        vLineEnd := instr(vComment, LF, vLineFrom);
        if vLineEnd = 0 then
          vLineEnd := length(vComment) + 1;
        end if;
        AppendClob(vClob, '    -- ' || substr(vComment, vLineFrom, vLineEnd - vLineFrom) || LF);
        vLineFrom := vLineEnd + 1;
      end loop;

      AppendClob(vClob, case when i = 1 then '    ' else '  , ' end || 'TY_ABNF_Rule(' || LF);
      AppendClob(vClob, '      RULE_NAME    => ' || PlsqlString(vRules(i).RULE_NAME) || LF);
      AppendClob(vClob, '    , COMMENT_TEXT => ' || PlsqlString(vRules(i).COMMENT_TEXT) || LF);
      AppendClob(vClob, '    , RULE_NODE    => ' || NodeToCode(vRules(i).RULE_NODE, 6) || LF);
      AppendClob(vClob, '    )' || LF);
    end loop;

    AppendClob(vClob, '  );' || LF);
    AppendClob(vClob, 'end GetRuleSet;' || LF);
  end if;
  return vClob;
end GeneratePLSQLFromRules;

function GeneratePLSQLFromABNF(pGrammar varchar2) return clob is
  vClob clob;
begin
  if pGrammar is not null then
    vClob := GeneratePLSQLFromRules(ParseGrammar(pGrammar));
  else
    DBMS_LOB.CREATETEMPORARY(vClob, True);
  end if;
  return vClob;
end GeneratePLSQLFromABNF;

------------------------------------------------------------------------------
-- Tokenise
------------------------------------------------------------------------------
function Tokenise(
           pRules       TY_ABNF_RuleSet
         , pTokenRules  varchar2
         , pInput       varchar2
         ) return TY_ABNF_TokenList pipelined is
  vRules     TY_ABNF_RuleSet := WithCore(pRules);
  vNames     TY_ABNF_StrList := TY_ABNF_StrList();
  vRefs      TY_ABNF_NodeList := TY_ABNF_NodeList();
  vCtx       TY_ABNF_RuleContext;
  vEnds      TY_ABNF_PosList;
  vLen       integer := nvl(length(pInput), 0);
  vPos       integer := 1;
  vSeq       integer := 0;
  vBestLen   integer;
  vBestIdx   integer;
  vTokenLen  integer;
  vLine      integer;
  vColumn    integer;
  vTried     varchar2(4000);
  vFrom      integer := 1;
  vComma     integer;
begin
  -- The rules to try, in priority order
  if pTokenRules is null then
    if pRules is not null then
      for i in 1..pRules.count
      loop
        vNames.extend;
        vNames(vNames.count) := pRules(i).RULE_NAME;
      end loop;
    end if;
  else
    while vFrom <= length(pTokenRules) + 1
    loop
      vComma := instr(pTokenRules, ',', vFrom);
      if vComma = 0 then
        vComma := length(pTokenRules) + 1;
      end if;
      if trim(substr(pTokenRules, vFrom, vComma - vFrom)) is not null then
        vNames.extend;
        vNames(vNames.count) := trim(substr(pTokenRules, vFrom, vComma - vFrom));
      end if;
      vFrom := vComma + 1;
    end loop;
  end if;

  for i in 1..vNames.count
  loop
    vRefs.extend;
    vRefs(vRefs.count) := TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => vNames(i));
    vTried := substr(vTried || case when i > 1 then ', ' end || vNames(i), 1, 4000);
  end loop;

  while vPos <= vLen
  loop
    vBestLen := 0;
    vBestIdx := 0;
    for i in 1..vRefs.count
    loop
      -- a fresh context each time, so one rule's failures do not affect the next
      vCtx  := TY_ABNF_RuleContext.NewContext(vRules);
      vEnds := vRefs(i).MatchInput(pInput => pInput, pOffset => vPos, pCtx => vCtx);
      vTokenLen := 0;
      for j in 1..vEnds.count
      loop
        vTokenLen := greatest(vTokenLen, vEnds(j) - vPos);
      end loop;
      if vTokenLen > vBestLen then
        vBestLen := vTokenLen;
        vBestIdx := i;
      end if;
    end loop;

    if vBestIdx = 0 then
      LineAndColumn(pInput, vPos, vLine, vColumn);
      raise_application_error(
        -20120
      , 'Line ' || to_char(vLine) || ', column ' || to_char(vColumn) || ': found "'
        || TY_ABNF_Context.Escape(substr(pInput, vPos, 1)) || '", which does not start any token. Rules tried: '
        || nvl(vTried, '(none)')
      );
    end if;

    vSeq := vSeq + 1;
    pipe row(TY_ABNF_Token(vSeq, vNames(vBestIdx), vPos, vBestLen, substr(pInput, vPos, least(vBestLen, 4000))));
    vPos := vPos + vBestLen;
  end loop;

  return;
end Tokenise;

function Tokenise(
           pGrammar     varchar2
         , pTokenRules  varchar2
         , pInput       varchar2
         ) return TY_ABNF_TokenList pipelined is
begin
  for rec in (
    select t.SEQ, t.RULE_NAME, t.START_POS, t.TOKEN_LENGTH, t.TEXT
    from table(Tokenise(ParseGrammar(pGrammar), pTokenRules, pInput)) t
    order by t.SEQ
  )
  loop
    pipe row(TY_ABNF_Token(rec.SEQ, rec.RULE_NAME, rec.START_POS, rec.TOKEN_LENGTH, rec.TEXT));
  end loop;
  return;
end Tokenise;

------------------------------------------------------------------------------
-- ParseTree
--
-- Matching only reports where a node can end, so the tree is rebuilt by a second pass: Derive finds one way
-- for a node to match exactly pPos..pEnd-1, adding a row for each user-defined rule on the way, and removes
-- the rows again when a choice turns out to be a dead end.
------------------------------------------------------------------------------
-- The ends of a match, longest first, so the greedy reading is tried before the shorter ones
function LongestFirst(pEnds TY_ABNF_PosList) return TY_ABNF_PosList is
  vResult TY_ABNF_PosList;
begin
  select e.COLUMN_VALUE
  bulk collect into vResult
  from table(pEnds) e
  order by e.COLUMN_VALUE desc;
  return vResult;
end LongestFirst;

-- The name pName has in the grammar's own rules, or null if the grammar does not define it
function UserRuleName(pUser TY_ABNF_RuleSet, pName varchar2) return varchar2 is
  vResult varchar2(128);
begin
  if pUser is not null then
    for i in 1..pUser.count
    loop
      if upper(pUser(i).RULE_NAME) = upper(pName) then
        vResult := pUser(i).RULE_NAME;
        exit;
      end if;
    end loop;
  end if;
  return vResult;
end UserRuleName;

procedure TrimRows(pRows in out nocopy TY_ABNF_ParseNodeList, pKeep integer) is
begin
  if pRows.count > pKeep then
    pRows.trim(pRows.count - pKeep);
  end if;
end TrimRows;

function Derive(
           pNode   in     TY_ABNF_Node
         , pInput  in     varchar2
         , pPos    in     integer
         , pEnd    in     integer
         , pParent in     integer
         , pDepth  in     integer
         , pUser   in     TY_ABNF_RuleSet
         , pCtx    in out nocopy TY_ABNF_RuleContext
         , pRows   in out nocopy TY_ABNF_ParseNodeList
         ) return boolean;

-- Children pIdx.. of a sequence must cover pPos..pEnd-1
function DeriveSequence(
           pChildren in     TY_ABNF_NodeList
         , pIdx      in     integer
         , pInput    in     varchar2
         , pPos      in     integer
         , pEnd      in     integer
         , pParent   in     integer
         , pDepth    in     integer
         , pUser     in     TY_ABNF_RuleSet
         , pCtx      in out nocopy TY_ABNF_RuleContext
         , pRows     in out nocopy TY_ABNF_ParseNodeList
         ) return boolean is
  vEnds   TY_ABNF_PosList;
  vSaved  integer;
  vResult boolean := False;
begin
  if pChildren is null or pIdx > pChildren.count then
    vResult := pPos = pEnd;
  elsif pChildren(pIdx) is null then
    vResult := DeriveSequence(pChildren, pIdx + 1, pInput, pPos, pEnd, pParent, pDepth, pUser, pCtx, pRows);
  else
    vEnds  := LongestFirst(pChildren(pIdx).MatchInput(pInput => pInput, pOffset => pPos, pCtx => pCtx));
    vSaved := pRows.count;
    for i in 1..vEnds.count
    loop
      if vEnds(i) <= pEnd
         and Derive(pChildren(pIdx), pInput, pPos, vEnds(i), pParent, pDepth, pUser, pCtx, pRows)
         and DeriveSequence(pChildren, pIdx + 1, pInput, vEnds(i), pEnd, pParent, pDepth, pUser, pCtx, pRows) then
        vResult := True;
        exit;
      end if;
      TrimRows(pRows, vSaved);
    end loop;
  end if;
  return vResult;
end DeriveSequence;

-- pCount repeats are done; the rest must cover pPos..pEnd-1
function DeriveRepetition(
           pRep    in     TY_ABNF_Repetition
         , pCount  in     integer
         , pInput  in     varchar2
         , pPos    in     integer
         , pEnd    in     integer
         , pParent in     integer
         , pDepth  in     integer
         , pUser   in     TY_ABNF_RuleSet
         , pCtx    in out nocopy TY_ABNF_RuleContext
         , pRows   in out nocopy TY_ABNF_ParseNodeList
         ) return boolean is
  vMin    integer := nvl(pRep.MIN_OCCURS, 0);
  vEnds   TY_ABNF_PosList;
  vSaved  integer;
  vResult boolean := False;
begin
  if pPos = pEnd and pCount >= vMin then
    vResult := True;
  elsif pRep.CHILD_NODE is not null and (pRep.MAX_OCCURS is null or pCount < pRep.MAX_OCCURS) then
    vEnds  := LongestFirst(pRep.CHILD_NODE.MatchInput(pInput => pInput, pOffset => pPos, pCtx => pCtx));
    vSaved := pRows.count;
    for i in 1..vEnds.count
    loop
      -- an empty repeat is only useful to reach the minimum count
      if vEnds(i) <= pEnd and (vEnds(i) > pPos or pCount < vMin)
         and Derive(pRep.CHILD_NODE, pInput, pPos, vEnds(i), pParent, pDepth, pUser, pCtx, pRows)
         and DeriveRepetition(pRep, pCount + 1, pInput, vEnds(i), pEnd, pParent, pDepth, pUser, pCtx, pRows) then
        vResult := True;
        exit;
      end if;
      TrimRows(pRows, vSaved);
    end loop;
  end if;
  return vResult;
end DeriveRepetition;

function Derive(
           pNode   in     TY_ABNF_Node
         , pInput  in     varchar2
         , pPos    in     integer
         , pEnd    in     integer
         , pParent in     integer
         , pDepth  in     integer
         , pUser   in     TY_ABNF_RuleSet
         , pCtx    in out nocopy TY_ABNF_RuleContext
         , pRows   in out nocopy TY_ABNF_ParseNodeList
         ) return boolean is
  vSaved    integer := pRows.count;
  vAlt      TY_ABNF_Alternative;
  vEnds     TY_ABNF_PosList;
  vRef      TY_ABNF_RuleRef;
  vTarget   TY_ABNF_Node;
  vRuleName varchar2(128);
  vId       integer;
  vResult   boolean := False;
begin
  if pNode is null then
    vResult := pPos = pEnd;
  elsif pNode is of (TY_ABNF_Sequence) then
    vResult := DeriveSequence(
                 treat(pNode as TY_ABNF_Sequence).CHILD_NODES, 1, pInput, pPos, pEnd, pParent, pDepth, pUser, pCtx, pRows
               );
  elsif pNode is of (TY_ABNF_Alternative) then
    vAlt := treat(pNode as TY_ABNF_Alternative);
    if vAlt.CHILD_NODES is not null then
      for i in 1..vAlt.CHILD_NODES.count
      loop
        vResult := Derive(vAlt.CHILD_NODES(i), pInput, pPos, pEnd, pParent, pDepth, pUser, pCtx, pRows);
        exit when vResult;
        TrimRows(pRows, vSaved);
      end loop;
    end if;
  elsif pNode is of (TY_ABNF_Repetition) then
    vResult := DeriveRepetition(
                 treat(pNode as TY_ABNF_Repetition), 0, pInput, pPos, pEnd, pParent, pDepth, pUser, pCtx, pRows
               );
  elsif pNode is of (TY_ABNF_RuleRef) then
    vRef      := treat(pNode as TY_ABNF_RuleRef);
    vRuleName := UserRuleName(pUser, vRef.RULE_NAME);
    if vRuleName is null then
      -- a core rule: it only has to match, it is not listed
      vEnds   := vRef.MatchInput(pInput => pInput, pOffset => pPos, pCtx => pCtx);
      vResult := pEnd member of vEnds;
    else
      vTarget := pCtx.FindRule(vRuleName);
      pRows.extend;
      vId := pRows.count;
      pRows(vId) := TY_ABNF_ParseNode(
                      vId, pParent, pDepth, vRuleName, pPos, pEnd - pPos
                    , substr(pInput, pPos, least(pEnd - pPos, 4000))
                    );
      vResult := Derive(vTarget, pInput, pPos, pEnd, vId, pDepth + 1, pUser, pCtx, pRows);
    end if;
  else
    -- literal, range or prose
    vEnds   := pNode.MatchInput(pInput => pInput, pOffset => pPos, pCtx => pCtx);
    vResult := pEnd member of vEnds;
  end if;

  if not vResult then
    TrimRows(pRows, vSaved);
  end if;
  return vResult;
end Derive;

function ParseTree(
           pRules       TY_ABNF_RuleSet
         , pStartRule   varchar2
         , pInput       varchar2
         ) return TY_ABNF_ParseNodeList pipelined is
  vCtx    TY_ABNF_RuleContext := TY_ABNF_RuleContext.NewContext(WithCore(pRules));
  vStart  TY_ABNF_Node := StartNode(pRules, pStartRule);
  vEnds   TY_ABNF_PosList;
  vLen    integer := nvl(length(pInput), 0);
  vRows   TY_ABNF_ParseNodeList := TY_ABNF_ParseNodeList();
begin
  if vStart is null then
    raise_application_error(-20121, 'There is no start rule to parse with');
  end if;

  -- also raises for undefined and left-recursive rules, before any tree is built
  vEnds := vStart.MatchInput(pInput => pInput, pOffset => 1, pCtx => vCtx);
  if not ((vLen + 1) member of vEnds) then
    raise_application_error(-20121, 'Input does not match: ' || ExplainMismatch(pRules, pStartRule, pInput));
  end if;

  if not Derive(vStart, pInput, 1, vLen + 1, null, 0, pRules, vCtx, vRows) then
    raise_application_error(-20121, 'Parse tree could not be built');
  end if;

  for i in 1..vRows.count
  loop
    pipe row(vRows(i));
  end loop;
  return;
end ParseTree;

function ParseTree(
           pGrammar     varchar2
         , pStartRule   varchar2
         , pInput       varchar2
         ) return TY_ABNF_ParseNodeList pipelined is
begin
  for rec in (
    select t.NODE_ID, t.PARENT_ID, t.DEPTH, t.RULE_NAME, t.START_POS, t.NODE_LENGTH, t.TEXT
    from table(ParseTree(ParseGrammar(pGrammar), pStartRule, pInput)) t
    order by t.NODE_ID
  )
  loop
    pipe row(TY_ABNF_ParseNode(
               rec.NODE_ID, rec.PARENT_ID, rec.DEPTH, rec.RULE_NAME, rec.START_POS, rec.NODE_LENGTH, rec.TEXT
             ));
  end loop;
  return;
end ParseTree;

end P_ABNF_Engine;
/

