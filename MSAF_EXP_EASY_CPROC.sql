create or replace 
package MSAF_EXP_EASY_CPROC is

USUARIO_P     VARCHAR2(20);

  /* VARIAVEIS DE CONTROLE DE CABECALHO DE RELATORIO */

  FUNCTION Parametros RETURN    VARCHAR2;
  FUNCTION Nome       RETURN    VARCHAR2;
  FUNCTION Tipo       RETURN    VARCHAR2;
  FUNCTION Versao     RETURN    VARCHAR2;
  FUNCTION Descricao  RETURN    VARCHAR2;
  FUNCTION Modulo     RETURN    VARCHAR2;
  FUNCTION Classificacao RETURN VARCHAR2;

  function executar(p_empresa varchar2,
                    p_estab   varchar2,
                    p_dataini date,
                    p_datafin date,
                    p_arquivo varchar2) RETURN INTEGER;


end MSAF_EXP_EASY_CPROC;