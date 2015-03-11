#import "CalypsoPostsViewController.h"

#import <WordPress-iOS-Shared/WPStyleGuide.h>

#import "Blog.h"
#import "ContextManager.h"
#import "WPLegacyEditPostViewController.h"
#import "Post.h"
#import "PostService.h"
#import "PostCardTableViewCell.h"
#import "UIView+Subviews.h"
#import "WordPressAppDelegate.h"
#import "WPNoResultsView+AnimatedBox.h"
#import "WPPostViewController.h"
#import "WPTableImageSource.h"
#import "WPTableViewHandler.h"
#import "WordPress-Swift.h"

static NSString * const TableViewCellIdentifier = @"PostCardTableViewCell";
static const CGFloat PostCardEstimatedRowHeight = 100.0;
static const NSInteger PostsLoadMoreThreshold = 4;
static const NSTimeInterval PostsControllerRefreshTimeout = 300; // 5 minutes

@interface CalypsoPostsViewController () <WPTableViewHandlerDelegate, WPContentSyncHelperDelegate>

@property (nonatomic, strong) WPTableViewHandler *tableViewHandler;
@property (nonatomic, strong) WPContentSyncHelper *syncHelper;
@property (nonatomic, strong) PostCardTableViewCell *cellForLayout;
@property (nonatomic, strong) WPTableImageSource *featuredImageSource;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIActivityIndicatorView *activityFooter;
@property (nonatomic, strong) WPNoResultsView *noResultsView;

- (IBAction)refresh:(id)sender;

@end

@implementation CalypsoPostsViewController

#pragma mark - Lifecycle Methods

+ (instancetype)controllerWithBlog:(Blog *)blog
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Calypso" bundle:[NSBundle mainBundle]];
    CalypsoPostsViewController *controller = [storyboard instantiateViewControllerWithIdentifier:@"CalypsoPostsViewController"];
    controller.blog = blog;
    return controller;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = NSLocalizedString(@"Posts", @"Tile of the screen showing the list of posts for a blog.");

    [self configureCellForLayout];
    [self configureTableView];
    [self configureTableViewHandler];
    [self configureSyncHelper];

    [WPStyleGuide configureColorsForView:self.view andTableView:self.tableView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self automaticallySyncIfAppropriate];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark - Configuration

- (void)configureCellForLayout
{
    self.cellForLayout = (PostCardTableViewCell *)[[[NSBundle mainBundle] loadNibNamed:@"PostTableViewCell" owner:nil options:nil] firstObject];
}

- (void)configureTableView
{
    self.tableView.accessibilityIdentifier = @"PostsTable";
    self.tableView.isAccessibilityElement = YES;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    // Register the cells
    UINib *postCardCellNib = [UINib nibWithNibName:@"PostTableViewCell" bundle:[NSBundle mainBundle]];
    [self.tableView registerNib:postCardCellNib forCellReuseIdentifier:TableViewCellIdentifier];
}

- (void)configureTableViewHandler
{
    self.tableViewHandler = [[WPTableViewHandler alloc] initWithTableView:self.tableView];
    self.tableViewHandler.cacheRowHeights = YES;
    self.tableViewHandler.delegate = self;
}

- (void)configureSyncHelper
{
    self.syncHelper = [[WPContentSyncHelper alloc] init];
    self.syncHelper.delegate = self;
}


- (void)configureNoResultsView
{
    if (!self.isViewLoaded) {
        return;
    }

    if (!self.noResultsView) {
        self.noResultsView = [[WPNoResultsView alloc] init];
    }

    if ([self.tableViewHandler.resultsController.fetchedObjects count] > 0) {
        [self.noResultsView removeFromSuperview];
        return;
    }

    // Refresh the NoResultsView Properties
    self.noResultsView.titleText        = self.noResultsTitleText;
    self.noResultsView.messageText      = self.noResultsMessageText;
    self.noResultsView.accessoryView    = self.noResultsAccessoryView;

    // Only add and animate no results view if it isn't already
    // in the table view
    if (![self.noResultsView isDescendantOfView:self.tableView]) {
        [self.tableView addSubviewWithFadeAnimation:self.noResultsView];
    } else {
        [self.noResultsView centerInSuperview];
    }

    [self.tableView sendSubviewToBack:self.noResultsView];
}

