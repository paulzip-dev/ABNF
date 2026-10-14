create or replace package P_UT_ABNF_Network is

--%suite(ABNF network rules: IPv4 octet, IPv6 address and e-mail address)
--%rollback(manual)

------------------------------------------------------------------------------
-- IPv4 octet
------------------------------------------------------------------------------
--%test(IPv4 octets 0 to 255 are valid)
procedure IPv4OctetValid;

--%test(IPv4 octets outside 0 to 255 or with leading zeros are invalid)
procedure IPv4OctetInvalid;

------------------------------------------------------------------------------
-- IPv6 address
------------------------------------------------------------------------------
--%test(Full eight group IPv6 addresses are valid)
procedure IPv6Full;

--%test(Compressed IPv6 addresses with :: are valid)
procedure IPv6Compressed;

--%test(IPv6 addresses ending in an IPv4 address are valid)
procedure IPv6EmbeddedIPv4;

--%test(Hex digits are case-insensitive)
procedure IPv6HexCase;

--%test(:: stands for any number of groups, including the extremes)
procedure IPv6CompressionExtremes;

--%test(Malformed IPv6 addresses are invalid)
procedure IPv6Invalid;

--%test(IPv6 with too many or too few groups is invalid)
procedure IPv6GroupCount;

--%test(ValidateIPv6 procedure reports why an address is invalid)
procedure IPv6Explains;

------------------------------------------------------------------------------
-- E-mail
------------------------------------------------------------------------------
--%test(Valid e-mail addresses)
procedure EmailValid;

--%test(Invalid e-mail addresses)
procedure EmailInvalid;

--%test(ValidateEmail procedure reports why an address is invalid)
procedure EmailExplains;

------------------------------------------------------------------------------
-- Rule sets
------------------------------------------------------------------------------
--%test(Rule sets accept and reject the same inputs as the node rules)
procedure RuleSetsAgree;

--%test(Email rule set parses an address into local-part and domain)
procedure EmailParseTree;

------------------------------------------------------------------------------
-- URI
------------------------------------------------------------------------------
--%test(Valid URIs: hierarchical, rootless and empty paths)
procedure UriValid;

--%test(Valid URIs with an IPv4, IPv6 or IPvFuture host)
procedure UriIpHosts;

--%test(Invalid URIs)
procedure UriInvalid;

--%test(URI-reference accepts URIs and relative references)
procedure UriReference;

--%test(relative-ref and absolute-URI start rules)
procedure UriStartRules;

--%test(URI rule set parses a URI into its components)
procedure UriParseTree;

--%test(ExplainMismatch points at the invalid character in a URI)
procedure UriExplains;

end P_UT_ABNF_Network;
/

create or replace package body P_UT_ABNF_Network is

-- Avoids a literal ampersand, which SQL*Plus would treat as a substitution variable
AMPERSAND constant varchar2(1) := chr(38);

procedure ExpectOctet(pInput varchar2, pExpected boolean) is
begin
  ut.expect(
    P_ABNF_Engine.ValidateInput(P_ABNF_Network.GetIPv4OctetRule(), pInput)
  , 'IPv4 octet <' || pInput || '>'
  ).to_equal(pExpected);
end ExpectOctet;

procedure ExpectIPv6(pAddress varchar2, pExpected boolean) is
begin
  ut.expect(P_ABNF_Network.ValidateIPv6(pAddress), 'IPv6 <' || pAddress || '>').to_equal(pExpected);
end ExpectIPv6;

procedure ExpectEmail(pEmail varchar2, pExpected boolean) is
begin
  ut.expect(P_ABNF_Network.ValidateEmail(pEmail), 'E-mail <' || pEmail || '>').to_equal(pExpected);
end ExpectEmail;

procedure ExpectUri(pUri varchar2, pStartRule varchar2, pExpected boolean) is
begin
  ut.expect(P_ABNF_Network.ValidateUri(pUri, pStartRule), pStartRule || ' <' || pUri || '>').to_equal(pExpected);
end ExpectUri;

------------------------------------------------------------------------------
-- IPv4 octet
------------------------------------------------------------------------------
procedure IPv4OctetValid is
begin
  for rec in (
    select to_char(LEVEL - 1) as OCTET
    from dual
    connect by LEVEL <= 256
  )
  loop
    ExpectOctet(rec.OCTET, True);
  end loop;
