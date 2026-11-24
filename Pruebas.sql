USE CountingFriend_BD;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

SET NOCOUNT ON;

IF EXISTS (
    SELECT 1
    FROM dbo.Asiento_Contable a
    OUTER APPLY (
        SELECT
            SUM(CASE WHEN m.tipo = 'Debe' THEN m.monto ELSE 0 END) AS total_debe,
            SUM(CASE WHEN m.tipo = 'Haber' THEN m.monto ELSE 0 END) AS total_haber
        FROM dbo.Movimiento_Asiento m
        WHERE m.id_asiento = a.id_asiento
    ) m
    WHERE a.estado = 'Contabilizado'
      AND (m.total_debe IS NULL
           OR m.total_debe <> a.total_debe
           OR m.total_haber <> a.total_haber
           OR a.total_debe <> a.total_haber)
)
    THROW 51100, 'Hay asientos contabilizados descuadrados o con totales incorrectos.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.Balance_General b
    OUTER APPLY (
        SELECT
            SUM(CASE WHEN c.tipo = 'Activo' THEN bc.monto ELSE 0 END) AS total_activo,
            SUM(CASE WHEN c.tipo = 'Pasivo' THEN bc.monto ELSE 0 END) AS total_pasivo,
            SUM(CASE WHEN c.tipo = 'Patrimonio' THEN bc.monto ELSE 0 END) AS total_patrimonio
        FROM dbo.Balance_Cuenta bc
        JOIN dbo.Cuenta c ON c.id_cuenta = bc.id_cuenta
        WHERE bc.id_balance = b.id_balance
    ) d
    WHERE ISNULL(d.total_activo, 0) <> b.total_activo
       OR ISNULL(d.total_pasivo, 0) <> b.total_pasivo
       OR ISNULL(d.total_patrimonio, 0) <> b.total_patrimonio
       OR (
           b.estado = 'Contabilizado'
           AND b.total_activo <> b.total_pasivo + b.total_patrimonio
       )
)
    THROW 51101, 'Hay balances con detalles o totales inconsistentes.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.vw_MovimientosContabilizados v
    JOIN dbo.Asiento_Contable a ON a.id_asiento = v.id_asiento
    WHERE a.estado <> 'Contabilizado'
       OR (v.tipo_cuenta = 'Ingreso'
           AND (v.importe_ingreso <> v.monto OR v.importe_gasto <> 0))
       OR (v.tipo_cuenta = 'Gasto'
           AND (v.importe_gasto <> v.monto OR v.importe_ingreso <> 0))
       OR (v.tipo_cuenta NOT IN ('Ingreso', 'Gasto')
           AND (v.importe_ingreso <> 0 OR v.importe_gasto <> 0))
)
    THROW 51109, 'La vista del dashboard incluye borradores o clasifica mal ingresos/gastos.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.vw_SaldoAcumuladoCuenta
    WHERE saldo_acumulado IS NULL
)
    THROW 51110, 'La vista de saldo acumulado contiene saldos nulos.', 1;
GO

EXECUTE AS USER = 'usr_app';
BEGIN TRY
    EXEC sys.sp_set_session_context @key = N'id_usuario', @value = 1;

    IF EXISTS (
        SELECT 1 FROM dbo.Asiento_Contable WHERE id_usuario <> 1
    )
        THROW 51102, 'La política RLS mostró asientos de otro usuario.', 1;

    EXEC sys.sp_set_session_context @key = N'id_usuario', @value = NULL;
    IF EXISTS (SELECT 1 FROM dbo.Asiento_Contable)
        THROW 51103, 'RLS permitió leer asientos sin contexto de usuario.', 1;

    IF HAS_PERMS_BY_NAME(N'dbo.Asiento_Contable', N'OBJECT', N'INSERT') = 1
       OR HAS_PERMS_BY_NAME(N'dbo.Asiento_Contable', N'OBJECT', N'DELETE') = 1
        THROW 51104, 'La aplicación tiene permisos directos de escritura no permitidos.', 1;

    IF HAS_PERMS_BY_NAME(N'dbo.MicroEmpresa', N'OBJECT', N'SELECT') = 1
       OR HAS_PERMS_BY_NAME(N'dbo.Usuario_MicroEmpresa', N'OBJECT', N'SELECT') = 1
        THROW 51108, 'La aplicación puede consultar directamente empresas o membresías.', 1;

    DECLARE @hash varchar(255);
    DECLARE @password_denied bit = 0;
    BEGIN TRY
        SELECT TOP (1) @hash = contrasena FROM dbo.Usuario;
    END TRY
    BEGIN CATCH
        SET @password_denied = 1;
    END CATCH;

    IF @password_denied = 0
        THROW 51105, 'La aplicación puede leer el hash de contraseña.', 1;

    EXEC sys.sp_set_session_context @key = N'id_usuario', @value = NULL;
    REVERT;
    PRINT 'Pruebas del rol de aplicación y RLS: correctas.';
END TRY
BEGIN CATCH
    EXEC sys.sp_set_session_context @key = N'id_usuario', @value = NULL;
    REVERT;
    THROW;
END CATCH;
GO

EXECUTE AS USER = 'usr_auditor';
BEGIN TRY
    IF HAS_PERMS_BY_NAME(N'dbo.Asiento_Contable', N'OBJECT', N'UPDATE') = 1
       OR HAS_PERMS_BY_NAME(N'dbo.Asiento_Contable', N'OBJECT', N'DELETE') = 1
        THROW 51106, 'El auditor tiene permisos de escritura.', 1;

    DECLARE @auditor_hash varchar(255);
    DECLARE @auditor_password_denied bit = 0;
    BEGIN TRY
        SELECT TOP (1) @auditor_hash = contrasena FROM dbo.Usuario;
    END TRY
    BEGIN CATCH
        SET @auditor_password_denied = 1;
    END CATCH;

    IF @auditor_password_denied = 0
        THROW 51107, 'El auditor puede leer el hash de contraseña.', 1;

    REVERT;
    PRINT 'Pruebas del rol auditor: correctas.';
END TRY
BEGIN CATCH
    REVERT;
    THROW;
END CATCH;
GO
