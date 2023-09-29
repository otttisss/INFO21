-- Таблица Peers
CREATE TABLE IF NOT EXISTS Peers (
	Nickname varchar PRIMARY KEY NOT NULL,
	Birthday date
);

-- Таблица Tasks
-- DONE Чтобы получить доступ к заданию, нужно выполнить задание, являющееся его условием входа.
-- DONE Для упрощения будем считать, что у каждого задания всего одно условие входа.
-- DONE В таблице должно быть одно задание, у которого нет условия входа (т.е. поле ParentTask равно null).
CREATE TABLE IF NOT EXISTS Tasks (
	Title varchar PRIMARY KEY NOT NULL,
	ParentTask varchar,
	MaxXP integer,
	CONSTRAINT fk_tasks_parent FOREIGN KEY (ParentTask) REFERENCES Tasks(Title)
);
CREATE INDEX IF NOT EXISTS index_parent_task ON Tasks ((1)) WHERE ParentTask IS NULL;


-- Статус проверки
DROP TYPE IF EXISTS CheckStatus;
CREATE TYPE CheckStatus AS ENUM ('Start', 'Success', 'Failure');


-- Таблица Checks
-- TODO Описывает проверку задания в целом. Проверка обязательно включает в себя один этап P2P и, возможно, этап Verter.
-- TODO Для упрощения будем считать, что пир ту пир и автотесты, относящиеся к одной проверке, всегда происходят в один день.
-- TODO Проверка считается успешной, если соответствующий P2P этап успешен, а этап Verter успешен, либо отсутствует.
-- TODO Проверка считается неуспешной, хоть один из этапов неуспешен.
-- TODO То есть проверки, в которых ещё не завершился этап P2P, или этап P2P успешен, но ещё не завершился этап Verter, не относятся ни к успешным, ни к неуспешным.
CREATE TABLE IF NOT EXISTS Checks (
	ID bigint PRIMARY KEY NOT NULL,
	Peer varchar,
	Task varchar,
	Date date,
	CONSTRAINT fk_checks_peer FOREIGN KEY (Peer) REFERENCES Peers(Nickname),
	CONSTRAINT fk_checks_task FOREIGN KEY (Task) REFERENCES Tasks(Title)
);


-- Таблица P2P
-- TODO Каждая P2P проверка состоит из 2-х записей в таблице: первая имеет статус начало, вторая - успех или неуспех. 
-- TODO В таблице не может быть больше одной незавершенной P2P проверки, относящейся к конкретному заданию, пиру и проверяющему. 
-- TODO Каждая P2P проверка (т.е. обе записи, из которых она состоит) ссылается на проверку в таблице Checks, к которой она относится.
CREATE TABLE IF NOT EXISTS P2P (
	ID bigint PRIMARY KEY NOT NULL,
	Check_ID bigint,
	CheckingPeer varchar,
	P2P_check_status CheckStatus,
	Time time,
 	CONSTRAINT fk_p2p_check FOREIGN KEY (Check_ID) REFERENCES Checks(ID),
	CONSTRAINT fk_p2p_checking_peer FOREIGN KEY (CheckingPeer) REFERENCES Peers(Nickname)
);


-- Таблица Verter
-- TODO Каждая проверка Verter'ом состоит из 2-х записей в таблице: первая имеет статус начало, вторая - успех или неуспех. 
-- TODO Каждая проверка Verter'ом (т.е. обе записи, из которых она состоит) ссылается на проверку в таблице Checks, к которой она относится. 
-- TODO Проверка Verter'ом может ссылаться только на те проверки в таблице Checks, которые уже включают в себя успешную P2P проверку.
CREATE TABLE IF NOT EXISTS Verter (
	ID bigint PRIMARY KEY NOT NULL,
	Check_ID bigint,
	Check_status_by_Verter CheckStatus,
	Time time,
	CONSTRAINT fk_verter_check FOREIGN KEY (Check_ID) REFERENCES Checks(ID)
);


-- Таблица TransferredPoints
-- TODO При каждой P2P проверке проверяемый пир передаёт один пир поинт проверяющему.
-- TODO Эта таблица содержит все пары проверяемый-проверяющий и кол-во переданных пир поинтов, то есть,
-- TODO другими словами, количество P2P проверок указанного проверяемого пира, данным проверяющим.
CREATE TABLE IF NOT EXISTS TransferredPoints (
	ID bigint PRIMARY KEY NOT NULL,
	CheckingPeer varchar,
	CheckedPeer varchar,
	PointsAmount integer,
	CONSTRAINT fk_transferred_points_checking_peer FOREIGN KEY (CheckingPeer) REFERENCES Peers(Nickname),
	CONSTRAINT fk_transferred_points_checked_peer FOREIGN KEY (CheckedPeer) REFERENCES Peers(Nickname)
);