end IPv4OctetValid;

procedure IPv4OctetInvalid is
begin
  ExpectOctet('256', False);
  ExpectOctet('260', False);
  ExpectOctet('300', False);
  ExpectOctet('999', False);
  ExpectOctet('1000', False);
  ExpectOctet('01', False);
  ExpectOctet('00', False);
  ExpectOctet('001', False);
  ExpectOctet('-1', False);
  ExpectOctet('1.', False);
  ExpectOctet('a', False);
  ExpectOctet(' 1', False);
  ExpectOctet(null, False);
end IPv4OctetInvalid;

------------------------------------------------------------------------------
-- IPv6 address
------------------------------------------------------------------------------
procedure IPv6Full is
begin
  ExpectIPv6('1:2:3:4:5:6:7:8', True);
  ExpectIPv6('2001:0db8:0000:0000:0000:ff00:0042:8329', True);
  ExpectIPv6('ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff', True);
  ExpectIPv6('0:0:0:0:0:0:0:0', True);
end IPv6Full;

procedure IPv6Compressed is
begin
  ExpectIPv6('::', True);
  ExpectIPv6('::1', True);
  ExpectIPv6('1::', True);
  ExpectIPv6('fe80::', True);
  ExpectIPv6('2001:db8::1', True);
  ExpectIPv6('2001:db8:85a3::8a2e:370:7334', True);
  ExpectIPv6('1::8', True);
  ExpectIPv6('1:2::7:8', True);
  ExpectIPv6('1:2:3::6:7:8', True);
  ExpectIPv6('1:2:3:4::7:8', True);
  ExpectIPv6('1:2:3:4:5::8', True);
  ExpectIPv6('1:2:3:4:5:6::8', True);
end IPv6Compressed;

procedure IPv6EmbeddedIPv4 is
begin
  ExpectIPv6('::ffff:192.0.2.1', True);
  ExpectIPv6('::192.0.2.1', True);
  ExpectIPv6('64:ff9b::192.0.2.33', True);
  ExpectIPv6('1:2:3:4:5:6:1.2.3.4', True);
  ExpectIPv6('::255.255.255.255', True);
  ExpectIPv6('::1.2.3', False);
  ExpectIPv6('::1.2.3.256', False);
  ExpectIPv6('::1.2.3.4.5', False);
  ExpectIPv6('1:2:3:4:5:6:7:1.2.3.4', False);
end IPv6EmbeddedIPv4;

procedure IPv6HexCase is
begin
  ExpectIPv6('FE80::1', True);
  ExpectIPv6('Fe80::AbCd', True);
  ExpectIPv6('ABCD:EF01:2345:6789:ABCD:EF01:2345:6789', True);
end IPv6HexCase;

procedure IPv6CompressionExtremes is
begin
  ExpectIPv6('::2:3:4:5:6:7:8', True);
  ExpectIPv6('1:2:3:4:5:6:7::', True);
  ExpectIPv6('1::3:4:5:6:7:8', True);
  ExpectIPv6('::3:4:5:6:7:8', True);
end IPv6CompressionExtremes;

procedure IPv6Invalid is
begin
  ExpectIPv6(null, False);
  ExpectIPv6(':', False);
  ExpectIPv6(':::', False);
  ExpectIPv6('1:::2', False);
  ExpectIPv6('1::2::3', False);
  ExpectIPv6('12345::', False);
  ExpectIPv6('g::1', False);
  ExpectIPv6('::g', False);
  ExpectIPv6(':1::', False);
  ExpectIPv6('1::2:', False);
  ExpectIPv6('::1 ', False);
  ExpectIPv6(' ::1', False);
  ExpectIPv6('1.2.3.4', False);
  ExpectIPv6('[::1]', False);
  ExpectIPv6('::1%eth0', False);
end IPv6Invalid;

procedure IPv6GroupCount is
begin
  ExpectIPv6('1:2:3:4:5:6:7', False);
  ExpectIPv6('1:2:3:4:5:6:7:8:9', False);
  ExpectIPv6('1:2:3:4:5:6:7:8::', False);
  ExpectIPv6('::1:2:3:4:5:6:7:8', False);
  ExpectIPv6('1:2:3:4::5:6:7:8', False);
end IPv6GroupCount;

