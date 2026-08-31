/// Centralized backend endpoint configuration.
///
/// The GraphQL URL is baked in at build time via `--dart-define=FRSH_API_URL=...`
/// so it can be swapped between environments (local/staging/production)
/// without touching source. Every feature should read [ApiConfig.graphqlUrl]
/// instead of hard-coding the backend URL.
class ApiConfig {
  const ApiConfig._();

  static const String graphqlUrl = String.fromEnvironment(
    'FRSH_API_URL',
    defaultValue: 'https://frshnearby-api.onrender.com/graphql',
  );
}
