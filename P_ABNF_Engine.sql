create or replace package P_ABNF_Engine is

function CoreAlpha return TY_ABNF_Alternative;
function CoreDigit return TY_ABNF_Range;
function CoreHexDig return TY_ABNF_Alternative;
function CoreBit return TY_ABNF_Alternative;
function CoreVchar return TY_ABNF_Range;
function CoreWsp return TY_ABNF_Alternative;
function CoreCrlf return TY_ABNF_Literal;

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

function GeneratePLSQLFromABNF(pGrammar varchar2) return clob;

end P_ABNF_Engine;
/

create or replace package body P_ABNF_Engine is

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
             , CHILD_NODES => TY_ABNF_NodeList(
                                TY_ABNF_Literal(NODE_NAME => 'SP',   VALUE => ' ')
                              , TY_ABNF_Literal(NODE_NAME => 'HTAB', VALUE => chr(9))
                              )
             );
  return vResult;
end CoreWsp;

------------------------------------------------------------------------------
-- CRLF = %x0D.0A
------------------------------------------------------------------------------
function CoreCrlf return TY_ABNF_Literal is
  vResult TY_ABNF_Literal;
begin
  vResult := TY_ABNF_Literal(
               NODE_NAME => 'CRLF'
             , VALUE     => chr(13) || chr(10)
             );
  return vResult;
end CoreCrlf;

