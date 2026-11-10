Create database CountingFriend_BD;
Go

use CountingFriend_BD;
go

--Daniel
--Entidades fuertes o padres pues
--Tabla Usuario
create table Usuario(
id_usuario int identity(1,1) primary key,
nombre varchar(200) not null,
correo varchar(150) not null,
contrasena varchar(255) not null
);

--tabla MICROEMPRESA
create table MicroEmpresa(
id_microempresa int identity(1,1) primary key,
nombre varchar(150) not null,
--Regla que si o si la empresa es una natural o juridica
tipo varchar(20) check (tipo in ('Natural', 'Juridica')),
nit varchar(20) unique
);
--tabla catalogocuentas
create table CatalogoCuentas(
id_catalogo int primary key,
nombre varchar(100) not null,
descripcion varchar(255)
);

--Tablas debiles o hijas
--tabla persona comn (subtipo de usuario)
create table Persona_Comun(
id_usuario int primary key,
foreign key (id_usuario) references Usuario(id_usuario)
on delete cascade
on update cascade
);

--Tabla usuario microempresa (subtipo de ususairo + fk de empresa)
create table Usuario_MicroEmpresa(
id_usuario int primary key,
cargo varchar(100),
id_microempresa int,
foreign key (id_usuario) references Usuario(id_usuario)
on delete cascade --si alguien ejecuta eliminr usuario 
--sql borrara su fila en persona_comun o usuario_microempresa
on update cascade,
foreign key (id_microempresa) references MicroEmpresa(id_microempresa)
on delete set null --si se borra la empresa, el usuario no se borra
--solo se queda sin empresa 
);

--Tabla CUENTA (Depende de CatalogoCuentas)
create table Cuenta(
id_cuenta int identity(1,1) primary key,
codigo varchar(20) unique not null,
nombre varchar(100) not null,
tipo varchar(50) check (tipo in ('Activo','Pasivo','Patrimonio','Ingreso','Gasto')),
naturaleza varchar(20) check (naturaleza in ('Deudor', 'Acreedor')),
id_catalogo int,
foreign key (id_catalogo) references CatalogoCuentas(id_catalogo)
on update cascade
);

--Tabla Balance General(Deepende de Usuario y MicroEmpresa)
create table Balance_General(
id_balance int primary key,
fecha_inicio date not null,
fecha_fin date not null,
total_activo decimal(12,2) default 0.00,
total_pasivo decimal(12,2) default 0.00,
total_patrimonio decimal(12,2) default 0.00,
id_usuario int,
id_microempresa int,
foreign key (id_usuario) references Usuario(id_usuario)
on delete cascade,
foreign key(id_microempresa) references MicroEmpresa(id_microempresa)
on delete set null
);

--Tabla Asiento Contable (Depende de Usaurio, MicroEmpresa y Balance General)
create table Asiento_Contable(
id_asiento int primary key,
numero int unique not null, --el numero de asientos no se puede repetir 
fecha date not null,
glosa varchar(300),
total_debe decimal(12,2) default 0.00,
total_haber decimal(12,2) default 0.00,
id_usuario int,
id_microempresa int,
id_balance int, 
foreign key(id_usuario) references Usuario(id_usuario)
on delete cascade,
foreign key (id_microempresa) references MicroEmpresa(id_microempresa)
on delete no action,
foreign key (id_balance) references Balance_General(id_balance)
on delete no action
--id_balance es el que permite saber si un asiento fue generado a partir
--de un balance, usamos on delete no action porque un asiento
--puede existir sin venir de un balance (como una compra diaria)
);

--Tabla Movimiento_Asiento 
create table Movimiento_Asiento(
id_asiento int not null,
id_movimiento int not null,
tipo varchar(10) check(tipo in ('Debe', 'Haber')),
monto decimal(12, 2) not null check(monto > 0),
id_cuenta int,

--pk compuesta de el asiento + su numero de linea interno
primary key (id_asiento, id_movimiento),

--fk al asiento (padre)
foreign key (id_asiento) references Asiento_Contable(id_asiento)
on delete cascade,

foreign key(id_cuenta) references Cuenta(id_cuenta)
on delete no action
);

