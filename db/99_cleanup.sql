USE [PositionsDb];
GO

DELETE FROM dbo.Positions
WHERE Id LIKE N'pos-test-%'
   OR DeviceId LIKE N'TEST-%';
GO

DELETE FROM dbo.Devices
WHERE DeviceId LIKE N'TEST-%';
GO
