/*
Expected seeded counts (UTC; windows are inclusive start, exclusive end):

Device             2025-01-15             2025-01-16             Total
TEST-D-10001        3                      2                      5
TEST-D-10002        2                      2                      4
TEST-X-20001        1                      2                      3
All devices         6                      6                     12

Date windows:
2025-01-15: [2025-01-15T00:00:00+00:00, 2025-01-16T00:00:00+00:00)
2025-01-16: [2025-01-16T00:00:00+00:00, 2025-01-17T00:00:00+00:00)
Both dates: [2025-01-15T00:00:00+00:00, 2025-01-17T00:00:00+00:00)
*/
USE [PositionsDb];
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Devices WHERE DeviceId = N'TEST-D-10001')
BEGIN
    INSERT INTO dbo.Devices (DeviceId, Name)
    VALUES (N'TEST-D-10001', N'Test Device 10001');
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Devices WHERE DeviceId = N'TEST-D-10002')
BEGIN
    INSERT INTO dbo.Devices (DeviceId, Name)
    VALUES (N'TEST-D-10002', N'Test Device 10002');
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Devices WHERE DeviceId = N'TEST-X-20001')
BEGIN
    INSERT INTO dbo.Devices (DeviceId, Name)
    VALUES (N'TEST-X-20001', N'Test Device 20001');
END;
GO

INSERT INTO dbo.Positions
    (Id, DeviceId, OccurredAt, Latitude, Longitude, SpeedKph, HeadingDeg)
SELECT seed.Id, seed.DeviceId, seed.OccurredAt, seed.Latitude, seed.Longitude, seed.SpeedKph, seed.HeadingDeg
FROM
(
    VALUES
        (N'pos-test-10001-01', N'TEST-D-10001', '2025-01-15T08:00:00+00:00', 51.507351, -0.127758, 42.50, 90.00),
        (N'pos-test-10001-02', N'TEST-D-10001', '2025-01-15T10:00:00+00:00', 51.508000, -0.128000, 45.00, 95.00),
        (N'pos-test-10001-03', N'TEST-D-10001', '2025-01-15T12:00:00+00:00', 51.509000, -0.129000, 48.25, 100.00),
        (N'pos-test-10001-04', N'TEST-D-10001', '2025-01-16T08:00:00+00:00', 51.510000, -0.130000, 50.00, 105.00),
        (N'pos-test-10001-05', N'TEST-D-10001', '2025-01-16T12:00:00+00:00', 51.511000, -0.131000, 52.75, 110.00),
        (N'pos-test-10002-01', N'TEST-D-10002', '2025-01-15T09:00:00+00:00', 40.712800, -74.006000, 30.00, 180.00),
        (N'pos-test-10002-02', N'TEST-D-10002', '2025-01-15T13:00:00+00:00', 40.713000, -74.007000, 32.50, 185.00),
        (N'pos-test-10002-03', N'TEST-D-10002', '2025-01-16T09:00:00+00:00', 40.714000, -74.008000, 35.00, 190.00),
        (N'pos-test-10002-04', N'TEST-D-10002', '2025-01-16T14:00:00+00:00', 40.715000, -74.009000, 37.25, 195.00),
        (N'pos-test-20001-01', N'TEST-X-20001', '2025-01-15T11:00:00+00:00', 34.052200, -118.243700, 55.00, 270.00),
        (N'pos-test-20001-02', N'TEST-X-20001', '2025-01-16T10:00:00+00:00', 34.053000, -118.244000, 58.00, 275.00),
        (N'pos-test-20001-03', N'TEST-X-20001', '2025-01-16T15:00:00+00:00', 34.054000, -118.245000, 60.50, 280.00)
) AS seed (Id, DeviceId, OccurredAt, Latitude, Longitude, SpeedKph, HeadingDeg)
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.Positions AS existing
    WHERE existing.Id = seed.Id
);
GO