- (NSString *)noResultsTitleText
{
    return NSLocalizedString(@"You haven't created any posts yet", @"Displayed when the user pulls up the posts view and they have no posts");
}

- (NSString *)noResultsMessageText {
    return NSLocalizedString(@"Would you like to create your first post?",  @"Displayed when the user pulls up the posts view and they have no posts");
}

- (UIView *)noResultsAccessoryView {
    return [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"penandink"]];
}

- (NSString *)noResultsButtonText
{
    return NSLocalizedString(@"Create post", @"Button title, encourages users to create their first post on their blog.");
}

- (void)didTapNoResultsView:(WPNoResultsView *)noResultsView
{
    [self showAddPostView:nil];
}


#pragma mark - Actions

- (IBAction)refresh:(id)sender
{
    [self syncItemsWithUserInteraction:YES];
}

- (IBAction)showAddPostView:(id)sender
{
// TODO: Flag we're adding a new post

    UINavigationController *navController;

    if ([WPPostViewController isNewEditorEnabled]) {
        WPPostViewController *postViewController = [[WPPostViewController alloc] initWithDraftForBlog:self.blog];
        navController = [[UINavigationController alloc] initWithRootViewController:postViewController];
        navController.restorationIdentifier = WPEditorNavigationRestorationID;
        navController.restorationClass = [WPPostViewController class];
    } else {
        WPLegacyEditPostViewController *editPostViewController = [[WPLegacyEditPostViewController alloc] initWithDraftForLastUsedBlog];
        navController = [[UINavigationController alloc] initWithRootViewController:editPostViewController];
        navController.restorationIdentifier = WPLegacyEditorNavigationRestorationID;
        navController.restorationClass = [WPLegacyEditPostViewController class];
    }

    [navController setToolbarHidden:NO]; // Fixes incorrect toolbar animation.
    navController.modalPresentationStyle = UIModalPresentationFullScreen;

    [self presentViewController:navController animated:YES completion:nil];

    [WPAnalytics track:WPAnalyticsStatEditorCreatedPost withProperties:@{ @"tap_source": @"posts_view" }];
}

#pragma mark - Syncing

- (void)automaticallySyncIfAppropriate
{
    // Only automatically refresh if the view is loaded and visible on the screen
    if (self.isViewLoaded == NO || self.view.window == nil) {
        DDLogVerbose(@"View is not visible and will not check for auto refresh.");
        return;
    }

    // Do not start auto-sync if connection is down
    WordPressAppDelegate *appDelegate = [WordPressAppDelegate sharedWordPressApplicationDelegate];
    if (appDelegate.connectionAvailable == NO) {
        return;
    }

    NSDate *lastSynced = self.blog.lastPostsSync;
    if (lastSynced == nil || ABS([lastSynced timeIntervalSinceNow]) > PostsControllerRefreshTimeout) {
        // Update in the background
        [self syncItemsWithUserInteraction:NO];
    }
}

- (void)syncItemsWithUserInteraction:(BOOL)userInteraction
{
    [self configureNoResultsView];
    [self.syncHelper syncContentWithUserInteraction:userInteraction];
}



#pragma mark - Sync Helper Delegate Methods

- (void)syncHelper:(WPContentSyncHelper *)syncHelper syncContentWithUserInteraction:(BOOL)userInteraction success:(void (^)(NSInteger, BOOL))success failure:(void (^)(NSError *))failure
{
    PostService *postService = [[PostService alloc] initWithManagedObjectContext:[self managedObjectContext]];
    [postService syncPostsOfType:PostServiceTypePost forBlog:self.blog success:^{
        if  (success) {
//TODO:
        }
    } failure:^(NSError *error) {
        if (failure) {
            failure(error);
        }
    }];
}

