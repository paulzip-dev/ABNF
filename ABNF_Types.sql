--------------------------------------------------------------------------------
-- Augmented Backus Naur Form Object Types
-- Copyright (c) 2026 Paul Scott
--
-- The object types behind P_ABNF_Engine. A grammar is a tree of TY_ABNF_Node subtypes (Literal, Range, Sequence,
-- Alternative, Repetition, RuleRef, Prose), each with a MatchInput method. Named rules are held in a TY_ABNF_RuleSet,
-- matching state in TY_ABNF_Context / TY_ABNF_RuleContext, and TY_ABNF_Token / ParseNode / CsvField (+ list types) are
-- the rows returned by Tokenise, ParseTree and ParseCsv. The block below drops every type first, in dependency order,
-- so installing this script invalidates the packages: rerun the whole build.
--------------------------------------------------------------------------------

declare
  procedure ExecDDL(pDDL varchar2) is
  begin
    dbms_output.put_line(pDDL || ';');
    execute immediate pDDL;
  end;
  function TypeExists(pTypeName varchar2) return boolean is
    vCount integer;
  begin
    select count(*)
    into vCount
    from user_types
    where TYPE_NAME = pTypeName;
    return vCount > 0;
  end;
  procedure DropType(pTypeName varchar2) is
  begin
    if TypeExists(pTypeName) then
      ExecDDL('drop type ' || pTypeName || ' force');
    end if;
  end;
begin
  DropType('TY_ABNF_CSVFIELDLIST');
  DropType('TY_ABNF_CSVFIELD');
  DropType('TY_ABNF_PARSENODELIST');
  DropType('TY_ABNF_PARSENODE');
  DropType('TY_ABNF_TOKENLIST');
  DropType('TY_ABNF_TOKEN');
  DropType('TY_ABNF_RULECONTEXT');
  DropType('TY_ABNF_RULESET');
  DropType('TY_ABNF_RULE');
  DropType('TY_ABNF_RULEREF');
  DropType('TY_ABNF_PROSE');
  DropType('TY_ABNF_REPETITION');
  DropType('TY_ABNF_ALTERNATIVE');
  DropType('TY_ABNF_SEQUENCE');
  DropType('TY_ABNF_RANGE');
  DropType('TY_ABNF_LITERAL');
  DropType('TY_ABNF_NODELIST');
  DropType('TY_ABNF_NODE');
  DropType('TY_ABNF_CONTEXT');
  DropType('TY_ABNF_POSLIST');
  DropType('TY_ABNF_STRLIST');
end;
/

--------------------------------------------------------------------------------
-- Matching contract
--
-- Every node implements MatchInput(pInput, pOffset, pCtx) and returns the list
-- of ALL positions at which a match starting at pOffset can end (the offset of
-- the first character after the match). An empty list means "no match".
-- Returning every possibility (rather than the first) is what gives real ABNF
-- semantics: alternation is unordered, so later elements can force an earlier
-- choice to be reconsidered (backtracking).
--
-- pCtx collects what was expected at the furthest failure position, so
-- mismatches can be explained. TY_ABNF_Context holds no nodes (nodes take it as
-- a parameter, so it cannot refer back to them); the subtype TY_ABNF_RuleContext
-- adds the rule registry that TY_ABNF_RuleRef nodes look rules up in.
--------------------------------------------------------------------------------

create or replace
type TY_ABNF_StrList as table of varchar2(4000);
/

create or replace
type TY_ABNF_PosList as table of integer;
/

--------------------------------------------------------------------------------
-- A piece of input recognised by P_ABNF_Engine.Tokenise
--------------------------------------------------------------------------------
create or replace
type TY_ABNF_Token as object (
  SEQ          integer         -- 1, 2, 3 ... in input order
, RULE_NAME    varchar2(128)   -- the token rule that matched, as named by the caller
, START_POS    integer         -- 1-based position of the first character
, TOKEN_LENGTH integer         -- number of characters (always > 0)
, TEXT         varchar2(4000)  -- the matched text (truncated at 4000 characters)
);
/

create or replace
type TY_ABNF_TokenList as table of TY_ABNF_Token;
/

