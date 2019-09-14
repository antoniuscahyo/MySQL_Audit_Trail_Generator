SET GLOBAL group_concat_max_len = 1000;

SET @dbName = "[[[your_db_name_here]]]";

SELECT concat("DROP TABLE IF EXISTS `", @dbName, "`.`", table_data.audit_table, "`;\r",
          "CREATE TABLE `", @dbName, "`.`", table_data.audit_table, "`\r",
          "(\r",
          "  `auditAction` ENUM ('INSERT', 'UPDATE', 'DELETE'),\r",
          "  `auditTimestamp` DATETIME DEFAULT CURRENT_TIMESTAMP,\r",
          "  `auditId` INT(14) AUTO_INCREMENT,",
          column_defs, ",\r"
          "  PRIMARY KEY (`auditId`),\r",
          "  INDEX (`auditTimestamp`)\r",
          ")\r",
          "  ENGINE = InnoDB;\r\r",
          "DROP TRIGGER IF EXISTS `", @dbName, "`.`", table_data.insert_trigger, "`;\r",
          "CREATE TRIGGER `", @dbName, "`.`", table_data.insert_trigger, "`\r",
          "  AFTER INSERT ON `", @dbName, "`.`", table_data.db_table, "`\r",
          "  FOR EACH ROW INSERT INTO `", @dbName, "`.`", table_data.audit_table, "`\r",
          "     (`auditAction`,", table_data.column_names, ")\r",
          "  VALUES\r",
          "     ('INSERT',", table_data.NEWcolumn_names, ");\r\r",
          "DROP TRIGGER IF EXISTS `", @dbName, "`.`", table_data.update_trigger, "`;\r",
          "CREATE TRIGGER `", @dbName, "`.`", table_data.update_trigger, "`\r",
          "  AFTER UPDATE ON `", @dbName, "`.`", table_data.db_table, "`\r",
          "  FOR EACH ROW INSERT INTO `", @dbName, "`.`", table_data.audit_table, "`\r",
          "     (`auditAction`,", table_data.column_names, ")\r",
          "  VALUES\r",
          "     ('UPDATE',", table_data.NEWcolumn_names, ");\r\r",
          "DROP TRIGGER IF EXISTS `", @dbName, "`.`", table_data.delete_trigger, "`;\r",
          "CREATE TRIGGER `", @dbName, "`.`", table_data.delete_trigger, "`\r",
          "  AFTER DELETE ON `", @dbName, "`.`", table_data.db_table, "`\r",
          "  FOR EACH ROW INSERT INTO `", @dbName, "`.`", table_data.audit_table, "`\r",
          "     (`auditAction`,", table_data.column_names, ")\r",
          "  VALUES\r",
          "     ('DELETE',", table_data.OLDcolumn_names, ");\r\r"
)
FROM (
   # This select builds a derived table of table names with ordered and grouped column information in different
   # formats as needed for audit table definitions and trigger definitions.
   SELECT
     table_order_key,
     table_name                                                                      AS db_table,
     concat("audit_", table_name)                                                    AS audit_table,
     concat(table_name, "_inserts")                                                  AS insert_trigger,
     concat(table_name, "_updates")                                                  AS update_trigger,
     concat(table_name, "_deletes")                                                  AS delete_trigger,
     group_concat("\r  `", column_name, "` ", column_type ORDER BY column_order_key) AS column_defs,
     group_concat("`", column_name, "`" ORDER BY column_order_key)                   AS column_names,
     group_concat("`NEW.", column_name, "`" ORDER BY column_order_key)               AS NEWcolumn_names,
     group_concat("`OLD.", column_name, "`" ORDER BY column_order_key)               AS OLDcolumn_names
   FROM
     (
       # This select builds a derived table of table names, column names and column types for
       # non-audit tables of the specified db, along with ordering keys for later order by.
       # The ordering must be done outside this select, as tables (including derived tables)
       # are by definition unordered.
       # We're only ordering so that the generated audit schema maintains a resemblance to the
       # main schema.
       SELECT
         information_schema.tables.table_name        AS table_name,
         information_schema.columns.column_name      AS column_name,
         information_schema.columns.column_type      AS column_type,
         information_schema.tables.create_time       AS table_order_key,
         information_schema.columns.ordinal_position AS column_order_key
       FROM information_schema.tables
         JOIN information_schema.columns
           ON information_schema.tables.table_name = information_schema.columns.table_name
       WHERE information_schema.tables.table_schema = @dbName
             AND information_schema.columns.table_schema = @dbName
             AND information_schema.tables.table_name NOT LIKE "audit\_%"
     ) table_column_ordering_info
   GROUP BY table_name
 ) table_data
ORDER BY table_order_key
INTO OUTFILE "[[[your_output_file]]]"
