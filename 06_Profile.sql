-- -----------------------------------------------------------------------------
--
-- Account profiles management
--
-- -----------------------------------------------------------------------------

DELIMITER $$

DROP TABLE IF EXISTS `sysaux`.`profiles`$$

CREATE TABLE `sysaux`.`profiles` (
	`profile`					VARCHAR(64)	NOT NULL,
	`max_queries_per_hour`		INT			NOT NULL DEFAULT 0,
	`max_updates_per_hour`		INT			NOT NULL DEFAULT 0,
	`max_connections_per_hour`	INT			NOT NULL DEFAULT 0,
	`max_user_connections`		INT			NOT NULL DEFAULT 0
) ENGINE=MyISAM$$

CREATE FUNCTION `sysaux`.`profile_man` (
	iStr		VARCHAR(1024)
) RETURNS INT DETERMINISTIC MODIFIES SQL DATA 
BEGIN
	DECLARE vAction			VARCHAR(64)	DEFAULT `sysaux`.`get_str`(iStr, 'ACTION'                  , '');
	DECLARE vUser			VARCHAR(16)	DEFAULT `sysaux`.`get_str`(iStr, 'USER'                    , '');
	DECLARE vProfile		VARCHAR(64)	DEFAULT `sysaux`.`get_str`(iStr, 'PROFILE'                 , 'default');
	DECLARE vMaxQueries		INT			DEFAULT `sysaux`.`get_int`(iStr, 'MAX_QUERIES_PER_HOUR'    , '0');
	DECLARE vMaxUpdates		INT			DEFAULT `sysaux`.`get_int`(iStr, 'MAX_UPDATES_PER_HOUR'    , '0');
	DECLARE vMaxConnHour	INT			DEFAULT `sysaux`.`get_int`(iStr, 'MAX_CONNECTIONS_PER_HOUR', '0');
	DECLARE vMaxUsrConn		INT			DEFAULT `sysaux`.`get_int`(iStr, 'MAX_USER_CONNECTIONS'    , '0');

	DECLARE vHost			VARCHAR(64);
	DECLARE ErrNo			INT			DEFAULT 0;
	DECLARE i				INT;
	DECLARE cUser 			CURSOR FOR SELECT host FROM `mysql`.`user` WHERE `user` = vUser;

	DECLARE EXIT HANDLER FOR NOT FOUND SET ErrNo=2;
	DECLARE EXIT HANDLER FOR SQLSTATE '23000' SET ErrNo=6; # duplicate entry

	IF	vProfile = '' THEN
		SET ErrNo = 3;
	ELSE
		CASE LOWER(vAction)
		WHEN 'create' THEN
			BEGIN
				INSERT INTO `sysaux`.`profiles` VALUES (vProfile, vMaxQueries, vMaxUpdates, vMaxConnHour, vMaxUsrConn);

				SET ErrNo = 0;
			END;
		WHEN 'modify' THEN
			BEGIN
				UPDATE	`sysaux`.`profiles`
				SET		`max_queries_per_hour`		= vMaxQueries,
						`max_updates_per_hour`		= vMaxUpdates,
						`max_connections_per_hour`	= vMaxConnHour,
						`max_user_connections`		= vMaxUsrConn
				WHERE	`profile`					= vProfile;

				SET ErrNo = 0;
			END;
		WHEN 'delete' THEN
			BEGIN
				DELETE FROM `sysaux`.`profiles` WHERE `profile` = vProfile;

				SET ErrNo = 0;
			END;
		WHEN 'set' THEN
			BEGIN
				IF vUser = '' THEN
					SET ErrNo = 4;
				ELSE
					OPEN cUser;

					SELECT found_rows() INTO i;

					IF i = 0 THEN
						SET ErrNo = 7;
					ELSE
						SELECT	`max_queries_per_hour`,
								`max_updates_per_hour`,
								`max_connections_per_hour`,
								`max_user_connections`
						INTO	vMaxQueries,
								vMaxUpdates,
								vMaxConnHour,
								vMaxUsrConn
						FROM	`sysaux`.`profiles`
						WHERE	`profile` = vProfile;

						the_loop: LOOP
							FETCH cUser INTO vHost;

							UPDATE	`mysql.user`
							SET		`max_questions`			= vMaxQueries,
									`max_updates`			= vMaxUpdates,
									`max_connections`		= vMaxConnHour,
									`max_user_connections`	= vMaxUsrConn
							WHERE	`host` = vHost
							AND		`user` = vUser;

							SET i = i -1;

							IF i = 0 THEN
								LEAVE the_loop;
							END IF;

						END LOOP the_loop;

						CLOSE cUser;

						FLUSH PRIVILEGES;

						SET ErrNo = 0;
					END IF;
				END IF;
			END;
		ELSE
			SET ErrNo = 5;
		END CASE;
	END IF;

    RETURN ErrNo;
END $$

SELECT `sysaux`.`profile_man`('ACTION=>create,PROFILE=>default,MAX_QUERIES_PER_HOUR=>0,MAX_UPDATES_PER_HOUR=>0,MAX_CONNECTIONS_PER_HOUR=>0,MAX_USER_CONNECTIONS=>0')$$
SELECT `sysaux`.`profile_man`('ACTION=>create,PROFILE_NAME=>guest,MAX_QUERIES_PER_HOUR=>5,MAX_UPDATES_PER_HOUR=>1,MAX_CONNECTIONS_PER_HOUR=>1,MAX_USER_CONNECTIONS=>1')$$

DELIMITER ;