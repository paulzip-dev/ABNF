create or replace package P_UT_ABNF_Engine is

--%suite(ABNF engine: matching, grammar parsing, code generation and mismatch explanations)
--%rollback(manual)

------------------------------------------------------------------------------
-- Literals
------------------------------------------------------------------------------
--%test(Quoted literal is case-insensitive by default (RFC 5234))
procedure LiteralCaseInsensitive;

--%test(%s literal is case-sensitive (RFC 7405))
procedure LiteralCaseSensitiveS;

--%test(%i literal is case-insensitive (RFC 7405))
procedure LiteralCaseInsensitiveI;

--%test(Empty literal matches empty input)
procedure LiteralEmpty;

--%test(Numeric concatenation %d13.10 matches CRLF)
procedure NumericConcatenation;

--%test(Numeric values are case-sensitive and support x, d and b bases)
procedure NumericBases;

--%test(Numeric range matches only codes inside the range)
procedure NumericRange;

--%test(Literal node built directly honours CASE_SENSITIVE)
procedure LiteralNodeDirect;

------------------------------------------------------------------------------
-- Structure
------------------------------------------------------------------------------
--%test(Repetition forms n, n*m, *, n* and *m)
procedure RepetitionForms;

--%test(Repetition node built directly)
procedure RepetitionNodeDirect;

--%test(Option and group)
procedure OptionAndGroup;

--%test(Concatenation binds tighter than alternation)
procedure Precedence;

--%test(Alternatives are unordered: a shorter alternative may need to be abandoned)
procedure BacktrackingAlternation;

--%test(Greedy repetition gives characters back)
procedure BacktrackingRepetition;

--%test(Recursive rule)
procedure RecursiveRule;

--%test(Rules may refer to rules defined later and names are case-insensitive)
procedure ForwardReferenceAndCase;

--%test(Incremental alternatives with =/)
procedure IncrementalAlternative;

--%test(Prose never matches)
procedure ProseNeverMatches;

--%test(Empty repetition body does not loop forever)
procedure EmptyMatchTerminates;

--%test(Left recursion is reported instead of looping)
--%throws(-20102)
procedure LeftRecursionRaises;

--%test(Undefined rule is reported)
--%throws(-20101)
procedure UndefinedRuleRaises;

------------------------------------------------------------------------------
-- Core rules
------------------------------------------------------------------------------
--%test(Core rules ALPHA DIGIT HEXDIG BIT)
procedure CoreRulesAlnum;

--%test(Core rules CHAR OCTET VCHAR CTL)
procedure CoreRulesCharacters;

--%test(Core rules CR LF CRLF DQUOTE HTAB SP WSP LWSP)
procedure CoreRulesWhitespace;

------------------------------------------------------------------------------
-- ParseGrammar
------------------------------------------------------------------------------
--%test(Rules are returned in definition order)
procedure ParseGrammarRules;

--%test(Leading and trailing comments are kept with their rule)
procedure CommentsCaptured;

--%test(A blank line detaches a comment from the next rule)
procedure CommentDetachedByBlankLine;

--%test(Semicolons and quotes inside strings and comments are handled)
procedure CommentsAndStrings;

--%test(Layout: tabs, indentation, CR, LF, CRLF and no trailing newline)
procedure LayoutVariants;

--%test(Multi-line rules with comment lines between the lines)
procedure MultiLineRule;

--%test(The ABNF grammar of ABNF (RFC 5234 section 4) parses)
procedure ParseAbnfOfAbnf;

--%test(The ABNF grammar of ABNF accepts and rejects grammar text)
procedure AbnfOfAbnfValidatesGrammars;

--%test(Syntax error reports line and column)
procedure SyntaxErrorLocation;

--%test(Duplicate rule is a syntax error)
--%throws(-20110)
procedure DuplicateRuleRaises;

--%test(=/ before the rule exists is a syntax error)
--%throws(-20110)
procedure IncrementalBeforeDefinitionRaises;

--%test(Unterminated string is a syntax error)
--%throws(-20110)
procedure UnterminatedStringRaises;

--%test(Reversed range is a syntax error)
--%throws(-20110)
procedure ReversedRangeRaises;

--%test(Reversed repeat counts are a syntax error)
--%throws(-20110)
procedure ReversedRepeatRaises;

--%test(Unclosed group is a syntax error)
--%throws(-20110)
procedure UnclosedGroupRaises;

--%test(Empty grammar gives an empty rule set)
procedure EmptyGrammar;

------------------------------------------------------------------------------
-- GeneratePLSQLFromABNF
------------------------------------------------------------------------------
--%test(Generated code has a GetRuleSet function and carries comments)
procedure GenerateShape;

--%test(Generated code compiles and validates like the grammar)
procedure GenerateCompilesAndMatches;

--%test(Generated code escapes quotes and control characters)
procedure GenerateEscaping;

--%test(Invalid grammar raises an error when generating)
--%throws(-20110)
procedure GenerateInvalidGrammarRaises;

------------------------------------------------------------------------------
-- ValidateInput / ExplainMismatch
------------------------------------------------------------------------------
--%test(ValidateInput procedure returns position and message)
procedure ValidateInputProcedure;

--%test(Explain returns null for valid input)
procedure ExplainValid;

--%test(Explain names the unexpected character, its position and the expected rule)
procedure ExplainUnexpectedCharacter;

--%test(Explain reports unexpected end of input)
procedure ExplainEndOfInput;

--%test(Explain reports trailing input after a complete match)
procedure ExplainTrailingInput;

--%test(Explain lists every alternative that was possible)
procedure ExplainAlternatives;

--%test(Explain reports line and column across line breaks)
procedure ExplainLineAndColumn;

--%test(Explain reports prose that cannot be evaluated)
procedure ExplainProse;

--%test(Explain structured form returns the pieces)
procedure ExplainStructured;

--%test(Explain works on a node tree without rules)
procedure ExplainNodeTree;

------------------------------------------------------------------------------
-- Tokenise
------------------------------------------------------------------------------
--%test(Input is split into tokens in order, with positions and text)
procedure TokeniseBasic;

--%test(Longest match wins)
procedure TokeniseLongestMatch;

--%test(A tie goes to the rule listed first)
procedure TokeniseTieFirstListed;

--%test(Null token rule list uses every rule in the grammar)
procedure TokeniseAllRules;

--%test(Rule set overload and core rules as tokens)
procedure TokeniseRuleSetAndCore;

--%test(Empty and null input give no tokens)
procedure TokeniseEmptyInput;

--%test(Zero-length matches never produce tokens or loop)
procedure TokeniseZeroLength;

--%test(Characters no rule matches raise an error with line, column and rules tried)
procedure TokeniseNoMatchMessage;

--%test(Unknown token rule is reported)
--%throws(-20101)
procedure TokeniseUnknownRule;

--%test(Many tokens are produced efficiently and in order)
procedure TokeniseManyTokens;

------------------------------------------------------------------------------
-- ParseTree
------------------------------------------------------------------------------
--%test(Rules matched are listed parent first with depth, position and length)
procedure ParseTreeStructure;

--%test(Parent ids link children to the enclosing rule)
procedure ParseTreeParents;

