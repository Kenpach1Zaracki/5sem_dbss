SET ROLE app_reader;

DO $$
BEGIN
    RAISE NOTICE '=== Роль app_reader ===';
    IF has_table_privilege('app_reader', 'app.clients',   'SELECT') THEN RAISE NOTICE 'Чтение app.clients   : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Чтение app.clients   : ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('app_reader', 'app.products',  'SELECT') THEN RAISE NOTICE 'Чтение app.products  : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Чтение app.products  : ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('app_reader', 'ref.product_category', 'SELECT') THEN RAISE NOTICE 'Чтение ref.categories: РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Чтение ref.categories: ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('app_reader', 'app.clients',   'INSERT') THEN RAISE NOTICE 'Вставка app.clients  : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Вставка app.clients  : ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('app_reader', 'app.clients',   'UPDATE') THEN RAISE NOTICE 'Правка app.clients   : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Правка app.clients   : ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('app_reader', 'app.clients',   'DELETE') THEN RAISE NOTICE 'Удаление app.clients : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Удаление app.clients : ЗАПРЕЩЕНО'; END IF;
END $$;

RESET ROLE;

SET ROLE app_writer;

DO $$
BEGIN
    RAISE NOTICE '=== Роль app_writer ===';
    IF has_table_privilege('app_writer', 'app.clients',   'SELECT') THEN RAISE NOTICE 'Чтение app.clients   : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Чтение app.clients   : ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('app_writer', 'ref.product_category', 'SELECT') THEN RAISE NOTICE 'Чтение ref.categories: РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Чтение ref.categories: ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('app_writer', 'app.products',  'INSERT') THEN RAISE NOTICE 'Вставка app.products : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Вставка app.products : ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('app_writer', 'app.clients',   'UPDATE') THEN RAISE NOTICE 'Правка app.clients   : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Правка app.clients   : ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('app_writer', 'app.clients',   'DELETE') THEN RAISE NOTICE 'Удаление app.clients : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Удаление app.clients : ЗАПРЕЩЕНО'; END IF;
END $$;

RESET ROLE;


SET ROLE app_owner;

DO $$
BEGIN
    RAISE NOTICE '=== Роль app_owner ===';
    IF has_table_privilege('app_owner', 'app.clients',  'SELECT') THEN RAISE NOTICE 'Чтение app.clients   : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Чтение app.clients   : ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('app_owner', 'app.products', 'INSERT') THEN RAISE NOTICE 'Вставка app.products : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Вставка app.products : ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('app_owner', 'app.clients',  'UPDATE') THEN RAISE NOTICE 'Правка app.clients   : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Правка app.clients   : ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('app_owner', 'app.products', 'DELETE') THEN RAISE NOTICE 'Удаление app.products: РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Удаление app.products: ЗАПРЕЩЕНО'; END IF;
    IF has_schema_privilege('app_owner', 'app', 'CREATE') THEN RAISE NOTICE 'Создание в app       : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Создание в app       : ЗАПРЕЩЕНО'; END IF;
END $$;

RESET ROLE;


SET ROLE auditor;

DO $$
BEGIN
    RAISE NOTICE '=== Роль auditor ===';
    IF has_table_privilege('auditor', 'audit.audit_log', 'SELECT') THEN RAISE NOTICE 'Чтение audit.audit_log : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Чтение audit.audit_log : ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('auditor', 'audit.login_log', 'SELECT') THEN RAISE NOTICE 'Чтение audit.login_log : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Чтение audit.login_log : ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('auditor', 'audit.audit_log', 'INSERT') THEN RAISE NOTICE 'Запись audit.audit_log : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Запись audit.audit_log : ЗАПРЕЩЕНО'; END IF;
    IF has_schema_privilege('auditor', 'app', 'USAGE') THEN RAISE NOTICE 'Доступ к app           : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Доступ к app           : ЗАПРЕЩЕНО'; END IF;
END $$;

RESET ROLE;


SET ROLE ddl_admin;

DO $$
BEGIN
    RAISE NOTICE '=== Роль ddl_admin ===';
    IF has_schema_privilege('ddl_admin', 'app',   'CREATE') THEN RAISE NOTICE 'Создание в app   : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Создание в app   : ЗАПРЕЩЕНО'; END IF;
    IF has_schema_privilege('ddl_admin', 'ref',   'USAGE')  THEN RAISE NOTICE 'Доступ к ref     : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Доступ к ref     : ЗАПРЕЩЕНО'; END IF;
    IF has_schema_privilege('ddl_admin', 'audit', 'USAGE')  THEN RAISE NOTICE 'Доступ к audit   : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Доступ к audit   : ЗАПРЕЩЕНО'; END IF;
    IF has_schema_privilege('ddl_admin', 'stg',   'CREATE') THEN RAISE NOTICE 'Создание в stg   : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Создание в stg   : ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('ddl_admin', 'app.products', 'INSERT') THEN RAISE NOTICE 'Вставка в данные : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Вставка в данные : ЗАПРЕЩЕНО'; END IF;
END $$;

RESET ROLE;


SET ROLE dml_admin;

DO $$
BEGIN
    RAISE NOTICE '=== Роль dml_admin ===';
    IF has_table_privilege('dml_admin', 'app.products', 'SELECT') THEN RAISE NOTICE 'Чтение app.products  : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Чтение app.products  : ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('dml_admin', 'app.products', 'INSERT') THEN RAISE NOTICE 'Вставка app.products : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Вставка app.products : ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('dml_admin', 'app.products', 'UPDATE') THEN RAISE NOTICE 'Правка app.products  : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Правка app.products  : ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('dml_admin', 'app.products', 'DELETE') THEN RAISE NOTICE 'Удаление app.products: РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Удаление app.products: ЗАПРЕЩЕНО'; END IF;
    IF has_schema_privilege('dml_admin', 'app', 'CREATE') THEN RAISE NOTICE 'Создание в app       : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Создание в app       : ЗАПРЕЩЕНО'; END IF;
END $$;

RESET ROLE;


SET ROLE security_admin;

DO $$
DECLARE
    can_create_role boolean;
BEGIN
    RAISE NOTICE '=== Роль security_admin ===';
    IF has_table_privilege('security_admin', 'pg_catalog.pg_roles',       'SELECT') THEN RAISE NOTICE 'Чтение pg_roles        : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Чтение pg_roles        : ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('security_admin', 'pg_catalog.pg_auth_members','SELECT') THEN RAISE NOTICE 'Чтение pg_auth_members : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Чтение pg_auth_members : ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('security_admin', 'pg_catalog.pg_namespace',   'SELECT') THEN RAISE NOTICE 'Чтение pg_namespace    : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Чтение pg_namespace    : ЗАПРЕЩЕНО'; END IF;
    IF has_table_privilege('security_admin', 'pg_catalog.pg_tables',      'SELECT') THEN RAISE NOTICE 'Чтение pg_tables       : РАЗРЕШЕНО'; ELSE RAISE NOTICE 'Чтение pg_tables       : ЗАПРЕЩЕНО'; END IF;

    SELECT rolcreaterole INTO can_create_role FROM pg_roles WHERE rolname = 'security_admin';
    IF can_create_role THEN
        RAISE NOTICE 'Создание ролей         : РАЗРЕШЕНО';
    ELSE
        RAISE NOTICE 'Создание ролей         : ЗАПРЕЩЕНО';
    END IF;
END $$;

RESET ROLE;