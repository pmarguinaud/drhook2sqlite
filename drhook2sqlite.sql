
SELECT AVG((t.row - sub.a) * (t.row - sub.a)) as var from t,  (SELECT AVG(row) AS a FROM t) AS sub;

select Name, avg (Self) from DrHookTime group by Name order by avg (Self) desc ;

SELECT Name, AVG(Self) as Self FROM DrHookTime group by Name;

SELECT AVG((DrHookTime.Self - sub.Self) * (DrHookTime.Self - sub.Self)) as var from DrHookTime,  (SELECT Name, AVG(Self) as Self FROM DrHookTime group by Name) AS sub;

# Average

CREATE TABLE DrHookTime_Merge (Name VARCHAR (255) NOT NULL, Avg_Self FLOAT NOT NULL, Std_Self FLOAT NOT NULL, Min_Self FLOAT NOT NULL, Max_Self FLOAT NOT NULL, PRIMARY KEY (Name)); 
INSERT INTO DrHookTime_Merge (Name, Avg_Self, Std_Self, Min_Self, Max_Self)  SELECT Name, AVG (Self), -1, -1, -1 FROM DrHookTime GROUP BY Name;

# StdDev

CREATE TABLE DrHookTime_Std (Name VARCHAR (255) NOT NULL, Std_Self FLOAT NOT NULL, PRIMARY KEY (Name)); 

INSERT INTO DrHookTime_Std (Name, Std_Self) SELECT DrHookTime.Name, SQRT (AVG ((DrHookTime.Self - DrHookTime_Merge.Avg_Self)*(DrHookTime.Self - DrHookTime_Merge.Avg_Self))) \
  FROM DrHookTime, DrHookTime_Merge WHERE DrHookTime.Name = DrHookTime_Merge.Name GROUP BY DrHookTime_Merge.Name;

UPDATE DrHookTime_Merge SET Std_Self = (SELECT Std_Self FROM DrHookTime_Std WHERE DrHookTime_Merge.Name = DrHookTime_Std.Name) ; 

SELECT DrHookTime.Name, SQRT (AVG ((DrHookTime.Self - DrHookTime_Merge.Avg_Self)*(DrHookTime.Self - DrHookTime_Merge.Avg_Self))) \
  FROM DrHookTime, DrHookTime_Merge WHERE DrHookTime.Name = DrHookTime_Merge.Name GROUP BY DrHookTime_Merge.Name;

SELECT DrHookTime.Name, DrHookTime_Merge.Avg_Self, SQRT (AVG ((DrHookTime.Self - DrHookTime_Merge.Avg_Self)*(DrHookTime.Self - DrHookTime_Merge.Avg_Self))) \
  FROM DrHookTime, DrHookTime_Merge WHERE DrHookTime.Name = DrHookTime_Merge.Name GROUP BY DrHookTime_Merge.Name \
  ORDER BY DrHookTime_Merge.Avg_Self DESC limit 10;

# Min/max

SELECT MIN (MaxTime.Max_Self), MAX (Maxtime.Max_Self) FROM (SELECT MAX(Self) AS Max_Self FROM DrHookTime WHERE Name = "RRTM_RTRN1A_140GP" GROUP BY Task) AS MaxTime; 


SELECT Name, MIN (MaxTime.Max_Self), MAX (Maxtime.Max_Self) \
  FROM (SELECT Name, MAX (Self) AS Max_Self FROM DrHookTime GROUP BY Name, Task) \
  AS MaxTime GROUP BY Name ORDER BY MAX (Maxtime.Max_Self);


CREATE TABLE DrHookTime_MinMax (Name VARCHAR (255) NOT NULL, Min_Self FLOAT NOT NULL, Max_Self FLOAT NOT NULL, PRIMARY KEY (Name));

INSERT INTO DrHookTime_MinMax (Name, Min_Self, Max_Self) \
  SELECT Name, MIN (MaxTime.Max_Self), MAX (Maxtime.Max_Self) \
  FROM (SELECT Name, MAX (Self) AS Max_Self FROM DrHookTime GROUP BY Name, Task) \
  AS MaxTime GROUP BY Name;

UPDATE DrHookTime_Merge SET \
  Min_Self = (SELECT Min_Self FROM DrHookTime_MinMax WHERE DrHookTime_Merge.Name = DrHookTime_MinMax.Name), \
  Max_Self = (SELECT Max_Self FROM DrHookTime_MinMax WHERE DrHookTime_Merge.Name = DrHookTime_MinMax.Name) ;





