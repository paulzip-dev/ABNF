--------------------------------------------------------------------------------
-- Package Specification: P_ABNF_CSV
--
-- CSV (RFC 4180) on top of P_ABNF_Engine. The grammar is held as a rule set (see GetRuleSet in the body), so
-- changing what counts as valid CSV means changing the grammar, not this package.
-- Records may end with CRLF, LF or CR (RFC 4180 itself only allows CRLF); the three may be mixed in one file.
--
-- The grammar must define these rules (as RFC 4180 does): file, header, record, name, field, escaped.
--------------------------------------------------------------------------------
create or replace
package P_ABNF_CSV is

-- The CSV rule set. Built once per session.
function GetCsvRuleSet return TY_ABNF_RuleSet;

-- All the routines that read CSV take a clob (a varchar2 converts implicitly). The text is read in chunks and cut
-- into records, and the grammar's record rule is matched one record at a time, so memory use depends on the
-- longest record, not the size of the input. A record, including the line break inside any quoted field, must
-- fit in the 32K the engine can match (a little less in a multibyte character set); a longer one raises ORA-20132.
-- Null or empty input is valid and has no records.
function ValidateCsv(pCsv clob) return boolean;

procedure ValidateCsv(
            pCsv            in  clob
          , pIsValid        out boolean
          , pErrorPosition  out integer
          , pFailedNodeName out varchar2
          , pErrorMessage   out varchar2
          );

-- Why pCsv is not valid CSV, e.g. 'Line 3, column 7: unexpected end of input, ...'; null if it is valid.
-- Line numbers count from the start of pCsv; the error position is a character offset into pCsv.
function ExplainCsv(pCsv clob) return varchar2;

-- Every field, in order, with its record and field number. Needs valid CSV (raises ORA-20121 otherwise;
-- use ExplainCsv to find out why). Rows are produced as the input is read, so a large file can be streamed.
--   pHasHeader 'Y' marks the first record as the header (IS_HEADER = 'Y'); 'N' means there is none.
-- A single line break at the very end of the input ends the last record; it does not start another.
-- Empty fields are returned, with a null VALUE. Raises ORA-20131 if pHasHeader is not 'Y' or 'N'.
-- START_POS is a character offset into pCsv. A value is cut to 4000 characters.
function ParseCsv(
           pCsv       clob
         , pHasHeader varchar2 default 'Y'
         ) return TY_ABNF_CsvFieldList pipelined;

-- How many characters are read from the clob at a time (default 4000, 1 to 8000). Only affects speed and the
-- longest record that fits; the tests set it very small to put chunk boundaries inside records. Null restores
-- the default. Applies to the current session.
procedure SetReadChunkSize(pChars integer);