--------------------------------------------------------------------------------
-- One matched rule in the parse tree returned by P_ABNF_Engine.ParseTree
--------------------------------------------------------------------------------
create or replace
type TY_ABNF_ParseNode as object (
  NODE_ID     integer         -- 1, 2, 3 ... in document order (a parent comes before its children)
, PARENT_ID   integer         -- NODE_ID of the enclosing rule match; null for the root
, DEPTH       integer         -- 0 for the root
, RULE_NAME   varchar2(128)   -- as named in the grammar's rule definition
, START_POS   integer         -- 1-based position of the first character
, NODE_LENGTH integer         -- number of characters; 0 for a rule that matched nothing
, TEXT        varchar2(4000)  -- the matched text (truncated at 4000 characters)
);
/

create or replace
type TY_ABNF_ParseNodeList as table of TY_ABNF_ParseNode;
/

--------------------------------------------------------------------------------
-- One CSV field as returned by P_ABNF_CSV.ParseCsv
--------------------------------------------------------------------------------
create or replace
type TY_ABNF_CsvField as object (
  RECORD_NO integer         -- 1, 2, 3 ... line by line (a quoted field may span several physical lines)
, FIELD_NO  integer         -- 1, 2, 3 ... within the record
, IS_HEADER varchar2(1)     -- 'Y' for the header record (the first record, when the caller says there is one)
, IS_QUOTED varchar2(1)     -- 'Y' if the field was written in double quotes
, START_POS integer         -- 1-based position of the field in the input, including any opening quote
, VALUE     varchar2(4000)  -- the field with quotes removed and "" turned into " (truncated at 4000 characters)
);
/

create or replace
type TY_ABNF_CsvFieldList as table of TY_ABNF_CsvField;
/

--------------------------------------------------------------------------------
-- Matching context: failure tracking and the active rule stack
--------------------------------------------------------------------------------
create or replace
type TY_ABNF_Context as object (
  FAIL_POS    integer           -- furthest offset at which something failed to match
, EXPECTED    TY_ABNF_StrList   -- what would have matched at FAIL_POS
, FAIL_PATH   varchar2(4000)    -- rule path active when FAIL_POS was reached
, STACK_NAMES TY_ABNF_StrList   -- rules currently being evaluated
, STACK_POS   TY_ABNF_PosList   -- offset at which each of those rules started
, static function Escape(pText varchar2) return varchar2
, member function StackPath return varchar2
, member procedure AddExpected(
    self  in out nocopy TY_ABNF_Context
  , pPos  integer
  , pText varchar2
  )
, member procedure Summarise(
    self         in out nocopy TY_ABNF_Context
  , pPos         integer
  , pBeforePos   integer
  , pBeforeCount integer
  , pName        varchar2
  , pForce       boolean
  )
, member procedure PushRule(
    self  in out nocopy TY_ABNF_Context
  , pName varchar2
  , pPos  integer
  )
, member procedure PopRule(self in out nocopy TY_ABNF_Context)
) not final;
/