--tabla de balance cuenta
create table Balance_Cuenta(
id_balance int not null,
id_balance_cuenta int not null,
monto decimal(12,2) not null,
id_cuenta int,

--pk compuesta por el balance+ numero de linea interno
primary key (id_balance, id_balance_cuenta),

--fk al balance general (padre)
foreign key(id_balance) references Balance_General(id_balance)
on delete cascade,

--fk a la cuenta
foreign key (id_cuenta) references Cuenta(id_cuenta)
on delete no action
--esta para que si intenta borra una cuenta (eje caja)
--que ya tiene movimiento registradi, sql dira "no puede borrarlo
--porque tiene movimiento asociado", esto es para proteger la contabilidad
);
-- esto no mas lo puse si iba todo bien 
SELECT name FROM sys.tables;
go


--Procedimientos de almacenado
--1. Registro de usuarios
CREATE PROCEDURE usp_RegistrarUsuario
@p_nombre varchar(150),
@p_correo varchar(150),
@p_contrasena varchar(255),
@p_tipo varchar(20) --'Comun' o 'MicroEmpresa'

as
begin
set nocount on; --Pa mejorar el rendimiento
begin try
--1. Insertamos en la tabla principal
insert into Usuario(nombre, correo, contrasena)
values(@p_nombre, @p_correo, @p_contrasena);

--2. Obtenemos el id que la base de datos acaba de generar
declare @nuevo_id int;
set @nuevo_id = SCOPE_IDENTITY();
--funcion que devuleve el ultimo id insertado

--2. Segun el tipo, sinertamos en su subtipo correspondiente
if @p_tipo = 'Comun'
begin
insert into Persona_Comun(id_usuario)
values (@nuevo_id);
end
else if @p_tipo = 'Microempresa'
begin
--El cargo y la empresa se asignan luego,
--asi que los dejamos como NULL por ahora.
insert into Usuario_MicroEmpresa(id_usuario,cargo,id_microempresa)
values (@nuevo_id, NULL, NULL);
end

print 'Usuario registrado correctamente con ID: '+ CAST(@nuevo_id as varchar);
end try
begin catch
print 'Erro al registrar usuario: '+ ERROR_MESSAGE();
end catch
end;
go

--2. Insertar MovimientoAsiento
create procedure usp_InsertarMovimientoAsiento
@p_id_asiento int,
@p_id_cuenta int,
@p_tipo varchar (10), --debe o haber
@p_monto decimal(12,2)

as
begin 
set nocount on;
begin try
--1. validamos que el monto sea positivo
if @p_monto <= 0
begin
  throw 50003, 'El monto del movimiento debe ser mayor a cero', 1;
end

--2. Generamos el número de movimiento consecutivo para este asiento
declare @nuevo_movimiento int;
--buscamos el ultimo movimiento de este asiento. Si no hay, empezamos en 1
select @nuevo_movimiento = ISNULL(MAX(id_movimiento),0)+1
from Movimiento_Asiento
where id_asiento = @p_id_asiento;

--3. Insertamos la linea (El debe o haber)
insert into Movimiento_Asiento(id_asiento, id_movimiento, tipo, monto, id_cuenta)
values(@p_id_asiento, @nuevo_movimiento, @p_tipo, @p_monto, @p_id_cuenta)

--4. Actualizamos los totales en el encabezado del asiento
--sumamos todos los 'debe' y 'haber' existentes para este asiento y los guardamos
update Asiento_Contable
set total_debe = (select ISNULL(SUM(monto),0) from Movimiento_Asiento 
where id_asiento =  @p_id_asiento and tipo = 'Debe'),
total_haber = (select ISNULL(SUM(monto),0) from Movimiento_Asiento
where id_asiento = @p_id_asiento and tipo = 'Haber')
where id_asiento = @p_id_asiento;

print  'Movimiento insertado correctamente.';

end try
begin catch
print 'Error al insertar movimiento: '+ ERROR_MESSAGE();
end catch
end;
go


--Procedimiento para generar el balance general
--1. Procedimiento para crear el encabezado del Balance:
create procedure usp_CrearBalanceGeneral
@p_id_usuario int,
@p_id_microempresa int,
@p_fecha_inicio date,
@p_fecha_fin date,
@p_id_balance_creado int output
as
begin
set nocount on;

