global with sharing class ErrorLogInvocable {
    global class Request {
        @InvocableVariable(required=true)  public String Message;
        @InvocableVariable                 public String Context;
        @InvocableVariable                 public String Severity;
        @InvocableVariable                 public String CorrelationId;
        @InvocableVariable                 public String PayloadJson;
        @InvocableVariable                 public String Source;
        @InvocableVariable                 public String Component;
        @InvocableVariable                 public String Operation;
    }

    @InvocableMethod(label='Log Error' description='Write an entry to Caliber Core error log')
    global static List<Id> log(List<Request> requests) {
        List<Id> out = new List<Id>();
        if (requests == null) return out;
        for (Request r : requests) {
            out.add(ErrorLogService.log(
                r.Context,
                r.Message,
                r.Severity,
                r.CorrelationId,
                null,
                r.PayloadJson,
                r.Source,
                r.Component,
                r.Operation
            ));
        }
        return out;
    }
}