--function ParseNode(
--             pNode     in     TY_ABNF_Node
--           , pInput    in     varchar2
--           , pOffset   in     integer
--           , pFailPos  in out integer
--           , pFailNode in out varchar2
--           ) return integer is
--    vCurrPos   integer := pOffset;
--    vMatchLen  integer := 0;
--    vSubLen    integer := 0;
--    vCount     integer := 0;
--    vResult    integer := 0;
--  begin
--    if pNode is null or pOffset > length(pInput) + 1 then
--      vResult := 0;
--    elsif pNode is of (TY_ABNF_Literal) then
--      --------------------------------------------------------------------------
--      -- 1. Literal Matching
--      --------------------------------------------------------------------------
--      declare
--        vLit    TY_ABNF_Literal := treat(pNode as TY_ABNF_Literal);
--        vLitVal varchar2(32767);
--      begin
--        vLitVal   := vLit.VALUE;
--        vMatchLen := length(vLitVal);
--
--        if substr(pInput, pOffset, vMatchLen) = vLitVal then
--          vResult := vMatchLen;
--        else
--          if pOffset > pFailPos then
--            pFailPos  := pOffset;
--            pFailNode := nvl(vLit.NODE_NAME, 'LITERAL');
--          end if;
--          vResult := 0;
--        end if;
--      end;
--
--    elsif pNode is of (TY_ABNF_Range) then
--      --------------------------------------------------------------------------
--      -- 2. ASCII Character Range Matching
--      --------------------------------------------------------------------------
--      declare
--        vRng     TY_ABNF_Range := treat(pNode as TY_ABNF_Range);
--        vCode    integer;
--        vMinCode integer;
--        vMaxCode integer;
--      begin
--        vMinCode := vRng.MIN_CODE;
--        vMaxCode := vRng.MAX_CODE;
--
--        if pOffset <= length(pInput) then
--          vCode := ascii(substr(pInput, pOffset, 1));
--          if vCode >= vMinCode and vCode <= vMaxCode then
--            vResult := 1;
--          else
--            if pOffset > pFailPos then
--              pFailPos  := pOffset;
--              pFailNode := nvl(vRng.NODE_NAME, 'RANGE');
--            end if;
--            vResult := 0;
--          end if;
--        else
--          if pOffset > pFailPos then
--            pFailPos  := pOffset;
--            pFailNode := nvl(vRng.NODE_NAME, 'RANGE');
--          end if;
--          vResult := 0;
--        end if;
--      end;
--
--    elsif pNode is of (TY_ABNF_Sequence) then
--      --------------------------------------------------------------------------
--      -- 3. Sequence (Ordered CONCATENATION of Child Nodes)
--      --------------------------------------------------------------------------
--      declare
--        vSeq  TY_ABNF_Sequence := treat(pNode as TY_ABNF_Sequence);
--        vExit boolean := False;
--      begin
--        if vSeq.CHILD_NODES is not null then
--          for i in 1 .. vSeq.CHILD_NODES.count loop
--            if not vExit then
--              vSubLen := ParseNode(
--                           pNode     => vSeq.CHILD_NODES(i)
--                         , pInput    => pInput
--                         , pOffset   => vCurrPos
--                         , pFailPos  => pFailPos
--                         , pFailNode => pFailNode
--                         );
--
--              if vSubLen = 0 and vSeq.CHILD_NODES(i) is not null then
--                vMatchLen := 0;
--                vExit     := True;
--              else
--                vCurrPos  := vCurrPos + vSubLen;
--                vMatchLen := vMatchLen + vSubLen;
--              end if;
--            end if;
--          end loop;
--        end if;
--        vResult := vMatchLen;
--      end;
--
--    elsif pNode is of (TY_ABNF_Alternative) then
--      --------------------------------------------------------------------------
--      -- 4. Alternative (FIRST MATCHing Child Node)
--      --------------------------------------------------------------------------
--      declare
--        vAlt     TY_ABNF_Alternative := treat(pNode as TY_ABNF_Alternative);
--        vMatched boolean := False;
--      begin
--        if vAlt.CHILD_NODES is not null then
--          for i in 1 .. vAlt.CHILD_NODES.count loop
--            if not vMatched then
--              vSubLen := ParseNode(
--                           pNode     => vAlt.CHILD_NODES(i)
--                         , pInput    => pInput
--                         , pOffset   => pOffset
--                         , pFailPos  => pFailPos
--                         , pFailNode => pFailNode
--                         );
--
--              if vSubLen > 0 then
--                vMatchLen := vSubLen;
--                vMatched  := True;
--              end if;
--            end if;
--          end loop;
--        end if;
--
--        if vMatched then
--          vResult := vMatchLen;
--        else
--          if pOffset > pFailPos then
--            pFailPos  := pOffset;
--            pFailNode := nvl(vAlt.NODE_NAME, 'ALT');
--          end if;
--          vResult := 0;
--        end if;
--      end;
--
--    elsif pNode is of (TY_ABNF_Repetition) then
--      --------------------------------------------------------------------------
--      -- 5. Repetition (MIN_OCCURS to MAX_OCCURS repeats)
--      --------------------------------------------------------------------------
--      declare
--        vRep  TY_ABNF_Repetition := treat(pNode as TY_ABNF_Repetition);
--        vLoop boolean := True;
--      begin
--        while vLoop loop
--          if vRep.MAX_OCCURS is not null and vCount >= vRep.MAX_OCCURS then
--            vLoop := False;
--          else
--            vSubLen := ParseNode(
--                         pNode     => vRep.CHILD_NODE
--                       , pInput    => pInput
--                       , pOffset   => vCurrPos
--                       , pFailPos  => pFailPos
--                       , pFailNode => pFailNode
--                       );
--
--            if vSubLen = 0 then
--              vLoop := False;
--            else
--              vCount    := vCount + 1;
--              vCurrPos  := vCurrPos + vSubLen;
--              vMatchLen := vMatchLen + vSubLen;
--            end if;
--          end if;
--        end loop;
--
--        if vCount >= vRep.MIN_OCCURS then
--          vResult := vMatchLen;
--        else
--          if pOffset > pFailPos then
--            pFailPos  := pOffset;
--            pFailNode := nvl(vRep.NODE_NAME, 'REPEAT');
--          end if;
--          vResult := 0;
--        end if;
--      end;
--    else
--      vResult := 0;
--    end if;
--
--    return vResult;
--  end ParseNode;

------------------------------------------------------------------------------
-- ValidateInput (Function overload)
------------------------------------------------------------------------------
function ValidateInput(
           pNode  TY_ABNF_Node
         , pInput varchar2
         ) return boolean is
  vIsValid        boolean := False;
  vErrorPosition  integer;
  vFailedNodeName varchar2(128);
  vErrorMessage   varchar2(4000);
begin
  ValidateInput(
    pNode           => pNode
  , pInput          => pInput
  , pIsValid        => vIsValid
  , pErrorPosition  => vErrorPosition
  , pFailedNodeName => vFailedNodeName
  , pErrorMessage   => vErrorMessage
  );

  return vIsValid;
end ValidateInput;

