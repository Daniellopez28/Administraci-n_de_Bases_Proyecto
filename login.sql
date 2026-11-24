USE [master];
GO

CREATE LOGIN [login_powerbi]
WITH PASSWORD = N'Chuchotriste1',
     CHECK_POLICY = ON;
GO

USE [CountingFriend_BD];
GO

CREATE USER [usr_powerbi]
FOR LOGIN [login_powerbi];
GO

ALTER ROLE [rol_auditor]
ADD MEMBER [usr_powerbi];
GO



GRANT SELECT TO [rol_auditor];
GO