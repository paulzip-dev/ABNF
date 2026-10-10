create or replace package P_UT_ABNF_CSV is

--%suite(ABNF CSV: validation, explanation, field extraction and writing)
--%rollback(manual)

--%test(Valid CSV is accepted)
procedure ValidateValid;

--%test(Invalid CSV is rejected)
procedure ValidateInvalid;

--%test(ValidateCsv procedure reports why CSV is invalid)
procedure ValidateProcedure;

--%test(ExplainCsv is null for valid CSV and describes the problem otherwise)
procedure Explain;

--%test(Fields come back with record and field numbers and the header flagged)
procedure ParseWithHeader;

--%test(pHasHeader N flags no header)
procedure ParseWithoutHeader;

--%test(Quoted fields: commas, doubled quotes and line breaks are kept)
procedure ParseQuoted;

--%test(IS_QUOTED and START_POS)
procedure ParseQuotedFlagAndPosition;

--%test(Empty fields are returned with a null value)
procedure ParseEmptyFields;

--%test(A line break at the very end does not start another record)
procedure ParseTrailingLineBreak;

--%test(Single line, null and blank input)
procedure ParseEdgeCases;

--%test(Invalid CSV raises an error from ParseCsv)
procedure ParseInvalidRaises;

--%test(Bad pHasHeader is rejected)
--%throws(-20131)
procedure ParseBadHeaderFlagRaises;

--%test(QuoteField quotes only when needed)
procedure QuoteFieldRules;

--%test(FormatRecord joins and quotes)
procedure FormatRecordJoins;

--%test(Written CSV is valid and reads back to the same values)
procedure RoundTrip;

--%test(NormaliseLineEndings turns LF and CR into CRLF without changing the fields)
procedure NormaliseLineEndingsMakesValid;

--%test(LF, CR and mixed line endings are read as line breaks)
procedure ParseUnixAndMacLineEndings;

--%test(Rule set is cached and contains the rules the package needs)
procedure RuleSetRules;

--%test(Records and fields are the same whatever the chunk size, including when a chunk ends inside a record)
procedure ChunkBoundaries;

--%test(A CR at the end of a chunk is not mistaken for a bare CR when an LF follows)
procedure CrLfSplitAcrossChunks;

--%test(A clob far bigger than a varchar2 is validated and parsed)
procedure LargeClob;

--%test(Errors in a later record give line numbers and positions for the whole input)
procedure ErrorLocationInLargeInput;

--%test(Line numbers in explanations count every kind of line break before the bad record)
procedure ExplainLineNumbers;

--%test(A record longer than the engine can match is reported)
--%throws(-20132)
procedure RecordTooLongValidate;

--%test(A record longer than the engine can match is reported by ParseCsv)
--%throws(-20132)
procedure RecordTooLongParse;

--%test(Chunk size must be 1 to 8000)
--%throws(-20134)
procedure BadChunkSizeRaises;

--%test(NormaliseLineEndings reads a clob in chunks)
procedure NormaliseClobInChunks;

--%aftereach
procedure ResetChunkSize;

end P_UT_ABNF_CSV;
/

create or replace package body P_UT_ABNF_CSV is

CRLF constant varchar2(2) := chr(13) || chr(10);

-- Fields as 'record.field=value' joined with '|'
function FieldsOf(pCsv varchar2, pHasHeader varchar2 default 'Y') return varchar2 is
  vResult varchar2(4000);
begin
  select listagg(f.RECORD_NO || '.' || f.FIELD_NO || '=' || f.VALUE, '|') within group (order by f.RECORD_NO, f.FIELD_NO)
  into vResult
  from table(P_ABNF_CSV.ParseCsv(pCsv, pHasHeader)) f;
  return vResult;
end FieldsOf;

-- START_POS of every field, joined with '|'
function PositionsOf(pCsv varchar2) return varchar2 is
  vResult varchar2(4000);
begin
  select listagg(f.START_POS, '|') within group (order by f.RECORD_NO, f.FIELD_NO)
  into vResult
  from table(P_ABNF_CSV.ParseCsv(pCsv)) f;
  return vResult;
