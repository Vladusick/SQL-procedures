USE [Miracle]
GO
/****** Object:  StoredProcedure [dbo].[KW_231_1_v1]    Script Date: 28.10.2022 16:09:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author: Самощенко Владислав
-- Create date: 27.10.2022
-- Description:	Получение состава программ маректинга Созвездие
-- Входные параметры: Идентификатор филиала и идентификатор маркетингового мероприятия Созвездия
-- =============================================
ALTER PROCEDURE [dbo].[KW_231_1_v1] @json nvarchar(max)
AS
BEGIN

 SET NOCOUNT ON;
 SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

  declare 
  @curDate date = getdate(),
  @branchId int = json_value(@json, '$.branch_id'), -- Идентификатор филиала
  @actionType varchar(100) = json_value(@json, '$.marketing_type_action'), -- Тип маркетингового мероприятия Созвездие
  -- переменные для хранение количества строк в каждом уровне древовидной таблицы и непривязанных товаров 
  @countOfRowsFromFirstLevel INTEGER = 0,
  @countOfRowsFromSecondLevel INTEGER = 0,
  @countOfRowsFromThirdLevel INTEGER = 0,
  @countIsUnattached INTEGER = 0

  -- таблица остатков по каждому товару (по regId) используется на 3 уровне вложенности в поле "Текущий остаток"
  create table #tmpOst(regId int, uQntOst numeric(15,5))
  -- таблица остатков общая по Созвездию (по product_id) используется на 1 и 2 уровне вложенности в поле "Текущий остаток"
  create table #tmpTotalOst(productId int, nomenclatureId int, totalOst numeric(15,5))
  -- таблица основных данных 
  create table #tmpActions(nomenclatureId int, productId int, nomenclatureName varchar(511), quantity int, cip int, regId int, actionId int, marketingActionName varchar(150), dateStart date, dateEnd date, uQntOst numeric(15,5), isAttached char(1))
  -- таблица поставщиков
  create table #tmpSuppliers(actionId int, productId int, cnt int)
  -- таблица, которая хранит в себе количество строк (товаров) на каждом уровне вложенности и непривязанные товары
  create table #amountOfRowsInLevels(first_level int, second_level int,  third_level int, is_unattached int)

  -- таблицы для трех уровней иерархии
  create table #lvl1(nomenclature_id int, product_id int, nomenclature_name varchar(511), quantity int, cip int, qnt_ost numeric(15,5), date_start date, date_end date, action_id int, marketing_action_name varchar(150), cnt int, reg_id int, is_attached char(1), total_ost numeric(15,5))
  create table #lvl2(nomenclature_id int, product_id int, nomenclature_name varchar(511), qnt_ost numeric(15,5), action_id int, reg_id int, is_attached char(1), drug_id int, total_ost numeric(15,5))
  create table #lvl3(nomenclature_id int, product_id int, nomenclature_name varchar(511), action_id int, fabr varchar(511), qnt_ost numeric(15,5), reg_id int, is_order char(1), drug_id int)

    /*
  Описание полей для таблиц с иерархической структурой:
  nomenclature_id - Код номенклатуры
  product_id - Код товара из Созвездия
  nomenclature_name - Название номенклатуры
  quantity - План упаковок
  cip - CIP-цена (не используется)
  qnt_ost - Текущий остаток
  date_start - Дата начала
  date_end - Дата окончания
  action_id - Код акции
  marketing_action_name - Наименование акции
  cnt - Количество разрешенных поставщиков
  reg_id - Код товара из Фармнет
  is_attached - Признак привязанности товара Созвездия к справочнику ФармНет
  total_ost - Общий остаток товаров (по product_id) Созвездия, используется на 1 и 2 уровне вложенности
  drug_id - Код лекарства из Фармнет, с помощью него можно убрать товары "не в тему" из 3 уровня (не используется)
  */

   -- заполнение таблицы остатков
 insert into #tmpOst(regId, uQntOst)
 select nd.RegID,
 sum(nd.uQntOst)
 from Miracle.dbo.NaklData nd with(nolock)
 where nd.branchId = @branchId and nd.[Disable] = '0' and nd.uQntOst > 0.0001
 group by nd.RegID
 option(optimize for unknown)


  -- заполнение основной таблицы
 insert into #tmpActions(nomenclatureId, productId, nomenclatureName, quantity, regId, 
 actionId, marketingActionName, dateStart, dateEnd, uQntOst, isAttached)
 select 
   cn.nomenclature_id,
   cp.product_id,
   cn.nomenclature_name,
   cp.quantity,
   cn.map_nomenclature_code,       -- Это regId в Созвездии, объединяются таблицы Созвездия и таблицы Фармнет через это поле.
   cb.marketing_action_id,
   cma.marketing_action_name,
   cma.date_start,
   cma.date_end,
   t.uQntOst,
   case when cn.map_nomenclature_code = 0 then '0' else '1' end [isAttached]
 from Miracle.dbo.ConstellationBranch cb with(nolock)
 join Miracle.dbo.ConstellationMarketingAction cma with(nolock)
 on cma.marketing_action_id = cb.marketing_action_id 
   and cma.marketing_action_type = @actionType
   and cma.[Disable] = '0' and @curDate between cma.date_start and cma.date_end
 left join Miracle.dbo.ConstellationProducts cp with(nolock)
 on cp.marketing_action_id = cma.marketing_action_id
 left join Miracle.dbo.ConstellationNomenclature cn with(nolock, forceseek, index = Ind1 )
 on cn.product_id = cp.product_id
 left join #tmpOst as t with(nolock) on cn.map_nomenclature_code = t.regId
 where cb.map_pharmacy_id = @branchId and cb.[Disable] = '0'
 option(optimize for unknown)


  -- скрыть удаленные товары
 update a set
 a.regId = isnull(r.RegID,0)
 from #tmpActions a with(nolock)
 left join Megapress.dbo.vRegistry r with(nolock, noexpand) on r.REGID = a.regid and r.FLAG = 0


 -- заполнение таблицы поставщиков
 insert into #tmpSuppliers(actionId, productId, cnt)
 select a.actionId, a.productId, count(*) cnt 
 from #tmpActions a with(nolock)
 join Miracle.dbo.ConstellationSuppliersActionProduct csap with(nolock, forceseek, index = Ind1)
 on csap.actionId = a.actionId and csap.productId = a.productId and csap.[disable] = '0'
 group by a.actionId,a.productId


