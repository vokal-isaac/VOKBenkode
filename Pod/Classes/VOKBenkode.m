//
//  VOKBenkode.m
//
//  Created by Isaac Greenspan on 12/23/14.
//  Copyright (c) 2014 VOKAL Interactive. All rights reserved.
//

#import "VOKBenkode.h"

static char const NumberStartDelimiter = 'i';
static char const ArrayStartDelimiter = 'l';
static char const DictionaryStartDelimiter = 'd';
static char const EndDelimiter = 'e';
static char const StringLengthDataSeparator = ':';

@implementation VOKBenkode

#pragma mark - Encoding

+ (NSData *)encode:(id)obj
    stringEncoding:(NSStringEncoding)stringEncoding
             error:(NSError **)error
{
    if ([obj isKindOfClass:[NSNumber class]]) {
        return [[NSString stringWithFormat:@"%c%ld%c", NumberStartDelimiter, [obj longValue], EndDelimiter]
                dataUsingEncoding:NSASCIIStringEncoding];
    }
    if ([obj isKindOfClass:[NSString class]]) {
        NSMutableData *result = [[[NSString stringWithFormat:@"%@%c", @([obj length]), StringLengthDataSeparator]
                                  dataUsingEncoding:NSASCIIStringEncoding] mutableCopy];
        [result appendData:[obj dataUsingEncoding:stringEncoding]];
        return result;
    }
    if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableData *result = [NSMutableData dataWithBytes:&ArrayStartDelimiter length:1];
        for (id innerObj in obj) {
            NSError *innerError;
            NSData *data = [self encode:innerObj
                         stringEncoding:stringEncoding
                                  error:&innerError];
            if (!data) {
                if (error) {
                    *error = innerError;
                }
                return nil;
            }
            [result appendData:data];
        }
        [result appendBytes:&EndDelimiter length:1];
        return result;
    }
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSMutableData *result = [NSMutableData dataWithBytes:&DictionaryStartDelimiter length:1];
        for (id key in obj) {
            NSError *innerError;
            NSData *data = [self encode:key
                         stringEncoding:stringEncoding
                                  error:&innerError];
            if (!data) {
                if (error) {
                    *error = innerError;
                }
                return nil;
            }
            [result appendData:data];
            data = [self encode:obj[key]
                 stringEncoding:stringEncoding
                          error:&innerError];
            if (!data) {
                if (error) {
                    *error = innerError;
                }
                return nil;
            }
            [result appendData:data];
        }
        [result appendBytes:&EndDelimiter length:1];
        return result;
    }
    
    if (error) {
        // TODO: set error object
    }
    return nil;
}

+ (NSData *)encode:(id)obj
             error:(NSError **)error
{
    return [self encode:obj
         stringEncoding:NSUTF8StringEncoding
                  error:error];
}

+ (NSData *)encode:(id)obj
    stringEncoding:(NSStringEncoding)stringEncoding
{
    return [self encode:obj
         stringEncoding:stringEncoding
                  error:NULL];
}

+ (NSData *)encode:(id)obj
{
    return [self encode:obj
                  error:NULL];
}

#pragma mark - Decoding

+ (id)decode:(NSData *)data
stringEncoding:(NSStringEncoding)stringEncoding
       error:(NSError **)error
      length:(NSUInteger *)length
{
    char *dataBytes = (char *)data.bytes;
    char firstByte = dataBytes[0];
    switch (firstByte) {
        case DictionaryStartDelimiter:
            return [self decodeDict:data
                     stringEncoding:stringEncoding
                              error:error
                             length:length];
            
        case ArrayStartDelimiter:
            return [self decodeArray:data
                      stringEncoding:stringEncoding
                               error:error
                              length:length];
            
        case NumberStartDelimiter:
            return [self decodeNumber:data
                                error:error
                               length:length];
            
        case '0':  // Intentional grouping.
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
        case '8':
        case '9':
            return [self decodeString:data
                       stringEncoding:stringEncoding
                                error:error
                               length:length];
            
        default:
            if (error) {
                // TODO: set error object
            }
            return nil;
    }
}

+ (id)decode:(NSData *)data
stringEncoding:(NSStringEncoding)stringEncoding
       error:(NSError **)error
{
    return [self decode:data
         stringEncoding:stringEncoding
                  error:error
                 length:NULL];
}

+ (id)decode:(NSData *)data
       error:(NSError **)error
{
    return [self decode:data
         stringEncoding:NSUTF8StringEncoding
                  error:error];
}

+ (id)decode:(NSData *)data
stringEncoding:(NSStringEncoding)stringEncoding
{
    return [self decode:data
         stringEncoding:stringEncoding
                  error:NULL];
}