begin try
--creamos el balance contotales en 0
insert into Balance_General(fecha_inicio,fecha_fin,id_usuario,id_microempresa,
total_activo,total_pasivo,total_patrimonio)
values(@p_fecha_inicio, @p_fecha_fin, @p_id_usuario, @p_id_microempresa, 0,0,0);

--devolvemos el id generado a JAVA
set @p_id_balance_creado = SCOPE_IDENTITY();
print 'Balance Gneral creado con ID: '+ CAST(@p_id_balance_creado as varchar);
end try
begin catch
print 'Error al crear balance: '+ ERROR_MESSAGE();
end catch
end;
go

--2. Procedimiento para agregar una cuenta a ese Balance:
create procedure usp_AgregarCuentaBalance
@p_id_balance int,
@p_id_cuenta int,
@p_monto decimal(12,2)
as
begin
set nocount on;

begin try
--generamos el numero de linea (1, 2, 3...)
declare @nuevo_id_linea int;
select @nuevo_id_linea = ISNULL(MAX(id_balance_cuenta), 0)+1
from Balance_cuenta
where id_balance = @p_id_balance;

--insertamos la cuenta en el balance
insert into Balance_Cuenta(id_balance, id_balance_cuenta, monto, id_cuenta)
values(@p_id_balance, @nuevo_id_linea, @p_monto, @p_id_cuenta);

--actualizamos los totales del encabezado automaticamente
update Balance_General
set
total_activo = ISNULL((select SUM(bc.monto) from Balance_Cuenta bc join Cuenta c on bc.id_cuenta
 = c.id_cuenta where bc.id_balance = @p_id_balance and c.tipo = 'Activo'), 0),
 total_pasivo = ISNULL((select SUM(bc.monto) from Balance_Cuenta bc join Cuenta c
 on bc.id_cuenta = c.id_cuenta where bc.id_balance = @p_id_balance and c.tipo
 ='Pasivo'),0),
 total_patrimonio = ISNULL((select SUM(bc.monto) from Balance_Cuenta bc join Cuenta c
 on bc.id_cuenta = c.id_cuenta where bc.id_balance = @p_id_balance and c.tipo
 ='Patrimonio'),0)
 where id_balance = @p_id_balance;

 print 'Cuenta agregada al balance correctamente. ';
 end try
 begin catch
 print 'Error al agregar cuenta: '+ ERROR_MESSAGE();
 end catch
 end;
 go

 --3. crear la view para el libro mayor
create view vw_LibroMayor
as
select 
    c.id_cuenta,
    c.codigo,
    c.nombre as nombre_cuenta,
    c.tipo,
    --sumamos todos los movimientos al debe para esa cuenta
    ISNULL(sum(case when m.tipo = 'Debe' then m.monto else 0 end), 0) as total_debe,
    --sumamos todos los movimientos al haber para esa cuenta
    ISNULL(sum(case when m.tipo = 'Haber' then m.monto else 0 end), 0) as total_haber,
    --calculamos el saldo final segun la naturaleza de la cuenta
    case 
        when c.naturaleza = 'Deudor' then 
            ISNULL(sum(case when m.tipo = 'Debe' then m.monto else 0 end), 0) - ISNULL(sum(case when m.tipo = 'Haber' then m.monto else 0 end), 0)
        when c.naturaleza = 'Acreedor' then 
            ISNULL(sum(case when m.tipo = 'Haber' then m.monto else 0 end), 0) - ISNULL(sum(case when m.tipo = 'Debe' then m.monto else 0 end), 0)
        else 0 
    end as saldo_final
from Cuenta c
--unimos con los movimientos (puede que una cuenta aun no tenga movimientos, por eso left join)
left join Movimiento_Asiento m on c.id_cuenta = m.id_cuenta
group by 
    c.id_cuenta,
    c.codigo,
    c.nombre,
    c.tipo,
    c.naturaleza;
go
--DROP PROCEDURE IF EXISTS usp_InsertarMovimientoAsiento;
--GO


