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


--Gael---------------------------------------------
--Creacion de esquemas de seguridad
create schema seguridad;
go

create function seguridad.fn_accesoporusuario(@id_usuario int)
returns table
with schemabinding
as
return
    select 1 as permitido
    where @id_usuario = cast(session_context(n'id_usuario') as int)
       or is_member('rol_administrador') = 1
       or is_member('rol_auditor') = 1
       or is_member('db_owner') = 1;
go

create function seguridad.fn_accesoporasiento(@id_asiento int)
returns table
with schemabinding
as
return
    select 1 as permitido
    from dbo.asiento_contable a
    where a.id_asiento = @id_asiento
      and (a.id_usuario = cast(session_context(n'id_usuario') as int)
           or is_member('rol_administrador') = 1
           or is_member('rol_auditor') = 1
           or is_member('db_owner') = 1);
go

create function seguridad.fn_accesoporbalance(@id_balance int)
returns table
with schemabinding
as
return
    select 1 as permitido
    from dbo.balance_general b
    where b.id_balance = @id_balance
      and (b.id_usuario = cast(session_context(n'id_usuario') as int)
           or is_member('rol_administrador') = 1
           or is_member('rol_auditor') = 1
           or is_member('db_owner') = 1);
go

create security policy seguridad.pol_accesoporusuario
    add filter predicate seguridad.fn_accesoporusuario(id_usuario) on dbo.asiento_contable,
    add block predicate seguridad.fn_accesoporusuario(id_usuario) on dbo.asiento_contable after insert,
    add block predicate seguridad.fn_accesoporusuario(id_usuario) on dbo.asiento_contable after update,
    add filter predicate seguridad.fn_accesoporusuario(id_usuario) on dbo.balance_general,
    add block predicate seguridad.fn_accesoporusuario(id_usuario) on dbo.balance_general after insert,
    add block predicate seguridad.fn_accesoporusuario(id_usuario) on dbo.balance_general after update,
    add filter predicate seguridad.fn_accesoporasiento(id_asiento) on dbo.movimiento_asiento,
    add block predicate seguridad.fn_accesoporasiento(id_asiento) on dbo.movimiento_asiento after insert,
    add filter predicate seguridad.fn_accesoporbalance(id_balance) on dbo.balance_cuenta,
    add block predicate seguridad.fn_accesoporbalance(id_balance) on dbo.balance_cuenta after insert
    with (state = on);
go

execute as user = 'usr_app';
exec sp_set_session_context @key = n'id_usuario', @value = 1;

select count(*) as asientos_visibles_usuario1
from dbo.asiento_contable;

begin try
    insert into dbo.asiento_contable(numero, fecha, glosa, id_usuario)
    values (900001, getdate(), 'intento de insertar a nombre de otro', 2);
    print 'error: debio bloquearse';
end try
begin catch
    print 'bloqueado correctamente: ' + error_message();
end catch

exec sp_set_session_context @key = n'id_usuario', @value = null;

select count(*) as asientos_visibles_sin_contexto
from dbo.asiento_contable;

begin try
    delete from dbo.asiento_contable
    where id_asiento = 1;
    print 'error: debio denegarse';
end try
begin catch
    print 'denegado correctamente: ' + error_message();
end catch

revert;
go

execute as user = 'usr_auditor';

select count(*) as asientos_visibles_auditor
from dbo.asiento_contable;

begin try
    select contrasena
    from dbo.usuario;
    print 'error: debio denegarse';
end try
begin catch
    print 'denegado correctamente: ' + error_message();
end catch

begin try
    update dbo.asiento_contable
    set glosa = 'x'
    where id_asiento = 1;
    print 'error: debio denegarse';
end try
begin catch
    print 'denegado correctamente: ' + error_message();
end catch

revert;
go
--Poblacion de la base de datos
select top (100) cast(row_number() over (order by (select null)) as int) as i
into #n
from sys.all_objects;

insert into dbo.usuario(nombre, correo, contrasena)
select concat('usuario ', i),
       concat('usuario', i, '@test.com'),
       'hash_de_prueba'
from #n;

insert into dbo.persona_comun(id_usuario)
select i from #n where i <= 50;

insert into dbo.microempresa(nombre, tipo, nit)
select concat('microempresa ', i),
       case when i % 2 = 0 then 'natural' else 'juridica' end,
       concat('nit-', right(concat('0000', i), 4))
from #n;

insert into dbo.usuario_microempresa(id_usuario, cargo, id_microempresa)
select 50 + i, 'empleado', i
from #n where i <= 50;

insert into dbo.catalogocuentas(id_catalogo, nombre, descripcion)
select i, concat('catalogo ', i), 'catalogo de prueba'
from #n;

insert into dbo.cuenta(codigo, nombre, tipo, naturaleza, id_catalogo)
select concat('c', right(concat('00', i), 3)),
       concat('cuenta de prueba ', i),
       choose(i % 5 + 1, 'activo', 'pasivo', 'patrimonio', 'ingreso', 'gasto'),
       choose(i % 5 + 1, 'deudor', 'acreedor', 'acreedor', 'acreedor', 'deudor'),
       i
from #n;

set identity_insert dbo.balance_general on;

insert into dbo.balance_general(id_balance, fecha_inicio, fecha_fin,
                                total_activo, total_pasivo, total_patrimonio, id_usuario)
select i,
       datefromparts(2026, (i - 1) / 10 + 1, 1),
       eomonth(datefromparts(2026, (i - 1) / 10 + 1, 1)),
       1000 + i * 15, 400 + i * 4, 600 + i * 11,
       (i - 1) % 10 + 1
from #n;

set identity_insert dbo.balance_general off;

insert into dbo.balance_cuenta(id_balance, id_balance_cuenta, monto, id_cuenta)
select i, 1, 1000 + i * 15, 5 * (1 + i % 20)
from #n;

set identity_insert dbo.asiento_contable on;

insert into dbo.asiento_contable(id_asiento, numero, fecha, glosa,
                                 total_debe, total_haber, id_usuario, id_microempresa)
select i, i,
       dateadd(day, -(i * 3), cast(getdate() as date)),
       concat('asiento de prueba ', i),
       case when i <= 50 then 100 + i * 10 else 0 end,
       case when i <= 50 then 100 + i * 10 else 0 end,
       (i - 1) % 10 + 1,
       i
from #n;

set identity_insert dbo.asiento_contable off;

insert into dbo.movimiento_asiento(id_asiento, id_movimiento, tipo, monto, id_cuenta)
select i, 1, 'debe', 100 + i * 10, 1 + (i % 10)
from #n where i <= 50
union all
select i, 2, 'haber', 100 + i * 10, 11 + (i % 10)
from #n where i <= 50;

drop table #n;

select 'usuario' as tabla, count(*) as filas from dbo.usuario
union all select 'persona_comun', count(*) from dbo.persona_comun
union all select 'microempresa', count(*) from dbo.microempresa
union all select 'usuario_microempresa', count(*) from dbo.usuario_microempresa
union all select 'catalogocuentas', count(*) from dbo.catalogocuentas
union all select 'cuenta', count(*) from dbo.cuenta
union all select 'balance_general', count(*) from dbo.balance_general
union all select 'balance_cuenta', count(*) from dbo.balance_cuenta
union all select 'asiento_contable', count(*) from dbo.asiento_contable
union all select 'movimiento_asiento', count(*) from dbo.movimiento_asiento;
GO
--Rodrigo------------------------------------------