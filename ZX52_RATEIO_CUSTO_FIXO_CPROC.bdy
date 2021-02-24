CREATE OR REPLACE PACKAGE BODY ZX52_RATEIO_CUSTO_FIXO_CPROC IS

  MCOD_EMPRESA EMPRESA.COD_EMPRESA%TYPE;
  MCOD_USUARIO USUARIO_EMPRESA.COD_USUARIO%TYPE;

  FUNCTION PARAMETROS RETURN VARCHAR2 IS
    PSTR   VARCHAR2(5000);
    DATA_W DATE;

    BEGIN
      SELECT ADD_MONTHS(SYSDATE, -1)
        INTO DATA_W
        FROM DUAL;

    MCOD_USUARIO := LIB_PARAMETROS.RECUPERAR(UPPER('USUARIO'));

-- 1
    LIB_PROC.ADD_PARAM(PPARAM      => PSTR,
                       PTITULO     => 'Período de Referência',
                       PTIPO       => 'DATE',
                       PCONTROLE   => 'TEXTBOX',
                       PMANDATORIO => 'S',
                       PDEFAULT    => DATA_W,
                       PMASCARA    => 'MM/YYYY',
                       PAPRESENTA  => 'S');

-- 2
    LIB_PROC.ADD_PARAM(PPARAM      => PSTR,
                       PTITULO     => 'Empresa',
                       PTIPO       => 'VARCHAR2',
                       PCONTROLE   => 'COMBOBOX',
                       PMANDATORIO => 'S',
                       PDEFAULT    => NULL,
                       PMASCARA    => NULL,
                       PVALORES    => 'SELECT COD_EMPRESA, COD_EMPRESA||'' - ''||RAZAO_SOCIAL FROM EMPRESA ORDER BY COD_EMPRESA',
                       PAPRESENTA  => 'S');

-- 3
    LIB_PROC.ADD_PARAM(PPARAM      => PSTR,
                       PTITULO     => 'Estabelecimento',
                       PTIPO       => 'VARCHAR2',
                       PCONTROLE   => 'COMBOBOX',
                       PMANDATORIO => 'S',
                       PDEFAULT    => NULL,
                       PMASCARA    => NULL,
                       PVALORES    => 'SELECT A.COD_ESTAB, A.COD_ESTAB||'' - ''||A.RAZAO_SOCIAL FROM ESTABELECIMENTO A WHERE A.COD_EMPRESA = :2 ORDER BY A.COD_EMPRESA,A.COD_ESTAB',
                       PAPRESENTA  => 'S');

-- 4
    LIB_PROC.ADD_PARAM(PPARAM      => PSTR,
                       PTITULO     => 'Vlr. Custo Fixo para Rateio',
                       PTIPO       => 'NUMBER',
                       PCONTROLE   => 'TEXTBOX',
                       PMANDATORIO => 'S',
                       PDEFAULT    => '0',
                       PMASCARA    => '00000000000000.00',
                       PAPRESENTA  => 'S');

    RETURN PSTR;
    END;

  FUNCTION NOME RETURN VARCHAR2 IS
  BEGIN
    RETURN ' Rateio Custo Fixo';
  END;

  FUNCTION TIPO RETURN VARCHAR2 IS
  BEGIN
    RETURN ' Administração de Materiais';
  END;

  FUNCTION VERSAO RETURN VARCHAR2 IS
  BEGIN
    RETURN '1.0';
  END;

  FUNCTION DESCRICAO RETURN VARCHAR2 IS
  BEGIN
    RETURN ' Processo para distribuição automática do rateio do custo fixo no inventário de materiais.';
  END;

  FUNCTION MODULO RETURN VARCHAR2 IS
  BEGIN
    RETURN 'Processos Customizados';
  END;

  FUNCTION CLASSIFICACAO RETURN VARCHAR2 IS
  BEGIN
    RETURN 'Processos Customizados';
  END;

  FUNCTION ORIENTACAOPAPEL RETURN VARCHAR2 IS
  BEGIN
    RETURN 'landscape';
  END;


