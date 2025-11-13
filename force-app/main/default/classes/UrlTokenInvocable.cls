public with sharing class UrlTokenInvocable {

    public class Input {
        @InvocableVariable public Integer length;
    }

    public class Output {
        @InvocableVariable public String token;
    }

    @InvocableMethod(label='Generate URL-safe Token')
    public static List<Output> generate(List<Input> inputs) {
        List<Output> outs = new List<Output>();
        for (Input inRec : inputs) {
            Output out = new Output();
            Integer len = (inRec.length == null ? 22 : inRec.length);
            out.token = UrlTokenService.makeUrlSafeToken(len);
            outs.add(out);
        }
        return outs;
    }
}