procedure IPv6Explains is
  vIsValid        boolean;
  vErrorPosition  integer;
  vFailedNodeName varchar2(4000);
  vErrorMessage   varchar2(4000);
begin
  P_ABNF_Network.ValidateIPv6('2001:db8::1', vIsValid, vErrorPosition, vFailedNodeName, vErrorMessage);
  ut.expect(vIsValid).to_be_true();
  ut.expect(vErrorMessage).to_be_null();

  P_ABNF_Network.ValidateIPv6('2001:db8::g', vIsValid, vErrorPosition, vFailedNodeName, vErrorMessage);
  ut.expect(vIsValid).to_be_false();
  ut.expect(vErrorPosition).to_be_not_null();
  ut.expect(vErrorMessage).to_be_like('Line 1, column %');

  -- the explanation points at the furthest position the address could have matched to
  P_ABNF_Network.ValidateIPv6('1:2:3:4:5:6:7:8:9', vIsValid, vErrorPosition, vFailedNodeName, vErrorMessage);
  ut.expect(vIsValid).to_be_false();
  ut.expect(vErrorPosition).to_equal(16);
end IPv6Explains;

------------------------------------------------------------------------------
-- E-mail
------------------------------------------------------------------------------
procedure EmailValid is
begin
  ExpectEmail('john.doe@example.com', True);
  ExpectEmail('user+tag@domain.org', True);
  ExpectEmail('"john doe"@example.com', True);
  ExpectEmail('a@b', True);
  ExpectEmail('a@b.co', True);
  ExpectEmail('first.last@sub.domain.example.com', True);
  ExpectEmail('o''brien@example.com', True);
  ExpectEmail('user@[192.168.0.1]', True);
  ExpectEmail('"quoted\"quote"@example.com', True);
end EmailValid;

procedure EmailInvalid is
begin
  ExpectEmail('johndoeexample.com', False);
  ExpectEmail('john..doe@example.com', False);
  ExpectEmail('@example.com', False);
  ExpectEmail('user@', False);
  ExpectEmail('.user@example.com', False);
  ExpectEmail('user.@example.com', False);
  ExpectEmail('john doe@example.com', False);
  ExpectEmail('user@@example.com', False);
  ExpectEmail('user@exam ple.com', False);
  ExpectEmail('user@example..com', False);
  ExpectEmail(null, False);
end EmailInvalid;

procedure EmailExplains is
  vIsValid        boolean;
  vErrorPosition  integer;
  vFailedNodeName varchar2(4000);
  vErrorMessage   varchar2(4000);
begin
  P_ABNF_Network.ValidateEmail('john.doe@example.com', vIsValid, vErrorPosition, vFailedNodeName, vErrorMessage);
  ut.expect(vIsValid).to_be_true();
  ut.expect(vErrorPosition).to_be_null();
  ut.expect(vErrorMessage).to_be_null();

  P_ABNF_Network.ValidateEmail('john..doe@example.com', vIsValid, vErrorPosition, vFailedNodeName, vErrorMessage);
  ut.expect(vIsValid).to_be_false();
  -- "john." was read, then an atext was required but a second "." was found
  ut.expect(vErrorPosition).to_equal(6);
  ut.expect(vErrorMessage).to_be_like('Line 1, column 6: found "."%');

  P_ABNF_Network.ValidateEmail('johndoeexample.com', vIsValid, vErrorPosition, vFailedNodeName, vErrorMessage);
  ut.expect(vIsValid).to_be_false();
  ut.expect(vErrorMessage).to_be_like('%unexpected end of input%');
end EmailExplains;

------------------------------------------------------------------------------
-- Rule sets
------------------------------------------------------------------------------
procedure RuleSetsAgree is
  vEmails sys.odcivarchar2list := sys.odcivarchar2list(
            'john.doe@example.com', '"quoted\"quote"@example.com', 'a@[192.168.0.1]', 'a@[x y]'
          , 'john..doe@example.com', 'johndoeexample.com', '@example.com', 'a@');
  vIPv6s  sys.odcivarchar2list := sys.odcivarchar2list(
            '2001:db8::1', '::', '::1', '1:2:3:4:5:6:7:8', '::ffff:192.0.2.1'
          , '1:2:3:4:5:6:7', '1::2::3', 'g::1', '1:2:3:4:5:6:7:8:9');
  vIPv4s  sys.odcivarchar2list := sys.odcivarchar2list(
            '1.2.3.4', '255.255.255.255', '0.0.0.0', '256.1.1.1', '1.2.3', '01.2.3.4');
