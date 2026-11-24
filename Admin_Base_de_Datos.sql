SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

CREATE DATABASE CountingFriend_BD;
Go

ALTER DATABASE CountingFriend_BD SET RECOVERY FULL;
GO

USE CountingFriend_BD;
GO

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
tipo varchar(20) not null check (tipo in ('Natural', 'Juridica')),
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
id_usuario_microempresa int identity(1,1) primary key,
id_usuario int not null,
cargo varchar(100),
id_microempresa int null,
foreign key (id_usuario) references Usuario(id_usuario)
on delete cascade --si alguien ejecuta eliminr usuario 
--sql borrara su fila en persona_comun o usuario_microempresa
on update cascade,
foreign key (id_microempresa) references MicroEmpresa(id_microempresa)
on delete set null --si se borra la empresa, el usuario no se borra
--solo se queda sin empresa 
);

CREATE UNIQUE INDEX UX_UsuarioMicro_Empresa
    ON dbo.Usuario_MicroEmpresa(id_usuario, id_microempresa)
    WHERE id_microempresa IS NOT NULL;

--Tabla CUENTA (Depende de CatalogoCuentas)
create table Cuenta(
id_cuenta int identity(1,1) primary key,
codigo varchar(20) not null,
nombre varchar(100) not null,
tipo varchar(50) not null check (tipo in ('Activo','Pasivo','Patrimonio','Ingreso','Gasto')),
naturaleza varchar(20) not null check (naturaleza in ('Deudor', 'Acreedor')),
id_catalogo int not null,
id_usuario int null,
id_microempresa int null,
constraint CK_Cuenta_Propietario check (id_usuario is null or id_microempresa is null),
foreign key (id_catalogo) references CatalogoCuentas(id_catalogo)
on update cascade,
foreign key (id_usuario) references Usuario(id_usuario),
foreign key (id_microempresa) references MicroEmpresa(id_microempresa)
);

CREATE UNIQUE INDEX UX_Cuenta_CodigoGlobal
    ON dbo.Cuenta(codigo)
    WHERE id_usuario IS NULL AND id_microempresa IS NULL;
CREATE UNIQUE INDEX UX_Cuenta_CodigoUsuario
    ON dbo.Cuenta(id_usuario, codigo)
    WHERE id_usuario IS NOT NULL;
CREATE UNIQUE INDEX UX_Cuenta_CodigoMicroempresa
    ON dbo.Cuenta(id_microempresa, codigo)
    WHERE id_microempresa IS NOT NULL;

--Tabla Balance General(Deepende de Usuario y MicroEmpresa)
create table Balance_General(
id_balance int identity(1,1) primary key,
fecha_inicio date not null,
fecha_fin date not null,
total_activo decimal(12,2) not null default 0.00 check (total_activo >= 0),
total_pasivo decimal(12,2) not null default 0.00 check (total_pasivo >= 0),
total_patrimonio decimal(12,2) not null default 0.00 check (total_patrimonio >= 0),
id_usuario int not null,
id_microempresa int,
estado varchar(15) not null default 'Borrador'
    check (estado in ('Borrador', 'Contabilizado')),
constraint CK_BalanceGeneral_Fechas check (fecha_fin >= fecha_inicio),
foreign key (id_usuario) references Usuario(id_usuario)
on delete cascade,
foreign key(id_microempresa) references MicroEmpresa(id_microempresa)
on delete set null
);

