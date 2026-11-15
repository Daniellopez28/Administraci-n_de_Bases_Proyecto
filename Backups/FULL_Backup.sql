USE msdb;
GO

-- 1. Crear el Job
EXEC sp_add_job @job_name = N'FULL_Backup';

-- 2. Definir el paso con tu comando exacto
EXEC sp_add_jobstep 
    @job_name = N'FULL_Backup',
    @step_name = N'Hacer Full Backup',
    @command = N'BACKUP DATABASE [CountingFriend_BD] TO DISK = N''/var/opt/mssql/data/CountingFriend_FULL.bak'' 
    WITH NOFORMAT, NOINIT, NAME = N''CountingFriend_BD-Completa Base de datos Copia de seguridad'', SKIP, NOREWIND, NOUNLOAD, STATS = 10;';

-- 3. Asignar el horario (Solo los Lunes, Miercoles y viernes a las 1:00 AM)
EXEC sp_add_jobschedule 
    @job_name = N'FULL_Backup',
    @name = N'Horario_Full_1AM',
    @freq_type = 8,             
    @freq_interval = 43,        -- Lunes, Miercoles, Viernes y Domingo
    @active_start_time = 010000;

-- 4. Asignar al servidor local
EXEC sp_add_jobserver @job_name = N'FULL_Backup';
GO