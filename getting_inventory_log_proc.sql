USE [Miracle]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		��������� �.�.
-- Create date: 15.12.22
-- Description:	��������� ������ ������� ��������������
-- ������� ���������:
-- @tblBranchList - ������ ��������
-- @begin         - ���� ������ ������
-- @end           - ���� ��������� �������
-- =============================================
CREATE PROCEDURE [dbo].[KW_232_1_v1]
	@person_id int,
	@json nvarchar(max)
AS
BEGIN

 SET NOCOUNT ON;
 SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

 -- ������ �������� � ������� ���������
 declare @tblBranchList dbo.IntList,
  @begin date = json_value(@json, '$.begin_date'),
  @end date = json_value(@json, '$.end_date')

 -- �������� �������
 INSERT INTO @tblBranchList(value)
 SELECT value
 FROM openjson(@json, '$.branch_ids');

 SELECT b.value AS branch_id,                                                   -- ������������� �������
 cf.CustomerFill AS branch,                                                     -- �������� �������
 it.InventoryTitleID AS inventory_title_id,                                     -- ������������� ��������������
 it.InventoryNumber AS inventory_number,                                        -- ����� ��������������
 it.DateStart AS date_start,                                                    -- ���� ������
 it.DateEnd AS date_end,                                                        -- ���� ���������
 it.[status] AS [status],                                                       -- ������ ��������������
 it.InvP AS prix_doc_number,                                                    -- ����� ��������� �������
 it.InvR AS rasx_doc_number,                                                    -- ����� ��������� �������
 SUM(ISNULL(it.surplus_o, 0)) AS surplus_sum,                                   -- ����� �������
 SUM(ISNULL(it.shortage_o, 0)) AS shortage_sum,                                 -- ����� ���������
 ABS(SUM(ISNULL(it.surplus_o, 0) - ISNULL(it.shortage_o, 0))) AS [difference]   -- ������� �����
 FROM @tblBranchList AS b
 JOIN Miracle.dbo.CustomerFill cf ON cf.CustomerFillId = b.value
 LEFT JOIN Miracle.dbo.InventoryTitle it ON it.BranchID = b.value
 WHERE it.DateStart >= @begin AND it.DateEnd <= @end AND it.[disable] = '0'
 GROUP BY b.value, cf.CustomerFill, it.InventoryTitleID, it.InventoryNumber, it.DateStart, it.DateEnd, it.[status], it.InvP, it.InvR
END

GO
USE [Miracle]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		��������� �.�.
-- Create date: 15.12.22
-- Description: �������� ������ ��������������
-- =============================================
CREATE PROCEDURE  [dbo].[KW_232_2_v1]
	@personId int,
	@json nvarchar(max)
AS
BEGIN
 set nocount on;

 declare
  @inventoryTitleId int = json_value(@json, '$.inventory_title_id')

 update Miracle.dbo.InventoryTitle set
  [Disable] = '1'
 where InventoryTitleID = @inventoryTitleId
END
