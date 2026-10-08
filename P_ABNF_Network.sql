--------------------------------------------------------------------------------
-- Package Specification: P_ABNF_Network
--------------------------------------------------------------------------------
create or replace
package P_ABNF_Network is

function GetIPv4OctetRule return TY_ABNF_Alternative;
function GetAddrSpecRule return TY_ABNF_Sequence;

function ValidateEmail(pEmail varchar2) return boolean;

procedure ValidateEmail(
            pEmail          in  varchar2
          , pIsValid        out boolean
          , pErrorPosition  out integer
          , pFailedNodeName out varchar2
          , pErrorMessage   out varchar2
          );

end P_ABNF_Network;
/

--------------------------------------------------------------------------------
-- Package Body: P_ABNF_Network
--------------------------------------------------------------------------------
create or replace
package body P_ABNF_Network is

------------------------------------------------------------------------------
-- IPv4 octet rule: 0-255
-- "25" %x30-35 / "2" %x30-34 DIGIT / "1" DIGIT DIGIT / %x31-39 DIGIT / DIGIT
------------------------------------------------------------------------------
function GetIPv4OctetRule return TY_ABNF_Alternative is
  vResult TY_ABNF_Alternative;
begin
  vResult := TY_ABNF_Alternative(
               NODE_NAME   => 'dec-octet'
             , CHILD_NODES => TY_ABNF_NodeList(
                                -- 250 - 255
                                TY_ABNF_Sequence(
                                  NODE_NAME   => 'octet_250_255'
                                , CHILD_NODES => TY_ABNF_NodeList(
                                                   TY_ABNF_Literal(NODE_NAME => null, VALUE => '25')
                                                 , TY_ABNF_Range(NODE_NAME => null, MIN_CODE => 48, MAX_CODE => 53)
                                                 )
                                )
                                -- 200 - 249
                              , TY_ABNF_Sequence(
                                  NODE_NAME   => 'octet_200_249'
                                , CHILD_NODES => TY_ABNF_NodeList(
                                                   TY_ABNF_Literal(NODE_NAME => null, VALUE => '2')
                                                 , TY_ABNF_Range(NODE_NAME => null, MIN_CODE => 48, MAX_CODE => 52)
                                                 , P_ABNF_Engine.CoreDigit()
                                                 )
                                )
                                -- 100 - 199
                              , TY_ABNF_Sequence(
                                  NODE_NAME   => 'octet_100_199'
                                , CHILD_NODES => TY_ABNF_NodeList(
                                                   TY_ABNF_Literal(NODE_NAME => null, VALUE => '1')
                                                 , P_ABNF_Engine.CoreDigit()
                                                 , P_ABNF_Engine.CoreDigit()
                                                 )
                                )
                                -- 10 - 99
                              , TY_ABNF_Sequence(
                                  NODE_NAME   => 'octet_10_99'
                                , CHILD_NODES => TY_ABNF_NodeList(
                                                   TY_ABNF_Range(NODE_NAME => null, MIN_CODE => 49, MAX_CODE => 57)
                                                 , P_ABNF_Engine.CoreDigit()
                                                 )
                                )
                                -- 0 - 9
                              , P_ABNF_Engine.CoreDigit()
                              )
             );
  return vResult;
end GetIPv4OctetRule;

------------------------------------------------------------------------------
-- Private Helper: Returns a rule for ABNF quoted-pair (%d92 VCHAR / WSP)
------------------------------------------------------------------------------
function GetQuotedPairRule return TY_ABNF_Sequence is
  vResult TY_ABNF_Sequence;
