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
  DropType('TY_ABNF_REPETITION');
  DropType('TY_ABNF_ALTERNATIVE');
  DropType('TY_ABNF_SEQUENCE');
  DropType('TY_ABNF_RANGE');
  DropType('TY_ABNF_LITERAL');
  DropType('TY_ABNF_NODELIST');
  DropType('TY_ABNF_NODE');
end;
/

create or replace
type TY_ABNF_Node as object (
  NODE_NAME varchar2(128)
, member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pFailPos        in out integer
  , pFailNode       in out varchar2
  ) return integer
) not final not instantiable;
/

create or replace
type body TY_ABNF_Node is

  member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pFailPos        in out integer
  , pFailNode       in out varchar2
  ) return integer is
  begin
    return -1;
  end MatchInput;

end;
/

create or replace
type TY_ABNF_Literal under TY_ABNF_Node (
  VALUE varchar2(32767)
, overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pFailPos        in out integer
  , pFailNode       in out varchar2
  ) return integer
);
/

create or replace
type body TY_ABNF_Literal is

  overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pFailPos        in out integer
  , pFailNode       in out varchar2
  ) return integer is
    vMatchLen integer := 0;
  begin
    if self.VALUE is not null then
      vMatchLen := length(self.VALUE);
      if substr(pInput, pOffset, vMatchLen) = self.VALUE then
        return vMatchLen;
      end if;
    end if;

    if pOffset > pFailPos then
      pFailPos  := pOffset;
      pFailNode := nvl(self.NODE_NAME, 'LITERAL');
    end if;

    return -1;
  end MatchInput;

end;
/

create or replace
type TY_ABNF_Range under TY_ABNF_Node (
  MIN_CODE integer
, MAX_CODE integer
, overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pFailPos        in out integer
  , pFailNode       in out varchar2
  ) return integer
);
/

create or replace
type body TY_ABNF_Range is

  overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pFailPos        in out integer
  , pFailNode       in out varchar2
  ) return integer is
    vCode integer;
  begin
    if pOffset <= length(pInput) then
      vCode := ascii(substr(pInput, pOffset, 1));
      if vCode >= self.MIN_CODE and vCode <= self.MAX_CODE then
        return 1;
      end if;
    end if;

    if pOffset > pFailPos then
      pFailPos  := pOffset;
      pFailNode := nvl(self.NODE_NAME, 'RANGE');
    end if;

    return -1;
  end MatchInput;

end;
/

create or replace
type TY_ABNF_NodeList as table of TY_ABNF_Node;
/

create or replace
type TY_ABNF_Sequence under TY_ABNF_Node (
  CHILD_NODES TY_ABNF_NodeList
, overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pFailPos        in out integer
  , pFailNode       in out varchar2
  ) return integer
);
/

create or replace
type body TY_ABNF_Sequence is

  overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pFailPos        in out integer
  , pFailNode       in out varchar2
  ) return integer is
    vCurrPos  integer := pOffset;
    vMatchLen integer := 0;
    vSubLen   integer := 0;
  begin
    if self.CHILD_NODES is not null then
      for i in 1 .. self.CHILD_NODES.count loop
        if self.CHILD_NODES(i) is not null then
          vSubLen := self.CHILD_NODES(i).MatchInput(
                       pInput    => pInput
                     , pOffset   => vCurrPos
                     , pFailPos  => pFailPos
                     , pFailNode => pFailNode
                     );

          if vSubLen < 0 then
            return -1;
          end if;

          vCurrPos  := vCurrPos + vSubLen;
          vMatchLen := vMatchLen + vSubLen;
        end if;
      end loop;
    end if;

    return vMatchLen;
  end MatchInput;

end;
/

create or replace
type TY_ABNF_Alternative under TY_ABNF_Node (
  CHILD_NODES TY_ABNF_NodeList
, overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pFailPos        in out integer
  , pFailNode       in out varchar2
  ) return integer
);
/

create or replace
type body TY_ABNF_Alternative is

  overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pFailPos        in out integer
  , pFailNode       in out varchar2
  ) return integer is
    vSubLen integer := 0;
  begin
    if self.CHILD_NODES is not null then
      for i in 1 .. self.CHILD_NODES.count loop
        if self.CHILD_NODES(i) is not null then
          vSubLen := self.CHILD_NODES(i).MatchInput(
                       pInput    => pInput
                     , pOffset   => pOffset
                     , pFailPos  => pFailPos
                     , pFailNode => pFailNode
                     );

          if vSubLen >= 0 then
            return vSubLen;
          end if;
        end if;
      end loop;
    end if;

    if pOffset > pFailPos then
      pFailPos  := pOffset;
      pFailNode := nvl(self.NODE_NAME, 'ALT');
    end if;

    return -1;
  end MatchInput;

end;
/

create or replace
type TY_ABNF_Repetition under TY_ABNF_Node (
  MIN_OCCURS integer
, MAX_OCCURS integer
, CHILD_NODE TY_ABNF_Node
, overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pFailPos        in out integer
  , pFailNode       in out varchar2
  ) return integer
);
/

create or replace
type body TY_ABNF_Repetition is

  overriding member function MatchInput(
    pInput          in     varchar2
  , pOffset         in     integer
  , pFailPos        in out integer
  , pFailNode       in out varchar2
  ) return integer is
    vCurrPos  integer := pOffset;
    vMatchLen integer := 0;
    vSubLen   integer := 0;
    vCount    integer := 0;
    vLoop     boolean := True;
  begin
    if self.CHILD_NODE is not null then
      while vLoop loop
        if self.MAX_OCCURS is not null and vCount >= self.MAX_OCCURS then
          vLoop := False;
        else
          vSubLen := self.CHILD_NODE.MatchInput(
                       pInput    => pInput
                     , pOffset   => vCurrPos
                     , pFailPos  => pFailPos
                     , pFailNode => pFailNode
                     );

          if vSubLen < 0 then
            vLoop := False;
          elsif vSubLen = 0 then
            vCount := vCount + 1;
            vLoop  := False;
          else
            vCount    := vCount + 1;
            vCurrPos  := vCurrPos + vSubLen;
            vMatchLen := vMatchLen + vSubLen;
          end if;
        end if;
      end loop;
    end if;

    if vCount >= nvl(self.MIN_OCCURS, 0) then
      return vMatchLen;
    end if;

    if pOffset > pFailPos then
      pFailPos  := pOffset;
      pFailNode := nvl(self.NODE_NAME, 'REPEAT');
    end if;

    return -1;
  end MatchInput;

end;
/
