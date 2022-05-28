--
-- Timezone
--

SET timezone = 'America/Los_Angeles';

---
--- Extensions
---

----------------------------------------------------------------------
-- The uuid-ossp extension offers functions to generate UUIDs. 
-- Note that because of the hyphen in the name, you have to 
-- quote the name of the extension.  Note that you should always 
-- use the PostgreSQL data type uuid for UUIDs. Don’t try to 
-- convert them to strings or numeric — you will waste space and lose performance.
----------------------------------------------------------------------

CREATE EXTENSION "uuid-ossp";

--
-- Customer Table
--

----------------------------------------------------------------------
-- When naming tables, you have two options – to use the singular for 
-- the table name or to use a plural. My suggestion would be to always 
-- go with names in the singular. If you’re naming entities that represent 
-- real-world facts, you should use nouns. These are tables like employee, -
-- customer, city, and country. If possible, use a single word that exactly 
-- describes what is in the table. 
----------------------------------------------------------------------

----------------------------------------------------------------------
-- PostgreSQL includes the following column constraints
----------------------------------------------------------------------
-- NOT NULL – ensures that values in a column cannot be NULL.
-- UNIQUE – ensures the values in a column unique across the rows within the same table.
-- PRIMARY KEY – a primary key column uniquely identify rows in a table.
-- CHECK – a CHECK constraint ensures the data must satisfy a boolean expression.
-- FOREIGN KEY – ensures values in a column or a group of columns from a table exists in a column or group of columns in another table. Unlike the primary key, a table can have many foreign keys.
----------------------------------------------------------------------

DROP TABLE IF EXISTS public.customer;

CREATE TABLE IF NOT EXISTS public.customer (
	id bigint GENERATED ALWAYS AS IDENTITY (CACHE 200) PRIMARY KEY,
    --- bigint uses only eight bytes, while uuid uses 16 bytes.
    --- id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
	first_name VARCHAR(50) NOT NULL,
	last_name VARCHAR(50) NOT NULL,
	email VARCHAR(255) UNIQUE NOT NULL,
    active boolean NOT NULL DEFAULT true,
	created TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE IF EXISTS public.customer
    OWNER to postgres;

ALTER TABLE IF EXISTS public.customer REPLICA IDENTITY USING INDEX customer_pkey;

--
-- Index: idx_last_name
--

DROP INDEX IF EXISTS public.idx_last_name;

CREATE INDEX IF NOT EXISTS idx_last_name
    ON public.customer USING btree
    (last_name COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;

--
-- FUNCTION: public.last_updated()
--

DROP FUNCTION IF EXISTS public.last_updated();

CREATE OR REPLACE FUNCTION public.last_updated()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100 VOLATILE NOT LEAKPROOF
AS $BODY$
BEGIN
    NEW.updated = CURRENT_TIMESTAMP;
    RETURN NEW;
END 
$BODY$;

ALTER FUNCTION public.last_updated()
    OWNER TO postgres;

--
-- Trigger: last_updated
--

DROP TRIGGER IF EXISTS last_updated ON public.customer;

CREATE TRIGGER last_updated
    BEFORE UPDATE 
    ON public.customer
    FOR EACH ROW
    EXECUTE FUNCTION public.last_updated();

---
--- Sample Data
---

INSERT INTO customer (first_name, last_name, email)
	VALUES
        ('Fred', 'Flintstone', 'fred@gmail.com')
    ;

---
--- Tests
---

-- --- Insert new customer
-- INSERT INTO customer (first_name, last_name, email)
-- 	VALUES ('Dan', 'Stroot', 'dan.stroot@gmail.com');

-- --- Update customer
-- UPDATE
-- 	customer
-- SET
-- 	active = FALSE
-- WHERE
-- 	id = 1;