-- pValue as a CSV field: in double quotes (with " doubled) if it holds a comma, a double quote or a line break
function QuoteField(pValue varchar2) return varchar2;

-- One record's worth of values joined with commas, quoted where needed. No line break is added.
function FormatRecord(pValues TY_ABNF_StrList) return varchar2;

-- Validation accepts CRLF, LF and CR, so this is not needed to read a file. Use it to write strict RFC 4180:
-- it turns bare LF, bare CR and CRLF all into CRLF. Line breaks inside quoted fields are changed too.
-- Returns a temporary clob (freed with the call), built chunk by chunk; null for null input.
function NormaliseLineEndings(pCsv clob) return clob;

end P_ABNF_CSV;
/

--------------------------------------------------------------------------------
-- Package Body: P_ABNF_CSV
--------------------------------------------------------------------------------
create or replace
package body P_ABNF_CSV is

CR  constant varchar2(1) := chr(13);
LF  constant varchar2(1) := chr(10);

-- Names of the rules this package relies on
RULE_FILE    constant varchar2(30) := 'file';
RULE_HEADER  constant varchar2(30) := 'header';
RULE_RECORD  constant varchar2(30) := 'record';
RULE_FIELD   constant varchar2(30) := 'field';
RULE_ESCAPED constant varchar2(30) := 'escaped';

QUOTE constant varchar2(1) := '"';

-- Most characters read from the clob at a time. 8000 characters can be 32000 bytes, which still fits a varchar2.
DEFAULT_CHUNK constant pls_integer := 4000;
MAX_CHUNK     constant pls_integer := 8000;
-- The engine matches a varchar2, so a record cannot be longer than this many bytes
MAX_RECORD    constant pls_integer := 32767;

gRuleSet   TY_ABNF_RuleSet;
gChunkSize pls_integer := DEFAULT_CHUNK;

-- Where reading a clob has got to. Buf holds the record being read (from Strt) and whatever follows it in the
-- last chunk; Scan is how far Buf has been searched for the end of the record.
type TReader is record (
  Buf      varchar2(32767)
, Strt     pls_integer := 1
, Scan     pls_integer := 1
, Base     integer     := 1         -- clob offset of Buf(1)
, ReadPos  integer     := 1         -- next clob offset to read
, TotalLen integer     := 0
, Eof      boolean     := True      -- everything has been read into Buf
, InQuote  boolean     := False
, RecordNo integer     := 0
, Lines    integer     := 0         -- line breaks in the records handed out so far
);

------------------------------------------------------------------------------
-- STUB: replace the body of this function with the CSV rule set.
-- Either paste the function generated by P_ABNF_Engine.GeneratePLSQLFromABNF over this one (it is also called
-- GetRuleSet), or keep the function and put the grammar text in it. This version holds the RFC 4180 grammar.
------------------------------------------------------------------------------
function GetRuleSet return TY_ABNF_RuleSet is
begin
--  return P_ABNF_Engine.ParseGrammar(
--           'file = [header NEWLINE] record *(NEWLINE record) [NEWLINE]' || LF
--        || 'header = name *(COMMA name)' || LF
--        || 'record = field *(COMMA field)' || LF
--        || 'name = field' || LF
--        || 'field = (escaped / non-escaped)' || LF
--        || 'escaped = DQUOTE *(TEXTDATA / COMMA / CR / LF / 2DQUOTE) DQUOTE' || LF
--        || 'non-escaped = *TEXTDATA' || LF
--        || 'COMMA = %x2C' || LF
--        || 'CR = %x0D' || LF
--        || 'DQUOTE = %x22' || LF
--        || 'LF = %x0A' || LF
--        || '; RFC 4180 only allows CRLF; LF (Unix) and CR (classic Mac OS) are accepted as well' || LF
--        || 'NEWLINE = CR LF / LF / CR' || LF
--        || 'TEXTDATA = %x20-21 / %x23-2B / %x2D-7E'
--         );
-- Generated by P_ABNF_Engine.GeneratePLSQLFromABNF
  return TY_ABNF_RuleSet(
    TY_ABNF_Rule(
      RULE_NAME    => 'file'
    , COMMENT_TEXT => null
    , RULE_NODE    => TY_ABNF_Sequence(
        NODE_NAME   => 'file'
      , CHILD_NODES => TY_ABNF_NodeList(
          TY_ABNF_Repetition(
            NODE_NAME  => null
          , MIN_OCCURS => 0
          , MAX_OCCURS => 1
          , CHILD_NODE => TY_ABNF_Sequence(
              NODE_NAME   => null
            , CHILD_NODES => TY_ABNF_NodeList(
                TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'header')
              , TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'NEWLINE')
              )
            )
          )
        , TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'record')
        , TY_ABNF_Repetition(
            NODE_NAME  => null
          , MIN_OCCURS => 0
          , MAX_OCCURS => null
          , CHILD_NODE => TY_ABNF_Sequence(
              NODE_NAME   => null
            , CHILD_NODES => TY_ABNF_NodeList(
                TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'NEWLINE')
              , TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'record')
              )
            )
          )
        , TY_ABNF_Repetition(
            NODE_NAME  => null
          , MIN_OCCURS => 0
          , MAX_OCCURS => 1
          , CHILD_NODE => TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'NEWLINE')
          )
        )
      )
    )
  , TY_ABNF_Rule(
      RULE_NAME    => 'header'
    , COMMENT_TEXT => null
    , RULE_NODE    => TY_ABNF_Sequence(
        NODE_NAME   => 'header'
      , CHILD_NODES => TY_ABNF_NodeList(
          TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'name')
        , TY_ABNF_Repetition(
            NODE_NAME  => null
          , MIN_OCCURS => 0
          , MAX_OCCURS => null
          , CHILD_NODE => TY_ABNF_Sequence(
              NODE_NAME   => null
            , CHILD_NODES => TY_ABNF_NodeList(
                TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'COMMA')
              , TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'name')
              )
            )
          )
        )
      )
    )
  , TY_ABNF_Rule(
      RULE_NAME    => 'record'
    , COMMENT_TEXT => null
    , RULE_NODE    => TY_ABNF_Sequence(
        NODE_NAME   => 'record'
      , CHILD_NODES => TY_ABNF_NodeList(
          TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'field')
        , TY_ABNF_Repetition(
            NODE_NAME  => null
          , MIN_OCCURS => 0
          , MAX_OCCURS => null
          , CHILD_NODE => TY_ABNF_Sequence(
              NODE_NAME   => null
            , CHILD_NODES => TY_ABNF_NodeList(
                TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'COMMA')
              , TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'field')
              )
            )
          )
        )
      )
    )
  , TY_ABNF_Rule(
      RULE_NAME    => 'name'
    , COMMENT_TEXT => null
    , RULE_NODE    => TY_ABNF_RuleRef(NODE_NAME => 'name', RULE_NAME => 'field')
    )
  , TY_ABNF_Rule(
      RULE_NAME    => 'field'
    , COMMENT_TEXT => null
    , RULE_NODE    => TY_ABNF_Alternative(
        NODE_NAME   => 'field'
      , CHILD_NODES => TY_ABNF_NodeList(
          TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'escaped')
        , TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'non-escaped')
        )
      )
    )
  , TY_ABNF_Rule(
      RULE_NAME    => 'escaped'
    , COMMENT_TEXT => null
    , RULE_NODE    => TY_ABNF_Sequence(
        NODE_NAME   => 'escaped'
      , CHILD_NODES => TY_ABNF_NodeList(
          TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'DQUOTE')
        , TY_ABNF_Repetition(
            NODE_NAME  => null
          , MIN_OCCURS => 0
          , MAX_OCCURS => null
          , CHILD_NODE => TY_ABNF_Alternative(
              NODE_NAME   => null
            , CHILD_NODES => TY_ABNF_NodeList(
                TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'TEXTDATA')
              , TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'COMMA')
              , TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'CR')
              , TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'LF')
              , TY_ABNF_Repetition(
                  NODE_NAME  => null
                , MIN_OCCURS => 2
                , MAX_OCCURS => 2
                , CHILD_NODE => TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'DQUOTE')
                )
              )
            )
          )
        , TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'DQUOTE')
        )
      )
    )
  , TY_ABNF_Rule(
      RULE_NAME    => 'non-escaped'
    , COMMENT_TEXT => null
    , RULE_NODE    => TY_ABNF_Repetition(
        NODE_NAME  => 'non-escaped'
      , MIN_OCCURS => 0
      , MAX_OCCURS => null
      , CHILD_NODE => TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'TEXTDATA')
      )
    )
  , TY_ABNF_Rule(
      RULE_NAME    => 'COMMA'
    , COMMENT_TEXT => null
    , RULE_NODE    => TY_ABNF_Literal(NODE_NAME => 'COMMA', VALUE => ',', CASE_SENSITIVE => 'Y')
    )
  , TY_ABNF_Rule(
      RULE_NAME    => 'CR'
    , COMMENT_TEXT => null
    , RULE_NODE    => TY_ABNF_Literal(NODE_NAME => 'CR', VALUE => chr(13), CASE_SENSITIVE => 'Y')
    )
  , TY_ABNF_Rule(
      RULE_NAME    => 'DQUOTE'
    , COMMENT_TEXT => null
    , RULE_NODE    => TY_ABNF_Literal(NODE_NAME => 'DQUOTE', VALUE => '"', CASE_SENSITIVE => 'Y')
    )
  , TY_ABNF_Rule(
      RULE_NAME    => 'LF'
    , COMMENT_TEXT => null
    , RULE_NODE    => TY_ABNF_Literal(NODE_NAME => 'LF', VALUE => chr(10), CASE_SENSITIVE => 'Y')
    )
    -- RFC 4180 only allows CRLF; LF (Unix) and CR (classic Mac OS) are accepted as well
  , TY_ABNF_Rule(
      RULE_NAME    => 'NEWLINE'
    , COMMENT_TEXT => 'RFC 4180 only allows CRLF; LF (Unix) and CR (classic Mac OS) are accepted as well'
    , RULE_NODE    => TY_ABNF_Alternative(
        NODE_NAME   => 'NEWLINE'
      , CHILD_NODES => TY_ABNF_NodeList(
          TY_ABNF_Sequence(
            NODE_NAME   => null
          , CHILD_NODES => TY_ABNF_NodeList(
              TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'CR')
            , TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'LF')
            )
          )
        , TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'LF')
        , TY_ABNF_RuleRef(NODE_NAME => null, RULE_NAME => 'CR')
        )
      )
    )
  , TY_ABNF_Rule(
      RULE_NAME    => 'TEXTDATA'
    , COMMENT_TEXT => null
    , RULE_NODE    => TY_ABNF_Alternative(
        NODE_NAME   => 'TEXTDATA'
      , CHILD_NODES => TY_ABNF_NodeList(
          TY_ABNF_Range(NODE_NAME => null, MIN_CODE => 32, MAX_CODE => 33)
        , TY_ABNF_Range(NODE_NAME => null, MIN_CODE => 35, MAX_CODE => 43)
        , TY_ABNF_Range(NODE_NAME => null, MIN_CODE => 45, MAX_CODE => 126)
        )
      )
    )
  );
