set serveroutput on size unlimited

-- Sample CSV for trying out P_ABNF_CSV. Each sample says whether it should be valid.
-- <CR> and <LF> in the text below are replaced by real line breaks before testing.
declare
  vCount integer := 0;

  procedure Try(pName varchar2, pExpectValid boolean, pCsv varchar2) is
    vCsv     varchar2(4000) := replace(replace(pCsv, '<CR>', chr(13)), '<LF>', chr(10));
    vIsValid boolean := P_ABNF_CSV.ValidateCsv(vCsv);
  begin
    vCount := vCount + 1;
    dbms_output.put_line(
      rpad(to_char(vCount) || '. ' || pName, 46)
      || case when vIsValid = pExpectValid then 'ok   ' else 'WRONG' end
      || '  valid=' || case when vIsValid then 'yes' else 'no ' end
    );
    if vIsValid then
      for rec in (
        select f.RECORD_NO, f.FIELD_NO, f.IS_HEADER, f.IS_QUOTED, f.VALUE
        from table(P_ABNF_CSV.ParseCsv(vCsv)) f
        order by f.RECORD_NO, f.FIELD_NO
      )
      loop
        dbms_output.put_line(
          '     ' || rec.RECORD_NO || '.' || rec.FIELD_NO
          || case when rec.IS_HEADER = 'Y' then ' [header]' end
          || case when rec.IS_QUOTED = 'Y' then ' [quoted]' end
          || '  ' || nvl(replace(replace(rec.VALUE, chr(13), '<CR>'), chr(10), '<LF>'), '(null)')
        );
      end loop;
    else
      dbms_output.put_line('     ' || P_ABNF_CSV.ExplainCsv(vCsv));
    end if;
  end Try;
begin
  dbms_output.put_line('--- Valid ---');
  Try('simple, with header',            True, 'name,age,city<CR><LF>Ann,34,Leeds<CR><LF>Bob,41,York');
  Try('Windows line endings, trailing', True, 'a,b<CR><LF>1,2<CR><LF>');
  Try('Unix line endings',              True, 'a,b<LF>1,2<LF>3,4<LF>');
  Try('classic Mac line endings',       True, 'a,b<CR>1,2<CR>3,4<CR>');
  Try('mixed line endings',             True, 'a<CR><LF>b<LF>c<CR>d');
  Try('comma inside quotes',            True, 'name,address<LF>Ann,"1 High St, Leeds"');
  Try('quotes inside quotes',           True, 'quote<LF>"She said ""hello"""');
  Try('line break inside quotes',       True, 'id,note<LF>1,"line one<LF>line two"<LF>2,plain');
  Try('empty fields',                   True, 'a,,c<LF>,,<LF>x,y,');
  Try('quoted empty string',            True, 'a,"",c');
  Try('blank line = empty record',      True, 'a<LF><LF>b');
  Try('single field, single line',      True, 'hello');
  Try('spaces are kept',                True, ' a , b <LF>c,d');
  Try('ragged rows (RFC does not care)', True, 'a,b,c<LF>1,2<LF>1,2,3,4');

  dbms_output.put_line('--- Invalid ---');
  Try('quote never closed',             False, 'a,"unterminated<LF>b,c');
  Try('text after closing quote',       False, 'a,"b"c,d');
  Try('quote inside unquoted field',    False, 'a,b"c,d');
  Try('tab character',                  False, 'a' || chr(9) || 'b,c');
  Try('non-ASCII character',            False, 'caf' || unistr('\00E9') || ',x');
end;
/
