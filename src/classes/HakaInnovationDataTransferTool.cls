public with sharing class HakaInnovationDataTransferTool {

    // select internal Community
    public static Community comm;

    // setup Feasibility Study and Risk record types
    public static Map<String, Id> studyTypes;
    public static Map<String, Id> riskTypes;
    public static Map<Id, Id> studyType2RiskType;

    public static Map<Id, HP_INN__Feasibility_Study__c> studies;

    private void prepForImport() {

        comm = [SELECT Id FROM Community WHERE Name = 'Internal Community' LIMIT 1];

        List<RecordType> types = [SELECT Id, Name, SObjectType FROM RecordType WHERE sObjectType = 'HP_INN__Feasibility_Study__c' OR sObjectType = 'HP_INN__Risk__c'];
        studyTypes = new Map<String, Id>();
        riskTypes = new Map<String, Id>();

        for (RecordType type : types) {
            if (type.sObjectType == 'HP_INN__Feasibility_Study__c') {
                studyTypes.put(type.Name, type.Id);
            } else if (type.SObjectType == 'HP_INN__Risk__c') {
                riskTypes.put(type.Name, type.Id);
            }
        }

        // build studyType2RiskType map
        for (String studyType : studyTypes.keySet()) {
            studyType2RiskType.put(studyTypes.get(studyType), riskTypes.get(studyType));
        }

        System.debug('Study Types: ' + studyTypes);
        System.debug('Risk Types: ' + riskTypes);

    }

    public String export() {

        String serializedData = SObjectDataLoader.serialize((new Map<Id, SObject>([SELECT Id FROM HP_NPI__Release__c])).keySet(),
            new SObjectDataLoader.SerializeConfig()
                .auto(HP_NPI__Release__c.SObjectType)
                .follow(HP_NPI__Release__c.HP_NPI__ProductMasterId__c) // up to PM
                .followChild(HP_NPI__ProductTeamMember__c.HP_NPI__ProductMasterId__c) // down to Product Team Members
                .followChild(HP_NPI__Persona__c.HP_NPI__SegmentId__c) // down to Persona
                .followChild(Case.HP_NPI__ProductMasterId__c) // down to Cases
                .followChild(Idea.HP_NPI__ProductMasterId__c) // down to Ideas
                .followChild(HP_NPI__VoiceOfTheCustomer__c.HP_NPI__ProductMasterId__c) // down to VOC
                .followChild(Product2.HP_NPI__ProductMasterId__c) // down to Products
                .followChild(HP_NPI__ProductCampaign__c.HP_NPI__ProductMasterId__c) // down to Product Campaign
                .follow(HP_NPI__ProductCampaign__c.HP_NPI__CampaignId__c) // and back up to Campaign
                .followChild(HP_NPI__ProductSegment__c.HP_NPI__ProductMasterId__c) // down to Product Segment
                .follow(HP_NPI__ProductSegment__c.HP_NPI__SegmentId__c) // and back up to Segment (to include the SegmentId on the PS record)
                .followChild(HP_NPI__SalesAction__c.HP_NPI__ProductSegmentId__c) // down to Sales Action
                .follow(HP_NPI__SalesAction__c.HP_NPI__Persona__c) // and back up to Persona (to include the PersonaId on the SA record)
                .followChild(HP_NPI__SegmentQualificationCriteria__c.HP_NPI__ProductSegmentId__c) // down to Seg Qual Criteria on PS
                .followChild(HP_INN__Release_Voice_Of_The_Customer__c.HP_INN__ReleaseId__c) // down to RVOC
                .follow(HP_INN__Release_Voice_Of_The_Customer__c.HP_INN__VoiceOfTheCustomerId__c) // and back up to VOC
                .followChild(HP_INN__Release_Case__c.HP_INN__ReleaseId__c) // down to RCase
                .follow(HP_INN__Release_Case__c.HP_INN__CaseId__c) // and back up to Case
                .followChild(HP_INN__Release_Idea__c.HP_INN__ReleaseId__c) // down to Release
                .follow(HP_INN__Release_Idea__c.HP_INN__IdeaId__c) // and back up to Idea
        );

        return serializedData;
    }

    public void import(String endpoint, String filename) {

        // sets up data required for the ReferenceCallback class later
        prepForImport();

        // data
        // Get the JSON document from the external server
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint + filename);
        req.setMethod('GET');
        HttpResponse res = http.send(req);

        String importData = res.getBody();

        // Log the JSON content
        System.debug(importData);

        // perform import
        Set<Id> newRecordIds = SObjectDataLoader.deserialize(importData, new ReferenceCallback());
        System.debug(newRecordIds);

    }



    public class ReferenceCallback implements SObjectDataLoader.IDeserializeCallback {

        // interface implementation
        public void unresolvedReferences(Schema.SObjectType sObjectType, List<SObjectDataLoader.UnresolvedReferences> unresolvedReferences){
            System.debug('Type: ' + sObjectType);
            for (SObjectDataLoader.UnresolvedReferences ref : unresolvedReferences) {
                System.debug(ref);
            }

            if (sObjectType == Idea.SObjectType) {
                for (SObjectDataLoader.UnresolvedReferences ref : unresolvedReferences) {
                    if (ref.References.contains(Idea.CommunityId)) {
                        ref.Record.put(Idea.CommunityId, HakaInnovationDataTransferTool.comm.Id);
                    }
                }
            } else if (sObjectType == HP_INN__Feasibility_Study__c.SObjectType) {
                // assign record types to Study and Risk records
                // NOTE: the exported Study records must have the name of the record type somewhere
                // in the name of the study for this to work
                for (SObjectDataLoader.UnresolvedReferences ref : unresolvedReferences) {
                    if (ref.References.contains(HP_INN__Feasibility_Study__c.RecordTypeId)) {
                        Id rtId;
                        String studyName = (String)ref.Record.get('Name');

                        if (studyName.contains('Market')) {
                            rtId = HakaInnovationDataTransferTool.studyTypes.get('Market');
                        } else if (studyName.contains('Economic')) {
                            rtId = HakaInnovationDataTransferTool.studyTypes.get('Economic');
                        } else if (studyName.contains('Technical')) {
                            rtId = HakaInnovationDataTransferTool.studyTypes.get('Technical');
                        } else if (studyName.contains('Operational')) {
                            rtId = HakaInnovationDataTransferTool.studyTypes.get('Operational');
                        }

                        ref.Record.put(HP_INN__Feasibility_Study__c.RecordTypeId, rtId);
                        System.debug(ref.Record);
                    }
                }
            } else if (sObjectType == HP_INN__Risk__c.SObjectType) {
                // by definition, Feasibility_Study__c records must have already been inserted
                // we query for, and store them, here
                if (HakaInnovationDataTransferTool.studies.isEmpty()) {
                    HakaInnovationDataTransferTool.studies = new Map<Id, HP_INN__Feasibility_Study__c>([SELECT Id, Name, RecordTypeId FROM HP_INN__Feasibility_Study__c]);
                }

                // now find the Record Type for the parent Study and use that to apply
                // the correct Record Type for the Risk
                for (SObjectDataLoader.UnresolvedReferences ref : unresolvedReferences) {
                    if (ref.References.contains(HP_INN__Risk__c.RecordTypeId)) {
                        Id studyId = (Id)ref.Record.get('HP_INN__FeasibilityId__c');
                        Id studyRecordTypeId = HakaInnovationDataTransferTool.studies.get(studyId).RecordTypeId;
                        Id riskRecordTypeId = HakaInnovationDataTransferTool.studyType2RiskType.get(studyRecordTypeId);

                        ref.Record.put(HP_INN__Risk__c.RecordTypeId, riskRecordTypeId);
                    }
                }
            }
        }
    }

}