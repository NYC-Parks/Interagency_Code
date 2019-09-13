/***********************************************************************************************************************
																													   	
 Created By: Dan Gallagher, daniel.gallagher@parks.nyc.gov, Innovation & Performance Management         											   
 Modified By: <Modifier Name>																						   			          
 Created Date:  07/31/2019																							   
 Modified Date: <MM/DD/YYYY>																							   
											       																	   
 Project: Data Warehouse	
 																							   
 Tables Used: <Database>.<Schema>.<Table Name1>																							   
 			  <Database>.<Schema>.<Table Name2>																								   
 			  <Database>.<Schema>.<Table Name3>				
			  																				   
 Description: Create the holiday reference table if it doesn't exist.  									   
																													   												
***********************************************************************************************************************/
use dwh
go

create procedure dbo.sp_create_tbl_ref_holiday_reportdb as 

begin
	if object_id('reportdb.rpt.tbl_ref_holiday') is null
		create table reportdb.rpt.tbl_ref_holiday (name nvarchar(25) not null, /*The name of the holiday*/
												   actual_date date primary key,/*The actual date of the holiday*/
												   observed_date date, /*If the holiday falls on a weekend, the day that is it observed by City employees*/
												   floating bit not null);/*Whether or not the holiday is considered to be a floating holiday*/;

	else
		declare @nothing int;
end;
