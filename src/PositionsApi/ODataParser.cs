using System.Globalization;

public static class ODataParser
{
    private const int MaxTop = 1000;

    private static readonly HashSet<string> SupportedOptions =
        new(StringComparer.OrdinalIgnoreCase) { "$filter", "$orderby", "$top", "$count" };

    public static bool TryParse(IQueryCollection query, out ODataQuery? result, out string? error)
    {
        result = null;
        error = null;

        // Anything other than the four supported options is rejected, for example $skip or $select.
        foreach (var key in query.Keys)
        {
            if (!SupportedOptions.Contains(key))
            {
                error = $"Unsupported query option: {key}";
                return false;
            }
        }

        int? top = null;
        if (query.TryGetValue("$top", out var topText))
        {
            // NumberStyles.None allows digits only, so "-1", "+5", "1.5" and "abc" all fail.
            if (!int.TryParse(topText.ToString(), NumberStyles.None, CultureInfo.InvariantCulture, out var parsedTop)
                || parsedTop > MaxTop)
            {
                error = "$top must be a whole number from 0 to 1000.";
                return false;
            }

            top = parsedTop;
        }

        // $orderby: only occurredAt is supported. Plain "occurredAt" means ascending.
        var orderDescending = false;
        if (query.TryGetValue("$orderby", out var orderByText))
        {
            switch (orderByText.ToString())
            {
                case "occurredAt":
                case "occurredAt asc":
                    break;
                case "occurredAt desc":
                    orderDescending = true;
                    break;
                default:
                    error = "$orderby must be 'occurredAt asc' or 'occurredAt desc'.";
                    return false;
            }
        }

        // $count: only the exact text true or false is accepted.
        var includeCount = false;
        if (query.TryGetValue("$count", out var countText))
        {
            switch (countText.ToString())
            {
                case "true":
                    includeCount = true;
                    break;
                case "false":
                    break;
                default:
                    error = "$count must be true or false.";
                    return false;
            }
        }

        var filter = new FilterValues();
        if (query.TryGetValue("$filter", out var filterText)
            && !TryParseFilter(filterText.ToString(), filter, out error))
        {
            return false;
        }

        result = new ODataQuery(
            filter.DeviceIdEquals, filter.DeviceIdStartsWith, filter.DeviceIdContains,
            filter.OccurredFrom, filter.OccurredTo,
            orderDescending, top, includeCount);
        return true;
    }

    // Collects the filter values while we read the clauses one by one.
    private sealed class FilterValues
    {
        public string? DeviceIdEquals { get; set; }
        public string? DeviceIdStartsWith { get; set; }
        public string? DeviceIdContains { get; set; }
        public DateTimeOffset? OccurredFrom { get; set; }
        public DateTimeOffset? OccurredTo { get; set; }
    }

    // Splits the filter on " and " and checks each clause on its own.
    private static bool TryParseFilter(string filter, FilterValues values, out string? error)
    {
        error = null;
        foreach (var clause in filter.Split(" and "))
        {
            if (!TryParseClause(clause, values, out error))
            {
                return false;
            }
        }

        return true;
    }

    // Reads one clause. Anything we do not recognise is an error.
    private static bool TryParseClause(string clause, FilterValues values, out string? error)
    {
        error = null;

        const string equalsPrefix = "deviceId eq ";
        if (clause.StartsWith(equalsPrefix, StringComparison.Ordinal))
        {
            if (values.DeviceIdEquals is not null)
            {
                error = "deviceId eq can only be used once.";
                return false;
            }

            if (!TryReadQuoted(clause[equalsPrefix.Length..], out var text))
            {
                error = "deviceId eq needs a value in single quotes, for example 'TEST-D-10001'.";
                return false;
            }

            values.DeviceIdEquals = text;
            return true;
        }

        const string fromPrefix = "occurredAt ge ";
        if (clause.StartsWith(fromPrefix, StringComparison.Ordinal))
        {
            if (values.OccurredFrom is not null)
            {
                error = "occurredAt ge can only be used once.";
                return false;
            }

            if (!TryReadDate(clause[fromPrefix.Length..], out var fromDate))
            {
                error = "occurredAt ge needs an ISO 8601 timestamp with a timezone, for example 2025-01-15T00:00:00Z.";
                return false;
            }

            values.OccurredFrom = fromDate;
            return true;
        }

        const string toPrefix = "occurredAt le ";
        if (clause.StartsWith(toPrefix, StringComparison.Ordinal))
        {
            if (values.OccurredTo is not null)
            {
                error = "occurredAt le can only be used once.";
                return false;
            }

            if (!TryReadDate(clause[toPrefix.Length..], out var toDate))
            {
                error = "occurredAt le needs an ISO 8601 timestamp with a timezone, for example 2025-01-15T23:59:59Z.";
                return false;
            }

            values.OccurredTo = toDate;
            return true;
        }

        if (clause.StartsWith("startswith(", StringComparison.Ordinal))
        {
            if (values.DeviceIdStartsWith is not null)
            {
                error = "startswith can only be used once.";
                return false;
            }

            if (!TryReadFunctionValue(clause, "startswith", out var prefix))
            {
                error = "startswith must look like startswith(deviceId,'TEST-D').";
                return false;
            }

            values.DeviceIdStartsWith = prefix;
            return true;
        }

        if (clause.StartsWith("contains(", StringComparison.Ordinal))
        {
            if (values.DeviceIdContains is not null)
            {
                error = "contains can only be used once.";
                return false;
            }

            if (!TryReadFunctionValue(clause, "contains", out var part))
            {
                error = "contains must look like contains(deviceId,'D-100').";
                return false;
            }

            values.DeviceIdContains = part;
            return true;
        }

        error = $"Unsupported $filter clause: {clause}";
        return false;
    }

    // Accepts 'text' (single quotes, no quote inside, not empty) and returns the text without the quotes.
    private static bool TryReadQuoted(string text, out string value)
    {
        value = "";
        if (text.Length < 3 || text[0] != '\'' || text[^1] != '\'')
        {
            return false;
        }

        var inner = text[1..^1];
        if (inner.Contains('\''))
        {
            return false;
        }

        value = inner;
        return true;
    }

    // Accepts 2025-01-15T00:00:00Z or '2025-01-15T00:00:00Z'. A timezone is required.
    private static bool TryReadDate(string text, out DateTimeOffset value)
    {
        value = default;

        // Tolerate quotes (the brief shows both forms); reuse the quote check from above.
        if (text.StartsWith('\'') && !TryReadQuoted(text, out text))
        {
            return false;
        }

        return PositionRequest.IsoTimestampWithTimeZone.IsMatch(text)
            && DateTimeOffset.TryParse(text, CultureInfo.InvariantCulture, DateTimeStyles.None, out value);
    }

    // Reads functionName(deviceId,'text') and returns the text. A space after the comma is allowed.
    private static bool TryReadFunctionValue(string clause, string functionName, out string value)
    {
        value = "";

        var start = functionName + "(deviceId,";
        if (!clause.StartsWith(start, StringComparison.Ordinal) || !clause.EndsWith(')'))
        {
            return false;
        }

        // Everything between "functionName(deviceId," and the closing bracket.
        var argument = clause[start.Length..^1].TrimStart();
        return TryReadQuoted(argument, out value);
    }
}
