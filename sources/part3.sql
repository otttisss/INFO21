-- 1
CREATE or REPLACE FUNCTION GetTransferredPoints()
RETURNS table (
Peer1 varchar,
Peer2 varchar,
PointsAmount integer
)
AS $$
BEGIN
	RETURN QUERY
	SELECT
		tp1.CheckedPeer as Peer1,
		tp1.CheckingPeer as Peer2,
		tp1.PointsAmount - COALESCE(tp2.PointsAmount, 0) as PointsAmount
	FROM
		transferredpoints tp1
	LEFT JOIN
		transferredpoints tp2
	ON
		tp1.CheckedPeer = tp2.CheckingPeer
		AND tp1.CheckingPeer = tp2.CheckedPeer;
END;
$$
language plpgsql;

SELECT * FROM GetTransferredPoints();


-- 2. Функция, которая возвращает таблицу вида: ник пользователя, название проверенного задания, кол-во полученного XP
CREATE OR REPLACE FUNCTION GetXpEarned()
    RETURNS TABLE(Peer varchar, 
				  Task text, 
				  XP integer) 
LANGUAGE plpgsql 
AS $$
BEGIN
    RETURN QUERY
        SELECT checks.Peer, SPLIT_PART(checks.task, '_', 1) AS Task, xpamount AS XP
        FROM checks
                 JOIN verter ON checks.id = verter.check_id AND verter.check_status_by_verter = 'Success'
                 JOIN p2p p ON checks.id = p.check_id AND p.p2p_check_status = 'Success'
                 JOIN xp ON checks.id = xp.check_id
        ORDER BY Peer, XP DESC;
END;
$$;

SELECT * FROM GetXPEarned();

-- 3. Функция, определяющая пиров, которые не выходили из кампуса в течение всего дня
CREATE OR REPLACE FUNCTION GetPeersInsideCampus(checkDate date)
RETURNS TABLE (
    Peer varchar
)
AS $$
BEGIN 
    RETURN QUERY
    SELECT DISTINCT tt1.peer
    FROM timetracking tt1
    WHERE tt1.date = checkDate
    AND NOT EXISTS (
        SELECT 1
        FROM timetracking tt2
        WHERE tt2.date = checkDate
        AND tt2.peer = tt1.peer
        AND tt2.state = 2
    );
END;
$$
LANGUAGE plpgsql;


SELECT * FROM GetPeersInsideCampus('2023-08-01');


-- 4. Функция, считающая изменение в количестве пир поинтов каждого пира по таблице TransferredPoints
CREATE OR REPLACE FUNCTION CalculatePointsChange()
RETURNS TABLE (
    Peer varchar,
    PointsChange bigint
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        tp.CheckedPeer AS Peer,
        SUM(tp.PointsAmount) - COALESCE(SUM(tp2.PointsAmount), 0) AS PointsChange
    FROM
        TransferredPoints tp
    LEFT JOIN
        TransferredPoints tp2
    ON
        tp.CheckedPeer = tp2.CheckingPeer
        AND tp.CheckingPeer = tp2.CheckedPeer
    GROUP BY
        tp.CheckedPeer
    ORDER BY
        PointsChange DESC;
END;
$$
LANGUAGE plpgsql;

SELECT * FROM CalculatePointsChange();


-- 5. Посчитать изменение в количестве пир поинтов каждого пира по таблице, возвращаемой первой функцией из Part 3
CREATE OR REPLACE PROCEDURE CalculatePointsChangeFromProcedure()
LANGUAGE plpgsql
AS $$
DECLARE
    result_cursor REFCURSOR;
    temp_record RECORD;
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'temp_points_change') THEN
        DROP TABLE temp_points_change;
    END IF;
    
    CREATE TEMP TABLE temp_points_change AS
    SELECT
        Peer1 AS Peer,
        SUM(PointsAmount) AS PointsChange
    FROM
        GetTransferredPoints()
    GROUP BY
        Peer1;

    OPEN result_cursor FOR SELECT * FROM temp_points_change ORDER BY PointsChange DESC;

    LOOP
        FETCH result_cursor INTO temp_record;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Peer: %, PointsChange: %', temp_record.Peer, temp_record.PointsChange;
    END LOOP;
    
    CLOSE result_cursor;
