//----------------------------------------------------------------------------------------------------//
// This file contains code from the Custom Metadata Saver project, released under the MIT License.            //
// See LICENSE file or go to https://github.com/jongpie/CustomMetadataSaver for full license details. //
//----------------------------------------------------------------------------------------------------//

@IsTest
private class CustomMetadataSaverTest {

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
    // New: delete-only invocation
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
    // New: invalid custom callback should not throw; falls
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
}
