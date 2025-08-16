public with sharing class OpportunityTriggerHandler {
    public static boolean skipUpdateHandlers = false;
    
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
    
    public static void noDeleteClosedOpps(List<Opportunity> opps) {
    if (opps == null || opps.isEmpty()) {
        return;
    }

    // Collect IDs safely
    Set<Id> oppIds = new Set<Id>();
    for (Opportunity opp : opps) {
        if (opp != null && opp.Id != null) {
            oppIds.add(opp.Id);
        }
    }

    if (oppIds.isEmpty()) {
        return;
    }

    // Query IsClosed explicitly
    Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(
        [SELECT Id, IsClosed FROM Opportunity WHERE Id IN :oppIds]
    );

    // Now check and add errors
    for (Opportunity oldOpp : opps) {
        Opportunity queried = oppMap.get(oldOpp.Id);
        if (queried != null && Boolean.valueOf(queried.IsClosed)) {
            oldOpp.addError('Cannot delete closed opportunity');
        }
    }
}

    
    
    
    
    
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
        List<Task> tasksToInsert = new List<Task>();
        for (Opportunity opp : opps){
            Task tsk = new Task();
            tsk.Subject = 'Call Primary Contact';
            tsk.WhatId = opp.Id;
            tsk.WhoId = opp.Primary_Contact__c;
            tsk.OwnerId = opp.OwnerId;
            tsk.ActivityDate = Date.today().addDays(3);
            tasksToInsert.add(tsk);
        }
        if (!tasksToInsert.isEmpty()){
            insert tasksToInsert;
        }
    }
    
    
    public static void stageChangesInDesc (List<Opportunity> opps) {
        for (Opportunity opp : opps){
            if (opp.StageName != null){
                opp.Description += '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
            }
        }
        update Trigger.new;
    }
    
    public static void notifyOwnersOpportunityDeleted(List<Opportunity> opps) {
        
        Set<Id> ownerIds = new Set<Id>();
        for (Opportunity opp : opps) {
            if (opp.OwnerId != null) {
                ownerIds.add(opp.OwnerId);
            }
        }
        
        Map<Id, User> ownersMap = new Map<Id, User>(
            [SELECT Id, Email FROM User WHERE Id IN :ownerIds]
            );
        
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        for (Opportunity opp : opps) {
            User owner = ownersMap.get(opp.OwnerId);
            if (owner != null && String.isNotBlank(owner.Email)) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[] { owner.Email });
                mail.setSubject('Opportunity Deleted: ' + opp.Name);
                mail.setPlainTextBody('Your Opportunity "' + opp.Name + '" has been deleted.');
                mails.add(mail);
            }
        }
        
        if (!mails.isEmpty()) {
            try {
                Messaging.sendEmail(mails);
            } catch (Exception e) {
                System.debug('Exception: ' + e.getMessage());
            }
        }
    }
    
    public static void assignPrimaryContact(List<Opportunity> oppList) {
        
        Map<Id, Opportunity> oppNewMap = new Map<Id, Opportunity>(oppList);
        
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : oppNewMap.values()) {
            if (opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }
        }
        
        if (accountIds.isEmpty()) {
            return;
        }
        
        Map<Id, Contact> accountToContactMap = new Map<Id, Contact>();
        for (Contact cont : [
        SELECT Id, AccountId
        FROM Contact
        WHERE Title = 'VP Sales'
        AND AccountId IN :accountIds
        ORDER BY CreatedDate ASC, Id ASC
    ]) {
            if (!accountToContactMap.containsKey(cont.AccountId)) {
                accountToContactMap.put(cont.AccountId, cont);
            }
        }
        
        if (accountToContactMap.isEmpty()) {
            return;
        }
        
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        
        for (Opportunity opp : oppNewMap.values()) {
            Boolean hasMatchingContact = accountToContactMap.containsKey(opp.AccountId);
            if (!hasMatchingContact) continue;
            
            if (Trigger.isUndelete) {
                oppsToUpdate.add(new Opportunity(
                    Id = opp.Id,
                Primary_Contact__c = accountToContactMap.get(opp.AccountId).Id
                    ));
            } else {
                if (opp.Primary_Contact__c == null) {
                    oppsToUpdate.add(new Opportunity(
                        Id = opp.Id,
                    Primary_Contact__c = accountToContactMap.get(opp.AccountId).Id
                        ));
                }
            }
        }
        
        if (!oppsToUpdate.isEmpty()) {
            skipUpdateHandlers = true;
            update oppsToUpdate;
            skipUpdateHandlers = false;
        }
    }
}