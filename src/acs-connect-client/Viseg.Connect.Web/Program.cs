using System.Globalization;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Localization;
using Microsoft.Extensions.Localization;
using Microsoft.FluentUI.AspNetCore.Components;
using Viseg.Connect.Web.Components;
using Viseg.Connect.Web.Configuration;
using Viseg.Connect.Web.Localization;
using Viseg.Connect.Web.Preferences;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddRazorComponents().AddInteractiveServerComponents();
builder.Services.AddFluentUIComponents();
builder.Services.AddLocalization();
builder.Services.AddHttpContextAccessor();
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddProblemDetails();
builder.Services.AddResponseCompression(options => options.EnableForHttps = true);
builder.Services.AddOptions<DemoOptions>().BindConfiguration("Demo").ValidateOnStart();
builder.Services.AddOptions<AccessOptions>().BindConfiguration("Access").ValidateOnStart();
builder.Services.AddOptions<RefreshOptions>().BindConfiguration("Refresh").ValidateDataAnnotations().ValidateOnStart();
builder.Services.AddOptions<DashboardOptions>().BindConfiguration("Dashboards").ValidateDataAnnotations().ValidateOnStart();
builder.Services.AddOptions<TelemetryOptions>().BindConfiguration("Telemetry").ValidateDataAnnotations()
    .Validate(options => !options.TraceBasedLogSampling, "Independent warning/error log export is required.").ValidateOnStart();
builder.Services.Configure<RequestLocalizationOptions>(options =>
{
    var cultures = DisplayPreferences.SupportedCultures.Select(name => new CultureInfo(name)).ToArray();
    options.DefaultRequestCulture = new RequestCulture("en-US");
    options.SupportedCultures = cultures;
    options.SupportedUICultures = cultures;
    options.RequestCultureProviders = [new CookieRequestCultureProvider(), new AcceptLanguageHeaderRequestCultureProvider()];
});

var app = builder.Build();
app.UseResponseCompression();
app.UseRequestLocalization();
app.UseExceptionHandler(errorApp => errorApp.Run(async context =>
{
    var text = context.RequestServices.GetRequiredService<IStringLocalizer<ProblemResources>>();
    await Results.Problem(statusCode: 500, title: text["Unexpected"], detail: text["TryAgain"],
        extensions: new Dictionary<string, object?> { ["code"] = "Unexpected", ["traceId"] = context.TraceIdentifier }).ExecuteAsync(context);
}));
app.Use(async (context, next) =>
{
    context.Response.Headers.XContentTypeOptions = "nosniff";
    context.Response.Headers["Referrer-Policy"] = "same-origin";
    context.Response.Headers.CacheControl = "no-store";
    await next(context);
});
app.UseAntiforgery();
app.MapGet("/health/live", () => Results.Ok(new { status = "healthy" }));
app.MapPost("/preferences", async (HttpContext context, IAntiforgery antiforgery, IStringLocalizer<ProblemResources> text) =>
{
    try { await antiforgery.ValidateRequestAsync(context); }
    catch (AntiforgeryValidationException) { return Results.Problem(statusCode: 400, title: text["InvalidRequest"], extensions: new Dictionary<string, object?> { ["code"] = "InvalidRequest" }); }
    var form = await context.Request.ReadFormAsync(context.RequestAborted);
    var theme = form["theme"].ToString();
    var culture = form["culture"].ToString();
    if (!DisplayPreferences.IsTheme(theme) || !DisplayPreferences.IsCulture(culture))
        return Results.Problem(statusCode: 400, title: text["InvalidPreference"], extensions: new Dictionary<string, object?> { ["code"] = "InvalidPreference" });
    DisplayPreferences.Write(context, theme, culture);
    return Results.LocalRedirect(DisplayPreferences.SafeReturnPath(form["returnUrl"]));
});
app.MapStaticAssets();
app.MapRazorComponents<App>().AddInteractiveServerRenderMode();
app.Run();

public partial class Program;