end GetRuleSet;

function GetCsvRuleSet return TY_ABNF_RuleSet is
begin
  if gRuleSet is null then
    gRuleSet := GetRuleSet();
  end if;
  return gRuleSet;
end GetCsvRuleSet;

------------------------------------------------------------------------------
-- Validation
------------------------------------------------------------------------------
procedure SetReadChunkSize(pChars integer) is
begin
  if pChars is not null and pChars not between 1 and MAX_CHUNK then
    raise_application_error(-20134, 'The chunk size must be between 1 and ' || MAX_CHUNK);
  end if;
  gChunkSize := nvl(pChars, DEFAULT_CHUNK);
end SetReadChunkSize;

------------------------------------------------------------------------------
-- Reading a clob one record at a time
--
-- A record ends at a CR, LF or CR LF that is not inside quotes. Whether a character is inside quotes only needs
-- the quotes counted (a doubled quote closes and reopens), so the cut is decided without the grammar and the
-- grammar then checks each record. Quotes that are not balanced swallow the rest of the input into one record,
-- which the grammar then rejects, so the cut cannot make invalid CSV look valid.
------------------------------------------------------------------------------
function OpenReader(pCsv clob) return TReader is
  vReader TReader;
begin
  vReader.TotalLen := nvl(dbms_lob.getlength(pCsv), 0);
  vReader.Eof      := vReader.TotalLen = 0;
  return vReader;