--Tabla Asiento Contable (Depende de Usaurio, MicroEmpresa y Balance General)
create table Asiento_Contable(
id_asiento int identity(1,1) primary key,
numero int unique not null, --el numero de asientos no se puede repetir 
fecha date not null,
glosa varchar(300),
total_debe decimal(12,2) not null default 0.00 check (total_debe >= 0),
total_haber decimal(12,2) not null default 0.00 check (total_haber >= 0),
id_usuario int not null,
id_microempresa int,
id_balance int, 
estado varchar(15) not null default 'Borrador'
    check (estado in ('Borrador', 'Contabilizado')),
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
tipo varchar(10) not null check(tipo in ('Debe', 'Haber')),
monto decimal(12, 2) not null check(monto > 0),
id_cuenta int not null,

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
monto decimal(12,2) not null check (monto >= 0),
id_cuenta int not null,

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
set xact_abort on;

if nullif(ltrim(rtrim(@p_nombre)), '') is null
   or nullif(ltrim(rtrim(@p_correo)), '') is null
   or nullif(ltrim(rtrim(@p_contrasena)), '') is null
   or @p_tipo is null or @p_tipo not in ('Comun', 'Microempresa')
    throw 50001, 'Datos de registro incompletos o tipo de usuario inválido.', 1;

begin try
begin transaction;
--1. Insertamos en la tabla principal
insert into Usuario(nombre, correo, contrasena)
values(ltrim(rtrim(@p_nombre)), lower(ltrim(rtrim(@p_correo))), @p_contrasena);

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

commit transaction;
select @nuevo_id as id_usuario;
end try
begin catch
if @@trancount > 0 rollback transaction;
throw;
end catch
end;
go

CREATE PROCEDURE dbo.usp_ObtenerCredencialUsuario
    @p_correo varchar(150)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT id_usuario, contrasena AS hash_contrasena
    FROM dbo.Usuario
    WHERE correo = LOWER(LTRIM(RTRIM(@p_correo)));
END;
GO

CREATE PROCEDURE dbo.usp_CrearMicroEmpresa
    @p_nombre varchar(150),
    @p_tipo varchar(20),
    @p_nit varchar(20) = NULL,
    @p_id_microempresa_creada int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @id_usuario int = TRY_CONVERT(int, SESSION_CONTEXT(N'id_usuario'));
    IF @id_usuario IS NULL
        THROW 50020, 'Debe establecerse el usuario autenticado en la sesión.', 1;
    IF NULLIF(LTRIM(RTRIM(@p_nombre)), '') IS NULL
        THROW 50021, 'El nombre de la microempresa es obligatorio.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO dbo.MicroEmpresa (nombre, tipo, nit)
        VALUES (LTRIM(RTRIM(@p_nombre)), @p_tipo, NULLIF(LTRIM(RTRIM(@p_nit)), ''));

        SET @p_id_microempresa_creada = CONVERT(int, SCOPE_IDENTITY());
        INSERT INTO dbo.Usuario_MicroEmpresa (id_usuario, cargo, id_microempresa)
        VALUES (@id_usuario, N'Propietario', @p_id_microempresa_creada);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE PROCEDURE dbo.usp_CrearAsiento
    @p_numero int,
    @p_fecha date,
    @p_glosa varchar(300) = NULL,
    @p_id_microempresa int = NULL,
    @p_id_balance int = NULL,
    @p_id_asiento_creado int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @id_usuario int = TRY_CONVERT(int, SESSION_CONTEXT(N'id_usuario'));
    IF @id_usuario IS NULL
        THROW 50002, 'Debe establecerse el usuario autenticado en la sesión.', 1;

    IF @p_numero IS NULL OR @p_fecha IS NULL
        THROW 50006, 'El número y la fecha del asiento son obligatorios.', 1;

    IF @p_id_microempresa IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
           FROM dbo.Usuario_MicroEmpresa
           WHERE id_usuario = @id_usuario
             AND id_microempresa = @p_id_microempresa
       )
        THROW 50007, 'El usuario no pertenece a la microempresa indicada.', 1;

    IF @p_id_balance IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
           FROM dbo.Balance_General
           WHERE id_balance = @p_id_balance
             AND id_usuario = @id_usuario
             AND (id_microempresa = @p_id_microempresa
                  OR (id_microempresa IS NULL AND @p_id_microempresa IS NULL))
       )
        THROW 50008, 'El balance no pertenece al usuario y empresa indicados.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO dbo.Asiento_Contable
            (numero, fecha, glosa, id_usuario, id_microempresa, id_balance)
        VALUES
            (@p_numero, @p_fecha, @p_glosa, @id_usuario, @p_id_microempresa, @p_id_balance);
        SET @p_id_asiento_creado = CONVERT(int, SCOPE_IDENTITY());
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