--Ricardo------------------------------------------
--Creacion de logins
CREATE LOGIN login_admin  WITH PASSWORD = 'Admin1234!', --Creamos el usuario admin
---con el check_policy obligamos a que la contra cumpla con las directivas de seguridad
CHECK_POLICY = ON, DEFAULT_DATABASE = CountingFriend_BD; --el default_database declara a que base de datos se conectara cada que ingrese

CREATE LOGIN login_app WITH PASSWORD = 'App1234!',
CHECK_POLICY = ON, DEFAULT_DATABASE = CountingFriend_BD;

CREATE LOGIN login_auditor WITH PASSWORD = 'Auditor1234',
CHECK_POLICY = ON, DEFAULT_DATABASE = CountingFriend_BD;

--creados los login creamos los usuarios
CREATE USER  usr_admin FOR LOGIN login_admin;
CREATE USER usr_app FOR LOGIN login_app;
CREATE USER usr_auditor FOR LOGIN login_auditor;

--Creamos los roles para los usuarios
CREATE ROLE rol_administrador;
CREATE ROLE rol_aplicacion;
CREATE ROLE rol_auditor;

--implementamso a los usuarios a los roles creados
ALTER ROLE rol_administrador ADD MEMBER usr_admin;
ALTER ROLE rol_aplicacion ADD MEMBER usr_app;
ALTER ROLE rol_auditor ADD MEMBER usr_auditor;

--Estructura de permisos para el administrador (leer, escribir, modificar, hacer respaldos)
ALTER ROLE db_datareader     ADD MEMBER rol_administrador;
ALTER ROLE db_datawriter     ADD MEMBER rol_administrador;
ALTER ROLE db_ddladmin       ADD MEMBER rol_administrador;
ALTER ROLE db_backupoperator ADD MEMBER rol_administrador;
GRANT EXECUTE ON SCHEMA::dbo TO rol_administrador; --Acceso a todos los datos, tablas y demas de dbo

--Estructura de permisos para la aplicacion (leer, hacer insercciones, modificar y actualizar, ejecutar)
GRANT SELECT ON SCHEMA::dbo TO rol_aplicacion;
GRANT EXECUTE ON dbo.usp_RegistrarUsuario         TO rol_aplicacion;
GRANT EXECUTE ON dbo.usp_InsertarMovimientoAsiento TO rol_aplicacion;
GRANT EXECUTE ON dbo.usp_CrearBalanceGeneral      TO rol_aplicacion;
GRANT EXECUTE ON dbo.usp_AgregarCuentaBalance     TO rol_aplicacion;
-- No existe procedimiento para crear asientos ni empresas, por eso estos permisos directos:
GRANT INSERT, UPDATE ON dbo.Asiento_Contable TO rol_aplicacion;
GRANT INSERT, UPDATE ON dbo.MicroEmpresa     TO rol_aplicacion;

--Estructura de permisos de auditor (solo lectura)
GRANT SELECT ON SCHEMA::dbo TO rol_auditor;
DENY SELECT ON dbo.Usuario (contrasena) TO rol_auditor;
DENY INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::dbo TO rol_auditor;
GO

--Hacemos una BD para probarla

DECLARE @u1 INT, @u2 INT;

INSERT INTO dbo.Usuario(nombre, correo, contrasena) VALUES ('Usuario Prueba 1', 'u1@test.com', 'HASH_DE_PRUEBA');
SET @u1 = SCOPE_IDENTITY();
INSERT INTO dbo.Usuario(nombre, correo, contrasena) VALUES ('Usuario Prueba 2', 'u2@test.com', 'HASH_DE_PRUEBA');
SET @u2 = SCOPE_IDENTITY();
INSERT INTO dbo.Persona_Comun(id_usuario) VALUES (@u1), (@u2);

INSERT INTO dbo.CatalogoCuentas(id_catalogo, nombre, descripcion) VALUES (1, 'Catálogo general', 'Catálogo de prueba');

