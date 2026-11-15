using Microsoft.EntityFrameworkCore;

namespace Viseg.Connect.Data;

/// <summary>Persistence boundary. User/grant/dashboard entities and migrations follow with access management.</summary>
public sealed class ConnectDbContext(DbContextOptions<ConnectDbContext> options) : DbContext(options);