--2. Insertar MovimientoAsiento
create procedure usp_InsertarMovimientoAsiento
@p_id_asiento int,
@p_id_cuenta int,
@p_tipo varchar (10), --debe o haber
@p_monto decimal(12,2)

as
begin 
set nocount on;
set xact_abort on;

if @p_tipo is null or @p_tipo not in ('Debe', 'Haber')
   or @p_monto is null or @p_monto <= 0
    throw 50003, 'El tipo debe ser Debe o Haber y el monto debe ser mayor a cero.', 1;

begin try
begin transaction;
--2. Generamos el número de movimiento consecutivo para este asiento
declare @nuevo_movimiento int;
declare @estado_asiento varchar(15);
declare @id_microempresa_asiento int;
declare @id_usuario int = TRY_CONVERT(int, SESSION_CONTEXT(N'id_usuario'));
select @estado_asiento = estado, @id_microempresa_asiento = id_microempresa
from dbo.Asiento_Contable with (UPDLOCK, HOLDLOCK)
where id_asiento = @p_id_asiento and id_usuario = @id_usuario;

if @estado_asiento is null
    throw 50009, 'El asiento no existe o no pertenece al usuario autenticado.', 1;
if @estado_asiento <> 'Borrador'
    throw 50010, 'No se pueden agregar movimientos a un asiento contabilizado.', 1;
if not exists (
    select 1
    from dbo.Cuenta c
    where c.id_cuenta = @p_id_cuenta
      and (
          (c.id_usuario is null and c.id_microempresa is null)
          or c.id_usuario = @id_usuario
          or c.id_microempresa = @id_microempresa_asiento
      )
)
    throw 50011, 'La cuenta no es accesible para este asiento.', 1;

select @nuevo_movimiento = ISNULL(MAX(id_movimiento),0)+1
from Movimiento_Asiento with (UPDLOCK, HOLDLOCK)
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

commit transaction;

end try
begin catch
if @@trancount > 0 rollback transaction;
throw;
end catch
end;
go

CREATE PROCEDURE dbo.usp_ContabilizarAsiento
    @p_id_asiento int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @id_usuario int = TRY_CONVERT(int, SESSION_CONTEXT(N'id_usuario'));
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Asiento_Contable WITH (UPDLOCK, HOLDLOCK)
            WHERE id_asiento = @p_id_asiento
              AND id_usuario = @id_usuario
              AND estado = 'Borrador'
        )
            THROW 50012, 'El asiento no existe, no es editable o no pertenece al usuario.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Movimiento_Asiento WHERE id_asiento = @p_id_asiento)
           OR EXISTS (
               SELECT 1 FROM dbo.Asiento_Contable
               WHERE id_asiento = @p_id_asiento
                 AND (total_debe <= 0 OR total_debe <> total_haber)
           )
            THROW 50013, 'El asiento debe tener movimientos y estar cuadrado antes de contabilizar.', 1;

        UPDATE dbo.Asiento_Contable
        SET estado = 'Contabilizado'
        WHERE id_asiento = @p_id_asiento;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

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
set xact_abort on;

if @p_fecha_inicio is null or @p_fecha_fin is null or @p_fecha_fin < @p_fecha_inicio
    throw 50004, 'El período del balance no es válido.', 1;
if @p_id_usuario is null
   or @p_id_usuario <> TRY_CONVERT(int, SESSION_CONTEXT(N'id_usuario'))
    throw 50016, 'El balance debe pertenecer al usuario autenticado.', 1;
if @p_id_microempresa is not null
   and not exists (
       select 1 from dbo.Usuario_MicroEmpresa
       where id_usuario = @p_id_usuario and id_microempresa = @p_id_microempresa
   )
    throw 50017, 'El usuario no pertenece a la microempresa indicada.', 1;

