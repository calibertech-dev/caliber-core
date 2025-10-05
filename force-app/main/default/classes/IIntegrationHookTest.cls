@IsTest
private class IIntegrationHookTest {

    // simple counters so we can assert behavior
    private static Integer invoked = 0;
    private static String lastEvent;
    private static Map<String, Object> lastPayload;

    // Private test-only implementer of the interface
    private class DummyHook implements IIntegrationHook {
        public String key()        { return 'dummy'; }
        public Boolean isEnabled() { return true; }
        public void onEvent(String eventName, Map<String, Object> payload) {
            invoked++;
            lastEvent = eventName;
            lastPayload = payload;
        }
    }

    @IsTest static void compiles_and_invokes() {
        IIntegrationHook h = new DummyHook();
        System.assertEquals('dummy', h.key());
        System.assertEquals(true, h.isEnabled());

        Map<String,Object> p = new Map<String,Object>{ 'a' => 1, 'b' => 'x' };
        h.onEvent('HELLO', p);

        System.assertEquals(1, invoked, 'Expected onEvent to increment counter once');
        System.assertEquals('HELLO', lastEvent, 'Event name should flow through');
        System.assertEquals(1, (Integer) lastPayload.get('a'));
        System.assertEquals('x', (String) lastPayload.get('b'));
    }
}