end OpenReader;

-- Reads the next chunk onto the end of Buf, first dropping the records already handed out
procedure FillBuffer(
            pCsv    in            clob
          , pReader in out nocopy TReader
          ) is
  vAmount pls_integer;
  vChunk  varchar2(32767);
begin
  if pReader.Strt > 1 then
    pReader.Buf   := substr(pReader.Buf, pReader.Strt);
    pReader.Base  := pReader.Base + pReader.Strt - 1;
    pReader.Scan  := pReader.Scan - pReader.Strt + 1;
    pReader.Strt  := 1;
  end if;

  vAmount := least(gChunkSize, pReader.TotalLen - pReader.ReadPos + 1);
  dbms_lob.read(pCsv, vAmount, pReader.ReadPos, vChunk);

  if nvl(lengthb(pReader.Buf), 0) + nvl(lengthb(vChunk), 0) > MAX_RECORD then
    raise_application_error(
      -20132
    , 'Record ' || (pReader.RecordNo + 1) || ' (starting at line ' || (pReader.Lines + 1)
      || ') is too long to match: the limit is about ' || MAX_RECORD || ' bytes'
    );
  end if;

  pReader.Buf     := pReader.Buf || vChunk;
  pReader.ReadPos := pReader.ReadPos + vAmount;
  pReader.Eof     := pReader.ReadPos > pReader.TotalLen;
