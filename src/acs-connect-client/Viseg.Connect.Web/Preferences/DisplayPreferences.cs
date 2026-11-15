using Microsoft.AspNetCore.Localization;

namespace Viseg.Connect.Web.Preferences;

public static class DisplayPreferences
{
    public const string ThemeCookie = "viseg.theme";
    public static readonly string[] SupportedCultures = ["en-US", "sv-SE"];
    public static bool IsTheme(string? value) => value is "dark" or "light";
    public static bool IsCulture(string? value) => value is "en-US" or "sv-SE";
    public static string ReadTheme(HttpContext? context) =>
        context?.Request.Cookies[ThemeCookie] is "light" ? "light" : "dark";
    public static string SafeReturnPath(string? value) =>
        value is not null && value.StartsWith('/') && !value.StartsWith("//", StringComparison.Ordinal) &&
        !value.Contains('\\') && !value.Any(char.IsControl) ? value : "/";
    public static CookieOptions CookieOptions(HttpContext context) => new()
    {
        HttpOnly = true, Secure = context.Request.IsHttps, SameSite = SameSiteMode.Lax,
        IsEssential = true, Path = "/", MaxAge = TimeSpan.FromDays(365)
    };
    public static void Write(HttpContext context, string theme, string culture)
    {
        context.Response.Cookies.Append(ThemeCookie, theme, CookieOptions(context));
        context.Response.Cookies.Append(CookieRequestCultureProvider.DefaultCookieName,
            CookieRequestCultureProvider.MakeCookieValue(new RequestCulture(culture)), CookieOptions(context));
    }
}
