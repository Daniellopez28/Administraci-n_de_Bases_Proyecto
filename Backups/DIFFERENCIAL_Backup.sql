USE msdb;
GO

-- 1. Crear el Job
EXEC sp_add_job @job_name = N'DIFFERENCIAL_Backup';

-- 2. Definir el paso con el comando EXACTO que copiaste
EXEC sp_add_jobstep 
    @job_name = N'DIFFERENCIAL_Backup',
    @step_name = N'Hacer Diff Backup',
    @command = N'BACKUP DATABASE [CountingFriend_BD] TO DISK = N''/var/opt/mssql/data/CountingFriend_DIFF.bak'' 
     WITH DIFFERENTIAL, NOFORMAT, INIT, NAME = N''CountingFriend_BD-Diferencial'', SKIP, NOREWIND, NOUNLOAD, STATS = 10;';

-- 3. Primer Horario (Lunes a Sábado a las 2:00 AM)
EXEC sp_add_jobschedule 
    @job_name = N'DIFFERENCIAL_Backup',
    @name = N'Horario_Diff_2AM',
    @freq_type = 8,             
    @freq_interval = 127,       -- Lunes a Sábado
    @active_start_time = 020000;

-- 4. Segundo Horario (Lunes a Sábado a las 12:00 PM)
EXEC sp_add_jobschedule 
    @job_name = N'DIFFERENCIAL_Backup',
    @name = N'Horario_Diff_12PM',
    @freq_type = 8,             
    @freq_interval = 127,       
    @active_start_time = 120000;

--tercer Horario (Lunes a Sábado a las 6:00 PM)
EXEC sp_add_jobschedule 
    @job_name = N'DIFFERENCIAL_Backup',
    @name = N'Horario_Diff_6PM',
    @freq_type = 8,             
    @freq_interval = 127,       
    @active_start_time = 180000;

-- 5. Asignar al servidor
EXEC sp_add_jobserver @job_name = N'DIFFERENCIAL_Backup';
GO