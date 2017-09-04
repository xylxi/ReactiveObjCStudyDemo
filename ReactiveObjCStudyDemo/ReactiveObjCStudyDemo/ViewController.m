//
//  ViewController.m
//  ReactiveObjCStudyDemo
//
//  Created by DMW_W on 2017/7/27.
//  Copyright © 2017年 XYLXI. All rights reserved.
//

#import "ViewController.h"
#import <ReactiveObjC.h>
#import <AFNetworking.h>

@interface ViewController ()

@property (nonatomic , strong) RACSignal *signal;
@property (nonatomic , strong) RACDisposable *d;
@property (nonatomic , strong) RACSubject *s;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    RACCommand *command = [[RACCommand alloc] initWithSignalBlock:^RACSignal * _Nonnull(id  _Nullable input) {
        return [RACSignal createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {
            NSURL *url = [NSURL URLWithString:@"http://localhost:3000"];
            AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc] initWithBaseURL:url];
            NSString *URLString = [NSString stringWithFormat:@"/api/products/%@", input ?: @1];
            NSURLSessionDataTask *task = [manager GET:URLString parameters:nil progress:nil
                                              success:^(NSURLSessionDataTask * _Nonnull task, id _Nullable responseObject) {
                                                  [subscriber sendNext:responseObject];
                                                  [subscriber sendCompleted];
                                              } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                                                  [subscriber sendError:error];
                                              }];
            return [RACDisposable disposableWithBlock:^{
                [task cancel];
            }];
        }];
    }];
    
}

@end
