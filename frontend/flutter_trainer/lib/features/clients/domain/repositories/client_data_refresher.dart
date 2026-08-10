/// Optional capability for repositories whose server-backed client streams
/// can be revalidated without replacing their current subscriptions.
abstract interface class ClientDataRefresher {
  /// Revalidates every currently subscribed client-data stream.
  void refreshAllClientData();

  /// Revalidates the roster and currently subscribed data for [clientId].
  void refreshClientData(String clientId);
}
