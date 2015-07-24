/*
_col_value(valtyp, row, fld)

Return either text/jsonb (depending on valtyp) value representing the row's
value for the specified field.

**** Requires implementation to be used with specific row types.
*/



-- _jq_extract_helper(row<anyelement>, fld<fldexpr|fldtype>, typ<*>)
create function _pg_json_query._jq_val_helper(
  row_ anyelement,
  fld _pg_json_query._field_type,
  typ jsonb
) returns jsonb language sql immutable as $$
  select case fld.path_arr_len
    when 0 then
      _pg_json_query._jq_col_val_impl(row_, fld.column_, typ)
    else
      _pg_json_query._field_extract_from_column(
        fld,
        _pg_json_query._jq_col_val_impl(row_, fld.column_, typ)
      )
    end;
$$;

create function _pg_json_query._jq_val_helper(
  row_ anyelement,
  fld _pg_json_query._field_type,
  typ json
) returns json language sql immutable as $$
  select case fld.path_arr_len
    when 0 then
      _pg_json_query._jq_col_val_impl(row_, fld.column_, typ)
    else
      _pg_json_query._field_extract_from_column(
        fld,
        _pg_json_query._jq_col_val_impl(row_, fld.column_, typ)
      )
    end;
$$;

create function _pg_json_query._jq_val_helper(
  row_ anyelement, 
  fld _pg_json_query._field_type,
  typ text
) returns text language sql immutable as $$
  select case fld.path_arr_len
    when 0 then 
      _pg_json_query._jq_col_val_impl(row_, fld.column_, typ)
    else
      _pg_json_query._field_extract_text_from_column(
        fld,
        _pg_json_query._jq_col_val_impl(row_, fld.column_, null::jsonb)
      )
    end;
$$;

create function _pg_json_query._jq_val_helper(
  row_ anyelement,
  fldexpr text,
  typ jsonb
) returns jsonb language sql immutable as $$
  select _pg_json_query._jq_val_helper(
    row_, _pg_json_query._field_type(fldexpr), typ
  );
$$;

create function _pg_json_query._jq_val_helper(
  row_ anyelement,
  fldexpr text,
  typ json
) returns json language sql immutable as $$
  select _pg_json_query._jq_val_helper(
    row_, _pg_json_query._field_type(fldexpr), typ
  );
$$;

create function _pg_json_query._jq_val_helper(
  row_ anyelement,
  fldexpr text,
  typ text
) returns text language sql immutable as $$
  select _pg_json_query._jq_val_helper(
    row_, _pg_json_query._field_type(fldexpr), typ
  );
$$;



-- text version.
-- To use with a row type, implement json_col_base_value_impl(text, <rowtype>, text)
-- that returns a textual representation of the specified column.
--create function _pg_json_query._col_value(valtyp text, row_ anyelement, fld text)
create function jq_val(row_ anyelement, colname text, typ text)
returns text language sql immutable as $$
  select _pg_json_query._jq_val_helper(row_, colname, typ);
$$;


create function jq_val(row_ anyelement, colname text, typ jsonb)
returns jsonb language sql immutable as $$
  select _pg_json_query._jq_val_helper(row_, colname, typ);
$$;


create function jq_val(row_ anyelement, colname text, typ json)
returns json language sql immutable as $$
  select _pg_json_query._jq_val_helper(row_, colname, typ);
$$;


-- Helper for jq_val(row_, jsonb_array) when the arrays are long.
create function _pg_json_query._jq_val_jsonb_arr(row_ anyelement, arr jsonb)
returns jsonb
language sql immutable
as $$
  select coalesce(json_agg(jq_val(row_, el, null::json)
                           order by idx)::jsonb, '[]')
  from jsonb_array_elements_text(arr) with ordinality o(el, idx);
$$;


