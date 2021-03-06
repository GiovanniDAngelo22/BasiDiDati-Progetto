
-- procedura per automatizzare le prenotazioni

CREATE OR REPLACE PROCEDURE ORGANIZZA_ORARI_PRENOTAZIONI IS
ANNO_CORRENTE NUMBER; 
FLAG NUMBER; 
BEGIN 
SELECT TO_NUMBER(TO_CHAR(TRUNC(SYSDATE,'YEAR'),'YYYY')) INTO ANNO_CORRENTE FROM DUAL; 
IF MOD(ANNO_CORRENTE,4) = 0
THEN FLAG:=1; 
ELSE FLAG:=0; 
END IF;

FOR J IN 1..5 			-- Per ogni sala della Clinica
LOOP
FOR I IN 1..365+FLAG    -- Per tutti i giorni dell'anno
LOOP  
IF TO_CHAR(TRUNC(SYSDATE,'YEAR')+I,'D') <> '7' 
AND TRUNC(SYSDATE,'YEAR')+I <> TO_DATE('06/01','DD/MM') 
AND TRUNC(SYSDATE,'YEAR')+I <> TO_DATE('25/04','DD/MM')
AND  TRUNC(SYSDATE,'YEAR')+I <> TO_DATE('01/05','DD/MM') 
AND  TRUNC(SYSDATE,'YEAR')+I <> TO_DATE('22/05','DD/MM')
AND  TRUNC(SYSDATE,'YEAR')+I <> TO_DATE('25/05','DD/MM')
AND  TRUNC(SYSDATE,'YEAR')+I <> TO_DATE('02/06','DD/MM')
AND  TRUNC(SYSDATE,'YEAR')+I <> TO_DATE('15/08','DD/MM') 
AND  TRUNC(SYSDATE,'YEAR')+I <> TO_DATE('11/10','DD/MM')
AND  TRUNC(SYSDATE,'YEAR')+I <> TO_DATE('01/11','DD/MM') 
AND	 TRUNC(SYSDATE,'YEAR')+I <> TO_DATE('02/11','DD/MM') 
AND  TRUNC(SYSDATE,'YEAR')+I <> TO_DATE('08/12','DD/MM') 
AND  TRUNC(SYSDATE,'YEAR')+I NOT BETWEEN TO_DATE('24/12','DD/MM') AND TO_DATE('31/12','DD/MM')
	THEN  -- Finché non è uno di questi giorni inserisci 24 tuple in Prenotazione 
	INSERT INTO PRENOTAZIONE(DATA_ORA,NUM_SALA)
	SELECT (1/48)*16+TRUNC(SYSDATE,'YEAR')+I+(1/48)*LEVEL , J
	FROM DUAL 
	CONNECT BY LEVEL<=24
	ORDER BY LEVEL;
END IF; 
END LOOP; 
END LOOP; 
END; 


/

SHO ERR; 


CREATE OR REPLACE PROCEDURE ORGANIZZA_TURNI_DOTTORI IS 
ID_GIORNO_CORRENTE NUMBER;
OFFSET NUMBER;
COD_TURNO_F NUMBER; 
NUMERO_DOT NUMBER;
NUMERO NUMBER; 
BEGIN
SELECT TO_NUMBER(TO_CHAR(SYSDATE,'D')) INTO ID_GIORNO_CORRENTE
FROM DUAL;


IF ID_GIORNO_CORRENTE = 7
THEN
	OFFSET :=1;
	ID_GIORNO_CORRENTE:=1;
ELSE OFFSET := 0;
END IF;

SELECT COUNT(*) INTO NUMERO
FROM DOTTORE; 

IF (MOD(NUMERO, 2) = 0)		-- Questo calcolo ci permette di far lavorare tutti i dottori, nessuno escluso, nel caso in cui il numero
							-- di dottori presente nella clinica sia dispari
THEN
NUMERO_DOT:= NUMERO/2; 
ELSE
NUMERO_DOT:=(NUMERO/2) + 1; 
END IF; 


FOR I IN ID_GIORNO_CORRENTE..6 LOOP  -- Per ogni giorno della settimana
			INSERT INTO EFFETTUA_T (CF_DOT, COD_TURNO, DATA_T) -- Inserisci i dottori randomicamente
				SELECT CF_DOT, 1, TRUNC(SYSDATE+I-ID_GIORNO_CORRENTE+OFFSET)
				FROM DOTTORE 
				WHERE ROWNUM<=NUMERO_DOT
				ORDER BY DBMS_RANDOM.VALUE;
		END LOOP; --FINE FOR PER I TURNI DI MATTINA