create or replace
type body TY_ABNF_Context is

  -- Makes control characters visible in messages
  static function Escape(pText varchar2) return varchar2 is
  begin
    return replace(replace(replace(pText, chr(13), '\r'), chr(10), '\n'), chr(9), '\t');
  end Escape;

  -- Records what was expected at pPos. Only the furthest position is kept.
  -- The rules being evaluated, outermost first: "a > b > c"
  member function StackPath return varchar2 is
    vPath varchar2(4000);
  begin
    for i in 1..self.STACK_NAMES.count
    loop
      if i > 1 then
        vPath := vPath || ' > ';
      end if;
      vPath := substr(vPath || self.STACK_NAMES(i), 1, 4000);
    end loop;
    return vPath;
  end StackPath;

  -- Records what was expected at pPos. Only the furthest position is kept.
  member procedure AddExpected(
    self  in out nocopy TY_ABNF_Context
  , pPos  integer
  , pText varchar2
  ) is
  begin
    if pPos > self.FAIL_POS then
      self.FAIL_POS  := pPos;
      self.EXPECTED  := TY_ABNF_StrList(pText);
      self.FAIL_PATH := self.StackPath;
    elsif pPos = self.FAIL_POS then
      if self.EXPECTED.count < 50 and not (pText member of self.EXPECTED) then
        self.EXPECTED.extend;
        self.EXPECTED(self.EXPECTED.count) := pText;
      end if;
    end if;
  end AddExpected;

  -- A named node failed at pPos: replace the detail recorded during its evaluation with its own name,
  -- unless it got further than pPos before failing (the detail is then more useful than the name).
  -- Unless pForce, a node that only had one thing to expect keeps that more specific detail.
  member procedure Summarise(
    self         in out nocopy TY_ABNF_Context
  , pPos         integer
  , pBeforePos   integer
  , pBeforeCount integer
  , pName        varchar2
  , pForce       boolean
  ) is
    vAdded integer := 0;
  begin
    if self.FAIL_POS <= pPos then
      if self.FAIL_POS = pPos then
        vAdded := case when pBeforePos = pPos then self.EXPECTED.count - pBeforeCount else self.EXPECTED.count end;
      end if;

      if pForce or vAdded > 1 or self.FAIL_POS < pPos then
        if self.FAIL_POS = pPos then
          if pBeforePos = pPos then
            self.EXPECTED.trim(vAdded);
          else
            self.EXPECTED := TY_ABNF_StrList();
          end if;
          self.FAIL_PATH := self.StackPath;
        end if;
        self.AddExpected(pPos, pName);
      end if;
    end if;
  end Summarise;

  member procedure PushRule(
    self  in out nocopy TY_ABNF_Context
  , pName varchar2
  , pPos  integer
  ) is
  begin
    -- Same rule at the same offset already active: left recursion would never terminate
    for i in reverse 1..self.STACK_POS.count
    loop
      exit when self.STACK_POS(i) < pPos;
      if upper(self.STACK_NAMES(i)) = upper(pName) then
        raise_application_error(
          -20102
        , 'Left recursion detected in rule "' || pName || '" at position ' || to_char(pPos)
        );
      end if;
    end loop;

    self.STACK_NAMES.extend;
    self.STACK_NAMES(self.STACK_NAMES.count) := pName;
    self.STACK_POS.extend;
    self.STACK_POS(self.STACK_POS.count) := pPos;
  end PushRule;

  member procedure PopRule(self in out nocopy TY_ABNF_Context) is
  begin
    self.STACK_NAMES.trim;
    self.STACK_POS.trim;
  end PopRule;

end;
/

create or replace
type TY_ABNF_Node as object (
  NODE_NAME varchar2(128)
, member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pCtx            in out nocopy TY_ABNF_Context
  ) return TY_ABNF_PosList
) not final not instantiable;
/

create or replace
type body TY_ABNF_Node is

  member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pCtx            in out nocopy TY_ABNF_Context
  ) return TY_ABNF_PosList is
  begin
    return TY_ABNF_PosList();
  end MatchInput;

end;
/

create or replace
type TY_ABNF_NodeList as table of TY_ABNF_Node;
/

--------------------------------------------------------------------------------
-- A named rule: the grammar rule name, its comment text and its definition
--------------------------------------------------------------------------------
create or replace
type TY_ABNF_Rule as object (
  RULE_NAME    varchar2(128)
, COMMENT_TEXT varchar2(4000)
, RULE_NODE    TY_ABNF_Node
);
/

create or replace
type TY_ABNF_RuleSet as table of TY_ABNF_Rule;
/

--------------------------------------------------------------------------------
-- Matching context that also holds the rules TY_ABNF_RuleRef nodes refer to
--------------------------------------------------------------------------------
create or replace
type TY_ABNF_RuleContext under TY_ABNF_Context (
  RULES TY_ABNF_RuleSet
, static function NewContext(pRules TY_ABNF_RuleSet) return TY_ABNF_RuleContext
, member function FindRule(pName varchar2) return TY_ABNF_Node
);
/