begin
  for i in 1..vEmails.count
  loop
    ut.expect(P_ABNF_Engine.ValidateInput(P_ABNF_Network.GetEmailRuleSet, 'addr-spec', vEmails(i)), 'E-mail <' || vEmails(i) || '>')
      .to_equal(P_ABNF_Network.ValidateEmail(vEmails(i)));
  end loop;
  for i in 1..vIPv6s.count
  loop
    ut.expect(P_ABNF_Engine.ValidateInput(P_ABNF_Network.GetIPv6RuleSet, 'IPv6address', vIPv6s(i)), 'IPv6 <' || vIPv6s(i) || '>')
      .to_equal(P_ABNF_Network.ValidateIPv6(vIPv6s(i)));
  end loop;
  for i in 1..vIPv4s.count
  loop
    ut.expect(P_ABNF_Engine.ValidateInput(P_ABNF_Network.GetIPv4RuleSet, 'IPv4address', vIPv4s(i)), 'IPv4 <' || vIPv4s(i) || '>')
      .to_equal(P_ABNF_Engine.ValidateInput(
                  TY_ABNF_Sequence(NODE_NAME => null, CHILD_NODES => TY_ABNF_NodeList(
                    P_ABNF_Network.GetIPv4OctetRule(), TY_ABNF_Literal(NODE_NAME => null, VALUE => '.')
                  , P_ABNF_Network.GetIPv4OctetRule(), TY_ABNF_Literal(NODE_NAME => null, VALUE => '.')
                  , P_ABNF_Network.GetIPv4OctetRule(), TY_ABNF_Literal(NODE_NAME => null, VALUE => '.')
                  , P_ABNF_Network.GetIPv4OctetRule()))
                , vIPv4s(i)));
  end loop;
end RuleSetsAgree;

procedure EmailParseTree is
  vLocal  varchar2(4000);
  vDomain varchar2(4000);
begin
  select max(case t.RULE_NAME when 'local-part' then t.TEXT end)
       , max(case t.RULE_NAME when 'domain' then t.TEXT end)
  into vLocal, vDomain
  from table(P_ABNF_Engine.ParseTree(P_ABNF_Network.GetEmailRuleSet, 'addr-spec', '"quoted\"quote"@example.com')) t;
  ut.expect(vLocal).to_equal('"quoted\"quote"');
  ut.expect(vDomain).to_equal('example.com');
end EmailParseTree;

------------------------------------------------------------------------------
-- URI
------------------------------------------------------------------------------
procedure UriValid is
begin
  ExpectUri('http://example.com', 'URI', True);
  ExpectUri('https://user:pw@example.com:8080/p/a/t/h?q=1' || AMPERSAND || 'r=2#frag', 'URI', True);
  ExpectUri('http://example.com/a%20b', 'URI', True);
  ExpectUri('http://example.com?x', 'URI', True);
  ExpectUri('http://example.com:/', 'URI', True);
  ExpectUri('file:///etc/hosts', 'URI', True);
  ExpectUri('mailto:john.doe@example.com', 'URI', True);
  ExpectUri('urn:isbn:0451450523', 'URI', True);
  ExpectUri('a+b-c.d:/x', 'URI', True);
  ExpectUri('mailto:', 'URI', True);
  ExpectUri('x:#', 'URI', True);
  ExpectUri('http://example.com/?a/b?c', 'URI', True);
end UriValid;

procedure UriIpHosts is
begin
  ExpectUri('ftp://192.168.0.1/x', 'URI', True);
  ExpectUri('http://[2001:db8::1]:80/', 'URI', True);
  ExpectUri('http://[::1]', 'URI', True);
  ExpectUri('http://[::ffff:192.0.2.1]/', 'URI', True);
  ExpectUri('http://[v7.fe80:a]/', 'URI', True);
  -- not a valid IPv4address, so it is read as a reg-name
  ExpectUri('http://256.1.1.1/', 'URI', True);
  ExpectUri('http://[::g]/', 'URI', False);
  ExpectUri('http://[1:2:3:4:5:6:7]/', 'URI', False);
  ExpectUri('http://[::1/', 'URI', False);
  ExpectUri('http://[v.x]/', 'URI', False);
