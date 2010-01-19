#import "DirectoryList.h"
#import "APIGateway.h"
#import "NSString+SBJSON.h"
#import "LocalStorage.h"
#import "FeedCache.h"
#import "MainTabBar.h"
#import "UserProfile.h"
#import "SpinnerWithTextCell.h"
#import "DirectorySearchDataSource.h"

@interface DirectoryListDelegate : TTTableViewVarHeightDelegate;
@end

@implementation DirectoryListDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {  
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  
  NSObject* object = [_controller.dataSource tableView:tableView objectForRowAtIndexPath:indexPath];
    
  if ([object isKindOfClass:[SpinnerWithTextItem class]]) {
    DirectoryList* dl = (DirectoryList*)_controller;
    [dl refreshDirectory];
    return;
  }
  
  if ([object isKindOfClass:[TTTableMoreButton class]]) {
    TTTableMoreButton *more = (TTTableMoreButton *)object;
    more.isLoading = YES;
    TTTableMoreButtonCell* cell = (TTTableMoreButtonCell*)[tableView cellForRowAtIndexPath:indexPath];
    cell.animating = YES;
    
    [NSThread detachNewThreadSelector:@selector(fetchMore) toTarget:_controller withObject:nil];    
  } else {
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
  }
}

@end

@implementation DirectoryList

@synthesize page;
@synthesize lastString = _lastString, currentString = _currentString, searchThread = _searchThread;

- (id)init {
  if (self = [super init]) {
    self.variableHeightRows = YES;

    self.page = 1;
    self.navigationBarTintColor = [MainTabBar yammerGray];

    _lastString = @"";
    _currentString = nil;
    _searchThread = nil;
    
    //SpinnerListDataSource* list = [[[SpinnerListDataSource alloc] init] autorelease];
    //[list.items addObject:[SpinnerWithTextItem item]];
    //self.dataSource = [[TTListDataSource alloc] init];
      
    [NSThread detachNewThreadSelector:@selector(loadUsers:) toTarget:self withObject:@"silent"];  
  }  
  return self;
}

- (void)resetForNetworkSwitch {
  [LocalStorage removeFile:DIRECTORY_CACHE];
  //SpinnerListDataSource* list = [[[SpinnerListDataSource alloc] init] autorelease];
  //[list.items addObject:[SpinnerWithTextItem item]];
  self.dataSource = nil;
  
  [NSThread detachNewThreadSelector:@selector(loadUsers:) toTarget:self withObject:@"silent"];
}

- (void)loadView {
  [super loadView];
  
  UISearchBar* searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 40)];
  searchBar.delegate = self;
  searchBar.showsCancelButton = YES;
  self.tableView.tableHeaderView = searchBar;
  
}

- (void)typeAheadThreadUpdate {
  NSLog(@"current %@", self.currentString);
  NSLog(@"last %@", self.lastString);
  
  if (self.currentString != nil && ![self.currentString isEqualToString:self.lastString]) {
    NSLog(@"!!!!!change");
    if (self.searchThread != nil) {
      [self.searchThread cancel];
      TT_RELEASE_SAFELY(_searchThread);
    }
    
    
    NSString* trimmed = [self.currentString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmed length] > 0) {      
      self.searchThread = [[NSThread alloc] initWithTarget:self selector:@selector(doSearch) object:trimmed];
      [self.searchThread start];
    }
  }
  
  if (self.currentString != nil)
    self.lastString = [NSString stringWithString:self.currentString];
  
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
  if (self.currentString == nil)
    self.dataSource = [[TTListDataSource alloc] init];
  
  self.currentString = [NSString stringWithString:searchText];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
  searchBar.text = @"";
  [searchBar resignFirstResponder];
  [NSThread detachNewThreadSelector:@selector(loadUsers:) toTarget:self withObject:@"silent"];
  _lastString = @"";
  _currentString = nil;
}

- (void)doSearch:(NSString*)trimmed {
  NSAutoreleasePool *autoreleasepool = [[NSAutoreleasePool alloc] init];
  NSMutableDictionary* results = [APIGateway autocomplete:trimmed];
  NSArray* users = [results objectForKey:@"users"];
  NSLog([users description]);
  [autoreleasepool release];
}


- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
}


- (void)refreshDirectory {
  //SpinnerListDataSource* list = [[[SpinnerListDataSource alloc] init] autorelease];
  //[list.items addObject:[SpinnerWithTextItem itemWithYammer]];
  self.dataSource = nil;
  
  [NSThread detachNewThreadSelector:@selector(loadUsers:) toTarget:self withObject:nil];  
}

- (void)loadUsers:(NSString *)style {
  NSAutoreleasePool *autoreleasepool = [[NSAutoreleasePool alloc] init];
  
  NSMutableArray *list;
  NSString *cached = [LocalStorage getFile:DIRECTORY_CACHE];
  if (cached && style != nil)
    list = (NSMutableArray *)[cached JSONValue];
  else {
    list = [APIGateway users:1 style:style];
    if (list == nil && cached)
      list = (NSMutableArray *)[cached JSONValue];
  }

  TTListDataSource* source = [[TTListDataSource alloc] init];

  //SpinnerListDataSource* source = [[[SpinnerListDataSource alloc] init] autorelease];
  //[source.items addObject:[SpinnerWithTextItem itemWithText:[FeedCache niceDate:[LocalStorage getFileDate:DIRECTORY_CACHE]]]];
  [self handleUsers:list source:source];
  
  if ([list count] == 50)
    [source.items addObject: [TTTableMoreButton itemWithText:@"                       More"]];

  [self performSelectorOnMainThread:@selector(setDataSource:)
                           withObject:source
                        waitUntilDone:YES];
  //self.dataSource = source;
  //[self showModel:YES];
  
  [autoreleasepool release];
}

- (id<UITableViewDelegate>)createDelegate {
  return [[DirectoryListDelegate alloc] initWithController:self];
}

- (void)handleUsers:(NSArray*)list source:(TTListDataSource*)source {
  for (int i=0; i < [list count]; i++) {
    NSMutableDictionary *dict = [list objectAtIndex:i];
    
    TTTableImageItem* item = [TTTableImageItem itemWithText:[UserProfile safeName:dict] imageURL:[dict objectForKey:@"mugshot_url"] 
                                               defaultImage:[UIImage imageNamed:@"no_photo_small.png"] 
                                                URL:[NSString stringWithFormat:@"yammer://user?id=%@", [dict objectForKey:@"id"]]];
    [source.items addObject:item];
  }
}

- (void)fetchMore {
  NSAutoreleasePool *autoreleasepool = [[NSAutoreleasePool alloc] init];
  NSMutableArray *users = [APIGateway users:2 style:nil];
  if (users) {
    TTListDataSource* source = (TTListDataSource*)self.dataSource;
    [source.items removeLastObject];
    [self handleUsers:users source:source];
  }
//  [self showModel:YES];
  [self performSelectorOnMainThread:@selector(doShowModel)
                         withObject:nil
                      waitUntilDone:YES];
  [autoreleasepool release];
}

- (void)doShowModel {
  [self showModel:YES];
}

- (void)dealloc {
  [super dealloc];
  TT_RELEASE_SAFELY(_lastString);
  TT_RELEASE_SAFELY(_currentString);
  TT_RELEASE_SAFELY(_searchThread);
}

- (void)textField:(TTSearchTextField*)textField didSelectObject:(id)object {
}

@end