END;
$$;

CALL CalculatePointsChangeFromProcedure();


-- 6. Определить самое часто проверяемое задание за каждый день
CREATE OR REPLACE PROCEDURE GetMostFrequentTasksPerDayProcedure()
LANGUAGE plpgsql
AS $$
DECLARE
    result_cursor REFCURSOR;
    temp_record RECORD;
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'temp_most_frequent_tasks') THEN
        DROP TABLE temp_most_frequent_tasks;
    END IF;
    
    CREATE TEMP TABLE temp_most_frequent_tasks AS
    SELECT
        c.Date AS Day,
        t.Title AS Task
    FROM (
        SELECT
            Date,
            Task,
            ROW_NUMBER() OVER (PARTITION BY Date ORDER BY COUNT(*) DESC) AS rn
        FROM
            Checks
        GROUP BY
            Date, Task
    ) c
    JOIN
        Tasks t
    ON
        c.Task = t.Title
    WHERE
        c.rn = 1;

    OPEN result_cursor FOR SELECT * FROM temp_most_frequent_tasks ORDER BY Day;

    LOOP
        FETCH result_cursor INTO temp_record;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Day: %, Task: %', temp_record.Day, temp_record.Task;
    END LOOP;
    
    CLOSE result_cursor;
END;
$$;

CALL GetMostFrequentTasksPerDayProcedure();


-- 7. Найти всех пиров, выполнивших весь заданный блок задач и дату завершения последнего задания
CREATE OR REPLACE PROCEDURE FindPeersByTaskBlock(IN blockName varchar)
LANGUAGE plpgsql
AS $$
DECLARE
    result_cursor REFCURSOR;
    temp_record RECORD;
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'temp_peer_tasks') THEN
        DROP TABLE temp_peer_tasks;
    END IF;
    
    CREATE TEMP TABLE temp_peer_tasks AS
    SELECT
        c.Peer,
        MAX(c.Date) AS LastTaskCompletionDate
    FROM (
        SELECT
            t.Peer,
            t.Date,
            t.Task,
            ROW_NUMBER() OVER (PARTITION BY t.Peer, t.Task ORDER BY t.Date DESC) AS rn
        FROM
            Checks t
            JOIN Tasks tt ON t.Task = tt.Title
        WHERE
            tt.ParentTask = blockName
    ) c
    WHERE
        c.rn = 1
    GROUP BY
        c.Peer;

    OPEN result_cursor FOR SELECT * FROM temp_peer_tasks ORDER BY LastTaskCompletionDate;

    LOOP
        FETCH result_cursor INTO temp_record;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Peer: %, Day: %', temp_record.Peer, temp_record.LastTaskCompletionDate;
    END LOOP;
    
    CLOSE result_cursor;
END;
$$;

CALL FindPeersByTaskBlock('C3_S21_StringPlus');


-- 8. Определить, к какому пиру стоит идти на проверку каждому обучающемуся
CREATE OR REPLACE PROCEDURE FindRecommendedPeer()
LANGUAGE plpgsql
AS $$
DECLARE
    result_cursor REFCURSOR;
    temp_record RECORD;
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'temp_peer_recommended') THEN
        DROP TABLE temp_peer_recommended;
    END IF;
    
    CREATE TEMP TABLE temp_peer_recommended AS
    SELECT
        r.Peer,
        r.RecommendedPeer
    FROM (
        SELECT
            rec.Peer,
            rec.RecommendedPeer,
            ROW_NUMBER() OVER (PARTITION BY rec.Peer ORDER BY COUNT(*) DESC) AS rn
        FROM
            Recommendations rec
            JOIN Friends f ON rec.RecommendedPeer = f.Peer1 AND rec.Peer = f.Peer2
        GROUP BY
            rec.Peer, rec.RecommendedPeer
    ) r
    WHERE
        r.rn = 1;

    OPEN result_cursor FOR SELECT * FROM temp_peer_recommended;

    LOOP
        FETCH result_cursor INTO temp_record;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Peer: %, RecommendedPeer: %', temp_record.Peer, temp_record.RecommendedPeer;
    END LOOP;
    
    CLOSE result_cursor;
