using System.ComponentModel.DataAnnotations;

namespace Viseg.Connect.Web.Configuration;

public sealed class DemoOptions { public bool UseSyntheticData { get; set; } }
public sealed class AccessOptions { public bool RequireAllowlist { get; set; } = true; }
public sealed class RefreshOptions { [Range(1, 3600)] public int MinimumSeconds { get; set; } = 30; }
public sealed class DashboardOptions { [Range(1, 20)] public int MaxWidgets { get; set; } = 20; }
public sealed class TelemetryOptions
{
    [Range(0.0, 1.0)] public double SamplingRatio { get; set; } = 0.1;
    public bool TraceBasedLogSampling { get; set; }
}
