--------------------------------------------------------------------------------
-- Package Specification: P_ABNF_Network
--------------------------------------------------------------------------------
create or replace
package P_ABNF_Network is

function GetIPv4OctetRule return TY_ABNF_Alternative;
function GetIPv6AddressRule return TY_ABNF_Alternative;
function GetEmailAddrSpecRule return TY_ABNF_Sequence;

-- The same grammars as named rule sets, for P_ABNF_Engine.ParseTree / Tokenise. Start rules: dec-octet,
-- IPv4address, IPv6address and addr-spec (the first rule in each set is the one to start from).
--   select * from table(P_ABNF_Engine.ParseTree(P_ABNF_Network.GetEmailRuleSet, 'addr-spec', 'a.b@example.com'))
function GetIPv4RuleSet return TY_ABNF_RuleSet;
function GetIPv6RuleSet return TY_ABNF_RuleSet;
function GetEmailRuleSet return TY_ABNF_RuleSet;

function ValidateIPv6(pAddress varchar2) return boolean;

procedure ValidateIPv6(
            pAddress        in  varchar2
          , pIsValid        out boolean
          , pErrorPosition  out integer
          , pFailedNodeName out varchar2
          , pErrorMessage   out varchar2
          );

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
-- Private helpers for the IPv6 rule
------------------------------------------------------------------------------
function Lit(pText varchar2) return TY_ABNF_Literal is
begin
  return TY_ABNF_Literal(NODE_NAME => null, VALUE => pText);
end Lit;

function Rep(pMin integer, pMax integer, pNode TY_ABNF_Node) return TY_ABNF_Repetition is
begin
  return TY_ABNF_Repetition(NODE_NAME => null, MIN_OCCURS => pMin, MAX_OCCURS => pMax, CHILD_NODE => pNode);
end Rep;

function Seq(pName varchar2, pNodes TY_ABNF_NodeList) return TY_ABNF_Sequence is
begin
  return TY_ABNF_Sequence(NODE_NAME => pName, CHILD_NODES => pNodes);
end Seq;

-- h16 = 1*4HEXDIG
function GetH16Rule return TY_ABNF_Repetition is
begin
  return TY_ABNF_Repetition(NODE_NAME => 'h16', MIN_OCCURS => 1, MAX_OCCURS => 4, CHILD_NODE => P_ABNF_Engine.CoreHexDig());
end GetH16Rule;

-- IPv4address = dec-octet "." dec-octet "." dec-octet "." dec-octet
function GetIPv4AddressRule return TY_ABNF_Sequence is
begin
  return Seq('IPv4address', TY_ABNF_NodeList(
                              GetIPv4OctetRule(), Lit('.')
                            , GetIPv4OctetRule(), Lit('.')
                            , GetIPv4OctetRule(), Lit('.')
                            , GetIPv4OctetRule()
                            ));
end GetIPv4AddressRule;

-- ls32 = ( h16 ":" h16 ) / IPv4address
function GetLs32Rule return TY_ABNF_Alternative is
begin
  return TY_ABNF_Alternative(
           NODE_NAME   => 'ls32'
         , CHILD_NODES => TY_ABNF_NodeList(
                            Seq(null, TY_ABNF_NodeList(GetH16Rule(), Lit(':'), GetH16Rule()))
                          , GetIPv4AddressRule()
                          )
         );
end GetLs32Rule;

-- h16 ":"
function GetH16ColonRule return TY_ABNF_Sequence is
begin
  return Seq(null, TY_ABNF_NodeList(GetH16Rule(), Lit(':')));
end GetH16ColonRule;

-- [ *n( h16 ":" ) h16 ] "::" followed by pTail (pMaxColonGroups null means just [ h16 ])
function GetCompressedForm(pMaxColonGroups integer, pTail TY_ABNF_NodeList) return TY_ABNF_Sequence is
  vNodes  TY_ABNF_NodeList := TY_ABNF_NodeList();
