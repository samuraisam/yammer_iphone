#import "NetworkList.h"
#import "MainTabBar.h"
#import "LocalStorage.h"
#import "NSString+SBJSON.h"
#import "YammerAppDelegate.h"

@interface NetworkListItem : TTTableTextItem {
  NSMutableDictionary* _network;
}
@property (nonatomic, retain) NSMutableDictionary* network;

+ (NetworkListItem*)itemWithNetwork:(NSMutableDictionary*)network;
@end

@implementation NetworkListItem

@synthesize network = _network;
+ (NetworkListItem*)itemWithNetwork:(NSMutableDictionary*)network {
  NetworkListItem* nli = [NetworkListItem itemWithText:@""];
  nli.network = network;
  return nli;
}
- (void)dealloc {
  TT_RELEASE_SAFELY(_network);
  [super dealloc];
}

@end

@interface NetworkListCell : TTTableTextItemCell {
  UILabel* _leftSide;
  TTLabel* _badge;
}
@property (nonatomic, retain) UILabel *leftSide;
@property (nonatomic, retain) TTLabel *badge;

@end

@implementation NetworkListCell

@synthesize leftSide = _leftSide, badge = _badge;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString*)identifier {
  if (self = [super initWithStyle:style reuseIdentifier:identifier]) {    
    _leftSide = [[UILabel alloc] initWithFrame:CGRectMake(10, 7, 210, 30)];
    _leftSide.text = @"Testing";
    _leftSide.font = [UIFont boldSystemFontOfSize:18];
    
    _badge = [[TTLabel alloc] initWithFrame:CGRectMake(225, 8, 25, 25)];
    _badge.style = TTSTYLE(largeBadge);
    _badge.backgroundColor = [UIColor clearColor];
    _badge.userInteractionEnabled = NO;
    _badge.text = @"60+";
    
    [self.contentView addSubview:_leftSide];
    [self.contentView addSubview:_badge];
  }
  return self;
}

- (void)dealloc {
  TT_RELEASE_SAFELY(_leftSide);
  [super dealloc];
}

- (void)setObject:(id)object {
  if (_item != object) {
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    NetworkListItem* nli = (NetworkListItem*)object;
    _leftSide.text = [nli.network objectForKey:@"name"];
    
    int count = [[nli.network objectForKey:@"unseen_message_count"] intValue];
        
    if (count == 0)
      _badge.hidden = YES;
    else {
      _badge.text = [NetworkList badgeFromIntToString:count];
      [_badge sizeToFit];
      _badge.hidden = NO;
    }
  }
}

+ (CGFloat)tableView:(UITableView*)tableView rowHeightForObject:(id)object {
  return 45.0;
}

@end

@interface NetworkListDataSource : TTSectionedDataSource;
@end

@implementation NetworkListDataSource
- (Class)tableView:(UITableView*)tableView cellClassForObject:(id)object {
  if ([object isKindOfClass:[NetworkListItem class]])
    return [NetworkListCell class];
  return [super tableView:tableView cellClassForObject:object];
}
@end

@interface NetworkListDelegate : TTTableViewVarHeightDelegate;
@end

@implementation NetworkListDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {  
  [tableView deselectRowAtIndexPath:indexPath animated:YES];

  NetworkList* networkList = (NetworkList*)[_controller.navigationController visibleViewController];
  NetworkListItem* nli = (NetworkListItem*)[_controller.dataSource tableView:tableView objectForRowAtIndexPath:indexPath];
  
  [networkList madeSelection:nli.network];
}

@end



@implementation NetworkList

- (id)init {
  if (self = [super init]) {
    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"title.png"]];
    self.navigationBarTintColor = [MainTabBar yammerGray];
    self.variableHeightRows = YES;
    
    _tableViewStyle = UITableViewStyleGrouped;    
    [self createNetworkListDataSource];
  }  
  return self;
}

- (void)createNetworkListDataSource {
  NSMutableArray* sections = [NSMutableArray array];
  NSMutableArray* items = [NSMutableArray array];
  NSMutableArray* section = [NSMutableArray array];
  
  NSMutableArray* networks = [[LocalStorage getFile:NETWORKS_CURRENT] JSONValue];
  
  for (NSMutableDictionary *network in networks) 
    [section addObject:[NetworkListItem itemWithNetwork:network]];
  
  [sections addObject:@"Select a network:"];
  [items addObject:section];
  self.dataSource = [[NetworkListDataSource alloc] initWithItems:items sections:sections]; 
}

- (id<UITableViewDelegate>)createDelegate {
  return [[NetworkListDelegate alloc] initWithController:self];
}

- (void)madeSelection:(NSMutableDictionary*)network {
  
  long network_id = [[network objectForKey:@"id"] longValue];
  YammerAppDelegate *yammer = (YammerAppDelegate *)[[UIApplication sharedApplication] delegate];
  
  if ([yammer.network_id longValue] == network_id) {
    TTNavigator* navigator = [TTNavigator navigator];
    [navigator removeAllViewControllers];
    [navigator openURL:@"yammer://tabs" animated:YES];
    return;
  }
  
  self.dataSource = nil;
  [self showModel:YES];
  [NSThread detachNewThreadSelector:@selector(doTheSwitch:) toTarget:self withObject:network];
}

- (void)doShowModel {
  [self showModel:YES];
}

- (void)doTheSwitch:(NSMutableDictionary*)network {
  NSAutoreleasePool *autoreleasepool = [[NSAutoreleasePool alloc] init];
  
  long network_id = [[network objectForKey:@"id"] longValue];
  YammerAppDelegate *yammer = (YammerAppDelegate *)[[UIApplication sharedApplication] delegate];
  
  if ([yammer.network_id longValue] != network_id) {
    if ([LocalStorage getFile:TOKENS] == nil) {
      
    }
  }
  
  sleep(1);
  
  if (true) {
    [self createNetworkListDataSource];
    [self performSelectorOnMainThread:@selector(doShowModel) withObject:nil waitUntilDone:NO];
  } else {  
    TTNavigator* navigator = [TTNavigator navigator];
    [navigator removeAllViewControllers];
    [navigator openURL:@"yammer://tabs" animated:YES];
  }
  [autoreleasepool release];
}  

+ (NSString*)badgeFromIntToString:(int)count {
  if (count > 0) {
    if (count > 60)
      return @"60+";
    else
      return [NSString stringWithFormat:@"%d", count];   
  }
  return nil;
}


@end