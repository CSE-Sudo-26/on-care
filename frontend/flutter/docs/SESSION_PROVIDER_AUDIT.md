# Session provider state audit

Issue #318 audits Riverpod state that can outlive an account transition. A
provider is reset when it caches account-specific server data or owns mutable
demo data that one account must not expose to the next account.

Account-specific leaf/controller providers are registered explicitly in
`app/session_feature_reset.dart`. Stateful mock repository roots are also
recreated so their local mutations cannot cross a session boundary. Explicit
leaf invalidation is necessary because a repository can rebuild to the same
const instance, in which case Riverpod may leave its dependents unchanged.

## Reset on account transition

| Provider group | Why state can cross accounts | Reset decision |
| --- | --- | --- |
| `profileProvider` | Non-auto-dispose account profile cache | Invalidate the cached profile |
| `aiCoachStateProvider`, `chatControllerProvider` | Non-auto-dispose personalized suggestions and in-memory chat | Invalidate both leaves |
| `dashboardSummaryProvider` | An active watcher can retain the previous account summary | Invalidate the summary |
| `dietRepositoryProvider`, `dietTodayProvider`, `dietRecommendationsProvider` | The mock repository mutates meals in memory; the leaves cache today's diet and personalized recommendations | Recreate the mock root and invalidate both leaves |
| `exerciseRepositoryProvider`, `exerciseWeekProvider` | The mock repository mutates sessions in memory; the leaf caches the week | Recreate the mock root and invalidate the leaf |
| `exerciseRoutineDoneProvider` | Non-auto-dispose local completion flags | Restore the initial flags |
| `gymRepositoryProvider`, `myGymProvider`, `myTrainerProvider` | The mock repository mutates membership links; leaves cache account links | Recreate the mock root and invalidate account leaves |
| `consultationRequestControllerProvider` | Non-auto-dispose in-memory requests and pending state | Recreate the controller |
| `memberCoachRepositoryProvider` and its four leaf providers | The mock repository mutates chat; leaves cache coach, routines, chat, and unread state | Recreate the mock root and invalidate all four leaves |
| `myHealthStateProvider` | Non-auto-dispose profile, health risk, points, and settings cache | Invalidate the cached state |
| Notification controller/list | The controller retains read and simulated-push state; an active list watcher can retain fetched items | Recreate the controller and invalidate the list |
| Schedule date/month families | Active family instances can retain account schedule entries | Invalidate every family instance |

Auto-dispose alone is not a sufficient boundary: demo-to-login authentication
can succeed without leaving the current page, so an actively watched provider
can survive the transition. Authentication success therefore publishes the new
access token before resetting feature state, ensuring immediate refetches use
the new account.

## Intentionally retained

| Provider | Reason |
| --- | --- |
| `themeModeProvider`, `localeProvider` | Device/app display preferences, not account data |
| `placeQueryProvider`, place providers | Map position, filter, and public place search results |
| `appConfigProvider`, logger, preferences, database | App infrastructure; account transitions must not recreate the container or delete persisted local data |
| `appRouterProvider` | App navigation infrastructure |
| `authAccessTokenProvider` | Written directly by `SessionController` before feature reset |
| `authControllerProvider` | Legacy mock controller with no production consumer; the active session uses `SessionController` |

Server records are never deleted by this reset. Providers are only disposed and
recreated so the next read uses the current session.

In mock builds, account and schedule requests can be served from the same Drift
database by `LocalApiInterceptor`. Resetting their providers clears cached
responses, but the next read can return the same persisted rows. Deleting or
partitioning that local database is outside this provider-cache reset.
