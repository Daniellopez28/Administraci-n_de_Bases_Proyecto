Create database CountingFriend_BD;
Go

use CountingFriend_BD;
go

--Daniel
--Entidades fuertes o padres pues
--Tabla Usuario
create table Usuario(
id_usuario int primary key,
nombre varchar(200) not null,
correo varchar(150) not null,
contrasena varchar(255) not null
);

--tabla MICROEMPRESA
create table MicroEmpresa(
id_microempresa int primary key,
nombre varchar(150) not null,
--Regla que si o si la empresa es una natural o juridica
tipo varchar(20) check (tipo in ('Natural', 'Juridica')),
nit varchar(20) unique
);

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
id_cuenta int primary key,
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