-- Таблица Friends
-- TODO Дружба взаимная, т.е. первый пир является другом второго, а второй -- другом первого.
CREATE TABLE IF NOT EXISTS TableName_Friends (
	ID bigint PRIMARY KEY NOT NULL,
	Peer1 varchar,
	Peer2 varchar,
	CONSTRAINT fk_friends_peer1 FOREIGN KEY (Peer1) REFERENCES Peers(Nickname),
	CONSTRAINT fk_friends_peer2 FOREIGN KEY (Peer2) REFERENCES Peers(Nickname)
);


-- Таблица Recommendations
-- TODO Каждому может понравиться, как проходила P2P проверка у того или иного пира.
-- TODO Пир, указанный в поле Peer, рекомендует проходить P2P проверку у пира из поля RecommendedPeer.
-- TODO Каждый пир может рекомендовать как ни одного, так и сразу несколько проверяющих.
CREATE TABLE IF NOT EXISTS TableName_Recommendations (
	ID bigint PRIMARY KEY NOT NULL,
	Peer varchar,
	RecommendedPeer varchar,
	CONSTRAINT fk_recommendations_peer FOREIGN KEY (Peer) REFERENCES Peers(Nickname),
	CONSTRAINT fk_recommendations_recommended_peer FOREIGN KEY (RecommendedPeer) REFERENCES Peers(Nickname)
);

-- Таблица XP
-- TODO За каждую успешную проверку пир, выполнивший задание, получает какое-то количество XP, отображаемое в этой таблице.
-- TODO Количество XP не может превышать максимальное доступное для проверяемой задачи.
-- TODO Первое поле этой таблицы может ссылаться только на успешные проверки.
CREATE TABLE IF NOT EXISTS XP (
	ID bigint PRIMARY KEY NOT NULL,
	Check_ID bigint,
	XPAmount integer,
	CONSTRAINT fk_xp_check FOREIGN KEY (Check_ID) REFERENCES Checks(ID)
);

-- Таблица TimeTracking
-- TODO Данная таблица содержит информация о посещениях пирами кампуса.
-- TODO Когда пир входит в кампус, в таблицу добавляется запись с состоянием 1, когда покидает - с состоянием 2.
-- TODO В заданиях, относящихся к этой таблице, под действием "выходить" подразумеваются все покидания кампуса за день, кроме последнего.
-- TODO В течение одного дня должно быть одинаковое количество записей с состоянием 1 и состоянием 2 для каждого пира.
CREATE TABLE IF NOT EXISTS TableName_TimeTracking (
	ID bigint PRIMARY KEY NOT NULL,
	Peer varchar,
	Date date,
	Time time,	
	State INT,
	CONSTRAINT fk_time_tracking_peer FOREIGN KEY (Peer) REFERENCES Peers(Nickname)
);