create or replace
type body TY_ABNF_RuleContext is

  static function NewContext(pRules TY_ABNF_RuleSet) return TY_ABNF_RuleContext is
  begin
    return TY_ABNF_RuleContext(
             0
           , TY_ABNF_StrList()
           , null
           , TY_ABNF_StrList()
           , TY_ABNF_PosList()
           , nvl(pRules, TY_ABNF_RuleSet())
           );
  end NewContext;

  member function FindRule(pName varchar2) return TY_ABNF_Node is
    vResult TY_ABNF_Node;
  begin
    for i in 1..self.RULES.count
    loop
      if upper(self.RULES(i).RULE_NAME) = upper(pName) then
        vResult := self.RULES(i).RULE_NODE;
        exit;
      end if;
    end loop;
    return vResult;
  end FindRule;

end;
/

--------------------------------------------------------------------------------
-- "text" (case-insensitive, RFC 5234), %s"text" (case-sensitive) and %i"text"
-- (case-insensitive) (RFC 7405), and %d13.10 style numeric strings
-- (case-sensitive). CASE_SENSITIVE is 'Y' or 'N'; null means 'N'.
--------------------------------------------------------------------------------
create or replace
type TY_ABNF_Literal under TY_ABNF_Node (
  VALUE          varchar2(32767)
, CASE_SENSITIVE varchar2(1)
, constructor function TY_ABNF_Literal(
    self  in out nocopy TY_ABNF_Literal
  , NODE_NAME varchar2
  , VALUE     varchar2
  ) return self as result
, overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pCtx            in out nocopy TY_ABNF_Context
  ) return TY_ABNF_PosList
);
/

create or replace
type body TY_ABNF_Literal is

  -- Two-argument form kept for existing callers: ABNF literals are case-insensitive by default
  constructor function TY_ABNF_Literal(
    self  in out nocopy TY_ABNF_Literal
  , NODE_NAME varchar2
  , VALUE     varchar2
  ) return self as result is
  begin
    self.NODE_NAME      := NODE_NAME;
    self.VALUE          := VALUE;
    self.CASE_SENSITIVE := 'N';
    return;
  end TY_ABNF_Literal;

  overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pCtx            in out nocopy TY_ABNF_Context
  ) return TY_ABNF_PosList is
    vResult  TY_ABNF_PosList := TY_ABNF_PosList();
    vLen     integer := nvl(length(self.VALUE), 0);
    vMatches boolean;
  begin
    if vLen = 0 then
      -- An empty string matches without consuming anything
      vResult := TY_ABNF_PosList(pOffset);
    else
      if self.CASE_SENSITIVE = 'Y' then
        vMatches := substr(pInput, pOffset, vLen) = self.VALUE;
      else
        vMatches := lower(substr(pInput, pOffset, vLen)) = lower(self.VALUE);
      end if;

      if vMatches then
        vResult := TY_ABNF_PosList(pOffset + vLen);
      else
        pCtx.AddExpected(pOffset, '"' || TY_ABNF_Context.Escape(self.VALUE) || '"');
      end if;
    end if;

    return vResult;
  end MatchInput;

end;
/

--------------------------------------------------------------------------------
-- %x30-39 style character range (a single character whose code is in range)
--------------------------------------------------------------------------------
create or replace
type TY_ABNF_Range under TY_ABNF_Node (
  MIN_CODE integer
, MAX_CODE integer
, overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pCtx            in out nocopy TY_ABNF_Context
  ) return TY_ABNF_PosList
);
/

create or replace
type body TY_ABNF_Range is

  overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pCtx            in out nocopy TY_ABNF_Context
  ) return TY_ABNF_PosList is
    vResult TY_ABNF_PosList := TY_ABNF_PosList();
    vCode   integer;
  begin
    if pOffset <= nvl(length(pInput), 0) then
      vCode := ascii(substr(pInput, pOffset, 1));
      if vCode >= self.MIN_CODE and vCode <= self.MAX_CODE then
        vResult := TY_ABNF_PosList(pOffset + 1);
      end if;
    end if;

    if vResult.count = 0 then
      pCtx.AddExpected(
        pOffset
      , '%x' || lpad(to_char(self.MIN_CODE, 'FMXXXXXXXX'), 2, '0')
        || case when self.MAX_CODE <> self.MIN_CODE
             then '-' || lpad(to_char(self.MAX_CODE, 'FMXXXXXXXX'), 2, '0')
           end
      );
    end if;

    return vResult;
  end MatchInput;

