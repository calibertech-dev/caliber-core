// v2.1: registry reads Integration_Hook__mdt and supports test-time row injection.
global with sharing class IntegrationRegistry {

    global class HookInfo {
        public String key;
        public IIntegrationHook impl;
        public HookInfo(String key, IIntegrationHook impl) {
            this.key = key;
            this.impl = impl;
        }
    }

    @TestVisible private static List<IIntegrationHook> injectedForTest;
    @TestVisible private static List<Row> injectedRowsForTest; // test-only CMDT rows

    // simple DTO for CMDT rows
    @TestVisible private class Row {
        String key;
        String impl;
        String ns;
        Boolean enabled;
        Row(String key, String impl, String ns, Boolean enabled) {
            this.key = key; this.impl = impl; this.ns = ns; this.enabled = enabled == null ? true : enabled;
        }
    }

    // --- Public API ---

    global static List<HookInfo> getHooks() {
        List<HookInfo> out = new List<HookInfo>();

        // 1) Discover from CMDT (or injected rows in tests)
        out.addAll(discoverFromCmdt());

        // 2) Include any injected hooks for tests
        if (injectedForTest != null) {
            for (IIntegrationHook h : injectedForTest) {
                if (h != null && h.isEnabled()) {
                    out.add(new HookInfo(h.key(), h));
                }
            }
        }
        return out;
    }

    global static void broadcast(String eventName, Map<String, Object> payload) {
        for (HookInfo hi : getHooks()) {
            try {
                hi.impl.onEvent(eventName, payload);
            } catch (Exception e) {
                // swallow; Core won't let add-ons break flows
            }
        }
    }

    global static Boolean invoke(String key, String eventName, Map<String, Object> payload) {
        for (HookInfo hi : getHooks()) {
            if (hi.key == key) {
                try {
                    hi.impl.onEvent(eventName, payload);
                    return true;
                } catch (Exception e) {
                    return false;
                }
            }
        }
        return false;
    }

    // --- Test helpers ---

    @TestVisible
    private static void injectForTest(List<IIntegrationHook> hooks) {
        injectedForTest = new List<IIntegrationHook>();
        if (hooks != null) injectedForTest.addAll(hooks);
    }

    @TestVisible
    private static void injectRowsForTest(List<String> impls, List<String> keys, List<Boolean> enableds, List<String> namespaces) {
        injectedRowsForTest = new List<Row>();
        Integer n = (impls == null) ? 0 : impls.size();
        for (Integer i = 0; i < n; i++) {
            String impl = impls[i];
            String key  = (keys != null && keys.size() > i) ? keys[i] : null;
            Boolean en  = (enableds != null && enableds.size() > i) ? enableds[i] : true;
            String ns   = (namespaces != null && namespaces.size() > i) ? namespaces[i] : null;
            injectedRowsForTest.add(new Row(key, impl, ns, en));
        }
    }

    @TestVisible
    private static void resetForTest() {
        injectedForTest = null;
        injectedRowsForTest = null;
    }

    // --- Internals ---

    @TestVisible
    private static List<HookInfo> discoverFromCmdt() {
        List<HookInfo> out = new List<HookInfo>();
        try {
            // Use injected rows if present (tests), otherwise query real CMDT
            List<Row> rows = injectedRowsForTest;
            if (rows == null) {
                rows = new List<Row>();
                for (Integration_Hook__mdt row :
                     [SELECT Key__c, Implementing_Class__c, Namespace__c, Enabled__c
                      FROM Integration_Hook__mdt]) {
                    rows.add(new Row(row.Key__c, row.Implementing_Class__c, row.Namespace__c, row.Enabled__c));
                }
            }

            for (Row r : rows) {
                if (r == null || r.enabled == false) continue;

                IIntegrationHook inst = safeConstruct(r.ns, r.impl);
                if (inst == null || !inst.isEnabled()) continue;

                String key = String.isBlank(r.key) ? inferKey(r.impl) : r.key;
                out.add(new HookInfo(key, inst));
            }
        } catch (Exception e) {
            // If the CMDT doesn't exist or any other issue, just return empty.
        }
        return out;
    }

    @TestVisible
    private static IIntegrationHook safeConstruct(String ns, String className) {
        try {
            Type t = String.isBlank(ns) ? Type.forName(className) : Type.forName(ns, className);
            if (t == null) return null;
            Object o = t.newInstance();
            return (o instanceof IIntegrationHook) ? (IIntegrationHook) o : null;
        } catch (Exception e) {
            return null;
        }
    }

    @TestVisible
    private static String inferKey(String implClass) {
        if (String.isBlank(implClass)) return 'unknown';
        String s = implClass.toLowerCase();
        if (s.endsWith('hook')) s = s.substring(0, s.length() - 4);
        s = s.replace('_', '');
        return s;
    }
}
