@IsTest
private class AccountNumberGeneratorTest {

    private static void turnOn()  { CaliberCoreFeatures.setForTest('AccountNumberGenerator', true); }
    private static void turnOff() { CaliberCoreFeatures.setForTest('AccountNumberGenerator', false); }

    // Helper: exactly 8 digits
    private static Boolean isEightDigits(String s) {
        return s != null && Pattern.matches('^\\d{8}$', s);
    }

    // ----- Flag OFF behavior -----
    @IsTest
    static void respectsFlag_off() {
        turnOff();

        // Direct call should no-op
        List<Account> accs = new List<Account>{
            new Account(Name='A'),
            new Account(Name='B')
        };
        AccountNumberGenerator.assignUniqueAccountNumbers(accs);
        System.assertEquals(null, accs[0].AccountNumber);
        System.assertEquals(null, accs[1].AccountNumber);

        // Trigger path should also no-op
        Account x = new Account(Name='X');
        insert x;
        x = [SELECT AccountNumber FROM Account WHERE Id = :x.Id];
        System.assertEquals(null, x.AccountNumber, 'Flag OFF: trigger must not assign a number');
    }

    // ---------- Unit-style tests ----------
    @IsTest
    static void nullList_noop() {
        // off or on doesn't matter; method returns early
        AccountNumberGenerator.assignUniqueAccountNumbers(null);
        System.assert(true, 'No-op on null list should not throw');
    }

    @IsTest
    static void allHaveNumbers_noop() {
        // off or on both pass; nothing should change
        List<Account> accs = new List<Account>{
            new Account(Name='X1', AccountNumber='00000001'),
            new Account(Name='X2', AccountNumber='00000002')
        };
        AccountNumberGenerator.assignUniqueAccountNumbers(accs);
        System.assertEquals('00000001', accs[0].AccountNumber);
        System.assertEquals('00000002', accs[1].AccountNumber);
    }

    @IsTest
    static void directCall_generatesForBlanks_inMemory() {
        turnOn();
        List<Account> accs = new List<Account>{
            new Account(Name='Blank-1'),
            new Account(Name='Blank-2'),
            new Account(Name='Has-Num', AccountNumber='12345678')
        };
        AccountNumberGenerator.assignUniqueAccountNumbers(accs);

        System.assert(isEightDigits(accs[0].AccountNumber));
        System.assert(isEightDigits(accs[1].AccountNumber));
        System.assertEquals('12345678', accs[2].AccountNumber);

        Set<String> uniq = new Set<String>{
            accs[0].AccountNumber, accs[1].AccountNumber, accs[2].AccountNumber
        };
        System.assertEquals(3, uniq.size(), 'All three numbers should be unique');
    }

    // ---------- End-to-end trigger path tests ----------
    @IsTest
    static void generatesForBlanks_andPreservesExisting_insertPath() {
        turnOn();

        Account a1 = new Account(Name='HasNumber-1', AccountNumber='12345678');
        Account a2 = new Account(Name='HasNumber-2', AccountNumber='00000042');
        Account b1 = new Account(Name='NeedsNumber-1');
        Account b2 = new Account(Name='NeedsNumber-2');
        Account b3 = new Account(Name='NeedsNumber-3');
        insert new List<Account>{ a1, a2, b1, b2, b3 };

        Map<Id, Account> byId = new Map<Id, Account>([
            SELECT Id, AccountNumber FROM Account
            WHERE Id IN :new Set<Id>{ a1.Id, a2.Id, b1.Id, b2.Id, b3.Id }
        ]);

        System.assertEquals('12345678', byId.get(a1.Id).AccountNumber);
        System.assertEquals('00000042', byId.get(a2.Id).AccountNumber);
        System.assert(isEightDigits(byId.get(b1.Id).AccountNumber));
        System.assert(isEightDigits(byId.get(b2.Id).AccountNumber));
        System.assert(isEightDigits(byId.get(b3.Id).AccountNumber));

        Set<String> nums = new Set<String>{
            byId.get(a1.Id).AccountNumber,
            byId.get(a2.Id).AccountNumber,
            byId.get(b1.Id).AccountNumber,
            byId.get(b2.Id).AccountNumber,
            byId.get(b3.Id).AccountNumber
        };
        System.assertEquals(5, nums.size(), 'All five numbers should be unique');
    }

    @IsTest
    static void doesNotChangeOnUpdate() {
        turnOn();

        Account a = new Account(Name='Initial');
        insert a;

        a = [SELECT Id, AccountNumber FROM Account WHERE Id = :a.Id];
        String assigned = a.AccountNumber;
        System.assert(Pattern.matches('^\\d{8}$', assigned));

        a.Name = 'Renamed';
        update a;

        Account after = [SELECT AccountNumber FROM Account WHERE Id = :a.Id];
        System.assertEquals(assigned, after.AccountNumber, 'Must not change on update');
    }

    @IsTest
    static void bulkInsert200_uniqueEightDigits() {
        turnOn();

        List<Account> many = new List<Account>();
        for (Integer i = 0; i < 200; i++) many.add(new Account(Name='Bulk-' + i));
        insert many;

        List<Account> inserted = [
            SELECT Id, AccountNumber
            FROM Account
            WHERE Id IN :new Map<Id,Account>(many).keySet()
        ];
        Set<String> nums = new Set<String>();
        for (Account a : inserted) {
            System.assert(Pattern.matches('^\\d{8}$', a.AccountNumber));
            nums.add(a.AccountNumber);
        }
        System.assertEquals(200, nums.size(), 'All 200 should be unique this batch');
    }

    @IsTest
    static void orgCollision_regenerates_toNewUnique() {
        turnOn();

        // Seed an existing number in the org
        insert new Account(Name='Existing', AccountNumber='77777777');

        // Next candidate collides, then a unique value
        AccountNumberGenerator.setTestNextNumbers(new List<String>{ '77777777', '12345670' });

        Account a = new Account(Name='NeedsNumber');
        insert a;

        Account got = [SELECT AccountNumber FROM Account WHERE Id = :a.Id];
        System.assertEquals('12345670', got.AccountNumber, 'Should regenerate away from org collision');
    }
}
