-- -----------------------------------------------------------------------------
--
-- Quota management
--
-- -----------------------------------------------------------------------------

DELIMITER $$

USE `sysaux`$$

SELECT DATABASE(), VERSION(), NOW(), USER()$$

DROP TABLE IF EXISTS `mysysutl`.`quota`$$

CREATE TABLE `mysysutl`.`quota` (
	`table_schema`	VARCHAR(64)	NOT NULL,
	`limit_in_mb`	INT			NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Disk quota allowed per schema'$$

DROP TABLE IF EXISTS `mysysutl`.`quota_exceed`$$

CREATE TABLE `mysysutl`.`quota_exceed` (
	`table_schema`	VARCHAR(64)	NOT NULL,
	`table_name`	VARCHAR(64)	NOT NULL,
	`grantee`		VARCHAR(81)	NOT NULL,
	`str_grants`	VARCHAR(19)	NOT NULL,
	`flg_grants`	BOOLEAN		NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Disk quota exceeded'$$

DROP FUNCTION IF EXISTS `mysysutl`.`quota_chk`$$

CREATE DEFINER='root'@'localhost' FUNCTION  `mysysutl`.`quota_chk` (
) RETURNS FLOAT DETERMINISTIC READS SQL DATA
BEGIN

	DECLARE end_cur		BOOLEAN DEFAULT FALSE;

	DECLARE my_grantee		VARCHAR(81);
	DECLARE my_grants		VARCHAR(19);
	DECLARE my_table		VARCHAR(64);
	DECLARE my_grant_option	BOOLEAN;

	DECLARE c_unlock CURSOR FOR
		SELECT	c.`grantee`,
				c.`table_name`,
				c.`str_grants`,
				IF(c.`flg_grants` = TRUE, ' WITH GRANT OPTION', '') AS grant_option
		FROM	`information_schema`.`tables` a,
				`mysysutl`.`quota` b,
				`mysysutl`.`quota_execed` c
		WHERE	a.`table_schema` = b.`table_schema`
        AND		a.`table_schema` = c.`table_schema`
		GROUP BY a.`table_schema`
		HAVING  b.`limit_in_mb` > round (SUM(((a.`table_rows` * a.`avg_row_length`) / 1024 / 1024)), 2);

	DECLARE c_lock CURSOR FOR
		SELECT	g.table_schema,
				g.grantee,
				g.object_name,
				GROUP_CONCAT(g.privilege_type ORDER BY g.privilege_type SEPARATOR ', ') AS privilege_type,
				IF(STRCMP(g.is_grantable, 'YES') = 0, TRUE, FALSE) AS grant_option
		FROM	(
				SELECT	`table_schema`,
						`grantee`,
						CONCAT('`', `table_schema`, '`.`', `table_name`, '`') as object_name,
						`privilege_type`,
						`is_grantable`
				FROM	`information_schema`.`table_privileges`
				UNION ALL
				SELECT	`table_schema`,
						`grantee`,
						CONCAT('`', `table_schema`, '`.*') as object_name,
						`privilege_type`,
						`is_grantable`
				FROM	`information_schema`.`schema_privileges`
			) g
		WHERE	g.privilege_type IN ('INSERT', 'UPDATE', 'DELETE')
		AND EXISTS (
				SELECT	a.`table_schema`,
						b.`limit_in_mb`
				FROM	`information_schema`.`tables` a,
						`mysysutl`.`quota` b
				WHERE	g.table_schema   = a.`table_schema`
				AND		a.`table_schema` = b.`table_schema`
				GROUP BY a.`table_schema`
				HAVING  b.`limit_in_mb` <= round (SUM(((a.`table_rows` * a.`avg_row_length`) / 1024 / 1024)), 2)
			)
		GROUP BY	g.table_schema,
					g.grantee,
					g.object_name;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET end_cur = TRUE;

	PREPARE sqlstr FROM 'GRANT ? ON ? TO ?';

	OPEN c_unlock;

	get_unlock: LOOP

		FETCH c_unlock INTO my_grantee, my_grants, my_table;

		IF end_cur = TRUE THEN
			LEAVE get_unlock;
		END IF;

		SET @my_grantee = my_grantee;
		SET @my_grants  = my_grants;
		SET @my_table   = my_table;

		EXECUTE sqlstr USING @my_grants, @my_table, @my_grantee;

		DELETE FROM `mysysutl`.`quota_execed` WHERE `table_schema` = my_table_schema AND `grantee` = my_grantee;

	END LOOP get_unlock;

	DEALLOCATE PREPARE sqlstr;

	CLOSE c_unlock;

	SET end_cur = FALSE;

	PREPARE sqlstr FROM 'REVOKE ? ON ? FROM ?';

	OPEN c_lock;

	get_lock: LOOP

		FETCH c_lock INTO my_table_schema, my_grantee, my_table, my_grants, my_grant_option;

		IF end_cur = TRUE THEN
			LEAVE get_lock;
		END IF;

		SET @my_grantee = my_grantee;
		SET @my_table   = my_table;
		SET @my_grants  = my_grants;

		EXECUTE sqlstr USING @my_grants, @my_table, @my_grantee;

		INSERT INTO `mysysutl`.`quota_execed` VALUES (my_table_schema, my_grantee, my_table, my_grants, my_grant_options);

	END LOOP get_lock;

	DEALLOCATE PREPARE sqlstr;

	CLOSE c_lock;

	RETURN 0;

END$$

DROP FUNCTION IF EXISTS `mysysutl`.`quota_man`$$

CREATE DEFINER='root'@'localhost' FUNCTION `mysysutl`.`quota_man` (
	iStr		VARCHAR(1024)
) RETURNS INT DETERMINISTIC MODIFIES SQL DATA 
BEGIN

	SET @myAction = `mysysutl`.`get_str`(iStr, 'ACTION', '');
	SET @mySchema = `mysysutl`.`get_str`(iStr, 'SCHEMA', '');
	SET @myQuota  = `mysysutl`.`get_str`(iStr, 'QUOTA' , '');

	IF     STRCMP(@myAction, 'SET') = 0 THEN
		INSERT INTO `mysysutl`.`quota` VALUES (@mySchema, @myQuota);
	ELSEIF STRCMP(@myAction, 'MODIFY') = 0 THEN
		UPDATE `mysysutl`.`quota` SET `limit_in_mb` = @myQuota WHERE `table_schema` = @mySchema;
	ELSEIF STRCMP(@myAction, 'UNSET') = 0 THEN
		DELETE FROM `mysysutl`.`quota` WHERE `table_schema` = @mySchema;
	ELSE
		RETURN -1;
	END IF;

	RETURN 0;

END$$

CREATE EVENT `quota_mon`
ON SCHEDULE EVERY 15 MINUTE
STARTS FROM_UNIXTIME(((UNIX_TIMESTAMP(NOW()) + 450) DIV 900) * 900)
-- STARTS DATE_FORMAT(DATE_ADD(now(), INTERVAL (IF(MINUTE(now()) < 15, 15, IF(MINUTE(now()) < 30, 30, IF(MINUTE(now()) < 45, 45, 60)))) - MINUTE(now()) MINUTE), '%Y-%m-%d %H:%i:00')
DISABLE ON SLAVE
COMMENT 'Scheduled Quota Monitor'
DO
	CALL `mysysutl`.`quota_chk`$$

DELIMITER ;