begin try
begin transaction;
--creamos el balance contotales en 0
insert into Balance_General(fecha_inicio,fecha_fin,id_usuario,id_microempresa,
total_activo,total_pasivo,total_patrimonio)
values(@p_fecha_inicio, @p_fecha_fin, @p_id_usuario, @p_id_microempresa, 0,0,0);

--devolvemos el id generado a JAVA
set @p_id_balance_creado = SCOPE_IDENTITY();
commit transaction;
end try
begin catch
if @@trancount > 0 rollback transaction;
throw;
end catch
end;
go

CREATE PROCEDURE dbo.usp_CrearCuenta
    @p_codigo varchar(20),
    @p_nombre varchar(100),
    @p_tipo varchar(50),
    @p_naturaleza varchar(20),
    @p_id_catalogo int,
    @p_id_microempresa int = NULL,
    @p_id_cuenta_creada int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @id_usuario int = TRY_CONVERT(int, SESSION_CONTEXT(N'id_usuario'));
    IF @id_usuario IS NULL
        THROW 50014, 'Debe establecerse el usuario autenticado en la sesión.', 1;

    IF @p_id_microempresa IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
           FROM dbo.Usuario_MicroEmpresa
           WHERE id_usuario = @id_usuario
             AND id_microempresa = @p_id_microempresa
       )
        THROW 50015, 'El usuario no pertenece a la microempresa indicada.', 1;

    INSERT INTO dbo.Cuenta
        (codigo, nombre, tipo, naturaleza, id_catalogo, id_usuario, id_microempresa)
    VALUES
        (@p_codigo, @p_nombre, @p_tipo, @p_naturaleza, @p_id_catalogo,
         CASE WHEN @p_id_microempresa IS NULL THEN @id_usuario END,
         @p_id_microempresa);
    SET @p_id_cuenta_creada = CONVERT(int, SCOPE_IDENTITY());
END;
GO

--2. Procedimiento para agregar una cuenta a ese Balance:
create procedure usp_AgregarCuentaBalance
@p_id_balance int,
@p_id_cuenta int,
@p_monto decimal(12,2)
as
begin
set nocount on;
set xact_abort on;

if @p_monto is null or @p_monto < 0
    throw 50005, 'El monto no puede ser negativo.', 1;

begin try
begin transaction;
declare @id_usuario int = TRY_CONVERT(int, SESSION_CONTEXT(N'id_usuario'));
declare @id_microempresa_balance int;
declare @estado_balance varchar(15);
select @id_microempresa_balance = id_microempresa
     , @estado_balance = estado
from dbo.Balance_General with (UPDLOCK, HOLDLOCK)
where id_balance = @p_id_balance and id_usuario = @id_usuario;

if @@rowcount = 0
    throw 50018, 'El balance no existe o no pertenece al usuario autenticado.', 1;
if @estado_balance <> 'Borrador'
    throw 50022, 'No se pueden modificar cuentas de un balance contabilizado.', 1;

if not exists (
    select 1
    from dbo.Cuenta c
    where c.id_cuenta = @p_id_cuenta
      and (
          (c.id_usuario is null and c.id_microempresa is null)
          or c.id_usuario = @id_usuario
          or c.id_microempresa = @id_microempresa_balance
      )
)
    throw 50019, 'La cuenta no es accesible para este balance.', 1;

--generamos el numero de linea (1, 2, 3...)
declare @nuevo_id_linea int;
select @nuevo_id_linea = ISNULL(MAX(id_balance_cuenta), 0)+1
from Balance_cuenta with (UPDLOCK, HOLDLOCK)
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

 commit transaction;
 end try
 begin catch
 if @@trancount > 0 rollback transaction;
 throw;
 end catch
 end;
 go

