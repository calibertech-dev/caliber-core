global with sharing class CoreThrowHook implements IIntegrationHook {
    public class BoomException extends Exception {}
    public String key()        { return 'throw'; }
    public Boolean isEnabled() { return true; }
    public void onEvent(String eventName, Map<String,Object> payload) {
        throw new BoomException('boom');
    }
}