------------------------------------------------------------------------------
-- ValidateInput (Procedure overload)
------------------------------------------------------------------------------
procedure ValidateInput(
            pNode           in  TY_ABNF_Node
          , pInput          in  varchar2
          , pIsValid          out boolean
          , pErrorPosition    out integer
          , pFailedNodeName   out varchar2
          , pErrorMessage     out varchar2
          ) is
  vMatchLength integer := 0;
  vFailPos     integer := 0;
  vFailNode    varchar2(128);
begin
  pIsValid        := False;
  pErrorPosition  := 0;
  pFailedNodeName := null;

  if pNode is null then
    pErrorMessage := 'Root rule node is null.';
  elsif pInput is null then
    pErrorMessage := 'Input string is null.';
  else
    vMatchLength := pNode.MatchInput(
                      pInput    => pInput
                    , pOffset   => 1
                    , pFailPos  => vFailPos
                    , pFailNode => vFailNode
                    );

    if vMatchLength = length(pInput) then
      pIsValid        := True;
      pErrorPosition  := null;
      pFailedNodeName := null;
      pErrorMessage   := null;
    else
      pIsValid := False;
      if vMatchLength >= 0 and vMatchLength < length(pInput) and (vFailPos is null or vFailPos <= vMatchLength) then
        pErrorPosition  := vMatchLength + 1;
        pFailedNodeName := 'UNEXPECTED_TRAILING_INPUT';
      else
        pErrorPosition  := greatest(nvl(vFailPos, 1), 1);
        pFailedNodeName := vFailNode;
      end if;
      pErrorMessage   := 'Parsing failed at character index ' || to_char(pErrorPosition)
                         || ' ("' || substr(pInput, pErrorPosition, 1) || '")'
                         || ' while evaluating rule node: ' || nvl(pFailedNodeName, 'UNKNOWN');
    end if;
  end if;
end ValidateInput;

------------------------------------------------------------------------------
-- Grammar Generator Helpers
------------------------------------------------------------------------------
function CleanGrammarLine(pLine varchar2) return varchar2 is
  vInQuote boolean := False;
  vLen     integer;
  vCh      varchar2(4);
begin
  if pLine is null then
    return null;
  end if;

  vLen := length(pLine);
  for i in 1 .. vLen loop
    vCh := substr(pLine, i, 1);
    if vCh = '"' then
      vInQuote := not vInQuote;
    elsif not vInQuote and vCh = ';' then
      return trim(substr(pLine, 1, i - 1));
    end if;
  end loop;
  return trim(pLine);
end CleanGrammarLine;

function FindEqualsSign(pLine varchar2) return integer is
  vInQuote boolean := False;
  vLen     integer;
  vCh      varchar2(4);
begin
  if pLine is null then
    return 0;
  end if;

  vLen := length(pLine);
  for i in 1 .. vLen loop
    vCh := substr(pLine, i, 1);
    if vCh = '"' then
      vInQuote := not vInQuote;
    elsif not vInQuote and vCh = '=' then
      return i;
    end if;
  end loop;
  return 0;
end FindEqualsSign;

function FormatPascalName(pName varchar2) return varchar2 is
  vClean  varchar2(100);
  vResult varchar2(100) := '';
  vCap    boolean := True;
  vChar   varchar2(4);
  vLen    integer;
begin
  if pName is null then
    return '';
  end if;

  vClean := translate(pName, '-_/.', '    ');
  vLen   := length(vClean);
  for i in 1 .. vLen loop
    vChar := substr(vClean, i, 1);
    if vChar = ' ' then
      vCap := True;
    elsif vCap then
      vResult := vResult || upper(vChar);
      vCap := False;
    else
      vResult := vResult || lower(vChar);
    end if;
  end loop;
  return vResult;
end FormatPascalName;

function ParseRangeExpr(pExpr varchar2) return varchar2 is
  vExpr   varchar2(100) := trim(pExpr);
  vBase   varchar2(1);
  vStr    varchar2(100);
  vDash   integer;
  vDot    integer;
  vMin    integer;
  vMax    integer;
  vPart   varchar2(20);
  vVal    integer;
  vLit    varchar2(1000) := '';
  vResult varchar2(1000);
