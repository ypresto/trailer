
@implementation PullRequest

@dynamic url;
@dynamic number;
@dynamic state;
@dynamic title;
@dynamic body;
@dynamic issueCommentLink;
@dynamic reviewCommentLink;
@dynamic updatedAt;
@dynamic serverId;
@dynamic postSyncAction;
@dynamic webUrl;
@dynamic userId;
@dynamic latestReadCommentDate;
@dynamic condition;
@dynamic userAvatarUrl;
@dynamic userLogin;
@dynamic sectionIndex;
@dynamic totalComments;
@dynamic unreadComments;
@dynamic repoName;
@dynamic mergeable;
@dynamic statusesLink;
@dynamic assignedToMe;
@dynamic isNewAssignment;
@dynamic issueUrl;
@dynamic reopened;
@dynamic statuses;
@dynamic repo;
@dynamic comments;
@dynamic labels;

static NSDateFormatter *itemDateFormatter;

+ (void)initialize
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		itemDateFormatter = [[NSDateFormatter alloc] init];
		itemDateFormatter.doesRelativeDateFormatting = YES;
		itemDateFormatter.dateStyle = NSDateFormatterMediumStyle;
		itemDateFormatter.timeStyle = NSDateFormatterShortStyle;
	});
}

+ (PullRequest *)pullRequestWithInfo:(NSDictionary *)info fromServer:(ApiServer *)apiServer
{
	PullRequest *p = [DataItem itemWithInfo:info type:@"PullRequest" fromServer:apiServer];
	if(p.postSyncAction.integerValue != kPostSyncDoNothing)
	{
		p.url = [info ofk:@"url"];
		p.webUrl = [info ofk:@"html_url"];
		p.number = [info ofk:@"number"];
		p.state = [info ofk:@"state"];
		p.title = [info ofk:@"title"];
		p.body = [info ofk:@"body"];

		NSNumber *m = [info ofk:@"mergeable"];
		if(!m) m = @YES;
		p.mergeable = m;

		NSDictionary *userInfo = [info ofk:@"user"];
		p.userId = [userInfo ofk:@"id"];
		p.userLogin = [userInfo ofk:@"login"];
		p.userAvatarUrl = [userInfo ofk:@"avatar_url"];

		NSDictionary *linkInfo = [info ofk:@"_links"];
		p.issueCommentLink = [[linkInfo ofk:@"comments"] ofk:@"href"];
		p.reviewCommentLink = [[linkInfo ofk:@"review_comments"] ofk:@"href"];
		p.statusesLink = [[linkInfo ofk:@"statuses"] ofk:@"href"];
		p.issueUrl = [[linkInfo ofk:@"issue"] ofk:@"href"];
	}

	p.reopened = @(p.condition.integerValue == kPullRequestConditionClosed);
	p.condition = @kPullRequestConditionOpen;

	return p;
}

- (void)postProcess
{
	NSInteger section;
	NSInteger condition = self.condition.integerValue;

	if(condition==kPullRequestConditionMerged)		section = kPullRequestSectionMerged;
	else if(condition==kPullRequestConditionClosed) section = kPullRequestSectionClosed;
	else if(self.isMine)							section = kPullRequestSectionMine;
	else if(self.commentedByMe)						section = kPullRequestSectionParticipated;
	else if(settings.hideAllPrsSection)	section = kPullRequestSectionNone;
	else											section = kPullRequestSectionAll;

	NSFetchRequest *f = [NSFetchRequest fetchRequestWithEntityName:@"PRComment"];
	f.returnsObjectsAsFaults = NO;

	NSDate *latestDate = self.latestReadCommentDate;

	if(((section == kPullRequestSectionAll) || (section == kPullRequestSectionNone))
	   && settings.autoParticipateInMentions)
	{
		if(self.refersToMe)
		{
			section = kPullRequestSectionParticipated;
			f.predicate = [self predicateForOthersCommentsSinceDate:latestDate];
			self.unreadComments = @([self.managedObjectContext countForFetchRequest:f error:nil]);
		}
		else
		{
			f.predicate = [self predicateForOthersCommentsSinceDate:nil];
			NSUInteger unreadCommentCount = 0;
			NSArray *allOthersComments = [self.managedObjectContext executeFetchRequest:f error:nil];
			for(PRComment *c in allOthersComments)
			{
				if(c.refersToMe)
				{
					section = kPullRequestSectionParticipated;
				}
				if([c.createdAt compare:latestDate]==NSOrderedDescending)
				{
					unreadCommentCount++;
				}
			}
			self.unreadComments = @(unreadCommentCount);
		}
	}
	else
	{
		f.predicate = [self predicateForOthersCommentsSinceDate:latestDate];
		self.unreadComments = @([self.managedObjectContext countForFetchRequest:f error:nil]);
	}

	self.sectionIndex = @(section);

	self.totalComments = @(self.comments.count);
	self.repoName = self.repo.fullName;

	if(!self.title) self.title = @"(No title)";
}

