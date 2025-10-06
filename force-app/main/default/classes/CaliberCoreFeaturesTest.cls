@IsTest
private class CaliberCoreFeaturesTest {

    @IsTest
    static void returnsFalse_whenRecordMissing_andNoOverride() {
        CaliberCoreFeatures.clearForTest('NonexistentFeature');
        System.assertEquals(false, CaliberCoreFeatures.isOn('NonexistentFeature'));
    }

    @IsTest
    static void returnsTrue_whenOverriddenOn() {
        CaliberCoreFeatures.setForTest('AccountNumberGenerator', true);
        System.assertEquals(true, CaliberCoreFeatures.isOn('AccountNumberGenerator'));
    }

    @IsTest
    static void overrideOff_andClear_restoreDefaults() {
        CaliberCoreFeatures.setForTest('AccountNumberGenerator', false);
        System.assertEquals(false, CaliberCoreFeatures.isOn('AccountNumberGenerator'));

        CaliberCoreFeatures.clearForTest('AccountNumberGenerator');
        // With no CMDT and no override, default is false
        System.assertEquals(false, CaliberCoreFeatures.isOn('AccountNumberGenerator'));
    }
}
