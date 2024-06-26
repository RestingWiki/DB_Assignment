USE GAME_COMPANY;

# Count the number of people in the team
DELIMITER $$
CREATE FUNCTION number_of_staff(_team_name VARCHAR(50))
RETURNS INT
DETERMINISTIC
BEGIN
	DECLARE num1 INT;
    DECLARE num2 INT;
    
	IF(NOT EXISTS(SELECT * FROM Team WHERE team_name = _team_name)) THEN
    RETURN -1;
    END IF;
    
    SELECT COUNT(*) INTO num1
    FROM Professional_Player
    WHERE Team = _team_name;

	SELECT COUNT(*) INTO num2
    FROM Coach
    WHERE Team = _team_name;
    
	RETURN num1 + num2;
END $$
DELIMITER ;

# Create a function to calculate the total money the team get from sponser
DELIMITER $$
CREATE FUNCTION Bonus_Sponsor(_team_name VARCHAR(50))
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
	DECLARE sum DECIMAL(10,2);
	IF (NOT EXISTS(SELECT * FROM Team WHERE team_name = _team_name)) THEN
		RETURN 0.00;
	ELSEIF(NOT EXISTS(SELECT * FROM sponsorship WHERE team = _team_name)) THEN
		RETURN 0.00;
	ELSE
		SELECT SUM(money) INTO sum
        FROM sponsorship
        WHERE team = _team_name;
        RETURN sum;
	END IF;
END $$
DELIMITER ;

# Create a function to calculate the total money the team get from the last tournmant 
DELIMITER $$
CREATE FUNCTION Bonus_Tournament(_team_name VARCHAR(50))
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
	DECLARE sum DECIMAL(10,2);
	IF (NOT EXISTS(SELECT * FROM Team WHERE team_name = _team_name)) THEN
		RETURN 0.00;
	ELSEIF (NOT EXISTS(SELECT * FROM Tournament WHERE joined_team = _team_name AND competition_year = YEAR(CURDATE()) - 1)) THEN
		RETURN 0.00;
	ELSE
		SELECT SUM(reward) INTO sum
        FROM Tournament
        WHERE joined_team = _team_name AND competition_year = YEAR(CURDATE()) - 1;
        RETURN sum;
	END IF;
END $$
DELIMITER ;

# Create two view from two previous functions
SELECT Team_name, Bonus_Sponsor(Team_name) AS Sponsor_money
FROM team;

SELECT Team_name, Bonus_Tournament(Team_name) AS Reward_money, 
	CASE 
		WHEN Bonus_Tournament(Team_name) = 0.00 AND YEAR(start_date) != YEAR(CURDATE()) THEN 0.8
        ELSE 1
	END AS Percentage
FROM team;

# Create information about team salary from this year
CREATE VIEW Team_Bonus AS
SELECT * , Bonus_Tournament(Team_name) AS Reward_money, 
	CASE 
		WHEN Bonus_Tournament(Team_name) = 0.00 AND YEAR(start_date) != YEAR(CURDATE()) THEN 0.8
        ELSE 1
	END AS Percentage, Bonus_Sponsor(Team_name) AS Sponsor_money, number_of_staff(Team_name) AS number_of_staff
FROM Team;

# Find the team salary per person in the team
DELIMITER $$
CREATE FUNCTION Bonus_Per_Person(_team_name VARCHAR(50))
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
	DECLARE money DECIMAL(10,2);
    
    SELECT (Reward_money + Sponsor_money / 12) * Percentage / number_of_staff INTO money
    FROM Team_Bonus
    WHERE Team_name = _team_name;

	RETURN money;
END $$
DELIMITER ;

# Find if the staff belong to any team
DELIMITER $$
CREATE FUNCTION belong_to_team(_Staff_Id CHAR(7))
RETURNS VARCHAR(50)
DETERMINISTIC
BEGIN
	DECLARE team_name VARCHAR(50);
    IF(EXISTS (SELECT team FROM Coach WHERE Coach_id = _Staff_Id)) THEN 
		SELECT team INTO team_name FROM Coach WHERE Coach_id = _Staff_Id;
		RETURN team_name;
	ELSEIF (EXISTS (SELECT team FROM Professional_Player WHERE Player_Id = _Staff_Id)) THEN
		SELECT team INTO team_name FROM Professional_Player WHERE Player_Id = _Staff_Id;
		RETURN team_name;
    END IF;
    RETURN 'NULL';
END $$
DELIMITER ;

# find the salary for staff id
DELIMITER $$
CREATE FUNCTION salary(_Staff_Id CHAR(7))
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
	DECLARE team_name VARCHAR(50);
    SET team_name = belong_to_team(_Staff_id);
    IF(team_name = 'NULL') THEN RETURN 0;
    ELSE RETURN Bonus_Per_Person(team_name);
    END IF;
END $$
DELIMITER ;
/*
SELECT * FROM Team_Salary_Tournament;
SELECT * FROM Team_Salary_Sponser;
SELECT * FROM Team_Salary;
SELECT Staff_id, Name, salary(Staff_id) AS Salary
FROM Staff;

SELECT Team_name, number_of_staff(team_name) AS number_of_staff
FROM Team;
*/

DROP PROCEDURE bonus_Salary;
DELIMITER $$
CREATE PROCEDURE bonus_salary()
BEGIN
	SELECT *, salary(Staff_id) AS Bonus_Salary_Tournament, 
    get_streamer_donation_cut_with_empid(Staff_id) AS "Bonus donation"
	FROM Staff;
END$$
DELIMITER ;

CALL bonus_salary();

DELIMITER $$
CREATE FUNCTION sponser_money(_sponsor_name VARCHAR(50))
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
	DECLARE money_ DECIMAL(10, 2);
	SELECT SUM(money) INTO money_ 
    FROM sponsorship
    WHERE  sponsor = _sponsor_name;
    RETURN money_;
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE call_sponsor_money(IN _sponsor_name VARCHAR(50))
BEGIN
	IF NOT EXISTS (SELECT * FROM sponsor WHERE sponsor_name = _sponsor_name) THEN
		SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = 'The sponser does not exist, can not find the total money';
    END IF;
	SELECT *, sponser_money(_sponsor_name)
	FROM sponsor
	WHERE sponsor_name = _sponsor_name;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sponsor_money_for_all()
BEGIN
	SELECT *, sponser_money(sponsor_name) AS total_money
	FROM sponsor;
END$$
DELIMITER ;

/*
CALL call_sponsor_money('Ho Van');
CALL sponsor_money_for_all();
CALL call_sponsor_money('Dinh Van');
SELECT * FROM staff_phones;
SELECT * FROM Contract;*/