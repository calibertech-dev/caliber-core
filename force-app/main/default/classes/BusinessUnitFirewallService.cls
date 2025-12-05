public with sharing class BusinessUnitFirewallService {

    private static final String FIREWALL_MESSAGE =
        'You do not have access to this Business Unit.';

    // ===== Test seam =====
    @TestVisible private static Boolean useTestAllowedBuIds = false;
    @TestVisible private static Set<Id> testAllowedBuIds;

    @TestVisible
    static void setTestAllowedBuIds(Set<Id> buIds) {
        useTestAllowedBuIds = true;
        testAllowedBuIds = (buIds == null) ? new Set<Id>() : new Set<Id>(buIds);
    }

    @TestVisible
    static void clearTestOverride() {
        useTestAllowedBuIds = false;
        testAllowedBuIds = null;
    }
    // =====================

    public static void enforceBusinessUnitAccess(List<SObject> records) {
        if (!CaliberCoreFeatures.isOn('BusinessUnitFirewall')) {
            return;
        }
        
        if (records == null || records.isEmpty()) return;

        SObjectType sType = records[0].getSObjectType();
        Map<String, Schema.SObjectField> fields =
            sType.getDescribe().fields.getMap();

        // Only act on objects that actually have Business_Unit__c
        if (!fields.containsKey('Business_Unit__c')) {
            return;
        }

        Set<Id> allowedBuIds;

        if (useTestAllowedBuIds) {
            // Test-injected BU set
            allowedBuIds = (testAllowedBuIds == null)
                ? new Set<Id>()
                : new Set<Id>(testAllowedBuIds);
        } else {
            Id userId = UserInfo.getUserId();
            List<BusinessUnitAccessService.Affiliation> affs =
                BusinessUnitAccessService.getAffiliationsForUser(userId);

            // If user has no affiliations at all, firewall is effectively off.
            if (affs.isEmpty()) {
                return;
            }

            allowedBuIds = new Set<Id>();
            for (BusinessUnitAccessService.Affiliation a : affs) {
                if (a != null && a.isActive && a.businessUnitId != null) {
                    allowedBuIds.add(a.businessUnitId);
                }
            }

            // If they only have inactive affiliations, block all BU-tagged records.
            if (allowedBuIds.isEmpty()) {
                for (SObject r : records) {
                    Id buId = (Id) r.get('Business_Unit__c');
                    if (buId != null) {
                        r.addError(FIREWALL_MESSAGE);
                    }
                }
                return;
            }
        }

        // Normal path: allow only records whose BU is in allowedBuIds
        for (SObject r : records) {
            Id buId = (Id) r.get('Business_Unit__c');
            if (buId == null) {
                // No BU on the record → let it through; other logic can complain if needed.
                continue;
            }
            if (!allowedBuIds.contains(buId)) {
                r.addError(FIREWALL_MESSAGE);
            }
        }
    }

    @TestVisible
    static String getFirewallMessage() {
        return FIREWALL_MESSAGE;
    }
}
