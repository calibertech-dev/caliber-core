public with sharing class ServiceRelationshipBrandingService {

    /**
     * Unified branding context for a record or BU.
     * This is what templates / email services / flows should consume.
     */
    public class BrandingContext {
        public Id businessUnitId;
        public String businessUnitName;
        public String businessUnitShortName;
        public String businessUnitShortCode;
        public String website;

        public String supportEmail;
        public String supportPhone;
        public String customerServiceEmail;
        public String customerServicePhone;
        public String noReplyEmail;

        public Id brandingId;
        public String logoUrl;
        public String primaryColor;
        public String accentColor;
    }

    /**
     * Resolve branding for an arbitrary record.
     * Uses RelationshipContextService to find the Business Unit
     * (via Service Relationship plugin or direct BU field).
     */
    public static BrandingContext forRecord(SObject record) {
        if (record == null) {
            return new BrandingContext();
        }

        RelationshipContextService.RelationshipContext ctx =
            RelationshipContextService.resolve(record);

        if (ctx == null || ctx.businessUnitId == null) {
            return new BrandingContext();
        }

        return forBusinessUnit(ctx.businessUnitId);
    }

    /**
     * Resolve branding directly from a Business Unit Id.
     * Useful for flows or services that already know the BU.
     */
    public static BrandingContext forBusinessUnit(Id businessUnitId) {
        BrandingContext bc = new BrandingContext();

        if (businessUnitId == null) {
            return bc;
        }

        // --- Load Business Unit ---

        Business_Unit__c bu = [
            SELECT Id,
                   Name,
                   Short_Name__c,
                   Short_Code__c,
                   Website__c,
                   Support_Email__c,
                   Support_Phone__c,
                   Customer_Service_Email__c,
                   Customer_Service_Phone__c,
                   No_Reply_Email__c
            FROM Business_Unit__c
            WHERE Id = :businessUnitId
            LIMIT 1
        ];

        bc.businessUnitId       = bu.Id;
        bc.businessUnitName     = bu.Name;
        bc.businessUnitShortName = bu.Short_Name__c;
        bc.businessUnitShortCode = bu.Short_Code__c;
        bc.website              = bu.Website__c;

        bc.supportEmail         = bu.Support_Email__c;
        bc.supportPhone         = bu.Support_Phone__c;
        bc.customerServiceEmail = bu.Customer_Service_Email__c;
        bc.customerServicePhone = bu.Customer_Service_Phone__c;
        bc.noReplyEmail         = bu.No_Reply_Email__c;

        // --- Load Branding record (if any) ---

        List<Business_Unit_Branding__c> brandings = [
            SELECT Id,
                   Logo_URL__c,
                   Primary_Color__c,
                   Accent_Color__c
            FROM Business_Unit_Branding__c
            WHERE Business_Unit__c = :businessUnitId
            LIMIT 1
        ];

        if (!brandings.isEmpty()) {
            Business_Unit_Branding__c b = brandings[0];
            bc.brandingId  = b.Id;
            bc.logoUrl     = b.Logo_URL__c;
            bc.primaryColor = b.Primary_Color__c;
            bc.accentColor  = b.Accent_Color__c;
        }

        return bc;
    }
}
