IF DB_ID(N'PositionsDb') IS NULL
BEGIN
    CREATE DATABASE [PositionsDb];
END;
GO

USE [PositionsDb];
GO

IF OBJECT_ID(N'dbo.Devices', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Devices
    (
        DeviceId NVARCHAR(50) NOT NULL,
        Name NVARCHAR(100) NOT NULL,
        CONSTRAINT PK_Devices PRIMARY KEY (DeviceId)
    );
END;
GO

IF OBJECT_ID(N'dbo.Positions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Positions
    (
        Id NVARCHAR(100) NOT NULL,
        DeviceId NVARCHAR(50) NOT NULL,
        OccurredAt DATETIMEOFFSET(7) NOT NULL,
        Latitude DECIMAL(9, 6) NOT NULL,
        Longitude DECIMAL(9, 6) NOT NULL,
        SpeedKph DECIMAL(7, 2) NOT NULL,
        HeadingDeg DECIMAL(6, 2) NOT NULL,
        CONSTRAINT PK_Positions PRIMARY KEY (Id),
        CONSTRAINT FK_Positions_Devices
            FOREIGN KEY (DeviceId) REFERENCES dbo.Devices (DeviceId)
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_Positions_DeviceId_OccurredAt'
      AND object_id = OBJECT_ID(N'dbo.Positions')
)
BEGIN
    CREATE INDEX IX_Positions_DeviceId_OccurredAt
        ON dbo.Positions (DeviceId, OccurredAt);
END;
GO
