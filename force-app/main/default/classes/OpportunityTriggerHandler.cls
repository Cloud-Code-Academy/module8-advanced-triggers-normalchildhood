public with sharing class OpportunityTriggerHandler {
    public static void setTypeProspect(List<Account> accounts) {
        for (Account acc : accounts) {
            if (acc.Type == null) {
                acc.Type = 'Prospect';
            }
        }
    }
    
    public static void validateAmountGreaterThan5000(List<Opportunity> opps) {
        for(Opportunity opp : opps){
            if(opp.Amount < 5000){
                opp.addError('Opportunity amount must be greater than 5000');
            }
        }
        
    }
    /* public static void closedWonBankingNoDelete(List<Opportunity> opps) {
        Map<Id, Account> accounts = new Map<Id, Account>([SELECT Id, Industry FROM Account WHERE Id IN 
                                                    (SELECT AccountId FROM Opportunity WHERE Id IN :Trigger.old)]);
        for(Opportunity opp : opps){
            if(opp.StageName == 'Closed Won'){
                if(accounts.get(opp.AccountId).Industry == 'Banking'){
                    opp.addError('Cannot delete a closed won opportunity for a banking account');
                }
            }
        }
    }*/ //This method above is not needed since you shouldn't be able to delete any closed won opps
    
    public static void noDeleteClosedOpps (List<Opportunity> opps) {
        for (Opportunity oldOpp : opps){
            if (oldOpp.IsClosed){
                oldOpp.addError('Cannot delete closed opportunity');
            }
        }
    }
    
    /*
     * Opportunity Trigger
     * When an opportunity is updated set the primary contact on the opportunity to the contact with the title of 'CEO'.
     * Trigger should only fire on update.
     */
    public static void oppCEOContact(List<Opportunity> opps){
        Set<Id> accountIds = new Set<Id>();
        for(Opportunity opp : opps){
            accountIds.add(opp.AccountId);
        }
        
        Map<Id, Contact> contacts = new Map<Id, Contact>([SELECT Id, FirstName, AccountId FROM Contact WHERE AccountId IN :accountIds AND Title = 'CEO' ORDER BY FirstName ASC]);
        Map<Id, Contact> accountIdToContact = new Map<Id, Contact>();
        
        for (Contact cont : contacts.values()) {
            if (!accountIdToContact.containsKey(cont.AccountId)) {
                accountIdToContact.put(cont.AccountId, cont);
            }
        }
        
        for(Opportunity opp : opps){
            if(opp.Primary_Contact__c == null){
                if (accountIdToContact.containsKey(opp.AccountId)){
                    opp.Primary_Contact__c = accountIdToContact.get(opp.AccountId).Id;
                }
            }
        }
    }
    
    public static void newOppDefaultType (List<Opportunity> opps) {
        Opportunity opp = opps[0];
        if (opp.Type == null){
            opp.Type = 'New Customer';
        }
    }
    
    public static void newOppTask(List<Opportunity> opps) {
        for (Opportunity opp : opps){
            Task tsk = new Task();
            tsk.Subject = 'Call Primary Contact';
            tsk.WhatId = opp.Id;
            tsk.WhoId = opp.Primary_Contact__c;
            tsk.OwnerId = opp.OwnerId;
            tsk.ActivityDate = Date.today().addDays(3);
            insert tsk;
        }
    }
    
    public static void stageChangesInDesc (List<Opportunity> opps) {
        for (Opportunity opp : opps){
            for (Opportunity oldOpp : opps){
                if (opp.StageName != null){
                    opp.Description += '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
                }
            }
        }
        update Trigger.new;
    }
    
    public static void notifyOwnersOpportunityDeleted(List<Opportunity> opps) {
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        for (Opportunity opp : opps){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            String[] toAddresses = new String[] {[SELECT Id, Email FROM User WHERE Id = :opp.OwnerId].Email};
            mail.setToAddresses(toAddresses);
            mail.setSubject('Opportunity Deleted : ' + opp.Name);
            mail.setPlainTextBody('Your Opportunity: ' + opp.Name +' has been deleted.');
            mails.add(mail);
        }
        
        try {
            Messaging.sendEmail(mails);
        } catch (Exception e){
            System.debug('Exception: ' + e.getMessage());
        }
    }
    
    public static void assignPrimaryContact(Map<Id,Opportunity> oppNewMap) {
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
        for (Opportunity opp : oppNewMap.values()){
            Contact primaryContact = [SELECT Id, AccountId FROM Contact WHERE Title = 'VP Sales' AND AccountId = :opp.AccountId LIMIT 1];
            if (opp.Primary_Contact__c == null){
                Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
                oppToUpdate.Primary_Contact__c = primaryContact.Id;
                oppMap.put(opp.Id, oppToUpdate);
            }
        }
        update oppMap.values();
    }
}