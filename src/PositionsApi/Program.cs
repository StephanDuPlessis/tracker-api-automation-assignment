using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Http.Json;

var builder = WebApplication.CreateBuilder(args);

var apiKey = Environment.GetEnvironmentVariable("API_KEY");
if (string.IsNullOrWhiteSpace(apiKey))
{
    throw new InvalidOperationException("Set the API_KEY environment variable before starting the API.");
}

var connectionString = Environment.GetEnvironmentVariable("DB_CONNECTION_STRING");
if (connectionString is null)
{
    connectionString = "Server=(localdb)\\MSSQLLocalDB;Database=PositionsDb;Integrated Security=True;TrustServerCertificate=True;";
}
else if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException("DB_CONNECTION_STRING cannot be empty.");
}

var urls = Environment.GetEnvironmentVariable("ASPNETCORE_URLS");
builder.WebHost.UseUrls(string.IsNullOrWhiteSpace(urls) ? "http://localhost:5080" : urls);
builder.Services.ConfigureHttpJsonOptions(options =>
    options.SerializerOptions.Converters.Add(new UtcDateTimeOffsetJsonConverter()));
builder.Services.AddSingleton(new PositionRepository(connectionString));

var app = builder.Build();

app.Use(async (context, next) =>
{
    var suppliedKey = context.Request.Headers["X-Api-Key"].ToString();
    var expectedBytes = Encoding.UTF8.GetBytes(apiKey);
    var suppliedBytes = Encoding.UTF8.GetBytes(suppliedKey);

    if (suppliedKey.Length == 0 || !CryptographicOperations.FixedTimeEquals(expectedBytes, suppliedBytes))
    {
        context.Response.StatusCode = StatusCodes.Status401Unauthorized;
        await context.Response.WriteAsJsonAsync(new { error = "Unauthorized." });
        return;
    }

    await next();
});

app.MapPost("/positions", CreatePositionAsync);
app.MapGet("/positions/{id}", GetPositionAsync);

app.Run();

static async Task<IResult> CreatePositionAsync(
    HttpRequest request,
    PositionRepository repository,
    CancellationToken cancellationToken)
{
    JsonDocument document;
    try
    {
        document = await JsonDocument.ParseAsync(request.Body, cancellationToken: cancellationToken);
    }
    catch (JsonException)
    {
        return Results.BadRequest(new { error = "Request body must be valid JSON." });
    }

    using (document)
    {
        if (document.RootElement.ValueKind != JsonValueKind.Object)
        {
            return Results.BadRequest(new { error = "Request body must be a JSON object." });
        }

        if (!PositionRequest.TryParse(document.RootElement, out var position, out var error))
        {
            return Results.BadRequest(new { error });
        }

        if (!await repository.TryInsertAsync(position, cancellationToken))
        {
            return Results.Conflict(new { error = "A position with this id already exists." });
        }

        return Results.Created($"/positions/{Uri.EscapeDataString(position.Id)}", position);
    }
}

static async Task<IResult> GetPositionAsync(
    string id,
    PositionRepository repository,
    CancellationToken cancellationToken)
{
    var position = await repository.GetByIdAsync(id, cancellationToken);
    return position is null ? Results.NotFound() : Results.Ok(position);
}
