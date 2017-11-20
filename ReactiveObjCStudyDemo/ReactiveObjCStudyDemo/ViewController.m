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
@property (weak, nonatomic) IBOutlet UITextField *textfield;
@property (weak, nonatomic) IBOutlet UITextField *textfieldTwo;

@property (nonatomic , strong) NSString *text;
@property (nonatomic , strong) RACChannelTerminal *integerChannel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[[RACSignal createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {
        [subscriber sendNext:[RACTuple tupleWithObjects:@1, nil]];
        [subscriber sendNext:[RACTuple tupleWithObjects:@2, nil]];
        return nil;
    }] reduceEach:^id(NSNumber *num1){
        return @([num1 intValue] * 10);
    }] subscribeNext:^(id  _Nullable x) {
        NSLog(@"%@",x);
    }] ;
    
}

@end