-- заполнение таблицы первого уровня вложенности
 insert into #lvl1(nomenclature_id, product_id, nomenclature_name, quantity, cip, qnt_ost, date_start, date_end, action_id,
 marketing_action_name, reg_id, cnt, is_attached)
 select
 v.nomenclatureId,
 v.productId,
 v.nomenclatureName,
 v.quantity,
 ISNULL(v.cip, 0),
 ISNULL(v.uQntOst, 0),
 v.dateStart,
 v.dateEnd,
 v.actionId,
 v.marketingActionName,
 v.regId,
 ISNULL(v.cnt, 0),
 v.isAttached
   from (
   select
   a.nomenclatureId,
   a.productId,
   a.nomenclatureName,
   a.quantity,
   a.cip,
   max(a.uQntOst) [uQntOst],
   a.dateStart,
   a.dateEnd,
   a.actionId,
   a.marketingActionName,
   max(a.regId) [regId],
   max(s.cnt) [cnt],
   max(a.isAttached) [isAttached]
   from #tmpActions as a with(nolock)
   left join #tmpSuppliers s with(nolock) on s.actionId = a.actionId and s.productId = a.productId
   group by
   a.nomenclatureId,
   a.productId,
   a.nomenclatureName,
   a.quantity,
   a.cip,
   a.dateStart,
   a.dateEnd,
   a.actionId,
   a.marketingActionName
   ) v


  -- заполнение таблицы второго уровня вложенности
 insert into #lvl2(nomenclature_id, product_id, action_id, nomenclature_name, reg_id, t.qnt_ost, is_attached, drug_id)
 select
 v.nomenclatureId,
 v.productId,
 v.actionId,
 v.nomenclatureName,
 v.regId,
 ISNULL(v.uQntOst, 0),
 v.isAttached,
 ISNULL(vr.DRUGID, 0)
 from (
	select
	a.nomenclatureId,
	a.productId,
	a.actionId,
	a.nomenclatureName,
	max(a.uQntOst) [uQntOst],
	max(a.regId) [regId],
	max(a.isAttached) [isAttached]
	from #tmpActions as a with(nolock)
	group by a.nomenclatureId, a.productId, a.actionId, a.nomenclatureName
 ) v
   left join Megapress.dbo.vRegistry vr with(nolock) on vr.regId = v.regId

 
 -- заполнение таблицы третьего уровня вложенности
 insert into #lvl3(nomenclature_id, product_id, action_id, nomenclature_name, reg_id, fabr, qnt_ost, is_order, drug_id)
 select distinct
 a.nomenclatureId,
 a.productId,
 a.actionId,
 vr.tovname,
 a.regId,
 vr.fabr,
 ISNULL(a.uQntOst, 0),
 case when o.isOrder = '0' then '1' else '0' end [isOrder],
 ISNULL(vr.DRUGID, 0)
 from #tmpActions as a with(nolock)
 left join Megapress.dbo.vRegistry as vr with(nolock, noexpand) on vr.REGID = a.regId
 left join Miracle.dbo.ConstellationOrderRegIdInBranch o with(nolock)
 on o.nomenclatureId = a.nomenclatureId and o.productId = a.productId and o.actionId = a.actionId and o.regId = a.regId
 where a.regId > 0


  -- заполнение таблицы общих остататков по Созвездию
 insert into #tmpTotalOst(productId, nomenclatureId, totalOst)
 select
 lvl3.product_id,
 lvl3.nomenclature_id,
 sum(t.uQntOst)
 from #lvl3 lvl3 with(nolock)
 left join #tmpOst t with(nolock)
 on t.regId = lvl3.reg_id 
 group by lvl3.product_id, lvl3.nomenclature_id
 option(optimize for unknown)

 
 -- обновление поля "общий остаток" на первом уровне
 update #lvl1
 set total_ost = ISNULL(t.totalOst, 0)
 from #lvl1 lvl1
 left join #tmpTotalOst t on t.productId = lvl1.product_id and t.nomenclatureId = lvl1.nomenclature_id


 -- обновление поля "общий остаток" на втором уровне
 update #lvl2
 set total_ost = ISNULL(t.totalOst, 0)
 from #lvl2 lvl2
 left join #tmpTotalOst t on t.productId = lvl2.product_id and t.nomenclatureId = lvl2.nomenclature_id


