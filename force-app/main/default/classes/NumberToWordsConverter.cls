public class NumberToWordsConverter {
    public static String convert(Decimal amount) {
        Long dollars = (Long)amount.setScale(0, System.RoundingMode.DOWN);
        Integer cents = (Integer)(((amount - dollars) * 100).setScale(0, System.RoundingMode.HALF_UP));
        return toWords(dollars) + ' Dollars' + (cents > 0 ? ' and ' + toWords(cents) + ' Cents' : '');
    }

    private static String toWords(Long num) {
        if (num == 0) return 'Zero';

        String[] ones = new String[] {
            '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
            'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
            'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'
        };
        String[] tens = new String[] {
            '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
        };

        String[] thousands = new String[] {
            '', 'Thousand', 'Million', 'Billion'
        };

        String result = '';
        Integer i = 0;

        while (num > 0) {
            Integer chunk = (Integer)Math.mod(num, 1000);
            if (chunk != 0) {
                result = chunkToWords(chunk, ones, tens) + ' ' + thousands[i] + (result != '' ? ' ' + result : '');
            }
            num = num / 1000;
            i++;
        }

        return result.trim();
    }

    private static String chunkToWords(Integer num, String[] ones, String[] tens) {
        String result = '';

        if (num >= 100) {
            result += ones[num / 100] + ' Hundred';
            num = Math.mod(num, 100);
            if (num > 0) result += ' ';
        }

        if (num >= 20) {
            result += tens[num / 10];
            if (Math.mod(num, 10) > 0) result += '-' + ones[Math.mod(num, 10)];
        } else if (num > 0) {
            result += ones[num];
        }

        return result;
    }
}