end PositionsOf;

-- NormaliseLineEndings for short text, as a varchar2
function Normalised(pCsv varchar2) return varchar2 is
begin
  return dbms_lob.substr(P_ABNF_CSV.NormaliseLineEndings(pCsv), 4000, 1);
end Normalised;

-- A temporary clob holding pText repeated pTimes times
function RepeatedClob(pText varchar2, pTimes integer) return clob is
  vResult clob;
begin
  dbms_lob.createtemporary(vResult, True);
  for i in 1..pTimes
  loop
    dbms_lob.writeappend(vResult, length(pText), pText);
  end loop;
  return vResult;
end RepeatedClob;

procedure ResetChunkSize is
begin
  P_ABNF_CSV.SetReadChunkSize(null);
end ResetChunkSize;

procedure ValidateValid is
begin
  ut.expect(P_ABNF_CSV.ValidateCsv('a,b,c')).to_be_true();
  ut.expect(P_ABNF_CSV.ValidateCsv('a,b' || CRLF || '1,2')).to_be_true();
  ut.expect(P_ABNF_CSV.ValidateCsv('a,b' || CRLF || '1,2' || CRLF)).to_be_true();
  ut.expect(P_ABNF_CSV.ValidateCsv('"a,b",c')).to_be_true();
  ut.expect(P_ABNF_CSV.ValidateCsv('"line' || CRLF || 'break",x')).to_be_true();
  ut.expect(P_ABNF_CSV.ValidateCsv('"say ""hi""",x')).to_be_true();
  ut.expect(P_ABNF_CSV.ValidateCsv('a,,c')).to_be_true();
  ut.expect(P_ABNF_CSV.ValidateCsv(',')).to_be_true();
  -- Unix (LF), classic Mac OS (CR) and mixed line endings
  ut.expect(P_ABNF_CSV.ValidateCsv('a,b' || chr(10) || '1,2')).to_be_true();
  ut.expect(P_ABNF_CSV.ValidateCsv('a,b' || chr(13) || '1,2')).to_be_true();
  ut.expect(P_ABNF_CSV.ValidateCsv('a,b' || chr(10) || '1,2' || chr(13) || '3,4' || CRLF || '5,6')).to_be_true();
end ValidateValid;

procedure ValidateInvalid is
begin
  -- quote never closed
  ut.expect(P_ABNF_CSV.ValidateCsv('"abc')).to_be_false();
  -- text after a closing quote
  ut.expect(P_ABNF_CSV.ValidateCsv('a,"b"c')).to_be_false();
  -- a quote in an unquoted field
  ut.expect(P_ABNF_CSV.ValidateCsv('a,b"c')).to_be_false();
  -- a tab is not TEXTDATA
  ut.expect(P_ABNF_CSV.ValidateCsv('a' || chr(9) || 'b')).to_be_false();
end ValidateInvalid;

procedure ValidateProcedure is
  vIsValid        boolean;
  vErrorPosition  integer;
  vFailedNodeName varchar2(4000);
  vErrorMessage   varchar2(4000);
begin
  P_ABNF_CSV.ValidateCsv('a,b', vIsValid, vErrorPosition, vFailedNodeName, vErrorMessage);
  ut.expect(vIsValid).to_be_true();
  ut.expect(vErrorMessage).to_be_null();

  P_ABNF_CSV.ValidateCsv('a,b"c', vIsValid, vErrorPosition, vFailedNodeName, vErrorMessage);
  ut.expect(vIsValid).to_be_false();
  ut.expect(vErrorPosition).to_equal(4);
  ut.expect(vErrorMessage).to_be_like('Line 1, column 4:%');

  -- the position is in the whole input, not in the record
  P_ABNF_CSV.ValidateCsv('a,b' || chr(10) || 'c,d"e', vIsValid, vErrorPosition, vFailedNodeName, vErrorMessage);
  ut.expect(vIsValid).to_be_false();
  ut.expect(vErrorPosition).to_equal(8);
  ut.expect(vErrorMessage).to_be_like('Line 2, column 4:%');
