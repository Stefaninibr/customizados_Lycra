create or replace 
PACKAGE ZSAFX80_CPROC IS

 ---------------------------------------------------------------------------------------------------------
 -- Autor   : Andre Canello - Stefanini
 -- Created : 11/10/2016
 -- Purpose : Atualização dos lançamentos contábeis sem centro de custos na tabela X01_contabil com a 
 --           utilização de um codigo genérico (BR10) e posterior geração da SAFX80.
 ---------------------------------------------------------------------------------------------------------

   cLinha VARCHAR2(1000);
   cCod_Empresa VARCHAR2(5);
   cNome varchar2(100);

   nRegistro integer :=0 ;
   nFlag smallint :=0;

   nVLR_SALDO_CONT_ANT  x80_saldos_ccusto.vlr_saldo_cont_ant%type;
   cIND_DEB_CRED_ANT    x80_saldos_ccusto.ind_deb_cred_ant%type;

   nVLR_SALDO_CONT_ATU  x80_saldos_ccusto.vlr_saldo_cont_atu%type;
   cIND_DEB_CRED_ATU    x80_saldos_ccusto.ind_deb_cred_atu%type;


   FUNCTION PARAMETROS RETURN VARCHAR2;
   FUNCTION TIPO RETURN VARCHAR2;
   FUNCTION NOME RETURN VARCHAR2;
   FUNCTION DESCRICAO RETURN VARCHAR2;
   FUNCTION EXECUTAR(p_empresa      VARCHAR2,
                     p_estab        VARCHAR2,
                     p_competencia  DATE) RETURN NUMBER;

   CURSOR rX01_CONTABIL(p_empresa           VARCHAR2,
                        p_estab             VARCHAR2,
                        p_competencia       DATE)
   IS
      SELECT   retorno.cod_empresa,
               retorno.cod_estab,
               LAST_DAY(retorno.data_lancto) AS data_saldo,
               retorno.cod_conta,
               --retorno.ident_conta,
               retorno.cod_custo,
               --retorno.ident_custo,
               SUM(retorno.valor_credito) AS valor_credito,
               --TRIM(TO_CHAR(SUM(retorno.valor_credito)*100,'99999999999999999')) AS valor_credito,
               SUM(retorno.valor_debito) AS valor_debito
               --TRIM(TO_CHAR(SUM(retorno.valor_debito)*100,'99999999999999999')) AS valor_debito
               FROM  (SELECT  cod_empresa,
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
                              WHERE x01_contabil.cod_empresa = p_empresa
                              AND x01_contabil.cod_estab = p_estab
                              AND (x01_contabil.data_lancto BETWEEN TO_DATE(p_competencia,'DD/MM/YYYY') AND LAST_DAY(TO_DATE(p_competencia,'DD/MM/YYYY')))
                              GROUP BY    cod_empresa,
                                          cod_estab,
                                          data_lancto,
                                          x2002_plano_contas.cod_conta,
                                          x2002_plano_contas.ident_conta,
                                          x2003_centro_custo.cod_custo,
                                          x2003_centro_custo.ident_custo,
                                          x01_contabil.ind_deb_cre
                              ORDER BY    cod_empresa,
                                          cod_estab,
                                          data_lancto,
                                          x2002_plano_contas.cod_conta,
                                          x2002_plano_contas.ident_conta,
                                          x2003_centro_custo.cod_custo,
                                          x01_contabil.ind_deb_cre
                     ) retorno

      GROUP BY    retorno.cod_empresa,
                  retorno.cod_estab,
                  LAST_DAY(retorno.data_lancto),
                  retorno.cod_conta,
                  --retorno.ident_conta,
                  retorno.cod_custo
                  --retorno.ident_custo

      ORDER BY    retorno.cod_empresa,
                  retorno.cod_estab,
                  LAST_DAY(retorno.data_lancto),
                  retorno.cod_conta,
                  --retorno.ident_conta,
                  retorno.cod_custo
                  --retorno.ident_custo
      ;

   CURSOR rX01_CONTABIL_SEM_MOV(p_empresa           VARCHAR2,
                                p_estab             VARCHAR2,
                                p_competencia       DATE)
   IS
                              SELECT  cod_empresa,
                              cod_estab,
                              x80.dat_saldo,
                              x2002_plano_contas.cod_conta,
                              x2002_plano_contas.ident_conta,
                              x2003_centro_custo.cod_custo,
                              x2003_centro_custo.ident_custo,
                              x80.ind_deb_cred_atu ind_deb_cre,
                              x80.vlr_saldo_cont_atu
                              FROM x80_saldos_ccusto x80
                              JOIN x2002_plano_contas ON x2002_plano_contas.ident_conta = x80.ident_conta
                              JOIN x2003_centro_custo ON x2003_centro_custo.ident_custo = x80.ident_custo
                              WHERE x80.cod_empresa = p_Empresa
                              AND x80.cod_estab = p_Estab
                              AND x80.dat_saldo BETWEEN ADD_MONTHS(TO_DATE(p_competencia,'DD/MM/YYYY'),-1) AND ADD_MONTHS(LAST_DAY(TO_DATE(p_competencia,'DD/MM/YYYY')),-1)
                              AND NOT EXISTS (SELECT 1
                                              FROM x01_contabil
                                              JOIN x2002_plano_contas x2002 ON x2002.ident_conta = x01_contabil.ident_conta
                                              JOIN x2003_centro_custo x2003 ON x2003.ident_custo = x01_contabil.ident_custo
                                              WHERE x01_contabil.cod_empresa = x80.cod_empresa
                                              AND x01_contabil.cod_estab     = x80.cod_estab
                                              AND x01_contabil.data_lancto BETWEEN TO_DATE(p_competencia,'DD/MM/YYYY') AND LAST_DAY(TO_DATE(p_competencia,'DD/MM/YYYY'))
                                              --AND ident_conta   = x80.ident_conta
                                              AND x2002.cod_conta = x2002_plano_contas.cod_conta
                                              --AND x01_contabil.ident_custo   = x80.ident_custo
                                              AND x2003.cod_custo = x2003_centro_custo.cod_custo
                                              AND ROWNUM = 1)
      ;
END ZSAFX80_CPROC;