end UriIpHosts;

procedure UriInvalid is
begin
  ExpectUri(null, 'URI', False);
  ExpectUri('//example.com', 'URI', False);
  ExpectUri('/a/b', 'URI', False);
  ExpectUri('1http://example.com', 'URI', False);
  ExpectUri(':foo', 'URI', False);
  ExpectUri('http://exa mple.com', 'URI', False);
  ExpectUri('http://example.com/a b', 'URI', False);
  ExpectUri('http://example.com/%zz', 'URI', False);
  ExpectUri('http://example.com/%2', 'URI', False);
  ExpectUri('http://example.com:80a/', 'URI', False);
  ExpectUri('http://example.com#a#b', 'URI', False);
  ExpectUri('http://[::1]x', 'URI', False);
  ExpectUri('http://exa<mple.com', 'URI', False);
end UriInvalid;

procedure UriReference is
begin
  ExpectUri('http://example.com/a', 'URI-reference', True);
  ExpectUri('//example.com/p', 'URI-reference', True);
  ExpectUri('/a/b', 'URI-reference', True);
  ExpectUri('a/b', 'URI-reference', True);
  ExpectUri('../x?y#z', 'URI-reference', True);
  ExpectUri('?q', 'URI-reference', True);
  ExpectUri('#f', 'URI-reference', True);
  ExpectUri('', 'URI-reference', True);
  ExpectUri('a:b', 'URI-reference', True);
  ExpectUri('http://exa mple.com', 'URI-reference', False);
  ExpectUri('#a#b', 'URI-reference', False);
end UriReference;

procedure UriStartRules is
begin
  -- the first segment of a relative path may not contain a colon
  ExpectUri('a:b/c', 'relative-ref', False);
  ExpectUri('./a:b', 'relative-ref', True);
  ExpectUri('/a:b', 'relative-ref', True);
  ExpectUri('//example.com', 'relative-ref', True);
  -- absolute-URI has no fragment
  ExpectUri('http://example.com/x?y', 'absolute-URI', True);
  ExpectUri('http://example.com/x?y#f', 'absolute-URI', False);
  ExpectUri('/x', 'absolute-URI', False);
end UriStartRules;

procedure UriParseTree is
  vScheme    varchar2(4000);
  vUserinfo  varchar2(4000);
  vHost      varchar2(4000);
  vPort      varchar2(4000);
  vPath      varchar2(4000);
  vQuery     varchar2(4000);
  vFragment  varchar2(4000);
begin
  select max(case t.RULE_NAME when 'scheme' then t.TEXT end)
       , max(case t.RULE_NAME when 'userinfo' then t.TEXT end)
       , max(case t.RULE_NAME when 'host' then t.TEXT end)
       , max(case t.RULE_NAME when 'port' then t.TEXT end)
       , max(case t.RULE_NAME when 'path-abempty' then t.TEXT end)
       , max(case t.RULE_NAME when 'query' then t.TEXT end)
       , max(case t.RULE_NAME when 'fragment' then t.TEXT end)
  into vScheme, vUserinfo, vHost, vPort, vPath, vQuery, vFragment
  from table(P_ABNF_Engine.ParseTree(P_ABNF_Network.GetUriRuleSet, 'URI', 'https://jo@example.com:8080/a/b?q=1#top')) t;
  ut.expect(vScheme).to_equal('https');
  ut.expect(vUserinfo).to_equal('jo');
  ut.expect(vHost).to_equal('example.com');
  ut.expect(vPort).to_equal('8080');
  ut.expect(vPath).to_equal('/a/b');
  ut.expect(vQuery).to_equal('q=1');
  ut.expect(vFragment).to_equal('top');
end UriParseTree;

procedure UriExplains is
begin
  ut.expect(P_ABNF_Engine.ExplainMismatch(P_ABNF_Network.GetUriRuleSet, 'URI', 'http://example.com/a')).to_be_null();
  ut.expect(P_ABNF_Engine.ExplainMismatch(P_ABNF_Network.GetUriRuleSet, 'URI', 'http://exa mple.com'))
    .to_be_like('Line 1, column 11: unexpected input " "%');
end UriExplains;

end P_UT_ABNF_Network;
/