--Il seguente FOR assegna i turni per il pomeriggio.
FOR I IN ID_GIORNO_CORRENTE..6 LOOP 
			INSERT INTO EFFETTUA_T (CF_DOT, COD_TURNO, DATA_T)
				SELECT CF_DOT, 2, TRUNC(SYSDATE+I-ID_GIORNO_CORRENTE+OFFSET)
				FROM DOTTORE 
				WHERE  ROWNUM<=NUMERO_DOT AND CF_DOT NOT IN (
					SELECT T.CF_DOT FROM EFFETTUA_T T WHERE TRUNC(DATA_T)=TRUNC(SYSDATE+I-ID_GIORNO_CORRENTE+OFFSET))
				ORDER BY DBMS_RANDOM.VALUE;
		END LOOP; 
END; 

/
SHO ERR; 

 -- Procedure automaticamente richiamata e assegna automaticamente il dottore per il servizio appena prenotato

CREATE OR REPLACE PROCEDURE ASSEGNA_DOT (NUMERO_SALA NUMBER, DATA_P DATE ) IS
TURNO_DA_ASS NUMBER;
ORARIO_NON_DISP EXCEPTION;

CF_FLAG CHAR(16); 

BEGIN 
TURNO_DA_ASS :=0;
IF TO_CHAR(DATA_P, 'HH24:MI')>=TO_CHAR(TO_DATE('8:30', 'HH24:MI'), 'HH24:MI') AND TO_CHAR(DATA_P, 'HH24:MI') < TO_CHAR(TO_DATE('14:30', 'HH24:MI'), 'HH24:MI') 
THEN 
TURNO_DA_ASS :=1;
ELSE IF TO_CHAR(DATA_P, 'HH24:MI')>=TO_CHAR(TO_DATE('14:30', 'HH24:MI'), 'HH24:MI') AND TO_CHAR(DATA_P, 'HH24:MI') < TO_CHAR(TO_DATE('20:30', 'HH24:MI'), 'HH24:MI')
THEN
TURNO_DA_ASS :=2;
END IF;
END IF;

IF TURNO_DA_ASS = 0
THEN 
RAISE ORARIO_NON_DISP;
END IF;

SELECT CF_DOT INTO CF_FLAG 
FROM (SELECT * FROM EFFETTUA_T E JOIN TURNO T ON E.COD_TURNO=T.COD_TURNO 
WHERE T.COD_TURNO = TURNO_DA_ASS AND TO_CHAR(DATA_P, 'DD/MM/YYYY')=TO_CHAR(E.DATA_T, 'DD/MM/YYYY') AND E.CF_DOT NOT IN -- Il dottore non deve essere occupato
(SELECT CF_DOT FROM LAVORA_IN WHERE TO_CHAR(DATA_ORA, 'DD/MM/YYYY HH24:MI')=TO_CHAR(DATA_P, 'DD/MM/YYYY HH24:MI')) 
ORDER BY DBMS_RANDOM.VALUE) 
WHERE ROWNUM<=1;

INSERT INTO LAVORA_IN(CF_DOT, NUM_SALA, DATA_ORA)
VALUES  (CF_FLAG, NUMERO_SALA, DATA_P);

EXCEPTION

WHEN ORARIO_NON_DISP
THEN RAISE_APPLICATION_ERROR(-20102,'ORA SELEZIONATA NON VALIDA'); 

END; 





/

SHO ERR; 


CREATE OR REPLACE PROCEDURE INSERISCI_PRENOTAZIONE (DATA_INS DATE, CF_INS CHAR, TIPO_INS VARCHAR,SALA_INS NUMBER) IS
NUM_DOTTORI NUMBER; 
NUM_PREN NUMBER;
PRENOTAZIONE_DA_MODIFICARE NUMBER; 
NUM_DOTTORI_OCCUPATI NUMBER;
SALE_DISPONIBILI NUMBER;
FLAG NUMBER;
FLAG_2 NUMBER;
NUMERO_FIALE_SANGUE NUMBER;
DISCRIMINATORE NUMBER;
NUM_PREN_STESSA_PERSONA NUMBER;
INIZIO_TURNO_VAR DATE;


SALA_OCCUPATA EXCEPTION;
NO_DOTTORI_DISPONIBILI EXCEPTION;
CF_INESISTENTE EXCEPTION;
ONNIPRESENZA EXCEPTION;
INSEMINAZIONE_NON_DISPONIBILE EXCEPTION;
BEGIN
PRENOTAZIONE_DA_MODIFICARE := 0;
NUM_DOTTORI:=0; 
NUM_PREN:=0; 
SALE_DISPONIBILI:=0;
FLAG:=0;
FLAG_2 :=0;
--PRENDO L'INIZIO TURNO POMERIDIANO, CHE CORRISPONDE ALLE 14:30
SELECT INIZIO_TURNO INTO INIZIO_TURNO_VAR FROM TURNO WHERE COD_TURNO='2';

