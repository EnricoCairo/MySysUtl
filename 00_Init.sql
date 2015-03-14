-- -----------------------------------------------------------------------------
--
-- Database
--
-- 13-03-2015
--
-- -----------------------------------------------------------------------------

DROP DATABASE IF EXISTS `sysaux`;
CREATE DATABASE `sysaux` /*!40100 DEFAULT CHARACTER SET utf8 */;
USE `sysaux`;

SET GLOBAL event_scheduler = ON;
SET GLOBAL general_log     = ON;
SET GLOBAL slow_query_log  = ON;
SET GLOBAL log_output      = 'table';
