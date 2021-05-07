BEGIN
DBMS_SCHEDULER.DROP_JOB ('Inizializza_Prenotazioni');
DBMS_SCHEDULER.DROP_JOB ('Pulisci_Prenotazioni'); 
DBMS_SCHEDULER.DROP_JOB ('Organizza_turni');
END; 
/ 

BEGIN
DBMS_SCHEDULER.CREATE_JOB (
   job_name			=>	'Inizializza_Prenotazioni',
   job_type			=>	'STORED_PROCEDURE',
   job_action		=>	'ORGANIZZA_ORARI_PRENOTAZIONI',
   start_date		=> TO_DATE('24/04/2018','DD/MM/YYYY'),
   repeat_interval	=> 'FREQ=YEARLY',
   enabled			=>	TRUE,
   comments			=>	'Crea gli slot per gli esami prenotabili in tutto l''anno.');
END;
/



BEGIN 
DBMS_SCHEDULER.CREATE_JOB (
 
	job_name		=> 'Pulisci_Prenotazioni',
	job_type		=> 'PLSQL_BLOCK',
	job_action		=> 'BEGIN 
						DELETE FROM PRENOTAZIONE 
						WHERE TRUNC(DATA_ORA)<TRUNC(SYSDATE) AND CF_CLI IS NULL AND CF_DON IS NULL; 
						
						COMMIT; 
						END;', 
	start_date		=>  NEXT_DAY(SYSDATE, 'DOMENICA'), 
	repeat_interval	=>  'FREQ=WEEKLY', 
	enabled			=> 	TRUE,
	
	comments		=>	'Elimina le tuple di prenotazione che non sono state utilizzate.'); 
	
	END; 



BEGIN 
DBMS_SCHEDULER.CREATE_JOB ( 
	job_name		=> 'Organizza_turni',
	job_type		=> 'STORED_PROCEDURE', 
	job_action		=>	'ORGANIZZA_TURNI_DOTTORI',
	start_date		=> NEXT_DAY(SYSDATE, 'DOMENICA'),
	repeat_interval	=> 'FREQ=WEEKLY',
	enabled			=> TRUE, 
	comments		=> 'Organizza i turni dei dottori ogni settimana di domenica.'); 
END; 
 

BEGIN 
DBMS_SCHEDULER.RUN_JOB('Inizializza_Prenotazioni'); 
DBMS_SCHEDULER.RUN_JOB('Pulisci_Prenotazioni'); 
DBMS_SCHEDULER.RUN_JOB('Organizza_turni'); 

END; 
