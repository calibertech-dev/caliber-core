trigger Account_BeforeInsert on Account (before insert) {
    AccountNumberGenerator.assignUniqueAccountNumbers(Trigger.new);
}
