create or replace 
PACKAGE ZX52_RATEIO_CUSTO_FIXO_CPROC IS

--********************************************************************************************
--*** Autor   : Andre Canello                                                            *****
--*** Created : 2018                                                                     *****
--*** Purpose : Automacao do processo de rateio do custo fixo                            *****
--********************************************************************************************

  FUNCTION PARAMETROS     RETURN VARCHAR2;
  FUNCTION NOME           RETURN VARCHAR2;
  FUNCTION TIPO           RETURN VARCHAR2;
  FUNCTION VERSAO         RETURN VARCHAR2;
  FUNCTION DESCRICAO      RETURN VARCHAR2;
  FUNCTION MODULO         RETURN VARCHAR2;
  FUNCTION CLASSIFICACAO  RETURN VARCHAR2;
  FUNCTION EXECUTAR( P_PERIODO DATE,
                     P_EMPRESA VARCHAR2,
                     P_ESTAB   VARCHAR2,
                     P_VLR_CF  NUMBER ) RETURN VARCHAR2;

END ZX52_RATEIO_CUSTO_FIXO_CPROC;