--%test(Core rules are not listed unless the grammar defines them)
procedure ParseTreeHidesCoreRules;

--%test(A rule that matched nothing is listed with length 0)
procedure ParseTreeEmptyMatch;

--%test(Dead ends taken while backtracking leave no rows behind)
procedure ParseTreeBacktracking;

--%test(Recursive rules nest)
procedure ParseTreeRecursive;

--%test(CSV: records, fields and quoted line breaks)
procedure ParseTreeCsv;

--%test(Rule set overload gives the same tree)
procedure ParseTreeRuleSetOverload;

--%test(Input that does not match raises an error with the explanation)
procedure ParseTreeMismatch;

--%test(Null start rule uses the first rule)
procedure ParseTreeDefaultStartRule;

end P_UT_ABNF_Engine;
/

create or replace package body P_UT_ABNF_Engine is

NL constant varchar2(1) := chr(10);

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------
function Matches(pGrammar varchar2, pInput varchar2, pStartRule varchar2 default null) return boolean is
begin
  return P_ABNF_Engine.ValidateInput(P_ABNF_Engine.ParseGrammar(pGrammar), pStartRule, pInput);
end Matches;

procedure ExpectMatch(pGrammar varchar2, pInput varchar2) is
begin
  ut.expect(Matches(pGrammar, pInput), 'Grammar <' || pGrammar || '> should match <' || pInput || '>').to_be_true();
end ExpectMatch;

procedure ExpectNoMatch(pGrammar varchar2, pInput varchar2) is
begin
  ut.expect(Matches(pGrammar, pInput), 'Grammar <' || pGrammar || '> should not match <' || pInput || '>').to_be_false();
end ExpectNoMatch;

-- Checks a core rule against one value it must accept and one it must reject
procedure ExpectCore(pRule varchar2, pGood varchar2, pBad varchar2) is
begin
  ExpectMatch('r = ' || pRule, pGood);
  ExpectNoMatch('r = ' || pRule, pBad);
end ExpectCore;

------------------------------------------------------------------------------
-- Literals
------------------------------------------------------------------------------
procedure LiteralCaseInsensitive is
begin
  ExpectMatch('r = "abc"', 'abc');
  ExpectMatch('r = "abc"', 'ABC');
  ExpectMatch('r = "abc"', 'aBc');
  ExpectNoMatch('r = "abc"', 'abd');
  ExpectNoMatch('r = "abc"', 'ab');
end LiteralCaseInsensitive;

procedure LiteralCaseSensitiveS is
begin
  ExpectMatch('r = %s"abc"', 'abc');
  ExpectNoMatch('r = %s"abc"', 'ABC');
  ExpectMatch('r = %S"AbC"', 'AbC');
  ExpectNoMatch('r = %S"AbC"', 'abc');
end LiteralCaseSensitiveS;

procedure LiteralCaseInsensitiveI is
begin
  ExpectMatch('r = %i"abc"', 'ABC');
  ExpectMatch('r = %I"abc"', 'abc');
  ExpectNoMatch('r = %i"abc"', 'abd');
end LiteralCaseInsensitiveI;

procedure LiteralEmpty is
begin
  ExpectMatch('r = ""', null);
  ExpectNoMatch('r = ""', 'a');
  ExpectMatch('r = "a" ""', 'a');
end LiteralEmpty;

procedure NumericConcatenation is
begin
  ExpectMatch('r = %d13.10', chr(13) || chr(10));
  ExpectMatch('r = %x0D.0A', chr(13) || chr(10));
  ExpectMatch('r = %x61.62.63', 'abc');
  ExpectNoMatch('r = %x61.62.63', 'ABC');
  ExpectNoMatch('r = %d13.10', chr(13));
end NumericConcatenation;

procedure NumericBases is
begin
  ExpectMatch('r = %x41', 'A');
  ExpectMatch('r = %X41', 'A');
  ExpectMatch('r = %d65', 'A');
  ExpectMatch('r = %b1000001', 'A');
  ExpectNoMatch('r = %x41', 'a');
  ExpectMatch('r = %b1000001.1000010', 'AB');
  ExpectMatch('r = %x7f', chr(127));
end NumericBases;

procedure NumericRange is
begin
  ExpectMatch('r = %x30-39', '5');
  ExpectMatch('r = %x30-39', '0');
  ExpectMatch('r = %x30-39', '9');
  ExpectNoMatch('r = %x30-39', 'a');
  ExpectNoMatch('r = %x30-39', '55');
  ExpectMatch('r = %d97-122', 'q');
  ExpectMatch('r = %b110000-111001', '7');
  ExpectNoMatch('r = %x30-39', null);
end NumericRange;

procedure LiteralNodeDirect is
begin
  ut.expect(P_ABNF_Engine.ValidateInput(
              TY_ABNF_Literal(NODE_NAME => null, VALUE => 'Ab', CASE_SENSITIVE => 'Y'), 'Ab'
            )).to_be_true();
  ut.expect(P_ABNF_Engine.ValidateInput(
              TY_ABNF_Literal(NODE_NAME => null, VALUE => 'Ab', CASE_SENSITIVE => 'Y'), 'ab'
            )).to_be_false();
  -- the two-argument constructor is case-insensitive
  ut.expect(P_ABNF_Engine.ValidateInput(TY_ABNF_Literal(NODE_NAME => null, VALUE => 'Ab'), 'aB')).to_be_true();
end LiteralNodeDirect;

------------------------------------------------------------------------------
-- Structure
------------------------------------------------------------------------------
procedure RepetitionForms is
begin
  ExpectMatch('r = 2DIGIT', '12');
  ExpectNoMatch('r = 2DIGIT', '1');
  ExpectNoMatch('r = 2DIGIT', '123');

  ExpectMatch('r = 1*3DIGIT', '1');
  ExpectMatch('r = 1*3DIGIT', '123');
  ExpectNoMatch('r = 1*3DIGIT', '1234');
  ExpectNoMatch('r = 1*3DIGIT', null);

  ExpectMatch('r = *DIGIT', null);
  ExpectMatch('r = *DIGIT', '123456789');
  ExpectNoMatch('r = *DIGIT', '12a');

  ExpectMatch('r = 2*DIGIT', '12');
  ExpectMatch('r = 2*DIGIT', '123456');
  ExpectNoMatch('r = 2*DIGIT', '1');

  ExpectMatch('r = *2DIGIT', null);
  ExpectMatch('r = *2DIGIT', '12');
  ExpectNoMatch('r = *2DIGIT', '123');

  ExpectMatch('r = 0DIGIT', null);
  ExpectMatch('r = 1*1DIGIT', '7');
  ExpectMatch('r = 3("ab")', 'ababab');
  ExpectMatch('r = 1*("a" / "b")', 'abba');
end RepetitionForms;

procedure RepetitionNodeDirect is
  vNode TY_ABNF_Node := TY_ABNF_Repetition(
                          NODE_NAME  => null
                        , MIN_OCCURS => 2
                        , MAX_OCCURS => 3
                        , CHILD_NODE => P_ABNF_Engine.CoreDigit()
                        );
