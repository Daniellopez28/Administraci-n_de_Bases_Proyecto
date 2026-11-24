USE msdb;
GO

IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = N'LOG_Backup')
    EXEC dbo.sp_delete_job @job_name = N'LOG_Backup', @delete_unused_schedule = 1;
GO

EXEC dbo.sp_add_job
    @job_name = N'LOG_Backup',
    @enabled = 1,
    @description = N'Respaldos del log de CountingFriend_BD cada hora.';

EXEC dbo.sp_add_jobstep
    @job_name = N'LOG_Backup',
    @step_name = N'Respaldo de log con verificación',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
DECLARE @file nvarchar(4000) =
    N''/var/opt/mssql/data/CountingFriend_BD_LOG_''
    + CONVERT(char(8), GETDATE(), 112) + N''_''
    + REPLACE(CONVERT(char(8), GETDATE(), 108), '':'', '''') + N''.trn'';
BACKUP LOG [CountingFriend_BD] TO DISK = @file
    WITH INIT, COMPRESSION, CHECKSUM, STATS = 10;
RESTORE VERIFYONLY FROM DISK = @file WITH CHECKSUM;';

EXEC dbo.sp_add_jobschedule
    @job_name = N'LOG_Backup',
    @name = N'Horario_Log_Cada_Hora',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 8,
    @freq_subday_interval = 1,
    @active_start_time = 000000,
    @active_end_time = 235959;

EXEC dbo.sp_add_jobserver @job_name = N'LOG_Backup';
GO