begin
  if pMaxColonGroups = 0 then
    vNodes.extend;
    vNodes(vNodes.count) := Rep(0, 1, GetH16Rule());
  else
    vNodes.extend;
    vNodes(vNodes.count) := Rep(0, 1, Seq(null, TY_ABNF_NodeList(Rep(0, pMaxColonGroups, GetH16ColonRule()), GetH16Rule())));
  end if;

  vNodes.extend;
  vNodes(vNodes.count) := Lit('::');
  for i in 1..pTail.count
  loop
    vNodes.extend;
    vNodes(vNodes.count) := pTail(i);
  end loop;

  return Seq(null, vNodes);
end GetCompressedForm;

------------------------------------------------------------------------------
-- IPv6 address (RFC 3986 section 3.2.2, RFC 4291 section 2.2)
--
-- IPv6address =                            6( h16 ":" ) ls32
--             /                       "::" 5( h16 ":" ) ls32
--             / [               h16 ] "::" 4( h16 ":" ) ls32
--             / [ *1( h16 ":" ) h16 ] "::" 3( h16 ":" ) ls32
--             / [ *2( h16 ":" ) h16 ] "::" 2( h16 ":" ) ls32
--             / [ *3( h16 ":" ) h16 ] "::"    h16 ":"   ls32
--             / [ *4( h16 ":" ) h16 ] "::"              ls32
--             / [ *5( h16 ":" ) h16 ] "::"              h16
--             / [ *6( h16 ":" ) h16 ] "::"
-- h16         = 1*4HEXDIG
-- ls32        = ( h16 ":" h16 ) / IPv4address
--
-- The alternatives overlap, so this only validates with a backtracking matcher.
------------------------------------------------------------------------------
function GetIPv6AddressRule return TY_ABNF_Alternative is
  vResult TY_ABNF_Alternative;
begin
  vResult := TY_ABNF_Alternative(
               NODE_NAME   => 'IPv6address'
             , CHILD_NODES => TY_ABNF_NodeList(
                                Seq(null, TY_ABNF_NodeList(Rep(6, 6, GetH16ColonRule()), GetLs32Rule()))
                              , Seq(null, TY_ABNF_NodeList(Lit('::'), Rep(5, 5, GetH16ColonRule()), GetLs32Rule()))
                              , GetCompressedForm(0, TY_ABNF_NodeList(Rep(4, 4, GetH16ColonRule()), GetLs32Rule()))
                              , GetCompressedForm(1, TY_ABNF_NodeList(Rep(3, 3, GetH16ColonRule()), GetLs32Rule()))
                              , GetCompressedForm(2, TY_ABNF_NodeList(Rep(2, 2, GetH16ColonRule()), GetLs32Rule()))
                              , GetCompressedForm(3, TY_ABNF_NodeList(GetH16ColonRule(), GetLs32Rule()))
                              , GetCompressedForm(4, TY_ABNF_NodeList(GetLs32Rule()))
                              , GetCompressedForm(5, TY_ABNF_NodeList(GetH16Rule()))
                              , GetCompressedForm(6, TY_ABNF_NodeList())
                              )
             );
  return vResult;
end GetIPv6AddressRule;

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
-- GetEmailAddrSpecRule: Returns the full RFC 5322 addr-spec rule
-- addr-spec = local-part "@" domain
------------------------------------------------------------------------------
function GetEmailAddrSpecRule return TY_ABNF_Sequence is
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
end GetEmailAddrSpecRule;

