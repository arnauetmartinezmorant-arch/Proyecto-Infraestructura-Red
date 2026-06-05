/* 06-sql-bd-y-alwayson.sql — Ejecutar en SSMS conectado a SQL01.
   BD + TDE + logins + esquema + datos + Availability Group + Listener. */

-- 1) BD y cifrado TDE (RN06)
CREATE DATABASE intranet_corporativa;
GO
USE master;
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name='##MS_DatabaseMasterKey##')
  CREATE MASTER KEY ENCRYPTION BY PASSWORD='Str0ng!Master';
IF NOT EXISTS (SELECT * FROM sys.certificates WHERE name='TDECert')
  CREATE CERTIFICATE TDECert WITH SUBJECT='TDE Cert';
GO
USE intranet_corporativa;
CREATE DATABASE ENCRYPTION KEY WITH ALGORITHM=AES_256 ENCRYPTION BY SERVER CERTIFICATE TDECert;
ALTER DATABASE intranet_corporativa SET ENCRYPTION ON;
GO

-- 2) Logins/usuarios (principio de minimo privilegio)
USE master;
CREATE LOGIN app_user    WITH PASSWORD='App!2025';
CREATE LOGIN backup_user WITH PASSWORD='Bkp!2025';
CREATE LOGIN admin_db    WITH PASSWORD='Adm!2025';
ALTER SERVER ROLE sysadmin ADD MEMBER admin_db;
GO
USE intranet_corporativa;
CREATE USER app_user FOR LOGIN app_user;       EXEC sp_addrolemember 'db_datareader','app_user'; EXEC sp_addrolemember 'db_datawriter','app_user';
CREATE USER backup_user FOR LOGIN backup_user; EXEC sp_addrolemember 'db_datareader','backup_user';
GO

-- 3) Esquema minimo de incidencias + datos de ejemplo
CREATE TABLE Departamento(id_departamento INT IDENTITY PRIMARY KEY, nombre NVARCHAR(50), descripcion NVARCHAR(100));
CREATE TABLE Incidencia(
  id_incidencia INT IDENTITY PRIMARY KEY, titulo NVARCHAR(100),
  prioridad NVARCHAR(10), estado NVARCHAR(20),
  fecha_creacion DATETIME, fecha_cierre DATETIME NULL, id_departamento INT NULL);
INSERT INTO Departamento(nombre,descripcion) VALUES ('Administracion','Area admin'),('Oficinas','Usuarios'),('Tecnicos','Soporte');
INSERT INTO Incidencia(titulo,prioridad,estado,fecha_creacion,fecha_cierre,id_departamento) VALUES
 ('No imprime','Media','Resuelta','2025-05-01','2025-05-01',2),
 ('Sin red','Alta','Resuelta','2025-05-02','2025-05-03',2),
 ('Cambio clave','Baja','Cerrada','2025-05-02','2025-05-02',1),
 ('VPN caida','Alta','En curso','2025-05-04',NULL,3),
 ('Correo lento','Media','Abierta','2025-05-05',NULL,1);
GO

-- 4) Always On: preparar BD y crear el Availability Group + Listener
ALTER DATABASE intranet_corporativa SET RECOVERY FULL;
BACKUP DATABASE intranet_corporativa TO DISK='C:\Backups\full.bak';
BACKUP LOG intranet_corporativa TO DISK='C:\Backups\log.trn';
GO
CREATE AVAILABILITY GROUP AG_Intranet FOR DATABASE intranet_corporativa
 REPLICA ON
  'SQL01' WITH (ENDPOINT_URL='TCP://SQL01.corp.local:5022', AVAILABILITY_MODE=SYNCHRONOUS_COMMIT, FAILOVER_MODE=AUTOMATIC),
  'SQL02' WITH (ENDPOINT_URL='TCP://SQL02.corp.local:5022', AVAILABILITY_MODE=SYNCHRONOUS_COMMIT, FAILOVER_MODE=AUTOMATIC);
GO
ALTER AVAILABILITY GROUP AG_Intranet
 ADD LISTENER 'AG-Intranet' (WITH IP (('10.10.10.30','255.255.255.0')), PORT=1433);
GO
-- EVIDENCIA: Availability Group Dashboard en estado Synchronized/Healthy.