END;
$$;

CALL FindRecommendedPeer();


-- 9. Определить процент пиров, которые:
-- Приступили только к блоку 1
-- Приступили только к блоку 2
-- Приступили к обоим
-- Не приступили ни к одному
CREATE OR REPLACE PROCEDURE CalculateBlockStatistics(
    IN block1_name varchar,
    IN block2_name varchar
)
LANGUAGE plpgsql
AS $$
DECLARE
    total_peers bigint;
    started_block1 bigint;
    started_block2 bigint;
    started_both_blocks bigint;
    didnt_start_any_block bigint;
BEGIN
    SELECT COUNT(DISTINCT Peer) INTO total_peers FROM Checks;

    SELECT COUNT(DISTINCT Peer) INTO started_block1
    FROM Checks
    WHERE Task LIKE block1_name || '%';

    SELECT COUNT(DISTINCT Peer) INTO started_block2
    FROM Checks
    WHERE Task LIKE block2_name || '%';

    SELECT COUNT(DISTINCT Peer) INTO started_both_blocks
    FROM Checks
    WHERE Task LIKE block1_name || '%' AND Peer IN (
        SELECT DISTINCT Peer FROM Checks WHERE Task LIKE block2_name || '%'
    );

    didnt_start_any_block := total_peers - started_block1 - started_block2 + started_both_blocks;

    RAISE NOTICE 'StartedBlock1: %', started_block1;
    RAISE NOTICE 'StartedBlock2: %', started_block2;
    RAISE NOTICE 'StartedBothBlocks: %', started_both_blocks;
    RAISE NOTICE 'DidntStartAnyBlock: %', didnt_start_any_block;
END;
$$;

CALL CalculateBlockStatistics('C3_S21_StringPlus', 'C3_SimpleBashUtils');


-- 10. Определить процент пиров, которые когда-либо успешно проходили проверку в свой день рождения
CREATE OR REPLACE PROCEDURE CalculateBirthdayCheckPercentages()
LANGUAGE plpgsql
AS $$
DECLARE
    totalPeers bigint;
    successfulPeers bigint;
    unsuccessfulPeers bigint;
BEGIN
    SELECT COUNT(*) INTO totalPeers FROM Peers;

    SELECT COUNT(DISTINCT p2p.CheckingPeer) INTO successfulPeers
    FROM P2P p2p
    JOIN Checks c ON p2p.check_id = c.ID
    JOIN Peers p ON c.Peer = p.Nickname
    WHERE p2p.p2p_check_status = 'Success' AND c.Date = p.Birthday;

    SELECT COUNT(DISTINCT p2p.CheckingPeer) INTO unsuccessfulPeers
    FROM P2P p2p
    JOIN Checks c ON p2p.check_id = c.ID
    JOIN Peers p ON c.Peer = p.Nickname
    WHERE p2p.p2p_check_status = 'Failure' AND c.Date = p.Birthday;

    RAISE NOTICE 'SuccessfulChecks: %', (successfulPeers * 100.0) / totalPeers;
    RAISE NOTICE 'UnsuccessfulChecks: %', (unsuccessfulPeers * 100.0) / totalPeers;
END;
$$;


CALL CalculateBirthdayCheckPercentages();


-- 11. Определить всех пиров, которые сдали заданные задания 1 и 2, но не сдали задание 3
CREATE OR REPLACE PROCEDURE FindPeersWithSpecificTaskCompletion(
    block1 VARCHAR,
    block2 VARCHAR,
    block3 VARCHAR,
    result_cursor REFCURSOR = 'result_cursor'
)
AS $$
BEGIN
    OPEN result_cursor FOR
        WITH t1 AS (
            SELECT c.Peer
            FROM Checks c
            JOIN P2P p ON c.ID = p.check_id
            JOIN Verter v ON c.ID = v.check_id
            WHERE c.Task = block1 AND p.p2p_check_status = 'Success' AND v.check_status_by_verter = 'Success'
        ),
        t2 AS (
            SELECT c.Peer
            FROM Checks c
            JOIN P2P p ON c.ID = p.check_id
            JOIN Verter v ON c.ID = v.check_id
            WHERE c.Task = block2 AND p.p2p_check_status = 'Success' AND v.check_status_by_verter = 'Success'
        ),
        t3 AS (
            SELECT c.Peer
            FROM Checks c
            JOIN P2P p ON c.ID = p.check_id
            JOIN Verter v ON c.ID = v.check_id
            WHERE c.Task = block3 AND p.p2p_check_status = 'Success' AND v.check_status_by_verter = 'Success'
        )
        SELECT DISTINCT t1.Peer
        FROM t1
        JOIN t2 ON t1.Peer = t2.Peer
        WHERE t1.Peer NOT IN (SELECT Peer FROM t3);
