using System.Globalization;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Localization;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Viseg.Connect.Core.Validation;
using Viseg.Connect.Web.Localization;
using Viseg.Connect.Web.Preferences;

namespace Viseg.Connect.Tests;

[TestClass]
public sealed class FoundationTests
{
    [TestMethod]
    [DataRow("https://example.com")]
    [DataRow("//example.com/path")]
    [DataRow("/\\example.com")]
    [DataRow("/\r\nLocation: other")]
    public void ReturnPathsCannotRedirectOutsideApplication(string path) => Assert.AreEqual("/", DisplayPreferences.SafeReturnPath(path));

    [TestMethod]
    public void QueryBoundsRejectReversedRangesAndExcessiveData()
    {
        var end = DateTimeOffset.UtcNow;
        var start = end.AddHours(-1);
        var limits = new QueryLimits(TimeSpan.FromDays(1), 1000);
        Assert.IsNull(QueryRules.Validate(start, end, 1000, limits));
        Assert.AreEqual("RangeOrder", QueryRules.Validate(end, start, 10, limits));
        Assert.AreEqual("RangeOrder", QueryRules.Validate(end, end, 10, limits));
        Assert.AreEqual("RangeTooWide", QueryRules.Validate(end.AddDays(-2), end, 10, limits));
        Assert.AreEqual("PointLimit", QueryRules.Validate(start, end, 1001, limits));
        Assert.AreEqual("PointLimit", QueryRules.Validate(start, end, 0, limits));
    }

    [TestMethod]
    public void EveryFeatureResourceHasCompleteEnglishAndSwedishTranslations()
    {
        var services = new ServiceCollection().AddLogging().AddLocalization();
        using var provider = services.BuildServiceProvider();
        var factory = provider.GetRequiredService<IStringLocalizerFactory>();
        var original = CultureInfo.CurrentUICulture;
        try
        {
            foreach (var type in new[] { typeof(ShellResources), typeof(ObserveResources), typeof(DashboardResources), typeof(ProblemResources) })
            {
                var localizer = factory.Create(type);
                CultureInfo.CurrentUICulture = new CultureInfo("en-US");
                var english = localizer.GetAllStrings(true).ToDictionary(item => item.Name, item => item.Value);
                CultureInfo.CurrentUICulture = new CultureInfo("sv-SE");
                var swedish = localizer.GetAllStrings(false).ToDictionary(item => item.Name, item => item.Value);
                Assert.IsGreaterThan(0, english.Count, $"No resources found for {type.Name}.");
                CollectionAssert.AreEquivalent(english.Keys.ToArray(), swedish.Keys.ToArray());
                Assert.IsTrue(swedish.Values.All(value => !string.IsNullOrWhiteSpace(value)));
            }
        }
        finally { CultureInfo.CurrentUICulture = original; }
    }
}
