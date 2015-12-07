-- -----------------------------------------------------------------------------
--
-- Database
--
-- 13-03-2015
--
-- -----------------------------------------------------------------------------

-- Do NOT forget to fix those hoosk in your my.cnf (or my.ini) file

SET GLOBAL event_scheduler = ON;
SET GLOBAL general_log     = ON;
SET GLOBAL slow_query_log  = ON;
SET GLOBAL log_output      = 'table';
SET GLOBAL init_connect    = 'CALL `sysaux`.logon_trigger()';

-- Databases creation

DROP DATABASE IF EXISTS `mysysutl`;
CREATE DATABASE `mysysutl` /*!40100 DEFAULT CHARACTER SET utf8 */;

DROP DATABASE IF EXISTS `sysaux`;
CREATE DATABASE `sysaux` /*!40100 DEFAULT CHARACTER SET utf8 */;

-- User sysman will be used in future for the front-end
-- Initial "grant usage" is necessary to avoid "Error Code: 1396. Operation DROP USER failed for 'sysman'@'localhost'"

GRANT USAGE   ON `sysaux`.* TO 'sysman'@'localhost' IDENTIFIED by 'being_deleted';
DROP   USER 'sysman'@'localhost';
CREATE USER 'sysman'@'localhost' IDENTIFIED by 'sysman';
GRANT EXECUTE ON `mysysutl`.* TO 'sysman'@'localhost';
GRANT EXECUTE ON `sysaux`.*   TO 'sysman'@'localhost';