begin
  if length(vExpr) < 3 then
    return null;
  end if;

  vBase := lower(substr(vExpr, 2, 1));
  vStr  := substr(vExpr, 3);
  vDash := instr(vStr, '-');
  vDot  := instr(vStr, '.');

  if vDash > 0 then
    if vBase = 'd' then
      vMin := to_number(substr(vStr, 1, vDash - 1));
      vMax := to_number(substr(vStr, vDash + 1));
    elsif vBase = 'x' then
      vMin := to_number(substr(vStr, 1, vDash - 1), 'XX');
      vMax := to_number(substr(vStr, vDash + 1), 'XX');
    elsif vBase = 'b' then
      vMin := to_number(substr(vStr, 1, vDash - 1));
      vMax := to_number(substr(vStr, vDash + 1));
    end if;
    vResult := 'TY_ABNF_Range(NODE_NAME => ''RANGE'', MIN_CODE => ' || to_char(vMin) || ', MAX_CODE => ' || to_char(vMax) || ')';
  elsif vDot > 0 then
    vStr := vStr || '.';
    while length(vStr) > 0 loop
      vDot  := instr(vStr, '.');
      vPart := substr(vStr, 1, vDot - 1);
      vStr  := substr(vStr, vDot + 1);
      if vBase = 'x' then
        vVal := to_number(vPart, 'XX');
      else
        vVal := to_number(vPart);
      end if;
      if vLit is not null then
        vLit := vLit || ' || ';
      end if;
      vLit := vLit || 'chr(' || to_char(vVal) || ')';
    end loop;
    vResult := 'TY_ABNF_Literal(NODE_NAME => ''LITERAL'', VALUE => ' || vLit || ')';
  else
    if vBase = 'd' then
      vMin := to_number(vStr);
    elsif vBase = 'x' then
      vMin := to_number(vStr, 'XX');
    elsif vBase = 'b' then
      vMin := to_number(vStr);
    end if;
    vResult := 'TY_ABNF_Range(NODE_NAME => ''RANGE'', MIN_CODE => ' || to_char(vMin) || ', MAX_CODE => ' || to_char(vMin) || ')';
  end if;

  return vResult;
end ParseRangeExpr;

procedure SkipWhitespace(pStr in varchar2, pPos in out integer) is
  vLen integer := nvl(length(pStr), 0);
  vCh  varchar2(4);
begin
  while pPos <= vLen loop
    vCh := substr(pStr, pPos, 1);
    if vCh in (' ', chr(9), chr(10), chr(13)) then
      pPos := pPos + 1;
    else
      exit;
    end if;
  end loop;
end SkipWhitespace;

-- Forward declarations for recursive descent parser
function ParseAlternation(
           pStr    in     varchar2
         , pPos    in out integer
         , pIndent in     integer
         ) return varchar2;

function ParseConcatenation(
           pStr    in     varchar2
         , pPos    in out integer
         , pIndent in     integer
         ) return varchar2;

function ParseRepetition(
           pStr    in     varchar2
         , pPos    in out integer
         , pIndent in     integer
         ) return varchar2;

function ParseElement(
           pStr    in     varchar2
         , pPos    in out integer
         , pIndent in     integer
         ) return varchar2;

function ParseElement(
           pStr    in     varchar2
         , pPos    in out integer
         , pIndent in     integer
         ) return varchar2 is
  vInd    varchar2(100) := rpad(' ', pIndent);
  vCh     varchar2(4);
  vCode   integer;
  vResult varchar2(32767);
  vEndPos integer;
  vVal    varchar2(4000);
  vEsc    varchar2(4000);
  vName   varchar2(128) := '';
  vUpper  varchar2(128);
  vLen    integer := nvl(length(pStr), 0);
