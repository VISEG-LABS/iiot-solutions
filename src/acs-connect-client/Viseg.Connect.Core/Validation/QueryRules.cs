namespace Viseg.Connect.Core.Validation;

public sealed record QueryLimits(TimeSpan MaximumSpan, int MaximumPoints);

public static class QueryRules
{
    public static string? Validate(DateTimeOffset start, DateTimeOffset end, int points, QueryLimits limits)
    {
        ArgumentNullException.ThrowIfNull(limits);
        if (limits.MaximumSpan <= TimeSpan.Zero || limits.MaximumPoints < 1)
            throw new ArgumentOutOfRangeException(nameof(limits));
        if (start >= end) return "RangeOrder";
        if (end - start > limits.MaximumSpan) return "RangeTooWide";
        return points < 1 || points > limits.MaximumPoints ? "PointLimit" : null;
    }
}
