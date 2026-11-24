USE CountingFriend_BD;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Asientos contabilizados de un usuario desde una fecha.
SELECT id_asiento, numero, fecha, glosa, total_debe, total_haber
FROM dbo.Asiento_Contable
WHERE id_usuario = 1
  AND estado = 'Contabilizado'
  AND fecha >= DATEADD(MONTH, -3, CAST(GETDATE() AS date));

-- Total por tipo de movimiento para una cuenta.
DECLARE @id_cuenta int =
    (SELECT id_cuenta FROM dbo.Cuenta WHERE codigo = '1101');
SELECT tipo, SUM(monto) AS total
FROM dbo.Movimiento_Asiento
WHERE id_cuenta = @id_cuenta
GROUP BY tipo;

-- Vistas de reportes.
SELECT * FROM dbo.vw_LibroMayor;
SELECT * FROM dbo.vw_EvolucionFinanciera;
SELECT * FROM dbo.vw_TopCuentasMovimiento;
GO

-- Saldo acumulado de una cuenta en orden cronológico.
DECLARE @codigo varchar(20) = '1101';
SELECT c.codigo, c.nombre AS cuenta, a.fecha, a.numero, m.tipo, m.monto,
       SUM(CASE WHEN c.naturaleza = 'Deudor'
                THEN CASE m.tipo WHEN 'Debe' THEN m.monto ELSE -m.monto END
                ELSE CASE m.tipo WHEN 'Haber' THEN m.monto ELSE -m.monto END
           END)
       OVER (PARTITION BY c.id_cuenta
             ORDER BY a.fecha, a.numero, m.id_movimiento
             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS saldo_acumulado
FROM dbo.Movimiento_Asiento m
JOIN dbo.Asiento_Contable a ON a.id_asiento = m.id_asiento
JOIN dbo.Cuenta c ON c.id_cuenta = m.id_cuenta
WHERE c.codigo = @codigo
  AND a.estado = 'Contabilizado'
ORDER BY a.fecha, a.numero, m.id_movimiento;
GO

-- Cinco asientos más recientes por usuario.
;WITH recientes AS (
    SELECT id_usuario, id_asiento, numero, fecha, glosa, total_debe,
           ROW_NUMBER() OVER (
               PARTITION BY id_usuario
               ORDER BY fecha DESC, numero DESC
           ) AS fila
    FROM dbo.Asiento_Contable
    WHERE estado = 'Contabilizado'
)
SELECT * FROM recientes WHERE fila <= 5
ORDER BY id_usuario, fila;
GO

-- Ranking de cuentas por volumen contabilizado dentro de cada tipo.
SELECT c.tipo, c.codigo, c.nombre,
       SUM(m.monto) AS monto_total,
       DENSE_RANK() OVER (
           PARTITION BY c.tipo ORDER BY SUM(m.monto) DESC
       ) AS posicion
FROM dbo.Movimiento_Asiento m
JOIN dbo.Asiento_Contable a ON a.id_asiento = m.id_asiento
JOIN dbo.Cuenta c ON c.id_cuenta = m.id_cuenta
WHERE a.estado = 'Contabilizado'
GROUP BY c.tipo, c.codigo, c.nombre
ORDER BY c.tipo, posicion;
GO

-- Variación mensual de activos por usuario.
;WITH balances AS (
    SELECT id_usuario, fecha_inicio, fecha_fin, total_activo,
           LAG(total_activo) OVER (
               PARTITION BY id_usuario ORDER BY fecha_inicio
           ) AS activo_anterior
    FROM dbo.Balance_General
    WHERE estado = 'Contabilizado'
)
SELECT id_usuario, fecha_inicio, fecha_fin, total_activo, activo_anterior,
       total_activo - activo_anterior AS variacion,
       CAST(100.0 * (total_activo - activo_anterior)
            / NULLIF(activo_anterior, 0) AS decimal(10,2)) AS variacion_pct
FROM balances
ORDER BY id_usuario, fecha_inicio;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

SELECT OBJECT_NAME(i.object_id) AS tabla, i.name AS indice,
       s.user_seeks, s.user_scans, s.user_updates
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats s
    ON s.object_id = i.object_id
   AND s.index_id = i.index_id
   AND s.database_id = DB_ID()
WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
  AND (i.name LIKE 'IX[_]%' OR i.name LIKE 'UX[_]%')
ORDER BY tabla, indice;
GO