INSERT INTO dbo.Cuenta(codigo, nombre, tipo, naturaleza, id_catalogo) VALUES
('1101', 'Caja',        'Activo',     'Deudor',   1),
('1102', 'Bancos',      'Activo',     'Deudor',   1),
('2101', 'Proveedores', 'Pasivo',     'Acreedor', 1),
('3101', 'Capital',     'Patrimonio', 'Acreedor', 1),
('4101', 'Ventas',      'Ingreso',    'Acreedor', 1),
('5101', 'Compras',     'Gasto',      'Deudor',   1);

-- 44 cuentas más, para que las búsquedas por cuenta sean selectivas
;WITH n AS (SELECT TOP (44) CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT) AS i FROM sys.all_objects)
INSERT INTO dbo.Cuenta(codigo, nombre, tipo, naturaleza, id_catalogo)
SELECT CONCAT('C', RIGHT(CONCAT('000', i), 3)),
       CONCAT('Cuenta de prueba ', i),
       CHOOSE(i % 5 + 1, 'Activo', 'Pasivo', 'Patrimonio', 'Ingreso', 'Gasto'),
       CHOOSE(i % 5 + 1, 'Deudor', 'Acreedor', 'Acreedor', 'Acreedor', 'Deudor'),
       1
FROM n;

-- 50 000 asientos repartidos entre los dos usuarios
SET IDENTITY_INSERT dbo.Asiento_Contable ON;
;WITH n AS (SELECT TOP (50000) CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT) AS i
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Asiento_Contable(id_asiento, numero, fecha, glosa, total_debe, total_haber, id_usuario)
SELECT i, i,
       DATEADD(DAY, -(i % 365), CAST(GETDATE() AS DATE)),
       CONCAT('Asiento de prueba ', i),
       10 + (i % 990), 10 + (i % 990),
       CASE WHEN i % 2 = 0 THEN @u1 ELSE @u2 END
FROM n;
SET IDENTITY_INSERT dbo.Asiento_Contable OFF;

--movimientos por asiento (partida doble: Debe = Haber)
SELECT CAST(ROW_NUMBER() OVER (ORDER BY id_cuenta) AS INT) AS n, id_cuenta INTO #c FROM dbo.Cuenta;

INSERT INTO dbo.Movimiento_Asiento(id_asiento, id_movimiento, tipo, monto, id_cuenta)
SELECT a.id_asiento, 1, 'Debe', 10 + (a.id_asiento % 990), c.id_cuenta
FROM dbo.Asiento_Contable a JOIN #c c ON c.n = 1 + (a.id_asiento % 50)
UNION ALL
SELECT a.id_asiento, 2, 'Haber', 10 + (a.id_asiento % 990), c.id_cuenta
FROM dbo.Asiento_Contable a JOIN #c c ON c.n = 1 + ((a.id_asiento + 17) % 50);

DROP TABLE #c;

--balances mensuales del usuario 1 (sirven para LAG)
SET IDENTITY_INSERT dbo.Balance_General ON;
;WITH m AS (SELECT TOP (12) CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT) AS i FROM sys.all_objects)
INSERT INTO dbo.Balance_General(id_balance, fecha_inicio, fecha_fin, total_activo, total_pasivo, total_patrimonio, id_usuario)
SELECT i, DATEFROMPARTS(2026, i, 1), EOMONTH(DATEFROMPARTS(2026, i, 1)),
       1000 + i * 150 + (i % 3) * 80, 400 + i * 40, 600 + i * 110, @u1
FROM m;
SET IDENTITY_INSERT dbo.Balance_General OFF;
GO

--Apratado de seguridad para los roles
CREATE SCHEMA Seguridad;
GO

