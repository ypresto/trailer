
@interface ApiServer : NSManagedObject

@property (nonatomic, retain) NSString * apiPath;
@property (nonatomic, retain) NSString * authToken;
@property (nonatomic, retain) NSString * label;
@property (nonatomic, retain) NSDate * latestReceivedEventDateProcessed;
@property (nonatomic, retain) NSString * latestReceivedEventEtag;
@property (nonatomic, retain) NSDate * latestUserEventDateProcessed;
@property (nonatomic, retain) NSString * latestUserEventEtag;
@property (nonatomic, retain) NSNumber * requestsLimit;
@property (nonatomic, retain) NSNumber * requestsRemaining;
@property (nonatomic, retain) NSDate * resetDate;
@property (nonatomic, retain) NSNumber * userId;
@property (nonatomic, retain) NSString * userName;
@property (nonatomic, retain) NSString * webPath;
@property (nonatomic, retain) NSDate * createdAt;
@property (nonatomic, retain) NSNumber * lastSyncSucceeded;
@property (nonatomic, retain) NSNumber * reportRefreshFailures;

@property (nonatomic, retain) NSSet *repos;
@property (nonatomic, retain) NSSet *comments;
@property (nonatomic, retain) NSSet *pullRequests;
@property (nonatomic, retain) NSSet *statuses;
@property (nonatomic, retain) NSSet *labels;

+ (ApiServer *)insertNewServerInMoc:(NSManagedObjectContext *)moc;

+ (void)resetSyncSuccessInMoc:(NSManagedObjectContext *)moc;

+ (BOOL)shouldReportRefreshFailureInMoc:(NSManagedObjectContext *)moc;

+ (void)ensureAtLeastGithubInMoc:(NSManagedObjectContext *)moc;

+ (ApiServer *)addDefaultGithubInMoc:(NSManagedObjectContext *)moc;

+ (NSArray *)allApiServersInMoc:(NSManagedObjectContext *)moc;

+ (BOOL)someServersHaveAuthTokensInMoc:(NSManagedObjectContext *)moc;

+ (NSUInteger)countApiServersInMoc:(NSManagedObjectContext *)moc;

- (void)rollBackAllUpdatesInMoc:(NSManagedObjectContext *)moc;

- (void)clearAllRelatedInfo;

- (void)resetToGithub;

- (BOOL)goodToGo;

@end

@interface ApiServer (CoreDataGeneratedAccessors)

- (void)addCommentsObject:(PRComment *)value;
- (void)removeCommentsObject:(PRComment *)value;
- (void)addComments:(NSSet *)values;
- (void)removeComments:(NSSet *)values;

- (void)addPullRequestsObject:(PullRequest *)value;
- (void)removePullRequestsObject:(PullRequest *)value;
- (void)addPullRequests:(NSSet *)values;
- (void)removePullRequests:(NSSet *)values;

- (void)addStatusesObject:(PRStatus *)value;
- (void)removeStatusesObject:(PRStatus *)value;
- (void)addStatuses:(NSSet *)values;
- (void)removeStatuses:(NSSet *)values;

- (void)addReposObject:(Repo *)value;
- (void)removeReposObject:(Repo *)value;
- (void)addRepos:(NSSet *)values;
- (void)removeRepos:(NSSet *)values;

- (void)addLabelsObject:(PRLabel *)value;
- (void)removeLabelsObject:(PRLabel *)value;
- (void)addLabels:(NSSet *)values;
- (void)removeLabels:(NSSet *)values;

@end