- (BOOL)markUnmergeable
{
	if(!self.mergeable.boolValue)
	{
		NSInteger section = self.sectionIndex.integerValue;

		if(section == kPullRequestSectionClosed || section == kPullRequestSectionMerged)
			return NO;

		if(section == kPullRequestSectionAll &&
		   settings.markUnmergeableOnUserSectionsOnly)
			return NO;

		return YES;
	}
	return NO;
}

- (BOOL)refersToMe
{
	NSString *myHandle = [NSString stringWithFormat:@"@%@", self.apiServer.userName];
	NSRange rangeOfHandle = [self.body rangeOfString:myHandle options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch];
	return rangeOfHandle.location != NSNotFound;
}

- (NSString *)sectionName
{
	return [kPullRequestSectionNames objectAtIndex:self.sectionIndex.integerValue];
}

- (NSString *)accessibleSubtitle
{
	NSMutableArray *components = [NSMutableArray new];
	
	if(settings.showReposInName)
	{
		[components addObject:[NSString stringWithFormat:@"Repository: %@", self.repoName]];
	}

	if(self.userLogin.length)
	{
		[components addObject:[NSString stringWithFormat:@"Author: %@", self.userLogin]];
	}

	if(settings.showCreatedInsteadOfUpdated)
	{
		[components addObject:[NSString stringWithFormat:@"Created %@",[itemDateFormatter stringFromDate:self.createdAt]]];
	}
	else
	{
		[components addObject:[NSString stringWithFormat:@"Updated %@",[itemDateFormatter stringFromDate:self.updatedAt]]];
	}

	if(!self.mergeable.boolValue)
	{
		[components addObject:@"Cannot be merged!"];
	}

	return [components componentsJoinedByString:@","];
}