IF (TIPO_INS = 'INSEMINAZIONE' )
THEN SELECT COUNT(*) INTO NUMERO_FIALE_SANGUE FROM FIALA_SANGUE WHERE CF_CLI = CF_INS AND SANO = 'SI';
IF NUMERO_FIALE_SANGUE <1
THEN RAISE INSEMINAZIONE_NON_DISPONIBILE;
END IF;
END IF;



IF (TO_CHAR(DATA_INS, 'HH24:MI') < TO_CHAR(INIZIO_TURNO_VAR, 'HH24:MI'))
THEN 
SELECT COUNT(*) INTO NUM_DOTTORI
FROM EFFETTUA_T E JOIN TURNO T ON E.COD_TURNO=T.COD_TURNO 
WHERE TO_CHAR(E.DATA_T,'DD/MM/YYYY')=TO_CHAR(DATA_INS,'DD/MM/YYYY') AND T.COD_TURNO='1';

SELECT COUNT(*) INTO NUM_DOTTORI_OCCUPATI FROM LAVORA_IN WHERE TO_CHAR(DATA_INS, 'DD/MM/YYYY HH24:MI') = TO_CHAR(DATA_ORA, 'DD/MM/YYYY HH24:MI');

NUM_DOTTORI := NUM_DOTTORI - NUM_DOTTORI_OCCUPATI;

ELSE 

SELECT COUNT(*) INTO NUM_DOTTORI
FROM EFFETTUA_T E JOIN TURNO T ON E.COD_TURNO=T.COD_TURNO 
WHERE TO_CHAR(E.DATA_T,'DD/MM/YYYY')=TO_CHAR(DATA_INS,'DD/MM/YYYY') AND T.COD_TURNO='2';

SELECT COUNT(*) INTO NUM_DOTTORI_OCCUPATI FROM LAVORA_IN WHERE TO_CHAR(DATA_INS, 'DD/MM/YYYY HH24:MI') = TO_CHAR(DATA_ORA, 'DD/MM/YYYY HH24:MI');

NUM_DOTTORI := NUM_DOTTORI - NUM_DOTTORI_OCCUPATI;

END IF; 

SELECT COUNT(*) INTO NUM_PREN 
FROM PRENOTAZIONE 
WHERE TO_CHAR(DATA_ORA, 'DD/MM/YYYY HH24:MI')=TO_CHAR(DATA_INS,'DD/MM/YYYY HH24:MI') AND  CF_CLI IS NOT NULL AND CF_DON IS NOT NULL;


SELECT COUNT(*) INTO NUM_PREN_STESSA_PERSONA
FROM PRENOTAZIONE 
WHERE TO_CHAR(DATA_ORA, 'DD/MM/YYYY HH24:MI')=TO_CHAR(DATA_INS,'DD/MM/YYYY HH24:MI') AND  (CF_CLI = CF_INS OR  CF_DON = CF_INS);

IF (NUM_PREN_STESSA_PERSONA > 0)
THEN RAISE ONNIPRESENZA;
END IF;

IF (NUM_DOTTORI <= NUM_PREN)
THEN RAISE NO_DOTTORI_DISPONIBILI; 
END IF; 



SELECT COUNT(*) INTO DISCRIMINATORE 
FROM PRENOTAZIONE
WHERE TO_CHAR(DATA_ORA, 'DD/MM/YYYY HH24:MI')=TO_CHAR(DATA_INS,'DD/MM/YYYY HH24:MI') AND NUM_SALA = SALA_INS AND (CF_CLI IS NOT NULL OR CF_DON IS NOT NULL);

IF (DISCRIMINATORE > 0)
THEN RAISE SALA_OCCUPATA;
END IF;




SELECT ID_PREN INTO PRENOTAZIONE_DA_MODIFICARE FROM PRENOTAZIONE WHERE TO_CHAR(DATA_ORA, 'DD/MM/YYYY HH24:MI')=TO_CHAR(DATA_INS,'DD/MM/YYYY HH24:MI') AND NUM_SALA = SALA_INS;

SELECT COUNT(*) INTO FLAG FROM DONATORE WHERE CF_DON = CF_INS;
IF FLAG >0
THEN
UPDATE PRENOTAZIONE
SET TIPO_PREN = TIPO_INS, CF_DON = CF_INS
WHERE ID_PREN = PRENOTAZIONE_DA_MODIFICARE;
END IF;



SELECT COUNT(*) INTO FLAG_2 FROM CLIENTE WHERE CF_CLI = CF_INS;
IF FLAG_2 >0
THEN
UPDATE PRENOTAZIONE
SET TIPO_PREN = TIPO_INS, CF_CLI = CF_INS
WHERE ID_PREN = PRENOTAZIONE_DA_MODIFICARE;
END IF;

IF FLAG = 0 AND FLAG_2 = 0
THEN RAISE CF_INESISTENTE;
END IF;