end ValidateProcedure;

procedure Explain is
begin
  ut.expect(P_ABNF_CSV.ExplainCsv('a,b' || CRLF || '1,2')).to_be_null();
  ut.expect(P_ABNF_CSV.ExplainCsv('a,b' || CRLF || '1,"2')).to_be_like('Line 2, column 5: unexpected end of input%');
  ut.expect(P_ABNF_CSV.ExplainCsv('a,b' || chr(10) || '1,2')).to_be_null();
  ut.expect(P_ABNF_CSV.ExplainCsv('a,b"c')).to_be_like('Line 1, column 4:%');
end Explain;

procedure ParseWithHeader is
  vHeaderRows integer;
begin
  ut.expect(FieldsOf('name,age' || CRLF || 'Ann,30' || CRLF || '"Smith, Bob",41'))
    .to_equal('1.1=name|1.2=age|2.1=Ann|2.2=30|3.1=Smith, Bob|3.2=41');

  select count(*)
  into vHeaderRows
  from table(P_ABNF_CSV.ParseCsv('name,age' || CRLF || 'Ann,30')) f
  where f.IS_HEADER = 'Y';
  ut.expect(vHeaderRows).to_equal(2);
end ParseWithHeader;

procedure ParseWithoutHeader is
  vHeaderRows integer;
begin
  select count(*)
  into vHeaderRows
  from table(P_ABNF_CSV.ParseCsv('name,age' || CRLF || 'Ann,30', 'N')) f
  where f.IS_HEADER = 'Y';
  ut.expect(vHeaderRows).to_equal(0);
  ut.expect(FieldsOf('name,age' || CRLF || 'Ann,30', 'n')).to_equal('1.1=name|1.2=age|2.1=Ann|2.2=30');
end ParseWithoutHeader;

procedure ParseQuoted is
begin
  ut.expect(FieldsOf('"a,b",c')).to_equal('1.1=a,b|1.2=c');
  ut.expect(FieldsOf('"say ""hi""",x')).to_equal('1.1=say "hi"|1.2=x');
  ut.expect(FieldsOf('"line' || CRLF || 'break",x' || CRLF || 'y,z'))
    .to_equal('1.1=line' || CRLF || 'break|1.2=x|2.1=y|2.2=z');
  -- a quoted empty string
  ut.expect(FieldsOf('"",x')).to_equal('1.1=|1.2=x');
end ParseQuoted;

procedure ParseQuotedFlagAndPosition is
  vQuoted varchar2(1);
  vPos    integer;
begin
  select f.IS_QUOTED, f.START_POS
  into vQuoted, vPos
  from table(P_ABNF_CSV.ParseCsv('ab,"cd"')) f
  where f.FIELD_NO = 2;
  ut.expect(vQuoted).to_equal('Y');
  ut.expect(vPos).to_equal(4);

  select f.IS_QUOTED, f.START_POS
  into vQuoted, vPos
  from table(P_ABNF_CSV.ParseCsv('ab,"cd"')) f
  where f.FIELD_NO = 1;
  ut.expect(vQuoted).to_equal('N');
  ut.expect(vPos).to_equal(1);
end ParseQuotedFlagAndPosition;

procedure ParseEmptyFields is
  vNulls integer;
begin
  ut.expect(FieldsOf('a,,c')).to_equal('1.1=a|1.2=|1.3=c');

  select count(*)
  into vNulls
  from table(P_ABNF_CSV.ParseCsv('a,,c' || CRLF || ',,')) f
  where f.VALUE is null;
  ut.expect(vNulls).to_equal(4);
end ParseEmptyFields;

procedure ParseTrailingLineBreak is
begin
  ut.expect(FieldsOf('a,b' || CRLF || '1,2' || CRLF)).to_equal('1.1=a|1.2=b|2.1=1|2.2=2');
  ut.expect(FieldsOf('a,b' || CRLF || '1,2')).to_equal('1.1=a|1.2=b|2.1=1|2.2=2');
