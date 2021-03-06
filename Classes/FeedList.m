#import "FeedList.h"
#import "FeedMessageList.h"
#import "APIGateway.h"
#import "LocalStorage.h"
#import "FeedCache.h"
#import "NSString+SBJSON.h"
#import "MainTabBar.h"
#import "SpinnerWithTextCell.h"
#import "FeedDictionary.h"

@interface FeedListDelegate : TTTableViewVarHeightDelegate;
@end

@implementation FeedListDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {  
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  
  NSObject* object = [_controller.dataSource tableView:tableView objectForRowAtIndexPath:indexPath];
  
  if ([object isKindOfClass:[SpinnerWithTextItem class]]) {
    FeedList* fl = (FeedList*)_controller;
    [fl refreshFeeds];
    return;
  }

  if ([object isKindOfClass:[TTTableImageItem class]]) {
    
    TTTableImageItem* item = (TTTableImageItem*)object;
    FeedMessageList *view = [[[FeedMessageList alloc] initWithFeed:[FeedDictionary feedWithDictionary:item.userInfo] refresh:NO compose:YES thread:NO] autorelease];
    [_controller.navigationController pushViewController:view animated:YES];
  }
}

@end

@implementation FeedTableImageItem
@end

@implementation FeedTableImageItemCell
+ (CGFloat)tableView:(UITableView*)tableView rowHeightForObject:(id)object {
  return 45.0;
}
@end

@implementation FeedList

- (id)init {
  if (self = [super init]) {
    self.navigationBarTintColor = [MainTabBar yammerGray];
    self.variableHeightRows = YES;

    SpinnerListDataSource* list = [[[SpinnerListDataSource alloc] init] autorelease];
    [list.items addObject:[SpinnerWithTextItem item]];
    self.dataSource = list;

    [NSThread detachNewThreadSelector:@selector(loadFeeds:) toTarget:self withObject:@"silent"];  
  }  
	return self;
}

- (void)loadView {
  [super loadView];
  
}

- (void)resetForNetworkSwitch {
  SpinnerListDataSource* list = [[[SpinnerListDataSource alloc] init] autorelease];
  [list.items addObject:[SpinnerWithTextItem item]];
  self.dataSource = list;
  
  [NSThread detachNewThreadSelector:@selector(loadFeeds:) toTarget:self withObject:@"silent"];  
}

- (id<UITableViewDelegate>)createDelegate {
  return [[FeedListDelegate alloc] initWithController:self];
}

- (void)loadFeeds:(NSString *)style {
  NSAutoreleasePool *autoreleasepool = [[NSAutoreleasePool alloc] init];

  NSMutableDictionary *dict;
  NSString *cached = [LocalStorage getFile:[APIGateway user_file]];
  if (cached && style != nil)
    dict = (NSMutableDictionary *)[cached JSONValue];
  else {
    dict = [APIGateway usersCurrent:style];
    if (dict == nil && cached)
      dict = (NSMutableDictionary *)[cached JSONValue];  
  }
  
  SpinnerListDataSource* source = [[[SpinnerListDataSource alloc] init] autorelease];
  [source.items addObject:[SpinnerWithTextItem itemWithText:[FeedCache niceDate:[LocalStorage getFileDate:[APIGateway user_file]]]]];
  
  dict = [dict objectForKey:@"web_preferences"];
  NSArray* list = [dict objectForKey:@"home_tabs"];
  for (int i=0; i<[list count]; i++) {
    NSDictionary* tab = [list objectAtIndex:i];
    
    if ([[tab objectForKey:@"url"] hasSuffix:@"/following"] || [[tab objectForKey:@"url"] hasSuffix:@"/received"])
      continue;

    NSString* lock = nil;
    if ([[tab objectForKey:@"private"] intValue] == 1)
      lock = @"bundle://lock.png";

    FeedTableImageItem* item = [FeedTableImageItem itemWithText:[tab objectForKey:@"name"] 
                                                   imageURL:lock
                                               defaultImage:nil URL:@"1"];
    item.userInfo = tab;
    [source.items addObject:item];
  }
  
  self.dataSource = source;
  
  [autoreleasepool release];
}

- (void)refreshFeeds {
  SpinnerListDataSource* list = [[[SpinnerListDataSource alloc] init] autorelease];
  [list.items addObject:[SpinnerWithTextItem itemWithYammer]];
  self.dataSource = list;

  [NSThread detachNewThreadSelector:@selector(loadFeeds:) toTarget:self withObject:nil];  
}

- (void)dealloc {
  [super dealloc];
}


@end
