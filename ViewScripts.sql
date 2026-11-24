-- Los view generados en este script son necesarios para el dashboard en el Power BI

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- 1. Crear la view para el libro mayor
CREATE VIEW vw_LibroMayor
AS
SELECT 
    c.id_cuenta,
    c.codigo,
    c.nombre AS nombre_cuenta,
    c.tipo,
    -- sumamos todos los movimientos al debe para esa cuenta
    ISNULL(sum(case when m.tipo = 'Debe' then m.monto else 0 end), 0) as total_debe,
    -- sumamos todos los movimientos al haber para esa cuenta
    ISNULL(sum(case when m.tipo = 'Haber' then m.monto else 0 end), 0) as total_haber,
    -- calculamos el saldo final segun la naturaleza de la cuenta
    case 
        when c.naturaleza = 'Deudor' then 
            ISNULL(sum(case when m.tipo = 'Debe' then m.monto else 0 end), 0) - ISNULL(sum(case when m.tipo = 'Haber' then m.monto else 0 end), 0)
        when c.naturaleza = 'Acreedor' then 
            ISNULL(sum(case when m.tipo = 'Haber' then m.monto else 0 end), 0) - ISNULL(sum(case when m.tipo = 'Debe' then m.monto else 0 end), 0)
        else 0 
    end as saldo_final
from dbo.Cuenta c
-- unimos con los movimientos (puede que una cuenta aun no tenga movimientos, por eso left join)
left join dbo.Movimiento_Asiento m
    on c.id_cuenta = m.id_cuenta
   and exists (
       select 1
       from dbo.Asiento_Contable a
       where a.id_asiento = m.id_asiento
         and a.estado = 'Contabilizado'
   )
group by 
    c.id_cuenta,
    c.codigo,
    c.nombre,
    c.tipo,
    c.naturaleza;
GO

-- Detalle contabilizado para análisis de ingresos/gastos y filtros del dashboard.
CREATE VIEW vw_MovimientosContabilizados
AS
SELECT
    a.id_usuario,
    a.id_microempresa,
    me.nombre AS nombre_microempresa,
    a.id_asiento,
    a.numero,
    a.fecha,
    a.glosa,
    m.id_movimiento,
    c.id_cuenta,
    c.codigo,
    c.nombre AS nombre_cuenta,
    c.tipo AS tipo_cuenta,
    c.naturaleza,
    m.tipo AS tipo_movimiento,
    m.monto,
    CASE WHEN c.tipo = 'Ingreso' THEN m.monto ELSE CONVERT(decimal(12,2), 0) END AS importe_ingreso,
    CASE WHEN c.tipo = 'Gasto' THEN m.monto ELSE CONVERT(decimal(12,2), 0) END AS importe_gasto
FROM dbo.Asiento_Contable a
JOIN dbo.Movimiento_Asiento m ON m.id_asiento = a.id_asiento
JOIN dbo.Cuenta c ON c.id_cuenta = m.id_cuenta
LEFT JOIN dbo.MicroEmpresa me ON me.id_microempresa = a.id_microempresa
WHERE a.estado = 'Contabilizado';
GO

