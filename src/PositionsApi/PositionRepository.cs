using Microsoft.Data.SqlClient;
using System.Data;

public sealed class PositionRepository(string connectionString)
{
    public async Task<Position?> GetByIdAsync(string id, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(
            """
            SELECT Id, DeviceId, OccurredAt, Latitude, Longitude, SpeedKph, HeadingDeg
            FROM dbo.Positions
            WHERE Id = @Id;
            """,
            connection);
        command.Parameters.Add("@Id", SqlDbType.NVarChar, 100).Value = id;

        await using var reader = await command.ExecuteReaderAsync(CommandBehavior.SingleRow, cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return new Position(
            reader.GetString(0),
            reader.GetString(1),
            reader.GetFieldValue<DateTimeOffset>(2),
            reader.GetDecimal(3),
            reader.GetDecimal(4),
            reader.GetDecimal(5),
            reader.GetDecimal(6));
    }

    public async Task<bool> TryInsertAsync(Position position, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);

        try
        {
            await using (var deviceCommand = new SqlCommand(
                """
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM dbo.Devices WITH (UPDLOCK, HOLDLOCK)
                    WHERE DeviceId = @DeviceId
                )
                BEGIN
                    INSERT INTO dbo.Devices (DeviceId, Name)
                    VALUES (@DeviceId, @DeviceName);
                END;
                """,
                connection,
                transaction))
            {
                deviceCommand.Parameters.Add("@DeviceId", SqlDbType.NVarChar, 50).Value = position.DeviceId;
                deviceCommand.Parameters.Add("@DeviceName", SqlDbType.NVarChar, 100).Value = position.DeviceId;
                await deviceCommand.ExecuteNonQueryAsync(cancellationToken);
            }

            await using (var positionCommand = new SqlCommand(
                """
                INSERT INTO dbo.Positions
                    (Id, DeviceId, OccurredAt, Latitude, Longitude, SpeedKph, HeadingDeg)
                VALUES
                    (@Id, @DeviceId, @OccurredAt, @Latitude, @Longitude, @SpeedKph, @HeadingDeg);
                """,
                connection,
                transaction))
            {
                positionCommand.Parameters.Add("@Id", SqlDbType.NVarChar, 100).Value = position.Id;
                positionCommand.Parameters.Add("@DeviceId", SqlDbType.NVarChar, 50).Value = position.DeviceId;
                positionCommand.Parameters.Add("@OccurredAt", SqlDbType.DateTimeOffset).Value = position.OccurredAt;
                AddDecimal(positionCommand, "@Latitude", position.Latitude, 9, 6);
                AddDecimal(positionCommand, "@Longitude", position.Longitude, 9, 6);
                AddDecimal(positionCommand, "@SpeedKph", position.SpeedKph, 7, 2);
                AddDecimal(positionCommand, "@HeadingDeg", position.HeadingDeg, 6, 2);

                await positionCommand.ExecuteNonQueryAsync(cancellationToken);
            }

            await transaction.CommitAsync(cancellationToken);
            return true;
        }
        catch (SqlException exception) when (exception.Number is 2601 or 2627)
        {
            return false;
        }
    }

    private static void AddDecimal(
        SqlCommand command,
        string name,
        decimal value,
        byte precision,
        byte scale)
    {
        var parameter = command.Parameters.Add(name, SqlDbType.Decimal);
        parameter.Precision = precision;
        parameter.Scale = scale;
        parameter.Value = value;
    }
}