------------------------------------------------------------------------------
-- Rule sets (named rules, so ParseTree can report them). Same grammars as the node builders above.
------------------------------------------------------------------------------
function GetIPv4RuleSet return TY_ABNF_RuleSet is
begin
  return P_ABNF_Engine.ParseGrammar(q'<
IPv4address = dec-octet "." dec-octet "." dec-octet "." dec-octet
dec-octet   = "25" %x30-35 / "2" %x30-34 DIGIT / "1" 2DIGIT / %x31-39 DIGIT / DIGIT
>');
end GetIPv4RuleSet;

function GetIPv6RuleSet return TY_ABNF_RuleSet is
begin
  return P_ABNF_Engine.ParseGrammar(q'<
IPv6address =                            6( h16 ":" ) ls32
            /                       "::" 5( h16 ":" ) ls32
            / [               h16 ] "::" 4( h16 ":" ) ls32
            / [ *1( h16 ":" ) h16 ] "::" 3( h16 ":" ) ls32
            / [ *2( h16 ":" ) h16 ] "::" 2( h16 ":" ) ls32
            / [ *3( h16 ":" ) h16 ] "::"    h16 ":"   ls32
            / [ *4( h16 ":" ) h16 ] "::"              ls32
            / [ *5( h16 ":" ) h16 ] "::"              h16
            / [ *6( h16 ":" ) h16 ] "::"
h16         = 1*4HEXDIG
ls32        = ( h16 ":" h16 ) / IPv4address
IPv4address = dec-octet "." dec-octet "." dec-octet "." dec-octet
dec-octet   = "25" %x30-35 / "2" %x30-34 DIGIT / "1" 2DIGIT / %x31-39 DIGIT / DIGIT
>');
end GetIPv6RuleSet;

function GetEmailRuleSet return TY_ABNF_RuleSet is
begin
  return P_ABNF_Engine.ParseGrammar(q'<
addr-spec      = local-part "@" domain
local-part     = dot-atom-text / quoted-string
domain         = dot-atom-text / domain-literal
dot-atom-text  = 1*atext *("." 1*atext)
atext          = ALPHA / DIGIT / "!" / "#" / "$" / "%" / "&" / "'" / "*" / "+" / "-"
               / "/" / "=" / "?" / "^" / "_" / "`" / "{" / "|" / "}" / "~"
quoted-string  = DQUOTE *qcontent DQUOTE
qcontent       = qtext / WSP / quoted-pair
qtext          = %d33 / %d35-91 / %d93-126
quoted-pair    = "\" (VCHAR / WSP)
domain-literal = "[" (IPv4address / *dtext) "]"
dtext          = %d33-90 / %d94-126
IPv4address    = dec-octet "." dec-octet "." dec-octet "." dec-octet
dec-octet      = "25" %x30-35 / "2" %x30-34 DIGIT / "1" 2DIGIT / %x31-39 DIGIT / DIGIT
>');
end GetEmailRuleSet;

------------------------------------------------------------------------------
-- ValidateEmail (Function overload)
------------------------------------------------------------------------------
function ValidateEmail(pEmail varchar2) return boolean is
  vResult boolean := False;
begin
  vResult := P_ABNF_Engine.ValidateInput(
               pNode  => GetEmailAddrSpecRule()
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
    pNode           => GetEmailAddrSpecRule()
  , pInput          => pEmail
  , pIsValid        => pIsValid
  , pErrorPosition  => pErrorPosition
  , pFailedNodeName => pFailedNodeName
  , pErrorMessage   => pErrorMessage
  );
end ValidateEmail;

------------------------------------------------------------------------------
-- ValidateIPv6 (Function overload)
------------------------------------------------------------------------------
function ValidateIPv6(pAddress varchar2) return boolean is
  vResult boolean := False;
begin
  vResult := P_ABNF_Engine.ValidateInput(
               pNode  => GetIPv6AddressRule()
             , pInput => pAddress
             );
  return vResult;
end ValidateIPv6;

------------------------------------------------------------------------------
-- ValidateIPv6 (Procedure overload)
------------------------------------------------------------------------------
procedure ValidateIPv6(
            pAddress        in  varchar2
          , pIsValid        out boolean
          , pErrorPosition  out integer
          , pFailedNodeName out varchar2
          , pErrorMessage   out varchar2
          ) is
begin
  P_ABNF_Engine.ValidateInput(
    pNode           => GetIPv6AddressRule()
  , pInput          => pAddress
  , pIsValid        => pIsValid
  , pErrorPosition  => pErrorPosition
  , pFailedNodeName => pFailedNodeName
  , pErrorMessage   => pErrorMessage
  );
end ValidateIPv6;

end P_ABNF_Network;
/

