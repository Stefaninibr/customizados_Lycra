CREATE OR REPLACE PACKAGE BODY MSAF_EXP_EASY_CPROC IS

  mcod_estab   estabelecimento.cod_estab%TYPE;
  mcod_empresa empresa.cod_empresa%TYPE;
  musuario     usuario_estab.cod_usuario%TYPE;

  FUNCTION Parametros RETURN VARCHAR2 IS
    pstr VARCHAR2(5000);
  BEGIN

    mcod_empresa := LIB_PARAMETROS.RECUPERAR('EMPRESA');
    mcod_estab   := NVL(LIB_PARAMETROS.RECUPERAR('ESTABELECIMENTO'), '');
    musuario     := LIB_PARAMETROS.Recuperar('USUARIO');

    LIB_PROC.add_param(pstr,
                       'Empresa',
                       'Varchar2',
                       'Combobox',
                       'S',
                       NULL,
                       NULL,
                       'SELECT DISTINCT emp.cod_empresa, emp.cod_empresa||'' - ''||emp.razao_social
                       FROM empresa emp
                       ORDER BY 2');

    LIB_PROC.add_param(pstr,
                       'Estabelecimento ',
                       'Varchar2',
                       'Combobox',
                       'S',
                       NULL,
                       NULL,
                       'SELECT DISTINCT e.cod_estab, e.cod_estab||'' - ''||e.razao_social FROM estabelecimento e, ict_estab_iestad i WHERE e.cod_empresa = i.cod_empresa(+) AND e.cod_estab = i.cod_estab(+) AND e.cod_empresa = ''' ||
                       mcod_empresa || '''
                       ORDER BY 2');

    LIB_PROC.add_param(pstr,
                       'Data Inicial ',
                       'Date',
                       'Textbox',
                       'S',
                       NULL,
                       'dd/mm/yyyy');
                       
     LIB_PROC.add_param(pstr,
                       'Data Final ',
                       'Date',
                       'Textbox',
                       'S',
                       NULL,
                       'dd/mm/yyyy');                       

    lib_proc.add_param(pstr,
                       'Arquivos',
                       'Varchar2',
                       'Listbox',
                       'S',
                       NULL,
                       NULL,
                       '1=1 - Cliente e Fornecedor,'||
                       '2=2 - Produtos,'||
                       '3=3 - Entrada Mestre,'||
                       '4=4 - Entrada Itens,'||
                       '5=5 - Sa�da Mestre,'||
                       '6=6 - Sa�da Itens');
                       
                       
 lib_proc.add_param(pstr,
                       'Stefanini - IT Solutions - Procedimentos Customizados',
                       'Varchar2',
                       'TEXT',
                       'N');
                       
 lib_proc.add_param(pstr, 'Versao  : 1.0', 'Varchar2', 'TEXT', 'N');                                              
                        
    
    RETURN pstr;
  END;

  FUNCTION Nome RETURN VARCHAR2 IS
  BEGIN
    RETURN 'Exporta��o - Transfer Pricing';
  END;

  FUNCTION Tipo RETURN VARCHAR2 IS
  BEGIN
    RETURN 'EXP - EASY';
  END;

  FUNCTION Versao RETURN VARCHAR2 IS
  BEGIN
    RETURN 'Vers�o 1';
  END;

  FUNCTION Descricao RETURN VARCHAR2 IS
  BEGIN
    RETURN 'EXP - EASY';
  END;

  FUNCTION Modulo RETURN VARCHAR2 IS
  BEGIN
    RETURN 'Processos Customizados';
  END;

  FUNCTION Classificacao RETURN VARCHAR2 IS
  BEGIN
    RETURN 'Processos Customizados';
  END;

  function executar(p_empresa varchar2,
                    p_estab   varchar2,
                    p_dataini date,
                    p_datafin date,
                    p_arquivo varchar2) return integer is

    /* Variaveis de Trabalho */

    mproc_id     INTEGER;
    mLinhaC      VARCHAR2(4000);
    v_registro   number := 0;
    --v_fimLinha   varchar2(2000) := chr(13) || chr(10);


   --Inicio do cursor de cliente e fornecedor
    CURSOR c_clifor IS

    select DISTINCT x04.COD_FIS_JUR COD_CLIENTE_FORNECEDOR,
           SUBSTR(x04.RAZAO_SOCIAL,1,60) NOME_CLIENTE_FORNECEDOR,
           rtrim(ltrim(x04.COD_PAIS)) SIGLA_PAIS,
           nvl(x04.CPF_CGC,0) CNPJ,
           (CASE
             WHEN TRIM(UPPER(SUBSTR(x04.RAZAO_SOCIAL,1,60))) LIKE 'INVISTA%' THEN --INVISTA
              'W'
             ELSE
              'O'
           END) tipo_relacionamento,
         '000000000' TAXA_JUROS_PROPRIA,
           TO_CHAR(x04.VALID_FIS_JUR,'ddmmyyyy')  DATA_INCLUSAO_SISTEMA_ORIGEM,
          TO_CHAR(x04.VALID_FIS_JUR,'ddmmyyyy')  DATA_ALTERACAO_SISTEMA_ORIGEM
      from x04_pessoa_fis_jur x04 ;

    CURSOR c_produto is
    
    SELECT DISTINCT substr(X2013.COD_PRODUTO,1,30) CODIGO_PRODUTO,
                x2013.descricao DESCRICAO_PRODUTO,
                x2007.cod_medida SIGLA_UNIDADE,
                null CODIGO_FAMILIA_PRODUTO,
                substr(X2045.COD_NCM,1,8) CODIGO_NCM,
                '0' ALIQUOTA_DIREFERENTE_PIS,
                '0' ALIQUOTA_DIREFERENTE_COFINS,
                null PERCENTUAL_FIXO_COMISSAO_VENDA,
                null DESCRICAO_DIPJ,
                null ALIQUOTA_IMPOSTO_IMPORTACAO,
                null PERCENTUAL_ESTI_OUTRA_DES,
                null DATA_INCLUSAO_SISTEMA_ORIGEM,
                null DATA_ATUALIZACAO_SIS_ORI
FROM X2013_PRODUTO X2013
,x2007_medida x2007
,X2045_COD_NCM X2045
where X2013.IDENT_NCM = X2045.IDENT_NCM(+)
and x2013.ident_medida = x2007.ident_medida;

cursor c_ent is
select DISTINCT X07.COD_EMPRESA EMPRESA,
       X07.COD_ESTAB FILIAL,
       X04.COD_FIS_JUR FORNECEDOR,
       substr(to_char(nvl(trunc(x07.num_docfis),'0')),1,6) NUMERO_NOTA,
       substr(nvl(x07.serie_docfis,'0'),1,2) SERIE,
       substr(nvl(x07.sub_serie_docfis,'0'),1,3) SUB_SERIE ,
       to_char(x07.data_fiscal, 'ddmmyyyy')DT_ENTRADA,
       replace(substr(to_char(nvl(X07.VLR_TOT_NOTA,'0')),1,17),'.',',') VLR_NOTA,
       nvl(X07.NORM_DEV,'0') TIPO_NF,
       nvl(x07.num_controle_docto,'0') NR_CONTROLE,
       nvl(x07.num_docfis,'0') NUMERO_CONT_DOC_ORIGINAL,
       nvl(x49.num_di,0) NUM_DI,
       to_char(x49.Dat_Di, 'ddmmyyyy') DATA_DI,
       null DIAS_VENCIMENTO,
       '000' COND_PAGTO,
       replace(substr(to_char(nvl(x07.vlr_frete,'0')),1,17),'.',',') VLR_FRETE,
       replace(substr(to_char(nvl(trib.Vlr_Tributo,'0')),1,17),'.',',') VLR_ICMS,
       replace(substr(to_char(nvl(trib2.Vlr_Tributo,'0')),1,17),'.',',') VLR_IPI,
       replace(substr(to_char(nvl(X07.VLR_DESCONTO,'0')),1,17),'.',',') VLR_DESCONTO,
       replace(substr(to_char(nvl(X49.VLR_FRETE,'0')),1,17),'.',',') VLR_FRETE_IMPORTACAO,
       0 VLR_SEGURO_IMPORTACAO,
       null VALOR_ROYALTLES_IMPORTACAO,
       replace(substr(to_char( NVL(x49.vlr_liq_merc,'0')),1,17),'.',',') VALOR_TOTAL_MOEDA,
       null SIGLA_MOEDA,
       to_char(X07.DATA_SAIDA_REC,'ddmmyyyy')  DATA_INCLUSAO_SIS_ORI,
       null COD_ORIGEM, 
       NVL(X2012.COD_CFO,'0') CFOP
  from x07_docto_fiscal X07
  join X04_PESSOA_FIS_JUR X04 on (X04.IDENT_FIS_JUR = X07.IDENT_FIS_JUR)
  left join x2012_cod_fiscal x2012 on (x2012.ident_cfo = x07.ident_cfo)
  left join x49_oper_imp x49 on ( x49.cod_empresa   = x07.cod_empresa   and
                                       x49.cod_estab     = x07.cod_estab     and
                                       x07.ident_fis_jur = x04.ident_fis_jur and
                                       x07.num_docfis    = x49.num_nf        and
                                       x49.num_item = '1' )
  left join x07_trib_docfis trib on (trib.COD_EMPRESA = x07.cod_empresa and
                                   trib.COD_ESTAB = x07.cod_estab and
                                    trib.IDENT_FIS_JUR = x07.ident_fis_jur and
                                    trib.NUM_DOCFIS = x07.num_docfis and
                                    trib.cod_tributo = 'ICMS')
  left join x07_trib_docfis trib2 on (trib2.COD_EMPRESA = x07.cod_empresa and
                                     trib2.COD_ESTAB = x07.cod_estab and
                                     trib2.IDENT_FIS_JUR = x07.ident_fis_jur and
                                     trib2.NUM_DOCFIS = x07.num_docfis and
                                     trib2.cod_tributo = 'IPI')
      where x07.num_docfis is not null and
      x07.movto_e_s <> 9  and
      x07.cod_empresa = p_empresa and
      x07.cod_estab = p_estab and
      x07.data_fiscal between p_dataini and p_datafin and
      x07.situacao = 'N' and
      x07.COD_CLASS_DOC_FIS = '1';

cursor c_enti is
SELECT x08.cod_empresa EMPRESA,
       x08.cod_estab FILIAL,
       x04.cod_fis_jur CODIGO_FORNECEDOR,
       substr(to_char(nvl(trunc(x08.num_docfis),'0')),1,6) NUMERO_NOTA_FISCAL_ENTRADA,
       substr(to_char(nvl(x08.Serie_Docfis,'0')),1,2) SERIE_NOTA_ENTRADA,
       substr(to_char(nvl(X08.Sub_Serie_Docfis,'0')),1,3) SUB_SERIE_NOTA_ENTRADA,
       nvl(X2012.COD_CFO,'0') CFOP,
       nvl(x2013.cod_produto,'0') CODIGO_PRODUTO,
       replace(nvl(x2007.cod_medida,'0'),'.','') SIGLA_UNIDADE,
       replace(substr(to_char(nvl(X08.Quantidade,'0')),1,18),'.',',') QUANTIDADE,
       replace(substr(to_char(nvl(x08.Vlr_Item,'0')),1,17),'.',',') PRECO_TOTAL,
       replace(substr(to_char(nvl(X08.Vlr_Frete,'0')),1,17),'.',',') VALOR_FRETE,
       replace(substr(to_char(nvl(x08t.Vlr_Tributo,'0')),1,17),'.',',') VALOR_ICMS,
       replace(substr(to_char(nvl(x08t22.vlr_tributo,'0')),1,17),'.',',') VALOR_IPI,
       replace(substr(to_char(nvl(x08.vlr_pis,'0')),1,17),'.',',') VALOR_PIS_NAO_CUMULATIVO,
       replace(substr(to_char(nvl(x08.vlr_cofins,'0')),1,17),'.',',') VALOR_COFINS_NAO_CUMULATIVO,
       replace(substr(to_char(nvl(x08.vlr_desconto,'0')),1,17),'.',',') VALOR_DESCONTO,
       replace(substr(to_char(nvl(X49.vlr_ii,'0')),1,17),'.',',') VALOR_IMPOSTO_IMPORT,
       replace(substr(to_char(nvl(X49.vlr_frete,'0')),1,17),'.',',') VALOR_FRETE_IMPOR,
       replace(substr(to_char(nvl(X49.vlr_seguro,'0')),1,17),'.',',') VALOR_SEGURO_IMPORT,
	   0 VALOR_ROYALTIES_IMPORT,
       replace(substr(to_char(nvl(X49.vlr_desp_acresc,'0')),1,17),'.',',') VALOR_OUT_DESP_IMPORT,
	   0 VALOR_ICMS_ST,
	   0 VALOR_IPI_ST,
       replace(substr(to_char(nvl(X49.vlr_merc_dolar,'0')),1,17),'.',',') VLR_TOTAL_MOEDA_ESTRANG,
     DECODE(SUBSTR(x2012.COD_CFO,1,1),'3','N','S') ICMS_INCLUSO_ITEM,
	   'N' IPI_INCLUSO_ITEM,  
     --0 PIS_INCLUSO_ITEM, --- VERIFICAR REGRA
     DECODE(SUBSTR(x2012.COD_CFO,1,1),'3','N','S') PIS_INCLUSO_ITEM,   -- se inicial CFO = 3  ---> 'N'
     --  0 COFINS_INCLUSO_ITEM,--- VERIFICAR REGRA
     DECODE(SUBSTR(x2012.COD_CFO,1,1),'3','N','S') COFINS_INCLUSO_ITEM,   -- se inicial CFO = 3  ---> 'N'
     null CODIGO_ORIGEM, --VER REGRA
     TO_CHAR(X08.DATA_FISCAL,'ddmmyyyy') DATA_FISCAL
  FROM X08_ITENS_MERC X08
  left  JOIN X2012_COD_FISCAL X2012  ON (X2012.IDENT_CFO        = X08.IDENT_CFO)
  left  join x04_pessoa_fis_jur x04  on (x04.ident_fis_jur      = x08.ident_fis_jur)
  left  join X2006_NATUREZA_OP X2006 ON X2006.IDENT_NATUREZA_OP = X08.IDENT_NATUREZA_OP
  join x2013_produto x2013     on x2013.ident_produto = x08.ident_produto
  left join x2007_medida x2007 on x2007.ident_medida = x2013.ident_medida
  left join x49_oper_imp x49   on (x49.cod_empresa   = x08.cod_empresa and
                                        x49.cod_estab     = x08.cod_estab         and
                                        x08.ident_fis_jur = x04.ident_fis_jur and
                                        x08.num_docfis    = x49.num_nf                    AND X49.NUM_item = X08.NUM_item )   ---   AQUI!!!
  LEFT JOIN X08_TRIB_MERC X08T ON X08T.COD_EMPRESA = X08.COD_EMPRESA
                              and X08T.COD_ESTAB   = X08.COD_ESTAB
                              and X08T.DATA_FISCAL = X08.DATA_FISCAL
                              and X08T.MOVTO_E_S   = X08.MOVTO_E_S
                              and X08T.NORM_DEV    = X08.NORM_DEV
                              and X08T.IDENT_DOCTO = X08.IDENT_DOCTO
                              and X08T.IDENT_FIS_JUR = X08.IDENT_FIS_JUR
                              and X08T.NUM_DOCFIS    = X08.NUM_DOCFIS
                              and X08T.SERIE_DOCFIS     = X08.SERIE_DOCFIS
                              and X08T.SUB_SERIE_DOCFIS =  X08.SUB_SERIE_DOCFIS
                              and X08T.DISCRI_ITEM      = X08.DISCRI_ITEM
                              and x08t.cod_tributo = 'ICMS'     
  LEFT JOIN X08_TRIB_MERC X08T22 ON (X08T22.COD_EMPRESA = X08.COD_EMPRESA
                                and X08T22.COD_ESTAB   = X08.COD_ESTAB
                                and X08T22.DATA_FISCAL = X08.DATA_FISCAL
                                and X08T22.MOVTO_E_S   = X08.MOVTO_E_S
                                and X08T22.NORM_DEV    = X08.NORM_DEV
                                and X08T22.IDENT_DOCTO = X08.IDENT_DOCTO
                                and X08T22.IDENT_FIS_JUR =   X08.IDENT_FIS_JUR
                                and X08T22.NUM_DOCFIS    = X08.NUM_DOCFIS
                                and X08T22.SERIE_DOCFIS  = X08.SERIE_DOCFIS
                                and X08T22.SUB_SERIE_DOCFIS = X08.SUB_SERIE_DOCFIS
                                and X08T22.DISCRI_ITEM      = X08.DISCRI_ITEM
                                and X08T22.cod_tributo = 'IPI'  )
---Somente NFs N�O canceladas
   JOIN X07_DOCTO_FISCAL X07 
                                ON (X07.COD_EMPRESA = X08.COD_EMPRESA
                                and X07.COD_ESTAB   = X08.COD_ESTAB
                                and X07.DATA_FISCAL = X08.DATA_FISCAL
                                and X07.MOVTO_E_S   = X08.MOVTO_E_S
                                and X07.NORM_DEV    = X08.NORM_DEV
                                and X07.IDENT_DOCTO = X08.IDENT_DOCTO
                                and X07.IDENT_FIS_JUR =   X08.IDENT_FIS_JUR
                                and X07.NUM_DOCFIS    = X08.NUM_DOCFIS
                                and X07.SERIE_DOCFIS  = X08.SERIE_DOCFIS
                                and X07.SUB_SERIE_DOCFIS = X08.SUB_SERIE_DOCFIS
                                and X07.SITUACAO     = 'N'    --- N�o canceladas
                                and x07.COD_CLASS_DOC_FIS = '1')  -- Somente mercadorias
                WHERE X08.MOVTO_E_S <> 9 
                AND   X08.DATA_FISCAL between p_dataini and p_datafin
                and   x08.cod_empresa = p_empresa
                and   x08.cod_estab = p_estab;
                
cursor c_saida is
select distinct X07.COD_EMPRESA EMPRESA,
       X07.COD_ESTAB FILIAL,
       X04.COD_FIS_JUR CLIENTE,
       substr(to_char(nvl(trunc(x07.num_docfis),'0')),1,6) NRO_NOTA_FISCAL,
       substr(to_char(NVL(x07.serie_docfis,'0')),1,2) SERIE,
       substr(to_char(NVL(x07.sub_serie_docfis,'0')),1,3) SUB_SERIE,
       to_char(x07.data_fiscal,'ddmmyyyy') DT_EMISSAO,
       replace(substr(to_char(nvl(X07.VLR_TOT_NOTA,'0')),1,17),'.',',') VALOR_TOTAL_NOTA,
       NVL(X07.NORM_DEV,'0') TIPO_NF,
       0 NR_CONTROLE,
       NVL(X07.num_docfis,'0') NUMERO_DOCUMENTO_ORI,
       'N' IND_SUBSTIT_TRIBUTARIA,
      '' NUM_DIAS_VENCIMENTO,
      '000B' CODIGO_COND_PAGAMENTO,
       replace(substr(to_char(NVL(trib.Vlr_Tributo,'0')),1,17),'.',',') VLR_TRIBUTO_ICMS,
       replace(substr(to_char(NVL(trib2.Vlr_Tributo,'0')),1,17),'.',',') VLR_TRIBUTO_IPI,
       0 VLR_TRIBUTO_ISS,
       0 VLR_DESCONTO,
       '0' VLR_FRETE_SEGURO,
       '' DT_EMBARQUE, --to_char(x49.dat_embarque,'ddmmyyyy') DT_EMBARQUE,
       to_char(x07.data_saida_rec,'ddmmyyyy') DATA_INCLUSAO_SISTEMA, -- to_char(x07.data_saida_rec,'ddmmyyyy') ,
       NVL(x2012.cod_cfo,'0') cod_cfo
  from x07_docto_fiscal X07
  JOIN X04_PESSOA_FIS_JUR X04 ON (X04.IDENT_FIS_JUR = X07.IDENT_FIS_JUR)
  left join x2012_cod_fiscal x2012 on (x2012.ident_cfo = x07.ident_cfo)
   left join x07_trib_docfis trib on (trib.COD_EMPRESA = x07.cod_empresa and
                                    trib.COD_ESTAB = x07.cod_estab and
                                    trib.IDENT_FIS_JUR = x07.ident_fis_jur and
                                    trib.NUM_DOCFIS = x07.num_docfis and
                                    trib.cod_tributo = 'ICMS')
  left join x07_trib_docfis trib2 on (trib2.COD_EMPRESA = x07.cod_empresa and
                                     trib2.COD_ESTAB = x07.cod_estab and
                                     trib2.IDENT_FIS_JUR =
                                     x07.ident_fis_jur and
                                     trib2.NUM_DOCFIS = x07.num_docfis and
                                     trib2.cod_tributo = 'IPI')
                                     
 left join X48_OPER_EXP x49 on (x49.cod_empresa = x07.cod_empresa and
                           x49.cod_estab = x07.cod_estab and
                           x07.ident_fis_jur = x04.ident_fis_jur and
                           x07.num_docfis = x49.num_nf)
where x07.movto_e_s = 9  
and   x07.data_fiscal between p_dataini and p_datafin
and   x07.cod_empresa = p_empresa
and   x07.cod_estab = p_estab
and   x07.situacao = 'N' 
and   x07.COD_CLASS_DOC_FIS = '1' ;

cursor c_saidai is
 SELECT x08.cod_empresa EMPRESA,
       x08.cod_estab FILIAL,
       substr(to_char(nvl(trunc(x08.num_docfis),'0')),1,6) NRO_NOTA,
       substr(to_char(NVL(x08.Serie_Docfis,'0')),1,2) SERIE_NOTA,
       substr(to_char(NVL(X08.Sub_Serie_Docfis,'0')),1,3) SUB_SERIE,
       NVL(X2012.COD_CFO,'0') CFOP,
       NVL(x2013.cod_produto,'0') CODIGO_MATERIAL,
       replace(NVL(x2007.cod_medida,'0'),'.','') UNID_MED,
       replace(substr(to_char(nvl(x08.Quantidade,'0')),1,18),'.',',') QUANTIDADE ,
       replace(substr(to_char(nvl(x08.Vlr_Item,'0')),1,17),'.',',') Preco_total,
       0 valor_frete_seguro,
       replace(substr(to_char(nvl(x08T.Vlr_Tributo,'0')),1,17),'.',',') valor_icms,
       replace(substr(to_char(nvl(X08T22.Vlr_Tributo,'0')),1,17),'.',',') valor_ipi,
       0 valor_iss,
       0 valor_desconto,
       0 valor_icms_ST,
       0 valo_ipi_ST,
       replace(substr(to_char(nvl(X49.VLR_DESP_COMIS,'0')),1,17),'.',',') valor_comissao,
       replace(substr(to_char(nvl(x08.vlr_pis,'0')),1,17),'.',',') valor_pis ,
       replace(substr(to_char(nvl(X08.VLR_COFINS,'0')),1,17),'.',',') valor_cofins,
       'S' icms_incluso_vlr_item,
       'N' ipi_incluso_vlr_item,
       to_char(X08.DATA_FISCAL,'ddmmyyyy')
  FROM X08_ITENS_MERC X08
   left JOIN X2012_COD_FISCAL X2012 ON (X2012.IDENT_CFO = X08.IDENT_CFO)
  join x04_pessoa_fis_jur x04 on (x04.ident_fis_jur = x08.ident_fis_jur)
  join X2006_NATUREZA_OP X2006 ON (X2006.IDENT_NATUREZA_OP =
                              X08.IDENT_NATUREZA_OP)
  join x2013_produto x2013 on (x2013.ident_produto = x08.ident_produto)
  join x2007_medida x2007 on (x2007.ident_medida = x2013.ident_medida)
  left join X48_OPER_EXP x49 on (x49.cod_empresa = x08.cod_empresa and
                           x49.cod_estab = x08.cod_estab and
                           x08.ident_fis_jur = x04.ident_fis_jur and
                           x08.num_docfis = x49.num_nf   and x08.num_item   = x49.num_item )
  LEFT JOIN X08_TRIB_MERC X08T ON (X08T.COD_EMPRESA = X08.COD_EMPRESA and
                                  X08T.COD_ESTAB = X08.COD_ESTAB and
                                  X08T.DATA_FISCAL = X08.DATA_FISCAL and
                                  X08T.MOVTO_E_S = X08.MOVTO_E_S and
                                  X08T.NORM_DEV = X08.NORM_DEV and
                                  X08T.IDENT_DOCTO = X08.IDENT_DOCTO and
                                  X08T.IDENT_FIS_JUR = X08.IDENT_FIS_JUR and
                                  X08T.NUM_DOCFIS = X08.NUM_DOCFIS and
                                  X08T.SERIE_DOCFIS = X08.SERIE_DOCFIS and
                                  X08T.SUB_SERIE_DOCFIS =
                                  X08.SUB_SERIE_DOCFIS and
                                  X08T.DISCRI_ITEM = X08.DISCRI_ITEM and
                                  x08t.cod_tributo = 'ICMS')
  LEFT JOIN X08_TRIB_MERC X08T22 ON (X08T22.COD_EMPRESA = X08.COD_EMPRESA and
                                    X08T22.COD_ESTAB = X08.COD_ESTAB and
                                    X08T22.DATA_FISCAL = X08.DATA_FISCAL and
                                    X08T22.MOVTO_E_S = X08.MOVTO_E_S and
                                    X08T22.NORM_DEV = X08.NORM_DEV and
                                    X08T22.IDENT_DOCTO = X08.IDENT_DOCTO and
                                    X08T22.IDENT_FIS_JUR =
                                    X08.IDENT_FIS_JUR and
                                    X08T22.NUM_DOCFIS = X08.NUM_DOCFIS and
                                    X08T22.SERIE_DOCFIS = X08.SERIE_DOCFIS and
                                    X08T22.SUB_SERIE_DOCFIS =
                                    X08.SUB_SERIE_DOCFIS and
                                    X08T22.DISCRI_ITEM = X08.DISCRI_ITEM and
                                    X08T22.cod_tributo = 'IPI')
---Somente NFs N�O canceladas
   JOIN X07_DOCTO_FISCAL X07 
                                ON (X07.COD_EMPRESA = X08.COD_EMPRESA
                                and X07.COD_ESTAB   = X08.COD_ESTAB
                                and X07.DATA_FISCAL = X08.DATA_FISCAL
                                and X07.MOVTO_E_S   = X08.MOVTO_E_S
                                and X07.NORM_DEV    = X08.NORM_DEV
                                and X07.IDENT_DOCTO = X08.IDENT_DOCTO
                                and X07.IDENT_FIS_JUR =   X08.IDENT_FIS_JUR
                                and X07.NUM_DOCFIS    = X08.NUM_DOCFIS
                                and X07.SERIE_DOCFIS  = X08.SERIE_DOCFIS
                                and X07.SUB_SERIE_DOCFIS = X08.SUB_SERIE_DOCFIS
                                and X07.SITUACAO     = 'N'    --- N�o canceladas
                                and x07.COD_CLASS_DOC_FIS = '1')  -- Somente mercadorias
									  WHERE X08.MOVTO_E_S = 9 
                    and   x08.data_fiscal between p_dataini and p_datafin
                    and   x08.cod_empresa = p_empresa
                    and   x08.cod_estab = p_estab;


    --inicia o processamento
begin
    -- cria processo
    mproc_id := lib_proc.new('MSAF_EXP_EASY_CPROC');
                      
    if p_arquivo = '1' then
    
     lib_proc.add_tipo(mproc_id,1,'CLIFOR_' || to_char(p_dataini, 'YYMM')||'.CSV',2);

      Lib_Proc.add('COD_FIS_JUR;RAZAO_SOCIAL;COD_PAIS;CPF_CGC;RAZAO_SOCIAL_1;VALID_FIS_JUR;',ptipo => 1);


 

     for mreg in c_clifor loop

      begin
        -- Cliente e Fornecedor
        mlinhaC := null;
        mlinhaC := lib_str.w(mlinhaC, nvl(mreg.cod_cliente_fornecedor,' ')||';',1); --campo 1-20
        mlinhaC := lib_str.w(mlinhaC, nvl(mreg.nome_cliente_fornecedor,' ')||';',22); --campo 2-60
        mlinhaC := lib_str.w(mlinhaC, nvl(mreg.sigla_pais,'999')||';',83); --campo 3-10
        mlinhaC := lib_str.w(mlinhaC, nvl(lpad(mreg.CNPJ,14,0),' ')||';',94); --campo 4-14
        mlinhaC := lib_str.w(mlinhaC, nvl(mreg.tipo_relacionamento,' ')||';', 109); --campo 5-1
        mlinhaC := lib_str.w(mlinhaC, nvl(mreg.taxa_juros_propria,' ')||';', 111); --campo 6-9
        mlinhaC := lib_str.w(mlinhaC, nvl(mreg.data_inclusao_sistema_origem,' ')||';', 121); --campo 7-8
        mlinhaC := lib_str.w(mlinhaC, nvl(mreg.data_alteracao_sistema_origem,' ')||';', 130); --campo 8-8

        lib_proc.add(mlinhaC);
        v_registro := v_registro + 1;
      end;
    end loop;
    LIB_PROC.add_log(v_registro ||
                     ' registro(s) gerado(s) para Cliente / Fornecedor ',
                     1);
                     
                

    elsif p_arquivo = '2' then
      
      lib_proc.add_tipo(mproc_id,1,'PRODUTO_' || to_char(p_dataini,'YYMM')||'.csv',2);

      Lib_Proc.add('COD_PRODUTO;DESCRICAO;COD_MEDIDA;COD_NCM;',ptipo => 1);

    for mregp in c_produto loop
      begin

        -- Produto
        mlinhaC := null;
        mlinhaC := lib_str.w(mlinhaC, nvl(mregp.codigo_produto,' ')||';',1); --campo 1-30
        mlinhaC := lib_str.w(mlinhaC, nvl(mregp.descricao_produto,' ')||';',31); --campo 2-60
        mlinhaC := lib_str.w(mlinhaC, nvl(mregp.sigla_unidade,' ')||';',92); --campo 3-04
        mlinhaC := lib_str.w(mlinhaC, nvl(mregp.codigo_familia_produto,' ')||';',97); --campo 4-16
        mlinhaC := lib_str.w(mlinhaC, nvl(mregp.codigo_ncm,' ')||';',114); --campo 5-8
        mlinhaC := lib_str.w(mlinhaC, nvl(mregp.aliquota_direferente_pis,' ')||';', 123); --campo 6-5
        mlinhaC := lib_str.w(mlinhaC, nvl(mregp.aliquota_direferente_cofins,' ')||';', 129); --campo 7-5
        mlinhaC := lib_str.w(mlinhaC, nvl(mregp.percentual_fixo_comissao_venda,' ')||';', 135); --campo 8-5
        mlinhaC := lib_str.w(mlinhaC, nvl(mregp.descricao_dipj,' ')||';', 141); --campo 9-60
        mlinhaC := lib_str.w(mlinhaC, nvl(mregp.aliquota_imposto_importacao,' ')||';', 202); --campo 10-5
        mlinhaC := lib_str.w(mlinhaC, nvl(mregp.percentual_esti_outra_des,' ')||';', 208); --campo 11-5
        mlinhaC := lib_str.w(mlinhaC, nvl(mregp.data_inclusao_sistema_origem,' ')||';', 214); --campo 12-8
        mlinhaC := lib_str.w(mlinhaC, nvl(mregp.data_atualizacao_sis_ori,' ')||';', 223); --campo 13-8

        lib_proc.add(mlinhaC);
        v_registro := v_registro + 1;

      end;
    end loop;
    
    LIB_PROC.add_log(v_registro ||' produtos(s) gerado(s).',1);
    
    elsif p_arquivo = '3' then -- NF Entrada Master
    
     lib_proc.add_tipo(mproc_id,1,'NFENTR0_' || to_char(p_dataini, 'YYMM')||'.CSV',2);
     
     Lib_Proc.add('EMPRESA;FILIAL;EMITENTE;NUMERO_NOTA;SERIE;SUB_SERIE;DT_ENTRADA;VLR NF;TIPO_NF;NR_CONTROLE;NR_DOC_ORIGINAL;NUM_DI;DATA_DI;DIAS_VENCIMENTO;COND_PAGTO;VLR_FRETE;VLR_ICMS;VLR_IPI;VLR_DESCONTO;VLR_FRETE_IMPORTACAO;VLR_SEGURO_IMPORTACAO;VLR_ROYALTIES_IMPORTACAO;VLR_TOTAL_NF_DI_MOEDA_ESTRANGEIRA;CODIGO_SIGLA_MOEDA_ESTRANGEIRA;DT_INCLUSAO_SISTEMA_ORIGEM;COD_ORIGEM;',ptipo => 1);
      
      for mrege in c_ent loop
      begin    -- Entrada Master
        mlinhaC := null;
        lib_proc.add(ptipo => 1, ppag => 2, plinha =>
        mrege.Empresa       ||';'||
        mrege.Filial        ||';'||
        mrege.Fornecedor    ||';'||
        mrege.Numero_Nota   ||';'||
        mrege.Serie         ||';'||
        mrege.Sub_Serie     ||';'||
        mrege.Dt_Entrada    ||';'||
        mrege.Vlr_Nota      ||';'||
        mrege.Tipo_Nf       ||';'||
        mrege.Nr_Controle   ||';'||
        mrege.Numero_Cont_Doc_Original ||';'||
        mrege.Num_Di        ||';'||
        mrege.Data_Di       ||';'||
        mrege.Dias_Vencimento ||';'||
        mrege.COND_PAGTO     ||'B'||';'||
        mrege.Vlr_Frete      ||';'||
        mrege.Vlr_Icms       ||';'||
        mrege.Vlr_Ipi        ||';'||
        mrege.Vlr_Desconto   ||';'||
        mrege.Vlr_Frete_Importacao  ||';'||
        mrege.Vlr_Seguro_Importacao ||';'||
        mrege.Valor_Royaltles_Importacao ||';'||
        mrege.Valor_Total_Moeda          ||';'||
        mrege.Sigla_Moeda       ||';'||
        mrege.Data_Inclusao_Sis_Ori||';');
        
        /*
        mlinhaC := lib_str.w(mlinhaC, mrege.Empresa||';',1); --campo 1-5
        mlinhaC := lib_str.w(mlinhaC, mrege.Filial||';',6); --campo 2-5
        mlinhaC := lib_str.w(mlinhaC, mrege.Fornecedor||';',12); --campo 3-20
        mlinhaC := lib_str.w(mlinhaC, mrege.Numero_Nota||';',33); --campo 4-6
        mlinhaC := lib_str.w(mlinhaC, mrege.Serie||';', 40); --campo 5-2
        mlinhaC := lib_str.w(mlinhaC, mrege.Sub_Serie||';', 43); --campo 6-3
        mlinhaC := lib_str.w(mlinhaC, mrege.Dt_Entrada||';', 47); --campo 7-8
        mlinhaC := lib_str.w(mlinhaC, mrege.Vlr_Nota||';', 56); --campo 8-17
        mlinhaC := lib_str.w(mlinhaC, mrege.Tipo_Nf||';', 74); --campo 9-3
        mlinhaC := lib_str.w(mlinhaC, mrege.Nr_Controle||';', 78); --campo 10-20
        mlinhaC := lib_str.w(mlinhaC, mrege.Numero_Cont_Doc_Original||';',99); --campo 11-20
        mlinhaC := lib_str.w(mlinhaC, mrege.Num_Di||';', 120); --campo 12-20
        mlinhaC := lib_str.w(mlinhaC, mrege.Data_Di||';', 141); --campo 13-8
        mlinhaC := lib_str.w(mlinhaC, mrege.Dias_Vencimento||';', 150); --campo 14-5
        mlinhaC := lib_str.w(mlinhaC, mrege.COND_PAGTO||'B'||';', 156); --campo 15-6
        mlinhaC := lib_str.w(mlinhaC, mrege.Vlr_Frete||';', 163); --campo 16-17 --, 
        mlinhaC := lib_str.w(mlinhaC, mrege.Vlr_Icms||';', 181); --campo 17-17
        mlinhaC := lib_str.w(mlinhaC, mrege.Vlr_Ipi||';', 199); --campo 18-17
        mlinhaC := lib_str.w(mlinhaC, mrege.Vlr_Desconto||';', 217); --campo 19-17
        mlinhaC := lib_str.w(mlinhaC, mrege.Vlr_Frete_Importacao||';', 235); --campo 20-17
        mlinhaC := lib_str.w(mlinhaC, mrege.Vlr_Seguro_Importacao||';', 253); --campo 21-17
        mlinhaC := lib_str.w(mlinhaC, mrege.Valor_Royaltles_Importacao||';', 271); --campo 22-17
        mlinhaC := lib_str.w(mlinhaC, mrege.Valor_Total_Moeda||';', 289); --campo 23-17
        mlinhaC := lib_str.w(mlinhaC, mrege.Sigla_Moeda||';',307); --campo 24-5
        mlinhaC := lib_str.w(mlinhaC, mrege.Data_Inclusao_Sis_Ori||';', 313);*/ --campo 25-8
        
        
        lib_proc.add(mlinhaC);
        v_registro := v_registro + 1;
      end;
    end loop;
    LIB_PROC.add_log(v_registro ||
                     ' NF Entrada Master.',
                     1);
                     
    elsif p_arquivo = '4' then   -- NF Entrada Itens                  
                     
    lib_proc.add_tipo(mproc_id,1,'NFENTR1_' || to_char(p_dataini, 'YYMM')||'.CSV',2);
     
     Lib_Proc.add('Empresa;Filial;Cod. do Fornecedor;Numero da NF;Serie da NF;SUB-SERIE;Codigo do CFOP;Cod. Material;Unidade de venda;Quantidade;Preco Total;Vr. do Frete;Vr. do ICMS;Vr. do IPI;Credito do PIS;Credito COFINS;Vr. do Desconto;Valor Imposto Importacao;Valor Frete Importacao;Valor Seguros na Importacao;Valor de Royalties na Importacao;Valor Outras despesas na importacao;Valor ICMS ST;Valor IPI ST;Valor Total item Moeda Estrangeira;ICMS Incluso valor item;IPI Incluso valor item;PIS Incluso valor item;COFINS Incluso valor item;Codigo Origem;Data de Entrada',ptipo => 1);
    
      for mregei in c_enti loop

      begin
        -- Entrada Itens
        mlinhaC := null;
        lib_proc.add(ptipo => 1, ppag => 2, plinha =>
        
        mregei.Empresa||';'||
        mregei.Filial||';'||
        mregei.codigo_fornecedor||';'||
        mregei.numero_nota_fiscal_entrada||';'||
        mregei.serie_nota_entrada||';'||
        mregei.sub_serie_nota_entrada||';'||
        mregei.cfop||';'||
        mregei.codigo_produto||';'||
        mregei.sigla_unidade||';'||
        mregei.quantidade||';'||
        mregei.preco_total||';'||
        mregei.valor_frete||';'||
        mregei.valor_icms||';'||
        mregei.valor_ipi||';'||
        mregei.valor_pis_nao_cumulativo||';'||
        mregei.valor_cofins_nao_cumulativo||';'||
        mregei.valor_desconto||';'||
        mregei.valor_imposto_import||';'||
        mregei.valor_frete_impor||';'||
        mregei.valor_seguro_import||';'||
        mregei.valor_royalties_import||';'||
        mregei.valor_out_desp_import||';'||
        mregei.valor_icms_st||';'||
        mregei.valor_ipi_st||';'||
        mregei.vlr_total_moeda_estrang||';'||
        mregei.icms_incluso_item||';'||
        mregei.ipi_incluso_item||';'||
        mregei.pis_incluso_item||';'||
        mregei.cofins_incluso_item||';'||
        mregei.codigo_origem||';'||
        mregei.data_fiscal||';'); 
      
        
        
        lib_proc.add(mlinhaC);
        v_registro := v_registro + 1;
      end;
    end loop;
    LIB_PROC.add_log(v_registro ||
                     ' NF Entrada Itens.',
                     1);
                     
    elsif p_arquivo = '5' then -- NF Saida Master
    
     lib_proc.add_tipo(mproc_id,1,'NFSAIDA0_' || to_char(p_dataini, 'YYMM')||'.CSV',2);
     
     lib_proc.add('Empresa;Filial;Codigo do Cliente;Numero da Nota Fiscal;Serie da Nota Fiscal;SUB-SERIE;Data de Emissao;Valor Total da Nota Fiscal;TIPO NOTA FISCAL;NR.DE CONTROLE;NR.DO DOC ORIGINAL;SUBSTITUICAO TRIBUTARIA;NR.DIAS VENCIMENTO;COD.COND PAGTO;Valor do ICMS;Valor do IPI;Valor do ISS;Valor de Desconto;Valor de Frete e Seguro;Data de Embarque;Data Inclusao Sist Origem',ptipo => 1);

      for mregsm in c_saida loop

      begin
        -- Saida Master
        mlinhaC := null;
        lib_proc.add(ptipo => 1, ppag => 2, plinha =>
        mregsm.Empresa||';'||
        mregsm.Filial||';'||
        mregsm.cliente||';'||
        mregsm.nro_nota_fiscal||';'||
        mregsm.serie||';'||
        mregsm.Sub_Serie||';'||
        mregsm.dt_emissao||';'||
        mregsm.valor_total_nota||';'||
        mregsm.tipo_nf||';'||
        mregsm.Nr_Controle||';'||
        mregsm.numero_documento_ori||';'||
        mregsm.ind_substit_tributaria||';'||
        mregsm.num_dias_vencimento||';'||
        mregsm.codigo_cond_pagamento||';'||
        mregsm.vlr_tributo_icms||';'||
        mregsm.vlr_tributo_ipi||';'||
        mregsm.vlr_tributo_iss||';'||
        mregsm.vlr_desconto||';'||
        mregsm.vlr_frete_seguro||';'||
        lpad(mregsm.dt_embarque,'',8)||';'||
        mregsm.data_inclusao_sistema||';'); 
       

        
        lib_proc.add(mlinhaC);
        v_registro := v_registro + 1;
      end;
    end loop;
    LIB_PROC.add_log(v_registro ||
                     ' NF Saida Master.',
                     1);  
        

     elsif p_arquivo = '6' then -- NF Saida Itens
    
     lib_proc.add_tipo(mproc_id,1,'NFSAIDA1_' || to_char(p_dataini, 'YYMM')||'.CSV',2);
     
     lib_proc.add('EMPRESA;FILIAL;NUMERO;SERIE;SUB-SERIE;CFOP;CODIGO DO MATERIAL;U.M.;QUANTIDADE;Preco Total;VALOR DO FRETE E SEGURO;VALOR ICMS;VALOR IPI;VALOR ISS;VALOR DO DESCONTO;Valor ICMS ST;Valor IPI ST;Valor Comissao;VALOR PIS;VALOR COFINS;ICMS Incluso valor item;IPI Incluso valor item');

      for mregsi in c_saidai loop

      
      begin
        -- Saida Itens
        mlinhaC := null;
        lib_proc.add(ptipo => 1, ppag => 2, plinha =>
        mregsi.Empresa||';'||
        mregsi.Filial||';'||
        mregsi.nro_nota||';'||
        mregsi.serie_nota||';'||
        mregsi.Sub_Serie||';'||
        mregsi.cfop||';'||
        mregsi.codigo_material||';'||
        mregsi.unid_med||';'||
        mregsi.quantidade||';'||
        mregsi.preco_total||';'||
        mregsi.valor_frete_seguro||';'||
        mregsi.valor_icms||';'||
        mregsi.valor_ipi||';'||
        mregsi.valor_iss||';'||
        mregsi.valor_desconto||';'||
        mregsi.valor_icms_st||';'||
        mregsi.valo_ipi_st||';'||
        mregsi.valor_comissao||';'||
        mregsi.valor_pis||';'||
        mregsi.valor_cofins||';'||
        mregsi.icms_incluso_vlr_item||';'||
        mregsi.ipi_incluso_vlr_item||';'); 
         
        
        lib_proc.add(mlinhaC);
        v_registro := v_registro + 1;
      end;
 
    end loop;
    LIB_PROC.add_log(v_registro ||
                     ' NF Sa�da Itens.',
                     1);
                                 

    end if;

     lib_proc.close();

    return mproc_id;

END;

END MSAF_EXP_EASY_CPROC;
/