+ (id)decode:(NSData *)data
{
    return [self decode:data
                  error:NULL];
}

#pragma mark Decoding Primitives

+ (NSDictionary *)decodeDict:(NSData *)data
              stringEncoding:(NSStringEncoding)stringEncoding
                       error:(NSError **)error
                      length:(NSUInteger *)length
{
    char *dataBytes = (char *)data.bytes;
    NSAssert(dataBytes[0] == DictionaryStartDelimiter, @"Data does not begin with dictionary-data indicator.");
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSUInteger index = 1;
    while (index < data.length
           && dataBytes[index] != EndDelimiter) {
        NSError *innerError;
        NSUInteger innerLength;
        id innerKey = [self decode:[data subdataWithRange:NSMakeRange(index, data.length - index)]
                    stringEncoding:stringEncoding
                             error:&innerError
                            length:&innerLength];
        if (!innerKey) {
            if (error) {
                *error = innerError;
            }
            return nil;
        }
        index += innerLength;
        id innerValue = [self decode:[data subdataWithRange:NSMakeRange(index, data.length - index)]
                      stringEncoding:stringEncoding
                               error:&innerError
                              length:&innerLength];
        if (!innerValue) {
            if (error) {
                *error = innerError;
            }
            return nil;
        }
        result[innerKey] = innerValue;
        index += innerLength;
    }
    if (index >= data.length) {
        if (error) {
            // TODO: set error object
        }
        return nil;
    }
    if (length) {
        *length = index + 1;  // +1 for the EndDelimiter at the end.
    }
    return result;
}

+ (NSArray *)decodeArray:(NSData *)data
          stringEncoding:(NSStringEncoding)stringEncoding
                   error:(NSError **)error
                  length:(NSUInteger *)length
{
    char *dataBytes = (char *)data.bytes;
    NSAssert(dataBytes[0] == ArrayStartDelimiter, @"Data does not begin with array-data indicator.");
    NSMutableArray *result = [NSMutableArray array];
    NSUInteger index = 1;
    while (index < data.length
           && dataBytes[index] != EndDelimiter) {
        NSError *innerError;
        NSUInteger innerLength;
        id innerObject = [self decode:[data subdataWithRange:NSMakeRange(index, data.length - index)]
                       stringEncoding:stringEncoding
                                error:&innerError
                               length:&innerLength];
        if (!innerObject) {
            if (error) {
                *error = innerError;
            }
            return nil;
        }
        [result addObject:innerObject];
        index += innerLength;
    }
    if (index >= data.length) {
        if (error) {
            // TODO: set error object
        }
        return nil;
    }
    if (length) {
        *length = index + 1;  // +1 for the EndDelimiter at the end.
    }
    return result;
}

+ (NSNumber *)decodeNumber:(NSData *)data
                     error:(NSError **)error
                    length:(NSUInteger *)length
{
    char *dataBytes = (char *)data.bytes;
    NSAssert(dataBytes[0] == NumberStartDelimiter, @"Data does not begin with numeric-data indicator.");
    NSMutableString *buffer = [NSMutableString stringWithCapacity:data.length - 2];
    NSUInteger index = 1;
    while (index < data.length
           && dataBytes[index] != EndDelimiter) {
        [buffer appendFormat:@"%c", dataBytes[index]];
        index++;
    }
    if (index >= data.length) {
        if (error) {
            // TODO: set error object
        }
        return nil;
    }
    if (length) {
        *length = index + 1;  // +1 for the EndDelimiter at the end.
    }
    return [NSNumber numberWithLongLong:[buffer longLongValue]];
}

+ (NSString *)decodeString:(NSData *)data
            stringEncoding:(NSStringEncoding)stringEncoding
                     error:(NSError **)error
                    length:(NSUInteger *)length
{
    char *dataBytes = (char *)data.bytes;
    NSMutableString *buffer = [NSMutableString stringWithCapacity:data.length - 2];
    NSUInteger index = 0;
    while (index < data.length
           && dataBytes[index] != StringLengthDataSeparator) {
        [buffer appendFormat:@"%c", dataBytes[index]];
        index++;
    }
    if (index >= data.length) {
        if (error) {
            // TODO: set error object
        }
        return nil;
    }
    long long stringLength = [buffer longLongValue];
    if (stringLength < 0) {
        if (error) {
            // TODO: set error object
        }
        return nil;
    }
    index++;  // +1 for the StringLengthDataSeparator between the length and the string.
    NSUInteger localLength = index + stringLength;
    if (localLength > data.length) {
        if (error) {
            // TODO: set error object
        }
        return nil;
    }
    if (length) {
        *length = localLength;
    }
    return [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(index, stringLength)]
                                 encoding:stringEncoding];
}

@end
