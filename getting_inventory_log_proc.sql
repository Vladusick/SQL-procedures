USE [Miracle]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Самощенко В.А.
-- Create date: 15.12.22
-- Description:	Получение данных журнала инвентаризации
-- Входные параметры:
-- @tblBranchList - Список филиалов
-- @begin         - Дата начала перода
-- @end           - Дата окончания периода
-- =============================================
CREATE PROCEDURE [dbo].[KW_232_1_v1]
	@person_id int,
	@json nvarchar(max)
AS
BEGIN

 SET NOCOUNT ON;
 SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

 -- Список филиалов и входные параметры
 declare @tblBranchList dbo.IntList,
  @begin date = json_value(@json, '$.begin_date'),
  @end date = json_value(@json, '$.end_date')

 -- Получаем филиалы
 INSERT INTO @tblBranchList(value)
 SELECT value
 FROM openjson(@json, '$.branch_ids');

 SELECT b.value AS branch_id,                                                   -- Идентификатор филиала
 cf.CustomerFill AS branch,                                                     -- Название филиала
 it.InventoryTitleID AS inventory_title_id,                                     -- Идентификатор инвентаризации
 it.InventoryNumber AS inventory_number,                                        -- Номер инвентаризации
 it.DateStart AS date_start,                                                    -- Дата начала
 it.DateEnd AS date_end,                                                        -- Дата окончания
 it.[status] AS [status],                                                       -- Статус инвентаризации
 it.InvP AS prix_doc_number,                                                    -- Номер документа прихода
 it.InvR AS rasx_doc_number,                                                    -- Номер документа расхода
 SUM(ISNULL(it.surplus_o, 0)) AS surplus_sum,                                   -- Сумма излишка
 SUM(ISNULL(it.shortage_o, 0)) AS shortage_sum,                                 -- Сумма недостачи
 ABS(SUM(ISNULL(it.surplus_o, 0) - ISNULL(it.shortage_o, 0))) AS [difference]   -- Разница итого
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
-- Author:		Самощенко В.А.
-- Create date: 15.12.22
-- Description: Удаление строки инвентаризации
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
