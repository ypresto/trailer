
#define LOW_API_WARNING 0.20

typedef enum {
	kNewComment = 0,
	kNewPr,
	kPrMerged,
	kPrReopened,
	kNewMention,
	kPrClosed,
	kNewRepoSubscribed,
	kNewRepoAnnouncement,
	kNewPrAssigned
} PRNotificationType;

typedef enum {
	kCreationDate = 0,
	kRecentActivity,
	kTitle,
	kRepository,
} PRSortingMethod;

typedef enum {
	kRepoAutoSubscribeNone = 0,
	kRepoAutoSubscribeParentsOnly,
	kRepoDontAutoSubscribeAll,
} PRSubscriptionPolicy;

typedef enum {
	kPullRequestHandlingKeepMine = 0,
	kPullRequestHandlingKeepAll,
	kPullRequestHandlingKeepNone,
} PRHandlingPolicy;

typedef void (^completionBlockType)();

#define PULL_REQUEST_ID_KEY @"pullRequestIdKey"
#define COMMENT_ID_KEY @"commentIdKey"
#define NOTIFICATION_URL_KEY @"urlKey"

#define API_USAGE_UPDATE @"RateUpdateNotification"

#define NETWORK_TIMEOUT 120.0
#define BACKOFF_STEP 120.0

@interface API : NSObject

@property (nonatomic) Reachability *reachability;
@property (nonatomic) long successfulRefreshesSinceLastStatusCheck, successfulRefreshesSinceLastLabelCheck;

- (void)updateLimitsFromServer;

- (void)fetchRepositoriesToMoc:(NSManagedObjectContext *)moc
				   andCallback:(completionBlockType)callback;

- (void)fetchPullRequestsForActiveReposAndCallback:(completionBlockType)callback;

- (void)getRateLimitFromServer:(ApiServer *)apiServer
				   andCallback:(void(^)(long long remaining, long long limit, long long reset))callback;

- (void)testApiToServer:(ApiServer *)apiServer andCallback:(void (^)(NSError *))callback;

- (void)expireOldImageCacheEntries;

- (void)clearImageCache;

- (NSString *)lastUpdateDescription;

- (BOOL)haveCachedAvatar:(NSString *)path
	  tryLoadAndCallback:(void(^)(IMAGE_CLASS *image))callbackOrNil;

@end