end;
/

--------------------------------------------------------------------------------
-- <prose description>. Prose cannot be evaluated, so it never matches.
--------------------------------------------------------------------------------
create or replace
type TY_ABNF_Prose under TY_ABNF_Node (
  TEXT varchar2(4000)
, overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pCtx            in out nocopy TY_ABNF_Context
  ) return TY_ABNF_PosList
);
/

create or replace
type body TY_ABNF_Prose is

  overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pCtx            in out nocopy TY_ABNF_Context
  ) return TY_ABNF_PosList is
  begin
    pCtx.AddExpected(pOffset, '<' || self.TEXT || '> (prose cannot be evaluated)');
    return TY_ABNF_PosList();
  end MatchInput;

end;
/

--------------------------------------------------------------------------------
-- Reference to another rule by (case-insensitive) name
--------------------------------------------------------------------------------
create or replace
type TY_ABNF_RuleRef under TY_ABNF_Node (
  RULE_NAME varchar2(128)
, overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pCtx            in out nocopy TY_ABNF_Context
  ) return TY_ABNF_PosList
);
/

create or replace
type body TY_ABNF_RuleRef is

  overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pCtx            in out nocopy TY_ABNF_Context
  ) return TY_ABNF_PosList is
    vResult      TY_ABNF_PosList;
    vRuleCtx     TY_ABNF_RuleContext := treat(pCtx as TY_ABNF_RuleContext);
    vTarget      TY_ABNF_Node;
    vBeforePos   integer;
    vBeforeCount integer;
  begin
    if vRuleCtx is null then
      raise_application_error(-20103, 'Rule "' || self.RULE_NAME || '" cannot be resolved: the matching context has no rules');
    end if;
    vTarget := vRuleCtx.FindRule(self.RULE_NAME);
    if vTarget is null then
      raise_application_error(-20101, 'Undefined rule "' || self.RULE_NAME || '"');
    end if;

    pCtx.PushRule(self.RULE_NAME, pOffset);
    vBeforePos   := pCtx.FAIL_POS;
    vBeforeCount := pCtx.EXPECTED.count;

    vResult := vTarget.MatchInput(pInput => pInput, pOffset => pOffset, pCtx => pCtx);

    pCtx.PopRule;
    -- The start rule (nothing left on the stack) keeps the more specific detail
    if vResult.count = 0 and pCtx.STACK_POS.count > 0 then
      pCtx.Summarise(pOffset, vBeforePos, vBeforeCount, self.RULE_NAME, True);
    end if;

    return vResult;
  end MatchInput;

end;
/

--------------------------------------------------------------------------------
-- Concatenation: every child in order
--------------------------------------------------------------------------------
create or replace
type TY_ABNF_Sequence under TY_ABNF_Node (
  CHILD_NODES TY_ABNF_NodeList
, overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pCtx            in out nocopy TY_ABNF_Context
  ) return TY_ABNF_PosList
);
/

create or replace
type body TY_ABNF_Sequence is

  overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pCtx            in out nocopy TY_ABNF_Context
  ) return TY_ABNF_PosList is
    vCurrent     TY_ABNF_PosList := TY_ABNF_PosList(pOffset);
    vNext        TY_ABNF_PosList;
    vChildEnds   TY_ABNF_PosList;
    vBeforePos   integer := pCtx.FAIL_POS;
    vBeforeCount integer := pCtx.EXPECTED.count;
  begin
    if self.CHILD_NODES is not null then
      for i in 1..self.CHILD_NODES.count
      loop
        if self.CHILD_NODES(i) is not null then
          vNext := TY_ABNF_PosList();
          for j in 1..vCurrent.count
          loop
            vChildEnds := self.CHILD_NODES(i).MatchInput(pInput => pInput, pOffset => vCurrent(j), pCtx => pCtx);
            vNext := vNext multiset union distinct vChildEnds;
          end loop;
          vCurrent := vNext;
          exit when vCurrent.count = 0;
        end if;
      end loop;
    end if;

    if vCurrent.count = 0 and self.NODE_NAME is not null then
      pCtx.Summarise(pOffset, vBeforePos, vBeforeCount, self.NODE_NAME, False);
    end if;

    return vCurrent;
  end MatchInput;

