@IsTest
private class NumberToWordsConverterTest {
    @IsTest
    static void testWholeDollars() {
        // 123 -> One Hundred Twenty-Three Dollars
        Decimal amount = 123;
        String expected = 'One Hundred Twenty-Three Dollars';
        System.assertEquals(expected, NumberToWordsConverter.convert(amount));
    }

    @IsTest
    static void testDollarsAndCents() {
        // 987.65 -> Nine Hundred Eighty-Seven Dollars and Sixty-Five Cents
        Decimal amount = 987.65;
        String expected = 'Nine Hundred Eighty-Seven Dollars and Sixty-Five Cents';
        System.assertEquals(expected, NumberToWordsConverter.convert(amount));
    }

    @IsTest
    static void testZeroDollars() {
        // 0.00 -> Zero Dollars
        Decimal amount = 0.00;
        String expected = 'Zero Dollars';
        System.assertEquals(expected, NumberToWordsConverter.convert(amount));
    }

    @IsTest
    static void testZeroCents() {
        // 42.00 -> Forty-Two Dollars
        Decimal amount = 42.00;
        String expected = 'Forty-Two Dollars';
        System.assertEquals(expected, NumberToWordsConverter.convert(amount));
    }

    @IsTest
    static void testCentsOnly() {
        // 0.27 -> Zero Dollars and Twenty-Seven Cents
        Decimal amount = 0.27;
        String expected = 'Zero Dollars and Twenty-Seven Cents';
        System.assertEquals(expected, NumberToWordsConverter.convert(amount));
    }

    @IsTest
    static void testThousands() {
        // 4321.89 -> Four Thousand Three Hundred Twenty-One Dollars and Eighty-Nine Cents
        Decimal amount = 4321.89;
        String expected = 'Four Thousand Three Hundred Twenty-One Dollars and Eighty-Nine Cents';
        System.assertEquals(expected, NumberToWordsConverter.convert(amount));
    }

    @IsTest
    static void testMillions() {
        // 7654321.11 -> Seven Million Six Hundred Fifty-Four Thousand Three Hundred Twenty-One Dollars and Eleven Cents
        Decimal amount = 7654321.11;
        String expected = 'Seven Million Six Hundred Fifty-Four Thousand Three Hundred Twenty-One Dollars and Eleven Cents';
        System.assertEquals(expected, NumberToWordsConverter.convert(amount));
    }
}
