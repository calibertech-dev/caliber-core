//----------------------------------------------------------------------------------------------------//
// This file contains code from the Custom Metadata Saver project, released under the MIT License.            //
// See LICENSE file or go to https://github.com/jongpie/CustomMetadataSaver for full license details. //
//----------------------------------------------------------------------------------------------------//

@IsTest
private inherited sharing class FlowCustomMetadataCreatorTest {

    @IsTest
    static void it_should_create_new_cmdt_record_instance() {
        FlowCustomMetadataCreator.FlowInput input = new FlowCustomMetadataCreator.FlowInput();
        input.customMetadataTypeName = SObjectType.CustomMetadataDeployTest__mdt.getName();
        input.masterLabel = 'My new cmdt';
        input.developerName = 'My_new_cmdt';

        List<FlowCustomMetadataCreator.FlowInput> inputs =
            new List<FlowCustomMetadataCreator.FlowInput>{ input };

        Test.startTest();
        List<SObject> newRecords = FlowCustomMetadataCreator.newInstance(inputs);
        Test.stopTest();

        System.assertEquals(1, newRecords.size(), 'Expected exactly one CMDT record created');

        CustomMetadataDeployTest__mdt trackedInstance =
            (CustomMetadataDeployTest__mdt)newRecords.get(0);
        System.assertEquals(input.masterLabel, trackedInstance.MasterLabel);
        System.assertEquals(input.developerName, trackedInstance.DeveloperName);
    }

    // ---------------------------------------------------
    // New: covers invalid type handling & try/catch block
    // ---------------------------------------------------
    @IsTest
    static void it_should_handle_invalid_type_gracefully() {
        FlowCustomMetadataCreator.FlowInput badInput = new FlowCustomMetadataCreator.FlowInput();
        badInput.customMetadataTypeName = 'DefinitelyNotAReal__mdt';
        badInput.masterLabel = 'Invalid test';
        badInput.developerName = 'invalid_test';

        List<FlowCustomMetadataCreator.FlowInput> inputs =
            new List<FlowCustomMetadataCreator.FlowInput>{ badInput };

        Test.startTest();
        List<SObject> result = FlowCustomMetadataCreator.newInstance(inputs);
        Test.stopTest();

        // Expect no SObjects returned (invalid type skipped, not thrown)
        System.assertEquals(0, result.size(), 'Invalid type should be skipped, not thrown');
    }

    // ---------------------------------------------------
    // New: covers empty/null input list (edge case)
    // ---------------------------------------------------
    @IsTest
    static void it_should_return_empty_list_when_no_inputs() {
        Test.startTest();
        List<SObject> result = FlowCustomMetadataCreator.newInstance(new List<FlowCustomMetadataCreator.FlowInput>());
        Test.stopTest();
        System.assertEquals(0, result.size(), 'Empty input list should return empty result');
    }
}
