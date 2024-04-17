DO $$
DECLARE
    schema_name               TEXT := 's335076';
    disabled_constraint_count INT  := 0;
    table_record              RECORD;
    column_record             RECORD;
    schema_oid                REGCLASS;
BEGIN
    -- Получаем OID схемы
    SELECT to_regclass(schema_name) INTO schema_oid;

    FOR table_record IN
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema = schema_name
    LOOP
        FOR column_record IN
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = table_record.table_schema
              AND table_name = table_record.table_name
              AND is_nullable = 'NO' -- Находим столбцы, которые не допускают NULL
              AND column_name NOT IN (
                  SELECT attname
                  FROM pg_index i
                  JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
                  WHERE i.indrelid = schema_oid
                    AND i.indisprimary
              )
        LOOP
            -- Отключаем ограничение NOT NULL для каждого столбца
            EXECUTE 'ALTER TABLE ' || quote_ident(table_record.table_schema) || '.' ||
                    quote_ident(table_record.table_name) ||
                    ' ALTER COLUMN ' || quote_ident(column_record.column_name) || ' DROP NOT NULL;';
            disabled_constraint_count := disabled_constraint_count + 1;
        END LOOP;
    END LOOP;
    RAISE NOTICE 'Схема: %', schema_name;
    RAISE NOTICE 'Ограничений целостности типа NOT NULL отключено: %', disabled_constraint_count;
END
$$ LANGUAGE plpgsql;
--работает когда нет primary key