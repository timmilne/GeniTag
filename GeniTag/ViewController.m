//
//  ViewController.m
//  GeniTag
//
//  Created by Tim.Milne on 10/19/15.
//  Copyright (c) 2015 Tim.Milne. All rights reserved.
//

#import "ViewController.h"
#import <EPCEncoder/EPCEncoder.h> // To encode the input barcode to hex

@interface ViewController ()
{    
    NSURL      *_inputFileURL;
    NSURL      *_outputFileURL;
    int         _startSer;
    int         _numEach;
    EPCEncoder *_encode;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    
    // Disable the generate button until input file loaded
    [_generateBtn setEnabled:FALSE];
    
    // Initiliaze the encoder and converter
    if (_encode == nil) _encode = [EPCEncoder alloc];
    
    // Hide the results images
    [_successImg setHidden:TRUE];
    [_failImg setHidden:TRUE];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (IBAction)OpenBtn:(id)sender {
    NSArray * fileTypes = [NSArray arrayWithObjects:@"csv",nil];
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setAllowedFileTypes:fileTypes];
    
    if ([panel runModal] == NSFileHandlingPanelOKButton) {
        for (NSURL *url in [panel URLs]) {
            _inputFileURL = url;
            [_inputFileFld setStringValue:[_inputFileURL absoluteString]];
            [_generateBtn setEnabled:TRUE];
            [_statusFld setStringValue:@"Ready to encode"];
            [_successImg setHidden:TRUE];
            [_failImg setHidden:TRUE];
            
            NSLog( @"Input File: %@\n", _inputFileURL);
            break;
        }
    }
}

- (IBAction)GenerateBtn:(id)sender {
    // Make sure there is something to do
    if (_inputFileURL == nil) return;
    
    _startSer = (int)[_startingSerialFld integerValue];
    NSLog( @"startSer: %d\n", _startSer);
    
    _numEach = (int)[_numberEachFld integerValue];
    NSLog( @"numEach: %d\n", _numEach);
    
    // Build an output file based on the intput filename and the range
    NSString *fileName = [NSString stringWithFormat:@"GeniTagOutput_%d-%d.csv", _startSer, (_startSer+_numEach-1)];
    _outputFileURL = [[_inputFileURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:fileName];
    
    [_successImg setHidden:TRUE];
    [_failImg setHidden:TRUE];
    
    // Load the input file
    NSError *error;
    NSString *stringFromInputFile = [NSString stringWithContentsOfURL:_inputFileURL
                                                             encoding:NSUTF8StringEncoding
                                                                error:&error];
    NSString *stringForOutputFile = [[NSString alloc] init];

    // Double loop to handle both newlines and carriage returns
    for (NSString *file in [stringFromInputFile componentsSeparatedByString:@"\n"]) {
        for (NSString *line in [file componentsSeparatedByString:@"\r"]) {
            // Skip empties
            if ([line length] == 0) continue;
            
            // Grab the barcode
            NSString *barcode = line;
            NSString *hex;
            
            // Quick length checks, chop to 12 for now (remove leading zeros)
            if (barcode.length == 13) barcode = [barcode substringFromIndex:1];
            if (barcode.length == 14) barcode = [barcode substringFromIndex:2];
            
            // Owned brand, encode DPCI in a GID
            if (barcode.length == 12 && [[barcode substringToIndex:2] isEqualToString:@"49"]) {
                NSString *dpt = [barcode substringWithRange:NSMakeRange(2,3)];
                NSString *cls = [barcode substringWithRange:NSMakeRange(5,2)];
                NSString *itm = [barcode substringWithRange:NSMakeRange(7,4)];
                
                // Start with the barcode
                stringForOutputFile = [stringForOutputFile stringByAppendingString:barcode];
                
                for (int i=0; i<=_numEach; i++){
                    NSString *ser = [NSString stringWithFormat:@"%d", (_startSer+i)];
                    
                    [_encode withDpt:dpt cls:cls itm:itm ser:ser];
                    hex = [_encode gid_hex];
                    
                    // Collect the encoded barcodes
                    stringForOutputFile = [stringForOutputFile stringByAppendingFormat:@",%@", hex];
                    
                    NSLog( @"\nBarcode: %@\nEncoded GID (hex): %@\n", barcode, hex);
                }
            }
            
            // National brand, encode GTIN in an SGTIN
            else if (barcode.length == 12) {
                // Take the gtin and encode a reference
                NSString *gtin = barcode;
                
                // Start with the barcode
                stringForOutputFile = [stringForOutputFile stringByAppendingString:barcode];
                
                for (int i=0; i<=_numEach; i++){
                    
                    NSString *ser = [NSString stringWithFormat:@"%d", (_startSer+i)];
                    
                    [_encode withGTIN:gtin ser:ser partBin:@"101"];
                    hex = [_encode sgtin_hex];
                    
                    // Collect the encoded barcodes
                    stringForOutputFile = [stringForOutputFile stringByAppendingFormat:@",%@", hex];
                    
                    NSLog( @"\nBarcode: %@\nEncoded SGTIN (hex): %@\n", barcode, hex);
                }
            }
            
            // Unsupported barcode
            else {
                NSLog( @"Unsupported Barcode: %@\n", barcode);
                continue;
            }
            
            // Carriage return for next record (the file is all one line)
            stringForOutputFile = [stringForOutputFile stringByAppendingString:@"\r"];
        }
    }
    
    // Write the output file
    if ([stringForOutputFile writeToURL:_outputFileURL
                             atomically:NO
                               encoding:NSUTF8StringEncoding
                                  error:&error] == YES)
    {
        [_statusFld setStringValue:@"Success"];
        [_successImg setHidden:FALSE];
        NSLog( @"Output file written: %@\n", _outputFileURL);
    }
    else
    {
        [_statusFld setStringValue:(NSString *)error];
        [_failImg setHidden:FALSE];
        NSLog( @"Error writing output file: %@\n", error);
    }
}

@end
