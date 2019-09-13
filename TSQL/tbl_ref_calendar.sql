/***********************************************************************************************************************
																													   	
 Created By: Dan Gallagher, daniel.gallagher@parks.nyc.gov, Innovation & Performance Management         											   
 Modified By: Dan Gallagher, daniel.gallagher@parks.nyc.gov, Innovation & Performance Management         																					   			          
 Created Date:  02/10/2017																							   
 Modified Date: 07/29/2019																							   
											       																	   
 Project: Data Warehouse
 																							   
 Tables Used: NONE				
			  																				   
 Description: Create a reference table for the Parks calendar that includes the fiscal year dates, the relative day in a fiscal 
			  year, the relative week in a fiscal quarter, the fiscal year, the fiscal quarter and the same set of values
			  for the calendar year.  								   
																													   												
***********************************************************************************************************************/
use dwh
go

/*create procedure dbo.insert_sp_tbl_ref_calendar as
begin*/
	set nocount on;

	--set @end_year = (select year(getdate()) + 1 as end_year);

	declare @date_ref table (ref_date date not null,
							 fiscal_day int not null,
							 fiscal_week int not null,
							 fiscal_qtr varchar(10) not null,
							 fiscal_year int not null,
							 calndr_day int not null,
							 calndr_week int not null, 
							 calndr_qtr varchar(10) not null,
							 calndr_year int not null);

	/*Create the tables to hold the week the data for the weeks that need to be adjusted because they are on the boundary
	  of fiscal quarters.*/
	declare @fiscal_adj table (fiscal_week int not null,
							   fiscal_qtr varchar(10) not null,
							   fiscal_year int not null,
							   n int);

	declare @fiscal_adj2 table (fiscal_week int not null,
								fiscal_qtr varchar(10) not null,
								fiscal_year int not null);

	/*Create the tables to hold the week the data for the weeks that need to be adjusted because they are on the boundary
	  of calendar quarters.*/
	declare @calndr_adj table (calndr_week int not null,
							   calndr_qtr varchar(10) not null,
							   calndr_year int not null,
							   n int);

	declare @calndr_adj2 table (calndr_week int not null,
								calndr_qtr varchar(10) not null,
								calndr_year int not null);

	declare @date_ref_adj table (ref_date date not null,
								 fiscal_day int not null,
								 fiscal_week int not null,
								 fiscal_qtr varchar(10) not null,
								 fiscal_qtr_adj varchar(10) not null,
								 fiscal_year int not null,
								 calndr_day int not null,
								 calndr_week int not null, 
								 calndr_qtr varchar(10) not null,
								 calndr_year int not null);

	declare @start_year int, @end_year int, 
			@start_date date, @end_date date,
			@i int = 0, @n int,
			@cy int, @fy int,
			/*Current iteration date value*/
			@date date,
			/*Fiscal and calendar day varaiables*/
			@c_week int, @c_day int, 
			/*Fiscal and calendar week varaiables*/
			@f_week int, @f_day int,
			/*Fiscal and calendar start date varaiables*/
			@f_st date, @c_st date,
			/*Fiscal and calendar end date varaiables*/
			@f_en date, @c_en date,
			/*Fiscal and calendar quarter varaiables*/
			@f_qtr varchar(6), @c_qtr varchar(6);

	set @start_year = /*year(getdate())*/2015;
	set @end_year = 2025/*year(getdate()) + 1*/;

	/*The start date equals January 1 of the start_year*/
	set @start_date = datefromparts(@start_year, 01, 01);
	/*The start date equals June 30 of the end_year*/
	set @end_date = datefromparts(@end_year, 06, 30);

	/*Calculate the number of days between the start date and the end date.*/
	set @n = datediff(day, @start_date, @end_date);

	while @i <= @n
		begin
			/*With each iteration add the iteration number to start date.*/
			set @date = dateadd(day, @i, @start_date);

			/*Set the fiscal year*/
			set @fy = case when month(@date) between 1 and 6 then year(@date)
						   else year(@date) + 1
					  end; 
		
			/*Set the current iterations calendar year*/
			set @cy = year(@date);

			/*Calendar year starts on 01-01*/
			set @c_st = datefromparts(@cy, 01, 01);
			/*Fiscal year starts on 07-01 of the previous year*/
			set @f_st = datefromparts(@fy - 1, 07, 01);

			/*Get the relative week of the date for the calendar and fiscal year.*/
			set @c_week = datediff(week, @c_st, @date);
			set @f_week = datediff(week, @f_st, @date);

			/*Get the relative day of the date for the calendar and fiscal year.*/
			set @c_day = datediff(day, @c_st, @date);
			set @f_day = datediff(day, @f_st, @date);

			set @c_qtr = cast(year(@date) as varchar) + 'Q' + cast(datename(quarter, @date) as varchar);
							    
			set @f_qtr = case when @date between datefromparts(@cy, 07, 01) and datefromparts(@cy, 09, 30) then cast(@fy as varchar) + 'Q1'
							  when @date between datefromparts(@cy, 10, 01) and datefromparts(@cy, 12, 31) then cast(@fy as varchar) + 'Q2'
							  when @date between datefromparts(@cy, 01, 01) and datefromparts(@cy, 03, 31) then cast(@fy as varchar) + 'Q3'
							  else cast(@fy as varchar) + 'Q4'
							end;
			/*Insert the values into the date reference table.*/
			insert into @date_ref (ref_date, fiscal_day, fiscal_week, fiscal_qtr, fiscal_year, calndr_day, calndr_week, calndr_qtr, calndr_year)
							values(@date, @f_day, @f_week, @f_qtr, @fy, @c_day, @c_week, @c_qtr, year(@date))

			/*Moved to the next iteration.*/
			set @i = @i + 1;
		end

	/*Include better documentation!*/
	/*Add column to account for adjustments in the fiscal quarter when weeks are included in more than 1 fiscal quarter.*/
	insert into @fiscal_adj
		select l.fiscal_week, 
			   r.fiscal_qtr, 
			   r.fiscal_year, 
			   /*Calculate the count of records in each week, year and quarter group.*/
			   count(*) as n
			 /*Calculate the weeks where they have a count of more than one fiscal quarter.*/
		from (select distinct fiscal_year, fiscal_week, count(distinct fiscal_qtr) as nqtr
			  from @date_ref
			  group by fiscal_year, fiscal_week
			  having count(distinct fiscal_qtr) > 1) as l
		left join
			 @date_ref as r
		on l.fiscal_year = r.fiscal_year and
		   l.fiscal_week = r.fiscal_week
		group by fiscal_qtr, r.fiscal_year, l.fiscal_week
		order by fiscal_qtr


	insert into @fiscal_adj2
		select fiscal_week, 
			   fiscal_qtr, 
			   fiscal_year
		from (select fiscal_week, 
					 fiscal_qtr, 
					 fiscal_year,
					 n, 
					 max(n) over(partition by fiscal_year, fiscal_week) as maxn
			  from @fiscal_adj) as t
		where n = maxn

	/*Add column to account for adjustments in the calendar quarter when weeks are included in more than 1 calendar quarter.*/
	insert into @calndr_adj
		select l.calndr_week, 
			   r.calndr_qtr, 
			   r.calndr_year, 
			   /*Calculate the count of records in each week, year and quarter group.*/
			   count(*) as n
			 /*Calculate the weeks where they have a count of more than one calendar quarter.*/
		from (select distinct calndr_year, calndr_week, count(distinct calndr_qtr) as nqtr
			  from @date_ref
			  group by calndr_year, calndr_week
			  having count(distinct calndr_qtr) > 1) as l
		left join
			 @date_ref as r
		on l.calndr_year = r.calndr_year and
		   l.calndr_week = r.calndr_week
		group by calndr_qtr, r.calndr_year, l.calndr_week
		order by calndr_qtr

	/*Make the adjustment to the calendar quarters*/
	insert into @calndr_adj2
		select calndr_week, 
			   calndr_qtr, 
			   calndr_year
			 /*Calculate the maximum number of records included in each week, year and quarter group.*/
		from (select calndr_week, 
					 calndr_qtr, 
					 calndr_year,
					 n, 
					 max(n) over(partition by calndr_year, calndr_week) as maxn
			  from @calndr_adj) as t
		/*Subset to only included the quarter with the maximum number of records for each week, year and quarter group.*/
		where n = maxn

	/*Join the date reference table with the fiscal quarter adjustment table.*/
	insert into @date_ref_adj
		select l.ref_date,
			   l.fiscal_day,
			   l.fiscal_week,
			   l.fiscal_qtr,
			   /*If the fiscal quarter is adjusted use that value, otherwise use the actual fiscal quarter*/
			   coalesce(r.fiscal_qtr,l.fiscal_qtr),
			   l.fiscal_year,
			   l.calndr_day,
			   l.calndr_week,
			   l.calndr_qtr,
			   l.calndr_year
		from @date_ref as l
		left join
			 @fiscal_adj2 as r
		on l.fiscal_year = r.fiscal_year and 
		   l.fiscal_week = r.fiscal_week;

	/*If the table already exists then truncate it.*/
	if object_id('dwh.dbo.tbl_ref_calendar') is not null

	/*Insert the results into the final table*/
	/*Join the table that includes the date reference and adjusted fiscal quarter with the calendar quarter adjustment table.*/
	begin transaction
		insert into dwh.dbo.tbl_ref_calendar
			select l.ref_date,
				   l.fiscal_day,
				   l.fiscal_week,
				   /*If a quarter was adjusted use that value, otherwise use the raw value.*/
				   l.fiscal_qtr,
				   l.fiscal_qtr_adj,
				   l.fiscal_year,
				   l.calndr_day,
				   l.calndr_week,
				   l.calndr_qtr,
				   /*If the calendar quarter is adjusted use that value, otherwise use the actual calendar quarter*/
				   coalesce(r.calndr_qtr, l.calndr_qtr),
				   l.calndr_year
			from @date_ref_adj as l
			left join
				 @calndr_adj2 as r
			on l.calndr_year = r.calndr_year and 
			   l.calndr_week = r.calndr_week;
		commit transaction;
/*end;*/
	/*Validate if the primary key designation automatically creates an index.*/
	--create index idx_ref_date on dwh.dbo.tbl_ref_calendar(ref_date)