CREATE FUNCTION Seguridad.fn_AccesoPorUsuario(@id_usuario INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS permitido
    WHERE @id_usuario = CAST(SESSION_CONTEXT(N'id_usuario') AS INT)
       OR IS_MEMBER('rol_administrador') = 1
       OR IS_MEMBER('rol_auditor') = 1
       OR IS_MEMBER('db_owner') = 1;
GO

CREATE FUNCTION Seguridad.fn_AccesoPorAsiento(@id_asiento INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS permitido
    FROM dbo.Asiento_Contable a
    WHERE a.id_asiento = @id_asiento
      AND (a.id_usuario = CAST(SESSION_CONTEXT(N'id_usuario') AS INT)
           OR IS_MEMBER('rol_administrador') = 1
           OR IS_MEMBER('rol_auditor') = 1
           OR IS_MEMBER('db_owner') = 1);
GO

CREATE FUNCTION Seguridad.fn_AccesoPorBalance(@id_balance INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS permitido
    FROM dbo.Balance_General b
    WHERE b.id_balance = @id_balance
      AND (b.id_usuario = CAST(SESSION_CONTEXT(N'id_usuario') AS INT)
           OR IS_MEMBER('rol_administrador') = 1
           OR IS_MEMBER('rol_auditor') = 1
           OR IS_MEMBER('db_owner') = 1);
GO

CREATE SECURITY POLICY Seguridad.pol_AccesoPorUsuario
    ADD FILTER PREDICATE Seguridad.fn_AccesoPorUsuario(id_usuario)   ON dbo.Asiento_Contable,
    ADD BLOCK  PREDICATE Seguridad.fn_AccesoPorUsuario(id_usuario)   ON dbo.Asiento_Contable AFTER INSERT,
    ADD BLOCK  PREDICATE Seguridad.fn_AccesoPorUsuario(id_usuario)   ON dbo.Asiento_Contable AFTER UPDATE,
    ADD FILTER PREDICATE Seguridad.fn_AccesoPorUsuario(id_usuario)   ON dbo.Balance_General,
    ADD BLOCK  PREDICATE Seguridad.fn_AccesoPorUsuario(id_usuario)   ON dbo.Balance_General AFTER INSERT,
    ADD BLOCK  PREDICATE Seguridad.fn_AccesoPorUsuario(id_usuario)   ON dbo.Balance_General AFTER UPDATE,
    ADD FILTER PREDICATE Seguridad.fn_AccesoPorAsiento(id_asiento)   ON dbo.Movimiento_Asiento,
    ADD BLOCK  PREDICATE Seguridad.fn_AccesoPorAsiento(id_asiento)   ON dbo.Movimiento_Asiento AFTER INSERT,
    ADD FILTER PREDICATE Seguridad.fn_AccesoPorBalance(id_balance)   ON dbo.Balance_Cuenta,
    ADD BLOCK  PREDICATE Seguridad.fn_AccesoPorBalance(id_balance)   ON dbo.Balance_Cuenta AFTER INSERT
    WITH (STATE = ON);
GO

--Pruebas de la seguridad implementada (suponen que los usuarios de prueba tienen id 1 y 2)

-- Prueba A: la app como usuario 1 ve solo sus asientos y no puede insertar a nombre del 2
EXECUTE AS USER = 'usr_app';
EXEC sp_set_session_context @key = N'id_usuario', @value = 1;
SELECT COUNT(*) AS asientos_visibles_usuario1 FROM dbo.Asiento_Contable;      -- ~25 000
BEGIN TRY
    INSERT INTO dbo.Asiento_Contable(numero, fecha, glosa, id_usuario)
    VALUES (900001, GETDATE(), 'Intento de insertar a nombre de otro', 2);
    PRINT 'ERROR: debió bloquearse';
END TRY
BEGIN CATCH
    PRINT 'Bloqueado correctamente: ' + ERROR_MESSAGE();
END CATCH
-- Prueba B: sin contexto de usuario no se ve nada
EXEC sp_set_session_context @key = N'id_usuario', @value = NULL;
SELECT COUNT(*) AS asientos_visibles_sin_contexto FROM dbo.Asiento_Contable;  -- 0
-- Prueba C: la app no tiene DELETE
BEGIN TRY
    DELETE FROM dbo.Asiento_Contable WHERE id_asiento = 1;
    PRINT 'ERROR: debió denegarse';
END TRY
BEGIN CATCH
    PRINT 'Denegado correctamente: ' + ERROR_MESSAGE();
END CATCH
REVERT;
GO

-- Prueba D: el auditor lee todo, pero no contraseñas ni puede modificar
EXECUTE AS USER = 'usr_auditor';
SELECT COUNT(*) AS asientos_visibles_auditor FROM dbo.Asiento_Contable;      -- 50 000
BEGIN TRY
    SELECT contrasena FROM dbo.Usuario;
    PRINT 'ERROR: debió denegarse';
END TRY
BEGIN CATCH
    PRINT 'Denegado correctamente: ' + ERROR_MESSAGE();
END CATCH
BEGIN TRY
    UPDATE dbo.Asiento_Contable SET glosa = 'x' WHERE id_asiento = 1;
    PRINT 'ERROR: debió denegarse';
END TRY
BEGIN CATCH
    PRINT 'Denegado correctamente: ' + ERROR_MESSAGE();
END CATCH
REVERT;
GO

DROP INDEX IF EXISTS UX_Usuario_Correo          ON dbo.Usuario;
DROP INDEX IF EXISTS IX_Movimiento_Cuenta       ON dbo.Movimiento_Asiento;
DROP INDEX IF EXISTS IX_Asiento_Usuario_Fecha   ON dbo.Asiento_Contable;
DROP INDEX IF EXISTS IX_Asiento_Microempresa    ON dbo.Asiento_Contable;
DROP INDEX IF EXISTS IX_Balance_Usuario_Fecha   ON dbo.Balance_General;
DROP INDEX IF EXISTS IX_BalanceCuenta_Cuenta    ON dbo.Balance_Cuenta;
DROP INDEX IF EXISTS IX_UsuarioMicro_Empresa    ON dbo.Usuario_MicroEmpresa;
GO

--MEDICIÓN "ANTES" (ejecutar con el plan de ejecución activado)
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

--asientos de un usuario en los últimos 3 meses
SELECT id_asiento, numero, fecha, glosa, total_debe, total_haber
FROM dbo.Asiento_Contable
WHERE id_usuario = 1
  AND fecha >= DATEADD(MONTH, -3, CAST(GETDATE() AS DATE));

--totales de una cuenta por tipo de movimiento (base del libro mayor)
DECLARE @c INT = (SELECT id_cuenta FROM dbo.Cuenta WHERE codigo = '1101');
SELECT m.tipo, SUM(m.monto) AS total
FROM dbo.Movimiento_Asiento m
WHERE m.id_cuenta = @c
GROUP BY m.tipo;

-- la vista del libro mayor completa
SELECT * FROM dbo.vw_LibroMayor;
GO

--CREACIÓN DE ÍNDICES (cada uno responde a una consulta real del sistema)

-- Login: buscar por correo. Además impide correos duplicados.
CREATE UNIQUE NONCLUSTERED INDEX UX_Usuario_Correo
    ON dbo.Usuario(correo) INCLUDE (nombre);

-- FK sin índice: vw_LibroMayor y el libro mayor filtran/agrupan por cuenta.
-- INCLUDE hace al índice "cubriente": no hace falta volver a la tabla por tipo y monto.
CREATE NONCLUSTERED INDEX IX_Movimiento_Cuenta
    ON dbo.Movimiento_Asiento(id_cuenta) INCLUDE (tipo, monto);

-- "Mis asientos por rango de fechas": igualdad (id_usuario) primero, rango (fecha) después.
-- También acelera el filtro de Row-Level Security, que siempre filtra por id_usuario.
CREATE NONCLUSTERED INDEX IX_Asiento_Usuario_Fecha
    ON dbo.Asiento_Contable(id_usuario, fecha) INCLUDE (numero, glosa, total_debe, total_haber);

CREATE NONCLUSTERED INDEX IX_Asiento_Microempresa
    ON dbo.Asiento_Contable(id_microempresa);

CREATE NONCLUSTERED INDEX IX_Balance_Usuario_Fecha
    ON dbo.Balance_General(id_usuario, fecha_inicio)
    INCLUDE (fecha_fin, total_activo, total_pasivo, total_patrimonio);

CREATE NONCLUSTERED INDEX IX_BalanceCuenta_Cuenta
    ON dbo.Balance_Cuenta(id_cuenta) INCLUDE (monto);

CREATE NONCLUSTERED INDEX IX_UsuarioMicro_Empresa
    ON dbo.Usuario_MicroEmpresa(id_microempresa);
GO
-- No se indexa Cuenta.tipo: es una tabla pequeña, un índice costaría más de lo que ahorra.
-- Cada índice acelera lecturas pero encarece INSERT/UPDATE; por eso solo se crean los justificados.

-- MEDICIÓN "DESPUÉS": repetir Q1, Q2 y Q3 y comparar logical reads y tiempos.
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT id_asiento, numero, fecha, glosa, total_debe, total_haber
FROM dbo.Asiento_Contable
WHERE id_usuario = 1
  AND fecha >= DATEADD(MONTH, -3, CAST(GETDATE() AS DATE));

DECLARE @c2 INT = (SELECT id_cuenta FROM dbo.Cuenta WHERE codigo = '1101');
SELECT m.tipo, SUM(m.monto) AS total
FROM dbo.Movimiento_Asiento m
WHERE m.id_cuenta = @c2
GROUP BY m.tipo;

SELECT * FROM dbo.vw_LibroMayor;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

-- Revisar el uso real de los índices
SELECT OBJECT_NAME(i.object_id) AS tabla, i.name AS indice,
       s.user_seeks, s.user_scans, s.user_updates
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats s
       ON s.object_id = i.object_id AND s.index_id = i.index_id AND s.database_id = DB_ID()
WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
  AND (i.name LIKE 'IX[_]%' OR i.name LIKE 'UX[_]%')
ORDER BY tabla, indice;
GO

DECLARE @codigo VARCHAR(20) = '1101';

SELECT c.codigo, c.nombre AS cuenta, a.fecha, a.numero, m.tipo, m.monto,
       SUM(CASE WHEN c.naturaleza = 'Deudor'
                THEN CASE m.tipo WHEN 'Debe'  THEN m.monto ELSE -m.monto END
                ELSE CASE m.tipo WHEN 'Haber' THEN m.monto ELSE -m.monto END
           END)
       OVER (PARTITION BY c.id_cuenta
             ORDER BY a.fecha, a.numero, m.id_movimiento
             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS saldo_acumulado
FROM dbo.Movimiento_Asiento m
JOIN dbo.Asiento_Contable a ON a.id_asiento = m.id_asiento
JOIN dbo.Cuenta c           ON c.id_cuenta  = m.id_cuenta
WHERE c.codigo = @codigo
ORDER BY a.fecha, a.numero, m.id_movimiento;
GO

-- ROW_NUMBER(): los 5 asientos más recientes de CADA usuario
;WITH r AS (
    SELECT a.id_usuario, a.id_asiento, a.numero, a.fecha, a.glosa, a.total_debe,
           ROW_NUMBER() OVER (PARTITION BY a.id_usuario
                              ORDER BY a.fecha DESC, a.numero DESC) AS rn
    FROM dbo.Asiento_Contable a
)
SELECT * FROM r WHERE rn <= 5
ORDER BY id_usuario, rn;
GO

-- DENSE_RANK(): ranking de cuentas por monto movido, dentro de cada tipo de cuenta
-- (a diferencia de RANK, DENSE_RANK no deja huecos tras un empate)
SELECT c.tipo, c.codigo, c.nombre,
       SUM(m.monto) AS monto_total,
       DENSE_RANK() OVER (PARTITION BY c.tipo ORDER BY SUM(m.monto) DESC) AS posicion
FROM dbo.Movimiento_Asiento m
JOIN dbo.Cuenta c ON c.id_cuenta = m.id_cuenta
GROUP BY c.tipo, c.codigo, c.nombre
ORDER BY c.tipo, posicion;
GO

--LAG(): variación del total de activos contra el balance anterior
;WITH b AS (
    SELECT id_usuario, fecha_inicio, fecha_fin, total_activo,
           LAG(total_activo) OVER (PARTITION BY id_usuario ORDER BY fecha_inicio) AS activo_anterior
    FROM dbo.Balance_General
)
SELECT id_usuario, fecha_inicio, fecha_fin, total_activo, activo_anterior,
       total_activo - activo_anterior AS variacion,
       CAST(100.0 * (total_activo - activo_anterior) / NULLIF(activo_anterior, 0) AS DECIMAL(10,2)) AS variacion_pct
FROM b
ORDER BY id_usuario, fecha_inicio;
GO

--Optimizacion con indices
--Gael---------------------------------------------


--Rodrigo------------------------------------------