end ParseTrailingLineBreak;

procedure ParseEdgeCases is
begin
  ut.expect(FieldsOf('only,one,line')).to_equal('1.1=only|1.2=one|1.3=line');
  ut.expect(FieldsOf('x')).to_equal('1.1=x');
  ut.expect(FieldsOf(null)).to_be_null();
  -- a lone line break ends one empty record
  ut.expect(FieldsOf(chr(10))).to_equal('1.1=');
  ut.expect(P_ABNF_CSV.ValidateCsv(null)).to_be_true();
  ut.expect(P_ABNF_CSV.ExplainCsv(null)).to_be_null();
end ParseEdgeCases;

procedure ParseInvalidRaises is
  vMessage varchar2(4000);
  vResult  varchar2(4000);
begin
  begin
    vResult := FieldsOf('a,"b');
  exception
    when OTHERS then
      vMessage := SQLERRM;
  end;
  ut.expect(vMessage).to_be_like('%ORA-20121: Input does not match:%');
end ParseInvalidRaises;

procedure ParseBadHeaderFlagRaises is
  vResult varchar2(4000);
begin
  vResult := FieldsOf('a,b', 'maybe');
end ParseBadHeaderFlagRaises;

procedure QuoteFieldRules is
begin
  ut.expect(P_ABNF_CSV.QuoteField('plain')).to_equal('plain');
  ut.expect(P_ABNF_CSV.QuoteField('a,b')).to_equal('"a,b"');
  ut.expect(P_ABNF_CSV.QuoteField('say "hi"')).to_equal('"say ""hi"""');
  ut.expect(P_ABNF_CSV.QuoteField('two' || chr(10) || 'lines')).to_equal('"two' || chr(10) || 'lines"');
  ut.expect(P_ABNF_CSV.QuoteField('two' || chr(13) || 'lines')).to_equal('"two' || chr(13) || 'lines"');
  ut.expect(P_ABNF_CSV.QuoteField('  spaced  ')).to_equal('  spaced  ');
  ut.expect(P_ABNF_CSV.QuoteField(null)).to_be_null();
end QuoteFieldRules;

procedure FormatRecordJoins is
begin
  ut.expect(P_ABNF_CSV.FormatRecord(TY_ABNF_StrList('a', 'b,c', null, 'd'))).to_equal('a,"b,c",,d');
  ut.expect(P_ABNF_CSV.FormatRecord(TY_ABNF_StrList('only'))).to_equal('only');
  ut.expect(P_ABNF_CSV.FormatRecord(TY_ABNF_StrList())).to_be_null();
  ut.expect(P_ABNF_CSV.FormatRecord(null)).to_be_null();
end FormatRecordJoins;

procedure RoundTrip is
  vCsv varchar2(4000);
begin
  vCsv := P_ABNF_CSV.FormatRecord(TY_ABNF_StrList('id', 'note'))
       || CRLF || P_ABNF_CSV.FormatRecord(TY_ABNF_StrList('1', 'has, a comma'))
       || CRLF || P_ABNF_CSV.FormatRecord(TY_ABNF_StrList('2', 'has "quotes"'))
       || CRLF || P_ABNF_CSV.FormatRecord(TY_ABNF_StrList('3', 'two' || CRLF || 'lines'))
       || CRLF || P_ABNF_CSV.FormatRecord(TY_ABNF_StrList('4', null));
  ut.expect(P_ABNF_CSV.ValidateCsv(vCsv)).to_be_true();
  ut.expect(FieldsOf(vCsv))
    .to_equal('1.1=id|1.2=note|2.1=1|2.2=has, a comma|3.1=2|3.2=has "quotes"|4.1=3|4.2=two' || CRLF || 'lines|5.1=4|5.2=');
end RoundTrip;

