global with sharing class CoreTestHook implements IIntegrationHook {
    public static Integer hits = 0;
    public static String lastEvent;
    public static Map<String,Object> lastPayload;

    public String key()        { return 'coretest'; }
    public Boolean isEnabled() { return true; }
    public void onEvent(String eventName, Map<String,Object> payload) {
        hits++;
        lastEvent = eventName;
        lastPayload = payload;
    }
}