ASSEGNA_DOT(SALA_INS, DATA_INS);

EXCEPTION
WHEN NO_DOTTORI_DISPONIBILI
THEN RAISE_APPLICATION_ERROR(-20027,'NON CI SONO DOTTORI DISPONIBILI PER PRENOTARE'); 

WHEN SALA_OCCUPATA
THEN RAISE_APPLICATION_ERROR(-20037,'LA SALA E GIA OCCUPATA'); 

WHEN CF_INESISTENTE
THEN RAISE_APPLICATION_ERROR(-20029,'NON SO A CHI APPARTENGA QUESTO CODICE FISCALE'); 


WHEN ONNIPRESENZA
THEN RAISE_APPLICATION_ERROR(-20049,'IL CLIENTE E GIA IN UN ALTRA SALA'); 
 
WHEN INSEMINAZIONE_NON_DISPONIBILE
THEN RAISE_APPLICATION_ERROR(-20109,'INSEMINAZIONE NON DISPONIBILE. FIALA DEL SANGUE RELATIVA NON TROVATA OPPURE INFETTA');
 
END;

/ 

SHO ERR; 

CREATE OR REPLACE PROCEDURE ELIMINA_PRENOTAZIONE (ID NUMBER ) IS 
FLAG NUMBER; 
NO_PREN EXCEPTION; 
DATAS DATE; 
NUMSALA NUMBER; 
BEGIN
SELECT COUNT(*) INTO FLAG 
FROM PRENOTAZIONE
WHERE ID_PREN=ID; 

IF FLAG>0
THEN 
UPDATE PRENOTAZIONE
SET CF_CLI=NULL, CF_DON=NULL, TIPO_PREN=NULL
WHERE ID_PREN=ID; 

SELECT DATA_ORA, NUM_SALA INTO DATAS, NUMSALA
FROM PRENOTAZIONE 
WHERE ID_PREN=ID; 

DE_ASSEGNA_DOT(DATAS, NUMSALA); 

ELSE 
RAISE NO_PREN; 
END IF; 
EXCEPTION
WHEN NO_PREN
THEN RAISE_APPLICATION_ERROR('-20034', 'LA TUPLA E VUOTA'); 
END; 

/

SHO ERR; 
-- SI RICHIAMA 
CREATE OR REPLACE PROCEDURE DE_ASSEGNA_DOT (DATAS DATE, NUMSALA NUMBER) IS
BEGIN
DELETE LAVORA_IN WHERE DATA_ORA = DATAS AND NUM_SALA = NUMSALA;
END; 


/ 

SHO ERR; 

CREATE OR REPLACE PROCEDURE INSERISCI_FIALA_SANGUE (ID_PRENO NUMBER, COD_ESAME CHAR, FLAG NUMBER) IS
ID_FIALA CHAR(4); 
CF_DA_INSERIRE CHAR(16); 
DATA_DA_INSERIRE DATE; 
ID_CRIO_DA_INS NUMBER; 

FLAG_COUNT NUMBER; 
BEGIN 
FLAG_COUNT:=0; 
SELECT COUNT(*) INTO FLAG_COUNT FROM PRENOTAZIONE WHERE CF_CLI IS NOT NULL AND ID_PREN=ID_PRENO; 

IF(FLAG_COUNT>0)
THEN 
	SELECT CF_CLI, DATA_ORA INTO CF_DA_INSERIRE, DATA_DA_INSERIRE
	FROM PRENOTAZIONE
	WHERE ID_PREN=ID_PRENO; 
ELSE 
	SELECT CF_DON, DATA_ORA INTO CF_DA_INSERIRE, DATA_DA_INSERIRE
	FROM PRENOTAZIONE 
	WHERE ID_PREN=ID_PRENO; 
END IF; 
	
ID_FIALA:= 'F'||TO_CHAR(ID_FIALA_SE_S.NEXTVAL); 
	
SELECT GET_ID_CRIO(1) INTO ID_CRIO_DA_INS FROM DUAL; 
	
IF (FLAG = 2 AND FLAG_COUNT=0) -- FLAG=2 VUOL DIRE CHE E' UN ESAME DEL SANGUE CLASSICO ED E UN DONATORE
THEN 
	INSERT INTO FIALA_SANGUE (DATA_SANGUE, ID_FIALA_SA, CF_DON, ID_CRIO_SANGUE, COD_E_SANGUE )
	SELECT DATA_DA_INSERIRE, ID_FIALA, CF_DA_INSERIRE, ID_CRIO_DA_INS, COD_ESAME FROM DUAL; 
	
