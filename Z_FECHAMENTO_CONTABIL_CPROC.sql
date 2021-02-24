create or replace 
PACKAGE Z_FECHAMENTO_CONTABIL_CPROC IS

  mLinha           varchar2(1000);

  FUNCTION PARAMETROS RETURN VARCHAR2;
  FUNCTION TIPO RETURN VARCHAR2;
  FUNCTION NOME RETURN VARCHAR2;
  FUNCTION DESCRICAO RETURN VARCHAR2;
  FUNCTION EXECUTAR(pEmpresa varchar2,
            pEstab varchar2,
            pCompetencia date,
            pConta varchar2,
            pTipo varchar2,
        pTipoEncerramento varchar2) RETURN NUMBER;
  --CURSORES
    --CURSOR HEADER
  CURSOR rHeader (pCabecalho varchar2) IS
     SELECT REGEXP_SUBSTR(pCabecalho,'[^,]+', 1, LEVEL) AS campo FROM dual
     CONNECT BY LEVEL <= regexp_count(pCabecalho,',') + 1 AND PRIOR sys_guid() IS NOT NULL;

  CURSOR Saldo    (pEmpresa varchar2,
         pEstab varchar2,
         pCompetencia date,
     pTipoEncerramento varchar2) IS
         SELECT 'X80' AS tabela,
            x80.cod_empresa,
            x80.cod_estab,
            x80.dat_saldo,
            x2002.cod_conta,
            x80.ident_conta,
            x2002.descricao,
            x80.ident_custo,
            x2003.cod_custo,
            x80.vlr_saldo_cont_ant AS vlr_saldo_ini,
            x80.ind_deb_cred_ant AS ind_saldo_ini,
            x80.vlr_saldo_cont_atu AS vlr_saldo_fim,
            x80.ind_deb_cred_atu AS ind_saldo_fim
         FROM x80_saldos_ccusto x80
         JOIN x2002_plano_contas x2002 ON x2002.ident_conta = x80.ident_conta
         JOIN x2003_centro_custo x2003 ON x2003.ident_custo = x80.ident_custo
         WHERE x80.cod_empresa    = pEmpresa
         AND x80.cod_estab    = pEstab
         AND x80.dat_saldo    = LAST_DAY(TO_DATE(pCompetencia,'DD/MM/RRRR'))
         AND x2002.ind_natureza IN ('3', '4', '8','9')
         AND x2002.ind_situacao = 'A'
         AND NVL(x80.vlr_saldo_cont_atu,0) > 0
     AND (CASE WHEN pTipoEncerramento = '1' THEN 0 ELSE 1 END) = 1

         UNION ALL

         SELECT 'X02' AS tabela,
            x02.cod_empresa,
            x02.cod_estab,
            x02.data_saldo,
            x2002.cod_conta,
            x2002.ident_conta,
            X2002.descricao,
            NULL AS ident_custo,
            NULL AS cod_custo,
            x02.vlr_saldo_ini,
            x02.ind_saldo_ini,
            x02.vlr_saldo_fim,
            x02.ind_saldo_fim
         FROM x02_saldos x02
         JOIN x2002_plano_contas x2002 ON x2002.ident_conta = x02.ident_conta
         WHERE x02.cod_empresa = pEmpresa
         AND x02.cod_estab     = pEstab
         AND x02.data_saldo    = LAST_DAY(TO_DATE(pCompetencia, 'DD/MM/RRRR'))
         AND x2002.ind_natureza IN ('3', '4', '8', '9')
         AND x2002.ind_situacao = 'A'
         AND NVL(x02.vlr_saldo_fim,0) > 0
         AND (pTipoEncerramento = '1' OR NOT EXISTS (SELECT 1
                 FROM x80_saldos_ccusto
                 WHERE x80_saldos_ccusto.cod_empresa = x02.cod_empresa
                 AND x80_saldos_ccusto.cod_estab     = x02.cod_estab
                 AND x80_saldos_ccusto.dat_saldo     = x02.data_saldo
                 AND x80_saldos_ccusto.ident_conta   = x02.ident_conta))
         ORDER BY 1,2,3,4,5;

  CURSOR  Fechamento (pEmpresa varchar2,
              pEstab varchar2,
              pCompetencia date) IS
              SELECT retorno.cod_empresa,
                 retorno.cod_estab,
                 LAST_DAY(retorno.data_lancto) AS data_saldo,
                 SUM(retorno.valor_credito) AS valor_credito,
                 SUM(retorno.valor_debito) AS valor_debito
                 FROM (SELECT cod_empresa,
                      cod_estab,
                      data_lancto,
                      x01_contabil.ind_deb_cre,
                      (CASE WHEN x01_contabil.ind_deb_cre = 'C' THEN SUM(x01_contabil.vlr_lancto) ELSE 0 END) AS valor_credito,
                      (CASE WHEN x01_contabil.ind_deb_cre = 'D' THEN SUM(x01_contabil.vlr_lancto) ELSE 0 END) AS valor_debito
                   FROM x01_contabil
                   WHERE x01_contabil.cod_empresa = pEmpresa
                   AND x01_contabil.cod_estab = pEstab
                   AND (x01_contabil.data_lancto BETWEEN TO_DATE(pCompetencia,'DD/MM/RRRR') AND LAST_DAY(TO_DATE(pCompetencia,'DD/MM/RRRR')))
                   AND tipo_lancto = 'E'
                   GROUP BY cod_empresa,
                        cod_estab,
                        data_lancto,
                        x01_contabil.ind_deb_cre
                   ORDER BY cod_empresa,
                        cod_estab,
                        data_lancto,
                        x01_contabil.ind_deb_cre ) retorno
                 GROUP BY retorno.cod_empresa,
                      retorno.cod_estab,
                      LAST_DAY(retorno.data_lancto)
                 ORDER BY retorno.cod_empresa,
                      retorno.cod_estab,
                      LAST_DAY(retorno.data_lancto);

  CURSOR  Saldo_Novo_X80 (pEmpresa varchar2,
              pEstab varchar2,
              pCompetencia date) IS
              SELECT retorno.cod_empresa,
                 retorno.cod_estab,
                 LAST_DAY(retorno.data_lancto) AS data_saldo,
                 retorno.cod_conta,
                 retorno.ident_conta,
                 retorno.cod_custo,
                 retorno.ident_custo,
                 SUM(retorno.valor_credito) AS valor_credito,
                 SUM(retorno.valor_debito) AS valor_debito
                 FROM (SELECT  cod_empresa,
                           cod_estab,
                           data_lancto,
                           x2002_plano_contas.cod_conta,
                           x2002_plano_contas.ident_conta,
                           x2003_centro_custo.cod_custo,
                           x2003_centro_custo.ident_custo,
                           x01_contabil.ind_deb_cre,
                           (CASE WHEN x01_contabil.ind_deb_cre = 'C' THEN SUM(x01_contabil.vlr_lancto) ELSE 0 END) AS valor_credito,
                           (CASE WHEN x01_contabil.ind_deb_cre = 'D' THEN SUM(x01_contabil.vlr_lancto) ELSE 0 END) AS valor_debito
                       FROM x01_contabil
                       JOIN x2002_plano_contas ON x2002_plano_contas.ident_conta = x01_contabil.ident_conta
                       JOIN x2003_centro_custo ON x2003_centro_custo.ident_custo = x01_contabil.ident_custo
                       WHERE x01_contabil.cod_empresa = pEmpresa
                       AND x01_contabil.cod_estab = pEstab
                       AND (x01_contabil.data_lancto BETWEEN TO_DATE(pCompetencia,'DD/MM/RRRR') AND LAST_DAY(TO_DATE(pCompetencia,'DD/MM/RRRR')))
               GROUP BY cod_empresa,
                        cod_estab,
                        data_lancto,
                        x2002_plano_contas.cod_conta,
                        x2002_plano_contas.ident_conta,
                        x2003_centro_custo.cod_custo,
                        x2003_centro_custo.ident_custo,
                        x01_contabil.ind_deb_cre
                       ORDER BY cod_empresa,
                        cod_estab,
                        data_lancto,
                        x2002_plano_contas.cod_conta,
                        x2002_plano_contas.ident_conta,
                        x2003_centro_custo.cod_custo,
                        x01_contabil.ind_deb_cre ) retorno
              GROUP BY retorno.cod_empresa,
                   retorno.cod_estab,
                   LAST_DAY(retorno.data_lancto),
                   retorno.cod_conta,
                   retorno.ident_conta,
                   retorno.cod_custo,
                   retorno.ident_custo
              ORDER BY retorno.cod_empresa,
                   retorno.cod_estab,
                   LAST_DAY(retorno.data_lancto),
                   retorno.cod_conta,
                   retorno.ident_conta,
                   retorno.cod_custo,
                   retorno.ident_custo;


  CURSOR  Saldo_Novo_X02 (pEmpresa varchar2,
              pEstab varchar2,
              pCompetencia date) IS
              SELECT retorno.cod_empresa,
                 retorno.cod_estab,
                 LAST_DAY(retorno.data_lancto) AS data_saldo,
                 retorno.cod_conta,
                 retorno.ident_conta,
                 SUM(retorno.valor_credito) AS valor_credito,
                 SUM(retorno.valor_debito) AS valor_debito
                 FROM (SELECT  cod_empresa,
                           cod_estab,
                           data_lancto,
                           x2002_plano_contas.cod_conta,
                           x2002_plano_contas.ident_conta,
                           x01_contabil.ind_deb_cre,
                           (CASE WHEN x01_contabil.ind_deb_cre = 'C' THEN SUM(x01_contabil.vlr_lancto) ELSE 0 END) AS valor_credito,
                           (CASE WHEN x01_contabil.ind_deb_cre = 'D' THEN SUM(x01_contabil.vlr_lancto) ELSE 0 END) AS valor_debito
                       FROM x01_contabil
                       JOIN x2002_plano_contas ON x2002_plano_contas.ident_conta = x01_contabil.ident_conta
                       WHERE x01_contabil.cod_empresa = pEmpresa
                       AND x01_contabil.cod_estab = pEstab
                       AND (x01_contabil.data_lancto BETWEEN TO_DATE(pCompetencia,'DD/MM/RRRR') AND LAST_DAY(TO_DATE(pCompetencia,'DD/MM/RRRR')))
                       GROUP BY cod_empresa,
                        cod_estab,
                        data_lancto,
                        x2002_plano_contas.cod_conta,
                        x2002_plano_contas.ident_conta,
                        x01_contabil.ind_deb_cre
                       ORDER BY cod_empresa,
                        cod_estab,
                        data_lancto,
                        x2002_plano_contas.cod_conta,
                        x2002_plano_contas.ident_conta,
                        x01_contabil.ind_deb_cre                                    
            ) retorno
              GROUP BY retorno.cod_empresa,
                   retorno.cod_estab,
                   LAST_DAY(retorno.data_lancto),
                   retorno.cod_conta,
                   retorno.ident_conta
              ORDER BY retorno.cod_empresa,
                   retorno.cod_estab,
                   LAST_DAY(retorno.data_lancto),
                   retorno.cod_conta,
                   retorno.ident_conta;
END Z_FECHAMENTO_CONTABIL_CPROC ;

