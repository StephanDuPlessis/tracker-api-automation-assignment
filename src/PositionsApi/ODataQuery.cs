public sealed record ODataQuery(
    string? DeviceIdEquals,
    string? DeviceIdStartsWith,
    string? DeviceIdContains,
    DateTimeOffset? OccurredFrom,
    DateTimeOffset? OccurredTo,
    bool OrderDescending,
    int? Top,
    bool IncludeCount);