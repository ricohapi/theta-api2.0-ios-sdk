/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import "HttpStatusTimer.h"

/**
 * Class for periodic monitoring of command status
 */
@interface HttpStatusTimer()
{
    NSMutableURLRequest *_request;
    NSURLSession* _session;
    NSString *_commandId;
    dispatch_semaphore_t _semaphore;
    NSString *_state;
}
@end

@implementation HttpStatusTimer

/**
 * Specified initializer
 * @param request HTTP request
 * @return Instance
 */
- (id)initWithRequest:(NSMutableURLRequest*)request
{
    if ([super init]) {
        _request = request;
    }
    return self;
}

/**
 * Start status monitoring
 * @param command ID of command to be monitored
 * @return Status indicating completion or error
 */
- (NSString*)run:(NSString*)command
{
    // Create and keep HTTP session
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
    _session= [NSURLSession sessionWithConfiguration:config];
    
    _commandId = command;
    
    // Semaphore for synchronization (cannot be entered until signal is called)
    _semaphore = dispatch_semaphore_create(0);
    
    // Create and start timer
    NSTimer *timer = [NSTimer timerWithTimeInterval:0.5f
                                             target:self
                                           selector:@selector(getState:)
                                           userInfo:nil
                                            repeats:YES];
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [runLoop addTimer:timer forMode:NSRunLoopCommonModes];
    [runLoop run];
    
    // Wait until signal is called
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    return _state;
}

/**
 * Delegate called during each set period of time
 * @param timer Timer
 */
- (void)getState:(NSTimer*)timer
{
    // Create JSON data
    NSDictionary *body = @{@"id": _commandId};
    
    // Set the request-body.
    [_request setHTTPBody:[NSJSONSerialization dataWithJSONObject:body options:0 error:nil]];
    
    // Send the url-request.
    NSURLSessionDataTask* task =
    [_session dataTaskWithRequest:_request
               completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                   if (!error) {
                       NSArray* array = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
                       _state = [array valueForKey:@"state"];
                       _fileUri = [array valueForKeyPath:@"results.fileUri"];
                       NSLog(@"result: %@", _state);
                   } else {
                       _state = @"error";
                       NSLog(@"GetStorageInfo: received data is invalid.");
                   }
                   if (![_state isEqualToString:@"inProgress"]) {
                       dispatch_semaphore_signal(_semaphore);
                       
                       // Stop timer
                       [timer invalidate];
                   }
               }];
    [task resume];
}
@end
