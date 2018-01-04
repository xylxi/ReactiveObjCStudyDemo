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

@property (nonatomic , strong) RACCommand *racComand;


@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (nonatomic , copy) NSString *string;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}


- (IBAction)click:(id)sender {
    NSLog(@"string = %@",self.string);
}

@end