end FillBuffer;

-- The next record, without the line break that ended it. pStartPos is its offset in the clob and pStartLine
-- its line number (a record always starts at the start of a line). pFound is false when there are no more.
-- A line break at the very end of the input only ends the last record; it does not start another.
procedure NextRecord(
            pCsv       in            clob
          , pReader    in out nocopy TReader
          , pRecord    out           varchar2
          , pStartPos  out           integer
          , pStartLine out           integer
          , pFound     out           boolean
          ) is
  NONE constant pls_integer := 1000000;
  vLen      pls_integer;
  vQuote    pls_integer;
  vLfPos    pls_integer;
  vCrPos    pls_integer;
  vPos      pls_integer;
  vEnd      pls_integer;   -- last character of the record, in Buf
  vNext     pls_integer;   -- first character after the line break, in Buf
  vDone     boolean := False;
  vNeedMore boolean;
  vText     varchar2(32767);
begin
  pFound := False;

  while not vDone
  loop
    vLen      := nvl(length(pReader.Buf), 0);
    vNeedMore := False;

    while not vDone and not vNeedMore
    loop
      if pReader.Scan > vLen then
        vNeedMore := True;
      elsif pReader.InQuote then
        vQuote := instr(pReader.Buf, QUOTE, pReader.Scan);
        if vQuote = 0 then
          pReader.Scan := vLen + 1;
        else
          pReader.InQuote := False;
          pReader.Scan    := vQuote + 1;
        end if;
      else
        vQuote := instr(pReader.Buf, QUOTE, pReader.Scan);
        vLfPos := instr(pReader.Buf, LF, pReader.Scan);
        vCrPos := instr(pReader.Buf, CR, pReader.Scan);
        vPos   := least(
                    case when vQuote = 0 then NONE else vQuote end
                  , case when vLfPos = 0 then NONE else vLfPos end
                  , case when vCrPos = 0 then NONE else vCrPos end
                  );
        if vPos = NONE then
          pReader.Scan := vLen + 1;
        elsif vPos = vQuote then
          pReader.InQuote := True;
          pReader.Scan    := vPos + 1;
        elsif vPos = vLfPos then
          vEnd  := vPos - 1;
          vNext := vPos + 1;
          vDone := True;
        elsif vPos = vLen and not pReader.Eof then
          -- a CR in the last position may be the first half of CR LF: read on before deciding
          vNeedMore := True;
        else
          vEnd  := vPos - 1;
          vNext := case when substr(pReader.Buf, vPos + 1, 1) = LF then vPos + 2 else vPos + 1 end;
          vDone := True;
        end if;
      end if;
    end loop;

    if not vDone then
      if not pReader.Eof then
        FillBuffer(pCsv, pReader);
      elsif pReader.Strt <= vLen then
        -- end of input: what is left is the last record (if quotes are still open the grammar will reject it)
        vEnd  := vLen;
        vNext := vLen + 1;
        vDone := True;
      else
        exit;
      end if;
    end if;
  end loop;

  if vDone then
    pRecord    := substr(pReader.Buf, pReader.Strt, vEnd - pReader.Strt + 1);
    pStartPos  := pReader.Base + pReader.Strt - 1;
    pStartLine := pReader.Lines + 1;

    pReader.RecordNo := pReader.RecordNo + 1;
    if instr(pRecord, LF) > 0 or instr(pRecord, CR) > 0 then
      vText := replace(replace(pRecord, CR || LF, LF), CR, LF);
      pReader.Lines := pReader.Lines + length(vText) - nvl(length(replace(vText, LF)), 0);
    end if;
    pReader.Lines := pReader.Lines + 1;
    pReader.Strt  := vNext;
    pReader.Scan  := vNext;
    pFound        := True;
  end if;
end NextRecord;

-- pMessage from the engine for one record has line numbers counted from that record: make them the file's
function WholeFileMessage(
           pMessage   varchar2
         , pStartLine integer
         ) return varchar2 is
  vLine   integer := to_number(regexp_substr(pMessage, '^Line ([0-9]+),', 1, 1, null, 1));
  vResult varchar2(32767) := pMessage;
