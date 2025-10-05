global interface IIntegrationHook {
    // Short, stable id like 'stripe' or 'magicplan'
    String key();

    // Implementer decides if it’s enabled (e.g., via its own config)
    Boolean isEnabled();

    // Generic event hook
    void onEvent(String eventName, Map<String, Object> payload);
}
