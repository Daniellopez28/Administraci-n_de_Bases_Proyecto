USE msdb;
GO

IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = N'FULL_Backup')
    EXEC dbo.sp_delete_job @job_name = N'FULL_Backup', @delete_unused_schedule = 1;
GO

EXEC dbo.sp_add_job
    @job_name = N'FULL_Backup',
    @enabled = 1,
    @description = N'Respaldo completo de CountingFriend_BD.';

EXEC dbo.sp_add_jobstep
    @job_name = N'FULL_Backup',
    @step_name = N'Respaldo completo con verificación',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
DECLARE @file nvarchar(4000) =
    N''/var/opt/mssql/data/CountingFriend_BD_FULL_''
    + CONVERT(char(8), GETDATE(), 112) + N''_''
    + REPLACE(CONVERT(char(8), GETDATE(), 108), '':'', '''') + N''.bak'';
BACKUP DATABASE [CountingFriend_BD] TO DISK = @file
    WITH INIT, COMPRESSION, CHECKSUM, STATS = 10;
RESTORE VERIFYONLY FROM DISK = @file WITH CHECKSUM;';

EXEC dbo.sp_add_jobschedule
    @job_name = N'FULL_Backup',
    @name = N'Horario_Full_1AM',
    @freq_type = 8,
    @freq_interval = 43,
    @freq_recurrence_factor = 1,
    @active_start_time = 010000;

EXEC dbo.sp_add_jobserver @job_name = N'FULL_Backup';
GO
