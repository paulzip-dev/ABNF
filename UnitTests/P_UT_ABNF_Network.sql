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

end P_UT_ABNF_Network;
/

create or replace package body P_UT_ABNF_Network is

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

end P_UT_ABNF_Network;
/
