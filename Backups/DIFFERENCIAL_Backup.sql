USE msdb;
GO

IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = N'DIFFERENCIAL_Backup')
    EXEC dbo.sp_delete_job @job_name = N'DIFFERENCIAL_Backup', @delete_unused_schedule = 1;
GO

EXEC dbo.sp_add_job
    @job_name = N'DIFFERENCIAL_Backup',
    @enabled = 1,
    @description = N'Respaldos diferenciales de CountingFriend_BD.';

EXEC dbo.sp_add_jobstep
    @job_name = N'DIFFERENCIAL_Backup',
    @step_name = N'Respaldo diferencial con verificación',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
DECLARE @file nvarchar(4000) =
    N''/var/opt/mssql/data/CountingFriend_BD_DIFF_''
    + CONVERT(char(8), GETDATE(), 112) + N''_''
    + REPLACE(CONVERT(char(8), GETDATE(), 108), '':'', '''') + N''.bak'';
BACKUP DATABASE [CountingFriend_BD] TO DISK = @file
    WITH DIFFERENTIAL, INIT, COMPRESSION, CHECKSUM, STATS = 10;
RESTORE VERIFYONLY FROM DISK = @file WITH CHECKSUM;';

EXEC dbo.sp_add_jobschedule
    @job_name = N'DIFFERENCIAL_Backup',
    @name = N'Horario_Diff_2AM',
    @freq_type = 8,
    @freq_interval = 127,
    @freq_recurrence_factor = 1,
    @active_start_time = 020000;

EXEC dbo.sp_add_jobschedule
    @job_name = N'DIFFERENCIAL_Backup',
    @name = N'Horario_Diff_12PM',
    @freq_type = 8,
    @freq_interval = 127,
    @freq_recurrence_factor = 1,
    @active_start_time = 120000;

EXEC dbo.sp_add_jobschedule
    @job_name = N'DIFFERENCIAL_Backup',
    @name = N'Horario_Diff_6PM',
    @freq_type = 8,
    @freq_interval = 127,
    @freq_recurrence_factor = 1,
    @active_start_time = 180000;

EXEC dbo.sp_add_jobserver @job_name = N'DIFFERENCIAL_Backup';
GO