end;
/

--------------------------------------------------------------------------------
-- Alternation: any child (all possibilities are kept, for backtracking)
--------------------------------------------------------------------------------
create or replace
type TY_ABNF_Alternative under TY_ABNF_Node (
  CHILD_NODES TY_ABNF_NodeList
, overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pCtx            in out nocopy TY_ABNF_Context
  ) return TY_ABNF_PosList
);
/

create or replace
type body TY_ABNF_Alternative is

  overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pCtx            in out nocopy TY_ABNF_Context
  ) return TY_ABNF_PosList is
    vResult      TY_ABNF_PosList := TY_ABNF_PosList();
    vChildEnds   TY_ABNF_PosList;
    vBeforePos   integer := pCtx.FAIL_POS;
    vBeforeCount integer := pCtx.EXPECTED.count;
  begin
    if self.CHILD_NODES is not null then
      for i in 1..self.CHILD_NODES.count
      loop
        if self.CHILD_NODES(i) is not null then
          vChildEnds := self.CHILD_NODES(i).MatchInput(pInput => pInput, pOffset => pOffset, pCtx => pCtx);
          vResult    := vResult multiset union distinct vChildEnds;
        end if;
      end loop;
    end if;

    if vResult.count = 0 and self.NODE_NAME is not null then
      pCtx.Summarise(pOffset, vBeforePos, vBeforeCount, self.NODE_NAME, False);
    end if;

    return vResult;
  end MatchInput;

end;
/

--------------------------------------------------------------------------------
-- Repetition: n*m element. MAX_OCCURS null means unbounded; MIN_OCCURS null means 0.
-- [element] is a repetition with MIN_OCCURS 0 and MAX_OCCURS 1.
--------------------------------------------------------------------------------
create or replace
type TY_ABNF_Repetition under TY_ABNF_Node (
  MIN_OCCURS integer
, MAX_OCCURS integer
, CHILD_NODE TY_ABNF_Node
, overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pCtx            in out nocopy TY_ABNF_Context
  ) return TY_ABNF_PosList
);
/

create or replace
type body TY_ABNF_Repetition is

  overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pCtx            in out nocopy TY_ABNF_Context
  ) return TY_ABNF_PosList is
    vMin         integer := nvl(self.MIN_OCCURS, 0);
    vFrontier    TY_ABNF_PosList := TY_ABNF_PosList(pOffset);  -- offsets reachable after vCount repeats
    vResult      TY_ABNF_PosList := TY_ABNF_PosList();         -- offsets reachable after vMin or more repeats
    vNext        TY_ABNF_PosList;
    vNew         TY_ABNF_PosList;
    vChildEnds   TY_ABNF_PosList;
    vCount       integer := 0;
    vBeforePos   integer := pCtx.FAIL_POS;
    vBeforeCount integer := pCtx.EXPECTED.count;
  begin
    if vMin = 0 then
      vResult := vFrontier;
    end if;

    if self.CHILD_NODE is not null then
      loop
        exit when self.MAX_OCCURS is not null and vCount >= self.MAX_OCCURS;
        exit when vFrontier.count = 0;

        vNext := TY_ABNF_PosList();
        for j in 1..vFrontier.count
        loop
          vChildEnds := self.CHILD_NODE.MatchInput(pInput => pInput, pOffset => vFrontier(j), pCtx => pCtx);
          vNext := vNext multiset union distinct vChildEnds;
        end loop;
        vFrontier := vNext;
        vCount    := vCount + 1;

        if vCount >= vMin then
          -- Stop once another repeat reaches nothing new (this also ends loops over empty matches)
          vNew := vFrontier multiset except vResult;
          exit when vNew.count = 0;
          vResult := vResult multiset union vNew;
        end if;
      end loop;
    elsif vMin > 0 then
      vResult := TY_ABNF_PosList();
    end if;

    if vResult.count = 0 and self.NODE_NAME is not null then
      pCtx.Summarise(pOffset, vBeforePos, vBeforeCount, self.NODE_NAME, False);
    end if;

    return vResult;
  end MatchInput;

end;
/
