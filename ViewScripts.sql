-- Los view generados en este script son necesarios para el dashboard en el Power BI

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
from Cuenta c
-- unimos con los movimientos (puede que una cuenta aun no tenga movimientos, por eso left join)
left join Movimiento_Asiento m on c.id_cuenta = m.id_cuenta
group by 
    c.id_cuenta,
    c.codigo,
    c.nombre,
    c.tipo,
    c.naturaleza;
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
FROM dbo.Balance_General;
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
JOIN dbo.Usuario u ON a.id_usuario = u.id_usuario;
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
LEFT JOIN dbo.Balance_General b ON m.id_microempresa = b.id_microempresa
GROUP BY m.id_microempresa, m.nombre, m.tipo;
GO

-- 6. Vista para los movimientos por usuario 
CREATE VIEW vw_MovimientosPorUsuario
AS
SELECT 
    u.id_usuario,
    u.nombre AS usuario,
    COUNT(a.id_asiento) AS total_asientos
FROM dbo.Usuario u
LEFT JOIN dbo.Asiento_Contable a ON u.id_usuario = a.id_usuario
GROUP BY u.id_usuario, u.nombre;
GO

--Se asignan los permisos a ciertos roles para que tengan visualizacion de los view
GRANT SELECT ON dbo.vw_EvolucionFinanciera    TO rol_administrador, rol_aplicacion, rol_auditor;
GRANT SELECT ON dbo.vw_TopCuentasMovimiento    TO rol_administrador, rol_aplicacion, rol_auditor;
GRANT SELECT ON dbo.vw_UltimosAsientos         TO rol_administrador, rol_aplicacion, rol_auditor;
GRANT SELECT ON dbo.vw_EmpresasPatrimonio      TO rol_administrador, rol_aplicacion, rol_auditor;
GRANT SELECT ON dbo.vw_MovimientosPorUsuario   TO rol_administrador, rol_aplicacion, rol_auditor;
GO
