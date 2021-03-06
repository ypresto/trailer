
@interface Repo : DataItem

@property (nonatomic, retain) NSString * fullName;
@property (nonatomic, retain) NSString * webUrl;
@property (nonatomic, retain) NSNumber * fork;
@property (nonatomic, retain) NSNumber * hidden;
@property (nonatomic, retain) NSNumber * dirty;
@property (nonatomic, retain) NSDate * lastDirtied;
@property (nonatomic, retain) NSNumber * inaccessible;
@property (nonatomic, retain) NSSet *pullRequests;

+ (Repo*)repoWithInfo:(NSDictionary*)info fromServer:(ApiServer *)apiServer;

+ (NSArray *)visibleReposInMoc:(NSManagedObjectContext *)moc;

+ (NSUInteger)countVisibleReposInMoc:(NSManagedObjectContext *)moc;

+ (NSArray *)syncableReposInMoc:(NSManagedObjectContext *)moc;

+ (NSArray *)unsyncableReposInMoc:(NSManagedObjectContext *)moc;

+ (NSArray *)inaccessibleReposInMoc:(NSManagedObjectContext *)moc;

+ (void)markDirtyReposWithIds:(NSSet *)ids inMoc:(NSManagedObjectContext *)moc;

@end

@interface Repo (CoreDataGeneratedAccessors)

- (void)addPullRequestsObject:(PullRequest *)value;
- (void)removePullRequestsObject:(PullRequest *)value;
- (void)addPullRequests:(NSSet *)values;
- (void)removePullRequests:(NSSet *)values;

@end