begin
  if vLine is not null then
    vResult := 'Line ' || (vLine + pStartLine - 1) || substr(pMessage, instr(pMessage, ','));
  end if;
  return vResult;
end WholeFileMessage;

------------------------------------------------------------------------------
-- Validation: the first record that does not match, if any
------------------------------------------------------------------------------
procedure FindProblem(
            pCsv            in  clob
          , pIsValid        out boolean
          , pErrorPosition  out integer
          , pFailedNodeName out varchar2
          , pErrorMessage   out varchar2
          ) is
  vReader    TReader := OpenReader(pCsv);
  vRecord    varchar2(32767);
  vStartPos  integer;
  vStartLine integer;
  vFound     boolean;
  vIsValid   boolean;
  vPosition  integer;
begin
  pIsValid        := True;
  pErrorPosition  := null;
  pFailedNodeName := null;
  pErrorMessage   := null;

  loop
    NextRecord(pCsv, vReader, vRecord, vStartPos, vStartLine, vFound);
    exit when not vFound;

    P_ABNF_Engine.ValidateInput(
      pRules          => GetCsvRuleSet()
    , pStartRule      => RULE_RECORD
    , pInput          => vRecord
    , pIsValid        => vIsValid
    , pErrorPosition  => vPosition
    , pFailedNodeName => pFailedNodeName
    , pErrorMessage   => pErrorMessage
    );

    if not vIsValid then
      pIsValid       := False;
      pErrorPosition := vPosition + vStartPos - 1;
      pErrorMessage  := WholeFileMessage(pErrorMessage, vStartLine);
      exit;
    end if;
  end loop;
end FindProblem;

function ValidateCsv(pCsv clob) return boolean is
  vIsValid        boolean;
  vErrorPosition  integer;
  vFailedNodeName varchar2(4000);
  vErrorMessage   varchar2(4000);
begin
  FindProblem(pCsv, vIsValid, vErrorPosition, vFailedNodeName, vErrorMessage);
  return vIsValid;
end ValidateCsv;

procedure ValidateCsv(
            pCsv            in  clob
          , pIsValid        out boolean
          , pErrorPosition  out integer
          , pFailedNodeName out varchar2
          , pErrorMessage   out varchar2
          ) is
begin
  FindProblem(pCsv, pIsValid, pErrorPosition, pFailedNodeName, pErrorMessage);
end ValidateCsv;

function ExplainCsv(pCsv clob) return varchar2 is
  vIsValid        boolean;
  vErrorPosition  integer;
  vFailedNodeName varchar2(4000);
  vErrorMessage   varchar2(4000);
begin
  FindProblem(pCsv, vIsValid, vErrorPosition, vFailedNodeName, vErrorMessage);
  return vErrorMessage;
end ExplainCsv;

------------------------------------------------------------------------------
-- ParseCsv
-- Each record is parsed with the header or record rule. The parse tree lists a record's fields in order, and a
-- quoted field is one followed by an escaped node whose parent it is.
------------------------------------------------------------------------------
function RecordTree(
           pRecord    varchar2
         , pRule      varchar2
         , pStartLine integer
         ) return TY_ABNF_ParseNodeList is
  vTree    TY_ABNF_ParseNodeList;
  vMessage varchar2(32767);
begin
  select TY_ABNF_ParseNode(t.NODE_ID, t.PARENT_ID, t.DEPTH, t.RULE_NAME, t.START_POS, t.NODE_LENGTH, t.TEXT)
  bulk collect into vTree
  from table(P_ABNF_Engine.ParseTree(GetCsvRuleSet(), pRule, pRecord)) t
  order by t.NODE_ID;
  return vTree;
exception
  when OTHERS then
    -- say where in the whole input the record is
    vMessage := regexp_substr(SQLERRM, 'Line [0-9]+, .*', 1, 1, 'n');
    if SQLCODE = -20121 and vMessage is not null then
      raise_application_error(-20121, 'Input does not match: ' || WholeFileMessage(vMessage, pStartLine));
    end if;
    raise;
end RecordTree;

