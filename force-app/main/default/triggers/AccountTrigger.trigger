trigger AccountTrigger on Account (before insert) {
    AccountNumberGenerator.assignUniqueAccountNumbers(Trigger.new);
}