- (NSString *)accessibleTitle
{
	NSMutableArray *components = [NSMutableArray new];
	[components addObject:self.title];
	if(settings.showLabels)
	{
		NSArray *sortedLabels = [self.labels sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
		[components addObject:[NSString stringWithFormat:@"%ld labels:",(long)sortedLabels.count]];
		for(PRLabel *l in sortedLabels) [components addObject:l.name];
	}
	return [components componentsJoinedByString:@","];
}

- (NSMutableAttributedString *)titleWithFont:(FONT_CLASS *)font labelFont:(FONT_CLASS *)labelFont
{
	NSMutableParagraphStyle *p = [[NSMutableParagraphStyle alloc] init];
	p.paragraphSpacing = 1.0;

	NSDictionary *titleAttributes = @{ NSFontAttributeName: font,
									   NSForegroundColorAttributeName: [COLOR_CLASS blackColor],
									   NSBackgroundColorAttributeName: [COLOR_CLASS clearColor],
									   NSParagraphStyleAttributeName: p,
									   };

	NSMutableAttributedString *_title = [[NSMutableAttributedString alloc] initWithString:self.title
																			   attributes:titleAttributes];

	if(settings.showLabels)
	{
		NSArray *sortedLabels = [self.labels sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
		if(sortedLabels.count>0)
		{
			[_title appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:titleAttributes]];
			NSMutableParagraphStyle *lp = [[NSMutableParagraphStyle alloc] init];
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
			lp.lineHeightMultiple = 1.15;
			NSDictionary *labelAttributes = [NSMutableDictionary dictionaryWithDictionary:
											 @{ NSFontAttributeName: labelFont,
												NSBackgroundColorAttributeName: [COLOR_CLASS clearColor],
												NSBaselineOffsetAttributeName: @2.0,
												NSParagraphStyleAttributeName: lp,
												}];
#else
			lp.minimumLineHeight = labelFont.pointSize+6.0;
			NSDictionary *labelAttributes = [NSMutableDictionary dictionaryWithDictionary:
											 @{ NSFontAttributeName: labelFont,
												NSBackgroundColorAttributeName: [COLOR_CLASS clearColor],
												NSBaselineOffsetAttributeName: @1.0,
												NSParagraphStyleAttributeName: lp,
												}];
#endif
			NSInteger count=0;
			for(PRLabel *l in sortedLabels)
			{
				NSMutableDictionary *a = [labelAttributes mutableCopy];
				COLOR_CLASS *color = l.colorForDisplay;
				a[NSBackgroundColorAttributeName] = color;
				a[NSForegroundColorAttributeName] = [self isDarkColor:color] ? [COLOR_CLASS whiteColor] : [COLOR_CLASS blackColor];

				NSString *name = [l.name stringByReplacingOccurrencesOfString:@" " withString:@"\u00a0"];

				[_title appendAttributedString:[[NSAttributedString alloc] initWithString:@"\u00a0" attributes:a]];
				[_title appendAttributedString:[[NSAttributedString alloc] initWithString:name attributes:a]];
				[_title appendAttributedString:[[NSAttributedString alloc] initWithString:@"\u00a0" attributes:a]];
				if(count<sortedLabels.count-1) [_title appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:labelAttributes]];
			}
		}
	}

	return _title;
}

// Much gratitude to the Samback/ColorArt project for the constants used below: https://github.com/Samback/ColorArt
- (BOOL)isDarkColor:(COLOR_CLASS *)color
{
	CGFloat r, g, b, a;
	[color getRed:&r green:&g blue:&b alpha:&a];
	CGFloat lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
	return (lum < 0.5);
}

- (NSMutableAttributedString *)subtitleWithFont:(FONT_CLASS *)font
{
	NSMutableAttributedString *_subtitle = [[NSMutableAttributedString alloc] init];

	NSMutableParagraphStyle *p = [[NSMutableParagraphStyle alloc] init];
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
	p.lineHeightMultiple = 1.3;
#endif

	NSDictionary *lightSubtitle = @{ NSForegroundColorAttributeName: [COLOR_CLASS grayColor],
									 NSFontAttributeName:font,
									 NSParagraphStyleAttributeName: p};

	NSAttributedString *separator;
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
	separator = [[NSAttributedString alloc] initWithString:@"\n"
												attributes:lightSubtitle];
#else
	separator = [[NSAttributedString alloc] initWithString:@"   "
												attributes:lightSubtitle];
#endif

	if(settings.showReposInName)
	{
		NSMutableDictionary *darkSubtitle = [lightSubtitle mutableCopy];
		darkSubtitle[NSForegroundColorAttributeName] = [COLOR_CLASS darkGrayColor];
		[_subtitle appendAttributedString:[[NSAttributedString alloc] initWithString:self.repoName
																		  attributes:darkSubtitle]];
		[_subtitle appendAttributedString:separator];
	}

	if(self.userLogin.length)
	{
		[_subtitle appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"@%@", self.userLogin]
																		  attributes:lightSubtitle]];
		[_subtitle appendAttributedString:separator];
	}

	if(settings.showCreatedInsteadOfUpdated)
		[_subtitle appendAttributedString:[[NSAttributedString alloc] initWithString:[itemDateFormatter stringFromDate:self.createdAt]
																		  attributes:lightSubtitle]];
	else
		[_subtitle appendAttributedString:[[NSAttributedString alloc] initWithString:[itemDateFormatter stringFromDate:self.updatedAt]
																		  attributes:lightSubtitle]];

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
	if(!self.mergeable.boolValue)
	{
		[_subtitle appendAttributedString:separator];
		NSMutableDictionary *redSubtitle = [lightSubtitle mutableCopy];
		redSubtitle[NSForegroundColorAttributeName] = [COLOR_CLASS redColor];
		[_subtitle appendAttributedString:[[NSAttributedString alloc] initWithString:@"Cannot be merged!"
																		  attributes:redSubtitle]];
	}
