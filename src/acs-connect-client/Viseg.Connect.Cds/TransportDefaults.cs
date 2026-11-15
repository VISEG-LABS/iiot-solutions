namespace Viseg.Connect.Cds;

/// <summary>Transport bounds; authenticated CONNECT operations are introduced behind the resource gateway.</summary>
public static class TransportDefaults
{
    public static readonly TimeSpan RequestTimeout = TimeSpan.FromSeconds(20);
    public const int MaximumResponseBytes = 8 * 1024 * 1024;
}