END;
$$ LANGUAGE plpgsql;

BEGIN;
	CALL FindPeersWithSpecificTaskCompletion('C3_S21_StringPlus', 'C3_SimpleBashUtils', 'C5_s21_decimal');
	FETCH ALL result_cursor;
COMMIT;

-- 12. Процедура с рекурсией, которая выводит количество предшествующих задач для каждой задачи
-- Коллеги, проверьте пожалуйста и по возможности исправьте
CREATE OR REPLACE PROCEDURE RecursiveTaskCount(
    result_cursor REFCURSOR = 'result_cursor'
)
AS $$
BEGIN
    OPEN result_cursor FOR
        WITH RECURSIVE rec AS (
            SELECT title AS task1, 0 AS CountC
            FROM tasks
            UNION ALL
            SELECT t.title, r.CountC + 1
            FROM rec r
            JOIN tasks t ON r.task1 = t.parenttask
        )
        SELECT task1 AS "Task", MAX(CountC) AS "PrevCount"
        FROM rec
        GROUP BY task1
        ORDER BY 2 DESC;
END;
$$ LANGUAGE plpgsql;


BEGIN;
    CALL RecursiveTaskCount();
    FETCH ALL result_cursor;
COMMIT;


-- 13. Процедура, которая находит "удачные" для проверок дни, если в нем есть хотя бы 
-- N идущих подряд успешных проверок
CREATE OR REPLACE PROCEDURE LuckyDays(amount INTEGER, result_cursor REFCURSOR = 'result_cursor')
AS $$
DECLARE
    success_counter INTEGER := 0;
    success_days    DATE[]  := '{}';
    current_day     DATE;
    state_value     VARCHAR;
    row_data        RECORD;
BEGIN
    FOR row_data IN SELECT *
                    FROM (WITH t1 AS (SELECT checks.id, checks.date, p.time, 'Success' AS State
                                      FROM checks
                                               JOIN tasks t ON t.title = checks.task
                                               JOIN xp x ON checks.id = x.check_id AND x.xpamount >= t.maxxp * 0.8
                                               JOIN p2p p ON checks.id = p.check_id AND p.p2p_check_status = 'Start'),
                               t2 AS (SELECT checks.id, checks.date, p.time, 'Failure' AS State
                                      FROM checks
                                               JOIN p2p p ON checks.id = p.check_id AND p.p2p_check_status = 'Start'
                                      EXCEPT
                                      SELECT id, date, time, 'Failure' AS State
                                      FROM t1)
                          SELECT * FROM t1 UNION SELECT * FROM t2 ORDER BY 2, 3) AS ft
        LOOP
            IF current_day IS NULL THEN
                current_day := row_data.date;
            ELSE
                IF current_day <> row_data.date THEN
                    current_day := row_data.date;
                    success_counter := 0;
                END IF;
            END IF;
            state_value := row_data.State;
            IF state_value = 'Success' THEN
                success_counter := success_counter + 1;
                IF success_counter = amount THEN
                    success_days := success_days || current_day;
                END IF;
            ELSE
                success_counter := 0;
            END IF;
        END LOOP;

    CREATE TEMPORARY TABLE temp_table
    (
        value DATE
    ) ON COMMIT DROP;

    INSERT INTO temp_table (value)
    SELECT unnest(success_days);

    OPEN result_cursor FOR
        SELECT DISTINCT value AS LuckyDay FROM temp_table;

END;
$$ LANGUAGE plpgsql;


