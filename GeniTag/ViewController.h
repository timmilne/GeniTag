//
//  ViewController.h
//  GeniTag
//
//  Created by Tim.Milne on 10/19/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ViewController : NSViewController
@property (weak) IBOutlet NSTextField *inputFileFld;
@property (weak) IBOutlet NSTextField *numberEachFld;
@property (weak) IBOutlet NSButton *generateBtn;
@property (weak) IBOutlet NSTextField *statusFld;
@property (weak) IBOutlet NSImageView *successImg;
@property (weak) IBOutlet NSImageView *failImg;

@end