begin
  ut.expect(P_ABNF_Engine.ValidateInput(vNode, '1')).to_be_false();
  ut.expect(P_ABNF_Engine.ValidateInput(vNode, '12')).to_be_true();
  ut.expect(P_ABNF_Engine.ValidateInput(vNode, '123')).to_be_true();
  ut.expect(P_ABNF_Engine.ValidateInput(vNode, '1234')).to_be_false();
end RepetitionNodeDirect;

procedure OptionAndGroup is
begin
  ExpectMatch('r = "a" ["b"] "c"', 'ac');
  ExpectMatch('r = "a" ["b"] "c"', 'abc');
  ExpectNoMatch('r = "a" ["b"] "c"', 'abbc');
  ExpectMatch('r = ("a" / "b") "c"', 'bc');
  ExpectMatch('r = *("a" "b")', 'ababab');
  ExpectNoMatch('r = *("a" "b")', 'aba');
  ExpectMatch('r = [("a" / "b") "c"]', null);
  ExpectMatch('r = [("a" / "b") "c"]', 'ac');
end OptionAndGroup;

procedure Precedence is
begin
  -- "a" / ("b" "c")
  ExpectMatch('r = "a" / "b" "c"', 'a');
  ExpectMatch('r = "a" / "b" "c"', 'bc');
  ExpectNoMatch('r = "a" / "b" "c"', 'ac');
  ExpectNoMatch('r = "a" / "b" "c"', 'b');
  -- repetition applies to the element only
  ExpectMatch('r = "a" *"b"', 'abbb');
  ExpectNoMatch('r = "a" *"b"', 'abab');
end Precedence;

procedure BacktrackingAlternation is
begin
  -- first-match-wins would take "a", fail on "c", and never try "ab"
  ExpectMatch('r = ("a" / "ab") "c"', 'abc');
  ExpectMatch('r = ("a" / "ab") "c"', 'ac');
  ExpectMatch('r = ("ab" / "a") "bc"', 'abc');
  ExpectNoMatch('r = ("a" / "ab") "c"', 'abd');
end BacktrackingAlternation;

procedure BacktrackingRepetition is
begin
  ExpectMatch('r = *DIGIT DIGIT', '123');
  ExpectMatch('r = *DIGIT "1"', '1111');
  ExpectMatch('r = *"a" "a" "b"', 'aaab');
  ExpectNoMatch('r = *DIGIT DIGIT', null);
  ExpectMatch('r = 1*ALPHA "@" 1*ALPHA', 'abc@def');
end BacktrackingRepetition;

procedure RecursiveRule is
  vGrammar varchar2(200) := 'r = "(" [r] ")"';
begin
  ExpectMatch(vGrammar, '()');
  ExpectMatch(vGrammar, '((()))');
  ExpectNoMatch(vGrammar, '(()');
  ExpectNoMatch(vGrammar, '(()))');
  ExpectNoMatch(vGrammar, '(');

  -- right recursion with several rules
  ExpectMatch('list = item *("," list)' || NL || 'item = 1*DIGIT', '1,22,333');
  ExpectNoMatch('list = item *("," list)' || NL || 'item = 1*DIGIT', '1,22,');
end RecursiveRule;

procedure ForwardReferenceAndCase is
  vGrammar varchar2(200) := 'a = B "x"' || NL || 'b = "y"';
begin
  ExpectMatch(vGrammar, 'yx');
  ut.expect(Matches(vGrammar, 'YX', 'A')).to_be_true();
  ut.expect(Matches(vGrammar, 'yx', 'a')).to_be_true();
  -- by default the first rule is the start rule
  ExpectNoMatch(vGrammar, 'y');
  ut.expect(Matches(vGrammar, 'y', 'B')).to_be_true();
end ForwardReferenceAndCase;

procedure IncrementalAlternative is
  vGrammar varchar2(200) := 'r = "a"' || NL || 'r =/ "b"' || NL || 'r =/ "c" "d"';
begin
  ExpectMatch(vGrammar, 'a');
  ExpectMatch(vGrammar, 'b');
  ExpectMatch(vGrammar, 'cd');
  ExpectNoMatch(vGrammar, 'c');
  ut.expect(P_ABNF_Engine.ParseGrammar(vGrammar).count).to_equal(1);
end IncrementalAlternative;

procedure ProseNeverMatches is
begin
  ExpectNoMatch('r = <any text at all>', 'x');
  ExpectNoMatch('r = <any text at all>', null);
  ExpectMatch('r = <prose> / "a"', 'a');
end ProseNeverMatches;

procedure EmptyMatchTerminates is
begin
  ExpectMatch('r = *("")', null);
  ExpectMatch('r = *[ "a" ]', 'aaa');
  ExpectMatch('r = 3*5("")', null);
end EmptyMatchTerminates;

procedure LeftRecursionRaises is
begin
  ExpectNoMatch('r = r "x" / "y"', 'yx');
end LeftRecursionRaises;

procedure UndefinedRuleRaises is
begin
  ExpectNoMatch('r = nothing-defined-here', 'x');
end UndefinedRuleRaises;

------------------------------------------------------------------------------
-- Core rules
------------------------------------------------------------------------------
procedure CoreRulesAlnum is
begin
  ExpectCore('ALPHA', 'q', '5');
  ExpectCore('ALPHA', 'Q', '_');
  ExpectCore('alpha', 'Z', '@');
  ExpectCore('DIGIT', '7', 'x');
  ExpectCore('HEXDIG', 'f', 'g');
  ExpectCore('HEXDIG', 'A', 'G');
  ExpectCore('HEXDIG', '9', '/');
  ExpectCore('BIT', '0', '2');
  ExpectCore('BIT', '1', 'a');
end CoreRulesAlnum;

procedure CoreRulesCharacters is
begin
  ExpectCore('CHAR', 'a', chr(0));
  ExpectCore('CHAR', chr(127), 'ab');
  ExpectCore('OCTET', chr(0), 'ab');
  ExpectCore('VCHAR', '~', ' ');
  ExpectCore('VCHAR', '!', chr(127));
  ExpectCore('CTL', chr(0), 'a');
  ExpectCore('CTL', chr(31), ' ');
  ExpectCore('CTL', chr(127), '~');
end CoreRulesCharacters;