BEGIN;
    CALL LuckyDays(2);
    FETCH ALL result_cursor;
COMMIT;


-- 14. Процедура, определяющая пира с наибольшим количеством XP
CREATE OR REPLACE PROCEDURE FindPeerWithMaxXp(IN result_cursor REFCURSOR = 'result_cursor') 
AS $$
BEGIN
    OPEN result_cursor FOR
        WITH tab1 AS (SELECT peer, xp
                      FROM (SELECT peer, sum(xpamount) AS xp
                            FROM xp
                                     JOIN checks c ON xp.check_id = c.id
                            GROUP BY peer) boo)
        SELECT peer, xp
        FROM tab1
        WHERE xp = (SELECT max(xp) FROM tab1);
END;
$$ LANGUAGE plpgsql;

BEGIN;
    CALL FindPeerWithMaxXp();
    FETCH ALL result_cursor;
COMMIT;


-- 15. Определить пиров, приходивших раньше заданного времени не менее N раз за всё время
CREATE OR REPLACE PROCEDURE FindPeersEarlyArrival(
	entry_time TIME, 
	amount INTEGER, 
	result_cursor REFCURSOR = 'result_cursor') AS $$
BEGIN
    OPEN rc FOR
        WITH t1 AS (SELECT peer, count(peer) AS count_state
                    FROM timetracking
                    WHERE timetracking.time < entry_time
                      AND state = 1
                    GROUP BY 1)
        SELECT peer
        FROM t1
        WHERE count_state >= amount
        ORDER BY LOWER(peer);
END
$$ LANGUAGE plpgsql;

BEGIN;
    CALL FindPeersEarlyArrival('20:00:00', 2);
    FETCH ALL result_cursor;
COMMIT;


-- 16. Определить пиров, выходивших за последние N дней из кампуса больше M раз
CREATE OR REPLACE PROCEDURE FindPeersLastDays(
  IN N_DAYS BIGINT,
  IN M_TIMES BIGINT,
  peer_list refcursor = 'peer_list'
)
LANGUAGE plpgsql
AS $$
BEGIN
  OPEN peer_list FOR
    WITH last_n_days AS (
      SELECT peer, timetracking.date
      FROM timetracking
      WHERE state = 2
        AND timetracking.date >= (current_date - (N_DAYS || ' day')::interval)
    )
    SELECT peer
    FROM last_n_days
    GROUP BY peer
    HAVING count(*) > M_TIMES;
END;
$$;

BEGIN;
  CALL FindPeersLastDays(20, 1);
  FETCH ALL FROM peer_list;
COMMIT;


-- 17. Определить для каждого месяца процент ранних входов
CREATE OR REPLACE PROCEDURE PercentEarlyEntry(
	entry REFCURSOR = 'entry')
	AS $$
BEGIN
    OPEN entry FOR
        WITH t1 AS (SELECT EXTRACT(MONTH FROM timetracking.date) AS Mon,
                           to_char(timetracking.date, 'Month')   AS Month,
                           count(peer)                AS TotalEntry
                    FROM timetracking
                             JOIN peers p ON p.nickname = timetracking.peer
                    WHERE state = 1
                      AND EXTRACT(MONTH FROM timetracking.date) = EXTRACT(MONTH FROM birthday)
                    GROUP BY 1, 2),
             t2 AS (SELECT EXTRACT(MONTH FROM timetracking.date) AS Mon,
                           to_char(timetracking.date, 'Month')   AS Month,
                           count(peer)                AS EarlyEntries
                    FROM timetracking
                             JOIN peers p ON p.nickname = timetracking.peer
                    WHERE state = 1
                      AND EXTRACT(MONTH FROM timetracking.date) = EXTRACT(MONTH FROM birthday)
                      AND timetracking.time < '12:00:00'
                    GROUP BY 1, 2)
        SELECT t1.Month, round(EarlyEntries * 100 / TotalEntry::NUMERIC, 2) AS EarlyEntries
        FROM t1
                 JOIN t2 ON t1.Mon = t2.Mon;
END
$$ LANGUAGE plpgsql;

BEGIN;
    CALL PercentEarlyEntry();
    FETCH ALL entry;
COMMIT;