function ParseCsv(
           pCsv       clob
         , pHasHeader varchar2 default 'Y'
         ) return TY_ABNF_CsvFieldList pipelined is
  vHasHeader varchar2(1) := upper(nvl(pHasHeader, 'Y'));
  vReader    TReader;
  vRecord    varchar2(32767);
  vStartPos  integer;
  vStartLine integer;
  vFound     boolean;
  vTree      TY_ABNF_ParseNodeList;
  vNode      TY_ABNF_ParseNode;
  vFieldNo   integer;
  vQuoted    boolean;
  vRaw       varchar2(32767);
  vValue     varchar2(32767);
begin
  if vHasHeader not in ('Y', 'N') then
    raise_application_error(-20131, 'pHasHeader must be ''Y'' or ''N''');
  end if;

  vReader := OpenReader(pCsv);
  loop
    NextRecord(pCsv, vReader, vRecord, vStartPos, vStartLine, vFound);
    exit when not vFound;

    vTree := RecordTree(
               vRecord
             , case when vReader.RecordNo = 1 and vHasHeader = 'Y' then RULE_HEADER else RULE_RECORD end
             , vStartLine
             );
    vFieldNo := 0;

    for i in 1..vTree.count
    loop
      vNode := vTree(i);
      if lower(vNode.RULE_NAME) = RULE_FIELD then
        vFieldNo := vFieldNo + 1;
        vQuoted  := i < vTree.count
                    and lower(vTree(i + 1).RULE_NAME) = RULE_ESCAPED
                    and vTree(i + 1).PARENT_ID = vNode.NODE_ID;
        vRaw     := substr(vRecord, vNode.START_POS, vNode.NODE_LENGTH);
        if vQuoted then
          vValue := replace(substr(vRaw, 2, length(vRaw) - 2), '""', '"');
        else
          vValue := vRaw;
        end if;

        pipe row(TY_ABNF_CsvField(
                   vReader.RecordNo
                 , vFieldNo
                 , case when vHasHeader = 'Y' and vReader.RecordNo = 1 then 'Y' else 'N' end
                 , case when vQuoted then 'Y' else 'N' end
                 , vStartPos + vNode.START_POS - 1
                 , substr(vValue, 1, 4000)
                 ));
      end if;
    end loop;
  end loop;

  return;
end ParseCsv;

------------------------------------------------------------------------------
-- Writing CSV
------------------------------------------------------------------------------
function QuoteField(pValue varchar2) return varchar2 is
  vResult varchar2(32767) := pValue;
begin
  if pValue is not null
     and (instr(pValue, ',') > 0 or instr(pValue, '"') > 0 or instr(pValue, CR) > 0 or instr(pValue, LF) > 0) then
    vResult := '"' || replace(pValue, '"', '""') || '"';
  end if;
  return vResult;
end QuoteField;

function FormatRecord(pValues TY_ABNF_StrList) return varchar2 is
  vResult varchar2(32767);
begin
  if pValues is not null then
    for i in 1..pValues.count
    loop
      vResult := vResult || case when i > 1 then ',' end || QuoteField(pValues(i));
    end loop;
  end if;
  return vResult;
end FormatRecord;

function NormaliseLineEndings(pCsv clob) return clob is
  vResult clob;
  vLen    integer := nvl(dbms_lob.getlength(pCsv), 0);
  vPos    integer := 1;
  vAmount pls_integer;
  vChunk  varchar2(32767);
  vText   varchar2(32767);
  vCarry  varchar2(1);   -- a CR at the end of a chunk, held back until the next shows whether an LF follows
begin
  if pCsv is not null then
    dbms_lob.createtemporary(vResult, True, dbms_lob.call);
    while vPos <= vLen
    loop
      vAmount := least(gChunkSize, vLen - vPos + 1);
      dbms_lob.read(pCsv, vAmount, vPos, vChunk);
      vPos   := vPos + vAmount;
      vText  := vCarry || vChunk;
      vCarry := null;
      if vPos <= vLen and substr(vText, -1) = CR then
        vCarry := CR;
        vText  := substr(vText, 1, length(vText) - 1);
      end if;
      vText := replace(replace(replace(vText, CR || LF, LF), CR, LF), LF, CR || LF);
      if vText is not null then
        dbms_lob.writeappend(vResult, length(vText), vText);
      end if;
    end loop;
  end if;
  return vResult;
end NormaliseLineEndings;

end P_ABNF_CSV;
/