begin
  SkipWhitespace(pStr, pPos);
  if pPos > vLen then
    return null;
  end if;

  vCh := substr(pStr, pPos, 1);

  if vCh = '(' then
    -- Group ( ... )
    pPos := pPos + 1; -- consume '('
    vResult := ParseAlternation(pStr, pPos, pIndent);
    SkipWhitespace(pStr, pPos);
    if pPos <= vLen and substr(pStr, pPos, 1) = ')' then
      pPos := pPos + 1; -- consume ')'
    end if;

  elsif vCh = '[' then
    -- Option [ ... ]
    pPos := pPos + 1; -- consume '['
    vResult := ParseAlternation(pStr, pPos, pIndent + 2);
    SkipWhitespace(pStr, pPos);
    if pPos <= vLen and substr(pStr, pPos, 1) = ']' then
      pPos := pPos + 1; -- consume ']'
    end if;

    vResult := 'TY_ABNF_Repetition(' || chr(10)
            || vInd || '  NODE_NAME  => ''OPTIONAL''' || chr(10)
            || vInd || ', MIN_OCCURS => 0' || chr(10)
            || vInd || ', MAX_OCCURS => 1' || chr(10)
            || vInd || ', CHILD_NODE => ' || vResult || chr(10)
            || vInd || ')';

  elsif vCh = '"' then
    -- String Literal "..."
    pPos := pPos + 1; -- consume opening '"'
    vEndPos := instr(pStr, '"', pPos);
    if vEndPos = 0 then
      vEndPos := vLen + 1;
    end if;
    vVal := substr(pStr, pPos, vEndPos - pPos);
    pPos := vEndPos + 1; -- consume closing '"'
    vEsc := replace(vVal, '''', '''''');
    vResult := 'TY_ABNF_Literal(NODE_NAME => ''LITERAL'', VALUE => ''' || vEsc || ''')';

  elsif vCh = '%' then
    -- Numeric value or range %x... or %d...
    vEndPos := pPos + 1;
    while vEndPos <= vLen loop
      vCh := substr(pStr, vEndPos, 1);
      if vCh in (' ', chr(9), chr(10), chr(13), ')', ']', '/') then
        exit;
      end if;
      vEndPos := vEndPos + 1;
    end loop;
    vVal := substr(pStr, pPos, vEndPos - pPos);
    pPos := vEndPos;
    vResult := ParseRangeExpr(vVal);

  else
    -- Rule Name / Identifier
    while pPos <= vLen loop
      vCh := substr(pStr, pPos, 1);
      vCode := ascii(vCh);
      if (vCode >= 65 and vCode <= 90)    -- A-Z
         or (vCode >= 97 and vCode <= 122) -- a-z
         or (vCode >= 48 and vCode <= 57)  -- 0-9
         or vCh in ('-', '_') then
        vName := vName || vCh;
        pPos := pPos + 1;
      else
        exit;
      end if;
    end loop;

    if length(vName) > 0 then
      vUpper := upper(vName);
      if vUpper = 'ALPHA' then
        vResult := 'P_ABNF_Engine.CoreAlpha()';
      elsif vUpper = 'DIGIT' then
        vResult := 'P_ABNF_Engine.CoreDigit()';
      elsif vUpper = 'HEXDIG' then
        vResult := 'P_ABNF_Engine.CoreHexDig()';
      elsif vUpper = 'BIT' then
        vResult := 'P_ABNF_Engine.CoreBit()';
      elsif vUpper = 'VCHAR' then
        vResult := 'P_ABNF_Engine.CoreVchar()';
      elsif vUpper = 'WSP' then
        vResult := 'P_ABNF_Engine.CoreWsp()';
      elsif vUpper = 'CRLF' then
        vResult := 'P_ABNF_Engine.CoreCrlf()';
      elsif vUpper = 'SP' then
        vResult := 'TY_ABNF_Literal(NODE_NAME => ''SP'', VALUE => '' '')';
      elsif vUpper = 'HTAB' then
        vResult := 'TY_ABNF_Literal(NODE_NAME => ''HTAB'', VALUE => chr(9))';
      elsif vUpper = 'DQUOTE' then
        vResult := 'TY_ABNF_Literal(NODE_NAME => ''DQUOTE'', VALUE => ''"'')';
      else
        vResult := 'Get' || FormatPascalName(vName) || 'Rule()';
      end if;
    end if;
  end if;

  return vResult;
end ParseElement;

function ParseRepetition(
           pStr    in     varchar2
         , pPos    in out integer
         , pIndent in     integer
         ) return varchar2 is
  vInd       varchar2(100) := rpad(' ', pIndent);
  vHasRepeat boolean := False;
  vMinStr    varchar2(20) := null;
  vMaxStr    varchar2(20) := null;
  vHasStar   boolean := False;
  vCh        varchar2(4);
  vCode      integer;
  vElemCode  varchar2(32767);
  vResult    varchar2(32767);
  vLen       integer := nvl(length(pStr), 0);
begin
  SkipWhitespace(pStr, pPos);
  if pPos > vLen then
    return null;
  end if;

  vCh := substr(pStr, pPos, 1);
  vCode := ascii(vCh);

  -- Check if starts with a digit or '*'
  if (vCode >= 48 and vCode <= 57) or vCh = '*' then
    vHasRepeat := True;

    -- Read digits before '*' (if any)
    while pPos <= vLen loop
      vCode := ascii(substr(pStr, pPos, 1));
      if vCode >= 48 and vCode <= 57 then
        vMinStr := vMinStr || substr(pStr, pPos, 1);
        pPos := pPos + 1;
      else
        exit;
      end if;
    end loop;

    -- Check for '*'
    if pPos <= vLen and substr(pStr, pPos, 1) = '*' then
      vHasStar := True;
      pPos := pPos + 1; -- consume '*'
      -- Read digits after '*' (if any)
      while pPos <= vLen loop
        vCode := ascii(substr(pStr, pPos, 1));
        if vCode >= 48 and vCode <= 57 then
          vMaxStr := vMaxStr || substr(pStr, pPos, 1);
          pPos := pPos + 1;
        else
          exit;
        end if;
      end loop;
    end if;

    if not vHasStar then
      -- Exact count: n
      vMaxStr := vMinStr;
    else
      if vMinStr is null then
        vMinStr := '0';
      end if;
    end if;
  end if;

  SkipWhitespace(pStr, pPos);
  vElemCode := ParseElement(pStr, pPos, pIndent + 2);
  if vElemCode is null then
    return null;
  end if;

  if vHasRepeat then
    vResult := 'TY_ABNF_Repetition(' || chr(10)
            || vInd || '  NODE_NAME  => ''REPEAT''' || chr(10)
            || vInd || ', MIN_OCCURS => ' || vMinStr || chr(10)
            || vInd || ', MAX_OCCURS => ' || nvl(vMaxStr, 'null') || chr(10)
            || vInd || ', CHILD_NODE => ' || vElemCode || chr(10)
            || vInd || ')';
  else
    vResult := vElemCode;
  end if;

  return vResult;
end ParseRepetition;

function ParseConcatenation(
           pStr    in     varchar2
         , pPos    in out integer
         , pIndent in     integer
         ) return varchar2 is
  vChild  varchar2(32767);
  vResult varchar2(32767);
  vCount  integer := 0;
  vInd    varchar2(100) := rpad(' ', pIndent);
  vCh     varchar2(4);
  vLen    integer := nvl(length(pStr), 0);
begin
  SkipWhitespace(pStr, pPos);
  while pPos <= vLen loop
    vCh := substr(pStr, pPos, 1);
    if vCh in ('/', ')', ']') then
      exit;
    end if;

    vChild := ParseRepetition(pStr, pPos, pIndent + 2);
    if vChild is not null then
      vCount := vCount + 1;
      if vCount = 1 then
        vResult := vChild;
      elsif vCount = 2 then
        vResult := 'TY_ABNF_Sequence(' || chr(10)
                || vInd || '  NODE_NAME   => ''SEQ''' || chr(10)
                || vInd || ', CHILD_NODES => TY_ABNF_NodeList(' || chr(10)
                || vInd || '                     ' || vResult || chr(10)
                || vInd || '                   , ' || vChild;
      else
        vResult := vResult || chr(10)
                || vInd || '                   , ' || vChild;
      end if;
    else
      exit;
    end if;

    SkipWhitespace(pStr, pPos);
  end loop;

  if vCount > 1 then
    vResult := vResult || chr(10)
            || vInd || '                   )' || chr(10)
            || vInd || ')';
  end if;

  return vResult;
end ParseConcatenation;

function ParseAlternation(
           pStr    in     varchar2
         , pPos    in out integer
         , pIndent in     integer
         ) return varchar2 is
  vChild  varchar2(32767);
  vResult varchar2(32767);
  vCount  integer := 0;
  vInd    varchar2(100) := rpad(' ', pIndent);
  vLen    integer := nvl(length(pStr), 0);
begin
  SkipWhitespace(pStr, pPos);
  while pPos <= vLen loop
    vChild := ParseConcatenation(pStr, pPos, pIndent + 2);
    if vChild is not null then
      vCount := vCount + 1;
      if vCount = 1 then
        vResult := vChild;
      elsif vCount = 2 then
        vResult := 'TY_ABNF_Alternative(' || chr(10)
                || vInd || '  NODE_NAME   => ''ALT''' || chr(10)
                || vInd || ', CHILD_NODES => TY_ABNF_NodeList(' || chr(10)
                || vInd || '                     ' || vResult || chr(10)
                || vInd || '                   , ' || vChild;
      else
        vResult := vResult || chr(10)
                || vInd || '                   , ' || vChild;
      end if;
    end if;

    SkipWhitespace(pStr, pPos);
    if pPos <= vLen and substr(pStr, pPos, 1) = '/' then
      pPos := pPos + 1; -- consume '/'
      SkipWhitespace(pStr, pPos);
    else
      exit;
    end if;
  end loop;

  if vCount > 1 then
    vResult := vResult || chr(10)
            || vInd || '                   )' || chr(10)
            || vInd || ')';
  end if;

  return vResult;
end ParseAlternation;

procedure FlushRule(
            pRuleName in     varchar2
          , pRuleRhs  in     varchar2
          , pClob     in out clob
          ) is
  vFuncName varchar2(100);
  vBodyCode varchar2(32767);
  vPos      integer := 1;
  vCode     varchar2(32767);
begin
  if trim(pRuleName) is not null and trim(pRuleRhs) is not null then
    vFuncName := 'Get' || FormatPascalName(trim(pRuleName)) || 'Rule';
    vBodyCode := ParseAlternation(trim(pRuleRhs), vPos, 4);

    if vBodyCode is not null then
      vCode := '  function ' || vFuncName || ' return TY_ABNF_Node is' || chr(10)
            || '    vResult TY_ABNF_Node;' || chr(10)
            || '  begin' || chr(10)
            || '    vResult := ' || vBodyCode || ';' || chr(10)
            || '    return vResult;' || chr(10)
            || '  end ' || vFuncName || ';' || chr(10) || chr(10);

      DBMS_LOB.WRITEAPPEND(pClob, length(vCode), vCode);
    end if;
  end if;
end FlushRule;

------------------------------------------------------------------------------
-- GeneratePLSQLFromABNF
------------------------------------------------------------------------------
function GeneratePLSQLFromABNF(pGrammar varchar2) return clob is
  vClob            clob;
  vLine            varchar2(32767);
  vCleanLine       varchar2(32767);
  vEqPos           integer;
  vStart           integer := 1;
  vEnd             integer;
  vLen             integer;
  vCurrentRuleName varchar2(100) := null;
  vCurrentRuleRhs  varchar2(32767) := null;
  vIncName         varchar2(100);
  vIncRhs          varchar2(32767);
begin
  DBMS_LOB.CREATETEMPORARY(vClob, True);
  if pGrammar is null then
    return vClob;
  end if;

  vLen := length(pGrammar);

  while vStart <= vLen loop
    vEnd := instr(pGrammar, chr(10), vStart);
    if vEnd = 0 then
      vEnd := vLen + 1;
    end if;

    if vEnd > vStart then
      vLine := substr(pGrammar, vStart, vEnd - vStart);
    else
      vLine := null;
    end if;

    vLine := replace(vLine, chr(13), '');
    vCleanLine := CleanGrammarLine(vLine);

    if length(vCleanLine) > 0 then
      vEqPos := FindEqualsSign(vCleanLine);
      if vEqPos > 0 then
        if substr(vCleanLine, vEqPos + 1, 1) = '/' then
          -- Incremental alternative (=/)
          vIncName := trim(substr(vCleanLine, 1, vEqPos - 1));
          vIncRhs  := trim(substr(vCleanLine, vEqPos + 2));
          if lower(vIncName) = lower(vCurrentRuleName) then
            vCurrentRuleRhs := vCurrentRuleRhs || ' / ' || vIncRhs;
          else
            FlushRule(vCurrentRuleName, vCurrentRuleRhs, vClob);
            vCurrentRuleName := vIncName;
            vCurrentRuleRhs  := vIncRhs;
          end if;
        else
          -- New rule definition
          FlushRule(vCurrentRuleName, vCurrentRuleRhs, vClob);
          vCurrentRuleName := trim(substr(vCleanLine, 1, vEqPos - 1));
          vCurrentRuleRhs  := trim(substr(vCleanLine, vEqPos + 1));
        end if;
      else
        -- Continuation line for current rule
        if vCurrentRuleName is not null then
          vCurrentRuleRhs := vCurrentRuleRhs || ' ' || vCleanLine;
        end if;
      end if;
    end if;

    vStart := vEnd + 1;
  end loop;

  -- Flush the final accumulated rule
  FlushRule(vCurrentRuleName, vCurrentRuleRhs, vClob);

  return vClob;
end GeneratePLSQLFromABNF;

end P_ABNF_Engine;
/