-- Saldo corriente por movimiento, particionado por usuario, empresa y cuenta.
CREATE VIEW vw_SaldoAcumuladoCuenta
AS
WITH movimientos AS (
    SELECT
        id_usuario,
        id_microempresa,
        nombre_microempresa,
        id_asiento,
        numero,
        fecha,
        glosa,
        id_movimiento,
        id_cuenta,
        codigo,
        nombre_cuenta,
        tipo_cuenta,
        naturaleza,
        tipo_movimiento,
        monto,
        CASE
            WHEN naturaleza = 'Deudor' AND tipo_movimiento = 'Debe' THEN monto
            WHEN naturaleza = 'Deudor' AND tipo_movimiento = 'Haber' THEN -monto
            WHEN naturaleza = 'Acreedor' AND tipo_movimiento = 'Haber' THEN monto
            ELSE -monto
        END AS variacion_saldo
    FROM dbo.vw_MovimientosContabilizados
)
SELECT
    id_usuario,
    id_microempresa,
    nombre_microempresa,
    id_asiento,
    numero,
    fecha,
    glosa,
    id_movimiento,
    id_cuenta,
    codigo,
    nombre_cuenta,
    tipo_cuenta,
    naturaleza,
    tipo_movimiento,
    monto,
    variacion_saldo,
    SUM(variacion_saldo) OVER (
        PARTITION BY id_usuario, id_microempresa, id_cuenta
        ORDER BY fecha, numero, id_asiento, id_movimiento
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS saldo_acumulado
FROM movimientos;
GO

-- 2. Vista para la evolucion financiera mensual (Activos, Pasivos, Patrimonio por período)
CREATE VIEW vw_EvolucionFinanciera
AS
SELECT 
    id_usuario,
    id_microempresa,
    fecha_inicio,
    fecha_fin,
    total_activo,
    total_pasivo,
    total_patrimonio,
    YEAR(fecha_inicio) AS anio,
    MONTH(fecha_inicio) AS mes
FROM dbo.Balance_General
WHERE estado = 'Contabilizado';
GO

-- 3. Vista para las estadisticas de cuentas con mayor movimiento (Gráfico de barras)
CREATE VIEW vw_TopCuentasMovimiento
AS
SELECT 
    c.id_cuenta,
    c.codigo,
    c.nombre AS cuenta,
    c.tipo,
    SUM(m.monto) AS monto_total,
    COUNT(m.id_asiento) AS total_movimientos
FROM dbo.Cuenta c
JOIN dbo.Movimiento_Asiento m ON c.id_cuenta = m.id_cuenta
JOIN dbo.Asiento_Contable a ON a.id_asiento = m.id_asiento
    AND a.estado = 'Contabilizado'
GROUP BY c.id_cuenta, c.codigo, c.nombre, c.tipo;
GO

-- 4. Vista para los últimos asientos registrados por usuario
CREATE VIEW vw_UltimosAsientos
AS
SELECT 
    a.id_asiento,
    a.fecha,
    a.numero,
    a.glosa,
    u.nombre AS usuario,
    a.total_debe,
    a.total_haber,
    a.id_usuario,
    a.id_microempresa
FROM dbo.Asiento_Contable a
JOIN dbo.Usuario u ON a.id_usuario = u.id_usuario
WHERE a.estado = 'Contabilizado';
GO

-- 5. Vista para empresas con mayor patrimonio 
CREATE VIEW vw_EmpresasPatrimonio
AS
SELECT 
    m.id_microempresa,
    m.nombre AS microempresa,
    m.tipo,
    ISNULL(SUM(b.total_patrimonio), 0) AS total_patrimonio
FROM dbo.MicroEmpresa m
LEFT JOIN dbo.Balance_General b
    ON m.id_microempresa = b.id_microempresa
   AND b.estado = 'Contabilizado'
WHERE IS_MEMBER('rol_administrador') = 1
   OR IS_MEMBER('rol_auditor') = 1
   OR IS_MEMBER('db_owner') = 1
   OR EXISTS (
       SELECT 1
       FROM dbo.Usuario_MicroEmpresa um
       WHERE um.id_microempresa = m.id_microempresa
         AND um.id_usuario = TRY_CONVERT(int, SESSION_CONTEXT(N'id_usuario'))
   )
GROUP BY m.id_microempresa, m.nombre, m.tipo;
GO

-- 6. Microempresas asociadas al usuario de sesión.
CREATE VIEW vw_MisMicroempresas
AS
SELECT m.id_microempresa, m.nombre, m.tipo, m.nit, um.cargo
FROM dbo.MicroEmpresa m
JOIN dbo.Usuario_MicroEmpresa um ON um.id_microempresa = m.id_microempresa;
GO

-- 7. Vista para los movimientos por usuario
CREATE VIEW vw_MovimientosPorUsuario
AS
SELECT 
    u.id_usuario,
    u.nombre AS usuario,
    COUNT(a.id_asiento) AS total_asientos
FROM dbo.Usuario u
LEFT JOIN dbo.Asiento_Contable a ON u.id_usuario = a.id_usuario
    AND a.estado = 'Contabilizado'
GROUP BY u.id_usuario, u.nombre;
GO

--Se asignan los permisos a ciertos roles para que tengan visualizacion de los view
GRANT SELECT ON dbo.vw_LibroMayor             TO rol_administrador, rol_aplicacion, rol_auditor;
GRANT SELECT ON dbo.vw_MovimientosContabilizados TO rol_administrador, rol_aplicacion, rol_auditor;
GRANT SELECT ON dbo.vw_SaldoAcumuladoCuenta   TO rol_administrador, rol_aplicacion, rol_auditor;
GRANT SELECT ON dbo.vw_EvolucionFinanciera    TO rol_administrador, rol_aplicacion, rol_auditor;
GRANT SELECT ON dbo.vw_TopCuentasMovimiento    TO rol_administrador, rol_aplicacion, rol_auditor;
GRANT SELECT ON dbo.vw_UltimosAsientos         TO rol_administrador, rol_aplicacion, rol_auditor;
GRANT SELECT ON dbo.vw_EmpresasPatrimonio      TO rol_administrador, rol_aplicacion, rol_auditor;
GRANT SELECT ON dbo.vw_MisMicroempresas        TO rol_administrador, rol_aplicacion, rol_auditor;
GRANT SELECT ON dbo.vw_MovimientosPorUsuario   TO rol_administrador, rol_aplicacion, rol_auditor;
GO