ELSE IF (FLAG =2 AND FLAG_COUNT>0) -- VUOL DIRE CHE E' UN CLIENTE
THEN 
	INSERT INTO FIALA_SANGUE (DATA_SANGUE, ID_FIALA_SA, CF_DON, ID_CRIO_SANGUE, COD_E_SANGUE )
	SELECT DATA_DA_INSERIRE, ID_FIALA, CF_DA_INSERIRE, ID_CRIO_DA_INS, COD_ESAME FROM DUAL;
	
ELSE 

	INSERT INTO FIALA_SANGUE (DATA_SANGUE, ID_FIALA_SA, CF_CLI, ID_CRIO_SANGUE, COD_E_FERTILITA)
	SELECT DATA_DA_INSERIRE, ID_FIALA, CF_DA_INSERIRE, ID_CRIO_DA_INS, COD_ESAME FROM DUAL;
END IF;
END IF; 
END; 


/

SHO ERR; 

CREATE OR REPLACE PROCEDURE INSERT_ES_SANGUE (ID_INS NUMBER, TPHA_INS NUMBER, VLDRL_INS NUMBER, LINF_INS NUMBER) IS
DATA_PREN DATE; 
CODICE CHAR(8); 

FLAG NUMBER; 

COD_INS CHAR(8); 

BEGIN 
SELECT DATA_ORA INTO DATA_PREN 
FROM PRENOTAZIONE
WHERE ID_PREN=ID_INS; 

-- POICHE SIA IL CLIENTE CHE IL DONATORE DEVONO FARE L'ESAME DEL SANGUE, RIUSCIRE AD OTTENERE IL CODICE DELLA CARTELLA CLINICA
-- E PIU' COMPLESSO. INFATTI DOBBIAMO TENERE CONTO DI COME E' STRUTTURATA LA TABELLA PRENOTAZIONE, CHE HA SIA IL CODICE FISCALE DEL CLIENTE CHE DEL
-- DONATORE. QUINDI DOBBIAMO PRIMA FILTRARE LE INFORMAZIONI PER OTTENERE IL GIUSTO CODICE. 

FLAG:= 0;

SELECT COUNT(*) INTO FLAG 
FROM PRENOTAZIONE P JOIN CLIENTE C ON C.CF_CLI=P.CF_CLI 
WHERE ID_PREN=ID_INS; 

IF (FLAG>0) 
THEN 

	SELECT C_CLINICA INTO CODICE 
	FROM (PRENOTAZIONE P JOIN CLIENTE C ON C.CF_CLI=P.CF_CLI) JOIN CARTELLA_CLINICA CC ON CC.CF_CLI=C.CF_CLI
	WHERE ID_PREN=ID_INS; 
	
ELSE 
	
		SELECT COUNT(*) INTO FLAG 
		FROM PRENOTAZIONE P JOIN DONATORE D ON D.CF_DON=P.CF_DON
		WHERE ID_PREN=ID_INS; 
	
		IF (FLAG>0)
		THEN 
		SELECT C_CLINICA INTO CODICE -- CERCO LA CARTELLA CLINICA ASSOCIATA 
		FROM (PRENOTAZIONE P JOIN DONATORE D ON D.CF_DON=P.CF_DON) JOIN CARTELLA_CLINICA CC ON CC.CF_DON=D.CF_DON 
		WHERE ID_PREN=ID_INS; 
		END IF; 
	
END IF; 

COD_INS:='CSA'||TO_CHAR(COD_SANGUE_S.NEXTVAL); 

INSERT INTO SANGUE (COD_E_SANGUE, ID_PREN, C_CLINICA, DATA_E_SA, TPHA, VLDRL, LINFOCITICD4)
SELECT COD_INS, ID_INS, CODICE, DATA_PREN, TPHA_INS, VLDRL_INS, LINF_INS FROM DUAL; 

INSERISCI_FIALA_SANGUE (ID_INS, COD_INS, 2);

END; 
/

SHO ERR; 



CREATE OR REPLACE PROCEDURE INSERT_ES_SPERM (ID_INS NUMBER, CNTZ_INS NUMBER, VOL_INS NUMBER, MOT_INS NUMBER, PH_INS NUMBER ) IS 
DATA_PREN DATE; 
CODICE  CHAR(8); 

COD_INS CHAR(8); 

BEGIN 

SELECT DATA_ORA INTO DATA_PREN 
FROM PRENOTAZIONE
WHERE ID_PREN=ID_INS; 

SELECT C_CLINICA INTO CODICE -- CERCO LA CARTELLA CLINICA ASSOCIATA 
FROM (PRENOTAZIONE P JOIN DONATORE D ON D.CF_DON=P.CF_DON) JOIN CARTELLA_CLINICA CC ON CC.CF_DON=D.CF_DON 
WHERE ID_PREN=ID_INS; 

COD_INS:='CSP'||TO_CHAR(COD_SPERM_S.NEXTVAL);