#endif

	return _subtitle;
}

+ (NSFetchRequest *)requestForPullRequestsWithFilter:(NSString *)filter
{
	NSFetchRequest *f = [NSFetchRequest fetchRequestWithEntityName:@"PullRequest"];
	f.returnsObjectsAsFaults = NO;

	NSMutableArray *predicateSegments = [NSMutableArray arrayWithObject:@"(sectionIndex > 0)"];

	if(filter.length)
	{
		if(settings.includeReposInFilter)
			[predicateSegments addObject:[NSString stringWithFormat:@"(title contains[cd] '%@' or userLogin contains[cd] '%@' or repoName contains[cd] '%@')",filter,filter,filter]];
		else
			[predicateSegments addObject:[NSString stringWithFormat:@"(title contains[cd] '%@' or userLogin contains[cd] '%@')",filter,filter]];
	}

	if(settings.shouldHideUncommentedRequests)
	{
		[predicateSegments addObject:@"(unreadComments > 0)"];
	}

	if(predicateSegments.count) f.predicate = [NSPredicate predicateWithFormat:[predicateSegments componentsJoinedByString:@" and "]];

	NSMutableArray *sortDescriptors = [NSMutableArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"sectionIndex" ascending:YES]];

	if(settings.groupByRepo)
	{
		[sortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@"repoName" ascending:YES selector:@selector(caseInsensitiveCompare:)]];
	}

	BOOL ascending = !settings.sortDescending;
	NSString *fieldName = settings.sortField;
	if([fieldName isEqualToString:@"title"])
	{
		[sortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:fieldName ascending:ascending selector:@selector(caseInsensitiveCompare:)]];
	}
	else if(fieldName.length)
	{
		[sortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:fieldName ascending:ascending]];
	}

	f.sortDescriptors = sortDescriptors;
	return f;
}

+ (NSArray *)allMergedRequestsInMoc:(NSManagedObjectContext *)moc
{
	NSFetchRequest *f = [NSFetchRequest fetchRequestWithEntityName:@"PullRequest"];
	f.returnsObjectsAsFaults = NO;
	f.predicate = [NSPredicate predicateWithFormat:@"condition == %d",kPullRequestConditionMerged];
	return [moc executeFetchRequest:f error:nil];
}

+ (NSArray *)allClosedRequestsInMoc:(NSManagedObjectContext *)moc
{
	NSFetchRequest *f = [NSFetchRequest fetchRequestWithEntityName:@"PullRequest"];
	f.returnsObjectsAsFaults = NO;
	f.predicate = [NSPredicate predicateWithFormat:@"condition == %d",kPullRequestConditionClosed];
	return [moc executeFetchRequest:f error:nil];
}

+ (NSUInteger)countOpenRequestsInMoc:(NSManagedObjectContext *)moc
{
	NSFetchRequest *f = [NSFetchRequest fetchRequestWithEntityName:@"PullRequest"];
	f.predicate = [NSPredicate predicateWithFormat:@"condition == %d or condition == nil",kPullRequestConditionOpen];
	return [moc countForFetchRequest:f error:nil];
}

+ (NSInteger)badgeCountInMoc:(NSManagedObjectContext *)moc
{
	NSFetchRequest *f = [PullRequest requestForPullRequestsWithFilter:nil];
	NSArray *allPRs = [moc executeFetchRequest:f error:nil];
	NSInteger count = 0;
	BOOL showCommentsEverywhere = settings.showCommentsEverywhere;
	for(PullRequest *r in allPRs)
	{
		NSInteger sectionIndex = r.sectionIndex.integerValue;
		if(showCommentsEverywhere ||
		   sectionIndex==kPullRequestSectionMine ||
		   sectionIndex==kPullRequestSectionParticipated)
		{
			count += r.unreadComments.integerValue;
		}
	}
	return count;
}

