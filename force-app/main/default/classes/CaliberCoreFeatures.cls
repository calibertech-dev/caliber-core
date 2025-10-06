public with sharing class CaliberCoreFeatures {
    private static Map<String, Boolean> cache = new Map<String, Boolean>();
    @TestVisible private static Map<String, Boolean> testOverrides = new Map<String, Boolean>();

    @TestVisible
    public static void setForTest(String key, Boolean val) {
        testOverrides.put(key, val);
        cache.remove(key);
    }
    @TestVisible
    public static void clearForTest(String key) {
        testOverrides.remove(key);
        cache.remove(key);
    }

    public static Boolean isOn(String key) {
        if (Test.isRunningTest() && testOverrides.containsKey(key)) {
            return testOverrides.get(key);
        }
        if (cache.containsKey(key)) return cache.get(key);

        Map<String, Caliber_Core_Features__mdt> all = Caliber_Core_Features__mdt.getAll();
        Boolean enabled = all.containsKey(key) ? all.get(key).Enabled__c : false;
        cache.put(key, enabled);
        return enabled;
    }
}
