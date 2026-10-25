# ABNF for Oracle PL/SQL

Parse, validate and explain input against [ABNF](https://www.rfc-editor.org/rfc/rfc5234) grammars, in Oracle 19c.

## Introduction

A grammar is a set of named rules describing what a valid piece of text looks like: an email address is a local part,
an `@` and a domain; a domain is labels separated by dots; and so on down to individual characters. Grammars were first
written down in [Backus-Naur Form](https://en.wikipedia.org/wiki/Backus%E2%80%93Naur_form) (BNF) for the ALGOL 60
language report. BNF is very bare: it has no way to say "one to four of these" or "optionally this", no way to write a
control character, and in practice every document that used it invented its own extensions.

[Augmented BNF](https://en.wikipedia.org/wiki/Augmented_Backus%E2%80%93Naur_form) (ABNF, [RFC 5234](https://www.rfc-editor.org/rfc/rfc5234))
standardised one dialect and added repetition (`1*4HEXDIG`), options and grouping, numeric character values and
ranges (`%x30-39`), and a set of core rules (`ALPHA`, `DIGIT`, `DQUOTE` ...). It is the notation used by most
[RFCs](https://en.wikipedia.org/wiki/Request_for_Comments), the numbered documents that specify Internet formats and
protocols: [RFC 5322](https://www.rfc-editor.org/rfc/rfc5322) for email addresses, [RFC 3986](https://www.rfc-editor.org/rfc/rfc3986)
for URIs and IP addresses, [RFC 4180](https://www.rfc-editor.org/rfc/rfc4180) for CSV. In those documents the grammar
is the authoritative definition of what is valid.

This project lets Oracle use those grammars as they are written:

- **Object types** (`TY_ABNF_*`) represent a grammar as a tree, one type per ABNF construct. Each node knows how to
  match input against itself. Matching returns every position a match can end at, so unordered alternation and
  backtracking work as the RFCs intend, which a first-match-wins matcher gets wrong.
- **`P_ABNF_Engine`** parses ABNF text into a rule set (`ParseGrammar`), validates input (`ValidateInput`), explains why
  input does not match (`ExplainMismatch`), splits input into tokens (`Tokenise`) or a parse tree (`ParseTree`), and can
  turn a grammar into PL/SQL code (`GeneratePLSQLFromABNF`) so the parsing cost is paid once, not on every call.
- **Example packages** built on the engine: `P_ABNF_Network` (IPv4, IPv6, email, URI) and `P_ABNF_CSV` (CSV).

Copy a grammar out of an RFC, pass it to `ParseGrammar`, and you have a validator you can check against the standard.

| Grammar | RFC | Package |
|---------|-----|---------|
| IPv4 address | [3986](https://www.rfc-editor.org/rfc/rfc3986) | `P_ABNF_Network` |
| IPv6 address | [3986](https://www.rfc-editor.org/rfc/rfc3986) | `P_ABNF_Network` |
| Email `addr-spec` | [5322](https://www.rfc-editor.org/rfc/rfc5322) | `P_ABNF_Network` |
| URI, URI-reference, absolute-URI, relative-ref | [3986](https://www.rfc-editor.org/rfc/rfc3986) | `P_ABNF_Network` |
| CSV | [4180](https://www.rfc-editor.org/rfc/rfc4180) | `P_ABNF_CSV` |
| Core rules (`ALPHA`, `DIGIT` ...) | [5234](https://www.rfc-editor.org/rfc/rfc5234) appendix B | `P_ABNF_Engine` |

## Install

```sql
@ABNF_Build.sql
```

## Use

### From ABNF text

```sql
declare
  vRules TY_ABNF_RuleSet := P_ABNF_Engine.ParseGrammar(
    '; a comma separated list of numbers' || chr(10)
 || 'list   = number *("," number)'        || chr(10)
 || 'number = 1*DIGIT'
  );
begin
  -- start rule null = first rule in the grammar
  if P_ABNF_Engine.ValidateInput(vRules, null, '1,22,333') then
    dbms_output.put_line('valid');
  end if;

  dbms_output.put_line(P_ABNF_Engine.ExplainMismatch(vRules, 'list', '1,2x'));
  -- Line 1, column 4: unexpected input "x" after a complete match of 3 character(s), expected one of: DIGIT, ",", end of input
end;
/
```

### From PL/SQL code

`GeneratePLSQLFromABNF(pGrammar)` returns the source of `function GetRuleSet return TY_ABNF_RuleSet`, with the
grammar's comments as PL/SQL comments. Paste it into your own package:

```sql
select P_ABNF_Engine.GeneratePLSQLFromABNF('r = "a" / %x30-39') from dual;
```

### Tokenising input

`Tokenise` is a pipelined function that splits input into tokens, each a match of one of the rules you name. The longest
match wins at each position; a tie goes to the rule listed first. Rules that match nothing never produce a token.

```sql
select t.SEQ, t.RULE_NAME, t.START_POS, t.TEXT
from table(P_ABNF_Engine.Tokenise(
       'int = 1*DIGIT' || chr(10) || 'op = "+" / "-"' || chr(10) || 'ws = 1*SP'
     , 'int,op,ws'
     , '12 + 345'
     )) t;
```

Pass a rule set (from `ParseGrammar`) instead of grammar text to avoid re-parsing, and `null` for the rule list to use
every rule in the grammar. If a position starts no token, it raises ORA-20120 with line, column and the rules tried.

### Parse tree

`ParseTree` matches the whole input against a start rule and returns one row for every match of a rule defined in the
grammar, parents before children. Use it when you need structure (which record, which field) rather than a flat token list.

```sql
select t.NODE_ID, t.PARENT_ID, t.DEPTH, t.RULE_NAME, t.START_POS, t.NODE_LENGTH, t.TEXT
from table(P_ABNF_Engine.ParseTree(vCsvGrammar, 'file', vCsv)) t
order by t.NODE_ID;
```

- Rules that matched nothing are listed (`NODE_LENGTH` 0), so an empty CSV field is a row. `Tokenise` skips them.
- Core rules (`DIGIT`, `ALPHA` ...) are not listed unless the grammar defines them itself.
- Each row's `PARENT_ID` is the `NODE_ID` of the enclosing rule match, so `connect by` or a self join gives record and column.
- When the input can be matched in more than one way, the reading that tries longer matches first is returned
  (so an optional CSV header is treated as present).
- If the input does not match it raises ORA-20121 with the `ExplainMismatch` message.
- It re-derives the tree after matching and can be slow on large inputs with highly ambiguous grammars.

`Tokenise` or `ParseTree`? `Tokenise` splits input into lexical pieces by longest match and is cheap. `ParseTree` follows
the grammar and gives nesting, but matches the entire input as one rule.

### From node trees

Build the tree yourself, as `P_ABNF_Network` does:

```sql
P_ABNF_Engine.ValidateInput(P_ABNF_Network.GetIPv6AddressRule(), '2001:db8::1')
```

### Ready-made rules ([P_ABNF_Network.sql](P_ABNF_Network.sql))

| Function | Rule |
|----------|------|
| `GetIPv4OctetRule` | `dec-octet` 0-255 (RFC 3986) |
| `GetIPv6AddressRule`, `ValidateIPv6` | `IPv6address` (RFC 3986 / 4291) |
| `GetEmailAddrSpecRule`, `ValidateEmail` | `addr-spec` (RFC 5322) |
| `GetUriRuleSet`, `ValidateUri` | `URI`, `URI-reference`, `absolute-URI`, `relative-ref` (RFC 3986) |

`GetIPv4RuleSet`, `GetIPv6RuleSet`, `GetEmailRuleSet` and `GetUriRuleSet` return the same grammars as rule sets, for
`ParseTree` and `Tokenise`. The node trees avoid re-parsing grammar text on each call; `ValidateUri` does parse its text
every time, so generate code from `GetUriRuleSet` (`GeneratePLSQLFromRules`) before using it in bulk.

### CSV ([P_ABNF_CSV.sql](P_ABNF_CSV.sql))

Records may end with CRLF, LF (Unix) or CR (classic Mac OS), mixed freely. RFC 4180 itself only allows CRLF; the
grammar's `NEWLINE = CR LF / LF / CR` rule is the one place to change that.

```sql
select f.RECORD_NO, f.FIELD_NO, f.IS_HEADER, f.VALUE
from table(P_ABNF_CSV.ParseCsv(vCsv)) f;            -- pHasHeader defaults to 'Y'

P_ABNF_CSV.ValidateCsv(vCsv)    -- boolean
P_ABNF_CSV.ExplainCsv(vCsv)     -- why it is not valid, null if it is
P_ABNF_CSV.FormatRecord(TY_ABNF_StrList('a', 'b,c', null))   -- a,"b,c",
P_ABNF_CSV.NormaliseLineEndings(vCsv)   -- all line breaks to CRLF, for writing strict RFC 4180
```

Input is a `clob` (a `varchar2` converts implicitly). It is read in chunks and cut into records at line breaks outside
quotes; the grammar is then matched one record at a time and `ParseCsv` pipes fields as it goes, so memory use depends
on the longest record, not the size of the file. A single record (with any line breaks inside its quotes) must fit in
about 32K, otherwise ORA-20132 is raised. `START_POS` and error positions are character offsets into the clob, and
`ExplainCsv` line numbers count from the start of the input. Reading in smaller or larger chunks
(`P_ABNF_CSV.SetReadChunkSize`, default 4000 characters) changes speed only. Most of the time goes on the per-record
match, not on reading the clob.

## Explaining a mismatch

`ValidateInput` returns whether input matches. `ExplainMismatch` says why, using the furthest position the input could
be matched to:

| Situation | Message |
|-----------|---------|
| Wrong character | `Line 1, column 3: found "x", expected DIGIT (while matching rule: r)` |
| Several possibilities | `Line 1, column 2: found "x", expected one of: "b", "c" (while matching rule: r)` |
| Input too short | `Line 1, column 3: unexpected end of input, expected DIGIT (while matching rule: r)` |
| Input too long | `Line 1, column 3: unexpected input "c" after a complete match of 2 character(s), expected end of input` |

Both are also available as procedures with structured outputs (position, line, column, found character, list of expected items).

## Coverage

| Feature | RFC | Supported |
|---------|-----|-----------|
| Rule names, `=`, `=/` incremental alternatives | 5234 | yes |
| Concatenation, alternation (`/`), grouping `( )`, option `[ ]` | 5234 | yes |
| Repetition `n`, `n*m`, `*`, `n*`, `*m` | 5234 | yes |
| `"text"` (case-insensitive) | 5234 | yes |
| `%x` `%d` `%b` values, ranges (`-`) and concatenations (`.`) | 5234 | yes, up to `%xFF` |
| `<prose>` | 5234 | parsed; never matches (cannot be evaluated) |
| `;` comments | 5234 | yes, kept as the rule's `COMMENT_TEXT` |
| Core rules (ALPHA, BIT, CHAR, CR, CRLF, CTL, DIGIT, DQUOTE, HEXDIG, HTAB, LF, LWSP, OCTET, SP, VCHAR, WSP) | 5234 App. B | yes |
| `%s"text"` / `%i"text"` | 7405 | yes |
| Recursive and forward-referenced rules | 5234 | yes |
| Ambiguous grammars (every alternative explored) | 5234 | yes |

### Limitations

- Left-recursive rules (`a = a "x" / "y"`) are detected and raise ORA-20102 rather than being matched.
- Grammar text and input are `varchar2` (32K).
- Characters are compared by `ascii()`: reliable for 7-bit ASCII; values above `%xFF` are rejected.
- Matching explores every possibility, so pathological grammars (nested unbounded repetitions of the same text) can be slow.

## Tests

Tests use [utPLSQL v3](https://utplsql.org). Install them by uncommenting the lines in `ABNF_Build.sql` (or run
the files in `UnitTests/`), then:

```sql
exec ut.run('P_UT_ABNF_Engine')
exec ut.run('P_UT_ABNF_Network')
exec ut.run('P_UT_ABNF_CSV')
```

See [CLAUDE.md](CLAUDE.md) for the file map and design notes.
