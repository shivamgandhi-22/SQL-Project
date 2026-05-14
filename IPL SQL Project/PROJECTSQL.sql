-- CREATING TABLE FOR DATABASES

--1 IPL_BALL
CREATE TABLE IPL_BALL(
	ID INT,
	INNING INT,
	OVER INT,
	BALL INT,
	BATSMAN VARCHAR,
	NON_STRIKER VARCHAR,
	BOWLER VARCHAR,
	BATSMAN_RUNS INT,
	EXTRA_RUNS INT,
	TOTAL_RUNS INT,
	IS_WICKET INT,
	DISMISSAL_KIND VARCHAR,
	PLAYER_DISMISSED VARCHAR,
	FIELDER VARCHAR,
	EXTRAS_TYPE VARCHAR,
	BATTING_TEAM VARCHAR,
	BOWLING_TEAM VARCHAR
);


--2 IPL_MATCHES
CREATE TABLE IPL_MATCHES(
	ID INT,
	CITY VARCHAR,
	DATE DATE,
	PLAYER_OF_MATCH VARCHAR,
	VENUE VARCHAR,
	NEUTRAL_VENUE INT,
	TEAM1 VARCHAR,
	TEAM2 VARCHAR,
	TOSS_WINNER VARCHAR,
	TOSS_DECISION VARCHAR,
	WINNER VARCHAR,
	RESULT VARCHAR,
	RESULT_MARGIN INT,
	ELIMINATOR VARCHAR,
	METHOD VARCHAR,
	UMPIRE1 VARCHAR,
	UMPIRE2 VARCHAR
);


--COPY CSV FILE INTO TABLE
--1 IPL_BALL

COPY IPL_BALL FROM 'C:\Program Files\PostgreSQL\16\data\data_copy\IPL Dataset\IPL_BALL.CSV' DELIMITER ',' CSV HEADER;

--2 IPL_MATCHES

SET datestyle = 'ISO, DMY';

COPY IPL_MATCHES FROM 'C:\Program Files\PostgreSQL\16\data\data_copy\IPL Dataset\IPL_matches.CSV' DELIMITER ',' CSV HEADER;


--ADDITIONAL QUESTIONS


--1 Get the count of cities that have hosted an IPL match

SELECT COUNT(DISTINCT CITY) AS HOST_CITIES
FROM MATCHES;


--CREATE DELIVERIES TABLE

CREATE TABLE DELIVERIES AS SELECT * FROM IPL_BALL;

SELECT * FROM DELIVERIES;

--2 CREATE DELIVERIES_V02 TABLE

CREATE TABLE DELIVERIES_V02 AS
SELECT *,
	CASE
	WHEN TOTAL_RUNS >= 4 THEN 'boundary'
	WHEN TOTAL_RUNS = 0 THEN 'dot'
    ELSE 'other'
	END AS BALL_RESULT
FROM DELIVERIES;

SELECT batsman_runs,total_runs,ball_result FROM DELIVERIES_V02 where ball_result='boundary';


--3 Write a query to fetch the total number of boundaries and dot balls from the deliveries_v02 table.

SELECT 
	SUM(CASE WHEN BALL_RESULT = 'boundary' THEN 1 ELSE 0 END) AS total_boundaries,
	SUM(CASE WHEN BALL_RESULT = 'dot' THEN 1 ELSE 0 END) AS total_dotballs
FROM DELIVERIES_V02 ;

--4 Write a query to fetch the total number of boundaries scored by each team from the deliveries_v02 table and order it in descending order of the number of boundaries scored.

SELECT BATTING_TEAM, COUNT(*) AS total_boundaries
FROM DELIVERIES_V02
WHERE BALL_RESULT = 'boundary'
GROUP BY BATTING_TEAM
ORDER BY total_boundaries DESC;

--5 Write a query to fetch the total number of dot balls bowled by each team and order it in descending order of the total number of dot balls bowled.

SELECT BOWLING_TEAM, COUNT(*) AS total_dotballs
FROM DELIVERIES_V02
WHERE BALL_RESULT = 'dot'
GROUP BY BOWLING_TEAM
ORDER BY total_dotballs DESC;

--6 Write a query to fetch the total number of dismissals by dismissal kinds where dismissal kind is not NA

SELECT DISMISSAL_KIND, COUNT(*) AS total_dismissals
FROM DELIVERIES_V02
WHERE DISMISSAL_KIND != 'NA'
GROUP BY DISMISSAL_KIND;

--7 Write a query to get the top 5 bowlers who conceded maximum extra runs from the deliveries table

SELECT BOWLER, SUM(EXTRA_RUNS) AS maximum_extra_runs
FROM DELIVERIES
GROUP BY BOWLER
ORDER BY maximum_extra_runs DESC
LIMIT 5;

--8 Write a query to create a table named deliveries_v03

--CREATE TABLE MATCHES

CREATE TABLE MATCHES AS SELECT * FROM IPL_MATCHES;

SELECT * FROM MATCHES;

--CREATE TABLE DELIVERIES_V03

CREATE TABLE DELIVERIES_V03 AS
SELECT d.*, m.venue, m.date AS match_date
FROM DELIVERIES_V02 d
JOIN MATCHES m
ON d.id = m.id;

SELECT * FROM DELIVERIES_V03 limit 10;

--9 Write a query to fetch the total runs scored for each venue and order it in the descending order of total runs scored

