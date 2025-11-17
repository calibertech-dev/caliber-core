@IsTest
private class EmailServiceTest {

    @IsTest
    static void testSend_WithBodyAndWhoId() {
        // Non-setup objects – fine for DML in tests
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            LastName  = 'Recipient',
            Email     = 'recipient@example.com',
            AccountId = acc.Id
        );
        insert con;

        // No templateId – we test the subject/body path instead
        EmailService.EmailRequest req = new EmailService.EmailRequest();
        req.templateId     = null;
        req.whatId         = acc.Id;
        req.whoId          = con.Id;
        req.subject        = 'Test Subject';
        req.plainTextBody  = 'Hello ' + con.LastName;
        req.saveAsActivity = true;

        List<EmailService.EmailRequest> requests =
            new List<EmailService.EmailRequest>{ req };

        Test.startTest();
        EmailService.EmailResult result = EmailService.send(
            requests,
            'Unit Test - Body + WhoId',
            'test-correlation',
            acc.Id,
            'Account'
        );
        Test.stopTest();

        System.assertEquals(1, result.totalRequests,  'totalRequests should be 1');
        System.assertEquals(1, result.builtEmails,    'builtEmails should be 1');
        System.assertEquals(1, result.sentEmails,     'sentEmails should be 1');
        System.assertEquals(null, result.error,       'error should be null');
    }

    @IsTest
    static void testSend_SkipsInvalidRequests() {
        // No whoId or toAddresses, no template, no body – should be skipped
        EmailService.EmailRequest badReq = new EmailService.EmailRequest();

        Test.startTest();
        EmailService.EmailResult result = EmailService.send(
            new List<EmailService.EmailRequest>{ badReq },
            'Unit Test - Invalid Request',
            null,
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(1, result.totalRequests, 'totalRequests should be 1');
        System.assertEquals(0, result.builtEmails,   'builtEmails should be 0');
        System.assertEquals(0, result.sentEmails,    'sentEmails should be 0');
    }

    @IsTest
    static void testSend_EmptyList() {
        Test.startTest();
        EmailService.EmailResult result = EmailService.send(
            new List<EmailService.EmailRequest>(),
            'Unit Test - Empty',
            null,
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(0, result.totalRequests, 'totalRequests should be 0');
        System.assertEquals(0, result.builtEmails,   'builtEmails should be 0');
        System.assertEquals(0, result.sentEmails,    'sentEmails should be 0');
    }
}
