public class AccountNumberGenerator {

    private static final Integer MAX_RETRIES = 10;

    // -------- Test seam (legal identifiers) --------
    @TestVisible private static List<String> testNextNumbers = new List<String>();
    @TestVisible
    static void setTestNextNumbers(List<String> nums) {
        testNextNumbers.clear();
        if (nums != null) testNextNumbers.addAll(nums);
    }
    // -----------------------------------------------

    public static void assignUniqueAccountNumbers(List<Account> accounts) {
        if (!CaliberCoreFeatures.isOn('AccountNumberGenerator')) return;

        if (accounts == null || accounts.isEmpty()) return;

        // 1) Partition: which need numbers vs already have one
        List<Account> needs = new List<Account>();
        Set<String> usedInBatch = new Set<String>();
        for (Account a : accounts) {
            if (!String.isBlank(a.AccountNumber)) usedInBatch.add(a.AccountNumber);
            else needs.add(a);
        }
        if (needs.isEmpty()) return;

        // 2) Pre-generate unique candidates within this batch
        for (Account a : needs) {
            String candidate;
            Integer attempts = 0;
            do {
                candidate = gen8(); // deterministic in tests if testNextNumbers is populated
                attempts++;
            } while (usedInBatch.contains(candidate) && attempts < MAX_RETRIES);

            if (usedInBatch.contains(candidate)) {
                a.addError('Could not generate a unique 8-digit number (batch collision). Please try again.');
                continue;
            }
            a.AccountNumber = candidate;
            usedInBatch.add(candidate);
        }

        // 3) Single org-wide collision check
        Set<String> proposed = new Set<String>();
        for (Account a : needs) if (!String.isBlank(a.AccountNumber)) proposed.add(a.AccountNumber);
        if (proposed.isEmpty()) return;

        Set<String> existing = new Set<String>();
        for (Account acc : [
            SELECT AccountNumber FROM Account WHERE AccountNumber IN :proposed
        ]) {
            if (!String.isBlank(acc.AccountNumber)) existing.add(acc.AccountNumber);
        }
        if (existing.isEmpty()) return;

        // 4) Regenerate locally for collided ones (no more queries)
        for (Account a : needs) {
            if (String.isBlank(a.AccountNumber)) continue;
            if (!existing.contains(a.AccountNumber)) continue;

            Boolean fixed = false;
            for (Integer i = 0; i < MAX_RETRIES; i++) {
                String candidate = gen8();
                if (!existing.contains(candidate) && !usedInBatch.contains(candidate)) {
                    a.AccountNumber = candidate;
                    usedInBatch.add(candidate);
                    fixed = true;
                    break;
                }
            }
            if (!fixed) {
                a.addError('Could not resolve AccountNumber collision after multiple attempts. Please try again.');
            }
        }
    }

    // Generates a zero-padded 8-digit string, e.g., "00439172"
    private static String gen8() {
        // Test-controlled path
        if (!testNextNumbers.isEmpty()) {
            String nextVal = testNextNumbers.remove(0);
            String s = (nextVal == null) ? '' : nextVal.replaceAll('\\D', '');
            if (s.length() > 8) s = s.substring(0, 8);
            while (s.length() < 8) s = '0' + s;
            return s;
        }
        // Production path
        Integer n = (Integer)Math.floor(Math.random() * 100000000); // 0..99,999,999
        String s = String.valueOf(n);
        while (s.length() < 8) s = '0' + s;
        return s;
    }
}
