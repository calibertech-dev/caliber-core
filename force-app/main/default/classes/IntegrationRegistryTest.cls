@IsTest
private class IntegrationRegistryTest {

    private static Integer hits = 0;
    private static String lastEvent;
    private static Map<String, Object> lastPayload;

    // Minimal inner implementer used for injection path
    private class DummyHook implements IIntegrationHook {
        public String key()        { return 'dummy'; }
        public Boolean isEnabled() { return true; }
        public void onEvent(String eventName, Map<String, Object> payload) {
            IntegrationRegistryTest.hits++;
            IntegrationRegistryTest.lastEvent = eventName;
            IntegrationRegistryTest.lastPayload = payload;
        }
    }

    @IsTest static void getHooks_returns_injected_only() {
        IntegrationRegistry.resetForTest();
        hits = 0; lastEvent = null; lastPayload = null;

        IntegrationRegistry.injectForTest(new List<IIntegrationHook>{ new DummyHook() });
        List<IntegrationRegistry.HookInfo> hooks = IntegrationRegistry.getHooks();

        System.assertEquals(1, hooks.size(), 'Should return injected hook');
        System.assertEquals('dummy', hooks[0].key);
    }

    @IsTest static void broadcast_invokes_all_injected_hooks() {
        IntegrationRegistry.resetForTest();
        hits = 0; lastEvent = null; lastPayload = null;

        IntegrationRegistry.injectForTest(new List<IIntegrationHook>{ new DummyHook() });

        Map<String,Object> p = new Map<String,Object>{ 'a' => 1, 'b' => 'x' };
        IntegrationRegistry.broadcast('TEST.EVENT', p);

        System.assertEquals(1, hits, 'Expected one invocation');
        System.assertEquals('TEST.EVENT', lastEvent);
        System.assertEquals(1, (Integer)lastPayload.get('a'));
        System.assertEquals('x', (String)lastPayload.get('b'));
    }

    @IsTest static void invoke_targets_by_key_and_reports_success_or_false() {
        IntegrationRegistry.resetForTest();
        hits = 0;

        IntegrationRegistry.injectForTest(new List<IIntegrationHook>{ new DummyHook() });

        Boolean ok = IntegrationRegistry.invoke('dummy', 'PING', new Map<String,Object>{});
        System.assertEquals(true, ok, 'Should return true when a hook handles the event');
        System.assertEquals(1, hits, 'Handler should be called once');

        Boolean miss = IntegrationRegistry.invoke('nope', 'PING', new Map<String,Object>{});
        System.assertEquals(false, miss, 'Unknown key should return false');
    }

    @IsTest static void cmdt_path_constructs_filters_and_infers_key() {
        IntegrationRegistry.resetForTest();
        CoreTestHook.hits = 0; CoreTestHook.lastEvent = null; CoreTestHook.lastPayload = null;

        // Inject "CMDT rows": enabled valid, enabled throwing, enabled bad class, disabled row
        IntegrationRegistry.injectRowsForTest(
            new List<String>{ 'CoreTestHook', 'CoreThrowHook', 'NoSuchClass', 'CoreTestHook' }, // impls
            new List<String>{ null          , 'throw'       , 'bad'        , 'ignored'      }, // keys
            new List<Boolean>{ true         , true          , true         , false          }, // enableds
            new List<String>{ null          , null          , null         , null           }  // namespaces
        );

        // No direct injected hooks this time; only CMDT rows
        List<IntegrationRegistry.HookInfo> hooks = IntegrationRegistry.getHooks();
        System.assertEquals(2, hooks.size(), 'Should include only the good enabled rows');

        // Should have inferred 'coretest' for CoreTestHook (key was null)
        Set<String> keys = new Set<String>();
        for (IntegrationRegistry.HookInfo h : hooks) keys.add(h.key);
        System.assert(keys.contains('coretest') && keys.contains('throw'));

        // Broadcast should call CoreTestHook and swallow CoreThrowHook exception
        IntegrationRegistry.broadcast('EVENT', new Map<String,Object>{ 'n' => 1 });
        System.assertEquals(1, CoreTestHook.hits, 'CoreTestHook should receive broadcast');
        System.assertEquals('EVENT', CoreTestHook.lastEvent);

        // invoke should return false when the target throws (CoreThrowHook)
        Boolean okThrow = IntegrationRegistry.invoke('throw', 'EVENT2', new Map<String,Object>());
        System.assertEquals(false, okThrow, 'invoke should return false when hook throws');
    }

    @IsTest static void getHooks_merges_cmdt_and_injected() {
        IntegrationRegistry.resetForTest();

        // One CMDT row (CoreTestHook) + one injected (DummyHook)
        IntegrationRegistry.injectRowsForTest(
            new List<String>{ 'CoreTestHook' },
            new List<String>{ null },
            new List<Boolean>{ true },
            new List<String>{ null }
        );
        IntegrationRegistry.injectForTest(new List<IIntegrationHook>{ new DummyHook() });

        List<IntegrationRegistry.HookInfo> hooks = IntegrationRegistry.getHooks();
        System.assertEquals(2, hooks.size(), 'Should merge CMDT and injected hooks');
    }
}