PROCEDURE CAB_RESUMO IS
  MLINHA VARCHAR2(1000);
  BEGIN
    MLINHA := LIB_STR.W('',RPAD('-',82,'-'),0);
    LIB_PROC.ADD(MLINHA);
    MLINHA := LIB_STR.W('','RESUMO DA APURAÇÃO DO CUSTO FIXO REALIZADA NO PERÍODO',15);
    LIB_PROC.ADD(MLINHA);
    MLINHA := LIB_STR.W('',RPAD('-',82,'-'),0);
    LIB_PROC.ADD(MLINHA);
END CAB_RESUMO;

PROCEDURE CAB_ARQ IS
  MLINHA VARCHAR2(1000);
  BEGIN
    MLINHA := LIB_STR.W('','RELATÓRIO ANALÍTICO',0);
    LIB_PROC.ADD(MLINHA,'','',2);
    MLINHA := LIB_STR.W('',' ',0);
    LIB_PROC.ADD(MLINHA,'','',2);
    MLINHA := LIB_STR.W('','COD_EMPRESA'||CHR(09)||'COD_ESTAB'||CHR(09)||'PERIODO'||CHR(09)||'COD_MATERIAL'||CHR(09)||'PLANTA_MANUFATURA'||CHR(09)||'PLANTA_INVENTARIO'||CHR(09)||'QUANTIDADE'||CHR(09)||'VLR_UNIT_SAP'||CHR(09)||'VLR_TOT_SAP'||CHR(09)||'PROD_PERIODO'||CHR(09)||'VLR_CF_UNIT'||CHR(09)||'VLR_TOT_CF',0);
    LIB_PROC.ADD(MLINHA,'','',2);