INSERT INTO SPERMIOGRAMMA(COD_E_SPERMIOGRAMMA, ID_PREN, C_CLINICA, DATA_E_SP, CNTZ,VOL,MOT,PH)
SELECT COD_INS, ID_INS, CODICE, DATA_PREN, CNTZ_INS, VOL_INS, MOT_INS, PH_INS FROM DUAL; 


END; 

/ 

SHO ERR; 


CREATE OR REPLACE PROCEDURE INSERT_ES_GENET(ID_INS NUMBER, IRT_INS NUMBER, ESO_INS NUMBER, CARIO_INS CHAR) IS
DATA_PREN DATE; 
CODICE CHAR(8); 

COD_INS CHAR(8); 

BEGIN 

SELECT DATA_ORA INTO DATA_PREN 
FROM PRENOTAZIONE 
WHERE ID_PREN=ID_INS; 

SELECT C_CLINICA INTO CODICE 
FROM (PRENOTAZIONE P JOIN DONATORE D ON D.CF_DON=P.CF_DON) JOIN CARTELLA_CLINICA CC ON CC.CF_DON=D.CF_DON 
WHERE ID_PREN=ID_INS; 

COD_INS:='CGE'||TO_CHAR(COD_GEN_S.NEXTVAL);

INSERT INTO GENETICO(COD_E_GENETICO, ID_PREN, C_CLINICA, DATA_GEN, IRT, ESONE7, CARIOTIPO)
SELECT COD_INS, ID_INS, CODICE, DATA_PREN, IRT_INS, ESO_INS, CARIO_INS FROM DUAL; 

END; 
/
SHO ERR; 


CREATE OR REPLACE PROCEDURE INSERT_ES_FERT(ID_INS NUMBER, PROL_INS NUMBER, FSH_INS NUMBER) IS 
DATA_PREN DATE; 
CODICE CHAR(8); 

COD_INS CHAR(8); 

BEGIN 
SELECT CC.C_CLINICA, P.DATA_ORA INTO CODICE, DATA_PREN
FROM (PRENOTAZIONE P JOIN CLIENTE C ON C.CF_CLI=P.CF_CLI) JOIN CARTELLA_CLINICA CC ON CC.CF_CLI=C.CF_CLI
WHERE P.ID_PREN=ID_INS; 

COD_INS:='CFE'||TO_CHAR(COD_FERT_S.NEXTVAL);

INSERT INTO FERTILITA(COD_E_FERTILITA, ID_PREN, C_CLINICA, DATA_E_FE, PROLATTINA, FSH)
SELECT COD_INS, ID_INS, CODICE, DATA_PREN, PROL_INS, FSH_INS FROM DUAL; 

INSERISCI_FIALA_SANGUE (ID_INS, COD_INS, 1);


END; 

/
SHO ERR; 

-- SI RICHIAMA AUTOMATICAMENTE 

CREATE OR REPLACE PROCEDURE APRI_CARTELLA (CF_INS CHAR) IS
ID_CC CHAR(8); 
FLAG_DON NUMBER; 
FLAG_CLI NUMBER; 
SESSO_FLAG CHAR(1); 


SCONOSCIUTO EXCEPTION; 

BEGIN 

FLAG_DON:=0; 
FLAG_CLI:=0; 

SELECT COUNT(*), MAX(SESSO_CLI) INTO FLAG_CLI, SESSO_FLAG FROM CLIENTE WHERE CF_CLI=CF_INS; 
SELECT COUNT(*) INTO FLAG_DON FROM DONATORE WHERE CF_DON=CF_INS; 

IF (FLAG_DON>0)
THEN
ID_CC:= 'CC'||TO_CHAR(ID_CC_S.NEXTVAL); 

INSERT INTO CARTELLA_CLINICA(C_CLINICA, DATA_CREAZIONE, CF_DON)
SELECT ID_CC, SYSDATE, CF_INS FROM DUAL; 

ELSE IF (FLAG_CLI>0 AND SESSO_FLAG = 'F')
THEN 
ID_CC:= 'CC'||TO_CHAR(ID_CC_S.NEXTVAL);

INSERT INTO CARTELLA_CLINICA(C_CLINICA, DATA_CREAZIONE, CF_CLI)
SELECT ID_CC, SYSDATE, CF_INS FROM DUAL; 
ELSE IF (FLAG_CLI>0  AND SESSO_FLAG = 'M')
THEN  RETURN;
ELSE
RAISE SCONOSCIUTO; 
END IF; 
END IF;
END IF; 

EXCEPTION
WHEN SCONOSCIUTO
THEN RAISE_APPLICATION_ERROR(-20234, 'QUESTA PERSONA NON E REGISTRATA');
END;

/
SHO ERR; 


CREATE OR REPLACE PROCEDURE INSERISCI_CLIENTE (CF CHAR, NOME CHAR, COGNOME CHAR, DATA_N DATE, S CHAR, CITTA CHAR, VIA CHAR, TELEFONO CHAR, PROVINCIA CHAR) IS 
BEGIN 

