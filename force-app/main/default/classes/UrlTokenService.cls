public with sharing class UrlTokenService {

    /**
     * Generates a random URL-safe token using a 256-bit AES key as the entropy source.
     * 
     * @param desiredLength Optional max length of the token. If null/<=0 or larger than
     *                      the encoded length, the full token is returned.
     */
    public static String makeUrlSafeToken(Integer desiredLength) {
        // 256 bits of entropy
        Blob b = Crypto.generateAesKey(256);

        // Base64 → URL-safe Base64-ish
        String b64 = EncodingUtil.base64Encode(b)
            .replace('+', '-')
            .replace('/', '_')
            .replace('=', '');

        if (desiredLength == null || desiredLength <= 0 || desiredLength >= b64.length()) {
            return b64;
        }
        return b64.substring(0, desiredLength);
    }

    // Convenience overload – common case fixed length
    public static String makeUrlSafeToken() {
        return makeUrlSafeToken(22);
    }
}
