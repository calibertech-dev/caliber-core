@isTest
private class UrlTokenServiceTest {

    @isTest
    static void testDefaultLengthToken() {
        String t = UrlTokenService.makeUrlSafeToken();
        System.assertNotEquals(null, t, 'Token should not be null');
        System.assert(t.length() > 0, 'Token should not be empty');

        // Default is 22 characters long
        System.assertEquals(22, t.length(), 'Default length should be 22');

        // Ensure no URL-unsafe characters
        System.assertEquals(-1, t.indexOf('+'), 'Token must not contain +');
        System.assertEquals(-1, t.indexOf('/'), 'Token must not contain /');
        System.assertEquals(-1, t.indexOf('='), 'Token must not contain =');
    }

    @isTest
    static void testCustomLengthToken() {
        Integer len = 30;
        String t = UrlTokenService.makeUrlSafeToken(len);

        System.assertNotEquals(null, t, 'Token should not be null');
        System.assertEquals(len, t.length(), 'Token should match requested length');

        // Still enforce URL-safe checks
        System.assertEquals(-1, t.indexOf('+'));
        System.assertEquals(-1, t.indexOf('/'));
        System.assertEquals(-1, t.indexOf('='));
    }

    @isTest
    static void testNoLengthOrZeroReturnsFullToken() {
        // Request invalid length → should return full base64 token
        String t1 = UrlTokenService.makeUrlSafeToken(0);
        String t2 = UrlTokenService.makeUrlSafeToken(-5);
        String t3 = UrlTokenService.makeUrlSafeToken(null);

        // Hard to know exact expected length (because the AES key entropy determines it),
        // but they should all match each other.
        System.assertEquals(t1.length(), t2.length());
        System.assertEquals(t1.length(), t3.length());
    }
}
