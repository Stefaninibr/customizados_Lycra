create or replace 
PACKAGE Z_FECH_CONT_FUNC_CPROC IS

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
         SELECT 'X227' AS tabela,
            x227.cod_empresa,
            x227.cod_estab,
            x227.dat_saldo,
            x2002.cod_conta,
            x227.ident_conta,
            x2002.descricao,
            x227.ident_custo,
            x2003.cod_custo,
            x227.vlr_saldo_ini AS vlr_saldo_ini,
            x227.ind_saldo_ini AS ind_saldo_ini,
            x227.vlr_saldo_fim AS vlr_saldo_fim,
            x227.ind_saldo_fim AS ind_saldo_fim
         FROM X227_SALDOS_CCUSTO_FUNC x227
         JOIN x2002_plano_contas x2002 ON x2002.ident_conta = x227.ident_conta
         JOIN x2003_centro_custo x2003 ON x2003.ident_custo = x227.ident_custo
         WHERE x227.cod_empresa    = pEmpresa
         AND x227.cod_estab    = pEstab
         AND x227.dat_saldo    = LAST_DAY(TO_DATE(pCompetencia,'DD/MM/RRRR'))
         AND x2002.ind_natureza IN ('3', '4', '8','9')
         AND x2002.ind_situacao = 'A'
         AND NVL(x227.vlr_saldo_fim,0) > 0
     AND (CASE WHEN pTipoEncerramento = '1' THEN 0 ELSE 1 END) = 1

         UNION ALL

         SELECT 'X226' AS tabela,
            x226.cod_empresa,
            x226.cod_estab,
            x226.data_operacao,
            x2002.cod_conta,
            x2002.ident_conta,
            X2002.descricao,
            NULL AS ident_custo,
            NULL AS cod_custo,
            x226.vlr_saldo_ini,
            x226.ind_saldo_ini,
            x226.vlr_saldo_fim,
            x226.ind_saldo_fim
         FROM X226_SALDOS_FUNC x226
         JOIN x2002_plano_contas x2002 ON x2002.ident_conta = x226.ident_conta
         WHERE x226.cod_empresa = pEmpresa
         AND x226.cod_estab     = pEstab
         AND x226.data_operacao    = LAST_DAY(TO_DATE(pCompetencia, 'DD/MM/RRRR'))
         AND x2002.ind_natureza IN ('3', '4', '8', '9')
         AND x2002.ind_situacao = 'A'
         AND NVL(x226.vlr_saldo_fim,0) > 0
         AND (pTipoEncerramento = '1' OR NOT EXISTS (SELECT 1
                 FROM X227_SALDOS_CCUSTO_FUNC
                 WHERE X227_SALDOS_CCUSTO_FUNC.cod_empresa = x226.cod_empresa
                 AND X227_SALDOS_CCUSTO_FUNC.cod_estab     = x226.cod_estab
                 AND X227_SALDOS_CCUSTO_FUNC.dat_saldo     = x226.data_operacao
                 AND X227_SALDOS_CCUSTO_FUNC.ident_conta   = x226.ident_conta))
         ORDER BY 1,2,3,4,5;

  CURSOR  Fechamento (pEmpresa varchar2,
              pEstab varchar2,
              pCompetencia date) IS
              SELECT retorno.cod_empresa,
                 retorno.cod_estab,
                 LAST_DAY(retorno.data_operacao) AS data_operacao,
                 SUM(retorno.valor_credito) AS valor_credito,
                 SUM(retorno.valor_debito) AS valor_debito
                 FROM (SELECT cod_empresa,
                      cod_estab,
                      data_operacao,
                      X225_CONTABIL_FUNC.ind_deb_cre,
                      (CASE WHEN X225_CONTABIL_FUNC.ind_deb_cre = 'C' THEN SUM(X225_CONTABIL_FUNC.vlr_lancto) ELSE 0 END) AS valor_credito,
                      (CASE WHEN X225_CONTABIL_FUNC.ind_deb_cre = 'D' THEN SUM(X225_CONTABIL_FUNC.vlr_lancto) ELSE 0 END) AS valor_debito
                   FROM X225_CONTABIL_FUNC
                   WHERE X225_CONTABIL_FUNC.cod_empresa = pEmpresa
                   AND X225_CONTABIL_FUNC.cod_estab = pEstab
                   AND (X225_CONTABIL_FUNC.data_operacao BETWEEN TO_DATE(pCompetencia,'DD/MM/RRRR') AND LAST_DAY(TO_DATE(pCompetencia,'DD/MM/RRRR')))
                   AND tipo_lancto = 'E'
                   GROUP BY cod_empresa,
                        cod_estab,
                        data_operacao,
                        X225_CONTABIL_FUNC.ind_deb_cre
                   ORDER BY cod_empresa,
                        cod_estab,
                        data_operacao,
                        X225_CONTABIL_FUNC.ind_deb_cre ) retorno
                 GROUP BY retorno.cod_empresa,
                      retorno.cod_estab,
                      LAST_DAY(retorno.data_operacao)
                 ORDER BY retorno.cod_empresa,
                      retorno.cod_estab,
                      LAST_DAY(retorno.data_operacao);

  CURSOR  Saldo_Novo_X227 (pEmpresa varchar2,
              pEstab varchar2,
              pCompetencia date) IS
              SELECT retorno.cod_empresa,
                 retorno.cod_estab,
                 LAST_DAY(retorno.data_operacao) AS data_operacao,
                 retorno.cod_conta,
                 retorno.ident_conta,
                 retorno.cod_custo,
                 retorno.ident_custo,
                 SUM(retorno.valor_credito) AS valor_credito,
                 SUM(retorno.valor_debito) AS valor_debito
                 FROM (SELECT  cod_empresa,
                           cod_estab,
                           data_operacao,
                           x2002_plano_contas.cod_conta,
                           x2002_plano_contas.ident_conta,
                           x2003_centro_custo.cod_custo,
                           x2003_centro_custo.ident_custo,
                           X225_CONTABIL_FUNC.ind_deb_cre,
                           (CASE WHEN X225_CONTABIL_FUNC.ind_deb_cre = 'C' THEN SUM(X225_CONTABIL_FUNC.vlr_lancto) ELSE 0 END) AS valor_credito,
                           (CASE WHEN X225_CONTABIL_FUNC.ind_deb_cre = 'D' THEN SUM(X225_CONTABIL_FUNC.vlr_lancto) ELSE 0 END) AS valor_debito
                       FROM X225_CONTABIL_FUNC
                       JOIN x2002_plano_contas ON x2002_plano_contas.ident_conta = X225_CONTABIL_FUNC.ident_conta
                       JOIN x2003_centro_custo ON x2003_centro_custo.ident_custo = X225_CONTABIL_FUNC.ident_custo
                       WHERE X225_CONTABIL_FUNC.cod_empresa = pEmpresa
                       AND X225_CONTABIL_FUNC.cod_estab = pEstab
                       AND (X225_CONTABIL_FUNC.data_operacao BETWEEN TO_DATE(pCompetencia,'DD/MM/RRRR') AND LAST_DAY(TO_DATE(pCompetencia,'DD/MM/RRRR')))
               GROUP BY cod_empresa,
                        cod_estab,
                        data_operacao,
                        x2002_plano_contas.cod_conta,
                        x2002_plano_contas.ident_conta,
                        x2003_centro_custo.cod_custo,
                        x2003_centro_custo.ident_custo,
                        X225_CONTABIL_FUNC.ind_deb_cre
                       ORDER BY cod_empresa,
                        cod_estab,
                        data_operacao,
                        x2002_plano_contas.cod_conta,
                        x2002_plano_contas.ident_conta,
                        x2003_centro_custo.cod_custo,
                        X225_CONTABIL_FUNC.ind_deb_cre ) retorno
              GROUP BY retorno.cod_empresa,
                   retorno.cod_estab,
                   LAST_DAY(retorno.data_operacao),
                   retorno.cod_conta,
                   retorno.ident_conta,
                   retorno.cod_custo,
                   retorno.ident_custo
              ORDER BY retorno.cod_empresa,
                   retorno.cod_estab,
                   LAST_DAY(retorno.data_operacao),
                   retorno.cod_conta,
                   retorno.ident_conta,
                   retorno.cod_custo,
                   retorno.ident_custo;


  CURSOR  Saldo_Novo_X226 (pEmpresa varchar2,
              pEstab varchar2,
              pCompetencia date) IS
              SELECT retorno.cod_empresa,
                 retorno.cod_estab,
                 LAST_DAY(retorno.data_operacao) AS data_operacao,
                 retorno.cod_conta,
                 retorno.ident_conta,
                 SUM(retorno.valor_credito) AS valor_credito,
                 SUM(retorno.valor_debito) AS valor_debito
                 FROM (SELECT  cod_empresa,
                           cod_estab,
                           data_operacao,
                           x2002_plano_contas.cod_conta,
                           x2002_plano_contas.ident_conta,
                           X225_CONTABIL_FUNC.ind_deb_cre,
                           (CASE WHEN X225_CONTABIL_FUNC.ind_deb_cre = 'C' THEN SUM(X225_CONTABIL_FUNC.vlr_lancto) ELSE 0 END) AS valor_credito,
                           (CASE WHEN X225_CONTABIL_FUNC.ind_deb_cre = 'D' THEN SUM(X225_CONTABIL_FUNC.vlr_lancto) ELSE 0 END) AS valor_debito
                       FROM X225_CONTABIL_FUNC
                       JOIN x2002_plano_contas ON x2002_plano_contas.ident_conta = X225_CONTABIL_FUNC.ident_conta
                       WHERE X225_CONTABIL_FUNC.cod_empresa = pEmpresa
                       AND X225_CONTABIL_FUNC.cod_estab = pEstab
                       AND (X225_CONTABIL_FUNC.data_operacao BETWEEN TO_DATE(pCompetencia,'DD/MM/RRRR') AND LAST_DAY(TO_DATE(pCompetencia,'DD/MM/RRRR')))
                       GROUP BY cod_empresa,
                        cod_estab,
                        data_operacao,
                        x2002_plano_contas.cod_conta,
                        x2002_plano_contas.ident_conta,
                        X225_CONTABIL_FUNC.ind_deb_cre
                       ORDER BY cod_empresa,
                        cod_estab,
                        data_operacao,
                        x2002_plano_contas.cod_conta,
                        x2002_plano_contas.ident_conta,
                        X225_CONTABIL_FUNC.ind_deb_cre                                    
            ) retorno
              GROUP BY retorno.cod_empresa,
                   retorno.cod_estab,
                   LAST_DAY(retorno.data_operacao),
                   retorno.cod_conta,
                   retorno.ident_conta
              ORDER BY retorno.cod_empresa,
                   retorno.cod_estab,
                   LAST_DAY(retorno.data_operacao),
                   retorno.cod_conta,
                   retorno.ident_conta;
END Z_FECH_CONT_FUNC_CPROC ;