procedure CoreRulesWhitespace is
begin
  ExpectCore('CR', chr(13), chr(10));
  ExpectCore('LF', chr(10), chr(13));
  ExpectCore('CRLF', chr(13) || chr(10), chr(10));
  ExpectCore('DQUOTE', '"', '''');
  ExpectCore('HTAB', chr(9), ' ');
  ExpectCore('SP', ' ', chr(9));
  ExpectCore('WSP', ' ', 'x');
  ExpectCore('WSP', chr(9), chr(10));
  ExpectCore('LWSP', null, 'x');
  ExpectCore('LWSP', ' ' || chr(9) || ' ', 'x');
  -- a line break is only allowed in LWSP when followed by white space
  ExpectMatch('r = LWSP', ' ' || chr(13) || chr(10) || ' ');
  ExpectNoMatch('r = LWSP', ' ' || chr(13) || chr(10));
end CoreRulesWhitespace;

------------------------------------------------------------------------------
-- ParseGrammar
------------------------------------------------------------------------------
procedure ParseGrammarRules is
  vRules TY_ABNF_RuleSet := P_ABNF_Engine.ParseGrammar('Alpha-1 = "a"' || NL || 'second = "b"' || NL || 'third = "c"');
begin
  ut.expect(vRules.count).to_equal(3);
  ut.expect(vRules(1).RULE_NAME).to_equal('Alpha-1');
  ut.expect(vRules(2).RULE_NAME).to_equal('second');
  ut.expect(vRules(3).RULE_NAME).to_equal('third');
  ut.expect(vRules(2).RULE_NODE is not null).to_be_true();
end ParseGrammarRules;

procedure CommentsCaptured is
  vRules TY_ABNF_RuleSet := P_ABNF_Engine.ParseGrammar(
                              '; leading one' || NL
                           || '; leading two' || NL
                           || 'r = "a" ; trailing' || NL
                           || NL
                           || 's = "b"' || NL
                           );
begin
  ut.expect(vRules.count).to_equal(2);
  ut.expect(vRules(1).COMMENT_TEXT).to_equal('leading one' || NL || 'leading two' || NL || 'trailing');
  ut.expect(vRules(2).COMMENT_TEXT).to_be_null();
end CommentsCaptured;

procedure CommentDetachedByBlankLine is
  vRules TY_ABNF_RuleSet := P_ABNF_Engine.ParseGrammar(
                              '; about nothing' || NL
                           || NL
                           || '; about r' || NL
                           || 'r = "a"' || NL
                           || '; about s' || NL
                           || 's = "b"' || NL
                           );
begin
  ut.expect(vRules(1).COMMENT_TEXT).to_equal('about r');
  ut.expect(vRules(2).COMMENT_TEXT).to_equal('about s');
end CommentDetachedByBlankLine;

procedure CommentsAndStrings is
begin
  ExpectMatch('r = ";" ; semicolon in a string, "quote in a comment' || NL, ';');
  ExpectMatch('r = "/" / ";"', '/');
  ExpectMatch('r = "a;b" ;c', 'A;B');
  ExpectMatch('r = ")" "(" "[" "]" "<" ">" "=" "%"', ')([]<>=%');
  ExpectMatch('r = <a ; b / c>' || NL || '  / "x"', 'x');
end CommentsAndStrings;

procedure LayoutVariants is
  vTab constant varchar2(1) := chr(9);
begin
  -- no whitespace at all
  ExpectMatch('r="a"/"b"', 'b');
  -- tabs
  ExpectMatch('r' || vTab || '=' || vTab || '"a"' || vTab || '/' || vTab || '"b"', 'b');
  -- CRLF, CR only, and no final line break
  ExpectMatch('r = "a"' || chr(13) || chr(10) || '  / "b"' || chr(13) || chr(10), 'b');
  ExpectMatch('r = "a"' || chr(13) || '  / "b"', 'b');
  -- every line indented (as when copied out of an RFC)
  ExpectMatch('   r = a / b' || NL || '   a = "x"' || NL || '   b = "y"', 'y');
  -- the rule name on one line and "=" on the next
  ExpectMatch('r' || NL || '  = "a"', 'a');
  -- blank lines and leading blank lines
  ExpectMatch(NL || NL || 'r = "a"' || NL || NL || NL || 's = "b"' || NL || NL, 'a');
  -- the same grammar laid out three ways gives the same rules
  ut.expect(P_ABNF_Engine.ParseGrammar('r = a b' || NL || 'a = "1"' || NL || 'b = "2"').count).to_equal(3);
  ut.expect(P_ABNF_Engine.ParseGrammar('r=a b a="1" b="2"').count).to_equal(3);
end LayoutVariants;

procedure MultiLineRule is
  vGrammar varchar2(500) := 'r = "a"' || NL
                         || '    ; between lines' || NL
                         || '    / "b"' || NL
                         || '' || NL
                         || '    / "c"' || NL
                         || 's = "z"';
begin
  ExpectMatch(vGrammar, 'a');
  ExpectMatch(vGrammar, 'c');
  ut.expect(P_ABNF_Engine.ParseGrammar(vGrammar).count).to_equal(2);
end MultiLineRule;

-- RFC 5234 section 4
function AbnfOfAbnf return varchar2 is
begin
  return 'rulelist       =  1*( rule / (*c-wsp c-nl) )' || NL
      || 'rule           =  rulename defined-as elements c-nl' || NL
      || '                       ; continues if next line starts' || NL
      || '                       ;  with white space' || NL
      || 'rulename       =  ALPHA *(ALPHA / DIGIT / "-")' || NL
      || 'defined-as     =  *c-wsp ("=" / "=/") *c-wsp' || NL
      || '                       ; basic rules definition and' || NL
      || '                       ;  incremental alternatives' || NL
      || 'elements       =  alternation *c-wsp' || NL
      || 'c-wsp          =  WSP / (c-nl WSP)' || NL
      || 'c-nl           =  comment / CRLF' || NL
      || '                       ; comment or newline' || NL
      || 'comment        =  ";" *(WSP / VCHAR) CRLF' || NL
      || 'alternation    =  concatenation' || NL
      || '                  *(*c-wsp "/" *c-wsp concatenation)' || NL
      || 'concatenation  =  repetition *(1*c-wsp repetition)' || NL
      || 'repetition     =  [repeat] element' || NL
      || 'repeat         =  1*DIGIT / (*DIGIT "*" *DIGIT)' || NL
      || 'element        =  rulename / group / option /' || NL
      || '                  char-val / num-val / prose-val' || NL
      || 'group          =  "(" *c-wsp alternation *c-wsp ")"' || NL
      || 'option         =  "[" *c-wsp alternation *c-wsp "]"' || NL
      || 'char-val       =  DQUOTE *(%x20-21 / %x23-7E) DQUOTE' || NL
      || '                       ; quoted string of SP and VCHAR' || NL
      || '                       ;  without DQUOTE' || NL
      || 'num-val        =  "%" (bin-val / dec-val / hex-val)' || NL
      || 'bin-val        =  "b" 1*BIT' || NL
      || '                  [ 1*("." 1*BIT) / ("-" 1*BIT) ]' || NL
      || '                       ; series of concatenated bit values' || NL
      || '                       ;  or single ONEOF range' || NL
      || 'dec-val        =  "d" 1*DIGIT' || NL
      || '                  [ 1*("." 1*DIGIT) / ("-" 1*DIGIT) ]' || NL
      || 'hex-val        =  "x" 1*HEXDIG' || NL
      || '                  [ 1*("." 1*HEXDIG) / ("-" 1*HEXDIG) ]' || NL
      || 'prose-val      =  "<" *(%x20-3D / %x3F-7E) ">"' || NL
      || '                       ; bracketed string of SP and VCHAR' || NL
      || '                       ;  without angles' || NL
      || '                       ; prose description, to be used as' || NL
      || '                       ;  last resort' || NL;
end AbnfOfAbnf;

procedure ParseAbnfOfAbnf is
  vRules TY_ABNF_RuleSet := P_ABNF_Engine.ParseGrammar(AbnfOfAbnf());
begin
  ut.expect(vRules.count).to_equal(21);
  ut.expect(vRules(1).RULE_NAME).to_equal('rulelist');
  ut.expect(vRules(21).RULE_NAME).to_equal('prose-val');
  ut.expect(vRules(2).COMMENT_TEXT).to_be_like('continues if next line starts%with white space');
end ParseAbnfOfAbnf;

procedure AbnfOfAbnfValidatesGrammars is
  vRules TY_ABNF_RuleSet := P_ABNF_Engine.ParseGrammar(AbnfOfAbnf());
  vCrlf  constant varchar2(2) := chr(13) || chr(10);
begin
  ut.expect(P_ABNF_Engine.ValidateInput(vRules, 'rulelist', 'a = "b"' || vCrlf)).to_be_true();
  ut.expect(P_ABNF_Engine.ValidateInput(vRules, 'rulelist', 'x = "a" / %x30-39 *DIGIT [y]' || vCrlf)).to_be_true();
  ut.expect(P_ABNF_Engine.ValidateInput(vRules, 'rulelist', 'a = b' || vCrlf || 'b =/ <prose>' || vCrlf)).to_be_true();
  ut.expect(P_ABNF_Engine.ValidateInput(vRules, 'rulelist', 'a = (b / c) 2*3d' || vCrlf)).to_be_true();
  -- no definition after the "="
  ut.expect(P_ABNF_Engine.ValidateInput(vRules, 'rulelist', 'a = ' || vCrlf)).to_be_false();
  -- missing "="
  ut.expect(P_ABNF_Engine.ValidateInput(vRules, 'rulelist', 'a "b"' || vCrlf)).to_be_false();
  -- unbalanced group
  ut.expect(P_ABNF_Engine.ValidateInput(vRules, 'rulelist', 'a = (b' || vCrlf)).to_be_false();
end AbnfOfAbnfValidatesGrammars;

procedure SyntaxErrorLocation is
  vMessage varchar2(4000);
begin
  begin
    vMessage := P_ABNF_Engine.ParseGrammar('a = "x"' || NL || 'b = (').count;
  exception
    when OTHERS then
      vMessage := SQLERRM;
  end;
  ut.expect(vMessage).to_be_like('%ABNF syntax error at line 2, column 6%');

  begin
    vMessage := P_ABNF_Engine.ParseGrammar('a = "x"' || NL || 'b = "y" )').count;
  exception
    when OTHERS then
      vMessage := SQLERRM;
  end;
  ut.expect(vMessage).to_be_like('%line 2, column 9%');
end SyntaxErrorLocation;

procedure DuplicateRuleRaises is
  vRules TY_ABNF_RuleSet;
begin
  vRules := P_ABNF_Engine.ParseGrammar('a = "x"' || NL || 'A = "y"');
end DuplicateRuleRaises;

procedure IncrementalBeforeDefinitionRaises is
  vRules TY_ABNF_RuleSet;
begin
  vRules := P_ABNF_Engine.ParseGrammar('a =/ "x"');
end IncrementalBeforeDefinitionRaises;

procedure UnterminatedStringRaises is
  vRules TY_ABNF_RuleSet;
begin
  vRules := P_ABNF_Engine.ParseGrammar('a = "x' || NL || 'b = "y"');
end UnterminatedStringRaises;

procedure ReversedRangeRaises is
  vRules TY_ABNF_RuleSet;
begin
  vRules := P_ABNF_Engine.ParseGrammar('a = %x39-30');
end ReversedRangeRaises;

procedure ReversedRepeatRaises is
  vRules TY_ABNF_RuleSet;
begin
  vRules := P_ABNF_Engine.ParseGrammar('a = 5*2"x"');
end ReversedRepeatRaises;

procedure UnclosedGroupRaises is
  vRules TY_ABNF_RuleSet;
begin
  vRules := P_ABNF_Engine.ParseGrammar('a = ("x" / "y"');
end UnclosedGroupRaises;

procedure EmptyGrammar is
begin
  ut.expect(P_ABNF_Engine.ParseGrammar(null).count).to_equal(0);
  ut.expect(P_ABNF_Engine.ParseGrammar('  ' || NL || '; just a comment' || NL).count).to_equal(0);
end EmptyGrammar;

------------------------------------------------------------------------------
-- GeneratePLSQLFromABNF
------------------------------------------------------------------------------
-- Compiles the generated code in an anonymous block and validates pInput against rule pStartRule
function RunGenerated(pCode clob, pStartRule varchar2, pInput varchar2) return integer is
  vResult integer;
begin
  execute immediate
    'declare ' || pCode
    || ' begin'
    || '  if P_ABNF_Engine.ValidateInput(GetRuleSet(), :1, :2) then :3 := 1; else :3 := 0; end if;'
    || ' end;'
  using in pStartRule, in pInput, out vResult;
  return vResult;
end RunGenerated;

procedure GenerateShape is
  vCode clob := P_ABNF_Engine.GeneratePLSQLFromABNF('; the rule' || NL || 'r = "a" / %x30-39' || NL);
begin
  ut.expect(vCode).to_be_like('%function GetRuleSet return TY_ABNF_RuleSet%');
  ut.expect(vCode).to_be_like('%-- the rule%');
  ut.expect(vCode).to_be_like('%RULE_NAME    => ''r''%');
  ut.expect(vCode).to_be_like('%TY_ABNF_Range%');
  ut.expect(vCode).to_be_like('%end GetRuleSet;%');
  ut.expect(DBMS_LOB.GETLENGTH(P_ABNF_Engine.GeneratePLSQLFromABNF(null))).to_equal(0);
end GenerateShape;

procedure GenerateCompilesAndMatches is
  vGrammar varchar2(1000) := '; a list of numbers' || NL
                          || 'list = number *("," list)' || NL
                          || 'number = 1*DIGIT / %s"x" 2HEXDIG ; hex form' || NL
                          || 'opt = [number] ("a" / "b") <prose>' || NL;
  vCode    clob := P_ABNF_Engine.GeneratePLSQLFromABNF(vGrammar);
begin
  ut.expect(RunGenerated(vCode, 'list', '1,22,x1F,3')).to_equal(1);
  ut.expect(RunGenerated(vCode, 'list', '1,22,X1F,3')).to_equal(0);
  ut.expect(RunGenerated(vCode, 'list', '1,,2')).to_equal(0);
  ut.expect(RunGenerated(vCode, 'number', '42')).to_equal(1);
  -- the generated rule set behaves the same as the parsed one
  ut.expect(Matches(vGrammar, '1,22,x1F,3', 'list')).to_be_true();
  ut.expect(Matches(vGrammar, '1,22,X1F,3', 'list')).to_be_false();
end GenerateCompilesAndMatches;

procedure GenerateEscaping is
  vGrammar varchar2(1000) := 'r = "it''s" %d13.10 %x01 %s"Q"';
  vCode    clob := P_ABNF_Engine.GeneratePLSQLFromABNF(vGrammar);
  vInput   varchar2(100) := 'IT''S' || chr(13) || chr(10) || chr(1) || 'Q';
begin
  ut.expect(RunGenerated(vCode, 'r', vInput)).to_equal(1);
  ut.expect(RunGenerated(vCode, 'r', replace(vInput, 'Q', 'q'))).to_equal(0);
end GenerateEscaping;

procedure GenerateInvalidGrammarRaises is
  vCode clob;
begin
  vCode := P_ABNF_Engine.GeneratePLSQLFromABNF('r = (');
end GenerateInvalidGrammarRaises;

------------------------------------------------------------------------------
-- ValidateInput / ExplainMismatch
------------------------------------------------------------------------------
procedure ValidateInputProcedure is
  vRules          TY_ABNF_RuleSet := P_ABNF_Engine.ParseGrammar('r = "ab" DIGIT');
  vIsValid        boolean;
  vErrorPosition  integer;
  vFailedNodeName varchar2(4000);
  vErrorMessage   varchar2(4000);
begin
  P_ABNF_Engine.ValidateInput(vRules, null, 'ab1', vIsValid, vErrorPosition, vFailedNodeName, vErrorMessage);
  ut.expect(vIsValid).to_be_true();
  ut.expect(vErrorPosition).to_be_null();
  ut.expect(vErrorMessage).to_be_null();

  P_ABNF_Engine.ValidateInput(vRules, 'r', 'abx', vIsValid, vErrorPosition, vFailedNodeName, vErrorMessage);
  ut.expect(vIsValid).to_be_false();
  ut.expect(vErrorPosition).to_equal(3);
  ut.expect(vFailedNodeName).to_equal('DIGIT');
  ut.expect(vErrorMessage).to_equal('Line 1, column 3: found "x", expected DIGIT (while matching rule: r)');

  P_ABNF_Engine.ValidateInput(vRules, 'r', 'ab1c', vIsValid, vErrorPosition, vFailedNodeName, vErrorMessage);
  ut.expect(vIsValid).to_be_false();
  ut.expect(vErrorPosition).to_equal(4);
  ut.expect(vFailedNodeName).to_equal('UNEXPECTED_TRAILING_INPUT');

  P_ABNF_Engine.ValidateInput(null, 'ab1', vIsValid, vErrorPosition, vFailedNodeName, vErrorMessage);
  ut.expect(vIsValid).to_be_false();
  ut.expect(vErrorMessage).to_equal('Root rule node is null.');
end ValidateInputProcedure;

procedure ExplainValid is
  vRules TY_ABNF_RuleSet := P_ABNF_Engine.ParseGrammar('r = "ab" DIGIT');
begin
  ut.expect(P_ABNF_Engine.ExplainMismatch(vRules, 'r', 'ab1')).to_be_null();
end ExplainValid;

procedure ExplainUnexpectedCharacter is
  vRules TY_ABNF_RuleSet := P_ABNF_Engine.ParseGrammar('r = "ab" DIGIT');
begin
  ut.expect(P_ABNF_Engine.ExplainMismatch(vRules, 'r', 'abx'))
    .to_equal('Line 1, column 3: found "x", expected DIGIT (while matching rule: r)');
  -- failing on the first character of the start rule keeps the specific detail
  ut.expect(P_ABNF_Engine.ExplainMismatch(vRules, 'r', 'xb1'))
    .to_equal('Line 1, column 1: found "x", expected "ab" (while matching rule: r)');
end ExplainUnexpectedCharacter;

procedure ExplainEndOfInput is
  vRules TY_ABNF_RuleSet := P_ABNF_Engine.ParseGrammar('r = "ab" DIGIT');
begin
  ut.expect(P_ABNF_Engine.ExplainMismatch(vRules, 'r', 'ab'))
    .to_equal('Line 1, column 3: unexpected end of input, expected DIGIT (while matching rule: r)');
end ExplainEndOfInput;

procedure ExplainTrailingInput is
  vRules TY_ABNF_RuleSet := P_ABNF_Engine.ParseGrammar('r = "ab"');
begin
  ut.expect(P_ABNF_Engine.ExplainMismatch(vRules, 'r', 'abc'))
    .to_equal('Line 1, column 3: unexpected input "c" after a complete match of 2 character(s), expected end of input');
end ExplainTrailingInput;

procedure ExplainAlternatives is
  vRules TY_ABNF_RuleSet := P_ABNF_Engine.ParseGrammar('r = "a" ("b" / "c")');
begin
  ut.expect(P_ABNF_Engine.ExplainMismatch(vRules, 'r', 'ax'))
    .to_equal('Line 1, column 2: found "x", expected one of: "b", "c" (while matching rule: r)');
end ExplainAlternatives;

procedure ExplainLineAndColumn is
  vRules TY_ABNF_RuleSet := P_ABNF_Engine.ParseGrammar('r = "a" LF "b"');
begin
  ut.expect(P_ABNF_Engine.ExplainMismatch(vRules, 'r', 'a' || NL || 'x'))
    .to_equal('Line 2, column 1: found "x", expected "b" (while matching rule: r)');
  -- control characters are shown escaped
  ut.expect(P_ABNF_Engine.ExplainMismatch(vRules, 'r', 'a' || chr(9)))
    .to_equal('Line 1, column 2: found "\t", expected LF (while matching rule: r)');
end ExplainLineAndColumn;

procedure ExplainProse is
  vRules TY_ABNF_RuleSet := P_ABNF_Engine.ParseGrammar('r = "a" <something clever>');
begin
  ut.expect(P_ABNF_Engine.ExplainMismatch(vRules, 'r', 'ab'))
    .to_be_like('%<something clever> (prose cannot be evaluated)%');
end ExplainProse;

procedure ExplainStructured is
  vRules    TY_ABNF_RuleSet := P_ABNF_Engine.ParseGrammar('r = "a" LF "b"');
  vIsValid  boolean;
  vPosition integer;
  vLine     integer;
  vColumn   integer;
  vFound    varchar2(10);
  vExpected TY_ABNF_StrList;
  vMessage  varchar2(4000);
begin
  P_ABNF_Engine.ExplainMismatch(vRules, 'r', 'a' || NL || 'x', vIsValid, vPosition, vLine, vColumn, vFound, vExpected, vMessage);
  ut.expect(vIsValid).to_be_false();
  ut.expect(vPosition).to_equal(3);
  ut.expect(vLine).to_equal(2);
  ut.expect(vColumn).to_equal(1);
  ut.expect(vFound).to_equal('x');
  ut.expect(vExpected.count).to_equal(1);
  ut.expect(vExpected(1)).to_equal('"b"');
  ut.expect(vMessage).to_be_like('Line 2, column 1:%');

  P_ABNF_Engine.ExplainMismatch(vRules, 'r', 'a' || NL || 'b', vIsValid, vPosition, vLine, vColumn, vFound, vExpected, vMessage);
  ut.expect(vIsValid).to_be_true();
  ut.expect(vMessage).to_be_null();
  ut.expect(vFound).to_be_null();
end ExplainStructured;

procedure ExplainNodeTree is
  vNode TY_ABNF_Node := TY_ABNF_Sequence(
                          NODE_NAME   => null
                        , CHILD_NODES => TY_ABNF_NodeList(
                                           TY_ABNF_Literal(NODE_NAME => null, VALUE => 'ab')
                                         , P_ABNF_Engine.CoreDigit()
                                         )
                        );
begin
  ut.expect(P_ABNF_Engine.ExplainMismatch(vNode, 'ab5')).to_be_null();
  ut.expect(P_ABNF_Engine.ExplainMismatch(vNode, 'abx')).to_equal('Line 1, column 3: found "x", expected %x30-39');
end ExplainNodeTree;

------------------------------------------------------------------------------
-- Tokenise
------------------------------------------------------------------------------
-- Tokens as 'RULE:text' joined with '|'
function TokensOf(pGrammar varchar2, pTokenRules varchar2, pInput varchar2) return varchar2 is
  vResult varchar2(4000);
begin
  select listagg(t.RULE_NAME || ':' || t.TEXT, '|') within group (order by t.SEQ)
  into vResult
  from table(P_ABNF_Engine.Tokenise(pGrammar, pTokenRules, pInput)) t;
  return vResult;
end TokensOf;

procedure TokeniseBasic is
  vGrammar varchar2(200) := 'int = 1*DIGIT' || NL || 'op = "+" / "-"' || NL || 'ws = 1*SP';
  vSeq     integer;
  vName    varchar2(128);
  vPos     integer;
  vLength  integer;
  vText    varchar2(4000);
begin
  ut.expect(TokensOf(vGrammar, 'int,op,ws', '12 + 345')).to_equal('int:12|ws: |op:+|ws: |int:345');

  select t.SEQ, t.RULE_NAME, t.START_POS, t.TOKEN_LENGTH, t.TEXT
  into vSeq, vName, vPos, vLength, vText
  from table(P_ABNF_Engine.Tokenise(vGrammar, 'int,op,ws', '12 + 345')) t
  where t.SEQ = 5;
  ut.expect(vName).to_equal('int');
  ut.expect(vPos).to_equal(6);
  ut.expect(vLength).to_equal(3);
  ut.expect(vText).to_equal('345');
end TokeniseBasic;

procedure TokeniseLongestMatch is
  vGrammar varchar2(200) := 'kw = "if"' || NL || 'ident = 1*ALPHA';
begin
  -- "iffy" is one identifier, not the keyword "if" followed by "fy"
  ut.expect(TokensOf(vGrammar, 'kw,ident', 'iffy')).to_equal('ident:iffy');
  ut.expect(TokensOf(vGrammar, 'ident,kw', 'iffy')).to_equal('ident:iffy');
end TokeniseLongestMatch;

procedure TokeniseTieFirstListed is
  vGrammar varchar2(200) := 'kw = "if"' || NL || 'ident = 1*ALPHA';
begin
  ut.expect(TokensOf(vGrammar, 'kw,ident', 'if')).to_equal('kw:if');
  ut.expect(TokensOf(vGrammar, 'ident,kw', 'if')).to_equal('ident:if');
  -- names are matched case-insensitively but reported as the caller wrote them
  ut.expect(TokensOf(vGrammar, 'KW,Ident', 'if')).to_equal('KW:if');
end TokeniseTieFirstListed;

procedure TokeniseAllRules is
  vGrammar varchar2(200) := 'word = 1*ALPHA' || NL || 'num = 1*DIGIT';
begin
  ut.expect(TokensOf(vGrammar, null, 'ab12cd')).to_equal('word:ab|num:12|word:cd');
end TokeniseAllRules;

procedure TokeniseRuleSetAndCore is
  vRules   TY_ABNF_RuleSet := P_ABNF_Engine.ParseGrammar('word = 1*ALPHA');
  vResult  varchar2(4000);
begin
  select listagg(t.RULE_NAME || ':' || t.TEXT, '|') within group (order by t.SEQ)
  into vResult
  from table(P_ABNF_Engine.Tokenise(vRules, 'word,DIGIT,SP', 'ab 1 2')) t;
  ut.expect(vResult).to_equal('word:ab|SP: |DIGIT:1|SP: |DIGIT:2');
end TokeniseRuleSetAndCore;

procedure TokeniseEmptyInput is
begin
  ut.expect(TokensOf('word = 1*ALPHA', 'word', null)).to_be_null();
  ut.expect(TokensOf('word = 1*ALPHA', 'word', '')).to_be_null();
end TokeniseEmptyInput;

procedure TokeniseZeroLength is
  vGrammar varchar2(200) := 'maybe = *DIGIT' || NL || 'word = 1*ALPHA';
begin
  -- "maybe" matches nothing at "a", so "word" supplies the token instead; no endless loop
  ut.expect(TokensOf(vGrammar, 'maybe,word', 'ab12')).to_equal('word:ab|maybe:12');
end TokeniseZeroLength;

procedure TokeniseNoMatchMessage is
  vMessage varchar2(4000);
  vResult  varchar2(4000);
begin
  begin
    vResult := TokensOf('word = 1*ALPHA' || NL || 'num = 1*DIGIT', 'word,num', 'ab12#d');
  exception
    when OTHERS then
      vMessage := SQLERRM;
  end;
  ut.expect(vMessage).to_be_like('%ORA-20120: Line 1, column 5: found "#", which does not start any token. Rules tried: word, num%');
end TokeniseNoMatchMessage;

procedure TokeniseUnknownRule is
  vResult varchar2(4000);
begin
  vResult := TokensOf('word = 1*ALPHA', 'word,nothing', 'ab');
end TokeniseUnknownRule;

procedure TokeniseManyTokens is
  vCount integer;
  vFirst integer;
  vLast  integer;
begin
  -- "ab ab ab ..." gives 1000 words and 1000 spaces
  select count(*), min(t.START_POS), max(t.START_POS)
  into vCount, vFirst, vLast
  from table(P_ABNF_Engine.Tokenise('w = 1*ALPHA' || NL || 's = 1*SP', 'w,s', rpad('ab ', 3000, 'ab '))) t;
  ut.expect(vCount).to_equal(2000);
  ut.expect(vFirst).to_equal(1);
  ut.expect(vLast).to_equal(3000);
end TokeniseManyTokens;

------------------------------------------------------------------------------
-- ParseTree
------------------------------------------------------------------------------
-- Rows as 'rule:depth:start:length' joined with '|', in document order
function TreeOf(pGrammar varchar2, pStartRule varchar2, pInput varchar2) return varchar2 is
  vResult varchar2(4000);
begin
  select listagg(t.RULE_NAME || ':' || t.DEPTH || ':' || t.START_POS || ':' || t.NODE_LENGTH, '|')
           within group (order by t.NODE_ID)
  into vResult
  from table(P_ABNF_Engine.ParseTree(pGrammar, pStartRule, pInput)) t;
  return vResult;
end TreeOf;

procedure ParseTreeStructure is
  vGrammar varchar2(200) := 'pair = key "=" value' || NL || 'key = 1*ALPHA' || NL || 'value = 1*DIGIT';
begin
  ut.expect(TreeOf(vGrammar, 'pair', 'ab=12')).to_equal('pair:0:1:5|key:1:1:2|value:1:4:2');
end ParseTreeStructure;

procedure ParseTreeParents is
  vParent integer;
  vText   varchar2(4000);
begin
  select t.PARENT_ID, t.TEXT
  into vParent, vText
  from table(P_ABNF_Engine.ParseTree(
         'pair = key "=" value' || NL || 'key = 1*ALPHA' || NL || 'value = 1*DIGIT', 'pair', 'ab=12'
       )) t
  where t.RULE_NAME = 'value';
  ut.expect(vParent).to_equal(1);
  ut.expect(vText).to_equal('12');

  select t.PARENT_ID
  into vParent
  from table(P_ABNF_Engine.ParseTree('pair = key "=" key' || NL || 'key = 1*ALPHA', 'pair', 'a=b')) t
  where t.NODE_ID = 1;
  ut.expect(vParent).to_be_null();
end ParseTreeParents;

procedure ParseTreeHidesCoreRules is
begin
  ut.expect(TreeOf('r = 1*DIGIT', 'r', '123')).to_equal('r:0:1:3');
  -- defined in the grammar itself, so listed
  ut.expect(TreeOf('r = 1*DIGIT' || NL || 'DIGIT = %x30-39', 'r', '12')).to_equal('r:0:1:2|DIGIT:1:1:1|DIGIT:1:2:1');
end ParseTreeHidesCoreRules;

procedure ParseTreeEmptyMatch is
  vGrammar varchar2(200) := 'record = field *("," field)' || NL || 'field = *ALPHA';
begin
  ut.expect(TreeOf(vGrammar, 'record', 'a,,b'))
    .to_equal('record:0:1:4|field:1:1:1|field:1:3:0|field:1:4:1');
end ParseTreeEmptyMatch;

procedure ParseTreeBacktracking is
  vGrammar varchar2(200) := 'r = a "bc"' || NL || 'a = "a" / "ab"';
begin
  -- the longer "ab" is tried first, leaves "c" which is not "bc", and must leave no row behind before "a" is used
  ut.expect(TreeOf(vGrammar, 'r', 'abc')).to_equal('r:0:1:3|a:1:1:1');
  -- here the longer reading is the one that works
  ut.expect(TreeOf(vGrammar, 'r', 'abbc')).to_equal('r:0:1:4|a:1:1:2');
end ParseTreeBacktracking;

procedure ParseTreeRecursive is
begin
  ut.expect(TreeOf('r = "(" [r] ")"', 'r', '(())')).to_equal('r:0:1:4|r:1:2:2');
end ParseTreeRecursive;

procedure ParseTreeCsv is
  vCsv     varchar2(2000) :=
       'file = [header CRLF] record *(CRLF record) [CRLF]' || NL
    || 'header = name *(COMMA name)' || NL
    || 'record = field *(COMMA field)' || NL
    || 'name = field' || NL
    || 'field = (escaped / non-escaped)' || NL
    || 'escaped = DQUOTE *(TEXTDATA / COMMA / CR / LF / 2DQUOTE) DQUOTE' || NL
    || 'non-escaped = *TEXTDATA' || NL
    || 'COMMA = %x2C' || NL
    || 'CR = %x0D' || NL
    || 'DQUOTE = %x22' || NL
    || 'LF = %x0A' || NL
    || 'CRLF = CR LF' || NL
    || 'TEXTDATA = %x20-21 / %x23-2B / %x2D-7E';
  vInput   varchar2(200) := 'a,b' || chr(13) || chr(10) || '1,"x' || chr(13) || chr(10) || 'y",' || chr(13) || chr(10) || '3,4,5';
  vHeaders integer;
  vRecords integer;
  vFields  integer;
  vQuoted  varchar2(4000);
  vEmpty   integer;
  vRecord1 integer;
  vRecord3 integer;
begin
  select count(case when t.RULE_NAME = 'header' then 1 end)
       , count(case when t.RULE_NAME = 'record' then 1 end)
       , count(case when t.RULE_NAME = 'field' then 1 end)
  into vHeaders, vRecords, vFields
  from table(P_ABNF_Engine.ParseTree(vCsv, 'file', vInput)) t;

  -- the header is optional; the reading that uses it is preferred
  ut.expect(vHeaders).to_equal(1);
  ut.expect(vRecords).to_equal(2);
  -- 2 header names + 3 fields in record 1 (the last one empty) + 3 in record 2
  ut.expect(vFields).to_equal(8);

  -- a quoted field holds its line break
  select t.TEXT
  into vQuoted
  from table(P_ABNF_Engine.ParseTree(vCsv, 'file', vInput)) t
  where t.RULE_NAME = 'escaped';
  ut.expect(vQuoted).to_equal('"x' || chr(13) || chr(10) || 'y"');

  -- the empty last field of the first record is listed, with length 0
  select count(*)
  into vEmpty
  from table(P_ABNF_Engine.ParseTree(vCsv, 'file', vInput)) t
  where t.RULE_NAME = 'field'
    and t.NODE_LENGTH = 0;
  ut.expect(vEmpty).to_equal(1);

  -- fields can be assigned to their record and column through PARENT_ID
  select count(*)
  into vRecord1
  from table(P_ABNF_Engine.ParseTree(vCsv, 'file', vInput)) f
  join table(P_ABNF_Engine.ParseTree(vCsv, 'file', vInput)) r on r.NODE_ID = f.PARENT_ID
  where f.RULE_NAME = 'field'
    and r.RULE_NAME = 'record'
    and r.START_POS = (
      select min(r2.START_POS)
      from table(P_ABNF_Engine.ParseTree(vCsv, 'file', vInput)) r2
      where r2.RULE_NAME = 'record'
    );
  ut.expect(vRecord1).to_equal(3);
end ParseTreeCsv;

procedure ParseTreeRuleSetOverload is
  vRules TY_ABNF_RuleSet := P_ABNF_Engine.ParseGrammar('pair = key "=" value' || NL || 'key = 1*ALPHA' || NL || 'value = 1*DIGIT');
  vResult varchar2(4000);
begin
  select listagg(t.RULE_NAME || ':' || t.TEXT, '|') within group (order by t.NODE_ID)
  into vResult
  from table(P_ABNF_Engine.ParseTree(vRules, 'pair', 'ab=12')) t;
  ut.expect(vResult).to_equal('pair:ab=12|key:ab|value:12');
end ParseTreeRuleSetOverload;

procedure ParseTreeMismatch is
  vMessage varchar2(4000);
  vResult  varchar2(4000);
begin
  begin
    vResult := TreeOf('pair = key "=" value' || NL || 'key = 1*ALPHA' || NL || 'value = 1*DIGIT', 'pair', 'ab=1x');
  exception
    when OTHERS then
      vMessage := SQLERRM;
  end;
  ut.expect(vMessage).to_be_like('%ORA-20121: Input does not match: Line 1, column 5:%');
end ParseTreeMismatch;

procedure ParseTreeDefaultStartRule is
begin
  ut.expect(TreeOf('top = leaf' || NL || 'leaf = "x"', null, 'x')).to_equal('top:0:1:1|leaf:1:1:1');
end ParseTreeDefaultStartRule;

end P_UT_ABNF_Engine;
/