INSERT INTO CLIENTE (CF_CLI, NOME_CLI, COGNOME_CLI, DN_CLI, SESSO_CLI, CITTA_CLI, VIA_CLI, TELEFONO_CLI, PROV_CLI)
SELECT CF, NOME, COGNOME, DATA_N, S, CITTA, VIA, TELEFONO, PROVINCIA FROM DUAL; 

APRI_CARTELLA(CF); 

END; 

/
SHO ERR; 


CREATE OR REPLACE PROCEDURE INSERISCI_DONATORE(CF CHAR, NOME CHAR, COGNOME CHAR, DATA_N DATE, CITTA CHAR, VIA CHAR, G CHAR, OCC CHAR, PE NUMBER, CAP CHAR, AN CHAR, ETN CHAR, ALT NUMBER, TELEFONO CHAR, PROVINCIA CHAR) IS 
BEGIN 
INSERT INTO DONATORE(CF_DON, NOME_DON, COGNOME_DON, DN_DON, CITTA_DON, VIA_DON, G_SANGUIGNO, OCCHI, PESO, CAPELLI, ANONIMATO, ETNIA, ALTEZZA, TELEFONO_DON, PROV_DON)
SELECT CF, NOME, COGNOME, DATA_N, CITTA, VIA, G, OCC, PE, CAP, AN, ETN, ALT, TELEFONO, PROVINCIA FROM DUAL; 

APRI_CARTELLA(CF); 

END; 


/ 
SHO ERR; 



CREATE OR REPLACE PROCEDURE ACQUISTO_FIALA (ID_FIALA CHAR, CF_INS CHAR, METODO_PAG CHAR) IS 
FLAG_ESIST NUMBER; 
FLAG_VEND NUMBER; 
FLAG_SANO CHAR(2); 
COD_FATTURA CHAR(10);
TIPO_PAG VARCHAR(20); 


NO_DISPONIBILE EXCEPTION; 
NON_ESISTE EXCEPTION; 
GIA_VENDUTA EXCEPTION; 

BEGIN 
TIPO_PAG := 'FIALA';
FLAG_ESIST:=0; FLAG_VEND:=0; 

-- VEDIAMO SE LA FIALA ESISTE PER ESSERE ACQUISTATA 
SELECT COUNT(*) INTO FLAG_ESIST 
FROM FIALA_SEME 
WHERE ID_FIALA_SE=ID_FIALA; 

IF (FLAG_ESIST<=0)
THEN RAISE NON_ESISTE; 
END IF; 

-- LA FIALA NON DEVE ESSERE GIA STATA VENDUTA 
SELECT COUNT(*) INTO FLAG_VEND 
FROM FIALA_SEME 
WHERE ID_FIALA_SE=ID_FIALA AND FATTURA IS NOT NULL; 

IF (FLAG_VEND>0)
THEN RAISE GIA_VENDUTA; 
END IF; 

-- NON SI PUO ACQUISTARE UNA FIALA NON SANA 
SELECT SANO INTO FLAG_SANO 
FROM FIALA_SEME
WHERE ID_FIALA_SE=ID_FIALA; 

IF(FLAG_SANO='NO')
THEN RAISE NO_DISPONIBILE; 
END IF; 

-- BISOGNA INSERIRE LA TUPLA IN PAGAMENTO 
COD_FATTURA:= 'FAT'|| TO_CHAR(FATTURA_S.NEXTVAL);

INSERT INTO PAGAMENTO(TIPO_PA, FATTURA, DATAP, METODOP,CF_CLI)
SELECT TIPO_PAG, COD_FATTURA, SYSDATE, METODO_PAG, CF_INS FROM DUAL;

UPDATE FIALA_SEME SET FATTURA=COD_FATTURA WHERE ID_FIALA_SE=ID_FIALA;  
EXCEPTION
WHEN NON_ESISTE
THEN RAISE_APPLICATION_ERROR(-20335,'NON SI PUO ACQUISTARE UNA FIALA NON ESISTENTE');

WHEN GIA_VENDUTA
THEN RAISE_APPLICATION_ERROR(-20336,'LA FIALA E STATA GIA VENDUTA'); 

WHEN NO_DISPONIBILE
THEN RAISE_APPLICATION_ERROR(-20337,'LA FIALA NON PUO ESSERE UTILIZZATA NE VENDUTA'); 

END; 

/

SHO ERR; 

CREATE OR REPLACE PROCEDURE INSERISCI_FIALA_SEME(ID_PRENO NUMBER, COD_SPERM CHAR, COD_GENET CHAR) IS 
ID_FIALA CHAR(4); 
CF_DA_INSERIRE CHAR(16); 
DATA_DA_INSERIRE DATE; 

