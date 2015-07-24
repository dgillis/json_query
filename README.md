# json_query

Use JSON objects to generate ```WHERE``` clause expressions.


## Overview

PostgreSQL provides no simple way to parameterize a query's ```WHERE``` clause
which severly limits the reusability of many types of SQL functions.

For example, given a table tracking customer purchases, it might be useful to
create a function that returns the total of all outstanding amounts:

```SQL
CREATE FUNCTION total_outstanding() RETURNS NUMERIC AS $$
  SELECT SUM(outstanding_amount)
  FROM purchase
  WHERE NOT written_off;
$$ LANGUAGE SQL STABLE;
```

It might also be able to apply some restrictions to the purchases we're
including:

```SQL
-- Includes only purchases made on or after the given date
CREATE FUNCTION total_outstanding_since(since_date DATE) RETURNS NUMERIC AS $$
  SELECT SUM(outstanding_amount)
  FROM purchase
  WHERE NOT written_off AND purchase_date >= since_date;
$$ LANGUAGE SQL STABLE;

-- Includes only purchases made by the specified customer
CREATE FUNCTION total_outstanding_for_customer(cid TEXT) RETURNS NUMERIC AS $$
  SELECT SUM(outstanding_amount)
  FROM purchase
  WHERE NOT written_off AND customer_id = cid;
$$ LANGUAGE SQL STABLE;

-- ... Etc.
```

Creating all of these repetitive variations on a function is tiresome and
so applications will typically construct the query using some programming
language specific query-builder

```SQL
CREATE FUNCTION total_outstanding(filters JSONB) RETURNS NUMERIC AS $$
  SELECT SUM(outstanding_amount)
  FROM purchase p
  WHERE NOT written_off AND json_query.filter(p, filters);
$$ LANGUAGE SQL STABLE;```

This function replaces all of the previous functions:

```SQL
-- Equivalent to total_outstanding():
SELECT total_outstanding('{}');

-- Equivalent to total_outstanding_since_date('2015-01-01'):
SELECT total_outstanding('{"purchase_date__ge": "2015-01-01"}');

-- Equivalent to total_outstanding_for_customer('a'):
SELECT total_outstanding('{"customer_id": "a"}');
```

And can also perform more complex variations of the original query:

```SQL
-- Total outstanding payments due from customers 'a' or 'b' for purchases on
-- or after Jan. 1, 2015:
SELECT total_outstanding('{"purchase_date__ge": "2015-01-01",
                           "customer_id__in": ["a","b"]}');
```

## Performance

All queries made using ```json_query.filter()``` are simplified by Postgres'
query optimizer to the same expression as would be used with the equivalent
inline query. So the only performance difference between json_query.filter()
and its inline equivalent is the time it takes the query optimizer to simplify
the expression, which is typically in the low single-digit milliseconds.

For example, both of the these queries actually use the same query plan, both
making use of the primary key index. Using ```json_query.filter()```:

```SQL
EXPLAIN SELECT * FROM customer c WHERE json_query.filter(c, '{"id": 1000}');

-- Output:

--                                    QUERY PLAN                                    
-- ---------------------------------------------------------------------------------
--  Index Scan using customer_pkey on customer c  (cost=0.29..8.31 rows=1 width=68)
--    Index Cond: (id = 1000)
```

and it's inline equivalent (same query plan as above):

```SQL
EXPLAIN SELECT * FROM customer c WHERE id = 1000;

-- Output:

--                                    QUERY PLAN                                    
-- ---------------------------------------------------------------------------------
--  Index Scan using customer_pkey on customer c  (cost=0.29..8.31 rows=1 width=68)
--    Index Cond: (id = 1000)
```


## API

### Filter object syntax

#### Django-style



To use 

Generate a boolean expression based on a JSONB object using Django-style filter syntax so that
```SQL
SELECT *
FROM tbl t
WHERE json_query.filter(t, '{"<column>__<op>": <value>}')
```
selects the same rows as
```SQL
SELECT *
FROM tbl t
WHERE t.<column> <op> <value>
```