procedure NormaliseLineEndingsMakesValid is
begin
  ut.expect(Normalised('a' || chr(10) || 'b')).to_equal('a' || CRLF || 'b');
  ut.expect(Normalised('a' || chr(13) || 'b')).to_equal('a' || CRLF || 'b');
  ut.expect(Normalised('a' || CRLF || 'b')).to_equal('a' || CRLF || 'b');
  ut.expect(Normalised('a' || chr(10) || chr(10) || 'b')).to_equal('a' || CRLF || CRLF || 'b');
  ut.expect(Normalised(null)).to_be_null();
  -- the same fields are read before and after
  ut.expect(FieldsOf(Normalised('a,b' || chr(10) || '1,2'))).to_equal(FieldsOf('a,b' || chr(10) || '1,2'));
  ut.expect(P_ABNF_CSV.ValidateCsv(P_ABNF_CSV.NormaliseLineEndings('a,b' || chr(10) || '1,2'))).to_be_true();
end NormaliseLineEndingsMakesValid;

procedure ParseUnixAndMacLineEndings is
begin
  ut.expect(FieldsOf('a,b' || chr(10) || '1,2' || chr(10))).to_equal('1.1=a|1.2=b|2.1=1|2.2=2');
  ut.expect(FieldsOf('a,b' || chr(13) || '1,2' || chr(13))).to_equal('1.1=a|1.2=b|2.1=1|2.2=2');
  -- mixed; CR LF is one line break, not two
  ut.expect(FieldsOf('a' || chr(13) || chr(10) || 'b' || chr(10) || 'c' || chr(13) || 'd')).to_equal('1.1=a|2.1=b|3.1=c|4.1=d');
  -- a line break inside quotes is kept as written
  ut.expect(FieldsOf('"x' || chr(10) || 'y",z' || chr(10) || '1,2')).to_equal('1.1=x' || chr(10) || 'y|1.2=z|2.1=1|2.2=2');
  -- a blank line is an empty record
  ut.expect(FieldsOf('a' || chr(10) || chr(10) || 'b')).to_equal('1.1=a|2.1=|3.1=b');
end ParseUnixAndMacLineEndings;

procedure RuleSetRules is
  vRules TY_ABNF_RuleSet := P_ABNF_CSV.GetCsvRuleSet();
  vNames varchar2(4000);
begin
  for i in 1..vRules.count
  loop
    vNames := vNames || ',' || lower(vRules(i).RULE_NAME) || ',';
  end loop;
  for rec in (
    select column_value as RULE_NAME
    from table(TY_ABNF_StrList('file', 'header', 'record', 'name', 'field', 'escaped'))
  )
  loop
    ut.expect(instr(vNames, ',' || rec.RULE_NAME || ','), 'rule ' || rec.RULE_NAME || ' is defined').to_be_greater_than(0);
  end loop;
end RuleSetRules;

procedure ChunkBoundaries is
  -- doubled quotes, an LF and a CR inside/after quotes, CRLF, a blank line and a trailing break
  vCsv      varchar2(4000) := 'id,note' || CRLF
                           || '1,"say ""hi"", ok"' || CRLF
                           || '2,"two' || chr(10) || 'lines"' || chr(13)
                           || '3,' || chr(10) || chr(10)
                           || '4,end' || CRLF;
  vExpected varchar2(4000) := '1.1=id|1.2=note|2.1=1|2.2=say "hi", ok|3.1=2|3.2=two' || chr(10) || 'lines|4.1=3|4.2=|5.1=|6.1=4|6.2=end';
  vPositions varchar2(4000) := PositionsOf(vCsv);
begin
  ut.expect(FieldsOf(vCsv), 'default chunk size').to_equal(vExpected);
  for vSize in 1..20
  loop
    P_ABNF_CSV.SetReadChunkSize(vSize);
    ut.expect(FieldsOf(vCsv), 'fields, chunk size ' || vSize).to_equal(vExpected);
    ut.expect(PositionsOf(vCsv), 'positions, chunk size ' || vSize).to_equal(vPositions);
    ut.expect(P_ABNF_CSV.ValidateCsv(vCsv), 'valid, chunk size ' || vSize).to_be_true();
  end loop;
end ChunkBoundaries;