-- Import Data from a .csv File
CREATE OR REPLACE PROCEDURE import_data_from_csv(
  IN filepath TEXT,
  IN separator TEXT,
  IN table_name TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
  EXECUTE format('COPY %I FROM %L WITH (FORMAT CSV, DELIMITER %L)', table_name, filepath, separator);
END;
$$;

-- Export Data to a .csv File
CREATE OR REPLACE PROCEDURE export_data_to_csv(
  IN filepath TEXT,
  IN separator TEXT,
  IN table_name TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
  EXECUTE format('COPY %I TO %L WITH (FORMAT CSV, DELIMITER %L)', table_name, filepath, separator);
END;
$$;

CREATE OR REPLACE PROCEDURE add_p2p_check(
    IN p_nickname VARCHAR,
    IN p_checker_nickname VARCHAR,
    IN p_task_name VARCHAR,
    IN p_check_status checkstatus,
    IN p_time TIME
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_check_status = 'Start' THEN
        INSERT INTO checks (id, peer, task, date)
        VALUES ((SELECT MAX(id) FROM checks) + 1, p_nickname, p_task_name, CURRENT_DATE);

        INSERT INTO p2p (id, Check_ID, checkingpeer, P2P_check_status, time)
        VALUES ((SELECT MAX(id) FROM p2p) + 1, 
                (SELECT MAX(id) FROM checks WHERE checks.peer = p_nickname AND checks.task = p_task_name AND checks.date = CURRENT_DATE),
                p_checker_nickname, p_check_status, p_time);
    ELSE
        INSERT INTO p2p (id, Check_ID, checkingpeer, P2P_check_status, time)
        VALUES ((SELECT MAX(id) FROM p2p) + 1,(
				SELECT P1.Check_ID
				FROM P2P P1
				WHERE P1.checkingpeer = p_checker_nickname
				AND P1.P2P_check_status = 'Start'
				AND NOT EXISTS (
    				SELECT *
    				FROM P2P P2
    				WHERE P2.Check_ID = P1.Check_ID
    				AND P2.P2P_check_status <> 'Start')
				),
                p_checker_nickname, p_check_status, p_time);
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE add_verter_check(
    p_nickname VARCHAR,
    p_task_name VARCHAR,
    p_check_status checkstatus,
    p_time TIME
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_check_id BIGINT;
BEGIN
    SELECT c.ID INTO v_check_id
    FROM Checks c
    JOIN P2P p ON c.ID = p.Check_ID
    WHERE c.Task = p_task_name
    AND p.P2P_check_status = 'Success'
    ORDER BY
		c.Date DESC,
		p.Time DESC
    LIMIT 1;
    INSERT INTO Verter (ID, Check_ID, Check_status_by_Verter, Time)
    VALUES ((SELECT MAX(id) FROM verter) + 1, v_check_id, p_check_status, p_time);
END;
$$;

CREATE OR REPLACE FUNCTION update_transferred_points()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.P2P_check_status = 'Start' THEN
        UPDATE transferredpoints
        SET pointsamount = pointsamount + 1
        WHERE checkingpeer = NEW.checkingpeer
        AND checkedpeer = (
            SELECT c.peer
            FROM P2P p
			JOIN checks c ON p.Check_ID = c.ID
            WHERE Check_ID = NEW.Check_ID
            AND P2P_check_status = 'Start'
        );
        IF NOT FOUND THEN
            INSERT INTO transferredpoints (ID, checkingpeer, checkedpeer, pointsamount)
            VALUES ((SELECT MAX(id) FROM transferredpoints) + 1, NEW.checkingpeer, (
                SELECT c.peer
                FROM P2P p
                JOIN checks c ON p.Check_ID = c.ID
                WHERE Check_ID = NEW.Check_ID
                AND P2P_check_status = 'Start'
            ), 1);
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_transferred_points_trigger
AFTER INSERT ON p2p
FOR EACH ROW
EXECUTE FUNCTION update_transferred_points();

CREATE OR REPLACE FUNCTION check_xp_record()
RETURNS TRIGGER AS $$
BEGIN
    DECLARE
        max_xp INTEGER;
    BEGIN
        SELECT MaxXP INTO max_xp FROM Tasks t JOIN checks c ON t.title = c.task WHERE c.id = NEW.Check_ID;
        IF NEW.xpamount > max_xp THEN
            RAISE EXCEPTION 'Number of XP exceeds the maximum available for the task';
        END IF;        
        IF NOT EXISTS (SELECT 1 FROM Checks c JOIN p2p p ON p.check_id = c.id JOIN verter v ON v.check_id = c.id
					   WHERE c.id = NEW.Check_ID AND p.p2p_check_status = 'Success' AND v.Check_status_by_Verter = 'Success') THEN
            RAISE EXCEPTION 'Check field does not refer to a successful check';
        END IF;
        
        RETURN NEW;
    END;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_xp_record_trigger
BEFORE INSERT ON xp
FOR EACH ROW
EXECUTE FUNCTION check_xp_record();

/*
CALL public.import_data_from_csv('/Users/vt/21/main/SQL2_Info21_v1.0-1/src/csv/peers.csv', ',', 'peers');
CALL public.import_data_from_csv('/Users/vt/21/main/SQL2_Info21_v1.0-1/src/csv/friends.csv', ',', 'tablename_friends');
CALL public.import_data_from_csv('/Users/vt/21/main/SQL2_Info21_v1.0-1/src/csv/transferredpoints.csv', ',', 'transferredpoints');
CALL public.import_data_from_csv('/Users/vt/21/main/SQL2_Info21_v1.0-1/src/csv/recommendations.csv', ',', 'tablename_recommendations');
CALL public.import_data_from_csv('/Users/vt/21/main/SQL2_Info21_v1.0-1/src/csv/timetracking.csv', ',', 'tablename_timetracking');
CALL public.import_data_from_csv('/Users/vt/21/main/SQL2_Info21_v1.0-1/src/csv/tasks.csv', ',', 'tasks');
CALL public.import_data_from_csv('/Users/vt/21/main/SQL2_Info21_v1.0-1/src/csv/checks.csv', ',', 'checks');
CALL public.import_data_from_csv('/Users/vt/21/main/SQL2_Info21_v1.0-1/src/csv/p2p.csv', ',', 'p2p');
CALL public.import_data_from_csv('/Users/vt/21/main/SQL2_Info21_v1.0-1/src/csv/verter.csv', ',', 'verter');
CALL public.import_data_from_csv('/Users/vt/21/main/SQL2_Info21_v1.0-1/src/csv/xp.csv', ',', 'xp');
*/

/*
1) Create a stored procedure that, without destroying the database, destroys all those tables 
in the current database whose names begin with the phrase 'TableName'.
*/
CREATE OR REPLACE PROCEDURE destroy_tables(
	IN TableName text
)
LANGUAGE plpgsql
AS $$
DECLARE
    table_n text;
BEGIN
    FOR table_n IN SELECT table_name FROM information_schema.tables WHERE table_name LIKE TableName || '%'
    LOOP
        EXECUTE 'DROP TABLE IF EXISTS ' || table_n || ' CASCADE;';
    END LOOP;
END;
$$;

--CALL destroy_tables('tablename');

--add some functions
CREATE OR REPLACE FUNCTION fnc_bday(pname VARCHAR)
RETURNS DATE
AS $$
SELECT birthday FROM peers WHERE nickname = pname;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION fnc_nickname(bday DATE)
RETURNS VARCHAR
AS $$
SELECT nickname FROM peers WHERE birthday = bday;
$$ LANGUAGE SQL;
--add some functions

/*
2) Create a stored procedure with an output parameter that outputs a list of names and parameters of all scalar user's SQL functions 
in the current database. Do not output function names without parameters. The names and the list of parameters must be in one string. 
The output parameter returns the number of functions found.
*/
CREATE OR REPLACE PROCEDURE get_function_info(OUT function_count integer)
AS $$
DECLARE
    function_info text := '';
    function_row record;
BEGIN
    function_count := 0;

    FOR function_row IN
        SELECT p.proname AS function_name,
               pg_catalog.pg_get_function_arguments(p.oid) AS function_args
		FROM pg_catalog.pg_proc p
        JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
		    AND p.prokind = 'f'
            AND pg_catalog.pg_get_function_arguments(p.oid) <> ''
    LOOP
        function_count := function_count + 1;
        function_info := function_info || function_row.function_name || '(' || function_row.function_args || ')\/';
    END LOOP;

    RAISE NOTICE 'Function Info: %', function_info;
END;
$$ LANGUAGE plpgsql;

/*
--Declare the variable and call the procedure
DO $$
DECLARE
    function_count integer;
BEGIN
    CALL get_function_info(function_count);
    RAISE NOTICE 'Number of functions found: %', function_count;
END;
$$;
*/

/*
3) Create a stored procedure with output parameter, which destroys all SQL DML triggers in the current database. 
The output parameter returns the number of destroyed triggers.
*/
CREATE OR REPLACE PROCEDURE destroy_triggers(OUT destroyed_trigger_count integer)
AS $$
DECLARE
    trigger_rec RECORD;
BEGIN
    destroyed_trigger_count := 0;

    FOR trigger_rec IN (
        SELECT trigger_name, event_object_table
        FROM information_schema.triggers
        WHERE trigger_schema NOT IN ('pg_catalog', 'information_schema')
    ) LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || trigger_rec.trigger_name || ' ON ' || trigger_rec.event_object_table;
        destroyed_trigger_count := destroyed_trigger_count + 1;
    END LOOP;

END;
$$ LANGUAGE plpgsql;

/*
--Declare the variable and call the procedure
DO $$
DECLARE
    destroyed_trigger_count integer;
BEGIN
    CALL destroy_triggers(destroyed_trigger_count);
    RAISE NOTICE 'Destroyed % triggers', destroyed_trigger_count;
END $$;
*/

/*
4) Create a stored procedure with an input parameter that outputs names and descriptions of object types 
(only stored procedures and scalar functions) that have a string specified by the procedure parameter.
*/
CREATE OR REPLACE PROCEDURE find_objects_with_string(p_search_string text)
LANGUAGE plpgsql
AS $$
DECLARE
    r record;
BEGIN
FOR r IN (
    SELECT CASE WHEN prokind = 'p' THEN 'Stored Procedure' ELSE 'Scalar Function' END AS object_type,
           proname AS object_name,
           prosrc AS object_definition
    FROM pg_proc
    WHERE prokind IN ('p', 'f')
    AND prosrc ILIKE '%' || p_search_string || '%'
)
LOOP
	RAISE NOTICE 'Object Name: %,  Object Type: %', r.object_name, r.object_type;   
END LOOP;
END;
$$;

--CALL find_objects_with_string('select');