ID_CRIO_DA_INS NUMBER; 
BEGIN 

-- CERCO IL CODICE FISCALE DEL DONATORE E LA DATA DELLA PRENOTAZIONE 
SELECT CF_DON, DATA_ORA INTO CF_DA_INSERIRE, DATA_DA_INSERIRE
FROM PRENOTAZIONE 
WHERE ID_PREN=ID_PRENO; 

ID_FIALA:= 'F'||TO_CHAR(ID_FIALA_SE_S.NEXTVAL); 

SELECT GET_ID_CRIO(2) INTO ID_CRIO_DA_INS FROM DUAL; 

INSERT INTO FIALA_SEME(CF_DON, DATA_SEME, ID_FIALA_SE, ID_CRIO, COD_E_SPERMIOGRAMMA, COD_E_GENETICO)
SELECT CF_DA_INSERIRE, DATA_DA_INSERIRE, ID_FIALA, ID_CRIO_DA_INS, COD_SPERM, COD_GENET FROM DUAL; 

END; 

/ 
SHO ERR; 









CREATE OR REPLACE PROCEDURE INSERISCI_CRIOCELLA(CAPIENZA NUMBER, TIPO_CRIO CHAR) IS 
BEGIN 
INSERT INTO CRIOCELLA (ID_CRIO, CAPIENZA_MAX, TIPO)
SELECT ID_CRIO_S.NEXTVAL, CAPIENZA, TIPO_CRIO FROM DUAL; 
END; 

/

SHO ERR; 




CREATE OR REPLACE PROCEDURE INSERT_INSEMINAZIONE (NUM_FIALE NUMBER, CF_DONATORE_F CHAR, TIPO_INSEMINAZIONE CHAR, FATTURA_INS CHAR, ID_PREN_INS NUMBER) IS 
COD_INSEM CHAR(8); 
FIALE_ESISTENTI NUMBER;
ID_FIALA_SEME_AGG CHAR(4);
FIALE_MANCANTI EXCEPTION;
BEGIN

SELECT COUNT(*) INTO FIALE_ESISTENTI
FROM FIALA_SEME
WHERE CF_DON = CF_DONATORE_F AND SANO = 'SI' AND FATTURA IS NULL AND COD_INS IS NULL;

IF FIALE_ESISTENTI < NUM_FIALE
THEN RAISE FIALE_MANCANTI;
END IF;

COD_INSEM:='INS'||TO_CHAR(COD_INS_S.NEXTVAL); 

INSERT INTO INSEMINAZIONE (COD_INS, TIPO_INS, FATTURA, ID_PREN)
SELECT COD_INSEM,TIPO_INSEMINAZIONE, FATTURA_INS, ID_PREN_INS FROM DUAL; 

FOR I IN 1..NUM_FIALE LOOP

SELECT ID_FIALA_SE INTO ID_FIALA_SEME_AGG 
FROM FIALA_SEME 
WHERE SANO = 'SI'AND FATTURA IS NULL AND COD_INS IS NULL AND CF_DON=CF_DONATORE_F AND ROWNUM = 1;
UPDATE FIALA_SEME SET FATTURA = FATTURA_INS, COD_INS = COD_INSEM WHERE ID_FIALA_SE=ID_FIALA_SEME_AGG;

END LOOP;

EXCEPTION

WHEN FIALE_MANCANTI
THEN RAISE_APPLICATION_ERROR(-21490,'MANCANO LE FIALE PER EFFETTUARE L INSEMINAZIONE'); 

END; 
/
SHO ERR; 





CREATE OR REPLACE PROCEDURE INSERISCI_PAG_INS (METODO VARCHAR, CF_INS CHAR, DATA_INS DATE) IS --BISOGNA PRIMA PAGARE
-- DI FARE L'INSEMINAZIONE 
COD_FATTURA CHAR(10);  
COUNT_FLAG NUMBER; 

NOT_GRANTED EXCEPTION; 
BEGIN

COUNT_FLAG:=0; 

SELECT COUNT(*) INTO COUNT_FLAG
FROM FIALA_SANGUE 
WHERE CF_CLI=CF_INS AND SANO='NO'; 

IF (COUNT_FLAG>=1)
THEN RAISE NOT_GRANTED;
END IF; 

COD_FATTURA:='FAT'||TO_CHAR(FATTURA_S.NEXTVAL); 

INSERT INTO PAGAMENTO (TIPO_PA, FATTURA, DATAP, METODOP,CF_CLI)
SELECT 'INSEMINAZIONE',COD_FATTURA, DATA_INS, METODO, CF_INS FROM DUAL; 

EXCEPTION
WHEN NOT_GRANTED
THEN RAISE_APPLICATION_ERROR(-20267,'LA CLIENTE NON E COMPATIBILE ALL INSEMINAZIONE'); 

END;