-- Выходной массив с иерархической структурой
 select
  lvl1.nomenclature_id,
  lvl1.product_id,
  lvl1.nomenclature_name,
  lvl1.quantity,
  lvl1.qnt_ost,
  lvl1.date_start,
  lvl1.date_end,
  lvl1.action_id,
  lvl1.marketing_action_name,
  lvl1.cnt,
  lvl1.is_attached,
  lvl1.cip,
  lvl1.total_ost,
  (select
  lvl2.nomenclature_id,
    lvl2.product_id,
    lvl2.nomenclature_name,
    lvl2.qnt_ost,
	lvl2.action_id,
	lvl2.is_attached,
	lvl2.total_ost,
    (select
	lvl3.nomenclature_id,
	lvl3.product_id,
	lvl3.action_id,
	lvl3.nomenclature_name,
	lvl3.reg_id,
	lvl3.fabr,
	lvl3.qnt_ost,
	lvl3.is_order
    from #lvl3 lvl3 with(nolock)
	-- условие связи второго и третьего уровня (если в него добавить сравнение по drug_id, то в 3 уровне исчезнут "товары не в тему")
 where lvl2.product_id = lvl3.product_id and lvl2.action_id = lvl3.action_id and lvl2.nomenclature_id = lvl3.nomenclature_id -- and lvl2.drug_id = lvl3.drug_id
   for json auto ) as data
   from #lvl2 lvl2 with(nolock)
   -- условие связи первого и второго уровня
 where lvl2.product_id = lvl1.product_id and lvl2.action_id = lvl1.action_id and lvl2.nomenclature_id = lvl1.nomenclature_id and lvl2.reg_id = lvl1.reg_id
   for json auto) as data
 from #lvl1 lvl1 with(nolock)
 for json auto
 
 -- заполнение переменных количеством строк (товаров) на каждом уровне и непривязанных товаров
 SET @countOfRowsFromFirstLevel = (SELECT COUNT(*) FROM #lvl1)
 SET @countOfRowsFromSecondLevel = (SELECT COUNT(*) FROM #lvl2)
 SET @countOfRowsFromThirdLevel = (SELECT COUNT(*) FROM #lvl3)
 SET @countIsUnattached = (SELECT COUNT(*) FROM #lvl2 where reg_id = 0)

 -- заполнение таблицы счетчиков строк
 insert into #amountOfRowsInLevels(first_level, second_level, third_level, is_unattached)
 SELECT @countOfRowsFromFirstLevel, @countOfRowsFromSecondLevel, @countOfRowsFromThirdLevel, @countIsUnattached

 -- вывод таблицы счетчиков количества строк, используется в верхнем тулбаре
 select first_level, second_level, third_level, is_unattached from #amountOfRowsInLevels with(nolock)
 for json auto

 drop table #tmpActions
 drop table #tmpSuppliers
 drop table #tmpOst
 drop table #lvl1
 drop table #lvl2
 drop table #lvl3
 drop table #amountOfRowsInLevels
 drop table #tmpTotalOst
 END


GO
/****** Object:  StoredProcedure [dbo].[KW_231_2_v1]    Script Date: 28.10.2022 16:10:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author: Самощенко Владислав
-- Create date: 16.10.2022
-- Description:	"Заказ"/"Отмена заказа" товара
-- =============================================
ALTER PROCEDURE [dbo].[KW_231_2_v1]
 @personID int,
 @json nvarchar(max)
AS
BEGIN

 set nocount on;
 declare
  @regId int = json_value(@json, '$.reg_id'),
  @branchId int = json_value(@json, '$.branch_id'),
  @actionId int = json_value(@json, '$.action_id'),
  @productId int = json_value(@json, '$.product_id'),
  @nomenclatureId int = json_value(@json, '$.nomenclature_id'),
  @isOrder char(1) = json_value(@json, '$.is_order'),
  @id int

 select @id = co.constellationOrderRegIdInBranchID
 from Miracle.dbo.ConstellationOrderRegIdInBranch co with(nolock)
 where branchId = @branchId
 and regid = @regId
 and actionId = @actionId
 and productId = @productId
 and nomenclatureId = @nomenclatureId
 option(optimize for unknown)

 if ISNULL(@id, 0) > 0
  begin
   update Miracle.dbo.ConstellationOrderRegIdInBranch set
    isOrder = case when @isOrder = '0' then '1' else '0' end
   where branchId = @branchId
    and regid = @regId
	and actionId = @actionId
	and productId = @productId
	and nomenclatureId = @nomenclatureId
    and isOrder != case when @isOrder = '0' then '1' else '0' end
   option(optimize for unknown)
  end
 else
  begin
   insert into Miracle.dbo.ConstellationOrderRegIdInBranch(branchId, actionId, productId, nomenclatureId, regId, isOrder)
   select @branchId, @actionId, @productId, @nomenclatureId, @regId, case when @isOrder = '1' then '0' else '1' end
   set @id = SCOPE_IDENTITY()
  end
END