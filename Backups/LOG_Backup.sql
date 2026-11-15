USE msdb;
GO

-- 1. Crear el Job
EXEC sp_add_job @job_name = N'LOG_Backup'; 

-- 2. Definir el paso con tu comando exacto
EXEC sp_add_jobstep 
    @job_name = N'LOG_Backup', 
    @step_name = N'Hacer Log Backup',
    @command = N'BACKUP LOG [CountingFriend_BD] TO DISK = N''/var/opt/mssql/data/LOG.bak'' 
                 WITH NOFORMAT, NOINIT, 
                 NAME = N''CountingFriend_BD-Completa Base de datos Copia de seguridad'', SKIP, NOREWIND, NOUNLOAD, STATS = 10;';

-- 3. Asignar el horario (Cada 1 hora de 3 AM a 8 PM)
EXEC sp_add_jobschedule 
    @job_name = N'LOG_Backup', 
    @name = N'Horario_Log_Cada_Hora',
    @freq_type = 4,             
    @freq_interval = 1,         
    @freq_subday_type = 8,      
    @freq_subday_interval = 1,  
    @active_start_time = 030000,-- 03:00:00 AM
    @active_end_time = 200000;  -- 08:00:00 PM

-- 4. Asignar al servidor local
EXEC sp_add_jobserver @job_name = N'LOG_Backup'; 
GO