- (void)catchUpWithComments
{
	for(PRComment *c in self.comments)
	{
		NSDate *commentCreation = c.createdAt;
		if(!self.latestReadCommentDate || [self.latestReadCommentDate compare:commentCreation]==NSOrderedAscending)
		{
			self.latestReadCommentDate = commentCreation;
		}
	}
	[self postProcess];
}

- (BOOL)isMine
{
	if(self.assignedToMe.boolValue && settings.moveAssignedPrsToMySection) return YES;
	return [self.userId isEqualToNumber:self.apiServer.userId];
}

- (BOOL)commentedByMe
{
	for(PRComment *c in self.comments)
		if(c.isMine)
			return YES;
	return NO;

}

- (NSArray *)displayedStatuses
{
	NSFetchRequest *f = [NSFetchRequest fetchRequestWithEntityName:@"PRStatus"];
	f.returnsObjectsAsFaults = NO;

	NSInteger mode = settings.statusFilteringMode;
	if(mode==kStatusFilterAll)
	{
		f.predicate = [NSPredicate predicateWithFormat:@"pullRequest == %@", self];
	}
	else
	{
		NSArray *terms = settings.statusFilteringTerms;
		if(terms.count)
		{
			NSMutableArray *ors = [NSMutableArray arrayWithCapacity:terms.count];
			for(NSString *term in terms)
			{
				[ors addObject:[NSString stringWithFormat:@"descriptionText contains[cd] '%@'", term]];
			}

			if(mode==kStatusFilterInclude)
			{
				f.predicate = [NSPredicate predicateWithFormat:@"pullRequest == %@ and (%@)", self, [ors componentsJoinedByString:@" or "]];
			}
			else
			{
				f.predicate = [NSPredicate predicateWithFormat:@"pullRequest == %@ and (not (%@))", self, [ors componentsJoinedByString:@" or "]];
			}
		}
		else
		{
			f.predicate = [NSPredicate predicateWithFormat:@"pullRequest == %@", self];
		}
	}

	f.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:NO]];
	NSMutableArray *result = [NSMutableArray array];
	NSMutableSet *targetUrls = [NSMutableSet set];
	NSMutableSet *descriptions = [NSMutableSet set];
	for(PRStatus *s in [self.managedObjectContext executeFetchRequest:f error:nil])
	{
		NSString *targetUrl = s.targetUrl;
		if(!targetUrl) targetUrl = @"";

		NSString *desc = s.descriptionText;
		if(!desc) desc = @"(No status description)";

		if(![descriptions containsObject:desc])
		{
			[descriptions addObject:desc];
			if(![targetUrls containsObject:targetUrl])
			{
				[targetUrls addObject:targetUrl];
				[result addObject:s];
			}
		}
	}
	return result;
}

- (NSString *)labelsLink
{
	return [self.issueUrl stringByAppendingPathComponent:@"labels"];
}

- (NSString *)urlForOpening
{
	if (self.unreadComments.integerValue != 0 && settings.openPrAtFirstUnreadComment)
	{
		NSFetchRequest *f = [NSFetchRequest fetchRequestWithEntityName:@"PRComment"];
		f.returnsObjectsAsFaults = NO;
		f.fetchLimit = 1;
		f.predicate = [self predicateForOthersCommentsSinceDate:self.latestReadCommentDate];
		f.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:YES]];
		NSArray *ret = [self.managedObjectContext executeFetchRequest:f error:nil];
		if (ret.count > 0)
		{
			PRComment *comment = (PRComment *)ret[0];
			return comment.webUrl;
		}
	}
	return self.webUrl;
}

- (NSPredicate *)predicateForOthersCommentsSinceDate:(NSDate *)date
{
	if(date)
	{
		return [NSPredicate predicateWithFormat:@"userId != %lld and pullRequest == %@ and createdAt > %@",
				self.apiServer.userId.longLongValue,
				self,
				date];
	}
	else
	{
		return [NSPredicate predicateWithFormat:@"userId != %lld and pullRequest == %@",
				self.apiServer.userId.longLongValue,
				self];
	}
}

@end
