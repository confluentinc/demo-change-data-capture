DROP USER DB_USER;

-- DB_USER is the user the Oracle CDC Connector uses to access Oracle
CREATE USER DB_USER IDENTIFIED BY democdc DEFAULT TABLESPACE USERS;

-- Grant permissions to DB_USER (password is democdc)
ALTER USER DB_USER QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION TO DB_USER;
GRANT SELECT ON DBA_TABLESPACES TO DB_USER;
GRANT LOGMINING TO DB_USER;
GRANT SELECT ON CUSTOMERS TO DB_USER;
GRANT SELECT ON DEMOGRAPHICS TO DB_USER;

-- Grant system privileges to DB_USER to access changelogs
begin rdsadmin.rdsadmin_util.grant_sys_object('ALL_VIEWS', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('ALL_TAB_PARTITIONS', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('ALL_INDEXES', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('ALL_OBJECTS', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('ALL_TABLES', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('ALL_USERS', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('ALL_CATALOG', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('ALL_CONSTRAINTS', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('ALL_CONS_COLUMNS', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('ALL_TAB_COLS', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('ALL_IND_COLUMNS', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('ALL_LOG_GROUPS', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('V_$ARCHIVED_LOG', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('V_$LOG', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('V_$LOGFILE', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('V_$DATABASE', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('V_$THREAD', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('V_$PARAMETER', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('V_$NLS_PARAMETERS', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('V_$TIMEZONE_NAMES', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('V_$TRANSACTION', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('DBA_REGISTRY', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('OBJ$', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('ALL_ENCRYPTED_COLUMNS', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('V_$LOGMNR_LOGS', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('V_$LOGMNR_CONTENTS','DB_USER','SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('DBMS_LOGMNR', 'DB_USER', 'EXECUTE'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('DBA_TABLESPACES', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.grant_sys_object('V_$INSTANCE', 'DB_USER', 'SELECT'); end;
begin rdsadmin.rdsadmin_util.alter_supplemental_logging(p_action => 'ADD'); end;
begin rdsadmin.rdsadmin_util.set_configuration('archivelog retention hours',24); end;
begin rdsadmin.rdsadmin_util.alter_supplemental_logging('ADD'); end;

-- Add logging and snapshotting to CUSTOMERS table for CDC
ALTER TABLE CUSTOMERS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
GRANT FLASHBACK ON CUSTOMERS TO DB_USER;
ALTER TABLE DEMOGRAPHICS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
GRANT FLASHBACK ON DEMOGRAPHICS TO DB_USER;