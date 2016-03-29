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
    NSURL          *_inputFileURL;
    NSURL          *_outputFileURL;
    NSOutputStream *_outputStream;
    NSURL          *_outputFilePGURL;
    NSOutputStream *_outputStreamPG;
    NSURL          *_outputFileErrorURL;
    NSOutputStream *_outputStreamError;
    int             _startSer;
    int             _numEach;
    EPCEncoder     *_encode;
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
    _outputStream = [[NSOutputStream alloc] initWithURL:_outputFileURL append:YES];
    [_outputStream open];
    NSString *fileNamePG = [NSString stringWithFormat:@"GeniTagOutputPG_%d-%d.csv", _startSer, (_startSer+_numEach-1)];
    _outputFilePGURL = [[_inputFileURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:fileNamePG];
    _outputStreamPG = [[NSOutputStream alloc] initWithURL:_outputFilePGURL append:YES];
    [_outputStreamPG open];
    NSString *fileNameError = [NSString stringWithFormat:@"GeniTagError_%d-%d.csv", _startSer, (_startSer+_numEach-1)];
    _outputFileErrorURL = [[_inputFileURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:fileNameError];
    _outputStreamError = [[NSOutputStream alloc] initWithURL:_outputFileErrorURL append:YES];
    [_outputStreamError open];
    
    [_successImg setHidden:TRUE];
    [_failImg setHidden:TRUE];
    
    // Load the input file
    NSError *error = nil;
    NSString *stringFromInputFile = [NSString stringWithContentsOfURL:_inputFileURL
                                                             encoding:NSUTF8StringEncoding
                                                                error:&error];

    // Double loop to handle both newlines and carriage returns
    for (NSString *file in [stringFromInputFile componentsSeparatedByString:@"\n"]) {
        for (NSString *line in [file componentsSeparatedByString:@"\r"]) {
            // Skip empties
            if ([line length] == 0) continue;
            
            // These output arrays can get big, so make sure they are released.
            @autoreleasepool {
                NSString *stringForOutputFile = [[NSString alloc] init];
                
                // Grab the barcode
                NSString *barcode = line;
                NSMutableString *hex;
                
                // Chop 13 and 14 digit barcodes to 12, if leading zeroes
                if (barcode.length == 13) {
                    if ([[barcode substringToIndex:1] isEqualToString:@"0"]) {
                        barcode = [barcode substringFromIndex:1];
                    }
                    else {
                        [self writeToErrorFile:barcode];
                        NSLog( @"Unsupported Barcode: %@\n", barcode);
                        continue;
                    }
                }
                if (barcode.length == 14) {
                    if ([[barcode substringToIndex:2] isEqualToString:@"00"]) {
                        barcode = [barcode substringFromIndex:2];
                    }
                    else {
                        [self writeToErrorFile:barcode];
                        NSLog( @"Unsupported Barcode: %@\n", barcode);
                        continue;
                    }
                }
                
                // Owned brand, encode DPCI in a GID
                if (barcode.length == 12 && [[barcode substringToIndex:2] isEqualToString:@"49"]) {
                    NSString *dpt = [barcode substringWithRange:NSMakeRange(2,3)];
                    NSString *cls = [barcode substringWithRange:NSMakeRange(5,2)];
                    NSString *itm = [barcode substringWithRange:NSMakeRange(7,4)];
                    
                    // Start with the barcode
                    stringForOutputFile = [stringForOutputFile stringByAppendingString:barcode];
                    
                    // Encode the first one
                    NSString *ser = [NSString stringWithFormat:@"%d", (_startSer)];
                    [_encode withDpt:dpt cls:cls itm:itm ser:ser];
                    hex = [NSMutableString stringWithString:[_encode gid_hex]];
                    
                    // Collect the encoded barcodes
                    stringForOutputFile = [stringForOutputFile stringByAppendingFormat:@",%@", hex];
                    [self writeToOutputFilePG:hex barcode:barcode];
                    NSLog( @"\nBarcode: %@\nEncoded GID (hex): %@\n", barcode, hex);
                    
                    // Now cycle through the rest
                    for (int i=1; i<_numEach; i++){
                        stringForOutputFile = [stringForOutputFile stringByAppendingFormat:@",%@", [self HexIncrement:hex]];
                        [self writeToOutputFilePG:hex barcode:barcode];
                        NSLog( @"\nBarcode: %@\nEncoded GID (hex): %@\n", barcode, hex);
                    }
                }
                
                // National brand, encode GTIN in an SGTIN
                else if (barcode.length == 12) {
                    // Take the gtin and encode a reference
                    NSString *gtin = barcode;
                    
                    // Start with the barcode
                    stringForOutputFile = [stringForOutputFile stringByAppendingString:barcode];
                    
                    // Encode the first one
                    NSString *ser = [NSString stringWithFormat:@"%d", (_startSer)];
                    [_encode withGTIN:gtin ser:ser partBin:@"101"];
                    hex = [NSMutableString stringWithString:[_encode sgtin_hex] ];
                    
                    // Collect the encoded barcodes
                    stringForOutputFile = [stringForOutputFile stringByAppendingFormat:@",%@", hex];
                    [self writeToOutputFilePG:hex barcode:barcode];
                    NSLog( @"\nBarcode: %@\nEncoded SGTIN (hex): %@\n", barcode, hex);
                    
                    // Now cycle through the rest
                    for (int i=1; i<_numEach; i++){
                        stringForOutputFile = [stringForOutputFile stringByAppendingFormat:@",%@", [self HexIncrement:hex]];
                        [self writeToOutputFilePG:hex barcode:barcode];
                        NSLog( @"\nBarcode: %@\nEncoded SGTIN (hex): %@\n", barcode, hex);
                    }
                }
                
                // Unsupported barcode
                else {
                    [self writeToErrorFile:barcode];
                    NSLog( @"Unsupported Barcode: %@\n", barcode);
                    continue;
                }
                
                // Write the output file one line at a time and clear the buffer
                [self writeToOutputFile:stringForOutputFile];
                stringForOutputFile = nil;
            }
        }
    }
    [_outputStream close];
    [_outputStreamPG close];
    [_outputStreamError close];
    
    if (error == nil) {
        [_statusFld setStringValue:@"Success"];
        [_successImg setHidden:FALSE];
        NSLog( @"Output file Completed: %@\n", _outputFileURL);
    }
    else
    {
        [_statusFld setStringValue:(NSString *)error];
        [_failImg setHidden:FALSE];
        NSLog( @"Error writing output file: %@\n", error);
    }
}

- (NSMutableString *)HexIncrement:(NSMutableString *)hex {
    // Find the last digit that is not an 'f'
    NSInteger length = hex.length;
    NSInteger rollDigit = hex.length;
    NSString *last;
    do {
        rollDigit--;
        if (rollDigit < 0 ) {
            hex = [NSMutableString stringWithString:@"1"];
            for (int i=0; i<length; i++) [hex appendString:@"0"];
            return hex;
        }
        last = [hex substringWithRange:NSMakeRange(rollDigit,1)];
    } while ([last isEqualToString:@"F"]);
    
    //Increment
    NSMutableString *increment;
    if      ([last isEqualToString:@"0"]) { increment = [NSMutableString stringWithString:@"1"]; }
    else if ([last isEqualToString:@"1"]) { increment = [NSMutableString stringWithString:@"2"]; }
    else if ([last isEqualToString:@"2"]) { increment = [NSMutableString stringWithString:@"3"]; }
    else if ([last isEqualToString:@"3"]) { increment = [NSMutableString stringWithString:@"4"]; }
    else if ([last isEqualToString:@"4"]) { increment = [NSMutableString stringWithString:@"5"]; }
    else if ([last isEqualToString:@"5"]) { increment = [NSMutableString stringWithString:@"6"]; }
    else if ([last isEqualToString:@"6"]) { increment = [NSMutableString stringWithString:@"7"]; }
    else if ([last isEqualToString:@"7"]) { increment = [NSMutableString stringWithString:@"8"]; }
    else if ([last isEqualToString:@"8"]) { increment = [NSMutableString stringWithString:@"9"]; }
    else if ([last isEqualToString:@"9"]) { increment = [NSMutableString stringWithString:@"A"]; }
    else if ([last isEqualToString:@"A"]) { increment = [NSMutableString stringWithString:@"B"]; }
    else if ([last isEqualToString:@"B"]) { increment = [NSMutableString stringWithString:@"C"]; }
    else if ([last isEqualToString:@"C"]) { increment = [NSMutableString stringWithString:@"D"]; }
    else if ([last isEqualToString:@"D"]) { increment = [NSMutableString stringWithString:@"E"]; }
    else if ([last isEqualToString:@"E"]) { increment = [NSMutableString stringWithString:@"F"]; }
    
    // Pad the increment
    for (NSInteger i=rollDigit+1; i<length; i++)
    {
        [increment appendString:@"0"];
    }
    
    // Replace the tail of the hex number with the increment
    [hex replaceCharactersInRange:NSMakeRange(rollDigit, length-rollDigit) withString:increment];
    
    return hex;
}

-(void) writeToOutputFile:(NSString*)content{
    // Carriage return for next record (the file is all one line)
    content = [content stringByAppendingString:@"\r\n"];
    NSData *strData = [content dataUsingEncoding:NSUTF8StringEncoding];
    [_outputStream write:(uint8_t *)[strData bytes] maxLength:[strData length]];
}

-(void) writeToOutputFilePG:(NSString*)hex barcode:(NSString*)barcode{
    // Carriage return for next record (the file is all one line)
    NSString *content = [NSString stringWithFormat:@"%@,%@\r\n", hex, barcode];
    NSData *strData = [content dataUsingEncoding:NSUTF8StringEncoding];
    [_outputStreamPG write:(uint8_t *)[strData bytes] maxLength:[strData length]];
}

-(void) writeToErrorFile:(NSString*)barcode{
    // Carriage return for next record (the file is all one line)
    NSString *content = [NSString stringWithFormat:@"%@\r\n", barcode];
    NSData *strData = [content dataUsingEncoding:NSUTF8StringEncoding];
    [_outputStreamError write:(uint8_t *)[strData bytes] maxLength:[strData length]];
}

@end
