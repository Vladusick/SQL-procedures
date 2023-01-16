USE [Miracle]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		��������� ���������
-- Create date: 06.12.2022
-- Description:	��������� ��������� ������ ��� �������� ����� "��������� ����"
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

	-- �������� ������ ��� ���������� ���������
	if @NaklTitleID is not null 
	begin

		-- �������� ����� ���������� ���������, �.�. ���������� ������ ��������� ��������
		select @naklTitleRId = ddt.NaklTitleRID
		from Miracle.dbo.DoubleDocTitle ddt with(nolock)
		where ddt.NaklTitleID = @naklTitleId

		-- ��������� ���������� ���������
		select
		@naklTitleRId as doc_title_r_id,      -- ������������� ���������� ���������
		@naklTitleId as doc_title_id,         -- ������������� ���������� ���������
		ntr.BranchID as branch_sender_id,     -- ������������� ������� �����������
		cfs.CustomerFill as branch_sender,    -- ������� �����������
		cs.Customer as sender,                -- ��� �����������
		nt.NaklTitleID as doc_number,         -- ����� ���������
		nt.DocDate as doc_date,               -- ���� ���������
		nt.BranchID as branch_recipient_id,	  -- ������������� ������� ����������
		cfr.CustomerFill as branch_recipient, -- ������ ����������
		cr.CustomerID as recipient_id,		  -- ������������� ����������
		cr.Customer as recipient,             -- ��� ����������
		cfr.Adress as adress                  -- ����� ����������
		from Miracle.dbo.NaklTitle nt with(nolock)
		left join Miracle.dbo.NaklTitleR ntr with(nolock) on ntr.NaklTitleRID = @naklTitleRId -- ��� ������� ���� ����������� ����������
		left join Miracle.dbo.CustomerFill cfs with(nolock) on cfs.CustomerFillID = ntr.BranchID
		left join Miracle.dbo.Customer cs with(nolock) on cs.CustomerID = cfs.CustomerID
		left join Miracle.dbo.CustomerFill cfr with(nolock) on cfr.CustomerFillID = nt.BranchID
		left join Miracle.dbo.Customer cr with(nolock) on cr.CustomerID = cfr.CustomerID
		where nt.NaklTitleID = @naklTitleId

		-- ��������� ������ ���������
		select
		ndr.NaklDataID as nakl_data_id,                                -- ������������� ������ ���������
		ISNULL(nd.Seria, '') as seria,                                 -- �����
		vr.TovName as tovname,                                         -- ��� ������
		vr.Fabr as fabr,                                               -- �������������
		vr.Form as form,                                               -- �����
		ndr.UQuantity as qnt,                                          -- ����������
		ISNULL(d.[NAME], '') as mnn,                                   -- ���
		nd.PriceOptNoNDS as price_opt_no_nds,                          -- ������� ���� ��� ���
		Round(nd.PriceOptNoNDS * ndr.UQuantity, 2) as sum_opt_no_nds,  -- ����� ������� ��� ���
		nd.PriceOptWNDS as price_opt_w_nds,                            -- ������� ���� � ���
		Round(nd.PriceOptWNDS * ndr.UQuantity, 2) as sum_opt_w_nds,    -- ����� ������� � ���
     	max(tsp.additionalSavePlace) as save_place                     -- ����� ��������
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
		
	-- �������� ������ ��� ���������� ���������
	else if @NaklTitleRID is not null
	begin

		-- �������� ����� ���������� ���������, �.�. ������ ��������� ��������
		select @naklTitleId = ddt.NaklTitleID
		from Miracle.dbo.DoubleDocTitle ddt with(nolock)
		where ddt.NaklTitleRID = @naklTitleRId

		-- ��������� ���������� ���������
		select
		@naklTitleRId as doc_title_r_id,      -- ������������� ���������� ���������
		@naklTitleId as doc_title_id,         -- ������������� ���������� ���������
		ntr.BranchID as branch_sender_id,	  -- ������������� ������� �����������
		cfs.CustomerFill as branch_sender,    -- ������� �����������
		cs.Customer as sender,				  -- ��� �����������
		ntr.NaklTitleRID as doc_number,       -- ����� ���������
		ntr.DocDate as doc_date,			  -- ���� ���������
		nt.BranchID as branch_recipient_id,   -- ������������� ������� ����������
		cfr.CustomerFill as branch_recipient, -- ������ ����������
		cr.CustomerID as recipient_id,        -- ������������� ����������
		cr.Customer as recipient,			  -- ��� ����������
		cfr.Adress as adress				  -- ����� ����������
		from Miracle.dbo.NaklTitleR ntr with(nolock)
		left join Miracle.dbo.NaklTitle nt with(nolock) on nt.NaklTitleID = @naklTitleId -- ��� ������� ���� ����������� ����������
		left join Miracle.dbo.CustomerFill cfs with(nolock) on cfs.CustomerFillID = ntr.BranchID
		left join Miracle.dbo.Customer cs with(nolock) on cs.CustomerID = cfs.CustomerID
		left join Miracle.dbo.CustomerFill cfr with(nolock) on cfr.CustomerFillID = nt.BranchID
		left join Miracle.dbo.Customer cr with(nolock) on cr.CustomerID = cfr.CustomerID
		where ntr.NaklTitleRID = @naklTitleRId

		-- ��������� ������ ���������
		select
		ndr.NaklDataID as nakl_data_id,                                -- ������������� ������ ���������
		ISNULL(nd.Seria, '') as seria,                                 -- �����
		vr.TovName as tovname,                                         -- ��� ������
		vr.Fabr as fabr,                                               -- �������������
		vr.Form as form,                                               -- �����
		ndr.UQuantity as qnt,                                          -- ����������
		ISNULL(d.[NAME], '') as mnn,                                   -- ���
		nd.PriceOptNoNDS as price_opt_no_nds,                          -- ������� ���� ��� ���
		Round(nd.PriceOptNoNDS * ndr.UQuantity, 2) as sum_opt_no_nds,  -- ����� ������� ��� ���
		nd.PriceOptWNDS as price_opt_w_nds,                            -- ������� ���� � ���
		Round(nd.PriceOptWNDS * ndr.UQuantity, 2) as sum_opt_w_nds,    -- ����� ������� � ���
     	max(tsp.additionalSavePlace) as save_place                     -- ����� ��������
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