CREATE PROCEDURE dbo.usp_ContabilizarBalance
    @p_id_balance int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @id_usuario int = TRY_CONVERT(int, SESSION_CONTEXT(N'id_usuario'));
    DECLARE @estado varchar(15);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @estado = estado
        FROM dbo.Balance_General WITH (UPDLOCK, HOLDLOCK)
        WHERE id_balance = @p_id_balance
          AND id_usuario = @id_usuario;

        IF @@ROWCOUNT = 0 OR @estado <> 'Borrador'
            THROW 50023, 'El balance no existe, ya está contabilizado o no pertenece al usuario.', 1;

        IF NOT EXISTS (
            SELECT 1 FROM dbo.Balance_Cuenta WHERE id_balance = @p_id_balance
        )
           OR EXISTS (
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
               WHERE b.id_balance = @p_id_balance
                 AND (
                     ISNULL(d.total_activo, 0) <> b.total_activo
                     OR ISNULL(d.total_pasivo, 0) <> b.total_pasivo
                     OR ISNULL(d.total_patrimonio, 0) <> b.total_patrimonio
                     OR b.total_activo <> b.total_pasivo + b.total_patrimonio
                 )
           )
            THROW 50024, 'El balance debe tener detalles y cumplir Activo = Pasivo + Patrimonio.', 1;

        UPDATE dbo.Balance_General
        SET estado = 'Contabilizado'
        WHERE id_balance = @p_id_balance;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

--Quite el view de aqui para dejaro en un mismo script (Gael)
--Ricardo------------------------------------------
-- Los usuarios quedan sin login para no guardar contraseñas en el repositorio.
-- Vincularlos a logins de SQL Server solo durante el despliegue.
CREATE USER usr_admin WITHOUT LOGIN;
CREATE USER usr_app WITHOUT LOGIN;
CREATE USER usr_auditor WITHOUT LOGIN;

CREATE ROLE rol_administrador;
CREATE ROLE rol_aplicacion;
CREATE ROLE rol_auditor;

ALTER ROLE rol_administrador ADD MEMBER usr_admin;
ALTER ROLE rol_aplicacion ADD MEMBER usr_app;
ALTER ROLE rol_auditor ADD MEMBER usr_auditor;

-- Administrador de la base de datos.
ALTER ROLE db_datareader     ADD MEMBER rol_administrador;
ALTER ROLE db_datawriter     ADD MEMBER rol_administrador;
ALTER ROLE db_ddladmin       ADD MEMBER rol_administrador;
ALTER ROLE db_backupoperator ADD MEMBER rol_administrador;
GRANT EXECUTE ON SCHEMA::dbo TO rol_administrador;

-- Aplicación: no conceder lectura indiscriminada del esquema ni de hashes.
GRANT SELECT ON dbo.Usuario (id_usuario, nombre, correo) TO rol_aplicacion;
DENY SELECT ON dbo.Usuario (contrasena) TO rol_aplicacion;
GRANT SELECT ON dbo.CatalogoCuentas TO rol_aplicacion;
GRANT SELECT ON dbo.Cuenta TO rol_aplicacion;
GRANT SELECT ON dbo.Persona_Comun TO rol_aplicacion;
GRANT SELECT ON dbo.Balance_General TO rol_aplicacion;
GRANT SELECT ON dbo.Balance_Cuenta TO rol_aplicacion;
GRANT SELECT ON dbo.Asiento_Contable TO rol_aplicacion;
GRANT SELECT ON dbo.Movimiento_Asiento TO rol_aplicacion;
GRANT EXECUTE ON dbo.usp_RegistrarUsuario         TO rol_aplicacion;
GRANT EXECUTE ON dbo.usp_ObtenerCredencialUsuario TO rol_aplicacion;
GRANT EXECUTE ON dbo.usp_CrearMicroEmpresa       TO rol_aplicacion;
GRANT EXECUTE ON dbo.usp_CrearAsiento             TO rol_aplicacion;
GRANT EXECUTE ON dbo.usp_InsertarMovimientoAsiento TO rol_aplicacion;
GRANT EXECUTE ON dbo.usp_ContabilizarAsiento      TO rol_aplicacion;
GRANT EXECUTE ON dbo.usp_CrearBalanceGeneral      TO rol_aplicacion;
GRANT EXECUTE ON dbo.usp_AgregarCuentaBalance     TO rol_aplicacion;
GRANT EXECUTE ON dbo.usp_ContabilizarBalance      TO rol_aplicacion;
GRANT EXECUTE ON dbo.usp_CrearCuenta              TO rol_aplicacion;