begin
  vResult := TY_ABNF_Sequence(
               NODE_NAME   => 'quoted-pair'
             , CHILD_NODES => TY_ABNF_NodeList(
                                TY_ABNF_Literal(NODE_NAME => 'BACKSLASH', VALUE => '\')
                              , TY_ABNF_Alternative(
                                  NODE_NAME   => 'quoted-pair-char'
                                , CHILD_NODES => TY_ABNF_NodeList(
                                                   P_ABNF_Engine.CoreVchar()
                                                 , P_ABNF_Engine.CoreWsp()
                                                 )
                                )
                              )
             );
  return vResult;
end GetQuotedPairRule;

------------------------------------------------------------------------------
-- Private Helper: Returns a rule for ABNF qtext (%d33 / %d35-91 / %d93-126)
------------------------------------------------------------------------------
function GetQtextRule return TY_ABNF_Alternative is
  vResult TY_ABNF_Alternative;
begin
  vResult := TY_ABNF_Alternative(
               NODE_NAME   => 'qtext'
             , CHILD_NODES => TY_ABNF_NodeList(
                                TY_ABNF_Range(NODE_NAME => 'QTEXT_33',    MIN_CODE => 33, MAX_CODE => 33)
                              , TY_ABNF_Range(NODE_NAME => 'QTEXT_35_91', MIN_CODE => 35, MAX_CODE => 91)
                              , TY_ABNF_Range(NODE_NAME => 'QTEXT_93_126',MIN_CODE => 93, MAX_CODE => 126)
                              )
             );
  return vResult;
end GetQtextRule;

------------------------------------------------------------------------------
-- Private Helper: Returns a rule for ABNF qcontent (qtext / WSP / quoted-pair)
------------------------------------------------------------------------------
function GetQcontentRule return TY_ABNF_Alternative is
  vResult TY_ABNF_Alternative;
begin
  vResult := TY_ABNF_Alternative(
               NODE_NAME   => 'qcontent'
             , CHILD_NODES => TY_ABNF_NodeList(
                                GetQtextRule()
                              , P_ABNF_Engine.CoreWsp()
                              , GetQuotedPairRule()
                              )
             );
  return vResult;
end GetQcontentRule;

------------------------------------------------------------------------------
-- Private Helper: Returns a rule for ABNF quoted-string DQUOTA *qcontent DQUOTA
------------------------------------------------------------------------------
function GetQuotedStringRule return TY_ABNF_Sequence is
  vResult TY_ABNF_Sequence;
begin
  vResult := TY_ABNF_Sequence(
               NODE_NAME   => 'quoted-string'
             , CHILD_NODES => TY_ABNF_NodeList(
                                TY_ABNF_Literal(NODE_NAME => 'DQUOTE_OPEN',  VALUE => '"')
                              , TY_ABNF_Repetition(
                                  NODE_NAME  => 'qcontent-repeat'
                                , MIN_OCCURS => 0
                                , MAX_OCCURS => null
                                , CHILD_NODE => GetQcontentRule()
                                )
                              , TY_ABNF_Literal(NODE_NAME => 'DQUOTE_CLOSE', VALUE => '"')
                              )
             );
  return vResult;
end GetQuotedStringRule;

------------------------------------------------------------------------------
-- Private Helper: Returns a rule for ABNF atext
-- ALPHA / DIGIT / "!" / "#" / "$" / "%" / "&" / "'" / "*" / "+" / "-"
-- / "/" / "=" / "?" / "^" / "_" / "`" / "{" / "|" / "}" / "~"
------------------------------------------------------------------------------
function GetAtextRule return TY_ABNF_Alternative is
  vResult TY_ABNF_Alternative;
begin
  vResult := TY_ABNF_Alternative(
               NODE_NAME   => 'atext'
             , CHILD_NODES => TY_ABNF_NodeList(
                                P_ABNF_Engine.CoreAlpha()
                              , P_ABNF_Engine.CoreDigit()
                              , TY_ABNF_Literal(NODE_NAME => 'ATEXT_EXCL',   VALUE => '!')
                              , TY_ABNF_Literal(NODE_NAME => 'ATEXT_HASH',   VALUE => '#')
                              , TY_ABNF_Literal(NODE_NAME => 'ATEXT_DOLLAR', VALUE => '$')
                              , TY_ABNF_Literal(NODE_NAME => 'ATEXT_PERCENT',VALUE => '%')
                              , TY_ABNF_Literal(NODE_NAME => 'ATEXT_AMP',    VALUE => '&')
                              , TY_ABNF_Literal(NODE_NAME => 'ATEXT_SQUOTE', VALUE => '''')
                              , TY_ABNF_Literal(NODE_NAME => 'ATEXT_STAR',   VALUE => '*')
                              , TY_ABNF_Literal(NODE_NAME => 'ATEXT_PLUS',   VALUE => '+')
                              , TY_ABNF_Literal(NODE_NAME => 'ATEXT_MINUS',  VALUE => '-')
                              , TY_ABNF_Literal(NODE_NAME => 'ATEXT_SLASH',  VALUE => '/')
                              , TY_ABNF_Literal(NODE_NAME => 'ATEXT_EQUAL',  VALUE => '=')
                              , TY_ABNF_Literal(NODE_NAME => 'ATEXT_QUESTION',VALUE => '?')
                              , TY_ABNF_Literal(NODE_NAME => 'ATEXT_CARET',  VALUE => '^')
                              , TY_ABNF_Literal(NODE_NAME => 'ATEXT_USCORE', VALUE => '_')
                              , TY_ABNF_Literal(NODE_NAME => 'ATEXT_GRAVE',  VALUE => '`')
                              , TY_ABNF_Literal(NODE_NAME => 'ATEXT_LBRACE', VALUE => '{')
                              , TY_ABNF_Literal(NODE_NAME => 'ATEXT_PIPE',   VALUE => '|')
                              , TY_ABNF_Literal(NODE_NAME => 'ATEXT_RBRACE', VALUE => '}')
                              , TY_ABNF_Literal(NODE_NAME => 'ATEXT_TILDE',  VALUE => '~')
                              )
             );
  return vResult;
end GetAtextRule;

------------------------------------------------------------------------------
-- Private Helper: Returns a rule for ABNF dot-atom-text 1*atext *("." 1*atext)
------------------------------------------------------------------------------
function GetDotAtomTextRule return TY_ABNF_Sequence is
  vResult TY_ABNF_Sequence;
begin
  vResult := TY_ABNF_Sequence(
               NODE_NAME   => 'dot-atom-text'
             , CHILD_NODES => TY_ABNF_NodeList(
                                TY_ABNF_Repetition(
                                  NODE_NAME  => 'atext-lead'
                                , MIN_OCCURS => 1
                                , MAX_OCCURS => null
                                , CHILD_NODE => GetAtextRule()
                                )
                              , TY_ABNF_Repetition(
                                  NODE_NAME  => 'dot-atext-repeat'
                                , MIN_OCCURS => 0
                                , MAX_OCCURS => null
                                , CHILD_NODE => TY_ABNF_Sequence(
                                                  NODE_NAME   => 'dot-atext-pair'
                                                , CHILD_NODES => TY_ABNF_NodeList(
                                                                   TY_ABNF_Literal(NODE_NAME => 'DOT', VALUE => '.')
                                                                 , TY_ABNF_Repetition(
                                                                     NODE_NAME  => 'atext-tail'
                                                                   , MIN_OCCURS => 1
                                                                   , MAX_OCCURS => null
                                                                   , CHILD_NODE => GetAtextRule()
                                                                   )
                                                                 )
                                                )
                                )
                              )
             );
  return vResult;
end GetDotAtomTextRule;

------------------------------------------------------------------------------
-- Private Helper: Returns a rule for ABNF local-part (dot-atom-text / quoted-string)
------------------------------------------------------------------------------
function GetLocalPartRule return TY_ABNF_Alternative is
  vResult TY_ABNF_Alternative;
begin
  vResult := TY_ABNF_Alternative(
               NODE_NAME   => 'local-part'
             , CHILD_NODES => TY_ABNF_NodeList(
                                GetDotAtomTextRule()
                              , GetQuotedStringRule()
                              )
             );
  return vResult;
end GetLocalPartRule;

------------------------------------------------------------------------------
-- Private Helper: Returns a rule for ABNF dtext (%d33-90 / %d94-126)
------------------------------------------------------------------------------
function GetDtextRule return TY_ABNF_Alternative is
  vResult TY_ABNF_Alternative;
begin
  vResult := TY_ABNF_Alternative(
               NODE_NAME   => 'dtext'
             , CHILD_NODES => TY_ABNF_NodeList(
                                TY_ABNF_Range(NODE_NAME => 'DTEXT_33_90',  MIN_CODE => 33, MAX_CODE => 90)
                              , TY_ABNF_Range(NODE_NAME => 'DTEXT_94_126', MIN_CODE => 94, MAX_CODE => 126)
                              )
             );
  return vResult;
end GetDtextRule;

------------------------------------------------------------------------------
-- Private Helper: Returns a rule for ABNF domain-literal "[" (IPv4 / *dtext) "]"
------------------------------------------------------------------------------
function GetDomainLiteralRule return TY_ABNF_Sequence is
  vResult TY_ABNF_Sequence;
begin
  vResult := TY_ABNF_Sequence(
               NODE_NAME   => 'domain-literal'
             , CHILD_NODES => TY_ABNF_NodeList(
                                TY_ABNF_Literal(NODE_NAME => 'LBRACKET', VALUE => '[')
                              , TY_ABNF_Alternative(
                                  NODE_NAME   => 'domain-literal-content'
                                , CHILD_NODES => TY_ABNF_NodeList(
                                                   TY_ABNF_Sequence(
                                                     NODE_NAME   => 'ipv4-address'
                                                   , CHILD_NODES => TY_ABNF_NodeList(
                                                                      GetIPv4OctetRule()
                                                                    , TY_ABNF_Literal(NODE_NAME => 'DOT1', VALUE => '.')
                                                                    , GetIPv4OctetRule()
                                                                    , TY_ABNF_Literal(NODE_NAME => 'DOT2', VALUE => '.')
                                                                    , GetIPv4OctetRule()
                                                                    , TY_ABNF_Literal(NODE_NAME => 'DOT3', VALUE => '.')
                                                                    , GetIPv4OctetRule()
                                                                    )
                                                   )
                                                 , TY_ABNF_Repetition(
                                                     NODE_NAME  => 'dtext-repeat'
                                                   , MIN_OCCURS => 0
                                                   , MAX_OCCURS => null
                                                   , CHILD_NODE => GetDtextRule()
                                                   )
                                                 )
                                )
                              , TY_ABNF_Literal(NODE_NAME => 'RBRACKET', VALUE => ']')
                              )
             );
  return vResult;
end GetDomainLiteralRule;

------------------------------------------------------------------------------
-- Private Helper: Returns a rule for ABNF domain (dot-atom-text / domain-literal)
------------------------------------------------------------------------------
function GetDomainRule return TY_ABNF_Alternative is
  vResult TY_ABNF_Alternative;
begin
  vResult := TY_ABNF_Alternative(
               NODE_NAME   => 'domain'
             , CHILD_NODES => TY_ABNF_NodeList(
                                GetDotAtomTextRule()
                              , GetDomainLiteralRule()
                              )
             );
  return vResult;
end GetDomainRule;

------------------------------------------------------------------------------
-- GetAddrSpecRule: Returns the full RFC 5322 addr-spec rule
-- addr-spec = local-part "@" domain
------------------------------------------------------------------------------
function GetAddrSpecRule return TY_ABNF_Sequence is
  vResult TY_ABNF_Sequence;
begin
  vResult := TY_ABNF_Sequence(
               NODE_NAME   => 'addr-spec'
             , CHILD_NODES => TY_ABNF_NodeList(
                                GetLocalPartRule()
                              , TY_ABNF_Literal(NODE_NAME => 'AT_SYMBOL', VALUE => '@')
                              , GetDomainRule()
                              )
             );
  return vResult;
end GetAddrSpecRule;

------------------------------------------------------------------------------
-- ValidateEmail (Function overload)
------------------------------------------------------------------------------
function ValidateEmail(pEmail varchar2) return boolean is
  vResult boolean := False;
begin
  vResult := P_ABNF_Engine.ValidateInput(
               pNode  => GetAddrSpecRule()
             , pInput => pEmail
             );
  return vResult;
end ValidateEmail;

------------------------------------------------------------------------------
-- ValidateEmail (Procedure overload)
------------------------------------------------------------------------------
procedure ValidateEmail(
            pEmail          in  varchar2
          , pIsValid        out boolean
          , pErrorPosition  out integer
          , pFailedNodeName out varchar2
          , pErrorMessage   out varchar2
          ) is
begin
  P_ABNF_Engine.ValidateInput(
    pNode           => GetAddrSpecRule()
  , pInput          => pEmail
  , pIsValid        => pIsValid
  , pErrorPosition  => pErrorPosition
  , pFailedNodeName => pFailedNodeName
  , pErrorMessage   => pErrorMessage
  );
end ValidateEmail;

end P_ABNF_Network;
/

