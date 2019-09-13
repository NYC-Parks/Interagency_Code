/***********************************************************************************************************************
																													   	
 Created By: Dan Gallagher, daniel.gallagher@parks.nyc.gov, Innovation & Performance Management         											   
 Modified By: <Modifier Name>																						   			          
 Created Date:  07/29/2019																							   
 Modified Date: <MM/DD/YYYY>																							   
											       																	   
 Project: Data Warehouse	
 																							   
 Tables Used: <Database>.<Schema>.<Table Name1>																							   
 			  <Database>.<Schema>.<Table Name2>																								   
 			  <Database>.<Schema>.<Table Name3>				
			  																				   
 Description: Create a stored proce									   
																													   												
***********************************************************************************************************************/
use dwh
go

create procedure dbo.sp_create_tbl_ref_calendar as
begin
	if object_id('dwh.dbo.tbl_ref_calendar') is null
		create table dwh.dbo.tbl_ref_calendar(ref_date date primary key,
											  fiscal_day int not null,
											  fiscal_week int not null,
											  fiscal_qtr varchar(10) not null,
											  fiscal_qtr_adj varchar(10) not null,
											  fiscal_year int not null,
											  calndr_day int not null,
											  calndr_week int not null, 
											  calndr_qtr varchar(10) not null,
											  calndr_qtr_adj varchar(10) not null,
											  calndr_year int not null);


	else
		declare @nothing int;
end;