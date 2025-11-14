//----------------------------------------------------------------------------------------------------//
// This file contains code from the Custom Metadata Saver project, released under the MIT License.     //
// See LICENSE file or go to https://github.com/jongpie/CustomMetadataSaver for full license details. //
//----------------------------------------------------------------------------------------------------//

@IsTest
private class CustomMetadataTableControllerTest {

    @IsTest
    static void it_should_return_sobject_api_name_for_custom_metadata_record() {
        CustomMetadataDeployTest__mdt customMetadataRecord = new CustomMetadataDeployTest__mdt();

        String returnedSObjectApiName = CustomMetadataTableController.getSObjectApiName(customMetadataRecord);
        System.assertEquals(customMetadataRecord.getSObjectType().getDescribe().getName(), returnedSObjectApiName);
    }

    @IsTest
    static void it_should_enqueue_deployment() {
        CustomMetadataDeployTest__mdt customMetadataRecord =
            new CustomMetadataDeployTest__mdt(DeveloperName = 'Some_API_Name', MasterLabel = 'Some Label');

        String deploymentId = CustomMetadataTableController.deploy(new List<SObject>{ customMetadataRecord });
        System.assertEquals(CustomMetadataSaver.MOCK_DEPLOYMENT_ID, deploymentId);
    }

    @IsTest
    static void it_should_get_deployment_status_when_deployment_succeeds() {
        String mockDeploymentStatus = 'Succeeded';
        DeploymentCalloutMock mock = new DeploymentCalloutMock();
        mock.setDeploymentStatus(mockDeploymentStatus);
        Test.setMock(HttpCalloutMock.class, mock);

        CustomMetadataTableController.DeploymentStatusResponse deploymentStatusResponse =
            CustomMetadataTableController.getDeploymentStatus(CustomMetadataSaver.MOCK_DEPLOYMENT_ID);

        System.assertEquals(CustomMetadataSaver.MOCK_DEPLOYMENT_ID, deploymentStatusResponse.id);
        System.assertEquals(mockDeploymentStatus, deploymentStatusResponse.deployResult.status);
    }

    // NEW: delete-only path from the LWC controller
    // In tests, CustomMetadataSaver skips the actual callout, so this should return null (no job id).
    @IsTest
    static void it_should_enqueue_delete_without_throwing() {
        List<String> fullNames = new List<String>{
            'CustomMetadataDeployTest__mdt.Record_To_Delete'
        };

        // Should not throw; delete-only returns null job id under tests
        String id = CustomMetadataTableController.deleteCmdt(fullNames);
        System.assertEquals(null, id, 'Delete-only should return null job id during tests');
    }

    // NEW: getDeploymentStatus should handle blank id gracefully and return null
    @IsTest
    static void it_should_return_null_status_when_jobid_blank() {
        CustomMetadataTableController.DeploymentStatusResponse res =
            CustomMetadataTableController.getDeploymentStatus('');
        System.assertEquals(null, res, 'Blank deployment id should yield null response');
    }

    // ----------------- Mock -----------------
    private class DeploymentCalloutMock implements HttpCalloutMock {
        private String status;

        public void setDeploymentStatus(String status) {
            this.status = status;
        }

        public HttpResponse respond(HttpRequest httpRequest) {
            CustomMetadataTableController.DeployResult deployResult = new CustomMetadataTableController.DeployResult();
            deployResult.status = this.status;

            CustomMetadataTableController.DeploymentStatusResponse deploymentStatusResponse =
                new CustomMetadataTableController.DeploymentStatusResponse();
            deploymentStatusResponse.deployResult = deployResult;
            deploymentStatusResponse.id = CustomMetadataSaver.MOCK_DEPLOYMENT_ID;

            HttpResponse httpResponse = new HttpResponse();
            httpResponse.setHeader('Content-Type', 'application/json');
            httpResponse.setBody(JSON.serialize(deploymentStatusResponse));
            httpResponse.setStatusCode(200);
            return httpResponse;
        }
    }

    // ─────────────────────────────────────────────
    // 1) getSObjectApiName: exercise the catch path
    // ─────────────────────────────────────────────
    @IsTest
    static void it_should_log_and_rethrow_when_getSObjectApiName_fails() {
        Boolean threw = false;

        Test.startTest();
        try {
            // Passing null will cause a NullPointerException inside the try block
            CustomMetadataTableController.getSObjectApiName(null);
            System.assert(false, 'Expected exception was not thrown');
        } catch (Exception ex) {
            threw = true;
            System.assertNotEquals(null, ex, 'Exception should be rethrown from getSObjectApiName');
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'getSObjectApiName should rethrow after logging');
    }

    // ─────────────────────────────────────────────
    // 2) deploy(List<SObject>): exercise its catch
    // ─────────────────────────────────────────────
    @IsTest
    static void it_should_log_and_rethrow_when_deploy_fails() {
        Boolean threw = false;

        Test.startTest();
        try {
            // Null list causes CustomMetadataSaver.deploy(List<SObject>) to blow up
            // in its for-each loop, inside the controller's try block.
            CustomMetadataTableController.deploy((List<SObject>)null);
            System.assert(false, 'Expected exception was not thrown');
        } catch (Exception ex) {
            threw = true;
            System.assertNotEquals(null, ex, 'Exception should be rethrown from deploy');
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'deploy should rethrow after logging');
    }

    // ─────────────────────────────────────────────
    // 3) getDeploymentStatus: exercise its catch
    //    by having the mock throw from respond().
    // ─────────────────────────────────────────────
    private class ThrowingDeploymentCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // Simulate ugly HTTP-level failure
            throw new CalloutException('Boom from mock');
        }
    }

    @IsTest
    static void it_should_log_and_rethrow_when_getDeploymentStatus_callout_fails() {
        Boolean threw = false;

        Test.setMock(HttpCalloutMock.class, new ThrowingDeploymentCalloutMock());

        Test.startTest();
        try {
            CustomMetadataTableController.getDeploymentStatus('someJobId');
            System.assert(false, 'Expected exception was not thrown');
        } catch (Exception ex) {
            threw = true;
            System.assertNotEquals(null, ex, 'Exception should be rethrown from getDeploymentStatus');
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'getDeploymentStatus should rethrow after logging');
    }
}

