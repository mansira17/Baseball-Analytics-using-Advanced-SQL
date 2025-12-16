-- PART I: SCHOOL ANALYSIS
use maven_advanced_sql;

-- 1. View the schools and school details tables

select * 
from schools;

select * 
from school_details;

-- 2. In each decade, how many schools were there that produced players?

select round(yearID, -1) as decade,
	   count(distinct schoolID) as num_schools
from schools 
group by decade
order by decade;

-- 3. What are the names of the top 5 schools that produced the most players?

select s.schoolID, sd.name_full, count(distinct s.playerID) as num_players
from schools as s
left join school_details as sd
on s.schoolID = sd.schoolID
group by s.schoolID, sd.name_full
order by num_players desc
limit 5;

-- 4. For each decade, what were the names of the top 3 schools that produced the most players?

with decade_count as (select sd.name_full,
                             round(yearID, -1) as decade,
                             count(distinct s.playerID) as num_players
					  from schools as s
					  left join school_details as sd
					  on s.schoolID = sd.schoolID
					  group by sd.name_full, decade),
                      
	ranked as (select name_full, decade, num_players,
                      row_number() over(partition by decade order by num_players desc) as ranks
			   from decade_count)

select name_full, decade, ranks
from ranked
where ranks < 4;

-- PART II: SALARY ANALYSIS
-- 1. View the salaries table
select *
from salaries;

-- 2. Return the top 20% of teams in terms of average annual spending
with team_salary as (select yearID, teamID, sum(salary) as spending
					from salaries
					group by teamID, yearID),
                    
	spend as (select teamID, avg(spending) as avg_spend,
					  ntile(5) over(order by avg(spending) desc) as pct_rank
               from team_salary
               group by teamID)

select teamID, avg_spend
from spend
where pct_rank = 1;

-- 3. For each team, show the cumulative sum of spending over the years

with yearly_spending as (select yearID, teamID, sum(salary) as spending
						 from salaries
						 group by teamID, yearID)
						
select yearID, teamID, spending,
	   sum(spending) over(partition by teamID order by yearID) as cumulative_sum
from yearly_spending
order by teamID, yearID;

-- 4. Return the first year that each team's cumulative spending surpassed 1 billion

with yearly_spending as (select yearID, teamID, sum(salary) as spending
						 from salaries
						 group by teamID, yearID),
                         
	cumulative_spending as (select yearID, teamID, spending,
						    sum(spending) over(partition by teamID order by yearID) as cumulative_sum
						    from yearly_spending),
                            
	ranked as (select yearID, teamID, cumulative_sum,
                      row_number() over(partition by teamID order by yearID) as top_salary
			   from cumulative_spending
               where cumulative_sum > 1000000000)
						
select yearID, teamID, cumulative_sum
from ranked
where top_salary = 1
order by teamID, yearID;

-- PART III: PLAYER CAREER ANALYSIS
-- 1. View the players table and find the number of players in the table
select *
from players;

select count(distinct playerID) as num_players
from players;

-- 2. For each player, calculate their age at their first game, their last game, and their career length (all in years). Sort from longest career to shortest career.

select nameGiven,
       timestampdiff(year, cast(concat(birthYear, '-', birthMonth, '-', birthDay) as date), debut) as starting_age,
       timestampdiff(year, cast(concat(birthYear, '-', birthMonth, '-', birthDay) as date), finalGame) as ending_age,
       timestampdiff(year, debut, finalGame) as career_length
from players
order by career_length desc;

-- 3. What team did each player play on for their starting and ending years?
select *
from players;

select *
from salaries;

select p.nameGiven,
       s.yearID as starting_year,
       s.teamID as starting_team,
       e.yearID as ending_year,
       e.teamID as ending_team
from players as p
inner join salaries as s
on p.playerID = s.playerID and
   year(p.debut) = s.yearID
inner join salaries as e
on p.playerId = e.playerID and
   year(p.finalGame) = e.yearID;
   

-- 4. How many players started and ended on the same team and also played for over a decade?

select p.nameGiven,
       s.yearID as starting_year,
       s.teamID as starting_team,
       e.yearID as ending_year,
       e.teamID as ending_team
from players as p
inner join salaries as s
on p.playerID = s.playerID and
   year(p.debut) = s.yearID
inner join salaries as e
on p.playerId = e.playerID and
   year(p.finalGame) = e.yearID
where s.teamID = e.teamID and
      e.yearID - s.yearID > 10;

-- PART IV: PLAYER COMPARISON ANALYSIS
-- 1. View the players table

select *
from players;

-- 2. Which players have the same birthday?
with birth as (
	select nameGiven,
           cast(concat(birthYear, '-', birthMonth, '-', birthDay) as date) as birthDate
	from players
)

select b1.nameGiven, b2.nameGiven, b1.birthDate
from birth as b1
join birth as b2
on b1.birthDate = b2.birthDate and
   b1.nameGiven <> b2.nameGiven;

-- 3. Create a summary table that shows for each team, what percent of players bat right, left and both
select s.teamID, 
	   round((sum(p.bats = 'R') / count(*)) * 100, 2) as bats_right,
       round((sum(p.bats = 'L') / count(*)) * 100, 2) as bats_left,
       round((sum(p.bats = 'B') / count(*)) * 100, 2) as bats_both
from players as p
inner join salaries as s
on p.playerID = s.playerID
group by s.teamID
order by s.teamID;

-- 4. How have average height and weight at debut game changed over the years, and what's the decade-over-decade difference?
with height_weight as (
	select floor(year(debut) / 10) * 10 as decade,
		   avg(weight) as avg_weight,
		   avg(height) as avg_height
	from players
	group by decade
)

select decade,
	   avg_weight - lag(avg_weight) over(order by decade) as weight_diff,
       avg_height - lag(avg_height) over(order by decade) as height_diff
from height_weight
where decade is not null;