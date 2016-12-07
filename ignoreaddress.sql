begin;

CREATE TABLE ignoreaddress
(
  uniqueaddress inet NOT NULL,
  ignoreaddress inet NOT NULL,
  CONSTRAINT ignore_address_pk PRIMARY KEY (uniqueaddress, ignoreaddress)
)
WITH (
  OIDS=FALSE
);

CREATE OR REPLACE FUNCTION ignoreaddress_delete_alias()
  RETURNS trigger AS
$BODY$
    BEGIN
        DELETE FROM device_ip d WHERE d.ip = NEW.uniqueaddress and d.alias = NEW.ignoreaddress;
        RETURN NEW;
    END $BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

CREATE TRIGGER tg_ignoreaddress_delete_alias AFTER INSERT ON ignoreaddress
  FOR EACH ROW EXECUTE PROCEDURE ignoreaddress_delete_alias();

CREATE OR REPLACE FUNCTION ignoreaddress_prevent_alias()
  RETURNS trigger AS
$BODY$
    declare 
        is_in_ignoreaddress boolean;
    begin
        select true from ignoreaddress i where i.uniqueaddress = new.ip and i.ignoreaddress = new.alias limit 1 into is_in_ignoreaddress;
        if is_in_ignoreaddress is true then 
            raise notice 'device % alias % not inserted into device_ip since listed in ignoreaddress', new.ip, new.alias;
            return null;
        else
            return new;
        end if; 
        
    end $BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

CREATE TRIGGER tg_ignoreaddress_prevent_alias BEFORE INSERT ON device_ip
  FOR EACH ROW EXECUTE PROCEDURE ignoreaddress_prevent_alias();

commit;
