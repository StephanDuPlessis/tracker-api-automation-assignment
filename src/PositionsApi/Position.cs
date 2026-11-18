using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

public sealed record Position(
    string Id,
    string DeviceId,
    DateTimeOffset OccurredAt,
    decimal Latitude,
    decimal Longitude,
    decimal SpeedKph,
    decimal HeadingDeg);

public static class PositionRequest
{
    internal static readonly Regex IsoTimestampWithTimeZone = new(
        @"\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})\z",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

    public static bool TryParse(JsonElement json, out Position position, out string error)
    {
        position = null!;
        error = string.Empty;

        if (!TryReadString(json, "id", out var id))
        {
            error = "id is required and must be a non-empty string.";
            return false;
        }

        if (id.Length > 100)
        {
            error = "id must not exceed 100 characters.";
            return false;
        }

        if (!TryReadString(json, "deviceId", out var deviceId))
        {
            error = "deviceId is required and must be a non-empty string.";
            return false;
        }

        if (deviceId.Length > 50)
        {
            error = "deviceId must not exceed 50 characters.";
            return false;
        }

        if (!TryReadString(json, "occurredAt", out var occurredAtText)
            || !IsoTimestampWithTimeZone.IsMatch(occurredAtText)
            || !DateTimeOffset.TryParse(
                occurredAtText,
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out var occurredAt))
        {
            error = "occurredAt must be an ISO 8601 timestamp with a timezone.";
            return false;
        }

        if (!TryReadDecimal(json, "latitude", out var latitude))
        {
            error = "latitude must be a number.";
            return false;
        }

        if (latitude is < -90 or > 90)
        {
            error = "latitude must be between -90 and 90.";
            return false;
        }

        if (!TryReadDecimal(json, "longitude", out var longitude))
        {
            error = "longitude must be a number.";
            return false;
        }

        if (longitude is < -180 or > 180)
        {
            error = "longitude must be between -180 and 180.";
            return false;
        }

        if (!TryReadDecimal(json, "speedKph", out var speedKph))
        {
            error = "speedKph must be a number.";
            return false;
        }

        if (speedKph is < 0 or > 1000)
        {
            error = "speedKph must be between 0 and 1000.";
            return false;
        }

        if (!TryReadDecimal(json, "headingDeg", out var headingDeg))
        {
            error = "headingDeg must be a number.";
            return false;
        }

        if (headingDeg is < 0 or > 360)
        {
            error = "headingDeg must be between 0 and 360.";
            return false;
        }

        position = new Position(id, deviceId, occurredAt, latitude, longitude, speedKph, headingDeg);
        return true;
    }

    private static bool TryReadString(JsonElement json, string name, out string value)
    {
        value = string.Empty;
        if (!json.TryGetProperty(name, out var property)
            || property.ValueKind != JsonValueKind.String
            || string.IsNullOrWhiteSpace(property.GetString()))
        {
            return false;
        }

        value = property.GetString()!;
        return true;
    }

    private static bool TryReadDecimal(JsonElement json, string name, out decimal value)
    {
        value = 0;
        return json.TryGetProperty(name, out var property)
            && property.ValueKind == JsonValueKind.Number
            && property.TryGetDecimal(out value);
    }
}

public sealed class UtcDateTimeOffsetJsonConverter : JsonConverter<DateTimeOffset>
{
    public override DateTimeOffset Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        if (reader.TokenType != JsonTokenType.String
            || !DateTimeOffset.TryParse(
                reader.GetString(),
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out var value))
        {
            throw new JsonException("A valid date and time is required.");
        }

        return value;
    }

    public override void Write(Utf8JsonWriter writer, DateTimeOffset value, JsonSerializerOptions options)
    {
        writer.WriteStringValue(
            value.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss.FFFFFFF'Z'", CultureInfo.InvariantCulture));
    }
}
