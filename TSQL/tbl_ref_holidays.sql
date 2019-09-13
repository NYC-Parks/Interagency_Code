/***********************************************************************************************************************
																													   	
 Created By: Dan Gallagher, daniel.gallagher@parks.nyc.gov, Innovation & Performance Management         											   
 Modified By: Dan Gallagher, daniel.gallagher@parks.nyc.gov, Innovation & Performance Management
 Created Date:  04/02/2018																							   
 Modified Date: 07/31/2019	     																						   			          																						   
											       																	   
 Project: DWH
 																							   
 Tables Used: dwh.dbo.tbl_ref_calendar																					   
			  
 Tables Created: dwh.dbo.tbl_ref_holidays
			  		
			  																				   
 Description: A script that creates a table of all NYC government (regular and floating) holidays for a specified range 
			  of years.	Reference: http://www.nyc.gov/html/dcas/downloads/pdf/psb/440_2R.PDF							   
																													   												
***********************************************************************************************************************/
use dwh
go
/*create procedure tbl_ref_holidays as
begin*/
	set nocount on;

	/*If the table currently exists then truncate all rows*/
	if object_id(N'dwh.dbo.tbl_ref_holiday') is not null
		--drop table dwh.dbo.tbl_ref_holidays;
		truncate table dwh.dbo.tbl_ref_holiday;

	/*Initialize the variables that are being used to create the output table*/
	declare @start_year int = 2015, 
			@end_year int = /*year(getdate())*/2024, 
			@year int,
			@i int,
			@n int,
			@fixed bit,
			@actual_date date, @observed_date date;

	/*Create the table variable to hold the values required to create the holidays table*/
	declare @holidays table(id int identity(1,1) not null, /*Unique ID*/
							name nvarchar(25) not null, /*The name of the holiday*/
							month_name nvarchar(9) not null, /*The month of the holiday*/
							day_number int null, /*The specific day of holiday, if applicable*/
							day_name nvarchar(9) null, /*The day of the week the holiday falls on if applicable*/
							day_rank nvarchar(3) null,/*For the specific day of the week, the rank of the day (ex: 2nd Monday of Month) */
							fixed bit not null,/*Whether or not the holiday is fixed (a specific date) or variable*/
							floating bit not null,/*Whether or not the holiday is considered to be a floating holiday*/
							actual_date date,/*The actual date of the holiday*/
							observed_date date);/*If the holiday falls on a weekend, the day that is it observed by City employees*/

	/*Create the table variable that holds the values from the calendar reference table that are needed to assign holiday dates.*/
	declare @dates table(year_date date not null,
						 month_name nvarchar(9) not null,
						 day_name nvarchar(9) not null,
						 day_rank nvarchar(3) not null);

	/*Insert the government holidays and their corresponding patterns into the holidays table*/
	insert into @holidays (name, month_name, day_number, day_name, day_rank, fixed, floating)
		values('New Year''s Day', 'January', 1, null, null, 1, 0),
			  ('Martin Luther King Day', 'January', null, 'Monday', '3', 0, 0),
			  ('Lincoln''s Birthday', 'February', 12, null, null, 1, 1),
			  ('Washington''s Birthday', 'February', null, 'Monday', '3', 0, 0),
			  ('Memorial Day', 'May', null, 'Monday', 'max', 0, 0),
			  ('Independence Day', 'July', 4, null, null, 1, 0),
			  ('Labor Day', 'September', null, 'Monday', '1', 0, 0),
			  ('Columbus Day', 'October', null, 'Monday', '2', 0, 0),
			  ('Election Day', 'November', null, 'Tuesday', '1', 0, 0),
			  ('Veteran''s Day', 'November', 11, null, null, 1, 0),
			  ('Thanksgiving Day', 'November', null, 'Thursday', '4', 0, 0),
			  ('Christmas', 'December', 25, null, null, 1, 0);

	/*Set the year*/
	set @year = @start_year;
	/*Set the number of iterations to the number of holidays*/
	set @n = (select count(*) from @holidays);

	/*While the year of the current iteration is less than or equal to the ending year then step through the loop*/
	while @year <= @end_year
		begin/*Start the year loop*/
			/*Create a table variable that holds the actual holiday date and the observed date*/
			declare @dates_ref table (actual_date date,
									  observed_date date);
			/*Set the inner loop value to start at 1*/
			set @i = 1;	
			/*Delete all records from the dates table variable*/		
			delete from @dates;

			/*Insert the values into the dates table variable from the calendar reference table*/
			insert into @dates
				select ref_date as year_date,
					   month_name,
					   day_name,
					   /*Calculate the rank of day names by months*/
					   dense_rank() over (partition by month_name, day_name order by ref_date, month_name, day_name) as day_rank
				from (select ref_date, 
							 /*Weekday name of reference date*/
							 datename(weekday, ref_date) as day_name, 
							 /*Month name of reference date*/
							 datename(month, ref_date) month_name 
					  from dwh.dbo.tbl_ref_calendar
					  /*Subset to the year of the current iteration*/
					  where year(ref_date) = @year) as t
					  order by ref_date;

				/*Iterate through the holidays where i is less than or equal to the number of holidays*/
				while @i <= @n
				begin/*Start the i loop*/
					/*Select the fixed value from holidays table variable where the id is equal to i*/
					set @fixed = (select fixed from @holidays where id = @i);

					/*If the holiday is not fixed (ex: 2nd Monday of Month) then insert the following records*/
					if @fixed = 0
						begin
							/*Insert the holiday date values into the dates reference table*/
							insert into @dates_ref
								/*Luckily the actual and observed dates will always be equal for these holidays because they always occur on weekdays.*/
								select r.year_date as actual_date,
									   r.year_date as observed_date
								from @holidays as l
								inner join
									(select *,
											/*Take the highest value for the rank of the day names in each month and assign it a value of max*/
											case when last_value(day_rank) over (partition by month_name, day_name order by month_name, day_name) = day_rank then 'max'
											/*Otherwise cast the rank as its value*/
													else cast(day_rank as nvarchar(3)) 
											end as day_rank2
										from @dates) as r
								/*Join the tables on the month name, the day name and when the day_ranks are equal.*/
								on l.month_name = r.month_name and
									l.day_name = r.day_name and
									(l.day_rank = r.day_rank2 or 
									 l.day_rank = r.day_rank)
								where id = @i;

								/*Set the actual holiday date from the dates reference table*/
								set @actual_date = (select actual_date from @dates_ref);
								/*Set the observed holiday date from the dates reference table*/
								set @observed_date = (select observed_date from @dates_ref);
						
							/*Delete the records in the dates_ref table*/
							delete from @dates_ref;

							/*Update the values in the holidays table with the actual and observed dates for a given holiday based on i being equal to the id*/
							update @holidays
								set actual_date = @actual_date,
									observed_date = @observed_date
								where id = @i;
						end;

					/*If the holiday is fixed (ex: July 4) then insert the following records*/
					else
						begin
							/*Insert the holiday date values into the dates reference table*/
							insert into @dates_ref
								/*The actual and observed dates of fixed holidays may vary depending on the day of the week on which the holiday falls*/
								select r.year_date as actual_date,
									   /*When a holiday falls on Saturday then the observed date is Friday, when it falls on a Sunday the observered date
										 is Monday, otherwise the actual and observed dates are equal. This logic is built from the link in the doc block.*/
									   case when r.day_name = 'Saturday' then cast(dateadd(day, -1, r.year_date) as date)
											when r.day_name = 'Sunday' then cast(dateadd(day, 1, r.year_date) as date)
											else r.year_date
									   end as observed_date
								from @holidays as l
								inner join
									 @dates as r
								/*Join the tables based the month name and the day number being equal*/
								on l.month_name = r.month_name and
								   l.day_number = datepart(day, r.year_date)
								where id = @i;

								/*Set the actual holiday date from the dates reference table*/
								set @actual_date = (select actual_date from @dates_ref);
								/*Set the observed holiday date from the dates reference table*/
								set @observed_date = (select observed_date from @dates_ref);
						
							/*Delete the records in the dates_ref table*/
							delete from @dates_ref;

							/*Update the values in the holidays table with the actual and observed dates for a given holiday based on i being equal to the id*/
							update @holidays
								set actual_date = @actual_date,
									observed_date = @observed_date
								where id = @i;
						end;
					/*Set the iteration to the next step*/
					set @i = @i + 1;
				end;/*End the i loop*/

				/*Insert the values from the holiday reference table variable into the permanent table*/
				begin transaction
				insert into dwh.dbo.tbl_ref_holiday(name, actual_date, observed_date, floating)
					select name, 
						   actual_date, 
						   observed_date, 
						   floating 
					from @holidays
				commit transaction
				/*Set the iteration to the next step*/
				set @year = @year + 1;
			end;/*End the year loop*/
/*end;*/