-- Auditor: lectura, sin datos de autenticación ni operaciones de escritura.
GRANT SELECT ON SCHEMA::dbo TO rol_auditor;
DENY SELECT ON dbo.Usuario (contrasena) TO rol_auditor;
DENY INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::dbo TO rol_auditor;
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
    WHERE @id_usuario = TRY_CONVERT(INT, SESSION_CONTEXT(N'id_usuario'))
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
      AND (a.id_usuario = TRY_CONVERT(INT, SESSION_CONTEXT(N'id_usuario'))
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
      AND (b.id_usuario = TRY_CONVERT(INT, SESSION_CONTEXT(N'id_usuario'))
           OR IS_MEMBER('rol_administrador') = 1
           OR IS_MEMBER('rol_auditor') = 1
           OR IS_MEMBER('db_owner') = 1);
GO

CREATE FUNCTION Seguridad.fn_AccesoPorMicroempresa(@id_microempresa INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS permitido
    WHERE IS_MEMBER('rol_administrador') = 1
       OR IS_MEMBER('rol_auditor') = 1
       OR IS_MEMBER('db_owner') = 1
       OR EXISTS (
           SELECT 1
           FROM dbo.Usuario_MicroEmpresa um
           WHERE um.id_microempresa = @id_microempresa
             AND um.id_usuario = TRY_CONVERT(INT, SESSION_CONTEXT(N'id_usuario'))
       );
GO

CREATE FUNCTION Seguridad.fn_AccesoPorCuenta
(
    @id_usuario int,
    @id_microempresa int
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS permitido
    WHERE (@id_usuario IS NULL AND @id_microempresa IS NULL)
       OR @id_usuario = TRY_CONVERT(INT, SESSION_CONTEXT(N'id_usuario'))
       OR EXISTS (
           SELECT 1
           FROM dbo.Usuario_MicroEmpresa um
           WHERE um.id_usuario = TRY_CONVERT(INT, SESSION_CONTEXT(N'id_usuario'))
             AND um.id_microempresa = @id_microempresa
       )
       OR IS_MEMBER('rol_administrador') = 1
       OR IS_MEMBER('rol_auditor') = 1
       OR IS_MEMBER('db_owner') = 1;
GO

CREATE SECURITY POLICY Seguridad.pol_AccesoPorUsuario
    ADD FILTER PREDICATE Seguridad.fn_AccesoPorUsuario(id_usuario) ON dbo.Usuario,
    ADD FILTER PREDICATE Seguridad.fn_AccesoPorUsuario(id_usuario) ON dbo.Persona_Comun,
    ADD FILTER PREDICATE Seguridad.fn_AccesoPorUsuario(id_usuario) ON dbo.Usuario_MicroEmpresa,
    ADD FILTER PREDICATE Seguridad.fn_AccesoPorMicroempresa(id_microempresa) ON dbo.MicroEmpresa,
    ADD FILTER PREDICATE Seguridad.fn_AccesoPorCuenta(id_usuario, id_microempresa) ON dbo.Cuenta,
    ADD BLOCK PREDICATE Seguridad.fn_AccesoPorCuenta(id_usuario, id_microempresa) ON dbo.Cuenta AFTER INSERT,
    ADD BLOCK PREDICATE Seguridad.fn_AccesoPorCuenta(id_usuario, id_microempresa) ON dbo.Cuenta AFTER UPDATE,
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

--CREACIÓN DE ÍNDICES (cada uno responde a una consulta real del sistema)
-- Optimizacion de index Gael

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