SELECT DISTINCT VENUE, SUM(TOTAL_RUNS) AS total_runs_scored
FROM DELIVERIES_V03
GROUP BY VENUE
ORDER BY total_runs_scored DESC;

--10 Write a query to fetch the year-wise total runs scored at Eden Gardens and order it in the descending order of total runs scored.

SELECT EXTRACT(YEAR FROM MATCH_DATE) AS year, SUM(TOTAL_RUNS) AS total_runs
FROM DELIVERIES_V03
WHERE VENUE = 'Eden Gardens'
GROUP BY EXTRACT(YEAR FROM MATCH_DATE) 
ORDER BY total_runs DESC;

--BIDDING ON BATTERS

--QUESTION 1

SELECT
  BATSMAN,
 ROUND ((SUM(CASE WHEN EXTRAS_TYPE != 'wides' THEN BATSMAN_RUNS ELSE 0 END)*1.0 /
   SUM(CASE WHEN EXTRAS_TYPE != 'wides' THEN 1 ELSE 0 END)) * 100,2) AS strike_rate
FROM IPL_BALL
GROUP BY
  BATSMAN
HAVING
  SUM(CASE WHEN EXTRAS_TYPE != 'wides' THEN 1 ELSE 0 END) > 500
ORDER BY
  strike_rate DESC
LIMIT 10;

--QUESTION 2

SELECT BATSMAN,
	COUNT(DISTINCT EXTRACT(YEAR FROM MATCH_DATE)) AS seasons,
	ROUND(SUM(BATSMAN_RUNS)*1.0/SUM(IS_WICKET),2) AS average
FROM DELIVERIES_V03
GROUP BY BATSMAN
HAVING SUM(IS_WICKET) >=1 and
	COUNT(DISTINCT EXTRACT(YEAR FROM MATCH_DATE)) > 2
ORDER BY average DESC
LIMIT 10;

--QUESTION 3

SELECT a.BATSMAN,
(b.BOUNDARY_RUNS*100/sum(a.BATSMAN_RUNS)) as boundary_percent
FROM DELIVERIES_V03 AS a
INNER JOIN
(SELECT a.BATSMAN,SUM(a.BATSMAN_RUNS) as boundary_runs
FROM DELIVERIES_V03 AS a
WHERE a.BATSMAN_RUNS=4 or a.BATSMAN_RUNS=6
GROUP BY a.BATSMAN) AS b
ON a.BATSMAN=b.BATSMAN
GROUP BY a.batsman,b.boundary_runs
HAVING COUNT(DISTINCT EXTRACT(YEAR FROM MATCH_DATE)) > 2
ORDER BY boundary_percent DESC
LIMIT 10;

--BIDDING ON BALLERS

--QUESTION 1

SELECT BOWLER, 
ROUND((SUM(TOTAL_RUNS) / (COUNT(BOWLER)/6.0)),2) AS economy_rate       
FROM IPL_BALL 
GROUP BY BOWLER
HAVING COUNT(BOWLER) >= 500  
ORDER BY economy_rate 
LIMIT 10;

--QUESTION 2

SELECT 
    BOWLER,
    ROUND((total_bowled * 1.0) / total_wickets,2) AS bowler_strike_rate
FROM (
    SELECT
        BOWLER,
        COUNT(*) AS total_bowled,
        SUM(CASE WHEN 
	dismissal_kind NOT IN ('run out','retired hurt','obstucting the field','NA') THEN 1 ELSE 0 END) AS total_wickets
    FROM IPL_BALL
    GROUP BY BOWLER
    HAVING COUNT(*) >= 500 
) AS bowlers
ORDER BY bowlers DESC 
LIMIT 10;


--BIDDING ON ALL ROUNDERS

--QESTION 1
	
CREATE TABLE BATTING_STRIKE_RATE AS SELECT
  BATSMAN,
 ROUND ((SUM(CASE WHEN EXTRAS_TYPE != 'wides' THEN BATSMAN_RUNS ELSE 0 END)*1.0 /
   SUM(CASE WHEN EXTRAS_TYPE != 'wides' THEN 1 ELSE 0 END)) * 100,2) AS batting_strike_rate
FROM IPL_BALL
GROUP BY
  BATSMAN
HAVING
  SUM(CASE WHEN EXTRAS_TYPE != 'wides' THEN 1 ELSE 0 END) > 500
ORDER BY
  batting_strike_rate DESC;


CREATE TABLE BOWLING_STRIKE_RATE AS SELECT 
    BOWLER,
    ROUND((total_bowled * 1.0) / total_wickets,2) AS bowler_strike_rate
FROM (
    SELECT
        BOWLER,
        COUNT(*) AS total_bowled,
        SUM(CASE WHEN 
	dismissal_kind NOT IN ('run out','retired hurt','obstucting the field','NA') THEN 1 ELSE 0 END) AS total_wickets
    FROM IPL_BALL
    GROUP BY BOWLER
    HAVING COUNT(*) >= 300 
) AS bowlers
ORDER BY bowler_strike_rate;


SELECT a.BATSMAN as all_rounder,a.BATTING_STRIKE_RATE as batting_strike_rate,b.BOWLER_STRIKE_RATE as bowling_strike_rate
from BATTING_STRIKE_RATE AS a
INNER JOIN BOWLING_STRIKE_RATE AS b
on a.BATSMAN=b.BOWLER
order by batting_strike_rate desc,bowling_strike_rate asc
limit 10;
