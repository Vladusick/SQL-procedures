USE [Miracle]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Самощенко Владислав
-- Create date: 06.12.2022
-- Description:	Процедура получения данных для печатной формы "Сборочный лист"
-- =============================================
CREATE PROCEDURE [dbo].[KW_434_8_v1]
	@personId int,
	@json nvarchar(max)
AS
BEGIN
	set nocount on;
	declare
	    @naklTitleId int = cast(json_value(@json, '$.doc_number') as int),
		@naklTitleRId int = cast(json_value(@json, '$.doc_number_r') as int)

	-- Собираем данные для ПРИХОДНОГО документа
	if @NaklTitleID is not null 
	begin

		-- Получаем номер расходного документа, т.к. изначально пришел приходный документ
		select @naklTitleRId = ddt.NaklTitleRID
		from Miracle.dbo.DoubleDocTitle ddt with(nolock)
		where ddt.NaklTitleID = @naklTitleId

		-- Получение заголовков документа
		select
		@naklTitleRId as doc_title_r_id,      -- Идентификатор расходного документа
		@naklTitleId as doc_title_id,         -- Идентификатор приходного документа
		ntr.BranchID as branch_sender_id,     -- Идентификатор филиала отправителя
		cfs.CustomerFill as branch_sender,    -- Филиала отправителя
		cs.Customer as sender,                -- Имя отправителя
		nt.NaklTitleID as doc_number,         -- Номер документа
		nt.DocDate as doc_date,               -- Дата документа
		nt.BranchID as branch_recipient_id,	  -- Идентификатор филиала получателя
		cfr.CustomerFill as branch_recipient, -- Филиал получателя
		cr.CustomerID as recipient_id,		  -- Идентификатор получателя
		cr.Customer as recipient,             -- Имя получателя
		cfr.Adress as adress                  -- Адрес получателя
		from Miracle.dbo.NaklTitle nt with(nolock)
		left join Miracle.dbo.NaklTitleR ntr with(nolock) on ntr.NaklTitleRID = @naklTitleRId -- эта строчка чтоб приджоинить получателя
		left join Miracle.dbo.CustomerFill cfs with(nolock) on cfs.CustomerFillID = ntr.BranchID
		left join Miracle.dbo.Customer cs with(nolock) on cs.CustomerID = cfs.CustomerID
		left join Miracle.dbo.CustomerFill cfr with(nolock) on cfr.CustomerFillID = nt.BranchID
		left join Miracle.dbo.Customer cr with(nolock) on cr.CustomerID = cfr.CustomerID
		where nt.NaklTitleID = @naklTitleId

		-- Получение данных документа
		select
		ndr.NaklDataID as nakl_data_id,                                -- Идентификатор данных документа
		ISNULL(nd.Seria, '') as seria,                                 -- Серия
		vr.TovName as tovname,                                         -- Имя товара
		vr.Fabr as fabr,                                               -- Производитель
		vr.Form as form,                                               -- Форма
		ndr.UQuantity as qnt,                                          -- Количество
		ISNULL(d.[NAME], '') as mnn,                                   -- МНН
		nd.PriceOptNoNDS as price_opt_no_nds,                          -- Оптовая цена без НДС
		Round(nd.PriceOptNoNDS * ndr.UQuantity, 2) as sum_opt_no_nds,  -- Сумма оптовая без НДС
		nd.PriceOptWNDS as price_opt_w_nds,                            -- Оптовая цена с НДС
		Round(nd.PriceOptWNDS * ndr.UQuantity, 2) as sum_opt_w_nds,    -- Сумма оптовая с НДС
     	max(tsp.additionalSavePlace) as save_place                     -- Место хранения
		from Miracle.dbo.NaklTitleR ntr with(nolock)
		left join Miracle.dbo.NaklDataR ndr with(nolock) on ndr.NaklTitleRID = ntr.NaklTitleRID
		left join Miracle.dbo.NaklData nd with(nolock) on nd.NaklDataID = ndr.NaklDataID
		left join Megapress.dbo.vRegistry vr with(nolock) on vr.REGID = nd.RegID
		left join Miracle.dbo.NaklData rnd with(nolock) on rnd.ParentNaklDataID = nd.NaklDataID and rnd.[Disable] = '0' and rnd.MNN is not null
		left join Megapress.dbo.DRUG d with(nolock) on d.DRUGID = rnd.MNN
		left join Miracle.dbo.TovInSavePlace tsp with(nolock) on tsp.RegID = vr.REGID
		where ntr.NaklTitleRID = @naklTitleRId and ndr.[Disable] = '0'
		group by ndr.NaklDataID, nd.Seria, vr.TovName, vr.Fabr,	vr.Form, ndr.UQuantity, d.[NAME], nd.PriceOptNoNDS, nd.PriceOptWNDS

	end
		
	-- Собираем данные для РАСХОДНОГО документа
	else if @NaklTitleRID is not null
	begin

		-- Получаем номер приходного документа, т.к. пришел расходный документ
		select @naklTitleId = ddt.NaklTitleID
		from Miracle.dbo.DoubleDocTitle ddt with(nolock)
		where ddt.NaklTitleRID = @naklTitleRId

		-- Получение заголовков документа
		select
		@naklTitleRId as doc_title_r_id,      -- Идентификатор расходного документа
		@naklTitleId as doc_title_id,         -- Идентификатор приходного документа
		ntr.BranchID as branch_sender_id,	  -- Идентификатор филиала отправителя
		cfs.CustomerFill as branch_sender,    -- Филиала отправителя
		cs.Customer as sender,				  -- Имя отправителя
		ntr.NaklTitleRID as doc_number,       -- Номер документа
		ntr.DocDate as doc_date,			  -- Дата документа
		nt.BranchID as branch_recipient_id,   -- Идентификатор филиала получателя
		cfr.CustomerFill as branch_recipient, -- Филиал получателя
		cr.CustomerID as recipient_id,        -- Идентификатор получателя
		cr.Customer as recipient,			  -- Имя получателя
		cfr.Adress as adress				  -- Адрес получателя
		from Miracle.dbo.NaklTitleR ntr with(nolock)
		left join Miracle.dbo.NaklTitle nt with(nolock) on nt.NaklTitleID = @naklTitleId -- эта строчка чтоб приджоинить получателя
		left join Miracle.dbo.CustomerFill cfs with(nolock) on cfs.CustomerFillID = ntr.BranchID
		left join Miracle.dbo.Customer cs with(nolock) on cs.CustomerID = cfs.CustomerID
		left join Miracle.dbo.CustomerFill cfr with(nolock) on cfr.CustomerFillID = nt.BranchID
		left join Miracle.dbo.Customer cr with(nolock) on cr.CustomerID = cfr.CustomerID
		where ntr.NaklTitleRID = @naklTitleRId

		-- Получение данных документа
		select
		ndr.NaklDataID as nakl_data_id,                                -- Идентификатор данных документа
		ISNULL(nd.Seria, '') as seria,                                 -- Серия
		vr.TovName as tovname,                                         -- Имя товара
		vr.Fabr as fabr,                                               -- Производитель
		vr.Form as form,                                               -- Форма
		ndr.UQuantity as qnt,                                          -- Количество
		ISNULL(d.[NAME], '') as mnn,                                   -- МНН
		nd.PriceOptNoNDS as price_opt_no_nds,                          -- Оптовая цена без НДС
		Round(nd.PriceOptNoNDS * ndr.UQuantity, 2) as sum_opt_no_nds,  -- Сумма оптовая без НДС
		nd.PriceOptWNDS as price_opt_w_nds,                            -- Оптовая цена с НДС
		Round(nd.PriceOptWNDS * ndr.UQuantity, 2) as sum_opt_w_nds,    -- Сумма оптовая с НДС
     	max(tsp.additionalSavePlace) as save_place                     -- Место хранения
		from Miracle.dbo.NaklTitleR ntr with(nolock)
		left join Miracle.dbo.NaklDataR ndr with(nolock) on ndr.NaklTitleRID = ntr.NaklTitleRID
		left join Miracle.dbo.NaklData nd with(nolock) on nd.NaklDataID = ndr.NaklDataID
		left join Megapress.dbo.vRegistry vr with(nolock) on vr.REGID = nd.RegID
		left join Miracle.dbo.NaklData rnd with(nolock) on rnd.ParentNaklDataID = nd.NaklDataID and rnd.[Disable] = '0' and rnd.MNN is not null
		left join Megapress.dbo.DRUG d with(nolock) on d.DRUGID = rnd.MNN
		left join Miracle.dbo.TovInSavePlace tsp with(nolock) on tsp.RegID = vr.REGID
		where ntr.NaklTitleRID = @naklTitleRId and ndr.[Disable] = '0'
		group by ndr.NaklDataID, nd.Seria, vr.TovName, vr.Fabr,	vr.Form, ndr.UQuantity, d.[NAME], nd.PriceOptNoNDS, nd.PriceOptWNDS

	end
		
END