END CAB_ARQ;


  FUNCTION EXECUTAR( P_PERIODO DATE,
                     P_EMPRESA VARCHAR2,
                     P_ESTAB   VARCHAR2,
                     P_VLR_CF  NUMBER ) RETURN VARCHAR2 IS

  MPROC_ID NUMBER;
  PDAT_INI DATE;
  PDAT_FIM DATE;
  VQTDE_PROD NUMBER := null;
  VQTDE_NPROD NUMBER := null;
  VQTDE_TOT NUMBER := null;
  V_VCF_NPROD NUMBER := null;
  V_VCF_RATEIO NUMBER := null;
  V_VCF_UNIT NUMBER := null;



    BEGIN
    MCOD_EMPRESA := LIB_PARAMETROS.RECUPERAR(UPPER('EMPRESA'));
    MCOD_USUARIO := LIB_PARAMETROS.RECUPERAR(UPPER('USUARIO'));
    PDAT_INI     := LAST_DAY(ADD_MONTHS(TO_DATE(P_PERIODO,'DD/MM/YYYY'),-1))+1;
    PDAT_FIM     := LAST_DAY(P_PERIODO);

    -- Cria Processo
    MPROC_ID := LIB_PROC.new('ZX52_RATEIO_CUSTO_FIXO_CPROC', 48, 150);
    LIB_PROC.add_tipo(mproc_id, 1, 'Relatório Resumo', 1);
    LIB_PROC.ADD_TIPO(MPROC_ID,2,MPROC_ID||'_RELATORIO_ANALITICO.xls',2);

    BEGIN
      DELETE ZX52_CALC_RATEIO_CF
      WHERE COD_EMPRESA     = P_EMPRESA
        AND COD_ESTAB       = P_ESTAB
        AND DATA_INVENTARIO = PDAT_FIM;
      COMMIT;

      INSERT INTO ZX52_CALC_RATEIO_CF
        SELECT TX52.COD_EMPRESA
              ,TX52.COD_ESTAB
              ,TX52.DATA_INVENTARIO
              ,TX52.GRUPO_CONTAGEM
              ,TX52.IDENT_PRODUTO
              ,TX52.IND_PRODUTO
              ,TX52.COD_PRODUTO
              ,TX52.IDENT_NAT_ESTOQUE
              ,TX52.IDENT_ALMOX
              ,TX52.COD_ALMOX
              ,TX52.QUANTIDADE
              ,TX52.VLR_UNIT
              ,TX52.VLR_TOT
              ,TX52.PLANTA_PROD
              ,NVL(TX10.IND_PD,'N') PRODUCAO
              ,'0' VLR_CF_UNIT
              ,'0' VLR_TOT_CF
              ,'0' VLR_TOT_AJU
        FROM (SELECT X52.COD_EMPRESA
                    ,X52.COD_ESTAB
                    ,X52.DATA_INVENTARIO
                    ,X52.GRUPO_CONTAGEM
                    ,X52.IDENT_PRODUTO
                    ,X2013.IND_PRODUTO
                    ,X2013.COD_PRODUTO
                    ,X52.IDENT_NAT_ESTOQUE
                    ,X52.IDENT_ALMOX
                    ,SUBSTR(X2021.COD_ALMOX,1,4) COD_ALMOX
                    ,X52.QUANTIDADE
                    ,X52.VLR_UNIT
                    ,X52.VLR_TOT
                    ,X2013.DSC_FINALIDADE PLANTA_PROD
              FROM X52_INVENT_PRODUTO X52
              JOIN X2013_PRODUTO X2013 ON X2013.IDENT_PRODUTO = X52.IDENT_PRODUTO
              LEFT OUTER JOIN X2021_ALMOXARIFADO X2021 ON X2021.IDENT_ALMOX = X52.IDENT_ALMOX
              WHERE X52.COD_EMPRESA             = P_EMPRESA
                AND X52.COD_ESTAB               = P_ESTAB
                AND X52.DATA_INVENTARIO         = PDAT_FIM
                AND NVL(X2013.DSC_FINALIDADE,0) = '2004' ) TX52
        LEFT OUTER JOIN (SELECT DISTINCT X10.COD_EMPRESA
                                        ,X10.COD_ESTAB
                                        ,X2013.IND_PRODUTO
                                        ,X2013.COD_PRODUTO
                                        ,'S' IND_PD
                         FROM X10_ESTOQUE X10
                         JOIN X2013_PRODUTO X2013 ON X2013.IDENT_PRODUTO = X10.IDENT_PRODUTO
                         LEFT OUTER JOIN X2021_ALMOXARIFADO X2021 ON X2021.IDENT_ALMOX = X10.IDENT_ALMOX
                         WHERE X10.COD_EMPRESA                      = P_EMPRESA
                           AND X10.COD_ESTAB                        = P_ESTAB
                           AND X10.DATA_MOVTO BETWEEN PDAT_INI AND PDAT_FIM
                           AND NVL(SUBSTR(X2021.COD_ALMOX,1,4),'0') = '2004'
                           AND NVL(X10.NUM_ORDEM,'0')              >= '1000000000'
                           AND NVL(X10.DSC_FINALIDADE,'0') IN ('101','102') ) TX10 ON TX10.COD_EMPRESA = TX52.COD_EMPRESA
                                                                                  AND TX10.COD_ESTAB   = TX52.COD_ESTAB
                                                                                  AND TX10.IND_PRODUTO = TX52.IND_PRODUTO
                                                                                  AND TX10.COD_PRODUTO = TX52.COD_PRODUTO;
      COMMIT;

      SELECT SUM(DECODE(PRODUCAO,'S',QUANTIDADE,0))
            ,SUM(DECODE(PRODUCAO,'N',QUANTIDADE,0))
            ,SUM(QUANTIDADE)
      INTO VQTDE_PROD
          ,VQTDE_NPROD
          ,VQTDE_TOT
      FROM zx52_calc_rateio_CF
      WHERE COD_EMPRESA     = P_EMPRESA
        AND COD_ESTAB       = P_ESTAB
        AND DATA_INVENTARIO = PDAT_FIM;

      FOR CFANT IN (SELECT Z1.COD_EMPRESA
                          ,Z1.COD_ESTAB
                          ,Z1.DATA_INVENTARIO
                          ,Z1.IND_PRODUTO
                          ,Z1.COD_PRODUTO
                          ,Z1.COD_ALMOX
                          ,Z2.VLR_CF_UNIT
                    FROM zx52_calc_rateio_CF Z1
                    JOIN ZX52_HIST_APUR_CF_UNIT Z2 ON Z2.COD_EMPRESA = Z1.COD_EMPRESA
                                                  AND Z2.COD_ESTAB   = Z1.COD_ESTAB
                                                  AND Z2.PER_REF     = (SELECT MAX(Z3.PER_REF) 
                                                                        FROM ZX52_HIST_APUR_CF_UNIT Z3 
                                                                        WHERE Z3.COD_EMPRESA = Z2.COD_EMPRESA
                                                                          AND Z3.COD_ESTAB   = Z2.COD_ESTAB
                                                                          AND Z3.PER_REF     < TO_CHAR(Z1.DATA_INVENTARIO,'MM/YYYY')
                                                                          AND Z3.IND_PRODUTO = Z2.IND_PRODUTO
                                                                          AND Z3.COD_PRODUTO = Z2.COD_PRODUTO )
                                                  AND Z2.IND_PRODUTO = Z1.IND_PRODUTO
                                                  AND Z2.COD_PRODUTO = Z1.COD_PRODUTO
                    WHERE Z1.COD_EMPRESA     = P_EMPRESA
                      AND Z1.COD_ESTAB       = P_ESTAB
                      AND Z1.DATA_INVENTARIO = PDAT_FIM
                      AND PRODUCAO           = 'N' ) LOOP

        UPDATE zx52_calc_rateio_CF SET VLR_CF_UNIT = CFANT.VLR_CF_UNIT
                                      ,VLR_TOT_CF  = ROUND(QUANTIDADE * CFANT.VLR_CF_UNIT,2)
                                      ,VLR_TOT_AJU = ROUND(QUANTIDADE * CFANT.VLR_CF_UNIT,2) + VLR_TOT
        WHERE COD_EMPRESA     = CFANT.COD_EMPRESA
          AND COD_ESTAB       = CFANT.COD_ESTAB
          AND DATA_INVENTARIO = CFANT.DATA_INVENTARIO
          AND IND_PRODUTO     = CFANT.IND_PRODUTO
          AND COD_PRODUTO     = CFANT.COD_PRODUTO
          AND COD_ALMOX       = CFANT.COD_ALMOX;
      END LOOP;
      COMMIT;

      SELECT SUM(VLR_TOT_CF)
        INTO V_VCF_NPROD
        FROM zx52_calc_rateio_CF
       WHERE COD_EMPRESA     = P_EMPRESA
         AND COD_ESTAB       = P_ESTAB
         AND DATA_INVENTARIO = PDAT_FIM
         AND PRODUCAO        = 'N';

      V_VCF_RATEIO := P_VLR_CF - V_VCF_NPROD;
      V_VCF_UNIT := ROUND((P_VLR_CF - V_VCF_NPROD)/VQTDE_PROD,15);

      FOR CFATU IN (SELECT Z1.COD_EMPRESA
                          ,Z1.COD_ESTAB
                          ,Z1.DATA_INVENTARIO
                          ,Z1.IND_PRODUTO
                          ,Z1.COD_PRODUTO
                          ,Z1.COD_ALMOX
                    FROM zx52_calc_rateio_CF Z1
                    WHERE Z1.COD_EMPRESA     = P_EMPRESA
                      AND Z1.COD_ESTAB       = P_ESTAB
                      AND Z1.DATA_INVENTARIO = PDAT_FIM
                      AND PRODUCAO           = 'S' ) LOOP

        UPDATE zx52_calc_rateio_CF SET VLR_CF_UNIT = V_VCF_UNIT
                                      ,VLR_TOT_CF  = ROUND(QUANTIDADE * V_VCF_UNIT,2)
                                      ,VLR_TOT_AJU = ROUND(QUANTIDADE * V_VCF_UNIT,2) + VLR_TOT
        WHERE COD_EMPRESA   = CFATU.COD_EMPRESA
          AND COD_ESTAB       = CFATU.COD_ESTAB
          AND DATA_INVENTARIO = CFATU.DATA_INVENTARIO
          AND IND_PRODUTO     = CFATU.IND_PRODUTO
          AND COD_PRODUTO     = CFATU.COD_PRODUTO
          AND COD_ALMOX       = CFATU.COD_ALMOX;
      END LOOP;
      COMMIT;

      DELETE ZX52_HIST_APUR_CF_UNIT
       WHERE COD_EMPRESA = P_EMPRESA
         AND COD_ESTAB   = P_ESTAB
         AND PER_REF     = TO_CHAR(PDAT_FIM,'MM/YYYY');
      COMMIT;

      INSERT INTO ZX52_HIST_APUR_CF_UNIT
      SELECT DISTINCT COD_EMPRESA
                     ,COD_ESTAB
                     ,TO_CHAR(DATA_INVENTARIO,'MM/YYYY')
                     ,IND_PRODUTO
                     ,COD_PRODUTO
                     ,VLR_CF_UNIT
      FROM ZX52_CALC_RATEIO_CF
      WHERE COD_EMPRESA     = P_EMPRESA
        AND COD_ESTAB       = P_ESTAB
        AND DATA_INVENTARIO = PDAT_FIM
        AND PRODUCAO        = 'S'
      ORDER BY 1,2,3,4,6,5;
      COMMIT;

    END;

    CAB_RESUMO;
    DECLARE
      MLINHA VARCHAR2(1000);
    BEGIN
      MLINHA := LIB_STR.W('','(1) Quantidade total de itens produzidos no período:'||LPAD(TO_CHAR(VQTDE_PROD,'999G999G999G999G990D00','nls_numeric_characters = '',.'''),30,'.'),0);
      LIB_PROC.ADD(MLINHA);
      MLINHA := LIB_STR.W('','(2) Quantidade total de itens não produzidos no período:'||LPAD(TO_CHAR(VQTDE_NPROD,'999G999G999G999G990D00','nls_numeric_characters = '',.'''),26,'.'),0);
      LIB_PROC.ADD(MLINHA);
      MLINHA := LIB_STR.W('','(3) Quantidade total de itens do período (1 + 2):'||LPAD(TO_CHAR(VQTDE_TOT,'999G999G999G999G990D00','nls_numeric_characters = '',.'''),33,'.'),0);
      LIB_PROC.ADD(MLINHA);
      MLINHA := LIB_STR.W('',RPAD('-',82,'-'),0);
      LIB_PROC.ADD(MLINHA);
      MLINHA := LIB_STR.W('','(4) Valor total do custo fixo apurado no período:'||LPAD(TO_CHAR(P_VLR_CF,'999G999G999G999G990D00','nls_numeric_characters = '',.'''),33,'.'),0);
      LIB_PROC.ADD(MLINHA);
      MLINHA := LIB_STR.W('','(5) Valor total do custo fixo itens não produtivos:'||LPAD(TO_CHAR(V_VCF_NPROD,'999G999G999G999G990D00','nls_numeric_characters = '',.'''),31,'.'),0);
      LIB_PROC.ADD(MLINHA);
      MLINHA := LIB_STR.W('','(6) Valor do custo fixo para rateio no período (4 - 5):'||LPAD(TO_CHAR(V_VCF_RATEIO,'999G999G999G999G990D00','nls_numeric_characters = '',.'''),27,'.'),0);
      LIB_PROC.ADD(MLINHA);
      MLINHA := LIB_STR.W('',RPAD('-',82,'-'),0);
      LIB_PROC.ADD(MLINHA);
      MLINHA := LIB_STR.W('','(7) Valor unitário do custo fixo referente a '||TO_CHAR(PDAT_FIM,'MM/YYYY')||' (6 / 1):'||LPAD(TO_CHAR(ROUND(V_VCF_UNIT,2),'999G999G999G999G990D00','nls_numeric_characters = '',.'''),21,'.'),0);
      LIB_PROC.ADD(MLINHA);
      MLINHA := LIB_STR.W('',RPAD('-',82,'-'),0);
      LIB_PROC.ADD(MLINHA);
    END;

    CAB_ARQ;
    DECLARE
      MLINHA VARCHAR2(1000);
    BEGIN
      FOR REG IN (SELECT COD_EMPRESA
                        ,COD_ESTAB
                        ,DATA_INVENTARIO
                        ,GRUPO_CONTAGEM
                        ,IDENT_PRODUTO
                        ,COD_PRODUTO
                        ,IDENT_NAT_ESTOQUE
                        ,PLANTA_PROD
                        ,IDENT_ALMOX
                        ,COD_ALMOX
                        ,QUANTIDADE
                        ,VLR_UNIT
                        ,VLR_TOT
                        ,DECODE(PRODUCAO,'S','Produzido','Não Produzido') PROD_PERIODO
                        ,ROUND(VLR_CF_UNIT,2) VLR_CF_UNIT
                        ,VLR_TOT_CF
                        ,VLR_TOT_AJU
                  FROM ZX52_CALC_RATEIO_CF
                  WHERE COD_EMPRESA     = P_EMPRESA
                    AND COD_ESTAB       = P_ESTAB
                    AND DATA_INVENTARIO = PDAT_FIM
                  ORDER BY 1,2,3,6,8,10 )
        LOOP
          UPDATE X52_INVENT_PRODUTO SET VLR_UNIT = ROUND(REG.VLR_TOT_AJU/REG.QUANTIDADE,6)
                                       ,VLR_TOT  = REG.VLR_TOT_AJU
          WHERE COD_EMPRESA       = REG.COD_EMPRESA
            AND COD_ESTAB         = REG.COD_ESTAB
            AND DATA_INVENTARIO   = REG.DATA_INVENTARIO
            AND GRUPO_CONTAGEM    = REG.GRUPO_CONTAGEM
            AND IDENT_PRODUTO     = REG.IDENT_PRODUTO
            AND IDENT_NAT_ESTOQUE = REG.IDENT_NAT_ESTOQUE
            AND IDENT_ALMOX       = REG.IDENT_ALMOX
            AND QUANTIDADE        = REG.QUANTIDADE;

          MLINHA := LIB_STR.W('',REG.COD_EMPRESA||CHR(09)||
                                 REG.COD_ESTAB||CHR(09)||
                                 TO_CHAR(REG.DATA_INVENTARIO,'MM/YYYY')||CHR(09)||
                                 REG.COD_PRODUTO||CHR(09)||
                                 REG.PLANTA_PROD||CHR(09)||
                                 REG.COD_ALMOX||CHR(09)||
                                 TO_CHAR(REG.QUANTIDADE,'999G999G999G999G990D00','nls_numeric_characters = '',.''')||CHR(09)||
                                 TO_CHAR(REG.VLR_UNIT,'999G999G999G999G990D00','nls_numeric_characters = '',.''')||CHR(09)||
                                 TO_CHAR(REG.VLR_TOT,'999G999G999G999G990D00','nls_numeric_characters = '',.''')||CHR(09)||
                                 REG.PROD_PERIODO||CHR(09)||
                                 TO_CHAR(REG.VLR_CF_UNIT,'999G999G999G999G990D00','nls_numeric_characters = '',.''')||CHR(09)||
                                 TO_CHAR(REG.VLR_TOT_CF,'999G999G999G999G990D00','nls_numeric_characters = '',.''')||CHR(09)||
                                 TO_CHAR(REG.VLR_TOT_AJU,'999G999G999G999G990D00','nls_numeric_characters = '',.'''),0);
          LIB_PROC.ADD(MLINHA,'','',2);
        END LOOP;
    END;

    lib_proc.add_log('',1);
    lib_proc.add_log('PROCESSO CONCLUIDO COM SUCESSO!',1);
    lib_proc.add_log(TO_CHAR(SYSDATE,'DD/MM/YYYY')||' - '||MCOD_USUARIO,1);

    --fecho o processo
    LIB_PROC.CLOSE;
    RETURN MPROC_ID;

    END;
END ZX52_RATEIO_CUSTO_FIXO_CPROC;
/