- (void)syncHelper:(WPContentSyncHelper *)syncHelper syncMoreWithSuccess:(void (^)(NSInteger, BOOL))success failure:(void (^)(NSError *))failure
{
    PostService *postService = [[PostService alloc] initWithManagedObjectContext:[self managedObjectContext]];
    [postService loadMorePostsOfType:PostServiceTypePost forBlog:self.blog success:^{
        if (success) {
//TODO:
        }
    } failure:^(NSError *error) {
        if (failure) {
            failure(error);
        }
    }];
}

- (void)syncContentEnded
{
    [self.refreshControl endRefreshing];
    [self.activityFooter stopAnimating];

    [self.noResultsView removeFromSuperview];
    if ([[self.tableViewHandler.resultsController fetchedObjects] count] == 0) {
        // This is a special case.  Core data can be a bit slow about notifying
        // NSFetchedResultsController delegates about changes to the fetched results.
        // To compensate, call configureNoResultsView after a short delay.
        // It will be redisplayed if necessary.
        [self performSelector:@selector(configureNoResultsView) withObject:self afterDelay:0.1];
    }
}


#pragma mark - TableView Handler Delegate Methods

- (NSManagedObjectContext *)managedObjectContext
{
    return [[ContextManager sharedInstance] mainContext];
}

- (NSFetchRequest *)fetchRequest
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass([Post class])];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"(blog = %@) && (original = nil)", self.blog];
    NSSortDescriptor *sortDescriptorLocal = [NSSortDescriptor sortDescriptorWithKey:@"remoteStatusNumber" ascending:YES];
    NSSortDescriptor *sortDescriptorDate = [NSSortDescriptor sortDescriptorWithKey:@"date_created_gmt" ascending:NO];
    fetchRequest.sortDescriptors = @[sortDescriptorLocal, sortDescriptorDate];
    fetchRequest.fetchBatchSize = 10;
    return fetchRequest;
}


#pragma mark - Table View Handling

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return PostCardEstimatedRowHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat width = [UIDevice isPad] ? WPTableViewFixedWidth : CGRectGetWidth(self.tableView.bounds);
    return [self tableView:tableView heightForRowAtIndexPath:indexPath forWidth:width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath forWidth:(CGFloat)width
{
    [self configureCell:self.cellForLayout atIndexPath:indexPath];
    CGSize size = [self.cellForLayout sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
    CGFloat height = ceil(size.height);
    return height;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
// TODO: Preload images (maybe?)

    // Are we approaching the end of the table?
    if ((indexPath.section + 1 == self.tableView.numberOfSections) &&
        (indexPath.row + PostsLoadMoreThreshold >= [self.tableView numberOfRowsInSection:indexPath.section])) {

        // Only 3 rows till the end of table
        if (self.syncHelper.hasMoreContent) {
            [self.syncHelper syncMoreContent];
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    AbstractPost *post = [self.tableViewHandler.resultsController objectAtIndexPath:indexPath];
    if (post.remoteStatus == AbstractPostRemoteStatusPushing) {
        // Don't allow editing while pushing changes
        return;
    }

    [self viewPost:post];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:TableViewCellIdentifier];

    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    PostCardTableViewCell *postCell = (PostCardTableViewCell *)cell;
    Post *post = (Post *)[self.tableViewHandler.resultsController objectAtIndexPath:indexPath];
    [postCell configureCell:post];
}


#pragma mark - Instance Methods

- (void)viewPost:(AbstractPost *)apost
{
    if ([WPPostViewController isNewEditorEnabled]) {
        WPPostViewController *postViewController = [[WPPostViewController alloc] initWithPost:apost
                                                                                         mode:kWPPostViewControllerModePreview];
        postViewController.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:postViewController animated:YES];
    } else {
        // In legacy mode, view means edit
        WPLegacyEditPostViewController *editPostViewController = [[WPLegacyEditPostViewController alloc] initWithPost:apost];
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:editPostViewController];
        [navController setToolbarHidden:NO]; // Fixes incorrect toolbar animation.
        navController.modalPresentationStyle = UIModalPresentationFullScreen;
        navController.restorationIdentifier = WPLegacyEditorNavigationRestorationID;
        navController.restorationClass = [WPLegacyEditPostViewController class];

        [self presentViewController:navController animated:YES completion:nil];
    }
}


@end
