create or replace 
PACKAGE ZSAFX227_CPROC IS

 ---------------------------------------------------------------------------------------------------------
 -- Autor   : Filipe Rezes - Stefanini
 -- Created : 15/05/2018
 -- Purpose : Atualização dos lançamentos contábeis sem centro de custos na tabela x225_contabil_func com a 
 --           utilização de um codigo genérico (BR10) e posterior geração da SAFX227.
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



   CURSOR rX225_CONTABIL(p_empresa           VARCHAR2,
                        p_estab             VARCHAR2,
                        p_competencia       DATE)
   IS
 SELECT   retorno.cod_empresa,
               retorno.cod_estab,
               LAST_DAY(retorno.data_operacao) AS data_saldo,
               retorno.cod_conta,
               retorno.cod_custo,
               SUM(retorno.valor_credito) AS valor_credito,
               SUM(retorno.valor_debito) AS valor_debito
               FROM  (SELECT  cod_empresa,
                              cod_estab,
                              data_operacao,
                              x2002_plano_contas.cod_conta,
                              x2002_plano_contas.ident_conta,
                              x2003_centro_custo.cod_custo,
                              x2003_centro_custo.ident_custo,
                              x225.ind_deb_cre,
                              (CASE WHEN x225.ind_deb_cre = 'C' THEN SUM(x225.vlr_lancto) ELSE 0 END) AS valor_credito,
                              (CASE WHEN x225.ind_deb_cre = 'D' THEN SUM(x225.vlr_lancto) ELSE 0 END) AS valor_debito
                              FROM x225_contabil_func x225
                              JOIN x2002_plano_contas ON x2002_plano_contas.ident_conta = x225.ident_conta
                              JOIN x2003_centro_custo ON x2003_centro_custo.ident_custo = x225.ident_custo
                              WHERE x225.cod_empresa = p_empresa
                              AND x225.cod_estab = p_estab
                              AND (x225.data_operacao BETWEEN p_competencia  AND LAST_DAY(p_competencia))
                              GROUP BY    cod_empresa,
                                          cod_estab,
                                          data_operacao,
                                          x2002_plano_contas.cod_conta,
                                          x2002_plano_contas.ident_conta,
                                          x2003_centro_custo.cod_custo,
                                          x2003_centro_custo.ident_custo,
                                          x225.ind_deb_cre
                              ORDER BY    cod_empresa,
                                          cod_estab,
                                          data_operacao,
                                          x2002_plano_contas.cod_conta,
                                          x2002_plano_contas.ident_conta,
                                          x2003_centro_custo.cod_custo,
                                          x225.ind_deb_cre
                     ) retorno

      GROUP BY    retorno.cod_empresa,
                  retorno.cod_estab,
                  LAST_DAY(retorno.data_operacao),
                  retorno.cod_conta,
                  retorno.cod_custo

      ORDER BY    retorno.cod_empresa,
                  retorno.cod_estab,
                  LAST_DAY(retorno.data_operacao),
                  retorno.cod_conta,
                  retorno.cod_custo;

   CURSOR rX227_CONTABIL_SEM_MOV(p_empresa           VARCHAR2,
                                p_estab             VARCHAR2,
                                p_competencia       DATE)
   IS
                              SELECT  x227.cod_empresa,
                              x227.cod_estab,
                              x227.dat_saldo,
                              x2002_plano_contas.cod_conta,
                              x2002_plano_contas.ident_conta,
                              x2003_centro_custo.cod_custo,
                              x2003_centro_custo.ident_custo,
                              x227.ind_saldo_fim ind_deb_cre,
                              x227.vlr_saldo_fim
                              FROM x227_saldos_ccusto_func x227
                              JOIN x2002_plano_contas ON x2002_plano_contas.ident_conta = x227.ident_conta
                              JOIN x2003_centro_custo ON x2003_centro_custo.ident_custo = x227.ident_custo
                              WHERE x227.cod_empresa = p_Empresa
                              AND x227.cod_estab = p_Estab
                              AND x227.dat_saldo BETWEEN ADD_MONTHS(TO_DATE(p_competencia,'DD/MM/YYYY'),-1) AND ADD_MONTHS(LAST_DAY(TO_DATE(p_competencia,'DD/MM/YYYY')),-1)
                              AND NOT EXISTS (SELECT 1
                                              FROM x227_saldos_ccusto_func x227
                                              JOIN x2002_plano_contas x2002 ON x2002.ident_conta = x227.ident_conta
                                              JOIN x2003_centro_custo x2003 ON x2003.ident_custo = x227.ident_custo
                                              WHERE x227.cod_empresa = x227.cod_empresa
                                              AND x227.cod_estab     = x227.cod_estab
                                              AND x227.dat_saldo BETWEEN TO_DATE(p_competencia,'DD/MM/YYYY') AND LAST_DAY(TO_DATE(p_competencia,'DD/MM/YYYY'))
                                              AND x2002.cod_conta = x2002_plano_contas.cod_conta
                                              AND x2003.cod_custo = x2003_centro_custo.cod_custo
                                              AND ROWNUM = 1)
                              AND (X2002_PLANO_CONTAS.COD_CONTA,X2003_CENTRO_CUSTO.COD_CUSTO) NOT IN 
                                  (SELECT COD_CONTA, COD_CUSTO FROM SAFX227 
                                   WHERE COD_EMPRESA = X227.COD_EMPRESA
                                   AND COD_ESTAB = X227.COD_ESTAB
                                   AND DAT_SALDO = TO_CHAR(LAST_DAY(TO_DATE(p_competencia,'DD/MM/YYYY')),'YYYYMMDD')
                                   AND COD_CONTA = X2002_PLANO_CONTAS.COD_CONTA 
                                   AND COD_CUSTO = X2003_CENTRO_CUSTO.COD_CUSTO
                                   AND ROWNUM <= 1)                       
                              AND X227.VLR_SALDO_FIM <> 0                                              
      ;
END ZSAFX227_CPROC;