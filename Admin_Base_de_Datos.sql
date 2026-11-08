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
create login login_admin  with password = 'Admin1234!', --Creamos el usuario admin
---con el check_policy obligamos a que la contra cumpla con las directivas de seguridad
check_policy = on, default_database = CountingFriend_BD; --el default_database declara a que base de datos se conectara cada que ingrese

create login login_app with password = 'App1234!',
check_policy = on, default_database = CountingFriend_BD;

create login login_auditor with password = 'Auditor1234',
check_policy = on, default_database = CountingFriend_BD;

--creados los login creamos los usuarios
create user  usr_admin for login login_admin;
create user usr_app for login login_app;
create user usr_auditor for login login_auditor;

--Creamos los roles para los usuarios
create role rol_administrador;
create role rol_aplicacion;
create role rol_auditor;

--implementamso a los usuarios a los roles creados
alter role rol_administrador add member usr_admin;
alter role rol_aplicacion add member usr_app;
alter role rol_auditor add member usr_auditor;

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



--Gael---------------------------------------------


--Rodrigo------------------------------------------