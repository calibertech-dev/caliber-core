//----------------------------------------------------------------------------------------------------//
// This file contains code from the Custom Metadata Saver project, released under the MIT License.            //
// See LICENSE file or go to https://github.com/jongpie/CustomMetadataSaver for full license details. //
//----------------------------------------------------------------------------------------------------//

@IsTest
private class CustomMetadataSaverTest {

    // Simple test DeployCallback to exercise the "valid class" branch
    private class TestCallback implements Metadata.DeployCallback {
        public Boolean invoked = false;

        public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
            invoked = true;
        }
    }

    // Mock for SOAP Metadata callouts (DeleteCmdtQueueable)
    private class MockMetadataDeleteCallout implements WebServiceMock {
        public void doInvoke(
            Object stub,
            Object request,
            Map<String, Object> response,
            String endpoint,
            String soapAction,
            String requestName,
            String responseNS,
            String responseName,
            String responseType
        ) {
            // Return a mix of success/failure to exercise both logging branches
            MetadataService.DeleteResult[] results = new MetadataService.DeleteResult[2];

            results[0] = new MetadataService.DeleteResult();
            results[0].success  = true;
            results[0].fullName = 'CustomMetadataDeployTest__mdt.success';

            results[1] = new MetadataService.DeleteResult();
            results[1].success  = false;
            results[1].fullName = 'CustomMetadataDeployTest__mdt.failure';

            MetadataService.Error err = new MetadataService.Error();
            err.statusCode = 'ERROR';
            err.message    = 'Something went wrong';
            results[1].errors = new MetadataService.Error[]{ err };

            // Standard pattern for WebServiceMock: put the response on 'response_x'
            response.put('response_x', results);
        }
    }

    @IsTest
    static void it_should_deploy_cmdt_record_for_list_of_cmdt() {
        CustomMetadataDeployTest__mdt cmdtRecord = new CustomMetadataDeployTest__mdt(
            MasterLabel = 'my test cmdt record',
            DeveloperName = 'my_test_cmdt_record',
            ExampleCheckboxField__c = true,
            ExampleDateField__c = System.today(),
            ExampleDatetimeField__c = System.now(),
            ExampleTextField__c = 'hello'
        );

        List<CustomMetadataDeployTest__mdt> cdmtRecords = new List<CustomMetadataDeployTest__mdt>{ cmdtRecord };
        System.assertEquals(1, cdmtRecords.size(), 'precondition');

        Test.startTest();
        CustomMetadataSaver.deploy(cdmtRecords);
        Test.stopTest();

        System.assertEquals(1, CustomMetadataSaver.getDeploymentJobIds().size(), 'one deployment enqueued');
    }

    @IsTest
    static void it_should_deploy_cmdt_record_for_list_of_flowInputs() {
        CustomMetadataDeployTest__mdt cmdtRecord = new CustomMetadataDeployTest__mdt(
            MasterLabel = 'my test cmdt record',
            DeveloperName = 'my_test_cmdt_record',
            ExampleCheckboxField__c = true,
            ExampleDateField__c = System.today(),
            ExampleDatetimeField__c = System.now(),
            ExampleTextField__c = 'hello'
        );

        List<CustomMetadataDeployTest__mdt> cdmtRecords = new List<CustomMetadataDeployTest__mdt>{ cmdtRecord };

        CustomMetadataSaver.FlowInput input = new CustomMetadataSaver.FlowInput();
        input.customMetadataRecords = cdmtRecords;
        input.sendEmailOnError = true;
        input.sendEmailOnSuccess = true;

        List<CustomMetadataSaver.FlowInput> inputs = new List<CustomMetadataSaver.FlowInput>{ input };
        System.assertEquals(1, cdmtRecords.size(), 'precondition');

        Test.startTest();
        List<String> jobIds = CustomMetadataSaver.deploy(inputs);
        Test.stopTest();

        System.assertEquals(1, CustomMetadataSaver.getDeploymentJobIds().size(), 'one deployment enqueued');
        System.assertEquals(1, jobIds.size(), 'returns one id per input');
        System.assertNotEquals(null, jobIds[0], 'mock job id returned under test');
    }

    @IsTest
    static void it_should_handle_deploy_success() {
        Boolean sendEmailOnError = true;
        Boolean sendEmailOnSuccess = true;
        CustomMetadataSaver.DefaultDeployCallback callback = new CustomMetadataSaver.DefaultDeployCallback(sendEmailOnError, sendEmailOnSuccess);

        Metadata.DeployResult result = new Metadata.DeployResult();
        result.success = true;
        result.numberComponentsTotal = 5;
        result.numberComponentErrors = 0;
        Metadata.DeployCallbackContext context = new Metadata.DeployCallbackContext();

        System.assertEquals(null, callback.success, 'precondition');

        Test.startTest();
        callback.handleResult(result, context);
        Test.stopTest();

        System.assertEquals(true, callback.success, 'success tracked');
    }

    @IsTest
    static void it_should_handle_deploy_error() {
        Boolean sendEmailOnError = true;
        Boolean sendEmailOnSuccess = true;
        CustomMetadataSaver.DefaultDeployCallback callback = new CustomMetadataSaver.DefaultDeployCallback(sendEmailOnError, sendEmailOnSuccess);

        Metadata.DeployResult result = new Metadata.DeployResult();
        result.success = false;
        result.numberComponentsTotal = 5;
        result.numberComponentErrors = 2;
        Metadata.DeployCallbackContext context = new Metadata.DeployCallbackContext();

        System.assertEquals(null, callback.success, 'precondition');

        Test.startTest();
        callback.handleResult(result, context);
        Test.stopTest();

        System.assertEquals(false, callback.success, 'failure tracked');
    }

    // -----------------------------
    // Delete-only invocation
    // -----------------------------
    @IsTest
    static void it_should_not_throw_for_delete_only_invocation() {
        // No upserts. Only deletes. In tests, enqueueDeleteCmdt is a no-op (no callout).
        CustomMetadataSaver.FlowInput input = new CustomMetadataSaver.FlowInput();
        input.customMetadataFullNamesToDelete = new List<String>{
            'CustomMetadataDeployTest__mdt.my_record_to_delete'
        };
        input.sendEmailOnError = false;
        input.sendEmailOnSuccess = false;

        List<CustomMetadataSaver.FlowInput> inputs = new List<CustomMetadataSaver.FlowInput>{ input };

        Test.startTest();
        List<String> jobIds = CustomMetadataSaver.deploy(inputs);
        Test.stopTest();

        // For delete-only, the method still returns one element per input; value can be null
        System.assertEquals(1, jobIds.size(), 'returns one id placeholder per input');
        System.assertEquals(0, CustomMetadataSaver.getDeploymentJobIds().size(), 'no upsert deployment enqueued');
    }

    // ----------------------------------------------------
    // Invalid custom callback should not throw; falls
    // back to default callback and still enqueues upsert.
    // ----------------------------------------------------
    @IsTest
    static void it_should_fallback_when_custom_callback_class_is_invalid() {
        CustomMetadataDeployTest__mdt cmdtRecord = new CustomMetadataDeployTest__mdt(
            MasterLabel = 'fallback test',
            DeveloperName = 'fallback_test',
            ExampleCheckboxField__c = false,
            ExampleDateField__c = System.today(),
            ExampleDatetimeField__c = System.now(),
            ExampleTextField__c = 'world'
        );

        CustomMetadataSaver.FlowInput input = new CustomMetadataSaver.FlowInput();
        input.customMetadataRecords = new List<CustomMetadataDeployTest__mdt>{ cmdtRecord };
        input.customCallbackName = 'ThisClassDoesNotExist';
        input.sendEmailOnError = false;
        input.sendEmailOnSuccess = false;

        Test.startTest();
        List<String> jobIds = CustomMetadataSaver.deploy(new List<CustomMetadataSaver.FlowInput>{ input });
        Test.stopTest();

        System.assertEquals(1, jobIds.size(), 'id list size');
        System.assertEquals(1, CustomMetadataSaver.getDeploymentJobIds().size(), 'still enqueued with default callback');
    }

    // ----------------------------------------------------
    // Valid custom callback name: exercises the
    // Type.forName(... ) success path in getFlowDeployCallback
    // ----------------------------------------------------
    @IsTest
    static void it_should_use_custom_callback_when_class_exists() {
        CustomMetadataDeployTest__mdt cmdtRecord = new CustomMetadataDeployTest__mdt(
            MasterLabel = 'callback test',
            DeveloperName = 'callback_test',
            ExampleCheckboxField__c = true,
            ExampleDateField__c = System.today(),
            ExampleDatetimeField__c = System.now(),
            ExampleTextField__c = 'with callback'
        );

        CustomMetadataSaver.FlowInput input = new CustomMetadataSaver.FlowInput();
        input.customMetadataRecords = new List<CustomMetadataDeployTest__mdt>{ cmdtRecord };
        // Inner class of this test class
        input.customCallbackName = 'CustomMetadataSaverTest.TestCallback';
        input.sendEmailOnError = false;
        input.sendEmailOnSuccess = false;

        Test.startTest();
        List<String> jobIds = CustomMetadataSaver.deploy(new List<CustomMetadataSaver.FlowInput>{ input });
        Test.stopTest();

        // We mainly care that no exception is thrown and a jobId is returned
        System.assertEquals(1, jobIds.size(), 'id list size');
        System.assertNotEquals(null, jobIds[0], 'mock job id returned under test');
    }

    // ----------------------------------------------------
    // Invocable with only email flags & no records/deletes:
    // exercises correlation ID + no-op behavior
    // ----------------------------------------------------
    @IsTest
    static void it_should_handle_empty_invocable_inputs_and_set_correlation_id() {
        CustomMetadataSaver.FlowInput input = new CustomMetadataSaver.FlowInput();
        input.sendEmailOnError = false;
        input.sendEmailOnSuccess = true;

        List<CustomMetadataSaver.FlowInput> inputs = new List<CustomMetadataSaver.FlowInput>{ input };

        Test.startTest();
        List<String> jobIds = CustomMetadataSaver.deploy(inputs);
        Test.stopTest();

        System.assertEquals(1, jobIds.size(), 'one output per input');
        // No upsert or delete, so jobId will be null
        System.assertEquals(null, jobIds[0], 'no deployment when there are no records or deletes');
        System.assertNotEquals(null, CustomMetadataSaver.currentCorrelationId(), 'correlation id should be set');
    }

    // ----------------------------------------------------
    // Direct coverage for DeleteCmdtQueueable with mock
    // SOAP Metadata callouts, including api version override.
    // ----------------------------------------------------
    @IsTest
    static void it_should_execute_delete_cmdt_queueable_with_mock_callout() {
        List<String> fullNames = new List<String>{
            'CustomMetadataDeployTest__mdt.success',
            'CustomMetadataDeployTest__mdt.failure'
        };

        Test.setMock(WebServiceMock.class, new MockMetadataDeleteCallout());
        CustomMetadataSaver.DeleteCmdtQueueable job = new CustomMetadataSaver.DeleteCmdtQueueable(fullNames);

        Test.startTest();
        // First pass: default metadata API version
        CustomMetadataSaver.metadataApiVersionOverride = null;
        job.execute(null);

        // Second pass: override metadata API version branch
        CustomMetadataSaver.metadataApiVersionOverride = '60.0';
        job.execute(null);
        Test.stopTest();

        // Reset override for hygiene
        CustomMetadataSaver.metadataApiVersionOverride = null;
        // No exceptions means both branches of execute() ran cleanly
        System.assert(true, 'DeleteCmdtQueueable executed twice without error');
    }

    // ----------------------------------------------------
    // Throwing invocable test to cover logging + rethrow branch
    // ----------------------------------------------------
    @IsTest
    static void it_should_log_and_rethrow_when_invocable_throws() {
        Boolean threw = false;

        Test.startTest();
        try {
            // Passing null will cause the for-each loop over `inputs` to throw
            CustomMetadataSaver.deploy((List<CustomMetadataSaver.FlowInput>)null);
        } catch (Exception ex) {
            threw = true;
            // We don’t really care about the exact type, just that it’s rethrown.
            System.assertNotEquals(null, ex, 'Exception should be rethrown from invocable deploy');
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'deploy(invocable) should rethrow after logging');
        // Side-effect: catch block is now covered (logError + throw ex).
    }
}