create function jq_val(row_ anyelement, colexpr jsonb, typ jsonb)
returns jsonb
language sql immutable
as $$
  select case jsonb_typeof(colexpr)
    when 'array' then
      case jsonb_array_length(colexpr)
        when 0 then
          '[]'
        when 1 then
           _pg_json_query._build_array(
             coalesce(
               _pg_json_query._jq_val_helper(row_, colexpr->>0, typ), 'null'))
        when 2 then
           _pg_json_query._build_array(
             coalesce(
               _pg_json_query._jq_val_helper(row_, colexpr->>0, typ), 'null'),
             coalesce(
               _pg_json_query._jq_val_helper(row_, colexpr->>1, typ), 'null'))
        when 3 then
           _pg_json_query._build_array(
             coalesce(
               _pg_json_query._jq_val_helper(row_, colexpr->>0, typ), 'null'),
             coalesce(
               _pg_json_query._jq_val_helper(row_, colexpr->>1, typ), 'null'),
             coalesce(
               _pg_json_query._jq_val_helper(row_, colexpr->>2, typ), 'null'))
        when 4 then
           _pg_json_query._build_array(
             coalesce(
               _pg_json_query._jq_val_helper(row_, colexpr->>0, typ), 'null'),
             coalesce(
               _pg_json_query._jq_val_helper(row_, colexpr->>1, typ), 'null'),
             coalesce(
               _pg_json_query._jq_val_helper(row_, colexpr->>2, typ), 'null'),
             coalesce(
               _pg_json_query._jq_val_helper(row_, colexpr->>3, typ), 'null'))
        when 5 then
           _pg_json_query._build_array(
             coalesce(
               _pg_json_query._jq_val_helper(row_, colexpr->>0, typ), 'null'),
             coalesce(
               _pg_json_query._jq_val_helper(row_, colexpr->>1, typ), 'null'),
             coalesce(
               _pg_json_query._jq_val_helper(row_, colexpr->>2, typ), 'null'),
             coalesce(
               _pg_json_query._jq_val_helper(row_, colexpr->>3, typ), 'null'),
             coalesce(
               _pg_json_query._jq_val_helper(row_, colexpr->>4, typ), 'null'))
        else
          _pg_json_query._jq_val_jsonb_arr(row_, colexpr)
        end
    else
      _pg_json_query._jq_val_helper(
        row_,
        _pg_json_query._json_string_to_text(colexpr),
        typ
      )
    end;
$$;


-- If type is omitted, default to JSONB.
create function jq_val(row_ anyelement, colname text)
returns jsonb language sql immutable as $$
  select _pg_json_query._jq_val_helper(row_, colname, null::jsonb);
$$;

-- If type is omitted, default to JSONB.
create function jq_val(row_ anyelement, colexpr jsonb)
returns jsonb language sql immutable as $$
  select jq_val(row_, colexpr, null::jsonb);
$$;

create function jq_val_text(row_ anyelement, colname text)
returns text language sql immutable as $$
  select _pg_json_query._jq_val_helper(row_, colname, null::text);
$$;



create function jq_val_text_array(row_ anyelement, arr text[])
returns text[]
language sql immutable
as $$
  select coalesce(array_agg(jq_val_text(row_, el) order by idx), '{}')::text[]
  from unnest(arr) with ordinality o(el, idx);
$$;


create function jq_val(row_ anyelement, arr text[], typ jsonb)
returns jsonb language sql immutable as $$
  select jq_val(row_, to_json(arr)::jsonb, typ);
$$;


create function jq_val(row_ anyelement, arr text[], typ text)
returns text[] language sql immutable as $$
  select jq_val_text_array(row_, arr);
$$;


create function jq_concat_val_args(e1 jsonb, e2 jsonb)
returns jsonb
language sql immutable
as $$
  select case
    when e1 is null then coalesce(e2, '[]')
    when e2 is null then coalesce(e1, '[]')
    else
      -- Both non-null.
      _pg_json_query._jsonb_array_concat(e1, e2)
    end;
$$;
