# netdisco-ignoreaddress
SQL-extension for Netdisco to ignore duplicate loopback IPs 

## The Problem

In complicated enterprise networks, loopback IPs might not be unique throughout the network, 
and some of this loopback IPs might be re-used on other devices you'd like to add to Netdisco. 
This doesn't work with the stock Netdisco database, and might create weird conflicts depending 
on which source added the IP to the database first.

## The Solution

This patch adds an additonal table:

       Table "public.ignoreaddress"
        Column     | Type | Modifiers
    ---------------+------+-----------
     uniqueaddress | inet | not null
     ignoreaddress | inet | not null
     
Add pairs of `uniqueaddress` (ie. the `device.ip` of the router with the duplicate address) 
and `ignoreaddress` (ie. the duplicatea address you'll want to ignore from that device) to configure 
what gets ignored.

The actual work is done by two triggers. The first trigger will prevent adding an ignored address to `device_ip`:

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
      
The second deletes entries that were already in `device_ip` before an ignoreaddress entry was added:

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
      

## Installation 

Apply the SQL like this:

    psql -U netdisco < ignoreaddress.sql
   
To add entries:

    psql -U netdisco
    insert into ignoreaddress (uniqueaddress, ignoreaddress) values ('10.2.1.255', '1.1.1.1'); 
   
Should work for both Netdisco 1.3 and 2.   




