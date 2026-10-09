CREATE ROLE app_reader  NOLOGIN;
CREATE ROLE app_writer  NOLOGIN;
CREATE ROLE app_owner   NOLOGIN;

CREATE ROLE auditor     NOLOGIN;

CREATE ROLE ddl_admin   NOLOGIN;
CREATE ROLE dml_admin   NOLOGIN;
CREATE ROLE security_admin NOLOGIN CREATEROLE;

CREATE ROLE test_reader   LOGIN NOINHERIT PASSWORD 'Reader_2026!';
CREATE ROLE test_writer   LOGIN NOINHERIT PASSWORD 'Writer_2026!';
CREATE ROLE test_owner    LOGIN NOINHERIT PASSWORD 'Owner_2026!';
CREATE ROLE test_auditor  LOGIN NOINHERIT PASSWORD 'Auditor_2026!';
CREATE ROLE test_ddl      LOGIN NOINHERIT PASSWORD 'Ddl_2026!';
CREATE ROLE test_dml      LOGIN NOINHERIT PASSWORD 'Dml_2026!';
CREATE ROLE test_security LOGIN NOINHERIT PASSWORD 'Sec_2026!';

GRANT app_reader TO test_reader;
GRANT app_writer TO test_writer;
GRANT app_owner  TO test_owner;
GRANT auditor    TO test_auditor;
GRANT ddl_admin  TO test_ddl;
GRANT dml_admin  TO test_dml;
GRANT security_admin TO test_security;
