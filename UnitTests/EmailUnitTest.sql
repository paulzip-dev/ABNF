declare
  vShowOnlyFailures boolean := False;
  vTotalTests       integer := 0;
  vPassCount        integer := 0;
  vFailCount        integer := 0;

  vLastIsValid        boolean;
  vLastErrorPosition  integer;
  vLastFailedNodeName varchar2(4000);
  vLastErrorMessage   varchar2(4000);

  function ValidateEmail(pEmail varchar2) return boolean is
  begin
    P_ABNF_Network.ValidateEmail(
      pEmail          => pEmail
    , pIsValid        => vLastIsValid
    , pErrorPosition  => vLastErrorPosition
    , pFailedNodeName => vLastFailedNodeName
    , pErrorMessage   => vLastErrorMessage
    );
    return vLastIsValid;
  end;

  function FormatBool(pVal boolean) return varchar2 is
  begin
    return case
             when pVal is null then 'null'
             when pVal then 'True'
             else 'False'
           end;
  end FormatBool;

  procedure AssertEquals(
              pTestNum  integer
            , pDesc     varchar2
            , pExpected boolean
            , pActual   boolean
            ) is
    vPassed boolean;
    vStatus varchar2(10);
  begin
    vTotalTests := vTotalTests + 1;

    if (pExpected is null and pActual is null)
       or (pExpected = pActual) then
      vPassed := True;
      vPassCount := vPassCount + 1;
      vStatus := 'PASS';
    else
      vPassed := False;
      vFailCount := vFailCount + 1;
      vStatus := 'FAIL';
    end if;

    if not vShowOnlyFailures or not vPassed then
      DBMS_OUTPUT.PUT_LINE(
        'Test ' || to_char(pTestNum) || ': ' || vStatus
        || ' (Expected: ' || FormatBool(pExpected) || ', Actual: ' || FormatBool(pActual) || ') - '
        || pDesc
      );
      if (not vPassed and not vLastIsValid) or (vPassed and not pExpected) then
        DBMS_OUTPUT.PUT_LINE(
          '  [Diagnostics] ErrorPosition = ' || to_char(vLastErrorPosition)
          || ', FailedNodeName = ' || vLastFailedNodeName
          || ', ErrorMessage = ' || vLastErrorMessage
        );
      elsif not vPassed and vLastIsValid then
        DBMS_OUTPUT.PUT_LINE(
          '  [Diagnostics] Expected False, but email unexpectedly passed validation.'
        );
      end if;
    end if;
  end AssertEquals;

begin
  begin
    -- Test 1: Standard valid email
    AssertEquals(
      pTestNum  => 1
    , pDesc     => 'Standard valid email (john.doe@example.com)'
    , pExpected => True
    , pActual   => ValidateEmail('john.doe@example.com')
    );

    -- Test 2: Valid email with symbol
    AssertEquals(
      pTestNum  => 2
    , pDesc     => 'Valid email with symbol (user+tag@domain.org)'
    , pExpected => True
    , pActual   => ValidateEmail('user+tag@domain.org')
    );

    -- Test 3: Quoted-string local part
    AssertEquals(
      pTestNum  => 3
    , pDesc     => 'Quoted-string local part ("john doe"@example.com)'
    , pExpected => True
    , pActual   => ValidateEmail('"john doe"@example.com')
    );

    -- Test 4: Missing @ symbol
    AssertEquals(
      pTestNum  => 4
    , pDesc     => 'Missing @ symbol (johndoeexample.com)'
    , pExpected => False
    , pActual   => ValidateEmail('johndoeexample.com')
    );

    -- Test 5: Consecutive dots in local-part
    AssertEquals(
      pTestNum  => 5
    , pDesc     => 'Consecutive dots in local-part (john..doe@example.com)'
    , pExpected => False
    , pActual   => ValidateEmail('john..doe@example.com')
    );

  exception
    when OTHERS then
      DBMS_OUTPUT.PUT_LINE('Unhandled exception during execution: ' || SQLERRM);
  end;

  DBMS_OUTPUT.PUT_LINE('----------------------------------------');
  DBMS_OUTPUT.PUT_LINE('Total Tests : ' || to_char(vTotalTests));
  DBMS_OUTPUT.PUT_LINE('Passed      : ' || to_char(vPassCount));
  DBMS_OUTPUT.PUT_LINE('Failed      : ' || to_char(vFailCount));
  DBMS_OUTPUT.PUT_LINE('----------------------------------------');
end;
/