procedure CrLfSplitAcrossChunks is
begin
  -- 'a' CR LF 'b': chunk size 2 ends with the CR; the LF belongs to the same line break
  P_ABNF_CSV.SetReadChunkSize(2);
  ut.expect(FieldsOf('a' || CRLF || 'b')).to_equal('1.1=a|2.1=b');
  -- a bare CR at the end of the whole input is a line break, not the start of CR LF
  ut.expect(FieldsOf('a' || chr(13))).to_equal('1.1=a');
  ut.expect(FieldsOf('a' || chr(13) || chr(13) || 'b')).to_equal('1.1=a|2.1=|3.1=b');
end CrLfSplitAcrossChunks;

procedure LargeClob is
  vCsv     clob := RepeatedClob('7,"a, b' || CRLF || 'c",z' || CRLF, 2000);
  vFields  integer;
  vRecords integer;
begin
  ut.expect(dbms_lob.getlength(vCsv), 'bigger than a varchar2').to_be_greater_than(32767);
  ut.expect(P_ABNF_CSV.ValidateCsv(vCsv)).to_be_true();

  select count(*), max(f.RECORD_NO)
  into vFields, vRecords
  from table(P_ABNF_CSV.ParseCsv(vCsv, 'N')) f;
  ut.expect(vFields).to_equal(6000);
  ut.expect(vRecords).to_equal(2000);

  dbms_lob.freetemporary(vCsv);
end LargeClob;

procedure ErrorLocationInLargeInput is
  vCsv clob := RepeatedClob('7,"a, b' || CRLF || 'c",z' || CRLF, 2000);
  vBad varchar2(10) := 'x,"y';
begin
  dbms_lob.writeappend(vCsv, length(vBad), vBad);
  ut.expect(P_ABNF_CSV.ValidateCsv(vCsv)).to_be_false();
  -- 2000 records of two lines each, so the bad record is on line 4001
  ut.expect(P_ABNF_CSV.ExplainCsv(vCsv)).to_be_like('Line 4001, column 5: unexpected end of input%');
  dbms_lob.freetemporary(vCsv);
end ErrorLocationInLargeInput;

procedure ExplainLineNumbers is
begin
  -- line 1 ends with LF, line 2 with CR LF, then the bad record starts on line 3 and runs on to line 4
  ut.expect(P_ABNF_CSV.ExplainCsv('a,b' || chr(10) || '1,2' || CRLF || '3,"4' || chr(10) || '5'))
    .to_be_like('Line 4, column 2: unexpected end of input%');
  -- bare CR line breaks count too
  ut.expect(P_ABNF_CSV.ExplainCsv('a,b' || chr(13) || '1,2' || chr(13) || '3,x"y'))
    .to_be_like('Line 3, column 4:%');
end ExplainLineNumbers;

procedure RecordTooLongValidate is
  vCsv    clob := RepeatedClob(rpad('x', 4000, 'x'), 10);
  vResult boolean;
begin
  vResult := P_ABNF_CSV.ValidateCsv(vCsv);
end RecordTooLongValidate;

procedure RecordTooLongParse is
  vCsv   clob := RepeatedClob(rpad('x', 4000, 'x'), 10);
  vCount integer;
begin
  select count(*) into vCount from table(P_ABNF_CSV.ParseCsv(vCsv));
end RecordTooLongParse;

procedure BadChunkSizeRaises is
begin
  P_ABNF_CSV.SetReadChunkSize(0);
end BadChunkSizeRaises;

procedure NormaliseClobInChunks is
  vIn  varchar2(100) := 'a' || chr(13) || 'b' || chr(10) || 'c' || CRLF || 'd' || chr(13);
  vOut varchar2(100) := 'a' || CRLF || 'b' || CRLF || 'c' || CRLF || 'd' || CRLF;
begin
  for vSize in 1..12
  loop
    P_ABNF_CSV.SetReadChunkSize(vSize);
    ut.expect(Normalised(vIn), 'chunk size ' || vSize).to_equal(vOut);
  end loop;
end NormaliseClobInChunks;

end P_UT_ABNF_CSV;
/
